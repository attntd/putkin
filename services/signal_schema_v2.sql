-- Migration 1 -> 2. Reply content moves into the existing outbox atomically.
CREATE TABLE reply_drafts (
    conversation_id TEXT PRIMARY KEY REFERENCES conversations,
    body TEXT NOT NULL,
    revision INTEGER NOT NULL,
    operation_id TEXT REFERENCES outbox
);
CREATE TABLE conversation_notifications (
    conversation_id TEXT PRIMARY KEY REFERENCES conversations,
    muted INTEGER NOT NULL CHECK(muted IN (0,1))
);
PRAGMA user_version=2;
