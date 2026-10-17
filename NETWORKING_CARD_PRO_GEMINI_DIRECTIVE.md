# ENGINEERING DIRECTIVE: CONTEXT-AWARE MEMORY RECALL & VIRTUAL CARD PLATFORM

**Application Name:** Networking Card Pro  
**Target Assignee:** Anti-Gravity  
**Target Codebase:** `/ContactCardBuilder` (Flutter cross-platform client)  
**Infrastructure Stack:** Cloudflare Edge (Workers, D1, Vectorize, Workers AI) + Firebase Authentication  
**Status:** Architecture Approval & Phase 2 Execution Directive  

---

## 1. Executive Summary & Problem Scope

The initial Flutter MVP established core multi-persona cards, RFC vCard generation, and local weighted token scoring. However, in real-world networking scenarios, users attend high-density conferences and forget names. A year later, they search conversational concepts (e.g., *"the developer I met at Cam's meetup who builds mobile frontends"*).

Anti-Gravity must transition `Networking Card Pro` from a static digital card repository into an **Offline-First Neural Networking Copilot**. Key requirements include:
1. Low-friction voice and vision capture in noisy venues.
2. Two-stage hybrid search combining local SQLite FTS5 with cloud semantic vector embeddings.
3. Bidirectional delta synchronization between Drift (SQLite) and Cloudflare D1.
4. Reciprocal sharing allowing card recipients to beam their contact details back without installing an app.

---

## 2. Feature & Protocol Specifications

### 2.1 The Reciprocal Memory Drop & Native Context Stamping
* **Web Card Landing Page:** Cards shared via QR code, NFC, or wallet pass open a web URL (`https://card.domain.com/c/:cardId?event=:eventId`).
* **Reciprocal Capture Form:** Position a 5-second form directly below the "Save Contact" button: *"Share your details back with [User]"* (Fields: Full Name, Email/LinkedIn, Quick Note). Submissions push an interaction record into the user's Cloudflare D1 inbox.
* **Native vCard Context:** Upgrade `VCardService` so that every exported contact auto-populates standard `NOTE:` and `CATEGORIES:` fields:
  ```text
  NOTE:Met at Cam's Tech Talk 2026. Discussion: Flutter architecture, message queues, and cross-platform UI. Stack: Flutter, Dart, RabbitMQ, Go.
  CATEGORIES:Cam's Tech Talk 2026,Flutter,Dart,Networking
  ```
* **Universal NFC Flasher:** Integrate `nfc_manager` to format and write the active profile URL to any generic NTAG213, NTAG215, or NTAG216 chip.

### 2.2 Multimodal Venue Capture (Low Friction)
* **5-Second Voice Memo:** Tap-and-hold mic action records compressed audio (Opus/m4a) and transmits it to `/api/v1/capture/memo`. The endpoint invokes `@cf/openai/whisper` followed by `@cf/meta/llama-3.1-8b-instruct` to extract structured JSON:
  ```json
  {
    "name": "Anit Singh",
    "company": "AuruNex",
    "role": "Mobile Architect",
    "discussion_summary": "Building offline-first contact builder on Android & Flutter",
    "tags": ["Flutter", "Android", "Cloudflare", "AI Agents"],
    "action_item": "Review their GitHub repo"
  }
  ```
* **Badge / Business Card OCR:** On-device OCR via `google_mlkit_text_recognition` parses physical badges and paper cards into contact fields via regex heuristics.
* **Calendar Geofencing:** Auto-activate **Active Event Mode** if device calendar entries match conference or summit keywords during the active time window.

---

## 3. Database Architecture: Two-Stage Hybrid Search

```
                 ┌─────────────────────────────────────────┐
                 │             Incoming Query              │
                 │ "mobile dev building side projects at   │
                 │            Cam's tech talk"             │
                 └────────────────────┬────────────────────┘
                                      │
               ┌──────────────────────┴──────────────────────┐
               │                                             │
               ▼                                             ▼
┌─────────────────────────────┐               ┌─────────────────────────────┐
│    Stage 1: L1 Local FTS5   │               │    Stage 2: L2 Cloud Vector │
│   (SQLite / Drift Engine)   │               │   (Cloudflare Workers AI)   │
│  - Matches keyword stems    │               │  - Worker embeds query via  │
│  - Instant (<5ms, Offline)  │               │    bge-small-en-v1.5        │
│  - Returns top 20 candidates│               │  - Vectorize cosine match   │
└──────────────┬──────────────┘               └──────────────┬──────────────┘
               │                                             │
               └──────────────────────┬──────────────────────┘
                                      │
                                      ▼
                    ┌──────────────────────────────────┐
                    │      Reciprocal Rank Fusion      │
                    │  Merges scores with k = 60       │
                    └─────────────────┬────────────────┘
                                      │
                                      ▼
                    ┌──────────────────────────────────┐
                    │  Ranked Results + Match Context  │
                    │ ("Why this card was matched")    │
                    └──────────────────────────────────┘
```

