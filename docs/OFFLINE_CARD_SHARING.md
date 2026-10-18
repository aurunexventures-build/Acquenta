# Offline card sharing

Send on a wallet card opens an offline vCard QR. The receiver opens Receive card,
scans, reviews, and saves into their local MetCue wallet without a backend request.
Long profiles use a basic QR retaining the name and contact details; Send contact
file exports the full vCard through the device share sheet. Remote portraits and
links may require connectivity later. Event notes are opt-in under More options.

Android NFC uses foreground HCE with a read-only NFC Forum Type 4 NDEF contact.
Both phones must support compatible NFC, have NFC enabled, and be unlocked.
Open Send by NFC on the sender and Receive card on the recipient. The shared
payload stays in memory and expires after two minutes; leaving the foreground or
closing sharing clears it. No iOS NFC transmission is enabled. Use QR between
Android and iPhone. Native protocol tests do not establish hardware compatibility.

Before claiming NFC device support, check actual sender/receiver phones in both
orientations, cancellation, screen lock, disabled NFC, and airplane mode. Verify
QR and contact-file receipt without connectivity on Android and iPhone. Builds
and rendered layout checks are complete; this physical-device testing is pending.
