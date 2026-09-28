"""Explicit forwarding through the existing durable outbox, preserving drafts."""
import uuid

from signal_events import identifier, integer
from signal_media import MAX_BATCH
from signal_transport import Failure


async def forward(bridge, params):
    store, account = bridge.store, bridge.account_id
    if not store or not store.healthy or params.get('accountId') != account:
        raise Failure('account_mismatch')
    if bridge.account_state != 'linked' or bridge.state not in ('ready', 'reconnecting'):
        raise Failure('account_unlinked')
    cid = params.get('conversationId')
    destination = params.get('targetConversationId')
    store.conversation(account, cid)
    if not store.conversation_item(account, destination)['canSend']:
        raise Failure('send_unavailable')
    values = params.get('messages')
    if not isinstance(values, list) or not 1 <= len(values) <= 100:
        raise Failure('invalid_request')
    targets = []
    for value in values:
        if not isinstance(value, dict):
            raise Failure('invalid_request')
        targets.append((identifier(value.get('messageId')), integer(value.get('versionTimestampMs'), minimum=1),
                        identifier(value.get('operationId'))))
    if len({v[0] for v in targets}) != len(targets) or len({v[2] for v in targets}) != len(targets):
        raise Failure('invalid_request')
    media = store.media
    async with bridge.media_lock:
        pending, operations, owned = [], [], []
        try:
            total = 0
            # Validate the whole selection before preparing files or enqueuing anything.
            for mid, version, operation in targets:
                old = store.db.execute("""SELECT f.*,o.account_id,o.conversation_id FROM forward_sources f
                    JOIN outbox o USING(operation_id) WHERE operation_id=?""", (operation,)).fetchone()
                if old:
                    if (old['account_id'], old['conversation_id'], old['source_message_id'], old['version_ms']) != (account, destination, mid, version):
                        raise Failure('operation_conflict')
                    operations.append(bridge.outbox.status(account, operation))
                    continue
                message = store.message(account, mid)
                if message['conversationId'] != cid or not message['canForward']:
                    raise Failure('message_unavailable')
                if message['versionTimestampMs'] != version:
                    raise Failure('version_conflict')
                if len(message['attachments']) > 8:
                    raise Failure('attachment_limit')
                total += sum(a['size_bytes'] for a in message['attachments'])
                if total > MAX_BATCH:
                    raise Failure('attachment_limit')
                pending.append((message, operation, []))
            for message, _, prepared in pending:
                for attachment in message['attachments']:
                    aid = str(uuid.uuid4())
                    owned.append(aid); media.active.add(aid)
                    prepared.append(await bridge.media_worker(media.prepare, attachment['url'], aid,
                        name=attachment['filename'], declared=attachment['content_type'], size=attachment['size_bytes']))
            if account != bridge.account_id or store is not bridge.store or not store.healthy:
                raise Failure('account_mismatch')
            if bridge.account_state != 'linked' or bridge.state not in ('ready', 'reconnecting'):
                raise Failure('account_unlinked')
            for message, _, _ in pending:
                current = store.message(account, message['messageId'])
                if not current['canForward'] or current['versionTimestampMs'] != message['versionTimestampMs']:
                    raise Failure('message_unavailable')
            if not store.conversation_item(account, destination)['canSend']:
                raise Failure('send_unavailable')
            with store.transaction():
                for message, operation, prepared in pending:
                    value = bridge.outbox.enqueue(account, {'conversationId': destination, 'text': message['text'] or '',
                        'styles': message['styles'], 'attachmentIds': [p['id'] for p in prepared], 'operationId': operation},
                        forwarded_attachments=prepared, forward_source=(message['messageId'], message['versionTimestampMs']),
                        transaction=False)
                    operations.append(value)
            bridge.wake_outbox.set()
            bridge.schedule_cleanup()
            return {'operations': operations}
        finally:
            media.active.difference_update(owned)
            if store.healthy and store is bridge.store:
                media.gc()
