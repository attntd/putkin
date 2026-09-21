"""Reusable S11 fixture and native/offscreen acceptance driver. Synthetic data only."""
from contextlib import closing
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import sqlite3
import statistics
import subprocess
import sys
import time
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from _common import ipc_json, ipc_reply, tool
from test_signal_history import event, send_result, OWN, PEER
from test_signal_groups import group, CREATED
from test_signal_media import fixtures, attachment_event
from test_signal_interactions import edit, reaction
from test_signal_retention import disappearing, deletion
from test_signal_receipts import receipt
from signal_paths import StoreLease
from signal_store import Store

loader = importlib.machinery.SourceFileLoader('signal_measurement', str(ROOT/'scripts/measure-idle'))
spec = importlib.util.spec_from_loader(loader.name, loader)
measurement = importlib.util.module_from_spec(spec)
loader.exec_module(measurement)


def eventually(read, predicate, description, seconds=20):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        value = read()
        if predicate(value): return value
        time.sleep(.05)
    # Do not put message bodies/drafts in failure logs.
    raise AssertionError('Deadline: ' + description)


def prepare(env, base, count=10000):
    old = os.umask(0o077)
    try:
        stamp = int(time.time()*1000) - 20000
        record, fixture = base/'processes.jsonl', base/'fixture.json'
        contacts = [{'number': '+12025550100', 'uuid': OWN, 'messageExpirationTime': 0},
                    {'number': '+12025550101', 'uuid': PEER, 'name': 'Alicja', 'profileSharing': True, 'messageExpirationTime': 0}]
        fixture.write_text(json.dumps({'format': 1, 'synthetic': True, 'record': str(record), 'receiveEvents': [],
            'readReceipts': False, 'groups': [group()], 'contacts': contacts,
            'interactionTimestamp': stamp+6000, 'sendResult': send_result(stamp+5000),
            'directoryFile': str(base/'directory.json')}))
        config = Path(env['XDG_CONFIG_HOME'])/'putkin'
        config.mkdir(mode=0o700, exist_ok=True)
        (config/'signal.json').write_text(json.dumps({'v': 1, 'enabled': True, 'deviceName': 'Putkin'}))
        env['PUTKIN_SIGNAL_TEST_SCENARIO'] = str(fixture)
        with patch.dict(os.environ, env):
            lease = StoreLease(); assert lease.acquire()
            store = Store(lease)
            try:
                account = store.bind_account(OWN, '+12025550100')
                started = time.monotonic()
                for i in range(count):
                    store.receive(account, event(timestamp=stamp-86400000+i, body='Syntetyczna historia %05d' % i))
                cid = store.open_conversation(account, {'kind': 'direct', 'serviceId': PEER})['conversationId']
                # Historical entries are already read. This setup does not send receipts.
                with store.transaction():
                    store.db.execute('UPDATE messages SET read_at_ms=?', (stamp,))
                latencies, cursor, ids = [], None, set()
                while True:
                    started_page = time.monotonic()
                    page = store.page(account, {'conversationId': cid, 'before': cursor, 'limit': 50}, messages=True)
                    latencies.append((time.monotonic()-started_page)*1000)
                    page_ids = {row['messageId'] for row in page['items']}
                    assert not ids & page_ids
                    ids |= page_ids
                    cursor = page['nextCursor']
                    if not cursor: break
                assert len(ids) == count
                plan = [row[3] for row in store.db.execute('EXPLAIN QUERY PLAN SELECT * FROM messages WHERE conversation_id=? AND hidden_local=0 AND (sort_ms,message_id)<(?,?) ORDER BY sort_ms DESC,message_id DESC LIMIT 51', (cid, stamp, 'z'))]
                assert any('messages_page' in line for line in plan), plan
                return {'stamp': stamp, 'cid': cid, 'record': record, 'count': count,
                    'seedAndPageSeconds': round(time.monotonic()-started, 3), 'pageCount': len(latencies),
                    'pageMs': {'median': statistics.median(latencies), 'p95': sorted(latencies)[int(.95*(len(latencies)-1))], 'max': max(latencies)},
                    'queryPlan': plan}
            finally:
                store.close(); lease.close()
    finally: os.umask(old)


