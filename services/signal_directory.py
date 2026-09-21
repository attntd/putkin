"""Versioned directory projection and fail-closed conversation permissions."""
import json
import os
import uuid

from signal_events import group_id, service_id, text
from signal_transport import Failure
from signal_paths import directory


def members(values):
    if not isinstance(values, list) or len(values) > 1000:
        raise Failure('invalid_frame')
    result = []
    for item in values:
        if not isinstance(item, dict):
            raise Failure('invalid_frame')
        result.append({'serviceId': service_id(item['uuid']) if item.get('uuid') else '',
                       'number': text(item.get('number') or '', 128), 'isAdmin': item.get('isAdmin') is True})
    return sorted(result, key=lambda v: (v['serviceId'], v['number']))


def normalize(contacts, groups, own):
    if not isinstance(contacts, list) or not isinstance(groups, list) or len(contacts) + len(groups) > 5000:
        raise Failure('invalid_frame')
    result = {'contacts': [], 'groups': [], 'ownServiceId': own}
    for item in contacts:
        if not isinstance(item, dict) or not isinstance(item.get('profile') or {}, dict):
            raise Failure('invalid_frame')
        profile = item.get('profile') or {}
        result['contacts'].append({
            'serviceId': service_id(item['uuid']) if item.get('uuid') else '',
            'number': text(item.get('number') or '', 128), 'name': text(item.get('name') or '', 512),
            'username': text(item.get('username') or '', 128), 'blocked': item.get('isBlocked') is True,
            'profileSharing': item.get('profileSharing') is True, 'unregistered': item.get('unregistered') is True,
            'profileName': text(' '.join(str(profile.get(k) or '') for k in ('givenName', 'familyName')).strip(), 512),
            'about': text(profile.get('about') or '', 1024), 'hasAvatar': profile.get('hasAvatar') is True})
    for item in groups:
        if not isinstance(item, dict):
            raise Failure('invalid_frame')
        group = {'ownServiceId': own, 'groupId': group_id(item.get('id')), 'name': text(item.get('name') or '', 512),
                 'description': text(item.get('description') or '', 8192),
                 'blocked': item.get('isBlocked') is True, 'isMember': item.get('isMember') is True,
                 'terminated': item.get('isTerminated') is True,
                 'inviteLink': text(item.get('groupInviteLink') or '', 2048)}
        for key in ('members', 'pendingMembers', 'requestingMembers', 'admins', 'banned'):
            group[key] = members(item.get(key, []))
        # Old partial snapshots can be displayed but cannot grant administration.
        group['complete'] = all(k in item for k in ('members', 'pendingMembers', 'requestingMembers',
            'permissionAddMember', 'permissionEditDetails', 'permissionSendMessage', 'isMember', 'isTerminated'))
        group['isAdmin'] = any(v['serviceId'] == own and v['isAdmin'] for v in group['members']) or any(v['serviceId'] == own for v in group['admins'])
        group['membership'] = ('terminated' if group['terminated'] else 'member' if group['isMember'] else
            'invited' if any(v['serviceId'] == own for v in group['pendingMembers']) else
            'requesting' if any(v['serviceId'] == own for v in group['requestingMembers']) else 'left')
        for key in ('permissionAddMember', 'permissionEditDetails', 'permissionSendMessage'):
            group[key] = item.get(key) if item.get(key) in ('EVERY_MEMBER', 'ONLY_ADMINS') else 'UNKNOWN'
        allowed = group['isMember'] and not group['blocked'] and not group['terminated']
        group['canSend'] = allowed and (group['permissionSendMessage'] == 'EVERY_MEMBER' or
            group['permissionSendMessage'] == 'ONLY_ADMINS' and group['isAdmin'])
        group['canAdmin'] = allowed and group['complete'] and group['isAdmin']
        group['canEdit'] = allowed and group['complete'] and (group['isAdmin'] or group['permissionEditDetails'] == 'EVERY_MEMBER')
        group['canAdd'] = allowed and group['complete'] and (group['isAdmin'] or group['permissionAddMember'] == 'EVERY_MEMBER')
        group['canAccept'] = group['complete'] and group['membership'] == 'invited' and not group['blocked']
        group['canLeave'] = group['membership'] in ('member', 'invited', 'requesting') and not group['terminated']
        result['groups'].append(group)
    result['contacts'].sort(key=lambda c: (c['serviceId'], c['number']))
    result['groups'].sort(key=lambda g: g['groupId'])
    return result


