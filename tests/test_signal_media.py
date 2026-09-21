"""S07 synthetic media, actual file workers, SQLite and bridge; no Signal account."""
import copy
import errno
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import time
import unittest
import uuid
import wave
import zlib
from unittest.mock import patch

import test_signal_history as history
from signal_media import MAX_FILE, local_path, verify_cli
from signal_transport import Failure


def png(path, width=96, height=64):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress((b"\0" + b"\x89\xb4\xfa" * width) * height)) + chunk(b"IEND", b""))
    path.chmod(0o600)
    return path


def fixtures(base):
    image = png(base / "zdjęcie ; $ nic.png")
    sound = base / "audio.wav"
    with wave.open(str(sound), "wb") as out:
        out.setparams((1, 2, 8000, 800, "NONE", "not compressed")); out.writeframes(b"\0\0" * 800)
    movie = base / "film.mp4"
    subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=blue:s=96x64:d=0.2", "-threads", "1", "-y", str(movie)], check=True)
    document = base / "dokument.txt"; document.write_text("Syntetyczny dokument 🐈\n")
    for p in (sound, movie, document): p.chmod(0o600)
    return [image, movie, sound, document]


def attachment_event(path, mime, timestamp=1790000010000, name="attachment", **fields):
    wire = history.event(name, timestamp=timestamp)
    env = wire["params"]["result"]["envelope"]
    data = env.get("dataMessage") or env["syncMessage"]["sentMessage"]
    data.update(message="Media syntetyczne", attachments=[{"id": path.name, "contentType": mime,
        "size": path.stat().st_size, "filename": "../../" + path.name, "isVoiceNote": False}], **fields)
    return wire


