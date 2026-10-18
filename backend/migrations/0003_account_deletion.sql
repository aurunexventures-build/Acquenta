-- Opaque account IDs only: prevents old devices/tokens restoring deleted data.
CREATE TABLE IF NOT EXISTS account_deletions (
  user_id TEXT PRIMARY KEY,
  requested_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TRIGGER IF NOT EXISTS deleted_wallet_insert BEFORE INSERT ON wallet_records
WHEN EXISTS(SELECT 1 FROM account_deletions WHERE user_id=NEW.user_id)
BEGIN SELECT RAISE(ABORT,'ACCOUNT_DELETED'); END;
CREATE TRIGGER IF NOT EXISTS deleted_wallet_update BEFORE UPDATE ON wallet_records
WHEN EXISTS(SELECT 1 FROM account_deletions WHERE user_id=NEW.user_id)
BEGIN SELECT RAISE(ABORT,'ACCOUNT_DELETED'); END;
CREATE TRIGGER IF NOT EXISTS deleted_photo_insert BEFORE INSERT ON photos
WHEN EXISTS(SELECT 1 FROM account_deletions WHERE user_id=NEW.user_id)
BEGIN SELECT RAISE(ABORT,'ACCOUNT_DELETED'); END;
CREATE TRIGGER IF NOT EXISTS deleted_share_insert BEFORE INSERT ON card_shares
WHEN EXISTS(SELECT 1 FROM account_deletions WHERE user_id=NEW.user_id)
BEGIN SELECT RAISE(ABORT,'ACCOUNT_DELETED'); END;
CREATE TRIGGER IF NOT EXISTS deleted_share_update BEFORE UPDATE ON card_shares
WHEN EXISTS(SELECT 1 FROM account_deletions WHERE user_id=NEW.user_id)
BEGIN SELECT RAISE(ABORT,'ACCOUNT_DELETED'); END;
CREATE TRIGGER IF NOT EXISTS deleted_usage_insert BEFORE INSERT ON ai_usage
WHEN EXISTS(SELECT 1 FROM account_deletions WHERE user_id=NEW.user_id)
BEGIN SELECT RAISE(ABORT,'ACCOUNT_DELETED'); END;