def access(store, account, row, contact, group):
    preference = store.db.execute('SELECT * FROM conversation_preferences WHERE conversation_id=?', (row['conversation_id'],)).fetchone()
    initiated = bool(preference and preference['initiated'])
    blocked = contact.get('blocked', False) if row['kind'] != 'group' else group.get('blocked', False)
    accepted = row['kind'] == 'note' or initiated or contact.get('profileSharing') is True
    if row['kind'] == 'group':
        state = group.get('membership', 'unknown')
        readable = state == 'member' and not blocked
        send = readable and group.get('canSend') is True
    else:
        state = 'accepted' if accepted else 'pending'
        readable = accepted and not blocked
        send = readable and not contact.get('unregistered', False) and not row['target'].startswith(('unresolved:', 'pni:'))
    return {'canSend': send, 'canRead': readable, 'requestState': 'blocked' if blocked else state,
            'blocked': blocked, 'hidden': bool(preference and preference['hidden']),
            'canSetExpiration': group.get('canEdit', False) if row['kind'] == 'group' else send,
            'avatar': avatar_url(store, account, row['target'])}


def avatar_url(store, account, target):
    row = store.db.execute('SELECT filename FROM directory_avatars WHERE account_id=? AND target=?', (account, target)).fetchone()
    return (store.media.root / 'avatars' / row[0]).as_uri() if row and store.media else ''


def cleanup_avatars(store):
    folder = store.media.root / 'avatars'
    os.close(directory(folder, private=True))
    live = {r[0] for r in store.db.execute('SELECT filename FROM directory_avatars')}
    for path in folder.iterdir():
        if path.name not in live and (path.is_file() or path.is_symlink()):
            path.unlink()


def system_event(store, account, cid, changes):
    """Typed local observation, no fake sender/text, no unread/receipt/toast."""
    mid = str(uuid.uuid4())
    store.db.execute("""INSERT INTO messages(message_id,conversation_id,author,sort_ms,direction,origin,kind,status,read_at_ms)
        VALUES(?,?,'',?,'incoming','local','system','received',?)""", (mid, cid, store.clock(), store.clock()))
    store.db.execute('INSERT INTO message_metadata VALUES(?,?)', (mid, json.dumps({'systemChanges': changes})))
    store.touch(account, cid, store.clock())
    store.notify_message(account, mid)


def install(store, account, result):
    for group in result['groups']:
        admin_ids = {m['serviceId'] for m in group['admins']}
        for member in group['members']:
            member['isAdmin'] = member['isAdmin'] or member['serviceId'] in admin_ids
    raw = json.dumps(result, ensure_ascii=False)
    if len(raw.encode()) > 512 * 1024:
        raise Failure('frame_too_large')
    old = store.directory(account)
    if old == result:
        return result
    with store.transaction():
        for group in result['groups']:
            previous = next((v for v in old['groups'] if v['groupId'] == group['groupId']), None)
            row = store.db.execute("SELECT conversation_id FROM conversations WHERE account_id=? AND kind='group' AND target=?", (account, group['groupId'])).fetchone()
            if row and previous:
                fields = [k for k in ('name', 'description', 'members', 'pendingMembers', 'requestingMembers',
                    'membership', 'permissionAddMember', 'permissionEditDetails', 'permissionSendMessage') if previous.get(k) != group.get(k)]
                if fields:
                    system_event(store, account, row[0], fields)
        for contact in result['contacts']:
            if contact['serviceId']:
                store.recipient(account, contact['serviceId'], contact['number'] or None)
        store.db.execute('INSERT INTO store_metadata VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value', ('directory:' + account, raw))
        store.changed('account.directory.changed', accountId=account)
        for row in store.db.execute('SELECT conversation_id FROM conversations WHERE account_id=?', (account,)):
            store.changed('conversation.changed', accountId=account, conversationId=row[0])
    return result


def preferences(store, account, params):
    cid = params.get('conversationId')
    store.conversation(account, cid)
    if type(params.get('hidden')) is not bool:
        raise Failure('invalid_request')
    with store.transaction():
        store.db.execute('INSERT INTO conversation_preferences(conversation_id,hidden) VALUES(?,?) ON CONFLICT(conversation_id) DO UPDATE SET hidden=excluded.hidden', (cid, params['hidden']))
        store.changed('conversation.changed', accountId=account, conversationId=cid)
    return store.conversation_item(account, cid)