class Driver:
    def __init__(self, env, base, app, log, seeded):
        self.env, self.base, self.app, self.log, self.seeded = env, base, app, log, seeded
        self.entry = str(ROOT/'signal-acceptance-test.qml')
        self.checks, self.helpers = [], set()
        self.db = Path(env['XDG_DATA_HOME'])/'putkin/signal/history.sqlite3'

    def ipc(self, method, *args):
        arguments = [str(v).lower() if isinstance(v, bool) else str(v) for v in args]
        result = subprocess.run([tool('quickshell'), 'ipc', '--path', self.entry, 'call', 'probe', method, *arguments],
            env=self.env, text=True, capture_output=True, timeout=5)
        return ipc_reply(result, self.app, self.log, starting=method == 'snapshot')

    def state(self):
        value = ipc_json(self.ipc('snapshot'))
        if value.get('pid'): self.helpers.add(value['pid'])
        return value

    def wait(self, predicate, description, seconds=20): return eventually(self.state, predicate, description, seconds)

    def records(self, kind):
        path = self.seeded['record']
        return [r for r in map(json.loads, path.read_text().splitlines()) if r['kind'] == kind] if path.exists() else []

    def query(self, sql, params=()):
        with closing(sqlite3.connect(self.db)) as db: return db.execute(sql, params).fetchall()

    def receive(self, wire): self.ipc('receive', json.dumps(wire))

    def check(self, description):
        self.checks.append(description)
        print('PASS: '+description, flush=True)

    def open(self, cid=None, monitor=''):
        assert self.ipc('openRoute', cid or self.seeded['cid'], monitor) == 'true'
        return self.wait(lambda s: s.get('loaded') and s.get('presentationOpacity') == 1 and s.get('draftReady') and s.get('count', 0) > 0 and not s.get('pending'), 'history ready')

    def close(self):
        self.ipc('close')
        return self.wait(lambda s: not s.get('loaded') and s.get('created') == s.get('destroyed'), 'window released')

    def metrics(self):
        self.ipc('metrics')
        return self.wait(lambda s: bool(s.get('metrics')), 'metrics')['metrics']

    def e2e(self, capture):
        stamp = self.seeded['stamp']
        self.wait(lambda s: s.get('state') == 'ready' and s.get('settingsReady') and not s.get('pending'), 'startup')
        assert not self.state()['loaded']
        self.receive(event(timestamp=stamp, body='Tekst S11 <b>dosłownie</b> hjkl 🐈'))
        self.wait(lambda s: len(s.get('history', [])) == 1 and not s.get('pending'), 'notification without messages window')
        media_dir = Path(self.env['XDG_DATA_HOME'])/'putkin/signal/cli/attachments'
        media_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        for i, (path, mime) in enumerate(zip(fixtures(media_dir), ['image/png', 'video/mp4', 'audio/wav', 'text/plain'])):
            original_name = path.name
            path = path.rename(media_dir / ('synthetic-media-' + str(i)))
            wire = attachment_event(path, mime, timestamp=stamp+100+i)
            wire['params']['result']['envelope']['dataMessage']['attachments'][0]['filename'] = '../../' + original_name
            self.receive(wire)
        self.wait(lambda s: len(s.get('history', [])) == 1 and not s.get('pending'), 'text and four media notifications')
        eventually(lambda: self.query("SELECT count(*) FROM media_files WHERE state='ready'")[0][0], lambda n: n == 4, 'media decoded')
        assert not self.records('receipt') and not self.state()['loaded']
        assert self.ipc('replyOpen', 0) == 'true'
        self.wait(lambda s: s.get('reply') and s['reply']['ready'], 'quick reply ready')
        self.ipc('replyDraft', 'Odpowiedź syntetyczna S11')
        assert self.ipc('replySend') == 'true'
        eventually(lambda: self.records('send'), lambda rows: len(rows) == 1, 'one quick reply send')
        self.wait(lambda s: s.get('reply') and s['reply']['state'] == 'sent', 'quick reply confirmed')
        assert not self.state()['loaded'] and self.records('send')[0]['params'] == {'recipient': [PEER]}
        self.ipc('replyClose')
        self.open()
        self.wait(lambda s: any(r['outgoing'] and r['statusCode'] == 'sent' for r in s['rows']), 'reply in history')
        capture('conversation-media')
        own = next(row for row in self.state()['rows'] if row['outgoing'])
        remote = next(row for row in self.state()['rows'] if row.get('timestamp') == stamp)
        assert self.ipc('react', remote['messageId'], '👍', False) == 'true'
        eventually(lambda: self.records('reaction'), bool, 'reaction dispatched')
        self.wait(lambda s: any('👍' in r.get('reactionsJson', '') for r in s['rows']), 'reaction visible')
        assert self.ipc('edit', own['messageId']) == 'true'
        self.ipc('compose', 'Poprawiona odpowiedź S11')
        assert self.ipc('submit') == 'true'
        eventually(lambda: self.records('edit'), lambda rows: len(rows) == 1, 'edit dispatched once')
        self.wait(lambda s: not s.get('editing') and any(r['text'] == 'Poprawiona odpowiedź S11' for r in s['rows']), 'edit visible')
        self.receive(receipt('read', [stamp+6000], when=stamp+7000))
        self.receive(receipt('delivery', [stamp+6000], when=stamp+6500))
        self.wait(lambda s: any(r['messageId'] == own['messageId'] and r['statusCode'] == 'read' for r in s['rows']), 'read never regresses')
        self.check('closed-window text/media notification → exact-recipient quick reply → history → reaction → edit → reverse receipts')
        self.ipc('trace', 'before-direct-close')
        self.close()
        self.ipc('trace', 'after-direct-close')
        count = len(self.state()['history'])
        self.receive(event('sent-sync', timestamp=stamp+8000, body='Telefon: bez toasta'))
        eventually(lambda: self.query('SELECT count(*) FROM messages WHERE sent_ms=?', (stamp+8000,))[0][0], lambda n: n == 1, 'phone sync stored')
        self.wait(lambda s: not s.get('pending'), 'phone sync settled')
        assert len(self.state()['history']) == count
        self.receive(edit(stamp+8100, stamp+8200, 'Edycja przed oryginałem'))
        self.receive(reaction(stamp+8100, stamp+8300))
        self.receive(event(timestamp=stamp+8100, body='Oryginał przychodzi później'))
        self.receive(deletion(stamp+8500, target=stamp+8400))
        self.receive(event(timestamp=stamp+8400, body='Nie może wrócić po usunięciu'))
        eventually(lambda: self.query('SELECT body,kind FROM messages WHERE sent_ms=?', (stamp+8400,)), lambda rows: rows and rows[0] == (None, 'deleted'), 'delete before target')
        self.check('phone sent-sync creates history without toast; reverse edit/reaction and delete-before-original preserve identity and redaction')
        self.ipc('trace', 'before-group-create')
        assert self.ipc('createGroup', 'Zespół S11', 'aci:'+PEER) == 'true'
        self.wait(lambda s: (s.get('selectedConversation') or {}).get('target') == CREATED and s.get('draftReady') and not s.get('pending'), 'group created')
        self.ipc('details'); self.wait(lambda s: (s.get('groupDetails') or {}).get('canAdmin') and not s.get('pending'), 'group details')
        self.ipc('trace', 'group-details')
        capture('group-details')
        self.close()
        self.receive(event(timestamp=stamp+8600, group=CREATED, body='Grupa S11'))
        self.wait(lambda s: any(r.get('summary') == 'Zespół S11' for r in s.get('history', [])) and not s.get('pending'), 'group notification')
        self.check('same process creates group, confirms admin roles and routes incoming group notification')
        self.ipc('trace', 'before-direct-reopen')
        self.open()
        self.ipc('trace', 'after-direct-reopen')
        assert self.ipc('remove', remote['messageId'], 'local') == 'true'
        self.wait(lambda s: all(r['messageId'] != remote['messageId'] for r in s['rows']) and not s.get('pending'), 'local delete')
        self.close()
        clock = int(time.time()*1000)
        self.receive(disappearing(phone=True, stamp=clock, start=clock, seconds=2, body='S11_EXPIRING_PRIVATE_MARKER'))
        eventually(lambda: self.query('SELECT count(*) FROM messages WHERE sent_ms=?', (clock,))[0][0], lambda n: n == 1, 'expiring sent sync')
        generation = self.state()['generation']
        self.ipc('reload')
        self.wait(lambda s: s.get('state') == 'ready' and s.get('generation') != generation and not s.get('pending'), 'hard reload')
        eventually(lambda: self.query('SELECT body,kind FROM messages WHERE sent_ms=?', (clock,)), lambda rows: rows and rows[0] == (None, 'expired'), 'expiry after restart')
        assert len(self.records('send')) == len(self.records('edit')) == 1
        self.check('local deletion and deadline survive hard reload; no send replay or expired body')

    def performance(self):
        self.close(); self.ipc('clearNotifications')
        # Let transient redraws and read batching finish before measuring.
        time.sleep(2)
        before = self.state(); metrics_before = self.metrics()
        assert before['qmlTimers'] == 0
        assert not metrics_before['typingTimers'] and not metrics_before['mediaWorker']
        start = time.monotonic(); samples = []
        print('Idle: 60 seconds with messages window closed, no IPC.', flush=True)
        for second in range(61):
            time.sleep(max(0, start+second-time.monotonic()))
            samples.append({'elapsed': time.monotonic()-start, 'processes': measurement.process_tree(self.app.pid)})
            if second and second % 20 == 0: print(f'Idle {second}/60 s', flush=True)
        after = self.state(); metrics_after = self.metrics()
        assert before['pid'] == after['pid'] and before['generation'] == after['generation']
        assert metrics_before == metrics_after
        assert all(len(s['processes']) == 4 for s in samples), 'expected QML, bridge, fake CLI and notification watcher'
        roles = {self.app.pid: 'qml', before['pid']: 'signal-bridge', self.records('start')[-1]['pid']: 'synthetic-cli'}
        for proc in samples[0]['processes']:
            if proc['pid'] not in roles:
                command = Path(f"/proc/{proc['pid']}/cmdline").read_bytes()
                assert b'/notification-watch.py' in command
                roles[proc['pid']] = 'notification-watcher'
        summaries = []
        for proc in samples[0]['processes']:
            values = [next(p for p in s['processes'] if p['pid'] == proc['pid']) for s in samples]
            summaries.append({'pid': proc['pid'], 'role': roles[proc['pid']], 'name': proc['name'], 'rssStartKiB': values[0]['rss_kib'], 'rssEndKiB': values[-1]['rss_kib'],
                'cpuSeconds': (values[-1]['cpu_ticks']-values[0]['cpu_ticks'])/os.sysconf('SC_CLK_TCK')})
        cycles = []
        for i in range(20):
            started = time.monotonic(); state = self.open()
            assert 0 < state['count'] <= 50 and state['nextCursor'] is not None
            assert state['delegates'] < 50
            self.ipc('more')
            second = self.wait(lambda s: s['count'] == state['count'] + 50 and not s['pending'], 'second 50-row page')
            assert second['delegates'] < 50
            closed = self.close()
            cycles.append({'cycle': i+1, 'elapsedMs': (time.monotonic()-started)*1000,
                'created': closed['created'], 'destroyed': closed['destroyed'],
                'firstPageRows': state['count'], 'secondPageRows': second['count'],
                'firstPageDelegates': state['delegates'], 'secondPageDelegates': second['delegates'],
                'processes': measurement.process_tree(self.app.pid)})
        # Warm-up allocations may grow the allocator; compare medians of two
        # settled batches, with a recorded 16 MiB regression budget.
        rss = [next(p['rss_kib'] for p in c['processes'] if p['pid'] == self.app.pid) for c in cycles]
        growth = statistics.median(rss[-5:])-statistics.median(rss[5:10])
        assert growth < 16*1024, 'QML RSS grew beyond the settled-cycle budget'
        assert all(len(c['processes']) == 4 for c in cycles)
        assert len(self.records('subscribe')) == len(self.records('start')) == 2  # initial + hard reload
        self.check('60 s closed-window idle; 20 opens/closes release every window; paginated history in batches of up to 50 rows, bounded delegates/processes/RSS')
        return {'idleSeconds': samples[-1]['elapsed'], 'idleSummary': summaries, 'samples': samples,
            'cycles': cycles, 'settledRssGrowthKiB': growth, 'growthBudgetKiB': 16*1024,
            'metricsBefore': metrics_before, 'metricsAfter': metrics_after, 'qmlTimersClosed': after['qmlTimers'],
            'totalSubscriptions': len(self.records('subscribe')), 'concurrentSubscriptions': 1,
            'scope': 'synthetic subscribed CLI; real empty-account JVM measured separately'}
