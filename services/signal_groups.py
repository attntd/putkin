"""Linked-device directory commands; durable unknown results never imply retry."""
import asyncio
import base64
import json
import os
import re
import shutil
import uuid
from pathlib import Path

from signal_events import digest, group_id, identifier, service_id, text
from signal_paths import directory
from signal_transport import Failure
import signal_directory

CAPABILITIES = ['directory.refresh', 'directory.profile', 'directory.avatar', 'group.get',
                'group.create', 'group.update', 'group.join', 'group.quit', 'group.operations',
                'group.reconcile', 'conversation.accept', 'conversation.block']


class Groups:
    def __init__(self, bridge):
        self.bridge = bridge
        self.lock = bridge.mutation_lock

    def ready(self, params):
        b = self.bridge
        if not b.store or not b.store.healthy or not b.account_id:
            raise Failure('not_ready')
        if params.get('accountId') != b.account_id:
            raise Failure('account_mismatch')
        return b.account_id

    def operations(self, account):
        return [self.operation(account, row[0]) for row in self.bridge.store.db.execute(
            "SELECT operation_id FROM directory_operations WHERE account_id=? ORDER BY CASE WHEN state IN ('sending','unknown','partial','requesting') THEN 0 ELSE 1 END,created_ms DESC LIMIT 100", (account,))]

    def operation(self, account, op):
        store = self.bridge.store
        row = store.db.execute('SELECT * FROM directory_operations WHERE account_id=? AND operation_id=?', (account, identifier(op))).fetchone()
        if not row:
            raise Failure('not_found')
        cid = store.db.execute('SELECT conversation_id FROM conversations WHERE account_id=? AND target=?', (account, row['target'])).fetchone()
        return {'operationId': op, 'kind': row['kind'], 'state': row['state'], 'target': row['target'],
                'conversationId': cid[0] if cid else '', 'errorCode': row['error_code'], 'candidates': json.loads(row['candidates'])}

    def group(self, account, target):
        result = next((g for g in self.bridge.store.directory(account)['groups'] if g['groupId'] == target), None)
        if result is None:
            raise Failure('group_unavailable')
        return dict(result, avatar=signal_directory.avatar_url(self.bridge.store, account, target))

    async def refresh(self, account):
        await self.bridge.account.directory_refresh()
        if account != self.bridge.account_id:
            raise Failure('account_mismatch')

    def settle(self, account, op, result, error):
        b, store = self.bridge, self.bridge.store
        row = store.db.execute('SELECT * FROM directory_operations WHERE account_id=? AND operation_id=?', (account, op)).fetchone()
        if not row or row['state'] not in ('sending', 'unknown'):
            return
        state, target, code = 'unknown', row['target'], 'result_unknown'
        if error is None and isinstance(result, dict):
            try:
                if row['kind'] in ('group.create', 'group.join'):
                    target = group_id(result.get('groupId'))
                results = result.get('results', [])
                if not isinstance(results, list) or any(not isinstance(v, dict) or not isinstance(v.get('type'), str) for v in results):
                    raise Failure('invalid_frame')
                state = 'partial' if any(v['type'] != 'SUCCESS' for v in results) else 'succeeded'
                if result.get('onlyRequested') is True:
                    state = 'requesting'
                code = 'partial_result' if state == 'partial' else ''
            except Failure:
                pass
        # CLI may update the server/local group and only then throw. Even an RPC
        # error is not proof of failure. Raw errors may contain private material.
        with store.transaction():
            store.db.execute('UPDATE directory_operations SET state=?,target=?,error_code=? WHERE operation_id=?', (state, target, code, op))
            if target and row['kind'].startswith('group.'):
                store.route(account, {'group': target})
            store.changed('directory.operation.changed', accountId=account, operationId=op)
        b.refresh_directory()
        b.wake_outbox.set()

    async def request(self, method, params):
        account = self.ready(params)
        b, store = self.bridge, self.bridge.store
        if method == 'group.operations':
            return {'items': self.operations(account)}
        if b.state != 'ready' or b.account_state != 'linked' or not b.transport:
            raise Failure('not_ready')
        if method == 'directory.refresh':
            await self.refresh(account)
            return store.directory(account)
        if method == 'directory.profile':
            sid = service_id(params.get('serviceId'))
            if not sid.startswith('aci:'):
                raise Failure('recipient_unresolved')
            # A targeted listContacts refreshes the profile; no probe message.
            await b.transport.request('listContacts', {'account': store.account(account)['cli_address'],
                'recipient': [sid.removeprefix('aci:')], 'allRecipients': True})
            await self.refresh(account)
            contact = next((c for c in store.directory(account)['contacts'] if c['serviceId'] == sid), None)
            if not contact:
                raise Failure('recipient_unresolved')
            return dict(contact, avatar=signal_directory.avatar_url(store, account, sid))
        if method == 'directory.avatar':
            return await self.avatar(account, params)
        async with self.lock:
            await b.account.check_current()
            await self.refresh(account)
            if method == 'group.get':
                return self.group(account, group_id(params.get('groupId')))
            if method == 'group.reconcile':
                return self.reconcile(account, params)
            if method in ('conversation.accept', 'conversation.block'):
                return await self.contact_action(account, method, params)
            return await self.mutate(account, method, params)

    def reconcile(self, account, params):
        store = self.bridge.store
        op = identifier(params.get('operationId'))
        result = self.operation(account, op)
        if result['state'] not in ('unknown', 'partial', 'requesting'):
            return result
        row = store.db.execute('SELECT * FROM directory_operations WHERE operation_id=?', (op,)).fetchone()
        if result['target']:
            group = self.group(account, result['target'])
            if params.get('groupId'):
                if params['groupId'] != result['target'] or params.get('confirm') != 'use-existing-group':
                    raise Failure('confirmation_required')
                with store.transaction():
                    store.db.execute("UPDATE directory_operations SET state='reconciled' WHERE operation_id=?", (op,))
                    store.changed('directory.operation.changed', accountId=account, operationId=op)
                result = self.operation(account, op)
            # Readback establishes actual membership, never delivery to everyone.
            result['group'] = group
            return result
        baseline = json.loads(row['baseline'])
        candidates = [g['groupId'] for g in store.directory(account)['groups'] if g['groupId'] not in baseline]
        chosen = params.get('groupId')
        if chosen and (params.get('confirm') != 'use-existing-group' or chosen not in candidates):
            raise Failure('confirmation_required')
        with store.transaction():
            if chosen:
                store.db.execute("UPDATE directory_operations SET target=?,state='reconciled',error_code='' WHERE operation_id=?", (chosen, op))
                store.route(account, {'group': chosen})
            store.db.execute('UPDATE directory_operations SET candidates=? WHERE operation_id=?', (json.dumps(candidates), op))
            store.changed('directory.operation.changed', accountId=account, operationId=op)
        return self.operation(account, op)

    async def mutate(self, account, method, params):
        b, store = self.bridge, self.bridge.store
        op = identifier(params.get('operationId'))
        fingerprint = digest([method, {k: v for k, v in params.items() if k != 'operationId'}])
        old = store.db.execute('SELECT * FROM directory_operations WHERE operation_id=?', (op,)).fetchone()
        if old:
            if old['account_id'] != account or old['fingerprint'] != fingerprint:
                raise Failure('operation_conflict')
            return self.operation(account, op)
        args = {'account': store.account(account)['cli_address']}
        target = ''
        if method == 'group.create':
            if store.db.execute("SELECT 1 FROM directory_operations WHERE account_id=? AND kind='group.create' AND state IN ('sending','unknown')", (account,)).fetchone():
                raise Failure('operation_pending')
            name = text(params.get('name'), 128, empty=False).strip()
            if not name:
                raise Failure('invalid_request')
            args.update(name=name, member=self.peers(params.get('members'), account))
            if not args['member']:
                raise Failure('invalid_request')
            rpc = 'updateGroup'
        elif method == 'group.join':
            uri = text(params.get('uri'), 2048, empty=False)
            if not re.fullmatch(r'https://signal\.group/#[A-Za-z0-9_=-]{16,1800}', uri):
                raise Failure('invalid_group_link')
            if store.db.execute("SELECT 1 FROM directory_operations WHERE account_id=? AND kind='group.join' AND state IN ('sending','unknown')", (account,)).fetchone():
                raise Failure('operation_pending')
            args['uri'] = uri
            rpc = 'joinGroup'
        elif method in ('group.update', 'group.quit'):
            target = group_id(params.get('groupId'))
            if store.db.execute("SELECT 1 FROM directory_operations WHERE account_id=? AND target=? AND state IN ('sending','unknown')", (account, target)).fetchone():
                raise Failure('operation_pending')
            group = self.group(account, target)
            args['groupId'] = target  # updateGroup without ID creates a new group.
            rpc = 'quitGroup' if method == 'group.quit' else 'updateGroup'
            if method == 'group.quit':
                if not group['canLeave']:
                    raise Failure('permission_denied')
                if params.get('confirm') != target:
                    raise Failure('confirmation_required')
                if group['membership'] == 'member' and group['isAdmin'] and len([m for m in group['members'] if m['isAdmin'] or m['serviceId'] in [v['serviceId'] for v in group['admins']]]) <= 1 and len(group['members']) > 1:
                    admins = self.peers(params.get('admins', []), account)
                    if not admins or any('aci:' + sid not in [m['serviceId'] for m in group['members']] for sid in admins):
                        raise Failure('last_admin')
                    args['admin'] = admins
            else:
                self.update_args(group, account, params, args)
        else:
            raise Failure('unsupported_method')
        avatar = ''
        try:
            if params.get('avatar'):
                if method not in ('group.create', 'group.update') or method == 'group.update' and params.get('action') != 'details':
                    raise Failure('invalid_request')
                avatar = await self.prepare_avatar(params['avatar'])
                args['avatar'] = avatar
            baseline = [g['groupId'] for g in store.directory(account)['groups']]
            with store.transaction():
                store.db.execute('INSERT INTO directory_operations(operation_id,account_id,kind,target,state,fingerprint,baseline,created_ms) VALUES(?,?,?,?,?,?,?,?)',
                    (op, account, method, target, 'sending', fingerprint, json.dumps(baseline), store.clock()))
                store.changed('directory.operation.changed', accountId=account, operationId=op)
            try:
                await b.transport.request(rpc, args, mutating=True,
                    on_result=lambda result, error: self.settle(account, op, result, error))
            except Failure as error:
                with store.transaction():
                    # busy before submission is the only proven no-op here.
                    state = 'failed' if error.code in ('busy', 'cancelled', 'not_ready') else 'unknown'
                    store.db.execute("UPDATE directory_operations SET state=?,error_code=? WHERE operation_id=? AND state='sending'", (state, error.code, op))
                    store.changed('directory.operation.changed', accountId=account, operationId=op)
                if asyncio.current_task().cancelling():
                    raise asyncio.CancelledError
            await self.refresh(account)
            return self.operation(account, op)
        finally:
            # The CLI takes ownership of the image during this command. Keep an
            # uncertain input until transport teardown/startup cleanup.
            if avatar and (not store.db.execute("SELECT 1 FROM directory_operations WHERE operation_id=? AND state='unknown'", (op,)).fetchone()):
                Path(avatar).unlink(missing_ok=True)

    def peers(self, values, account):
        if not isinstance(values, list) or len(values) > 999:
            raise Failure('invalid_request')
        own = self.bridge.store.account(account)['service_id']
        result = []
        for value in values:
            sid = service_id(value)
            if not sid.startswith('aci:') or sid == own:
                raise Failure('invalid_recipient')
            if sid[4:] not in result:
                result.append(sid[4:])
        return result

    def update_args(self, group, account, params, args):
        action = params.get('action')
        if action == 'accept':
            if not group['canAccept']:
                raise Failure('permission_denied')
            return  # updateGroup accepts a pending invitation.
        permission = 'canEdit' if action == 'details' else 'canAdd' if action == 'add' else 'canAdmin'
        if not group.get(permission):
            raise Failure('permission_denied')
        if action == 'details':
            if 'name' in params:
                name = text(params['name'], 128, empty=False).strip()
                if not name: raise Failure('invalid_request')
                args['name'] = name
            if 'description' in params:
                args['description'] = text(params['description'], 480)
        elif action in ('add', 'remove', 'promote', 'demote', 'approve', 'deny'):
            peers = self.peers(params.get('members'), account)
            if not peers:
                raise Failure('invalid_request')
            pool = group['requestingMembers'] if action in ('approve', 'deny') else group['members'] + group['pendingMembers']
            if action != 'add' and any('aci:' + sid not in [m['serviceId'] for m in pool] for sid in peers):
                raise Failure('member_unavailable')
            if action in ('remove', 'demote', 'deny') and params.get('confirm') != group['groupId']:
                raise Failure('confirmation_required')
            args[{'add': 'member', 'remove': 'removeMember', 'promote': 'admin', 'demote': 'removeAdmin', 'approve': 'member', 'deny': 'removeMember'}[action]] = peers
        elif action == 'permissions':
            for source, target in (('addMember', 'setPermissionAddMember'), ('editDetails', 'setPermissionEditDetails'), ('sendMessages', 'setPermissionSendMessages')):
                if params.get(source) not in ('every-member', 'only-admins'):
                    raise Failure('invalid_request')
                args[target] = params[source]
        elif action == 'link':
            if params.get('link') not in ('enabled', 'enabled-with-approval', 'disabled'):
                raise Failure('invalid_request')
            if params.get('reset') and params.get('confirm') != group['groupId']:
                raise Failure('confirmation_required')
            args['link'] = params['link']
            if params.get('reset'): args['resetLink'] = True
        else:
            raise Failure('invalid_request')

    async def contact_action(self, account, method, params):
        b, store = self.bridge, self.bridge.store
        row = store.conversation(account, params.get('conversationId'))
        if row['kind'] == 'note' or not row['target'].startswith('aci:') and row['kind'] != 'group':
            raise Failure('permission_denied')
        args = {'account': store.account(account)['cli_address']}
        args['groupId' if row['kind'] == 'group' else 'recipient'] = [row['target'].removeprefix('aci:')]
        if method == 'conversation.accept':
            if row['kind'] == 'group' or store.conversation_item(account, row['conversation_id'])['blocked']:
                raise Failure('permission_denied')
            args['type'] = 'accept'
            rpc = 'sendMessageRequestResponse'
        else:
            if type(params.get('blocked')) is not bool:
                raise Failure('invalid_request')
            if params.get('blocked') and params.get('confirm') != row['conversation_id']:
                raise Failure('confirmation_required')
            rpc = 'block' if params['blocked'] else 'unblock'
        await b.transport.request(rpc, args, mutating=True)
        await self.refresh(account)
        result = store.conversation_item(account, row['conversation_id'])
        if method == 'conversation.accept' and result['requestState'] != 'accepted' or method == 'conversation.block' and result['blocked'] != params['blocked']:
            raise Failure('result_unknown')
        # Readback verifies local profile sharing/block state, not phone receipt.
        return result

    async def prepare_avatar(self, source):
        b, media = self.bridge, self.bridge.store.media
        aid = str(uuid.uuid4())
        media.active.add(aid)
        try:
            prepared = await b.media_worker(media.prepare, source, aid)
            if prepared['mime'] not in ('image/png', 'image/jpeg', 'image/webp') or prepared['size'] > 2 * 1024 * 1024 or not prepared['thumbnail']:
                raise Failure('invalid_avatar')
            folder = media.root / 'avatars'
            os.close(directory(folder, private=True))
            if sum(p.stat(follow_symlinks=False).st_size for p in folder.iterdir()) > 32 * 1024 * 1024:
                raise Failure('media_quota')
            destination = folder / (aid + '.jpg')
            shutil.copyfile(media.cache / (aid + '-thumbnail.jpg'), destination)
            destination.chmod(0o600)
            with destination.open('rb') as handle: os.fsync(handle.fileno())
            return str(destination)
        finally:
            media.active.discard(aid)
            media.gc()

    async def avatar(self, account, params):
        b, store = self.bridge, self.bridge.store
        group = params.get('groupId')
        target = group_id(group) if group else service_id(params.get('serviceId'))
        if group: self.group(account, target)
        elif not any(c['serviceId'] == target for c in store.directory(account)['contacts']):
            raise Failure('recipient_unresolved')
        args = {'account': store.account(account)['cli_address'], 'groupId' if group else 'profile': target if group else target.removeprefix('aci:')}
        try:
            result = await b.transport.request('getAvatar', args)
        except Failure as error:
            if error.code != 'rpc_error':
                raise
            # Missing/invalid local CLI avatar uses a placeholder, never a stale
            # image from a previous profile. No raw error text reaches QML.
            old = store.db.execute('SELECT filename FROM directory_avatars WHERE account_id=? AND target=?', (account, target)).fetchone()
            with store.transaction():
                store.db.execute('DELETE FROM directory_avatars WHERE account_id=? AND target=?', (account, target))
                store.changed('account.directory.changed', accountId=account)
            if old: (store.media.root / 'avatars' / old[0]).unlink(missing_ok=True)
            return {'target': target, 'avatar': ''}
        if not isinstance(result, dict) or not isinstance(result.get('data'), str) or len(result['data']) > 700000:
            raise Failure('invalid_avatar')
        try:
            data = base64.b64decode(result['data'], validate=True)
        except ValueError:
            raise Failure('invalid_avatar') from None
        folder = store.media.root / 'avatars'
        os.close(directory(folder, private=True))
        source = folder / (str(uuid.uuid4()) + '.input')
        try:
            with source.open('xb') as handle:
                os.chmod(source, 0o600)
                handle.write(data)
            path = await self.prepare_avatar(str(source))
            old = store.db.execute('SELECT filename FROM directory_avatars WHERE account_id=? AND target=?', (account, target)).fetchone()
            with store.transaction():
                store.db.execute('INSERT INTO directory_avatars VALUES(?,?,?) ON CONFLICT(account_id,target) DO UPDATE SET filename=excluded.filename', (account, target, Path(path).name))
                store.changed('account.directory.changed', accountId=account)
            if old: (folder / old[0]).unlink(missing_ok=True)
            return {'target': target, 'avatar': Path(path).as_uri()}
        finally:
            source.unlink(missing_ok=True)
