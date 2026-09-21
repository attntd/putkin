"""Bounded file IO in workers; SQLite ownership remains on the bridge loop.

No remote URLs, shell interpolation, raw payloads in IPC, or executable opens.
IDs, never a sender's filename, address controlled copies. Cleanup is refcounted.
"""
import errno
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile
import threading
import unicodedata
import uuid
from urllib.parse import unquote, urlsplit

from signal_events import identifier, text
from signal_paths import directory
from signal_transport import Failure
from signal_process import child_command

MAX_FILE = 32 * 1024 * 1024
MAX_BATCH = 128 * 1024 * 1024
MAX_FILES = 8
MAX_STORE = 512 * 1024 * 1024
MAX_PIXELS = 20_000_000
MEDIA_CAPABILITIES = ["attachment.stage", "attachment.paste", "attachment.remove", "attachment.save", "attachment.open"]
TYPES = {"image/png": "png", "image/jpeg": "jpg", "image/webp": "webp", "image/gif": "gif",
         "video/mp4": "mp4", "video/webm": "webm", "video/x-matroska": "mkv", "video/quicktime": "mov",
         "audio/mpeg": "mp3", "audio/ogg": "ogg", "audio/x-wav": "wav", "audio/wav": "wav",
         "audio/flac": "flac", "audio/x-flac": "flac", "audio/mp4": "m4a", "application/ogg": "ogg",
         "application/pdf": "pdf", "text/plain": "txt"}
EXECUTABLE = {"application/x-executable", "application/x-pie-executable", "application/x-sharedlib",
              "application/x-dosexec", "application/x-msdownload", "application/x-desktop",
              "text/x-shellscript", "text/x-python", "text/x-perl", "text/x-php", "application/javascript"}
DANGEROUS_SUFFIXES = {".desktop", ".exe", ".com", ".bat", ".cmd", ".sh", ".py", ".pl", ".js", ".jar", ".appimage"}


def verify_cli(executable):
    try:
        expected = json.loads(Path(__file__).with_name("signal-cli-media").joinpath("runtime.json").read_text())
        library = Path(executable).resolve().parents[1] / "lib/libsignal-cli-0.14.8.jar"
        application = library.with_name("signal-cli-0.14.8.jar")
        if (hashlib.sha256(library.read_bytes()).hexdigest() != expected["librarySha256"]
                or hashlib.sha256(application.read_bytes()).hexdigest() != expected["applicationSha256"]):
            raise ValueError()
    except (OSError, ValueError, KeyError):
        raise Failure("media_policy_required") from None


def filename(value):
    # Display only. Strip separators, bidi/control characters and cap length.
    value = str(value or "Załącznik").replace("\\", "/").split("/")[-1]
    return "".join(c for c in value if not unicodedata.category(c).startswith("C"))[:160] or "Załącznik"


def local_path(value):
    value = text(value, 8192, empty=False)
    if value.startswith("file:"):
        url = urlsplit(value)
        if url.netloc or url.query or url.fragment:
            raise Failure("unsafe_path")
        value = unquote(url.path)
    path = Path(value)
    if not path.is_absolute() or ".." in path.parts or "\0" in value:
        raise Failure("unsafe_path")
    return path


def open_source(path):
    # Unlike directory(), selecting a source must never create directories.
    parent = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in path.parts[1:-1]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
            os.close(parent)
            parent = child
        return os.open(path.name, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW, dir_fd=parent)
    finally:
        os.close(parent)


def run_worker(arguments, timeout=12, started=None, finished=None):
    """prlimit avoids unsafe preexec_fn in the multithreaded bridge."""
    try:
        with tempfile.TemporaryFile() as output:
            with subprocess.Popen(child_command(["prlimit", "--as=1073741824", "--cpu=10", "--fsize=41943040", "--nofile=64", "--", *arguments]),
                                  stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.DEVNULL) as process:
                try:
                    if started: started(process)
                    result_code = process.wait(timeout=timeout)
                finally:
                    if process.poll() is None: process.kill()
                    process.wait()
                    if finished: finished(process)
            output.seek(0); value = output.read(65537)
            if result_code or len(value) > 65536:
                raise Failure("media_decode_failed")
            return value
    except (FileNotFoundError, subprocess.TimeoutExpired):
        raise Failure("media_decoder_unavailable") from None


