# Offline card sharing

## Supported paths

- Native iPhone to native iPhone: Send nearby / Receive nearby, using MultipeerConnectivity. Both phones must have Acquenta open in the foreground, with Bluetooth/Wi-Fi and local-network permission enabled. Internet and a shared router are not required. This does not use iPhone NFC or trigger automatically when phones touch.
- Android: existing NFC send/receive option, subject to device NFC support. This is separate from the iPhone nearby protocol.
- All platforms: offline contact QR, plus contact-file sharing. QR contains the card itself; a previously loaded web app can display it without internet. Initial loading of the web app still requires connectivity.

## Consent and transfer

The receiver advertises a random device label. The sender selects it and the receiver accepts the invitation. Both people compare and confirm the six-digit code. Only then may the sender swipe up or tap Send. The receiver previews the contact and explicitly saves it. The sender reports saved only after the receiver acknowledges a successful local-wallet save. The original card remains in the sender's wallet.

The transfer copies public contact data, social links, skills and the public introduction. It excludes the portrait URL, account credentials, private relationship notes and card purpose. Portraits are omitted so the exchange does not depend on an image download. Local text checks still apply; offline checks do not reproduce cloud contextual moderation.

The session requires encrypted MCSession transport plus an ephemeral Curve25519-derived AES-GCM payload key bound to the matching code. Only one peer and one card are accepted per session. Sessions stop on backgrounding or after three minutes. Leaving the screen stops discovery and releases the screen-awake lock. Users should compare the codes before confirming.

## Validation

Automated widget tests cover verification gating, receiver preview before saving, acknowledgement after local persistence, rejection of URL payloads, and unsupported-platform guidance. Flutter analysis, the full Flutter suite, iOS compilation and web compilation verify the integration. A physical two-iPhone transfer, permission prompts and discovery with the internet disabled must still be tested on devices; compilation and mocks do not prove radio behavior.
