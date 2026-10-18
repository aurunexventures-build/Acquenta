# Acquenta

A Flutter networking wallet: share the right identity, keep a short memory of who you met, and find them later from those cues.

## What works in this change

- Multiple identity cards with contact details, skills and social links.
- Offline vCard QR display, camera scanning, pasted-card import and a preview before saving. Re-scanning the same Acquenta identity preserves the recipient's existing private cues.
- Share as an actual `.vcf` file; optionally publish a revocable online card link. Publishing is explicit. Syncing personal cards alone does not make them public.
- **Add cue** from Connections, a received card, or a saved person's detail screen. Speak or type a rough memory; AI asks up to three relevant questions, optionally reads them aloud, and uses your answers to refine an editable memory card. Skip questions or save at any time. Original text and answers are retained and searchable. Optional guided prompts still work when offline or signed out.
- **Faces:** choose/take a portrait in onboarding or the card editor, or add a private photo to a connection during cue capture. Photos appear in the wallet and recall results. Local photo drafts and account-scoped caches work offline; sync uploads image bytes to R2, with ownership metadata in D1. Shared QR cards carry an opaque portrait reference; recipients fetch the face when online. Private connection photos are excluded from exports.
- Local recall plus debounced backend embedding search. Both Ranked Cards and Neural Brain use the same hybrid results and filters. Old search responses cannot overwrite a newer query.
- Account-specific local wallets, one-time guest wallet adoption, sync of full card/connection records, remote contacts, deletions and concurrent local edits. Signed-in saves automatically queue sync; resuming the app retries. Manual sync is also available.
- Clean first launch. Demo fixtures are opt-in for tests. Anonymous account registration upgrades the existing Firebase UID rather than discarding its wallet.

## AI choice

The implementation uses the existing Cloudflare stack:

1. **Cue suggestions:** `@cf/meta/llama-3.2-3b-instruct` through Workers AI, with JSON output, low temperature, bounded input, instructions to use only supplied facts, and an editable review step. `CUE_MODEL` is configured in `wrangler.jsonc`.
2. **Smart Recall:** `@cf/baai/bge-small-en-v1.5` produces 384-dimensional embeddings of profiles and meeting cues; Vectorize retrieves similar meanings inside the signed-in user's namespace. Local relevance and semantic ranks are merged using reciprocal rank fusion.
3. **Voice:** `speech_to_text` supplies editable transcription and `flutter_tts` reads questions with the platform's available voice. This is dictation, not ambient conversation recording. Offline recognition is device-dependent; typed capture, stored cards, QR exchange and local search work without a connection.

AI is advisory: the original memory stays available, suggestions are editable, and AI failure does not prevent a local save. No social-profile scraping is performed; links are saved as links.

