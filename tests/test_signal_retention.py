"""S09: real SQLite, controlled wall clock, deletion graphs and RPC boundaries."""
import asyncio
import copy
import errno
import json
import os
from pathlib import Path
import time
import threading
import sys
import test_signal_media as media_tests
import unittest
from unittest.mock import patch

import test_signal_history as history
import test_signal_interactions as interaction
import signal_retention as retention
import signal_receipts
from signal_transport import Failure

T = 1790000000000


def disappearing(*, phone=False, stamp=T, start=None, seconds=30, body='S09_PRIVATE_MARKER', group=None):
    wire = history.event('sent-sync' if phone else 'incoming', timestamp=stamp, body=body, group=group)
    env = wire['params']['result']['envelope']
    data = env['syncMessage']['sentMessage'] if phone else env['dataMessage']
    data['expiresInSeconds'] = seconds
    if start is not None:
        data['expirationStartTimestamp'] = start
    return wire


def deletion(stamp=T, *, target=T, phone=False, group=None, author=None):
    wire = history.event('sent-sync' if phone else 'incoming', timestamp=stamp, group=group, author=author)
    env = wire['params']['result']['envelope']
    data = env['syncMessage']['sentMessage'] if phone else env['dataMessage']
    data.update(message=None, remoteDelete={'timestamp': target})
    return wire


