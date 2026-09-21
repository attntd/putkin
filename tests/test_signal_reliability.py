"""S11 fault/overload/privacy regression. Never uses a real Signal account."""
import asyncio
from contextlib import closing
import json
import os
from pathlib import Path
import signal
import sqlite3
import time
import unittest
from unittest.mock import patch

import test_signal_history as history
from signal_backend import Output
from signal_transport import MAX_FRAME


class ReliabilityTests(unittest.TestCase):
    setUp = history.BridgeHistoryTests.setUp
    tearDown = history.BridgeHistoryTests.tearDown
    start = history.BridgeHistoryTests.start
    request = history.BridgeHistoryTests.request
    operation = history.BridgeHistoryTests.operation

    def records(self, kind):
        return [r for r in map(json.loads, self.record.read_text().splitlines()) if r['kind'] == kind]

    def test_identity_failure_is_failed_without_trust_or_automatic_resend(self):
        client = self.start(receiveEvents=[], sendResult=history.send_result(kind='IDENTITY_FAILURE'))
        client.state('ready')
        cid = self.request(client, 'conversation.open', {'kind': 'direct', 'serviceId': history.PEER})['conversationId']
        op = self.request(client, 'message.send', {'conversationId': cid, 'text': 'S11_IDENTITY_BODY'})
        status = self.operation(client, op['operationId'], 'failed')
        self.assertEqual(status['recipients'][0]['result_type'], 'IDENTITY_FAILURE')
        self.assertTrue(status['safeRetry'])  # eligibility for an explicit user action only
        time.sleep(.15)
        self.assertEqual(len(self.records('send')), 1)
        self.assertNotIn('trust', self.record.read_text())
        client.close()
        client = self.start(receiveEvents=[])
        client.state('ready')
        self.assertEqual(self.request(client, 'operation.status', {'operationId': op['operationId']})['state'], 'failed')
        self.assertEqual(len(self.records('send')), 1)

    def test_rpc_private_error_never_enters_logs_status_or_database(self):
        client = self.start(receiveEvents=[], sendError=True)
        client.state('ready')
        cid = self.request(client, 'conversation.open', {'kind': 'direct', 'serviceId': history.PEER})['conversationId']
        op = self.request(client, 'message.send', {'conversationId': cid, 'text': 'S11_PRIVATE_BODY'})
        status = self.operation(client, op['operationId'], 'unknown')
        self.assertFalse(status['safeRetry'])
        self.assertNotIn('SYNTHETIC_PRIVATE_ERROR', json.dumps(status))
        client.process.stdin.close(); client.process.wait(timeout=8)
        stderr = client.process.stderr.read()
        self.assertEqual(stderr, b'')
        self.assertNotIn('S11_PRIVATE_BODY', self.record.read_text())
        self.assertNotIn('SYNTHETIC_PRIVATE_ERROR', self.record.read_text())
        path = Path(self.env['XDG_DATA_HOME'])/'putkin/signal'
        for db in path.glob('history.sqlite3*'):
            self.assertNotIn(b'SYNTHETIC_PRIVATE_ERROR', db.read_bytes())
        for item in path.rglob('*'):
            self.assertEqual(item.stat().st_mode & 0o077, 0, item.name)

    def test_burst_out_of_order_duplicate_receive_commits_once_and_keeps_one_subscription(self):
        events = [history.event(timestamp=1790000000000+i, body=f'S11_BURST_{i}') for i in range(400)]
        client = self.start(receiveEvents=list(reversed(events))+events)
        client.state('ready', seconds=25)
        cid = self.request(client, 'conversation.open', {'kind': 'direct', 'serviceId': history.PEER})['conversationId']
        cursor, mids, stamps = None, set(), []
        for _ in range(8):
            page = self.request(client, 'messages.page', {'conversationId': cid, 'before': cursor, 'limit': 50})
            self.assertEqual(len(page['items']), 50)
            for row in page['items']:
                self.assertNotIn(row['messageId'], mids)
                mids.add(row['messageId']); stamps.append(row['sentTimestampMs'])
            cursor = page['nextCursor']
        self.assertIsNone(cursor)
        self.assertEqual(stamps, sorted(set(stamps), reverse=True))
        self.assertEqual(len(self.records('subscribe')), 1)
        metrics = self.request(client, 'test.metrics')
        self.assertLessEqual(metrics['rpcPending'], 8)
        self.assertLessEqual(metrics['outputBytes'], 4*MAX_FRAME)
        client.close()
        client = self.start(receiveEvents=[]); client.state('ready')
        path = Path(self.env['XDG_DATA_HOME'])/'putkin/signal/history.sqlite3'
        with closing(sqlite3.connect(path)) as db:
            self.assertEqual(db.execute('SELECT count(*) FROM messages').fetchone()[0], 400)
            self.assertEqual(db.execute('PRAGMA integrity_check').fetchone()[0], 'ok')

    def test_revoked_account_after_cli_death_preserves_history_and_disables_send(self):
        revoked = self.base/'revoked'
        client = self.start(revokedFile=str(revoked))
        client.state('ready')
        cid = self.request(client, 'conversations.page')['items'][0]['conversationId']
        revoked.touch()
        os.kill(self.records('start')[-1]['pid'], signal.SIGKILL)
        state = client.state('idle', seconds=15)
        self.assertEqual(state['data']['accountState'], 'relinkRequired')
        self.assertEqual(state['data']['errorCode'], 'relink_required')
        client.send('send-revoked', 'message.send', {'conversationId': cid, 'text': 'Must not dispatch'})
        self.assertEqual(client.reply('send-revoked')['error']['code'], 'account_unlinked')
        self.assertEqual(self.records('send'), [])
        self.assertEqual(len(self.request(client, 'messages.page', {'conversationId': cid})['items']), 1)


class OutputPressureTests(unittest.IsolatedAsyncioTestCase):
    async def test_stalled_reader_has_four_megabyte_bound_and_requests_shutdown(self):
        read_fd, write_fd = os.pipe()
        stop = asyncio.Event()
        try:
            class Sink:
                def fileno(self): return write_fd
            with patch('signal_backend.sys.stdout', Sink()):
                output = Output(stop)
            # No yielding: simulate a pipe consumer that does not drain at all.
            for _ in range(100): output.emit({'synthetic': 'x'*(MAX_FRAME//2)})
            self.assertTrue(stop.is_set())
            self.assertLessEqual(len(output.buffer), 4*MAX_FRAME)
            output.flush()  # a nonblocking partial write must not hang teardown
            self.assertLessEqual(len(output.buffer), 4*MAX_FRAME)
        finally:
            asyncio.get_running_loop().remove_writer(write_fd)
            os.close(read_fd); os.close(write_fd)
