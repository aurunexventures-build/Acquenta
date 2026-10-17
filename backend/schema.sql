-- Cloudflare D1 Database Schema for ContactCardBuilder
-- Supports User Cards, Saved Connections, Event Context, and Vector Embeddings for Search

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY, -- Firebase Auth UID
    email TEXT NOT NULL,
    display_name TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS contact_cards (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'professional', -- professional, personal, sideProject, event, custom
    full_name TEXT NOT NULL,
    headline TEXT,
    company TEXT,
    role TEXT,
    email TEXT,
    phone TEXT,
    location TEXT,
    bio TEXT,
    tech_stack TEXT, -- JSON array of strings: '["Flutter", "Android", "Cloudflare"]'
    links TEXT, -- JSON array of CardLink objects
    theme_color_hex TEXT DEFAULT '#2563EB',
    is_default INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS saved_connections (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL, -- Owner who saved this connection
    full_name TEXT NOT NULL,
    role TEXT,
    company TEXT,
    headline TEXT,
    email TEXT,
    phone TEXT,
    avatar_url TEXT,
    tech_stack TEXT, -- JSON array of strings
    links TEXT, -- JSON array of CardLink objects
    event_name TEXT NOT NULL,
    event_location TEXT,
    event_date DATETIME NOT NULL,
    discussion_notes TEXT,
    event_tags TEXT, -- JSON array of strings
    embedding_id TEXT, -- Vector ID in Cloudflare Vectorize (for AI semantic search)
    is_favorite INTEGER DEFAULT 0,
    saved_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Indexes for lightning fast searching across text fields
CREATE INDEX IF NOT EXISTS idx_cards_user ON contact_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_connections_user ON saved_connections(user_id);
CREATE INDEX IF NOT EXISTS idx_connections_event ON saved_connections(event_name);
