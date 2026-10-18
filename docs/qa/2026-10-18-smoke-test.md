# Acquenta smoke test — 18 October 2026

## Automated checks
- Flutter analyze: no issues.
- Flutter: 114 tests passed.
- Backend: typecheck passed; 32 tests passed.
- Admin: typecheck passed; 8 tests passed.
- git diff --check: passed.

## Live browser walkthrough
Tested deployed app with a new isolated QA account and synthetic contact details.
- Empty sign-in form: email/password validation shown.
- Email sign-in: successful.
- First account setup: first/last name, phone, email, LinkedIn username, role, company, introduction entered and saved.
- Card wizard: purpose, primary selection, prefilled identity/contact fields, colour and review steps completed; card saved.
- AI skill extraction: Flutter, Kotlin and Android app development returned; selected and saved.
- Card detail and send-card QR preview opened.
- Connections empty state and QR scanner opened; camera stream appeared. No physical QR roundtrip performed.
- Paste vCard: synthetic Jamie QA contact parsed and saved.
- Memory cue: entered text, AI organisation, review and save completed.
- Connection detail and interaction logging form exercised. Interaction submitted; immediate detail did not display the new note, so persistence of that interaction was not separately verified.
- Follow-up reminder created and appeared in Follow-ups. Complete action exercised; resulting completed filter was not separately checked.
- Smart Recall: Android developer + blue jacket matched Jamie; own Alex card excluded. Plumber returned zero results. AI tidy and Matches visibility control exercised.
- Return to My Cards worked. Profile and saved wallet remained after reload.
- Event name/location entered and saved.
- Account/privacy dialog and Privacy Policy opened. Explicit sync reported wallet synced and AI index updated.
- Admin existing owner session: Overview and Users opened; search found QA profile with one card and one connection. After refreshing portal, reauthentication ended with auth/popup-closed-by-user. Refreshed portrait/history/deletion UI was not tested.

## Device and coverage limits
Android SM-G990E and iPhone 14 Pro detected. Recent Android log excerpt contained no matching fatal exception or Flutter overflow; this is a limited log check, not a native UI walkthrough. No native Android/iOS screen-by-screen pass, microphone dictation, physical QR/NFC exchange, photo/OCR upload, notifications delivery, external share delivery or payment flow was completed. Browser viewport override did not apply (remained 1512x805); mobile responsive coverage comes from automated Flutter tests.

Google sign-in still displays the legacy Firebase domain. This branding work remains pending homepage/privacy URL configuration.

## Evidence
Flutter log: /private/tmp/acquenta-qa-flutter.log
Android excerpt: /private/tmp/acquenta-qa-android.log
Live recall screenshot: /private/tmp/acquenta-qa-recall.png

No application source code was changed during this QA session. This smoke test is not a claim that every screen or hardware feature has passed.

QA account and synthetic cloud data removed through the account deletion API (HTTP 200); subsequent email login rejected (HTTP 400).
