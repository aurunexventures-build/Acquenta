# Cloudflare + Firebase Architecture Guide for ContactCardBuilder

This backend module is designed to bridge **Firebase Authentication** with **Cloudflare D1** (Serverless SQLite) and **Cloudflare Workers AI + Vectorize** (Semantic Search).

## 1. Authentication Flow
1. User logs in on the Flutter app using **Firebase Auth** (Google Sign-In, Apple Sign-In, or Email/Password).
2. Flutter client acquires the Firebase ID token:
   ```dart
   final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
   ```
3. Flutter sends this token in the `Authorization: Bearer <idToken>` header on all requests to the Cloudflare Worker.
4. The Cloudflare Worker verifies the token using Google's public JWKS endpoint (`https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com`).
5. The Worker extracts the `uid` and scopes all D1 queries to `WHERE user_id = ?`.

## 2. Cloudflare D1 Database
* **Schema**: Defined in [schema.sql](file:///Users/anitsingh/Downloads/AuruNex/ContactCardBuilder/backend/schema.sql).
* **Tables**:
  * `users`: Stores user identity and metadata.
  * `contact_cards`: Stores multiple visiting cards per user.
  * `saved_connections`: Stores received contacts stamped with event context, discussion notes, and tech stack tags.

## 3. Extended Semantic Search with Cloudflare Workers AI & Vectorize
When saving or updating a connection in the Worker:
1. Concatenate context text:
   `"${full_name} | ${role} @ ${company} | Event: ${event_name} | Notes: ${discussion_notes} | Skills: ${tech_stack}"`
2. Generate 384-dimension dense embedding via Cloudflare Workers AI:
   ```javascript
   const embedding = await env.AI.run('@cf/baai/bge-small-en-v1.5', { text: [contextText] });
   ```
3. Upsert the vector into Cloudflare Vectorize index with the connection ID.
4. When a user runs a natural query (e.g. *"Cam's Tech Talk Flutter apps"*):
   - Worker embeds the query text.
   - Vectorize returns top-$K$ nearest neighbors by cosine similarity.
   - Worker fetches full records from D1 and returns them ranked to Flutter.