### 3.1 Local SQLite (Drift) & FTS5 Implementation
Deprecate SharedPreferences as primary storage. Migrate to `drift` with native SQLite FTS5 virtual tables:

```dart
// lib/core/database/database.dart
import 'package:drift/drift.dart';

class Interactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get contactName => text().withLength(min: 1, max: 100)();
  TextColumn get company => text().nullable()();
  TextColumn get eventName => text()();
  IntColumn get eventDate => integer()();
  TextColumn get location => text().nullable()();
  TextColumn get notes => text()();
  TextColumn get tags => text()();
  TextColumn get contactDetailsJson => text()();
  IntColumn get updatedAt => integer()();
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Interactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('''
        CREATE VIRTUAL TABLE interactions_fts USING fts5(
          id UNINDEXED,
          contact_name,
          company,
          event_name,
          notes,
          tags,
          tokenize = 'porter unicode61'
        );
      ''');
      await customStatement('''
        CREATE TRIGGER interactions_ai AFTER INSERT ON interactions BEGIN
          INSERT INTO interactions_fts(id, contact_name, company, event_name, notes, tags)
          VALUES (new.id, new.contact_name, new.company, new.event_name, new.notes, new.tags);
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER interactions_au AFTER UPDATE ON interactions BEGIN
          DELETE FROM interactions_fts WHERE id = old.id;
          INSERT INTO interactions_fts(id, contact_name, company, event_name, notes, tags)
          VALUES (new.id, new.contact_name, new.company, new.event_name, new.notes, new.tags);
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER interactions_ad AFTER DELETE ON interactions BEGIN
          DELETE FROM interactions_fts WHERE id = old.id;
        END;
      ''');
    },
  );
}
```

### 3.2 Reciprocal Rank Fusion (RRF) Formula
Combine rank lists from Stage 1 (Local FTS5) and Stage 2 (Cloudflare Vectorize) using RRF:

$$\text{RRF\_Score}(d) = \sum_{m \in M} \frac{1}{k + r_m(d)}$$

Where $k = 60$, $M$ represents the search models $\{ \text{FTS5}, \text{Vectorize} \}$, and $r_m(d)$ represents document rank in that model. If offline, the client defaults strictly to Stage 1.

---

## 4. Cloudflare Edge Backend Specification

### 4.1 Firebase Authentication via JWKS
Validate Firebase ID tokens inside the Worker against Google's public JWKS without requiring the Firebase Admin SDK:

```typescript
// worker/src/auth.ts
import { createRemoteJWKSet, jwtVerify } from 'jose';

const FIREBASE_PROJECT_ID = "networking-card-pro";
const GOOGLE_JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")
);

export async function verifyAuth(request: Request): Promise<string> {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    throw new Error("Missing or invalid authorization header.");
  }
  const token = authHeader.substring(7);
  const { payload } = await jwtVerify(token, GOOGLE_JWKS, {
    issuer: `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`,
    audience: FIREBASE_PROJECT_ID,
  });
  if (!payload.sub) throw new Error("Invalid token UID.");
  return payload.sub;
}
```

### 4.2 D1 Relational Schema (`schema.sql`)
```sql
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS contact_cards (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    full_name TEXT NOT NULL,
    headline TEXT,
    company TEXT,
    email TEXT,
    phone TEXT,
    skills_json TEXT NOT NULL,
    links_json TEXT NOT NULL,
    theme_config TEXT,
    updated_at INTEGER NOT NULL,
    is_deleted INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS interactions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    contact_name TEXT NOT NULL,
    company TEXT,
    event_name TEXT NOT NULL,
    event_date INTEGER NOT NULL,
    location TEXT,
    notes TEXT NOT NULL,
    tags_json TEXT NOT NULL,
    contact_details_json TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    is_deleted INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_interactions_sync ON interactions(user_id, updated_at);
```

