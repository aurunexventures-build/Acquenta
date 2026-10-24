CREATE TABLE IF NOT EXISTS text_safety_checks(user_id TEXT NOT NULL,fingerprint TEXT NOT NULL,verdict TEXT NOT NULL,checked_at INTEGER NOT NULL,PRIMARY KEY(user_id,fingerprint));
CREATE TABLE IF NOT EXISTS text_safety_usage(month TEXT NOT NULL,day INTEGER NOT NULL,user_id TEXT NOT NULL,calls INTEGER NOT NULL,units INTEGER NOT NULL,PRIMARY KEY(month,day,user_id));
