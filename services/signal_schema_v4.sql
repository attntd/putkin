-- Media ownership is separate from protocol attachment identities.
CREATE TABLE media_files (
    attachment_id TEXT PRIMARY KEY REFERENCES attachments ON DELETE CASCADE,
    filename TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'pending',
    error_code TEXT NOT NULL DEFAULT '',
    extension TEXT NOT NULL DEFAULT '',
    thumbnail INTEGER NOT NULL DEFAULT 0,
    preview INTEGER NOT NULL DEFAULT 0,
    voice_note INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE draft_attachments (
    conversation_id TEXT NOT NULL REFERENCES conversations,
    attachment_id TEXT NOT NULL UNIQUE REFERENCES attachments ON DELETE CASCADE,
    created_ms INTEGER NOT NULL,
    PRIMARY KEY(conversation_id, attachment_id)
);
CREATE TABLE media_cli_gc (cli_id TEXT PRIMARY KEY);
CREATE TRIGGER attachment_cli_gc AFTER DELETE ON attachments
WHEN OLD.cli_id NOT LIKE 'local:%'
BEGIN
    INSERT OR IGNORE INTO media_cli_gc VALUES(OLD.cli_id);
END;
PRAGMA user_version=4;
