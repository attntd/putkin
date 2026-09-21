"""Release compatibility and pinned runtime; never restore user data."""
from contextlib import closing
import ast
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import sqlite3
import stat
import tempfile

from signal_transport import Failure

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def tree(root):
    result = {}
    if root.is_symlink() or not root.is_dir():
        raise ValueError("Brak katalogu runtime Signala.")
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            raise ValueError("Dowiązanie w runtime Signala.")
        if path.is_dir():
            continue
        if not path.is_file():
            raise ValueError("Nieprawidłowy plik runtime Signala.")
        result[str(path.relative_to(root))] = [digest(path), bool(path.stat().st_mode & 0o111)]
    return result


def tree_digest(files):
    return hashlib.sha256(json.dumps(files, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def verify_runtime(bundle, source=ROOT):
    pin = json.loads((source / "services/signal-cli-media/distribution.json").read_text())
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        raise ValueError("Runtime Signala wymaga Linux x86_64/glibc.")
    if tree_digest(tree(bundle)) != pin["treeSha256"]:
        raise ValueError("Nieprawidłowy runtime Signala (SHA-256 lub prawa wykonania). Przygotuj scripts/package-signal-runtime.")
    return {key: pin[key] for key in ("platform", "cliVersion", "javaVersion", "policy", "treeSha256")}


def release_spec(source=ROOT):
    path = source / "services/signal-release.json"
    if not path.exists():
        if (source / "services/SignalBackend.qml").exists():
            raise ValueError("Wydanie Signala bez kontraktu zgodności; downgrade zatrzymany.")
        return None  # A pre-Signal shell cannot read or mutate Signal data.
    spec = json.loads(path.read_text())
    if (not isinstance(spec, dict) or spec.get("format") != 1 or type(spec.get("schemaMin")) is not int
            or type(spec.get("schemaMax")) is not int or type(spec.get("retention")) is not int
            or not isinstance(spec.get("cliStore"), str)
            or not 0 <= spec["schemaMin"] <= spec["schemaMax"] or spec["retention"] < 2):
        raise ValueError("Nieprawidłowy kontrakt wydania Signala.")
    if (source / "services/SignalBackend.qml").exists():
        syntax = ast.parse((source / "services/signal_store.py").read_text())
        schema = next((node.value.value for node in syntax.body if isinstance(node, ast.Assign)
                       and any(isinstance(target, ast.Name) and target.id == "SCHEMA_VERSION" for target in node.targets)
                       and isinstance(node.value, ast.Constant)), None)
        pin = json.loads((source / "services/signal-cli-media/distribution.json").read_text())
        policy = json.loads((source / "services/signal-cli-media/runtime.json").read_text())
        if (schema != spec["schemaMax"] or "signal-cli-" + pin["cliVersion"] != spec["cliStore"]
                or pin["policy"] != "putkin-retention-" + str(spec["retention"])
                or policy["policy"] != pin["policy"]):
            raise ValueError("Kod, CLI i kontrakt schematu Signala są niezgodne.")
    return spec


def safe_path(path):
    # Inspection must not create anything in the destination (including dry-run).
    for parent in (*reversed(path.parents), path):
        if parent.is_symlink():
            raise ValueError("Dowiązanie w danych Signala; przełączenie zatrzymane.")
    if path.exists() and (not path.is_file() or path.stat().st_nlink != 1):
        raise ValueError("Nieprawidłowy plik danych Signala.")


def compatibility(data, spec):
    if spec is None:
        return {"signal": "unavailable", "data": "preserved"}
    db = data / "history.sqlite3"
    marker = data / "release.json"
    safe_path(marker)
    record = json.loads(marker.read_text()) if marker.exists() else None
    if record is not None:
        if not isinstance(record, dict) or record.get("format") != 1 or record.get("cliStore") != spec["cliStore"]:
            raise ValueError("Niezgodny format danych signal-cli; nie wolno cofać kluczy/sesji konta.")
        if type(record.get("retention")) is not int or record["retention"] > spec["retention"]:
            raise ValueError("Downgrade polityki retencji Signala jest niedozwolony.")
        if type(record.get("schemaMax")) is not int or record["schemaMax"] > spec["schemaMax"]:
            raise ValueError("Downgrade schematu Signala jest niedozwolony.")
    elif (data / "cli").exists() and any((data / "cli").iterdir()):
        # Legacy development accounts have no proven protocol version.
        raise ValueError("Istnieją dane CLI bez kontraktu wersji; wymagany audyt zgodności konta.")
    safe_path(db)
    schema = 0
    if db.exists():
        # SQLite read-only can still create SHM. Inspect a private disposable copy
        # with the WAL, never immutable=1 (which would ignore pending migrations).
        with tempfile.TemporaryDirectory(prefix="pk-signal-schema-") as directory:
            copy = Path(directory) / db.name
            for suffix in ("", "-wal", "-shm", "-journal"):
                path = db.with_name(db.name + suffix)
                safe_path(path)
                if path.exists() and suffix != "-shm":
                    shutil.copyfile(path, copy.with_name(copy.name + suffix))
                    copy.with_name(copy.name + suffix).chmod(0o600)
            with closing(sqlite3.connect(copy)) as connection:
                schema = connection.execute("PRAGMA user_version").fetchone()[0]
                if connection.execute("PRAGMA quick_check").fetchone()[0] != "ok":
                    raise ValueError("Uszkodzona historia Signala; przełączenie zatrzymane.")
    if not spec["schemaMin"] <= schema <= spec["schemaMax"]:
        raise ValueError(f"Niezgodny schemat Signala: baza v{schema}, wydanie obsługuje v{spec['schemaMin']}–v{spec['schemaMax']}.")
    return {"schema": schema, "targetSchema": spec["schemaMax"], "cliStore": spec["cliStore"],
            "retention": spec["retention"], "data": "preserved"}


def claim_release(lease):
    """Under the inherited owner lease, before migrations or CLI writes."""
    try:
        spec = release_spec()
        compatibility(lease.data, spec)
        raw = json.dumps(spec, sort_keys=True).encode()
        fd, name = tempfile.mkstemp(prefix=".release-", dir=lease.data)
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(raw)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(name, lease.data / "release.json")
            os.fsync(lease.directory_fd)
        finally:
            Path(name).unlink(missing_ok=True)
    except ValueError:
        raise Failure("incompatible_release") from None
    except (OSError, sqlite3.Error):
        raise Failure("storage_error") from None


def command(config):
    """Installed builds resolve their own pinned tools without changing config."""
    bundle = ROOT / "dependencies/signal"
    env = dict(os.environ)
    if bundle.exists():
        try:
            verify_runtime(bundle)
        except (OSError, ValueError, KeyError, TypeError):
            raise Failure("runtime_invalid") from None
        executable = bundle / "cli/bin/signal-cli"
        java = bundle / "jre"
        if (config.get("executable") and Path(config["executable"]).resolve() != executable.resolve()
                or config.get("javaHome") and Path(config["javaHome"]).resolve() != java.resolve()):
            raise Failure("invalid_config")
        env["JAVA_HOME"] = str(java)
    else:
        executable = config.get("executable", "signal-cli")
        if "/" in executable and not Path(executable).is_absolute():
            raise Failure("invalid_config")
        executable = shutil.which(executable)
        if not executable:
            raise Failure("cli_unavailable")
        if config.get("javaHome"):
            if not Path(config["javaHome"]).is_absolute():
                raise Failure("invalid_config")
            env["JAVA_HOME"] = config["javaHome"]
    # Do not inherit arbitrary JVM injection or account-independent logging.
    for key in ("JAVA_TOOL_OPTIONS", "JDK_JAVA_OPTIONS", "_JAVA_OPTIONS", "JAVA_OPTS", "CLASSPATH"):
        env.pop(key, None)
    return [str(executable)], env
