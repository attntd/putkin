"""Verified downloads, empty-cache planning and deterministic runtime selection."""
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
import urllib.error
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import _signal_bootstrap as bootstrap
import _signal_install as install


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="pk-bootstrap-")
        self.addCleanup(tmp.cleanup)
        self.base = Path(tmp.name)
        self.file = self.base / "downloads/archive"
        self.spec = {"url": "https://example.invalid/archive", "sha256": hashlib.sha256(b"verified").hexdigest()}

    def test_verified_fetch_is_cached_and_offline_reuses_it(self):
        with patch.object(bootstrap.urllib.request, "urlopen", return_value=io.BytesIO(b"verified")) as fetch:
            self.assertEqual(bootstrap.download(self.spec, self.file), self.file)
            self.assertEqual(bootstrap.download(self.spec, self.file, offline=True), self.file)
            self.assertEqual(fetch.call_count, 1)
        self.assertEqual(self.file.read_bytes(), b"verified")

    def test_corrupt_partial_and_missing_offline_downloads_never_publish(self):
        with patch.object(bootstrap.urllib.request, "urlopen", return_value=io.BytesIO(b"corrupt")):
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                bootstrap.download(self.spec, self.file)
        self.assertFalse(self.file.exists())
        self.assertFalse(list(self.file.parent.glob(".download-*")))
        with patch.object(bootstrap.urllib.request, "urlopen", side_effect=urllib.error.URLError("offline")):
            with self.assertRaisesRegex(RuntimeError, "Ponów"):
                bootstrap.download(self.spec, self.file)
        with self.assertRaisesRegex(ValueError, "offline"):
            bootstrap.download(self.spec, self.file, offline=True)

    def test_empty_cache_dry_run_plans_build_without_creating_it(self):
        cache = self.base / "cache"
        with patch.object(install, "ROOT", self.base):
            bundle, info = install.runtime(ROOT, cache=cache, dry_run=True)
        self.assertIsNone(bundle)
        self.assertEqual(info["action"], "download-patch-build")
        self.assertFalse(cache.exists())

    def test_explicit_wrong_runtime_is_not_silently_replaced(self):
        supplied = self.base / "bad-runtime"
        supplied.mkdir()
        with patch.object(install, "build") as build:
            with self.assertRaises(ValueError):
                install.runtime(ROOT, supplied, prepare=True)
            build.assert_not_called()

    def test_all_build_sources_match_the_recipe(self):
        policy = ROOT / "services/signal-cli-media"
        recipe = json.loads((policy / "recipe.json").read_text())
        inputs = json.loads((policy / "build.json").read_text())
        self.assertEqual(set(inputs["sources"]), set(recipe["sources"]))
        self.assertTrue(all("/v0.14.8/" in url for url in inputs["sources"].values()))


if __name__ == "__main__":
    unittest.main()
