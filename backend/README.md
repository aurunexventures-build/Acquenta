# Acquenta backend

Cloudflare Worker using Firebase ID tokens, D1, R2, Workers AI and Vectorize. The repository-root `wrangler.jsonc` is the single deployment configuration for the compiled Flutter web app and Worker API. Firebase handles authentication only; Cloudflare D1 is the application database.

## Endpoints

| Endpoint | Purpose | Access |
| --- | --- | --- |
| `GET /health` | Protocol and process status (not a database/AI availability probe) | Public |
| `POST /api/v1/sync` | Versioned full-record sync of cards, connections and deletion markers | Firebase |
| `POST /api/v1/cues/generate` | Rough text to editable JSON memory cues | Firebase |
| `POST /api/v1/photos?purpose=portrait` or `connection` | Bounded binary photo upload to R2 | Firebase |
| `GET /api/v1/photos/:id` | Owner-only photo retrieval | Firebase |
| `GET /api/v1/portraits/:id` | A shared portrait referenced by an active identity card | Opaque portrait reference |
| `POST /api/v1/search/semantic` | Embedding retrieval scoped to the user's wallet | Firebase |
| `POST /api/v1/cards/publish` | Explicitly create/update an online card URL | Firebase |
| `DELETE /api/v1/cards/publish` | Revoke an online card URL | Firebase |
| `GET /c/:token` | Published profile and reciprocal contact form | Public share token |
| `GET /api/v1/cards/shared/:token` | Import a published profile into the app | Public share token |
| `POST /api/v1/reciprocal` | Return contact details to a published card's owner | Public share token; per-IP/share throttle |

Cue requests accept a `conversation` array with up to three `{question, answer}` turns. The model sees the original note and prior answers, is instructed to avoid invented facts and repeated questions, and stops asking after three answers. The saved connection retains all answers for local and semantic recall. Text-to-speech is optional platform playback; it does not introduce another cloud AI provider.

The previous unused server audio endpoint is replaced by text cue generation: the app already obtains text through platform dictation. No audio upload or extra speech provider is required.

## Local checks

```sh
npm ci
npm run types
npm run typecheck
npm test
npm run deploy:check
```

The backend tests run the actual handler and SQL against Node SQLite, with an injected test authentication verifier and simulated AI/Vectorize bindings. The production export always verifies Firebase JWTs (RS256, project audience and issuer). No debug auth bypass exists in the deployed handler.

For a fresh local database:

```sh
npm run db:migrate:local
# From the repository root, build and preview both frontend and API:
cd ..
npm run dev
```

Workers AI and Vectorize require real bindings for live model calls; local handler tests simulate them without sending notes to a provider.

## Deploying this change

The ordered migrations now include `0000_legacy_schema.sql`, an idempotent bootstrap, so a fresh D1 database does not require a manual schema import. Existing prototype tables remain in place.

Create the `metcue-photos` R2 bucket before the first production deployment if it does not already exist (`npx wrangler r2 bucket create metcue-photos --config ../wrangler.jsonc`, from this backend directory). Keep the bucket private; public portrait access is mediated by the Worker.

Before applying a production migration, verify the current database schema against `schema.sql`, including the legacy `saved_connections.event_location` column. The additive migration copies legacy cards and connections into `wallet_records`; it does not modify or remove the legacy tables. Take a backup before applying it.

```sh
npx wrangler d1 export metcue-db --config ../wrangler.jsonc --remote --output /private/tmp/metcue-before-v2.sql
npx wrangler d1 migrations apply metcue-db --config ../wrangler.jsonc --remote
cd ..
npm run deploy
```

`npm run deploy` builds and publishes the matching Flutter web app and API together. Native releases use the same API. The existing Vectorize index must remain 384-dimensional with cosine distance. Its name and the existing database binding are preserved in the root `wrangler.jsonc`. New connection vectors use a SHA-256 ID incorporating the user's UID and are queried in that user's namespace. Old prototype vectors are ignored unless they resolve to an owned v2 record.

Do a signed-in acceptance check with synthetic data: scan a card, save a voice/text cue, organise it with the real model, review and save, allow automatic sync, then search using a paraphrase. Check a second account and a second device, deletion, revocation, and an offline save followed by reconnecting. Inspect generated cue quality with diverse professions and languages before making broad AI accuracy claims.

## Sync and recovery behaviour

- Entire connection JSON is stored: social links, avatar, all cues, raw text, event data and favourites. Own cards use the same sync store but are private until explicitly published.
- Composite primary keys isolate `(user_id, kind, id)` records. Queries for sync and search are owner-scoped.
- `updatedAt` is a millisecond version. Newer versions win; deletion wins a timestamp tie. Client updates use a monotonic local clock. Clocks over five minutes ahead are rejected. This is last-write-wins, not collaborative field-level editing; simultaneous offline edits to one record on different devices resolve to the latest timestamp.
- Deletion markers are retained and synced so stale devices cannot resurrect deleted records. A later explicit local save can restore one. Local edits/deletions made during a sync are merged rather than discarded.
- Up to 500 records of each kind and 500 deletion markers are accepted per request, with a 512 KB request cap. This prototype does not paginate very large wallets.
- Indexing processes up to 20 pending connections per request, embedding them in a batch. Only changed versions are indexed. D1 saves succeed if AI is unavailable; the response reports pending indexing, retried on the next sync/search. Vectorize mutation visibility is eventual. An embedding model's context limit still applies to very long notes.
- Text generation and search share a 100-request daily limit per Firebase UID. Public reciprocal submissions are limited to five per minute per share/IP hash. This is a basic prototype budget, not a full anti-abuse service; anonymous Firebase identities can be recreated.
- User notes, raw speech text, names and contact information are not written to application error logs. Public HTML is escaped, links are restricted to supported schemes and responses disallow framing. Private recall cues never enter public card payloads.

## Remaining platform boundaries

Photos accept JPEG, PNG and WebP bytes up to 512 KB, validate their signatures, and reject SVG/other formats. The picker requests a resized photo. Local drafts are uploaded before record sync; D1 stores only an opaque reference. Private `photo:` references are owner-scoped and rejected on shared identity cards. Public `portrait:` references resolve only while an active identity card references that portrait. Removing a portrait from all identity cards prevents further public retrieval; already downloaded copies can remain in recipients' local caches. Unreferenced R2 objects are retained for now; automatic orphan cleanup is not implemented. Uploaded images are not sent to the language model.

The local avatar cache is keyed by Firebase UID. Uploads are cached by UID/purpose/content hash to avoid uploading the same draft repeatedly. Accounts are checked around token retrieval and before syncing prepared records.

No push channel is implemented: returned web-form contacts appear on the owner's next automatic/manual sync. Offline QR saves are immediate in the scanning device's wallet. There is no NFC transfer, badge OCR, calendar integration or social-network scraping in this version.

Schema migration and production Worker/frontend deployment are still required for the new remote functions. Live model output, Firebase provider settings, index binding health and cross-device delivery are not established by unit tests or a successful dry run.
