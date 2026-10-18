-- Private reusable source details; independent of owned cards and their limits.
CREATE TABLE IF NOT EXISTS account_profiles (
  user_id TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  version INTEGER NOT NULL
);
CREATE TRIGGER IF NOT EXISTS deleted_profile_insert BEFORE INSERT ON account_profiles
WHEN EXISTS(SELECT 1 FROM account_deletions WHERE user_id=NEW.user_id)
BEGIN SELECT RAISE(ABORT,'ACCOUNT_DELETED'); END;
CREATE TRIGGER IF NOT EXISTS deleted_profile_update BEFORE UPDATE ON account_profiles
WHEN EXISTS(SELECT 1 FROM account_deletions WHERE user_id=NEW.user_id)
BEGIN SELECT RAISE(ABORT,'ACCOUNT_DELETED'); END;