Cloudflare references: [text generation model](https://developers.cloudflare.com/workers-ai/models/llama-3.2-3b-instruct/), [embedding model](https://developers.cloudflare.com/workers-ai/models/bge-small-en-v1.5/), [Vectorize API](https://developers.cloudflare.com/vectorize/reference/client-api/).

## Architecture

Acquenta follows the same service split as Landing Page Builder, using its own resources:

```text
Flutter web / Android / iOS
  ├─ sign-in → Firebase Authentication (metcue09)
  └─ Firebase ID token → Cloudflare Worker (metcue-worker)
       ├─ Cloudflare D1 (metcue-db): cards, connections, private cues and sync
       ├─ Cloudflare Vectorize (metcue-index): per-user recall embeddings
       ├─ Cloudflare Workers AI: cue suggestions and semantic search
       ├─ Cloudflare R2 (metcue-photos): portraits and private wallet photos
       └─ Cloudflare Static Assets: compiled Flutter web app (build/web)
```

Firebase supplies identity and ID tokens. All application database writes and reads go through the authenticated Worker into D1. There is no Firebase Firestore, Realtime Database, Firebase Storage or Firebase Hosting integration. The Firebase project identifiers include a default storage bucket, but the app does not use it. SharedPreferences is only the account-scoped offline wallet cache; signed-in records sync to Cloudflare.

Web requests use the origin serving the app, so the frontend and API deploy together. Native builds use the existing Worker endpoint. All protected API calls verify the Firebase token and scope records to its UID. Public card shares are explicit, token-based exceptions.

The single deployment config is `wrangler.jsonc` at the repository root. It serves `build/web`, routes `/api/*`, `/c/*` and `/health` to the Worker, and binds the existing Acquenta D1/Vectorize/AI resources. It does not point to Landing Page Builder's Firebase project or database. The `PHOTOS` R2 binding stores images. Photo ownership and purpose are checked by the Worker; the bucket itself does not need public access.

## Development

```sh
flutter pub get
flutter run -d chrome --dart-define=METCUE_API_URL=http://127.0.0.1:8787
flutter analyze
flutter test
flutter build web
flutter build apk --debug

npm --prefix backend ci
npm --prefix backend run types
npm --prefix backend run typecheck
npm --prefix backend test

# Unified Cloudflare preview: build Flutter, then serve app + API
npm run dev
# Build and validate the complete Cloudflare deployment without publishing
npm run deploy:check
# Build and publish app + API together, after database migration
npm run deploy
```

Node 22+ is needed for the backend tooling and SQLite tests. Use `--dart-define=METCUE_API_URL=https://your-worker.example` to point a Flutter build at a different API. Without it, web uses its page origin and native uses `metcue-worker.quadban-cloudflare.workers.dev`. A standalone Flutter/Python preview needs an explicit API override; `npm run dev` serves the full web app and API on the same origin.

The Android Firebase app is configured by `android/app/google-services.json`. The registered Acquenta Web app in the same `metcue09` project is configured in `lib/firebase_options.dart`. Those are public client identifiers, not server credentials. iOS has its own Firebase app configuration and Google callback scheme in the same project; its unsigned device build passes, with signing/device login still pending. macOS still needs its own Firebase configuration; local wallets remain available.

## Backend activation

Source changes and local builds do not update the hosted API. Before using the new AI/sync functionality online, review and apply the additive migration and deploy the matching Worker. See [backend/README.md](backend/README.md). No production migration or code deployment was performed as part of this change. The `metcue-photos` bucket must exist before production deployment.

The new protocol is deliberately versioned (`protocol: 2`). An old frontend must be upgraded with the backend. Existing legacy database tables are preserved by the migration.

## Verification boundaries

The regression suite checks offline imports, escaped Unicode vCards, repeat scans, original-cue retention, local recall, account isolation, deletion conflicts, in-flight local edits, debounced/stale search responses, AI failure, explicit sharing/revocation, reciprocal receipt, SQL migration and user-scoped retrieval. Backend AI and Vectorize responses in these tests are simulated; live model quality and device camera/microphone behaviour need a signed-in end-to-end check after deployment.


## Follow-up reminders

Open the bell in the top bar for pending follow-ups, sorted by due date. On a connection, set a date/time and private note, reschedule, snooze until tomorrow at 09:00, complete, or remove the reminder. One current reminder is supported per connection; completing retains its date/note until replaced or removed. Reminders use account-scoped offline storage and the existing authenticated record sync; deploy the matching backend before using cloud sync with reminder fields. No database migration is required.

Reminders appear inside Acquenta. Export to calendar shares an `.ics` event with a requested ten-minute alert; the user must import it into a calendar, whose settings control alerts. Calendar exports are independent copies and do not change when Acquenta reminders are edited or completed. Optional native local notifications are now available on Android and iOS; see Contact capture and device alerts below. Remote push notifications are not used.


## Relationship tools

Connections now include **Log interaction**, an expandable dated history and **Reconnect**. Reconnect provides editable offline message templates and conversation ideas from saved context; it copies text only and never sends messages. Replacing a memory archives its previous original cue, summary and interview answers; history is searchable locally and through authenticated semantic search after sync. Histories are private and excluded from shared vCards. Growing wallets upload in bounded batches under the existing request limit. Each connection supports 100 history entries or 200 KB of history; exceeding that rejects the edit rather than silently dropping older entries.

Follow-ups have All, Overdue, Today, Upcoming and Completed views. Completed reminders can be reopened. Cue editors and the contact editor reject stale saves, and removed connections show a safe empty state. Deploy the matching backend before syncing history fields. This is incremental coverage, not a claim that every possible edge case or competitor feature is implemented.


## Contact capture and device alerts

From **Receive a card**, choose **Import contacts**, **Scan paper card**, or **Review duplicates**.

- Imports support UTF-8 CSV and multi-contact vCard files, up to 1 MB / 500 contacts. Preview and select before saving. CSV accepts Name or First Name/Last Name plus common Google/Outlook email, phone, company, role and notes headers. Unsupported/missing-name vCards and incomplete rows are reported. Possible duplicates default to unselected, are rechecked during import, and can be merged individually using Review merge. No phone-address-book permissions or writes are needed.
- Duplicate candidates use ID, normalized email/phone, or name plus company; names alone do not match. User-confirmed merges retain the chosen contact ID/current values, fill empty fields, union links/tags, archive the source details and conflicting reminder as private history, then tombstone the second saved contact. Source photos are not archived. Limits and stale previews reject the merge; imported files are not modified.
- Paper-card OCR uses on-device ML Kit Latin text recognition on Android/iOS. Take or select a photo, review extracted name/email/phone, fill company/role, and save. OCR does not upload the image. Browser/desktop users can enter details manually or import a contact file. iOS now requires 15.5+ for ML Kit.
- **Follow-ups → Device reminder alerts** opts in per account on this device. Permission denial and OS failures preserve all local reminders. Schedules refresh after edits, sync, account changes and app resume. Completion/deletion disables those pending alerts; account switches cancel the previous account's schedules. Alerts contain generic text, not contact details. The next 60 future reminders are scheduled to stay below mobile OS limits; opening the app refreshes the window. Android uses inexact alarms (no special exact-alarm permission), so delivery may be delayed by OS/battery settings. Web/desktop continue to use calendar exports.

Verification: automated tests cover import parsing, duplicate heuristics/merge retention and tombstones, OCR field extraction, mobile/desktop review layouts, and notification permission/scheduling/account-switch behavior with a fake OS backend. Camera recognition and real notification delivery require native-device checks; an APK build alone does not verify them. No hosted deployment is performed by these changes.


## Phone authentication and policies

Login/sign-up use compact layouts on phone widths, respect safe areas, and hide decorative content while the keyboard is open. Normal portrait layouts fit without scrolling from 320×568 through 430×932 in the responsive checks; short landscape, errors and enlarged text retain a scroll fallback so controls remain accessible. Scrollbars and overscroll effects are suppressed on authentication screens. Policy links open in-app Privacy Policy / Terms of Use pages, including from sign-up and the signed-in account screen, without losing form drafts. Small-screen offline access is available through the phone icon in the header.

### Mobile card setup update (18 October 2026)

Card setup now uses four focused steps: required name/job title/pitch, optional
skills, contact/appearance, and final preview. A toolbar preview is available
without occupying form space. Skill candidates use authenticated Workers AI via
`POST /api/v1/profile/skills`; users confirm tags or add their own (12 maximum).
The ambiguous device-continuation welcome action has been removed. Android/iOS
launcher icons use the existing purple infinity branding; regenerate with
`swift assets/branding/generate_icon.swift assets/branding` followed by
`dart run flutter_launcher_icons`. Validation: 69 Flutter tests, 19 Worker tests,
and clean Flutter analysis/Worker typecheck.

Deployment verification: Worker version `f1f5f6f1-7c85-4d17-a508-b309694433fd`
is live; all three additive D1 migrations applied. Health returned protocol 2.
Authenticated live skill tests for Florist and Teacher returned HTTP 200 with
profession-specific tags; disposable Firebase test account deleted afterward.
Updated Android and iPhone builds installed without removing app data. Android
process confirmed running; automatic iPhone launch was blocked by screen lock.

### AI questionnaire drafting

Identity setup includes “Help me draft my card”: describe your work, optionally
add your audience and specialties, then review an editable job title, pitch and
removable skill tags before choosing “Use this draft”. Existing identity fields
are unchanged until confirmation; name/email prefill from the signed-in account.
The authenticated `/api/v1/profile/draft` endpoint sends only questionnaire
answers to Workers AI, shares the existing AI quota, and does not write wallet
records. Missing roles must be completed by the user; offline/failed requests
keep the answers available for retry or manual setup. LinkedIn remains deferred.
Validation: 71 Flutter tests, 20 Worker tests and clean analysis/typecheck.
Live model checks prompted an additional server-side draft filter: skill tags
must match phrases present in the questionnaire answers (case/punctuation
normalized). This conservatively omits unsupported or paraphrased skills;
users can still add skills themselves during card setup. Both device updates
installed successfully and iPhone launch succeeded.

### Account deletion

Home and onboarding both expose Account & privacy → Delete account. The screen
explains permanent removal and copy limits, requires an acknowledgement and
password/Google reauthentication, then calls authenticated DELETE /api/v1/account.
The server requires authentication within five minutes and explicit confirmation.
It blocks restoration using an opaque UID deletion marker and SQL write guards,
removes D1 wallet/legacy records, R2 photos, Vectorize entries and shared links,
then deletes the Firebase identity using its fresh ID token. Cleanup failures can
retry; external-object metadata remains until removal succeeds. Client sync is
paused/drained before deletion; successful deletion clears account-scoped local
wallet/photo caches/alert preferences, cancels alerts, clears image memory and
signs out. Other devices cannot repopulate deleted cloud data; updated clients
clear their account cache when a sync reports deletion. Offline/device backups
and copies exported or saved by recipients are outside remote recall.
Validation: 75 Flutter tests, 26 Worker tests, clean analysis and typecheck.
Live verification (18 October 2026): deployed Worker
`0f63c95c-031b-4ac8-bb3a-a3c91a55e1c2`; a disposable Firebase account created a
wallet, portrait and public card, rejected missing confirmation, then deleted
successfully. Its old token received 410 on attempted re-upload; public card and
portrait returned 404; Firebase password sign-in failed after deletion. Both
phone updates installed; iPhone automatic launch was blocked by its screen lock.

### Simpler phone flows

Receive opens directly in the QR camera. Paper cards, file imports and pasted
links live in More options. Phone home removes the promotional panel. Profile
setup exposes three required fields and collapses company/photo; “Speak or write
my profile” opens one main question with optional details collapsed.
A shared robot AI control supports speech or typed input in profiles, memory
capture and recall. Dictation stays visible and editable, then organises after
speech finishes; microphone failures retain typing. Memory capture is a single
organise/review/save flow, without questions or read-aloud interviews. Original
notes remain intact, with extra structured fields available under More details.
Recall includes own cards under Your cards, independently from saved people;
exact query evidence takes priority over broad semantic suggestions, with recent
contacts breaking relevance ties. Match diagnostics start hidden and follow
results. Keyboard controls become compact, including in nested phone screens.
Validation: 82 Flutter tests, 28 Worker tests, clean analysis/typecheck and rendered
360px phone screenshots under build/ui-review. Android hardware speech/camera
verification remains pending reconnection; no device installation is claimed.
Live AI verification uses an Android-app developer profile, a Priya/Android/London
memory and the matching spoken search wording. Organisation never returns a
follow-up question in one-pass mode; empty model summaries fall back to the
original note. Explicitly typed specialties are kept even if the model omits them.
Android APK and signed iOS release builds succeeded; phone installation remains
pending as requested while the Android device is disconnected.
Final live verification: Worker `284d8be2-9dff-447a-84bf-f611db93ff0a` returned
an Android developer draft with the explicit specialty, a nonempty Priya/Android/
London memory with no follow-up question, and a search query retaining Android
and London. Disposable test identities were removed. No phone was installed
in this pass, following the user's choice to continue build/layout testing.
