# Admin sign-in and access management

Deployed to https://admin.acquenta.aurunex.com on 18 October 2026.
Worker version: d027c18a-7a91-4e55-beef-1c3868a3b4b5.

Signed-out live Chrome view shows only the sign-in card and AuruNex Ventures branding, with no sidebar or workspace header. Google opens the Acquenta account chooser. Owner account was not among the browser's available accounts, so authenticated UI and actual sign-out were not verified in this run. Screenshot: /private/tmp/acquenta-admin-signin.png.

Owner-only Administrators page grants/revokes access by verified email. No invitation email is sent. Each private request checks access; delegated administrators cannot manage access or delete users permanently. Owner access remains in the deployment allowlist. Admin accounts are protected from suspension and deletion. Changes are audited.

Applied additive 0007_admin_access.sql directly to remote metcue-db before deploying admin only. No administrators were granted access in production. No public app or backend deployment was performed.

Validation: all 11 admin tests passed; TypeScript and JavaScript syntax checks passed; Worker dry-run passed. Added coverage includes grants, revocation, permission boundaries, protected owner and delegated accounts. Remote migration and deployment succeeded.
