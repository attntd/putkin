"""Build the independently pinned RingRTC tunnel; never touch an account/audio device."""
import fcntl
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile

from _common import ROOT
sys.path.insert(0, str(ROOT / "services"))
from signal_call_runtime import verify
from signal_release import digest


def build(source=ROOT, cache=None, offline=False):
    source = source.resolve()
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        raise ValueError("Runtime rozmów Signal wymaga Linux x86_64/glibc.")
    policy = source / "services/signal-call-tunnel"
    pin = json.loads((policy / "runtime.json").read_text())
    for name, checksum in pin["patches"].items():
        if digest(policy / name) != checksum:
            raise ValueError("Niezgodna poprawka tunelu Signal: " + name)
    cache = (cache or Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "putkin/signal").resolve()
    work = cache / ("calls-" + digest(policy / "runtime.json")[:16])
    bundle = work / "runtime"
    work.mkdir(parents=True, exist_ok=True)
    with (work / ".lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if bundle.exists():
            verify(bundle, source)
            return bundle
        missing = [v for v in ("git", "cargo", "rustc", "clang", "cmake", "protoc", "pkg-config") if not shutil.which(v)]
        if missing:
            raise ValueError("Budowanie rozmów Signal wymaga: " + ", ".join(missing))
        def run(*args, **kwargs):
            return subprocess.run(list(map(str, args)), check=True, stdout=sys.stderr, **kwargs)
        tunnel = work / "source"
        def checkout(path, repo, commit):
            if not path.exists():
                if offline:
                    raise ValueError("Brak źródeł tunelu w cache offline.")
                run("git", "clone", "--no-checkout", repo, path)
            run("git", "-C", path, "checkout", "--force", "--detach", commit,
                env=dict(os.environ, GIT_NO_LAZY_FETCH="1") if offline else None)
            actual = subprocess.check_output(["git", "-C", str(path), "rev-parse", "HEAD"], text=True).strip()
            if actual != commit:
                raise ValueError("Niezgodne źródła tunelu Signal.")
        checkout(tunnel, pin["repository"], pin["commit"])
        ringrtc = tunnel / "third-party/ringrtc"
        if ringrtc.exists() and not (ringrtc / ".git").exists():
            ringrtc.rmdir()  # Empty gitlink directory in the parent checkout.
        checkout(ringrtc, pin["ringrtcRepository"], pin["ringrtcCommit"])
        if offline:
            # RingRTC's build script fetches WebRTC outside Cargo; verify its
            # exact cached archive before allowing an offline build to start.
            versions = dict(line.split("=", 1) for line in (ringrtc / "config/version.properties").read_text().splitlines() if "=" in line)
            archive = ringrtc / "out" / ("webrtc-" + versions["webrtc.version"] + "-linux-x64-release.tar.bz2")
            expected = json.loads((ringrtc / "config/webrtc_artifact_checksums.json").read_text())["linux-x64"]
            if not archive.is_file() or digest(archive) != expected:
                raise ValueError("Brak poprawnego archiwum WebRTC w cache offline.")
        run("git", "-C", tunnel, "apply", policy / "compatibility.patch")
        run("git", "-C", ringrtc, "apply", policy / "audio-lifecycle.patch")
        env = dict(os.environ, CARGO_HOME=str(work / "cargo"), OUTPUT_DIR=str(ringrtc / "out"))
        if offline:
            env["CARGO_NET_OFFLINE"] = "true"  # Includes cubeb's nested Cargo build.
        # Cargo.lock belongs to the pinned source plus the checked-in compatibility patch.
        run("cargo", "build", "--release", "--locked", *(["--offline"] if offline else []),
            "--manifest-path", tunnel / "signal-call-tunnel/Cargo.toml", env=env)
        with tempfile.TemporaryDirectory(prefix=".bundle-", dir=work) as temp:
            stage = Path(temp)
            (stage / "bin").mkdir()
            binary = stage / "bin/signal-call-tunnel"
            shutil.copy2(tunnel / "signal-call-tunnel/target/release/signal-call-tunnel", binary)
            shutil.copy2(ringrtc / "LICENSE", stage / "LICENSE-AGPL-3.0")
            shutil.copy2(ringrtc / "out/release/LICENSE.md", stage / "LICENSE-WebRTC.md")
            (stage / "manifest.json").write_text(json.dumps({"format": 1, "source": pin, "sha256": digest(binary),
                "rustc": subprocess.check_output(["rustc", "--version"], text=True).strip()}, indent=2) + "\n")
            verify(stage, source)
            os.replace(stage, bundle)
        return bundle


def runtime(source=ROOT, *, prepare=False, dry_run=False, cache=None, offline=False, installed=None):
    if not (source / "services/signal-call-tunnel/runtime.json").exists():
        return None, None  # Older releases can still be restored with text-only Signal.
    candidates = [source / "dependencies/signal-calls", source / "artifacts/signal-call-runtime"]
    if installed:
        candidates.append(installed / "dependencies/signal-calls")
    for path in candidates:
        if path.exists():
            try:
                verify(path, source)
                return path, {"calling": True, "bundle": str(path)}
            except (OSError, ValueError):
                if installed and path == installed / "dependencies/signal-calls":
                    continue
                raise
    if dry_run:
        return None, {"calling": True, "action": "build-from-cache" if offline else "download-build"}
    if prepare:
        path = build(source, cache, offline)
        return path, {"calling": True, "bundle": str(path)}
    raise ValueError("Brak tunelu Signal. Uruchom scripts/prepare-signal-calls albo scripts/install.")
