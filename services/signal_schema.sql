-- Migration 0 -> 1. Executed statement by statement in one transaction.
CREATE TABLE accounts (
    account_id TEXT PRIMARY KEY,
    service_id TEXT NOT NULL UNIQUE,
    cli_address TEXT NOT NULL
);
CREATE TABLE store_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE recipients (
    recipient_id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts,
    service_id TEXT NOT NULL,
    resolved INTEGER NOT NULL,
    UNIQUE(account_id, service_id)
);
CREATE TABLE recipient_aliases (
    recipient_id TEXT NOT NULL REFERENCES recipients ON DELETE CASCADE,
    alias TEXT NOT NULL,
    PRIMARY KEY(recipient_id, alias)
);
CREATE TABLE conversations (
    conversation_id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts,
    kind TEXT NOT NULL CHECK(kind IN ('direct', 'group', 'note')),
    peer_id TEXT REFERENCES recipients,
    target TEXT NOT NULL,
    title TEXT NOT NULL DEFAULT '',
    activity_ms INTEGER NOT NULL DEFAULT 0,
    expiration_seconds INTEGER NOT NULL DEFAULT 0,
    expiration_version INTEGER NOT NULL DEFAULT 0,
    UNIQUE(account_id, kind, target)
);
CREATE INDEX conversations_page ON conversations(account_id, activity_ms DESC, conversation_id DESC);
CREATE TABLE messages (
    message_id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations,
    author TEXT NOT NULL,
    sent_ms INTEGER,
    sort_ms INTEGER NOT NULL,
    source_device INTEGER,
    server_received_ms INTEGER,
    direction TEXT NOT NULL CHECK(direction IN ('incoming', 'outgoing')),
    origin TEXT NOT NULL CHECK(origin IN ('remote', 'phone', 'local')),
    kind TEXT NOT NULL,
    body TEXT,
    fingerprint TEXT,
    status TEXT NOT NULL,
    conflict INTEGER NOT NULL DEFAULT 0,
    expires_at_ms INTEGER,
    edited_ms INTEGER,
    UNIQUE(conversation_id, author, sent_ms)
);
CREATE INDEX messages_page ON messages(conversation_id, sort_ms DESC, message_id DESC);
CREATE INDEX messages_expiry ON messages(expires_at_ms) WHERE expires_at_ms IS NOT NULL;
CREATE TABLE tombstones (
    conversation_id TEXT NOT NULL REFERENCES conversations,
    author TEXT NOT NULL,
    sent_ms INTEGER NOT NULL,
    reason TEXT NOT NULL,
    PRIMARY KEY(conversation_id, author, sent_ms)
);
CREATE TABLE attachments (
    attachment_id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts,
    cli_id TEXT NOT NULL,
    content_type TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    UNIQUE(account_id, cli_id)
);
CREATE TABLE attachment_refs (
    message_id TEXT NOT NULL REFERENCES messages ON DELETE CASCADE,
    attachment_id TEXT NOT NULL REFERENCES attachments ON DELETE CASCADE,
    PRIMARY KEY(message_id, attachment_id)
);
-- Only non-content metadata until S06/S08; no raw envelopes or edit text.
CREATE TABLE pending_events (
    event_key TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts,
    conversation_id TEXT REFERENCES conversations,
    kind TEXT NOT NULL,
    author TEXT NOT NULL,
    target_ms INTEGER NOT NULL,
    event_ms INTEGER NOT NULL,
    expires_at_ms INTEGER NOT NULL
);
CREATE INDEX pending_target ON pending_events(conversation_id, author, target_ms);
CREATE INDEX pending_expiry ON pending_events(expires_at_ms);
CREATE TABLE drafts (
    conversation_id TEXT PRIMARY KEY REFERENCES conversations,
    body TEXT NOT NULL,
    revision INTEGER NOT NULL
);
CREATE TABLE outbox (
    operation_id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts,
    conversation_id TEXT NOT NULL REFERENCES conversations,
    message_id TEXT NOT NULL UNIQUE REFERENCES messages,
    state TEXT NOT NULL CHECK(state IN ('queued','sending','sent','failed','unknown','cancelled')),
    created_ms INTEGER NOT NULL,
    error_code TEXT NOT NULL DEFAULT '',
    safe_retry INTEGER NOT NULL DEFAULT 0,
    attempt INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX outbox_queue ON outbox(account_id, state, created_ms, operation_id);
CREATE TABLE outbox_attempts (
    operation_id TEXT NOT NULL REFERENCES outbox,
    attempt INTEGER NOT NULL,
    state TEXT NOT NULL,
    sent_ms INTEGER,
    started_ms INTEGER NOT NULL,
    PRIMARY KEY(operation_id, attempt)
);
CREATE TABLE outbox_results (
    operation_id TEXT NOT NULL,
    attempt INTEGER NOT NULL,
    recipient TEXT NOT NULL,
    result_type TEXT NOT NULL,
    retry_after_seconds INTEGER,
    PRIMARY KEY(operation_id, attempt, recipient),
    FOREIGN KEY(operation_id, attempt) REFERENCES outbox_attempts
);
PRAGMA user_version=1;
