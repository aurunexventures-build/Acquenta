-- Stop an in-flight sync from recreating identity metadata after deletion.
CREATE TRIGGER IF NOT EXISTS deleted_identity_insert BEFORE INSERT ON users
WHEN EXISTS(SELECT 1 FROM account_deletions WHERE user_id=NEW.id)
BEGIN SELECT RAISE(ABORT,'ACCOUNT_DELETED'); END;
CREATE TRIGGER IF NOT EXISTS deleted_identity_update BEFORE UPDATE ON users
WHEN EXISTS(SELECT 1 FROM account_deletions WHERE user_id=NEW.id)
BEGIN SELECT RAISE(ABORT,'ACCOUNT_DELETED'); END;