class MediaTests(unittest.TestCase):
    setUp = history.HistoryTests.setUp
    tearDown = history.HistoryTests.tearDown
    committed = history.HistoryTests.committed
    reopen = history.HistoryTests.reopen
    conversation = history.HistoryTests.conversation
    messages = history.HistoryTests.messages
    enqueue = history.HistoryTests.enqueue

    def prepare(self, path, **kwargs):
        return self.store.media.prepare(str(path), str(uuid.uuid4()), **kwargs)

    def stage(self, cid, paths):
        media = self.store.media
        prepared = []
        try:
            for path in paths:
                p = self.prepare(path); prepared.append(p); media.active.add(p["id"])
            return media.stage(self.account, cid, prepared)["attachments"]
        finally:
            media.active.difference_update(p["id"] for p in prepared)
            media.gc()

    def import_all(self):
        media = self.store.media
        for row in media.pending(self.account):
            aid = row["attachment_id"]; media.active.add(aid)
            try:
                p = media.prepare(str(media.source(row["cli_id"])), aid, name=row["filename"], declared=row["content_type"], size=row["size_bytes"])
                media.imported(self.account, aid, p)
            finally: media.active.remove(aid)
            media.release_cli(row["cli_id"])
        media.gc()

    def test_multiple_media_draft_send_and_restart_survive_original_removal(self):
        cid = self.conversation(); paths = fixtures(self.base)
        items = self.stage(cid, paths)
        self.assertEqual(len(items), 4)
        self.assertTrue(all(i["state"] == "ready" and not i["errorCode"] for i in items), items)
        image = next(i for i in items if i["content_type"] == "image/png")
        self.assertTrue(image["thumbnail"] and image["preview"])
        for path in paths: path.unlink()
        self.reopen()
        self.assertEqual(len(self.store.draft(self.account, cid)["attachments"]), 4)
        op = self.enqueue(cid, "tekst + pliki", attachmentIds=[i["attachment_id"] for i in items])
        params, attempt = self.outbox.begin(self.account, op["operationId"])
        self.assertEqual(len(params["attachment"]), 4)
        self.assertTrue(all(Path(p).is_file() for p in params["attachment"]))
        self.assertNotIn("voiceNote", params)
        self.outbox.finish(self.account, op["operationId"], attempt, history.send_result())
        self.reopen()
        self.assertEqual(self.messages(cid)[0]["status"], "sent")
        self.assertEqual(len(self.messages(cid)[0]["attachments"]), 4)
        self.assertEqual(self.store.draft(self.account, cid)["attachments"], [])

    def test_incoming_phone_sync_shared_refs_and_retention_hook(self):
        cli = self.lease.data / "cli/attachments"; cli.mkdir(mode=0o700, parents=True)
        paths = fixtures(cli)
        mimes = ("image/png", "video/mp4", "audio/x-wav", "text/plain")
        for i, (path, mime) in enumerate(zip(paths, mimes)):
            # CLI filenames are opaque IDs, unlike display names.
            target = path.with_name(str(i) + path.suffix); path.rename(target); paths[i] = target
            self.store.receive(self.account, attachment_event(target, mime, timestamp=1790000010000+i))
        self.store.receive(self.account, attachment_event(paths[0], "image/png", timestamp=1790000010010, name="sent-sync"))
        self.import_all(); self.reopen()
        cid = self.conversation(); rows = self.messages(cid)
        self.assertEqual(len(rows), 5)
        self.assertTrue(all(r["attachments"][0]["state"] == "ready" for r in rows))
        self.assertEqual(list(cli.iterdir()), [])
        image_rows = [r for r in rows if r["attachments"][0]["content_type"] == "image/png"]
        aid = image_rows[0]["attachments"][0]["attachment_id"]
        original = local_path(image_rows[0]["attachments"][0]["url"])
        with self.store.transaction(): self.store.redact_message(self.account, image_rows[0]["messageId"], "deleted")
        self.assertTrue(original.exists())
        with self.store.transaction(): self.store.redact_message(self.account, image_rows[1]["messageId"], "deleted")
        self.assertFalse(original.exists())
        self.assertFalse(list(self.store.media.cache.glob(aid + "*")))

    def test_reject_zero_large_mime_executable_and_paths(self):
        empty = self.base / "empty"; empty.touch()
        huge = self.base / "huge"
        with huge.open("wb") as f: f.truncate(MAX_FILE + 1)
        executable = self.base / "file.png"; executable.write_bytes(b"#!/bin/sh\necho unsafe\n")
        plain = self.base / "plain.txt"; plain.write_text("document")
        symlink = self.base / "link"; symlink.symlink_to(plain)
        hardlink = self.base / "hard"; os.link(plain, hardlink)
        for path in (empty, huge, executable, symlink, hardlink):
            with self.assertRaises(Failure, msg=str(path)): self.prepare(path)
        hardlink.unlink()
        with self.assertRaisesRegex(Failure, "attachment_mime"): self.prepare(plain, declared="image/png")
        for source in ("https://example.com/a.png", "file://host/etc/passwd", str(self.base / ".." / "outside")):
            with self.assertRaises(Failure): self.store.media.prepare(source, str(uuid.uuid4()))
        for source in ("../../outside", "..", "a/b"):
            with self.assertRaises(Failure): self.store.media.source(source)
        self.assertEqual(list(self.store.media.staging.iterdir()), [])
        self.assertEqual(list(self.store.media.originals.iterdir()), [])

    def test_unknown_upload_failure_retry_cancel_and_loss(self):
        cid = self.conversation(); path = png(self.base / "image.png")
        items = self.stage(cid, [path]); op = self.enqueue(cid, "", attachmentIds=[items[0]["attachment_id"]])
        args, attempt = self.outbox.begin(self.account, op["operationId"])
        self.outbox.finish(self.account, op["operationId"], attempt, None, {"code": -1})
        self.reopen()
        self.assertEqual(self.outbox.status(self.account, op["operationId"])["state"], "unknown")
        with self.assertRaisesRegex(Failure, "retry_unsafe"): self.outbox.retry(self.account, op["operationId"])
        with self.assertRaisesRegex(Failure, "operation_not_queued"): self.outbox.cancel(self.account, op["operationId"])
        self.assertTrue(Path(args["attachment"][0]).exists())
        items = self.stage(cid, [path]); op2 = self.enqueue(cid, "", attachmentIds=[items[0]["attachment_id"]])
        self.outbox.cancel(self.account, op2["operationId"])
        self.assertFalse(local_path(items[0]["url"]).exists())
        items = self.stage(cid, [path]); op3 = self.enqueue(cid, "", attachmentIds=[items[0]["attachment_id"]])
        local_path(items[0]["url"]).unlink()
        with self.assertRaisesRegex(Failure, "attachment_unavailable"): self.outbox.begin(self.account, op3["operationId"])
        self.assertEqual(self.outbox.status(self.account, op3["operationId"])["state"], "queued")

    def test_draft_remove_quota_disk_full_and_startup_orphans(self):
        cid = self.conversation(); path = png(self.base / "image.png")
        items = self.stage(cid, [path]); aid = items[0]["attachment_id"]
        self.store.media.remove(self.account, cid, aid)
        self.assertFalse(local_path(items[0]["url"]).exists())
        with patch("signal_media.MAX_STORE", 1), self.assertRaisesRegex(Failure, "media_quota"): self.prepare(path)
        with patch("signal_media.os.fsync", side_effect=OSError(errno.ENOSPC, "full")), self.assertRaisesRegex(Failure, "media_disk_full"): self.prepare(path)
        orphan = self.store.media.staging / (str(uuid.uuid4()) + ".part"); orphan.write_bytes(b"partial")
        self.reopen(); self.assertFalse(orphan.exists())

    def test_save_explicit_no_overwrite_no_symlink_and_failure_cleanup(self):
        cid = self.conversation(); item = self.stage(cid, [png(self.base / "image.png")])[0]
        dest = self.base / "user-saved.png"
        self.store.media.save(item["url"], str(dest))
        self.assertEqual(dest.read_bytes(), local_path(item["url"]).read_bytes())
        with self.assertRaises(FileExistsError): self.store.media.save(item["url"], str(dest))
        failed = self.base / "failed.png"
        with patch("signal_media.shutil.copyfileobj", side_effect=OSError(errno.ENOSPC, "full")), self.assertRaises(OSError):
            self.store.media.save(item["url"], str(failed))
        self.assertFalse(failed.exists())
        self.store.media.remove(self.account, cid, item["attachment_id"])
        self.assertTrue(dest.exists())

    def test_view_once_creates_no_managed_copies(self):
        path = png(self.base / "image.png")
        for i, fields in enumerate(({"viewOnce": True},)):
            self.store.receive(self.account, attachment_event(path, "image/png", timestamp=1790000010100+i, **fields))
        self.assertFalse(self.store.media.pending(self.account))
        self.assertTrue(all(not m["attachments"] for m in self.messages(self.conversation())))
        self.assertEqual(list(self.store.media.originals.iterdir()), [])

    def test_corrupt_decoder_is_explicit_and_no_thumbnail(self):
        path = png(self.base / "broken.png"); path.write_bytes(path.read_bytes()[:40])
        prepared = self.prepare(path)
        self.assertTrue(prepared["error"])
        self.assertFalse(prepared["thumbnail"] or prepared["preview"])

    def test_dimensions_source_change_permissions_and_synthetic_clipboard(self):
        large = png(self.base / "dimensions.png", 5001, 4000)
        p = self.prepare(large)
        self.assertEqual(p["error"], "media_dimensions")
        self.assertFalse(p["thumbnail"] or p["preview"])
        path = self.base / "change.txt"; path.write_text("original")
        fsync = os.fsync
        changed = False
        def mutate(fd):
            nonlocal changed
            fsync(fd)
            if not changed:
                changed = True; path.write_text("modified")
        with patch("signal_media.os.fsync", mutate), self.assertRaisesRegex(Failure, "attachment_changed"):
            self.prepare(path)
        path.chmod(0)
        with self.assertRaisesRegex(Failure, "attachment_unavailable"): self.prepare(path)
        path.chmod(0o600)
        # A fake clipboard executable emits an actual PNG through stdout. All
        # preparation, sniffing, streaming and thumbnail code remains real.
        image = png(self.base / "clip.png")
        bin_dir = self.base / "bin"; bin_dir.mkdir()
        executable = bin_dir / "wl-paste"
        executable.write_text("#!/usr/bin/python3\nimport sys\nsys.stdout.buffer.write(bytes.fromhex(" + repr(image.read_bytes().hex()) + "))\n")
        executable.chmod(0o700)
        with patch.dict(os.environ, {"PATH": str(bin_dir) + ":/usr/bin:/bin"}):
            result = self.store.media.paste(str(uuid.uuid4()))
        self.assertEqual(result["mime"], "image/png")
        self.assertTrue(result["thumbnail"])
        self.assertEqual(list(self.store.media.staging.iterdir()), [])

    def test_known_upload_failure_retry_and_thumbnail_regeneration_failure(self):
        cid = self.conversation(); path = png(self.base / "image.png")
        items = self.stage(cid, [path])
        op = self.enqueue(cid, "", attachmentIds=[items[0]["attachment_id"]])
        _, attempt = self.outbox.begin(self.account, op["operationId"])
        self.outbox.finish(self.account, op["operationId"], attempt, history.send_result(kind="UNREGISTERED_FAILURE"))
        self.assertTrue(self.outbox.status(self.account, op["operationId"])["safeRetry"])
        self.assertEqual(self.outbox.retry(self.account, op["operationId"])["state"], "queued")
        args, attempt = self.outbox.begin(self.account, op["operationId"])
        self.assertTrue(Path(args["attachment"][0]).exists())
        self.outbox.finish(self.account, op["operationId"], attempt, history.send_result())
        with self.store.transaction(): self.store.redact_message(self.account, op["messageId"], "deleted")
        self.assertFalse(local_path(items[0]["thumbnail"]).exists())

    def test_sent_sync_before_and_after_send_preserves_local_id_without_conflict_or_cli_leak(self):
        cid = self.conversation(); path = png(self.base / "image.png")
        cli = self.lease.data / "cli/attachments"; cli.mkdir(mode=0o700, parents=True)
        for before in (True, False):
            items = self.stage(cid, [path]); timestamp = 1790000400000 + int(before)
            op = self.enqueue(cid, "Media syntetyczne", attachmentIds=[items[0]["attachment_id"]])
            _, attempt = self.outbox.begin(self.account, op["operationId"])
            incoming = png(cli / (str(timestamp) + ".png"))
            wire = attachment_event(incoming, "image/png", timestamp=timestamp, name="sent-sync")
            if before: self.store.receive(self.account, wire)
            self.outbox.finish(self.account, op["operationId"], attempt, history.send_result(timestamp=timestamp))
            if not before: self.store.receive(self.account, wire)
            row = self.store.message(self.account, op["messageId"])
            self.assertFalse(row["conflict"])
            self.assertEqual(len(row["attachments"]), 1)
            # A sync after the local result never inserts another attachment
            # row, but the known redundant CLI copy must still be released.
            self.assertFalse(incoming.exists())


