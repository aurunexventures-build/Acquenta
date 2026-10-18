# Acquenta admin

Admin portal: https://admin.acquenta.aurunex.com

Sign in with Google as **aurunex.ventures@gmail.com**, an existing verified Acquenta Firebase user. No separate password has been generated. Admin checks validate the Firebase signature, issuer, audience, verified email and server-side owner allowlist on every private request. Browser tokens remain in memory and signing out clears the session.

## Available controls

- Search synced accounts and view card/connection counts and last synced record time.
- Review uploaded **card portraits**, hide/restore them without deleting accounts.
- Suspend/restore cloud access. Suspension prevents sync, AI, photo access, public cards and reciprocal submissions. Self-service account deletion remains available.
- View the latest 100 moderation actions with actor, target, reason and timestamp.

Every moderation action requires a reason. Hide/suspend controls are reversible; account deletion is permanent and records requested/completed audit entries. Private connection images and conversation notes are excluded. Admin authorization does not depend on frontend visibility. Unknown API routes deny access before handling requests.

## Boundaries

This dashboard inventories cloud-synced users and portraits, not all Firebase signups or local-only activity. Account email/name are updated from verified Firebase token claims on future syncs; older records may only show card names and user IDs. Last sync uses the latest record modification timestamp, not a complete event log. AI request totals count quota reservations, including failed model requests. There is no automatic image classification, report inbox or notification service in this version. Suspension does not disable the Firebase identity or revoke local/offline access. Hiding an image cannot recall copies already downloaded by other devices.

Portrait bytes are retained privately for admin review and reversal. The owner account cannot suspend itself. Allowlisted admin accounts are labelled and cannot be deleted. Other accounts can be deleted with exact email confirmation and recent owner authentication.

## Development

From repository root:

```sh
npm ci --prefix admin
node backend/node_modules/typescript/bin/tsc --project admin/tsconfig.json
node admin/test/run.mjs
npm test --prefix backend
node backend/node_modules/wrangler/bin/wrangler.js deploy --config admin/wrangler.jsonc --dry-run
```

Backend enforcement lives in `backend/src/moderation.ts`, with narrow calls in `index.ts` and `photos.ts`. The additive `0004_admin_moderation.sql` migration must be applied before deploying that backend. Both Workers bind the existing `metcue-db` and `metcue-photos`; the admin Worker has independent assets/configuration and no AI binding. Deploying only admin does not update backend enforcement.

Deployment:

```sh
node backend/node_modules/wrangler/bin/wrangler.js d1 migrations apply metcue-db --remote
node backend/node_modules/wrangler/bin/wrangler.js deploy --config admin/wrangler.jsonc
node backend/node_modules/wrangler/bin/wrangler.js deploy --keep-vars
```

Preserve concurrent application work and its compiled `build/web` output. Firebase must authorize the admin hostname for Google sign-in. The custom domain's certificate must be active before the portal can be used over HTTPS.


## Owner-initiated deletion

In Users, choose **Delete user**, supply a reason, and type the exact target email address. The portal requests fresh owner authentication when needed. Server-side checks protect the signed-in owner and every allowlisted owner email. The server uses the same account deletion cleanup as the app and additionally removes the Firebase login using a dedicated identity with only `firebaseauth.users.get` and `firebaseauth.users.delete`.

The `FIREBASE_ADMIN_SERVICE_ACCOUNT` secret is stored in Cloudflare, never in frontend assets or tracked files. Configure it with Wrangler secret input. The admin Worker binds the existing Vectorize index for account-scoped cleanup. Missing credentials stop deletion before any data changes. Interrupted deletions remain under **Pending deletions** and can be retried; repeated successful requests are idempotent. Exact email confirmation and a recent owner sign-in are also required when retrying.

The deletion marker prevents old tokens and in-flight wallet/profile writes from restoring cloud records; migration `0006_deleted_identity_guard.sql` extends that safeguard to identity metadata. Audit records retain actor, opaque target ID, reason, action and time. Deletion request audit entries retain the target email for safe retries after partial cleanup. Recipient exports and offline copies cannot be remotely recalled. Review the retention and moderation follow-up plan in `docs/privacy-moderation-plan-2026-10-18.md`.

## Administrator management

The signed-out page shows only the sign-in card and AuruNex Ventures branding. Navigation is revealed only after `/api/me` confirms access. Sign-out immediately hides the workspace, closes dialogs and clears rendered data and photo URLs.

Owners configured in `ADMIN_EMAILS` can open **Administrators**, add an email, or remove delegated access. The recipient uses their own verified Firebase account; this grants access directly without sending an email or creating an account. Delegated administrators can review and moderate, but cannot manage administrators or permanently delete users. Owner access cannot be removed through this interface. Each request rechecks database access, so removal takes effect on the next API request. Admin accounts are protected from account suspension and deletion. Grants and revocations are audited.

Apply `backend/migrations/0007_admin_access.sql` before deploying this version.
