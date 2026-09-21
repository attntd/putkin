-- Directory mutations have their own durable identity; they are never replayed.
CREATE TABLE directory_operations (
    operation_id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts,
    kind TEXT NOT NULL,
    target TEXT NOT NULL DEFAULT '',
    state TEXT NOT NULL,
    fingerprint TEXT NOT NULL,
    baseline TEXT NOT NULL DEFAULT '[]',
    candidates TEXT NOT NULL DEFAULT '[]',
    error_code TEXT NOT NULL DEFAULT '',
    created_ms INTEGER NOT NULL
);
CREATE INDEX directory_operations_account ON directory_operations(account_id,created_ms);
CREATE TABLE conversation_preferences (
    conversation_id TEXT PRIMARY KEY REFERENCES conversations ON DELETE CASCADE,
    initiated INTEGER NOT NULL DEFAULT 0,
    hidden INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE directory_avatars (
    account_id TEXT NOT NULL REFERENCES accounts,
    target TEXT NOT NULL,
    filename TEXT NOT NULL,
    PRIMARY KEY(account_id,target)
);
PRAGMA user_version=7;
