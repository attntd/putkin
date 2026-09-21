-- Canonical message IDs stay stable; protocol timestamps address versions.
CREATE TABLE message_versions (
    conversation_id TEXT NOT NULL REFERENCES conversations,
    author TEXT NOT NULL,
    version_ms INTEGER NOT NULL,
    target_ms INTEGER,
    message_id TEXT REFERENCES messages ON DELETE CASCADE,
    body TEXT,
    metadata TEXT NOT NULL DEFAULT '{}',
    hidden INTEGER NOT NULL DEFAULT 0,
    expires_at_ms INTEGER,
    PRIMARY KEY(conversation_id, author, version_ms)
);
CREATE INDEX versions_message ON message_versions(message_id, version_ms);
CREATE INDEX versions_pending ON message_versions(conversation_id, author, target_ms) WHERE message_id IS NULL;
CREATE INDEX versions_expiry ON message_versions(expires_at_ms);
INSERT INTO message_versions(conversation_id,author,version_ms,message_id,body,hidden)
    SELECT conversation_id,author,sent_ms,message_id,body,kind NOT IN ('text','media') FROM messages WHERE sent_ms IS NOT NULL;
CREATE TABLE message_metadata (
    message_id TEXT PRIMARY KEY REFERENCES messages ON DELETE CASCADE,
    payload TEXT NOT NULL
);
CREATE TABLE message_reactions (
    conversation_id TEXT NOT NULL REFERENCES conversations,
    author TEXT NOT NULL,
    target_ms INTEGER NOT NULL,
    actor TEXT NOT NULL,
    event_ms INTEGER NOT NULL,
    emoji TEXT NOT NULL,
    removed INTEGER NOT NULL,
    message_id TEXT REFERENCES messages ON DELETE CASCADE,
    expires_at_ms INTEGER,
    PRIMARY KEY(conversation_id,author,target_ms,actor)
);
CREATE INDEX reactions_message ON message_reactions(message_id,actor,event_ms);
CREATE INDEX reactions_expiry ON message_reactions(expires_at_ms);
CREATE TABLE interaction_outbox (
    operation_id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts,
    conversation_id TEXT NOT NULL REFERENCES conversations,
    message_id TEXT NOT NULL REFERENCES messages,
    kind TEXT NOT NULL CHECK(kind IN ('edit','reaction')),
    payload TEXT NOT NULL,
    state TEXT NOT NULL CHECK(state IN ('queued','sending','sent','failed','unknown','cancelled')),
    created_ms INTEGER NOT NULL,
    error_code TEXT NOT NULL DEFAULT '',
    safe_retry INTEGER NOT NULL DEFAULT 0,
    attempt INTEGER NOT NULL DEFAULT 0,
    sent_ms INTEGER,
    expires_at_ms INTEGER NOT NULL
);
CREATE INDEX interactions_queue ON interaction_outbox(account_id,state,created_ms);
CREATE INDEX interactions_message ON interaction_outbox(message_id,created_ms);
CREATE TABLE version_recipients (
    message_id TEXT NOT NULL REFERENCES messages ON DELETE CASCADE,
    version_ms INTEGER NOT NULL,
    recipient TEXT NOT NULL,
    PRIMARY KEY(message_id,version_ms,recipient)
);
INSERT INTO version_recipients SELECT m.message_id,m.sent_ms,r.recipient FROM messages m
    JOIN message_recipients r USING(message_id) WHERE m.sent_ms IS NOT NULL;
ALTER TABLE drafts ADD COLUMN composition TEXT NOT NULL DEFAULT '{}';
PRAGMA user_version=5;