class Media:
    def __init__(self, store, lease):
        self.store, self.root = store, lease.data
        self.originals, self.cache, self.staging = [self.root / x for x in ("media", "thumbnails", "staging")]
        for path in (self.originals, self.cache, self.staging):
            os.close(directory(path, private=True))
        self.active = set()
        self.revoked = set()
        self.jobs = {}
        self.jobs_lock = threading.Lock()

    def retire(self, aids):
        """Called after dropping refs: abort only workers with no remaining owner."""
        for aid in aids:
            if aid not in self.active or self.store.db.execute('SELECT 1 FROM attachment_refs WHERE attachment_id=? UNION ALL SELECT 1 FROM draft_attachments WHERE attachment_id=?', (aid, aid)).fetchone():
                continue
            with self.jobs_lock:
                self.revoked.add(aid)
                process = self.jobs.get(aid)
                if process and process.poll() is None:
                    process.kill()

    def check_active(self, aid):
        if aid in self.revoked:
            raise Failure('attachment_unavailable')

    def decode(self, aid, args):
        def started(process):
            with self.jobs_lock:
                self.jobs[aid] = process
                if aid in self.revoked and process.poll() is None: process.kill()
        def finished(process):
            with self.jobs_lock:
                if self.jobs.get(aid) is process: self.jobs.pop(aid)
        self.check_active(aid)
        return run_worker(args, started=started, finished=finished)

    def path(self, aid, extension):
        return self.originals / (identifier(aid) + "." + extension)

    def used(self):
        return sum(p.stat(follow_symlinks=False).st_size for folder in (self.originals, self.cache, self.staging)
                   for p in folder.iterdir() if p.is_file() and not p.is_symlink())

    def prepare(self, source, aid, name=None, declared=None, size=None, clipboard=False):
        """Worker: immutable durable copy; failure/cancellation leaves no copy."""
        aid = identifier(aid)
        part = self.staging / (aid + ".part")
        dest = None
        try:
            for folder in (self.originals, self.cache, self.staging):
                os.close(directory(folder, private=True))
            path = local_path(source)
            with os.fdopen(open_source(path), "rb") as src:
                before = os.fstat(src.fileno())
                if not stat.S_ISREG(before.st_mode) or before.st_mode & 0o111 or before.st_nlink != 1:
                    raise Failure("attachment_unsafe")
                if before.st_size <= 0 or before.st_size > MAX_FILE or (size is not None and before.st_size != size):
                    raise Failure("attachment_size")
                if self.used() + before.st_size > MAX_STORE:
                    raise Failure("media_quota")
                if shutil.disk_usage(self.root).free < before.st_size + 16 * 1024 * 1024:
                    raise Failure("media_disk_full")
                label = filename(name or path.name)
                if Path(label).suffix.lower() in DANGEROUS_SUFFIXES:
                    raise Failure("attachment_unsafe")
                count = 0
                with part.open("xb") as target:
                    os.chmod(part, 0o600)
                    while chunk := src.read(256 * 1024):
                        self.check_active(aid)
                        count += len(chunk)
                        if count > MAX_FILE:
                            raise Failure("attachment_size")
                        target.write(chunk)
                    target.flush()
                    os.fsync(target.fileno())
                after = os.fstat(src.fileno())
                if count != before.st_size or (before.st_mtime_ns, before.st_ctime_ns) != (after.st_mtime_ns, after.st_ctime_ns):
                    raise Failure("attachment_changed")
            mime = self.decode(aid, ["file", "--brief", "--mime-type", "--", str(part)]).decode().strip()
            if mime in EXECUTABLE or mime.startswith("text/x-"):
                raise Failure("attachment_unsafe")
            if declared and declared not in (mime, "application/octet-stream"):
                aliases = [{"audio/wav", "audio/x-wav"}, {"audio/ogg", "application/ogg"}, {"audio/flac", "audio/x-flac"}]
                if not any({mime, declared} <= group for group in aliases):
                    raise Failure("attachment_mime")
            if clipboard and mime != "image/png":
                raise Failure("attachment_mime")
            extension = TYPES.get(mime, "bin")
            dest = self.path(aid, extension)
            self.check_active(aid)
            os.replace(part, dest)
            result = {"id": aid, "filename": label, "mime": mime, "size": count, "extension": extension,
                      "thumbnail": False, "preview": False, "error": ""}
            if mime.startswith(("image/", "audio/", "video/")) or mime == "application/ogg":
                try:
                    probe = json.loads(self.decode(aid, ["ffprobe", "-v", "error", "-threads", "1", "-protocol_whitelist", "file,pipe",
                        "-show_entries", "stream=codec_type,width,height", "-of", "json", str(dest)]))
                    streams = probe.get("streams", [])
                    if not streams:
                        raise Failure("media_decode_failed")
                    for stream in streams:
                        if stream.get("width", 0) * stream.get("height", 0) > MAX_PIXELS:
                            raise Failure("media_dimensions")
                    if mime.startswith("image/"):
                        for variant, bound in (("thumbnail", 384), ("preview", 1600)):
                            target = self.cache / (aid + "-" + variant + ".jpg")
                            self.decode(aid, ["ffmpeg", "-v", "error", "-nostdin", "-threads", "1", "-protocol_whitelist", "file,pipe",
                                "-i", str(dest), "-frames:v", "1", "-vf", f"scale={bound}:{bound}:force_original_aspect_ratio=decrease",
                                "-threads", "1", "-update", "1", "-y", str(target)])
                            os.chmod(target, 0o600)
                            result[variant] = True
                except (Failure, ValueError) as error:
                    result["error"] = error.code if isinstance(error, Failure) else "media_decode_failed"
                    for variant in ("thumbnail", "preview"):
                        (self.cache / (aid + "-" + variant + ".jpg")).unlink(missing_ok=True)
                        result[variant] = False
            for folder in (self.originals, self.cache):
                fd = os.open(folder, os.O_RDONLY | os.O_DIRECTORY)
                try: os.fsync(fd)
                finally: os.close(fd)
            self.check_active(aid)
            return result
        except OSError as error:
            if dest: dest.unlink(missing_ok=True)
            raise Failure("media_disk_full" if error.errno == errno.ENOSPC else "attachment_unavailable") from None
        except BaseException:
            if dest: dest.unlink(missing_ok=True)
            raise
        finally:
            part.unlink(missing_ok=True)
            if aid in self.revoked:
                for variant in ('thumbnail', 'preview'):
                    (self.cache / (aid + '-' + variant + '.jpg')).unlink(missing_ok=True)

    def stage(self, account, cid, prepared):
        self.store.conversation(account, cid)
        with self.store.transaction():
            existing = self.draft(account, cid)
            if len(existing) + len(prepared) > MAX_FILES or sum(a["size_bytes"] for a in existing) + sum(p["size"] for p in prepared) > MAX_BATCH:
                raise Failure("attachment_limit")
            for p in prepared:
                self.store.db.execute("INSERT INTO attachments VALUES(?,?,?,?,?)", (p["id"], account, "local:" + p["id"], p["mime"], p["size"]))
                self.record(p)
                self.store.db.execute("INSERT INTO draft_attachments VALUES(?,?,?)", (cid, p["id"], self.store.clock()))
            self.store.changed("attachments.changed", accountId=account, conversationId=cid)
        return {"attachments": self.draft(account, cid)}

    def record(self, p):
        self.store.db.execute("""INSERT INTO media_files(attachment_id,filename,state,error_code,extension,thumbnail,preview)
            VALUES(?,?,'ready',?,?,?,?) ON CONFLICT(attachment_id) DO UPDATE SET state='ready',error_code=excluded.error_code,
            extension=excluded.extension,thumbnail=excluded.thumbnail,preview=excluded.preview""",
            (p["id"], p["filename"], p["error"], p["extension"], p["thumbnail"], p["preview"]))

    def item(self, account, aid):
        row = self.store.db.execute("SELECT a.*,m.filename,m.state,m.error_code,m.extension,m.thumbnail,m.preview,m.voice_note FROM attachments a LEFT JOIN media_files m USING(attachment_id) WHERE a.account_id=? AND a.attachment_id=?", (account, identifier(aid))).fetchone()
        if not row:
            raise Failure("not_found")
        item = {key: row[key] for key in ("attachment_id", "content_type", "size_bytes")}
        ready = row["state"] == "ready"
        if ready:
            try:
                info = self.path(aid, row["extension"]).lstat()
                ready = stat.S_ISREG(info.st_mode) and info.st_size == row["size_bytes"] and not (info.st_mode & 0o177)
            except OSError: ready = False
        state = "unavailable" if row["state"] == "ready" and not ready else row["state"] or "unavailable"
        item.update(filename=row["filename"] or "Załącznik", state=state, errorCode=row["error_code"] or "",
                    voiceNote=bool(row["voice_note"]), url=self.path(aid, row["extension"]).as_uri() if ready else "",
                    thumbnail=(self.cache / (aid + "-thumbnail.jpg")).as_uri() if ready and row["thumbnail"] else "",
                    preview=(self.cache / (aid + "-preview.jpg")).as_uri() if ready and row["preview"] else "")
        return item

    def draft(self, account, cid):
        self.store.conversation(account, cid)
        return [self.item(account, r[0]) for r in self.store.db.execute("SELECT attachment_id FROM draft_attachments WHERE conversation_id=? ORDER BY created_ms,attachment_id", (cid,))]

    def remove(self, account, cid, aid):
        self.store.conversation(account, cid)
        with self.store.transaction():
            self.store.db.execute("DELETE FROM draft_attachments WHERE conversation_id=? AND attachment_id=?", (cid, identifier(aid)))
            self.store.changed("attachments.changed", accountId=account, conversationId=cid)
        return {"attachments": self.draft(account, cid)}

    def pending(self, account):
        return self.store.db.execute("SELECT a.*,m.filename FROM attachments a JOIN media_files m USING(attachment_id) WHERE a.account_id=? AND m.state='pending'", (account,)).fetchall()

    def source(self, cli_id):
        if not re.fullmatch(r"[a-zA-Z0-9_+=.-]{1,256}", cli_id) or cli_id in (".", ".."):
            raise Failure("unsafe_path")
        return self.root / "cli/attachments" / cli_id

    def imported(self, account, aid, prepared=None, error=""):
        if not self.store.db.execute("SELECT 1 FROM attachments WHERE account_id=? AND attachment_id=?", (account, aid)).fetchone():
            return
        with self.store.transaction():
            if prepared: self.record(prepared)
            else: self.store.db.execute("UPDATE media_files SET state='unavailable',error_code=? WHERE attachment_id=?", (error, aid))
            for row in self.store.db.execute("SELECT message_id FROM attachment_refs WHERE attachment_id=?", (aid,)):
                self.store.notify_message(account, row[0])

    def gc(self, startup=False):
        """Post-COMMIT + startup hook. Shared refs survive; saved user copies do not belong here."""
        self.revoked.intersection_update(self.active)
        self.store.db.execute("DELETE FROM attachments WHERE NOT EXISTS(SELECT 1 FROM attachment_refs r WHERE r.attachment_id=attachments.attachment_id) AND NOT EXISTS(SELECT 1 FROM draft_attachments d WHERE d.attachment_id=attachments.attachment_id)")
        for row in self.store.db.execute("SELECT cli_id FROM media_cli_gc").fetchall():
            self.release_cli(row[0])
            self.store.db.execute("DELETE FROM media_cli_gc WHERE cli_id=?", (row[0],))
        live = {r[0] for r in self.store.db.execute("SELECT attachment_id FROM attachments")} | self.active
        for folder in (self.originals, self.cache, self.staging):
            for path in folder.iterdir():
                aid = path.name[:36]
                if aid not in live:
                    if path.is_file() or path.is_symlink(): path.unlink()
        # CLI IDs may be shared: retain until every pending import finished.
        pending = {r[0] for r in self.store.db.execute("SELECT cli_id FROM attachments JOIN media_files USING(attachment_id) WHERE state='pending'")}
        cli = self.root / "cli/attachments"
        if startup and cli.exists():
            fd = directory(cli, private=True)
            try:
                for name in os.listdir(fd):
                    if name not in pending:
                        info = os.stat(name, dir_fd=fd, follow_symlinks=False)
                        if stat.S_ISREG(info.st_mode) or stat.S_ISLNK(info.st_mode): os.unlink(name, dir_fd=fd)
            finally: os.close(fd)
        temporary = self.root / "cli/tmp"
        if startup and temporary.exists():
            fd = directory(temporary, private=True)
            try:
                for name in os.listdir(fd):
                    info = os.stat(name, dir_fd=fd, follow_symlinks=False)
                    if stat.S_ISREG(info.st_mode) or stat.S_ISLNK(info.st_mode): os.unlink(name, dir_fd=fd)
            finally: os.close(fd)

    def release_cli(self, cli_id):
        if self.store.db.execute("SELECT 1 FROM attachments JOIN media_files USING(attachment_id) WHERE cli_id=? AND state='pending'", (cli_id,)).fetchone():
            return
        try:
            path = self.source(cli_id)
        except Failure:
            return  # An invalid identifier never authorizes a filesystem action.
        try:
            fd = directory(path.parent, private=True)
            try: os.unlink(path.name, dir_fd=fd)
            finally: os.close(fd)
        except FileNotFoundError:
            pass

    def send_paths(self, account, mid):
        result = []
        for row in self.store.db.execute("SELECT attachment_id FROM attachment_refs WHERE message_id=?", (mid,)):
            item = self.item(account, row[0])
            if item["state"] != "ready": raise Failure("attachment_unavailable")
            path = local_path(item["url"])
            try:
                with os.fdopen(open_source(path), "rb") as source:
                    info = os.fstat(source.fileno())
                    if not stat.S_ISREG(info.st_mode) or info.st_size != item["size_bytes"] or info.st_mode & 0o177:
                        raise Failure("attachment_changed")
            except OSError:
                raise Failure("attachment_unavailable") from None
            result.append(str(path))
        return result

    def save(self, source, destination):
        # Exclusive create: never overwrite a target or follow a symlink.
        destination = local_path(destination)
        parent = directory(destination.parent)
        target = None
        created = False
        try:
            target = os.open(destination.name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=parent)
            created = True
            with os.fdopen(open_source(local_path(source)), "rb") as src, os.fdopen(target, "wb") as out:
                target = None
                shutil.copyfileobj(src, out, 256 * 1024)
                out.flush(); os.fsync(out.fileno())
            os.fsync(parent)
        except BaseException:
            if target is not None: os.close(target)
            if created: os.unlink(destination.name, dir_fd=parent)
            raise
        finally:
            os.close(parent)

    def paste(self, aid):
        path = self.staging / (aid + ".png")
        try:
            with path.open("xb") as output:
                os.chmod(path, 0o600)
                try:
                    result = subprocess.run(child_command(["prlimit", "--fsize=" + str(MAX_FILE), "--cpu=5", "--", "wl-paste", "--no-newline", "--type", "image/png"]),
                        stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.DEVNULL, timeout=8)
                    if result.returncode: raise Failure("clipboard_unavailable")
                except (OSError, subprocess.TimeoutExpired):
                    raise Failure("clipboard_unavailable") from None
            return self.prepare(str(path), aid, name="Schowek.png", clipboard=True)
        finally:
            path.unlink(missing_ok=True)