class RetentionTests(unittest.TestCase):
    setUp = history.HistoryTests.setUp
    tearDown = history.HistoryTests.tearDown
    committed = history.HistoryTests.committed
    reopen = history.HistoryTests.reopen
    conversation = history.HistoryTests.conversation
    messages = history.HistoryTests.messages
    enqueue = history.HistoryTests.enqueue

    def clean(self):
        with self.store.transaction():
            self.store.cleanup()

    def msg(self, mid):
        return self.store.message(self.account, mid)

    def assert_purged(self, marker='S09_PRIVATE_MARKER'):
        self.assertNotIn(marker, '\n'.join(self.store.db.iterdump()))
        for suffix in ('', '-wal'):
            path = self.lease.data / ('history.sqlite3' + suffix)
            if path.exists():
                self.assertNotIn(marker.encode(), path.read_bytes())

    def test_incoming_timer_starts_on_read_and_earliest_phone_sync_wins(self):
        self.now = T + 1000
        self.store.receive(self.account, disappearing())
        cid = self.conversation(); mid = self.messages(cid)[0]['messageId']
        self.assertIsNone(self.msg(mid)['expiresAtMs'])
        self.now += 10000
        signal_receipts.mark_visible(self.store, self.account, {'conversationId': cid, 'messageIds': [mid]})
        self.assertEqual(self.msg(mid)['expiresAtMs'], self.now + 30000)
        wire = history.event('read-sync')
        env = wire['params']['result']['envelope']
        env['timestamp'] = T + 5000
        env['syncMessage']['readMessages'] = [{'senderUuid': history.PEER, 'timestamp': T}]
        self.store.receive(self.account, wire)
        self.assertEqual(self.msg(mid)['expiresAtMs'], T + 35000)
        env['timestamp'] = T + 20000
        self.store.receive(self.account, wire)
        self.assertEqual(self.msg(mid)['expiresAtMs'], T + 35000)
        self.now = T + 35000; self.clean(); self.assert_purged()
        self.assertEqual(self.msg(mid)['kind'], 'expired')

    def test_read_before_message_and_phone_sent_expire_before_publication(self):
        wire = history.event('read-sync'); env = wire['params']['result']['envelope']
        env['timestamp'] = T + 1000
        env['syncMessage']['readMessages'] = [{'senderUuid': history.PEER, 'timestamp': T}]
        self.store.receive(self.account, wire)
        self.changes.clear()
        self.store.receive(self.account, disappearing())
        self.store.receive(self.account, disappearing(phone=True, stamp=T + 1, start=T + 1000))
        self.assertTrue(all(m['kind'] == 'expired' for m in self.messages(self.conversation())))
        self.assertFalse(any(n == 'message.received' for n, _ in self.changes))
        self.assert_purged()

    def test_outgoing_local_and_note_start_after_send_not_enqueue(self):
        for kind, target in (('direct', history.PEER), ('note', history.OWN)):
            cid = self.conversation(kind, target)
            with self.store.transaction():
                retention.configure(self.store, self.account, cid, 30, self.now)
            op = self.enqueue(cid, 'S09_PRIVATE_MARKER')
            self.assertIsNone(self.msg(op['messageId'])['expirationStartMs'])
            _, attempt = self.outbox.begin(self.account, op['operationId'])
            self.outbox.finish(self.account, op['operationId'], attempt, history.send_result(self.now, recipient=target))
            self.assertEqual(self.msg(op['messageId'])['expiresAtMs'], self.now + 30000)
        self.now += 30000; self.reopen(); self.assert_purged()

    def test_actual_cli_timer_overrides_racing_preflight_and_partial_send_expires(self):
        cid = self.conversation()
        op = self.enqueue(cid, 'S09_PRIVATE_MARKER')
        _, attempt = self.outbox.begin(self.account, op['operationId'])
        self.outbox.require_timer = True
        result = history.send_result(self.now)
        result['expiresInSeconds'] = 1
        self.outbox.finish(self.account, op['operationId'], attempt, result)
        self.assertEqual(self.msg(op['messageId'])['expiresAtMs'], self.now + 1000)
        self.now += 1000; self.clean(); self.assert_purged()
        cid = self.conversation('group', history.GROUP)
        op = self.enqueue(cid, 'S09_PRIVATE_MARKER')
        _, attempt = self.outbox.begin(self.account, op['operationId'])
        result = history.send_result(self.now)
        result['expiresInSeconds'] = 1
        result['results'].append({'recipientAddress': {'uuid': history.OTHER}, 'type': 'NETWORK_FAILURE'})
        self.outbox.finish(self.account, op['operationId'], attempt, result)
        self.assertEqual(self.outbox.status(self.account, op['operationId'])['state'], 'unknown')
        self.now += 1000; self.clean(); self.assert_purged()

    def test_conversation_changes_edits_duplicates_do_not_extend_existing_deadline(self):
        self.now = T + 1000
        wire = disappearing(phone=True, start=T)
        self.store.receive(self.account, wire)
        cid = self.conversation(); mid = self.messages(cid)[0]['messageId']
        with self.store.transaction():
            retention.configure(self.store, self.account, cid, 604800, T + 2000)
            retention.configure(self.store, self.account, cid, 0, T + 3000)
        self.store.receive(self.account, interaction.edit(phone=True, body='S09_PRIVATE_MARKER_EDIT'))
        self.store.receive(self.account, wire)
        self.assertEqual(self.msg(mid)['expiresAtMs'], T + 30000)
        self.assertEqual(self.store.conversation(self.account, cid)['expiration_seconds'], 0)
        self.now = T + 30000; self.clean(); self.assert_purged()

    def test_delete_before_target_closes_reverse_edit_graph_and_replay(self):
        for group in (None, history.GROUP):
            cid = self.conversation('group', group) if group else self.conversation()
            self.store.receive(self.account, interaction.edit(T + 1000, T + 2000, 'S09_PRIVATE_MARKER', group=group))
            self.store.receive(self.account, deletion(T + 3000, target=T + 2000, group=group))
            self.assert_purged()
            self.store.receive(self.account, interaction.edit(T, T + 1000, 'S09_PRIVATE_MARKER', group=group))
            self.store.receive(self.account, history.event(body='S09_PRIVATE_MARKER', group=group))
            self.reopen()
            self.store.receive(self.account, interaction.edit(T + 2000, T + 4000, 'S09_PRIVATE_MARKER', group=group))
            self.assert_purged()
            self.assertEqual(self.messages(cid)[0]['kind'], 'deleted')

    def test_wrong_author_conversation_and_account_do_not_delete_other_message(self):
        self.store.receive(self.account, history.event(body='keep'))
        self.store.receive(self.account, deletion(author=history.OTHER))
        self.store.receive(self.account, deletion(group=history.GROUP))
        self.assertEqual(self.messages(self.conversation())[0]['text'], 'keep')

    def test_local_delete_never_enqueues_remote_and_prevents_send_retry(self):
        cid = self.conversation(); op = self.enqueue(cid)
        retention.local_delete(self.store, self.account, {'conversationId': cid, 'messageId': op['messageId']})
        self.assertEqual(self.messages(cid), [])
        self.assertIsNone(self.outbox.next(self.account))
        self.assertEqual(self.store.db.execute('SELECT COUNT(*) FROM interaction_outbox').fetchone()[0], 0)
        with self.assertRaises(Failure): self.outbox.retry(self.account, op['operationId'])

    def test_remote_delete_is_durable_validated_and_uses_actual_rpc(self):
        cid = self.conversation(); op = self.enqueue(cid)
        _, attempt = self.outbox.begin(self.account, op['operationId'])
        self.outbox.finish(self.account, op['operationId'], attempt, history.send_result(self.now))
        message = self.msg(op['messageId'])
        params = {'conversationId': cid, 'messageId': message['messageId'], 'versionTimestampMs': self.now}
        delete = self.outbox.mutations.enqueue(self.account, params, 'delete')
        self.assertEqual(self.outbox.rpc_method(self.account, delete['operationId']), 'remoteDelete')
        rpc, attempt = self.outbox.begin(self.account, delete['operationId'])
        self.assertEqual(rpc, {'account': '+12025550100', 'recipient': [history.PEER], 'targetTimestamp': self.now})
        self.outbox.finish(self.account, delete['operationId'], attempt, history.send_result(self.now + 1))
        self.assertEqual(self.msg(op['messageId'])['kind'], 'deleted')
        self.assertFalse(self.outbox.status(self.account, delete['operationId'])['safeRetry'])

    def test_remote_delete_limit_incoming_denial_partial_and_restart_unknown(self):
        self.store.receive(self.account, history.event())
        cid = self.conversation(); incoming = self.messages(cid)[0]
        params = {'conversationId': cid, 'messageId': incoming['messageId'], 'versionTimestampMs': T}
        with self.assertRaisesRegex(Failure, 'delete_unavailable'):
            self.outbox.mutations.enqueue(self.account, params, 'delete')
        self.store.receive(self.account, history.event('sent-sync', timestamp=self.now))
        mid = self.messages(cid)[0]['messageId']; stamp = self.now
        params.update(messageId=mid, versionTimestampMs=stamp)
        self.now += retention.DELETE_WINDOW
        with self.assertRaisesRegex(Failure, 'delete_unavailable'):
            self.outbox.mutations.enqueue(self.account, params, 'delete')
        self.now = stamp + 1
        op = self.outbox.mutations.enqueue(self.account, params, 'delete')
        self.outbox.begin(self.account, op['operationId']); self.reopen()
        self.assertEqual(self.outbox.status(self.account, op['operationId'])['state'], 'unknown')
        with self.assertRaises(Failure): self.outbox.retry(self.account, op['operationId'])

    def test_quotes_versions_composition_and_mutations_are_scrubbed(self):
        self.store.receive(self.account, history.event(body='S09_PRIVATE_MARKER'))
        cid = self.conversation(); mid = self.messages(cid)[0]['messageId']
        op = self.enqueue(cid, 'separate message', quoteMessageId=mid)
        self.store.set_draft(self.account, {'conversationId': cid, 'text': 'draft', 'expectedRevision': 0, 'composition': {'quoteMessageId': mid}})
        self.store.receive(self.account, deletion(T + 3000))
        self.assert_purged()
        self.assertEqual(self.msg(op['messageId'])['quote']['text'], '')
        self.assertNotIn('quoteMessageId', self.store.draft(self.account, cid).get('composition', {}))
        self.assertEqual(self.store.draft(self.account, cid)['text'], 'draft')
        # A late quoted reply must not reintroduce its snapshot of deleted text.
        wire = history.event(timestamp=T + 4000, body='reply')
        wire['params']['result']['envelope']['dataMessage']['quote'] = {'id': T, 'authorUuid': history.PEER, 'text': 'S09_PRIVATE_MARKER'}
        self.store.receive(self.account, wire); self.assert_purged()

    def test_inflight_edit_result_and_late_send_sync_cannot_restore_deleted_text(self):
        self.store.receive(self.account, history.event('sent-sync', timestamp=self.now))
        cid = self.conversation(); mid = self.messages(cid)[0]['messageId']
        op = self.outbox.mutations.enqueue(self.account, {'conversationId': cid, 'messageId': mid, 'versionTimestampMs': self.now, 'text': 'S09_PRIVATE_MARKER'}, 'edit')
        _, attempt = self.outbox.begin(self.account, op['operationId'])
        retention.local_delete(self.store, self.account, {'conversationId': cid, 'messageId': mid})
        self.outbox.finish(self.account, op['operationId'], attempt, history.send_result(self.now + 1))
        self.assert_purged()
        self.store.receive(self.account, interaction.edit(self.now, self.now + 1, 'S09_PRIVATE_MARKER', phone=True))
        self.assert_purged(); self.assertEqual(self.messages(cid), [])

    def test_expiring_media_shared_references_and_late_worker_cleanup(self):
        media = self.store.media
        cli = self.lease.data / 'cli/attachments'; cli.mkdir(parents=True, mode=0o700)
        source = media_tests.png(cli / 'image.png')
        self.store.receive(self.account, media_tests.attachment_event(source, 'image/png', timestamp=T, expiresInSeconds=1))
        self.store.receive(self.account, media_tests.attachment_event(source, 'image/png', timestamp=T + 1))
        cid = self.conversation(); messages = self.messages(cid)
        expiring = next(m for m in messages if m['sentTimestampMs'] == T)
        other = next(m for m in messages if m['sentTimestampMs'] == T + 1)
        row = media.pending(self.account)[0]; aid = row['attachment_id']
        media.active.add(aid)
        prepared = media.prepare(str(source), aid)
        media.imported(self.account, aid, prepared)
        media.active.discard(aid); media.gc()
        original = Path(media.item(self.account, aid)['url'].removeprefix('file://'))
        self.assertTrue(original.exists())
        signal_receipts.mark_visible(self.store, self.account, {'conversationId': cid, 'messageIds': [expiring['messageId']]})
        self.now += 1000; self.clean()
        self.assertTrue(original.exists())  # The ordinary message still owns it.
        retention.local_delete(self.store, self.account, {'conversationId': cid, 'messageId': other['messageId']})
        self.assertFalse(original.exists()); self.assertFalse(source.exists())
        self.assertEqual(list(media.cache.iterdir()), [])
        # A prepared result arriving after deletion never recreates a reference.
        source = media_tests.png(cli / 'late.png')
        self.store.receive(self.account, media_tests.attachment_event(source, 'image/png', timestamp=T + 2))
        mid = next(m['messageId'] for m in self.messages(cid) if m['sentTimestampMs'] == T + 2)
        row = media.pending(self.account)[0]; aid = row['attachment_id']; media.active.add(aid)
        prepared = media.prepare(str(source), aid)
        retention.local_delete(self.store, self.account, {'conversationId': cid, 'messageId': mid})
        media.imported(self.account, aid, prepared)
        media.active.discard(aid); media.gc()
        self.assertEqual(list(media.originals.iterdir()), [])
        self.assertEqual(list(media.cache.iterdir()), [])
        self.assertEqual(list(media.staging.iterdir()), [])

    def test_redaction_stops_the_owned_decoder_before_it_can_publish(self):
        media = self.store.media
        cli = self.lease.data / 'cli/attachments'; cli.mkdir(parents=True, mode=0o700)
        source = media_tests.png(cli / 'decoding.png')
        self.store.receive(self.account, media_tests.attachment_event(source, 'image/png', timestamp=T))
        cid = self.conversation(); mid = self.messages(cid)[0]['messageId']
        aid = media.pending(self.account)[0]['attachment_id']; media.active.add(aid)
        errors = []
        def work():
            try: media.decode(aid, [sys.executable, '-c', 'import time; time.sleep(20)'])
            except Failure as error: errors.append(error.code)
        worker = threading.Thread(target=work); worker.start()
        limit = time.monotonic() + 3
        while aid not in media.jobs and time.monotonic() < limit: time.sleep(.01)
        self.assertIn(aid, media.jobs)
        retention.local_delete(self.store, self.account, {'conversationId': cid, 'messageId': mid})
        worker.join(2)
        self.assertFalse(worker.is_alive()); self.assertTrue(errors)
        media.active.discard(aid); media.gc()
        self.assertFalse(media.jobs); self.assertFalse(media.revoked)

    def test_restart_suspend_clock_steps_and_cleanup_failure_recover(self):
        self.now = T + 1000
        self.store.receive(self.account, disappearing(phone=True, start=T))
        cid = self.conversation(); mid = self.messages(cid)[0]['messageId']
        self.now = T - 10000; self.clean()
        self.assertEqual(self.msg(mid)['expiresAtMs'], T + 30000)
        self.now = T + 60000  # Same expiry path after resume/forward step.
        with patch.object(self.store.media, 'gc', side_effect=OSError('synthetic IO failure')):
            with self.assertRaisesRegex(Failure, 'storage_error'): self.clean()
        self.assertFalse(self.store.healthy)
        self.reopen(); self.assert_purged()
        self.assertEqual(self.msg(mid)['kind'], 'expired')


class DeadlineTests(unittest.IsolatedAsyncioTestCase):
    async def test_real_timerfd_nearest_deadline_and_cancel(self):
        ready = asyncio.Event()
        timer = retention.Deadline(time.time_ns() // 1000000 + 30, ready.set)
        await asyncio.wait_for(ready.wait(), 1)
        self.assertIsNone(timer.fd)
        timer = retention.Deadline(time.time_ns() // 1000000 + 30000, ready.set)
        fd = timer.fd; timer.cancel()
        with self.assertRaises(OSError): os.fstat(fd)

    async def test_clock_step_cancellation_rechecks_database(self):
        called = []
        timer = retention.Deadline(time.time_ns() // 1000000 + 30000, lambda: called.append(True))
        with patch('signal_retention.os.read', side_effect=OSError(errno.ECANCELED, 'clock changed')):
            timer.ready()
        self.assertEqual(called, [True]); self.assertIsNone(timer.fd)
