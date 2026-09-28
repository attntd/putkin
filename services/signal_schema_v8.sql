-- Reception order is independent of sender clocks and later send receipts.
ALTER TABLE messages ADD COLUMN order_sequence INTEGER NOT NULL DEFAULT 0;
UPDATE messages SET order_sequence=rowid;
INSERT INTO store_metadata(key,value) SELECT 'message-order',CAST(COALESCE(MAX(order_sequence),0) AS TEXT) FROM messages;
CREATE INDEX messages_order ON messages(conversation_id,order_sequence DESC,message_id DESC);

ALTER TABLE interaction_outbox RENAME TO interaction_outbox_v7;
DROP INDEX interactions_queue;
DROP INDEX interactions_message;
CREATE TABLE interaction_outbox (
    operation_id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts,
    conversation_id TEXT NOT NULL REFERENCES conversations,
    message_id TEXT NOT NULL REFERENCES messages,
    kind TEXT NOT NULL CHECK(kind IN ('edit','reaction','delete','pin','unpin')),
    payload TEXT NOT NULL,
    state TEXT NOT NULL CHECK(state IN ('queued','sending','sent','failed','unknown','cancelled')),
    created_ms INTEGER NOT NULL,
    error_code TEXT NOT NULL DEFAULT '',
    safe_retry INTEGER NOT NULL DEFAULT 0,
    attempt INTEGER NOT NULL DEFAULT 0,
    sent_ms INTEGER,
    expires_at_ms INTEGER NOT NULL
);
INSERT INTO interaction_outbox SELECT * FROM interaction_outbox_v7;
DROP TABLE interaction_outbox_v7;
CREATE INDEX interactions_queue ON interaction_outbox(account_id,state,created_ms);
CREATE INDEX interactions_message ON interaction_outbox(message_id,created_ms);
CREATE TABLE message_pins (
    message_id TEXT PRIMARY KEY REFERENCES messages ON DELETE CASCADE,
    event_ms INTEGER NOT NULL,
    actor TEXT NOT NULL,
    active INTEGER NOT NULL,
    pin_order INTEGER NOT NULL,
    expires_at_ms INTEGER
);
CREATE INDEX pins_expiry ON message_pins(expires_at_ms) WHERE active=1;
CREATE TABLE forward_sources (
    operation_id TEXT PRIMARY KEY REFERENCES outbox ON DELETE CASCADE,
    source_message_id TEXT NOT NULL,
    version_ms INTEGER NOT NULL
);
PRAGMA user_version=8;
