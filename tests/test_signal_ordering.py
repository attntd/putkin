"""Ordering follows local reception, independently of sender clocks and receipts."""
import unittest
import sqlite3
from contextlib import closing
from pathlib import Path
from unittest.mock import patch
from test_signal_history import HistoryTests, event, send_result
from signal_receipts import mark_visible
from signal_store import Store
from signal_outbox import Outbox
from signal_transport import Failure


class OrderingTests(unittest.TestCase):
    setUp = HistoryTests.setUp
    tearDown = HistoryTests.tearDown
    reopen = HistoryTests.reopen
    committed = HistoryTests.committed
    conversation = HistoryTests.conversation
    enqueue = HistoryTests.enqueue
    messages = HistoryTests.messages

    def test_later_received_earlier_sender_clock_stays_after_reply_even_after_ack(self):
        cid = self.conversation()
        self.store.receive(self.account, event(timestamp=self.now - 9000, body="First"))
        first = self.messages(cid)[0]
        op = self.enqueue(cid, "Reply")
        args, attempt = self.outbox.begin(self.account, op["operationId"])
        self.store.receive(self.account, event(timestamp=self.now - 1500, body="Received later"))
        self.outbox.finish(self.account, op["operationId"], attempt, send_result(self.now + 1000))
        rows = self.messages(cid)
        self.assertEqual([v["text"] for v in rows], ["Received later", "Reply", "First"])
        self.assertLess(rows[0]["sentTimestampMs"], rows[1]["sentTimestampMs"])
        order = [v["orderSequence"] for v in rows]
        self.assertEqual(order, sorted(order, reverse=True))
        self.store.receive(self.account, event(timestamp=self.now - 9000, body="First"))
        self.reopen()
        self.assertEqual([v["orderSequence"] for v in self.messages(cid)], order)
        marked = mark_visible(self.store, self.account, {"conversationId": cid, "throughMessageId": first["messageId"]})
        self.assertEqual(marked["messageIds"], [first["messageId"]])
        self.assertTrue(self.messages(cid)[0]["unread"])

    def test_equal_timestamps_page_by_reception_without_gaps_or_duplicates(self):
        cid = self.conversation()
        for index in range(9):
            stamp = self.now - (index // 2) * 1000
            self.store.receive(self.account, event("sent-sync" if index % 2 else "incoming", timestamp=stamp, body=str(index)))
        seen, cursor = [], None
        while True:
            page = self.store.page(self.account, {"conversationId": cid, "limit": 2, "before": cursor}, messages=True)
            seen.extend(v["text"] for v in page["items"])
            cursor = page["nextCursor"]
            if cursor is None:
                break
        self.assertEqual(seen, list(map(str, reversed(range(9)))))

    def test_real_v7_migration_is_atomic_and_preserves_history_drafts_and_pending_operations(self):
        cid = self.conversation()
        self.store.receive(self.account, event(timestamp=self.now - 1000, body='First'))
        first = self.messages(cid)[0]
        self.store.receive(self.account, event(timestamp=self.now - 2000, body='Later'))
        pending = self.outbox.mutations.enqueue(self.account, {'conversationId': cid,
            'messageId': first['messageId'], 'versionTimestampMs': first['versionTimestampMs'], 'emoji': '👍'}, 'reaction')
        self.store.set_draft(self.account, {'conversationId': cid, 'text': 'Saved draft', 'expectedRevision': 0})
        queued = self.enqueue(cid, 'Queued')
        before = [m['messageId'] for m in self.messages(cid)]
        snapshot = sqlite3.connect(':memory:')
        self.store.db.backup(snapshot)
        self.store.close(); self.store = None
        path = self.lease.data / 'history.sqlite3'
        path.unlink()
        # Construct a real old database from the shipped historical schemas.
        with closing(sqlite3.connect(path)) as old, old:
            sources = Path(__file__).resolve().parents[1] / 'services'
            for name in ['signal_schema.sql'] + [f'signal_schema_v{n}.sql' for n in range(2, 8)]:
                old.executescript((sources / name).read_text())
            for (table,) in old.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall():
                columns = [v[1] for v in old.execute(f'PRAGMA table_info({table})')]
                fields = ','.join(columns)
                data = snapshot.execute(f'SELECT {fields} FROM {table} ORDER BY rowid').fetchall()
                if table == 'store_metadata':
                    data = [v for v in data if v[0] != 'message-order']
                old.executemany(f'INSERT INTO {table}({fields}) VALUES({",".join("?" for _ in columns)})', data)
        snapshot.close()
        connect = sqlite3.connect
        def deny(*args, **kwargs):
            db = connect(*args, **kwargs)
            db.set_authorizer(lambda action, name, *_: sqlite3.SQLITE_DENY
                if action == sqlite3.SQLITE_CREATE_TABLE and name == 'message_pins' else sqlite3.SQLITE_OK)
            return db
        with patch('signal_store.sqlite3.connect', deny):
            with self.assertRaisesRegex(Failure, 'storage_error'):
                Store(self.lease)
        with closing(connect(path)) as old:
            self.assertEqual(old.execute('PRAGMA user_version').fetchone()[0], 7)
            self.assertNotIn('order_sequence', [c[1] for c in old.execute('PRAGMA table_info(messages)')])
            self.assertEqual(old.execute('SELECT kind FROM interaction_outbox').fetchone()[0], 'reaction')
        self.store = Store(self.lease, self.committed, lambda: self.now)
        self.outbox = Outbox(self.store)
        self.assertEqual(self.store.db.execute('PRAGMA user_version').fetchone()[0], 8)
        self.assertEqual(self.store.db.execute('PRAGMA integrity_check').fetchone()[0], 'ok')
        self.assertEqual([m['messageId'] for m in self.messages(cid)], before)
        self.assertEqual(self.outbox.status(self.account, pending['operationId'])['state'], 'queued')
        self.assertEqual(self.outbox.status(self.account, queued['operationId'])['state'], 'queued')
        self.assertEqual(self.store.draft(self.account, cid)['text'], 'Saved draft')
        self.store.receive(self.account, event(timestamp=self.now - 5000, body='After migration'))
        self.assertEqual(self.messages(cid)[0]['text'], 'After migration')


del HistoryTests

if __name__ == "__main__":
    unittest.main()
