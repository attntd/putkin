"""Private XDG paths and the inherited, stable-inode store lease."""
import fcntl
import json
import uuid
import os
from pathlib import Path
import stat

from signal_transport import Failure


def directory(path, *, private=False):
    """Walk with directory FDs: no symlink or check/open race at any level."""
    path = Path(path)
    if not path.is_absolute() or ".." in path.parts:
        raise Failure("unsafe_path")
    fd = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in path.parts[1:]:
            try:
                os.mkdir(part, mode=0o700, dir_fd=fd)
            except FileExistsError:
                pass
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = child
            info = os.fstat(fd)
            # A user namespace can expose the system root as an unmapped UID.
            system_uid = os.stat("/").st_uid
            sticky_root = info.st_uid == system_uid and bool(info.st_mode & stat.S_ISVTX)
            if info.st_uid not in (system_uid, os.getuid()) or (info.st_mode & 0o022 and not sticky_root):
                raise Failure("unsafe_path")
        info = os.fstat(fd)
        if info.st_uid != os.getuid() or (private and info.st_mode & 0o077):
            raise Failure("unsafe_path")
        return fd
    except BaseException:
        os.close(fd)
        raise


def private_file(parent_fd, name, *, create=False):
    fd = os.open(name, os.O_RDWR | os.O_NOFOLLOW | os.O_NONBLOCK | (os.O_CREAT if create else 0),
                 0o600, dir_fd=parent_fd)
    info = os.fstat(fd)
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077 or info.st_nlink != 1:
        os.close(fd)
        raise Failure("unsafe_path")
    return fd


class StoreLease:
    def __init__(self):
        data_home = os.environ.get("XDG_DATA_HOME")
        config_home = os.environ.get("XDG_CONFIG_HOME")
        self.data = Path(data_home if data_home is not None else Path.home() / ".local/share") / "putkin/signal"
        self.config = Path(config_home if config_home is not None else Path.home() / ".config") / "putkin"
        runtime = os.environ.get("XDG_RUNTIME_DIR")
        if not runtime:
            raise Failure("unsafe_path")
        fd = directory(runtime, private=True)
        os.close(fd)
        self.directory_fd = directory(self.data, private=True)
        try:
            self.lock_fd = private_file(self.directory_fd, "owner.lock", create=True)
        except BaseException:
            os.close(self.directory_fd)
            raise

    def acquire(self):
        try:
            fcntl.flock(self.lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return True
        except BlockingIOError:
            return False

    def read_config(self):
        fd = directory(self.config)
        try:
            try:
                config_fd = private_file(fd, "signal.json")
            except FileNotFoundError:
                return None
            with os.fdopen(config_fd, "rb") as source:
                raw = source.read(16385)
            if len(raw) > 16384:
                raise Failure("invalid_config")
            config = json.loads(raw)
            if (not isinstance(config, dict) or config.get("v") != 1
                    or type(config.get("enabled")) is not bool
                    or set(config) - {"v", "enabled", "executable", "javaHome", "deviceName", "typingIndicators"}):
                raise Failure("invalid_config")
            if "typingIndicators" in config and type(config["typingIndicators"]) is not bool:
                raise Failure("invalid_config")
            for key in ("executable", "javaHome", "deviceName"):
                if key in config and (not isinstance(config[key], str) or not config[key]):
                    raise Failure("invalid_config")
            return config
        except (ValueError, UnicodeError, RecursionError):
            raise Failure("invalid_config") from None
        finally:
            os.close(fd)

    def write_config(self, config):
        # Same validated parent/target as read_config; replace, fsync, never follow links.
        self.read_config()
        fd = directory(self.config)
        name = ".signal-" + uuid.uuid4().hex
        try:
            target = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                             0o600, dir_fd=fd)
            with os.fdopen(target, "w") as output:
                json.dump(config, output, ensure_ascii=False)
                output.flush()
                os.fsync(output.fileno())
            os.replace(name, "signal.json", src_dir_fd=fd, dst_dir_fd=fd)
            os.fsync(fd)
        finally:
            try:
                os.unlink(name, dir_fd=fd)
            except FileNotFoundError:
                pass
            os.close(fd)

    def close(self):
        # Never unlink or LOCK_UN: a surviving exec child holds this same lease.
        os.close(self.lock_fd)
        os.close(self.directory_fd)
