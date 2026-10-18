# Acquenta admin and phone update — 18 October 2026

Admin canonical URL: https://admin.acquenta.aurunex.com/. Legacy admin.metcue.aurunex.com redirects with HTTP 308, verified live. New hostname authorised in Firebase. HTTPS verified with normal certificate validation and live Chrome owner Google login completed successfully.

Live Users page: AuruNex Ventures shows Admin account · Cannot be deleted, with neither delete nor suspend controls. Other users open a deletion dialog asking for exact account email and reason. Dialog was inspected and cancelled; no real user was deleted. Server validates email against Firebase or stored account identity, protects all allowlisted admins, enforces recent sign-in and keeps safe retry identity evidence in deletion-request audit metadata. Pending deletions display the email when available; unavailable email disables the retry control.

Admin deployment b282fb47-fda3-4fda-aa1d-42bd167aa308. Admin typecheck and nine tests passed, including UID/wrong-email rejection, retry after partial cleanup, protected admin inventory and legacy hostname redirect. JavaScript syntax check passed. Flutter analysis clean and all 114 tests passed.

Android debug APK rebuilt, installed with adb install -r, launched and running (PID checked). iPhone Release build signed with existing development team and installed successfully. iOS launch verification was blocked because the device was locked; user can launch after unlocking. Existing bundle IDs and account data preserved. Native default API URL now https://acquenta.aurunex.com.

Branding scan found no remaining legacy display strings in app UI, web pages, admin assets or Android/iOS display resources. Technical Firebase IDs, native bundle IDs, storage protocols and Cloudflare resource names remain stable for compatibility. Backend/admin private package metadata and current admin README now use Acquenta. Historical docs may describe legacy names.

Evidence: /private/tmp/acquenta-admin-protected-account.png and /private/tmp/acquenta-admin-email-confirmation.png. Build logs: /private/tmp/acquenta-final-android.log, /private/tmp/acquenta-final-ios.log. Tests: /private/tmp/acquenta-final-tests.log.
