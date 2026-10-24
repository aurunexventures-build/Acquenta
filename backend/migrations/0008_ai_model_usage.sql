-- Company-wide counters are intentionally independent of user/account records.
CREATE TABLE IF NOT EXISTS ai_model_usage (
 day TEXT NOT NULL, provider TEXT NOT NULL, model TEXT NOT NULL,
 calls INTEGER NOT NULL DEFAULT 0, succeeded INTEGER NOT NULL DEFAULT 0, failed INTEGER NOT NULL DEFAULT 0,
 input_tokens INTEGER NOT NULL DEFAULT 0, output_tokens INTEGER NOT NULL DEFAULT 0, token_responses INTEGER NOT NULL DEFAULT 0,
 audio_seconds REAL NOT NULL DEFAULT 0, audio_responses INTEGER NOT NULL DEFAULT 0, characters INTEGER NOT NULL DEFAULT 0,
 first_at TEXT NOT NULL, last_at TEXT NOT NULL,
 PRIMARY KEY(day,provider,model)
);
CREATE TABLE IF NOT EXISTS ai_provider_quota (
 provider TEXT NOT NULL, model TEXT NOT NULL, observed_at TEXT NOT NULL, headers TEXT NOT NULL,
 PRIMARY KEY(provider,model)
);
