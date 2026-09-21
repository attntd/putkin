-- Migration 2 -> 3. Protocol read keys are distinct from remote receipts.
ALTER TABLE messages ADD COLUMN read_at_ms INTEGER;
CREATE INDEX messages_unread ON messages(conversation_id, read_at_ms) WHERE direction='incoming';
CREATE INDEX messages_receipt_target ON messages(author, sent_ms, direction);
CREATE TABLE message_recipients (
    message_id TEXT NOT NULL REFERENCES messages ON DELETE CASCADE,
    recipient TEXT NOT NULL,
    PRIMARY KEY(message_id, recipient)
);
CREATE TABLE receipt_reports (
    account_id TEXT NOT NULL REFERENCES accounts,
    recipient TEXT NOT NULL,
    target_ms INTEGER NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('delivery','read','viewed')),
    event_ms INTEGER NOT NULL,
    expires_at_ms INTEGER,
    PRIMARY KEY(account_id, recipient, target_ms, kind)
);
CREATE INDEX receipt_expiry ON receipt_reports(expires_at_ms);
CREATE TABLE read_markers (
    account_id TEXT NOT NULL REFERENCES accounts,
    author TEXT NOT NULL,
    target_ms INTEGER NOT NULL,
    read_ms INTEGER NOT NULL,
    expires_at_ms INTEGER,
    PRIMARY KEY(account_id, author, target_ms)
);
CREATE INDEX read_marker_expiry ON read_markers(expires_at_ms);
CREATE TABLE read_queue (
    account_id TEXT NOT NULL REFERENCES accounts,
    author TEXT NOT NULL,
    target_ms INTEGER NOT NULL,
    state TEXT NOT NULL CHECK(state IN ('queued','sending','submitted','unknown','failed')),
    PRIMARY KEY(account_id, author, target_ms)
);
-- S02 retained the exact identifiers and timestamps, without bodies.
INSERT INTO receipt_reports
    SELECT account_id,author,target_ms,kind,MAX(event_ms),MAX(expires_at_ms)
    FROM pending_events WHERE kind IN ('delivery','read','viewed')
    GROUP BY account_id,author,target_ms,kind;
INSERT INTO read_markers
    SELECT account_id,author,target_ms,MAX(event_ms),MAX(expires_at_ms)
    FROM pending_events WHERE kind='read_sync' GROUP BY account_id,author,target_ms;
DELETE FROM pending_events WHERE kind IN ('delivery','read','viewed','read_sync');
INSERT OR IGNORE INTO message_recipients
    SELECT o.message_id,r.recipient FROM outbox o JOIN outbox_results r USING(operation_id)
    WHERE r.attempt=o.attempt;
PRAGMA user_version=3;