### 4.3 Cloudflare Worker Core Handlers (`src/index.ts`)
```typescript
import { verifyAuth } from './auth';

export interface Env {
  DB: D1Database;
  VECTORIZE: VectorizeIndex;
  AI: any;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);
      const userId = await verifyAuth(request);

      // Delta Synchronization
      if (url.pathname === "/api/v1/sync" && request.method === "POST") {
        const { lastSyncedAt, mutations } = await request.json();

        for (const item of mutations) {
          await env.DB.prepare(`
            INSERT INTO interactions (id, user_id, contact_name, company, event_name, event_date, location, notes, tags_json, contact_details_json, updated_at, is_deleted)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              contact_name=excluded.contact_name,
              company=excluded.company,
              event_name=excluded.event_name,
              notes=excluded.notes,
              tags_json=excluded.tags_json,
              contact_details_json=excluded.contact_details_json,
              updated_at=excluded.updated_at,
              is_deleted=excluded.is_deleted
          `).bind(
            item.id, userId, item.contactName, item.company, item.eventName,
            item.eventDate, item.location, item.notes, JSON.stringify(item.tags),
            JSON.stringify(item.details), item.updatedAt, item.isDeleted ? 1 : 0
          ).run();

          if (!item.isDeleted) {
            const textToEmbed = `${item.contactName} ${item.company || ''} ${item.eventName} ${item.tags.join(' ')} ${item.notes}`;
            const embedding = await env.AI.run("@cf/baai/bge-small-en-v1.5", { text: [textToEmbed] });
            await env.VECTORIZE.upsert([{
              id: item.id,
              values: embedding.data[0],
              namespace: userId,
              metadata: { eventName: item.eventName, contactName: item.contactName }
            }]);
          } else {
            await env.VECTORIZE.deleteByIds([item.id]);
          }
        }

        const changes = await env.DB.prepare(`
          SELECT * FROM interactions WHERE user_id = ? AND updated_at > ?
        `).bind(userId, lastSyncedAt).all();

        return Response.json({ success: true, changes: changes.results, timestamp: Date.now() });
      }

      // Cloud Semantic Search
      if (url.pathname === "/api/v1/search/semantic" && request.method === "POST") {
        const { query } = await request.json();
        const embeddingRes = await env.AI.run("@cf/baai/bge-small-en-v1.5", { text: [query] });
        const matches = await env.VECTORIZE.query(embeddingRes.data[0], {
          topK: 20,
          namespace: userId
        });
        return Response.json({ success: true, matches: matches.matches });
      }

      // Voice Memo Ingest
      if (url.pathname === "/api/v1/capture/memo" && request.method === "POST") {
        const formData = await request.formData();
        const audioFile = formData.get("audio") as File;
        const audioBuffer = await audioFile.arrayBuffer();

        const transcription = await env.AI.run("@cf/openai/whisper", {
          audio: [...new Uint8Array(audioBuffer)]
        });

        const prompt = `Extract networking contact data to JSON: {"name": string|null, "company": string|null, "role": string|null, "discussion_summary": string, "tags": string[], "action_item": string|null}. Transcript: "${transcription.text}"`;
        const extraction = await env.AI.run("@cf/meta/llama-3.1-8b-instruct", { prompt, max_tokens: 512 });

        return Response.json({ rawText: transcription.text, structured: JSON.parse(extraction.response) });
      }

      return new Response("Not Found", { status: 404 });
    } catch (err: any) {
      return new Response(JSON.stringify({ error: err.message }), { status: 500 });
    }
  }
};
```

---

## 5. UI/UX Directives: The "Neural Rolodex"

1. **Card Tilt Physics:** Implement a custom GLSL fragment shader mapped to device gyro coordinates (`sensors_plus`) for an anisotropic metallic sheen when the phone tilts.
2. **Radial NFC Feedback:** Render an expanding circular shader pulse from the device's NFC antenna location upon tag contact, accompanied by `HapticFeedback.mediumImpact()`.
3. **Constellation Graph Mode:** Provide a toggle from the standard list into a 2D spring-damper node graph linking contacts by shared events, company, or tech stack.
4. **Context Explanation Badges:** Every result on the Smart Recall screen must include a pill explaining why it surfaced:
   - Amber pill: *"Matched on Topic: Message Queues"*
   - Cyan pill: *"Matched on Skill: Flutter"*
   - Purple pill: *"Matched on Event: Cam's Tech Talk 2026"*

---

## 6. Phase 2 Sprint Backlog & Milestones

### MILESTONE 1: Local SQLite Drift & FTS5
* 1.1: Add `drift`, `drift_flutter`, `sqlite3` dependencies to `pubspec.yaml`.
* 1.2: Implement `AppDatabase` with `Interactions` table & FTS5 virtual table.
* 1.3: Migrate `StorageService` from `SharedPreferences` to Drift DAOs.
* 1.4: Verify tests pass with: `flutter test`.

### MILESTONE 2: Cloudflare Worker Backend
* 2.1: Initialize worker project with `wrangler`, TypeScript, and `jose`.
* 2.2: Apply D1 schema and configure Vectorize index (384 dims, cosine).
* 2.3: Implement `/api/v1/sync`, `/api/v1/search/semantic`, and `/api/v1/capture/memo`.

### MILESTONE 3: Client Sync & Hybrid Search
* 3.1: Implement `SyncService` with delta timestamp tracking.
* 3.2: Implement `HybridSearchService` combining local FTS5 with Vectorize via RRF.

### MILESTONE 4: Multimodal Capture & Viral Sharing
* 4.1: Floating action 5-second voice memo with Whisper / Llama 3.1 parsing.
* 4.2: In-app NFC writer (`nfc_manager`) for blank NFC chips.
* 4.3: Web card landing page with 5-second reciprocal contact capture.