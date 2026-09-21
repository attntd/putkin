-- S09: immutable per-message retention, independently of conversation defaults.
ALTER TABLE messages ADD COLUMN expiration_seconds INTEGER NOT NULL DEFAULT 0;
ALTER TABLE messages ADD COLUMN expiration_start_ms INTEGER;
ALTER TABLE messages ADD COLUMN hidden_local INTEGER NOT NULL DEFAULT 0;
ALTER TABLE interaction_outbox RENAME TO interaction_outbox_v5;
DROP INDEX interactions_queue;
DROP INDEX interactions_message;
CREATE TABLE interaction_outbox (
    operation_id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts,
    conversation_id TEXT NOT NULL REFERENCES conversations,
    message_id TEXT NOT NULL REFERENCES messages,
    kind TEXT NOT NULL CHECK(kind IN ('edit','reaction','delete')),
    payload TEXT NOT NULL,
    state TEXT NOT NULL CHECK(state IN ('queued','sending','sent','failed','unknown','cancelled')),
    created_ms INTEGER NOT NULL,
    error_code TEXT NOT NULL DEFAULT '',
    safe_retry INTEGER NOT NULL DEFAULT 0,
    attempt INTEGER NOT NULL DEFAULT 0,
    sent_ms INTEGER,
    expires_at_ms INTEGER NOT NULL
);
INSERT INTO interaction_outbox SELECT * FROM interaction_outbox_v5;
DROP TABLE interaction_outbox_v5;
CREATE INDEX interactions_queue ON interaction_outbox(account_id,state,created_ms);
CREATE INDEX interactions_message ON interaction_outbox(message_id,created_ms);
PRAGMA user_version=6;
