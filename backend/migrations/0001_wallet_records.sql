-- Additive migration. Existing prototype tables remain untouched.
CREATE TABLE IF NOT EXISTS wallet_records (
  user_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('connection', 'card')),
  id TEXT NOT NULL,
  payload TEXT NOT NULL,
  version INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  indexed_version INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, kind, id)
);
CREATE INDEX IF NOT EXISTS wallet_records_owner ON wallet_records(user_id, kind, deleted);
CREATE TABLE IF NOT EXISTS card_shares (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  card_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  UNIQUE(user_id, card_id)
);
-- Copy the original prototype wallet into the versioned store without losing links/notes.
INSERT OR IGNORE INTO wallet_records(user_id, kind, id, payload, version)
SELECT user_id, 'connection', id, json_object(
  'id', id, 'fullName', full_name, 'role', coalesce(role,''),
  'company', coalesce(company,''), 'headline', coalesce(headline,''),
  'email', coalesce(email,''), 'phone', coalesce(phone,''),
  'avatarUrl', coalesce(avatar_url,''),
  'techStack', json(coalesce(tech_stack,'[]')), 'links', json(coalesce(links,'[]')),
  'eventContext', json_object('eventName', event_name, 'location', coalesce(event_location,''),
    'date', event_date, 'notes', coalesce(discussion_notes,''), 'tags', json(coalesce(event_tags,'[]'))),
  'savedAt', saved_at, 'updatedAt', saved_at, 'isFavorite', json(case when is_favorite = 1 then 'true' else 'false' end)
), coalesce(unixepoch(saved_at)*1000,1) FROM saved_connections;
INSERT OR IGNORE INTO wallet_records(user_id, kind, id, payload, version)
SELECT user_id, 'card', id, json_object(
  'id', id, 'title', title, 'category', category, 'fullName', full_name,
  'headline', coalesce(headline,''), 'company', coalesce(company,''), 'role', coalesce(role,''),
  'email', coalesce(email,''), 'phone', coalesce(phone,''), 'location', coalesce(location,''),
  'bio', coalesce(bio,''), 'techStack', json(coalesce(tech_stack,'[]')), 'links', json(coalesce(links,'[]')),
  'themeColorHex', theme_color_hex, 'isDefault', json(case when is_default = 1 then 'true' else 'false' end),
  'createdAt', created_at, 'updatedAt', updated_at
), coalesce(unixepoch(updated_at)*1000,1) FROM contact_cards;
CREATE TABLE IF NOT EXISTS ai_usage (
  user_id TEXT NOT NULL,
  day TEXT NOT NULL,
  calls INTEGER NOT NULL,
  PRIMARY KEY(user_id,day)
);