class MediaBridgeTests(unittest.TestCase):
    setUp = history.BridgeHistoryTests.setUp
    tearDown = history.BridgeHistoryTests.tearDown
    start = history.BridgeHistoryTests.start
    request = history.BridgeHistoryTests.request
    operation = history.BridgeHistoryTests.operation

    def test_real_bridge_stages_sends_receives_and_restarts_media(self):
        client = self.start(receiveEvents=[])
        account = client.state("ready")["data"]["accountId"]
        cid = self.request(client, "conversation.open", {"serviceId": history.PEER})["conversationId"]
        scope = {"accountId": account, "conversationId": cid}
        paths = fixtures(self.base)
        items = self.request(client, "attachment.stage", {**scope, "paths": [p.as_uri() for p in paths]})["attachments"]
        self.assertTrue(all(not i["errorCode"] for i in items), items)
        op = self.request(client, "message.send", {**scope, "text": "Media", "attachmentIds": [a["attachment_id"] for a in items]})
        self.operation(client, op["operationId"], "sent")
        cli = Path(self.env["XDG_DATA_HOME"]) / "putkin/signal/cli/attachments"; cli.mkdir(mode=0o700, exist_ok=True)
        path = png(cli / "inbound.png")
        self.request(client, "test.echo", {"receive": attachment_event(path, "image/png")})
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            rows = self.request(client, "messages.page", scope)["items"]
            incoming = [r for r in rows if r["direction"] == "incoming"]
            if incoming and incoming[0]["attachments"][0]["state"] == "ready": break
            time.sleep(.05)
        self.assertEqual(incoming[0]["attachments"][0]["state"], "ready")
        self.assertFalse(path.exists())
        client.close(); client = self.start(receiveEvents=[]); client.state("ready")
        self.assertEqual(len(self.request(client, "messages.page", scope)["items"]), 2)
        self.assertEqual(len([r for r in map(json.loads, self.record.read_text().splitlines()) if r["kind"] == "send"]), 1)

    def test_cancel_preparation_and_foreign_account_leave_no_files(self):
        client = self.start(receiveEvents=[]); account = client.state("ready")["data"]["accountId"]
        cid = self.request(client, "conversation.open", {"serviceId": history.PEER})["conversationId"]
        path = png(self.base / "image.png", 1024, 1024)
        client.send("foreign", "attachment.stage", {"accountId": str(uuid.uuid4()), "conversationId": cid, "paths": [str(path)]})
        self.assertEqual(client.reply("foreign")["error"]["code"], "account_mismatch")
        client.send("stage", "attachment.stage", {"accountId": account, "conversationId": cid, "paths": [str(path)]})
        client.send("cancel", "request.cancel", {"id": "stage"})
        self.assertTrue(client.reply("cancel")["result"]["accepted"])
        self.assertEqual(client.reply("stage")["error"]["code"], "cancelled")
        self.assertEqual(self.request(client, "draft.get", {"conversationId": cid})["attachments"], [])
        root = Path(self.env["XDG_DATA_HOME"]) / "putkin/signal"
        self.assertFalse(list((root / "media").iterdir()))
        self.assertFalse(list((root / "staging").iterdir()))


if __name__ == "__main__": unittest.main()
