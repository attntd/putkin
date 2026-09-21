"""Ephemeral, rate-limited typing. Timers exist only while something expires."""
import asyncio
from signal_events import normalize
from signal_transport import Failure


class Typing:
    def __init__(self, bridge):
        self.bridge = bridge
        self.outgoing = {}
        self.incoming = {}
        self.timer = None
        self.lock = asyncio.Lock()
        self.tasks = set()

    def enabled(self):
        return self.bridge.account.config.get('typingIndicators', False)

    async def stop_all(self):
        for cid in list(self.outgoing):
            await self.set({'accountId': self.bridge.account_id, 'conversationId': cid, 'active': False})

    def clear(self):
        if self.timer:
            self.timer.cancel()
            self.timer = None
        cids = {k[0] for k in self.incoming}
        self.incoming.clear()
        self.outgoing.clear()
        for task in self.tasks:
            task.cancel()
        for cid in cids:
            self.publish(cid)

    def publish(self, cid):
        self.bridge.event('typing.changed', {'accountId': self.bridge.account_id, 'conversationId': cid,
            'authors': [actor for (chat, actor), value in self.incoming.items() if chat == cid and value[2]]})

    def receive(self, wire):
        if not self.enabled():
            return
        b = self.bridge
        now = asyncio.get_running_loop().time()
        for event in normalize(wire, b.store.account(b.account_id)['service_id']):
            if event['kind'] == 'message':
                route = event['route']
                chat = b.store.db.execute('SELECT conversation_id FROM conversations WHERE account_id=? AND kind=? AND target=?',
                    (b.account_id, 'group' if route.get('group') else 'direct', route.get('group') or route.get('peer'))).fetchone()
                if chat and (chat[0], event['author']) in self.incoming:
                    del self.incoming[(chat[0], event['author'])]
                    self.publish(chat[0])
                continue
            if event['kind'] != 'typing':
                continue
            row = b.store.db.execute('SELECT conversation_id FROM conversations WHERE account_id=? AND kind=? AND target=?',
                (b.account_id, 'group' if event['group'] else 'direct', event['group'] or event['author'])).fetchone()
            if not row:
                continue  # Typing cannot fabricate a conversation or activity.
            cid = row[0]
            key = (cid, event['author'])
            old = self.incoming.get(key)
            if old and old[0] >= event['event_ms']:
                continue
            if len(self.incoming) >= 1000 and key not in self.incoming:
                continue
            self.incoming[key] = (event['event_ms'], now + 15, event['active'])
            self.publish(cid)
        self.schedule()

    async def set(self, params):
        b = self.bridge
        if not b.store or not b.store.healthy or not b.account_id:
            raise Failure('not_ready')
        if params.get('accountId') != b.account_id or type(params.get('active')) is not bool:
            raise Failure('invalid_request')
        cid = params.get('conversationId')
        conversation = b.store.conversation(b.account_id, cid)
        async with self.lock:
            now = asyncio.get_running_loop().time()
            active = params['active'] and self.enabled() and b.state == 'ready'
            old = self.outgoing.get(cid)
            if not active:
                self.outgoing.pop(cid, None)
                if not old or not b.transport or b.state != 'ready':
                    self.schedule()
                    return {'accepted': True}
            else:
                if not b.store.conversation_item(b.account_id, cid)['canSend'] or conversation['kind'] == 'note':
                    return {'accepted': False}
                if old and now - old[0] < 8:
                    self.outgoing[cid] = (old[0], now + 5)
                    self.schedule()
                    return {'accepted': True}
                self.outgoing[cid] = (now, now + 5)
            fields = {'account': b.store.account(b.account_id)['cli_address'], 'stop': not active}
            fields['groupId' if conversation['kind'] == 'group' else 'recipient'] = [conversation['target'].removeprefix('aci:')]
            self.schedule()
            # No durable queue or replay. 0.14.8 does not export the phone's
            # preference or enforce it here; the explicit Putkin setting owns this.
            try:
                await b.transport.request('sendTyping', fields, timeout=5)
            except Failure:
                self.outgoing.pop(cid, None)
            return {'accepted': True}

    def schedule(self):
        if self.timer:
            self.timer.cancel()
            self.timer = None
        deadlines = [v[1] for v in self.incoming.values()] + [v[1] for v in self.outgoing.values()]
        if deadlines:
            loop = asyncio.get_running_loop()
            self.timer = loop.call_later(max(0, min(deadlines) - loop.time()), self.expire)

    def expire(self):
        self.timer = None
        now = asyncio.get_running_loop().time()
        cids = set()
        for key, value in list(self.incoming.items()):
            if value[1] <= now:
                del self.incoming[key]
                cids.add(key[0])
        for cid in cids:
            self.publish(cid)
        for cid, value in list(self.outgoing.items()):
            if value[1] <= now:
                # Keep ownership until serialized STOP consumes it; advance the
                # deadline to avoid spinning while another typing RPC is running.
                self.outgoing[cid] = (value[0], now + 6)
                task = asyncio.create_task(self.set({'accountId': self.bridge.account_id, 'conversationId': cid, 'active': False}))
                self.tasks.add(task)
                task.add_done_callback(self.tasks.discard)
        self.schedule()
