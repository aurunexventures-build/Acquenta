# Adaptive information layout and iOS contact export

18 October 2026. Deployed web version 8c13e535-ed79-442e-ab14-373bb3298025. Live main.dart.js SHA-256 matches local build: 27d89c307f6301592ff6b12c9d14d255e4d728b8aa96ac381c8c76096d65ab61.

## Changes
- Wallet heading fills content width; QR action sits at its right edge on My Cards and Connections.
- Primary and exposed stack faces use content height. Removed the spacer that separated identity from details. Other card headers remain accessible in the stack.
- Own card preview includes saved location and up to three social/web links. Detail screen retains full data.
- Connection details lead with a compact name/photo/role/company summary; duplicate role/headline removed. Contact information follows, with memory and contact-save actions next. Empty contact and meeting context sections are omitted.
- Original notes, interview answers, follow-up tools and interaction history are collapsed under Notes & activity. Saved cues and other fields remain available. Labels for meeting context are plainer.
- Previously, own-card export copied vCard text; connection export copied/shared plain text. Both now route to native ContactsUI on iOS or a real contact.vcf file on other platforms, with errors surfaced. iOS has explicit contacts usage wording, save/cancel handling and an in-progress editor guard. Contact location now exports in vCard ADR.

## Verification
Flutter analysis clean; all 119 tests passed, including 5 new layout/platform-routing cases. Real-font phone renders inspected: build/ui-review/home-no-gap.png and connection-information-first.png. No overflow found in tested layouts. Info.plist validates. Final Android debug and iOS signed Release builds succeeded and installed on the connected phones; Android launched successfully.

Native iOS contact save/cancel is implemented and compiles; the platform-channel contract is tested. An actual user-confirmed contact save in iOS Contacts was not performed during this run. No real address-book contact was created. This remains a device acceptance check, not a verified end-to-end save claim.

Logs: /private/tmp/acquenta-adaptive-final-tests.log, /private/tmp/acquenta-adaptive-android.log, /private/tmp/acquenta-adaptive-ios.log, /private/tmp/acquenta-adaptive-deploy.log.
