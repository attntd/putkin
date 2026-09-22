"""Reproduce the pinned Signal runtime from verified public inputs."""
import fcntl
import json
import os
from pathlib import Path
import platform
import runpy
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

from _common import ROOT

sys.path.insert(0, str(ROOT / "services"))
from signal_release import digest, verify_runtime


def download(spec, path, offline=False):
    """Cache only complete, checksum-verified files; a failed fetch is retryable."""
    if path.exists():
        if path.is_symlink() or digest(path) != spec["sha256"]:
            raise ValueError(f"Uszkodzony plik pobrania: {path}. Usuń go i ponów instalację.")
        return path
    if offline:
        raise ValueError(f"Brak pliku w cache offline: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    print(f"Signal: pobieranie {path.name}", file=sys.stderr, flush=True)
    fd, name = tempfile.mkstemp(prefix=".download-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            with urllib.request.urlopen(spec["url"], timeout=60) as response:
                shutil.copyfileobj(response, output)
        if digest(Path(name)) != spec["sha256"]:
            raise ValueError(f"Nieprawidłowy SHA-256 pobrania: {path.name}")
        os.replace(name, path)
    except urllib.error.URLError as error:
        raise RuntimeError(f"Nie udało się pobrać {path.name}: {error.reason}. Ponów scripts/install; poprawne pobrania zostają w cache.") from None
    finally:
        Path(name).unlink(missing_ok=True)
    return path


def cache_directory():
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    return (cache if cache.is_absolute() else Path.home() / ".cache") / "putkin/signal"


def bundle_path(source=ROOT, cache=None):
    pin = json.loads((source / "services/signal-cli-media/distribution.json").read_text())
    return (cache or cache_directory()) / pin["treeSha256"] / "runtime"


def build(source=ROOT, cache=None, offline=False):
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        raise ValueError("Runtime Signala wymaga Linux x86_64/glibc.")
    policy = source / "services/signal-cli-media"
    pin = json.loads((policy / "distribution.json").read_text())
    recipe = json.loads((policy / "recipe.json").read_text())
    inputs = json.loads((policy / "build.json").read_text())
    bundle = bundle_path(source, cache)
    bundle.parent.mkdir(parents=True, exist_ok=True)
    with (bundle.parent / ".build.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if bundle.exists():
            verify_runtime(bundle, source)
            return bundle
        if not shutil.which("patch"):
            raise ValueError("Budowanie Signal wymaga programu patch (Arch: sudo pacman -S --needed patch).")
        downloads = bundle.parent / "downloads"
        archives = {name: download(spec, downloads / (name + ".tar.gz"), offline)
                    for name, spec in (("cli", pin["cliArchive"]), ("jre", pin["jreArchive"]), ("jdk", inputs["jdkArchive"]))}
        sources = downloads / "sources"
        for name, sha in recipe["sources"].items():
            download({"url": inputs["sources"][name], "sha256": sha}, sources / name, offline)
        extract = runpy.run_path(str(ROOT / "scripts/package-signal-runtime"))["extract"]
        with tempfile.TemporaryDirectory(prefix=".build-", dir=bundle.parent) as directory:
            work = Path(directory)
            cli = extract(archives["cli"], pin["cliArchive"]["sha256"], work / "original")
            jdk = extract(archives["jdk"], inputs["jdkArchive"]["sha256"], work / "java")
            env = {k: v for k, v in os.environ.items() if k not in
                   ("JAVA_TOOL_OPTIONS", "JDK_JAVA_OPTIONS", "_JAVA_OPTIONS", "JAVA_OPTS", "CLASSPATH")}
            print("Signal: nakładanie poprawek i kompilacja", file=sys.stderr, flush=True)
            subprocess.run([sys.executable, ROOT / "scripts/build-signal-media-cli", "--policy", policy,
                            "--source", sources, "--distribution", cli, "--jdk", jdk,
                            "--output", work / "patched"], env=env, stdout=sys.stderr, check=True)
            subprocess.run([sys.executable, ROOT / "scripts/package-signal-runtime", "--source", source,
                            "--cli-archive", archives["cli"], "--jre-archive", archives["jre"],
                            "--patched-cli", work / "patched", "--output", work / "runtime"],
                           env=env, stdout=sys.stderr, check=True)
            verify_runtime(work / "runtime", source)
            os.replace(work / "runtime", bundle)
        return bundle
