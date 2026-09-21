"""Abrupt exits at actual SQLite/outbox boundaries; only private test XDG."""
import os
from pathlib import Path
import sqlite3
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "services"))
from signal_paths import StoreLease
from signal_store import Store
from signal_outbox import Outbox

phase = sys.argv[1]
armed = False


class CrashConnection(sqlite3.Connection):
    def execute(self, sql, *args):
        if armed and sql == "COMMIT" and phase == "before":
            os._exit(90)
        result = super().execute(sql, *args)
        if armed and sql == "COMMIT" and phase == "after":
            os._exit(90)
        return result


connect = sqlite3.connect
sqlite3.connect = lambda *args, **kwargs: connect(*args, factory=CrashConnection, **kwargs)
os.umask(0o077)
lease = StoreLease()
assert lease.acquire()
store = Store(lease)
outbox = Outbox(store)
account = store.bind_account("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", "+12025550100")
cid = store.open_conversation(account, {"serviceId": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"})["conversationId"]
armed = True
op = outbox.enqueue(account, {"conversationId": cid, "text": "Synthetic transaction boundary"})
outbox.begin(account, op["operationId"])
os._exit(90)
