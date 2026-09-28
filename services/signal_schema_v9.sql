-- Local conversation organization; hidden is retained as the archive flag.
ALTER TABLE conversation_preferences ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0;
ALTER TABLE conversation_preferences ADD COLUMN marked_unread INTEGER NOT NULL DEFAULT 0;
PRAGMA user_version=9;
