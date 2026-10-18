# Acquenta privacy and moderation plan

Prepared 18 October 2026. Proposed follow-up work, not a compliance certification or a claim that automated moderation is live.

## Current scope

Acquenta has private account profiles, identity cards, public/revocable card links, QR/NFC/file exchange, received contact cards, private notes/photos, AI recall, and optional device reminder alerts. Firebase supplies identity; Cloudflare stores and processes cloud wallet data. Private notes are not a public feed. Assess each sharing route separately rather than assuming Landing Page Builder's assessment transfers to this product.

Existing controls: user-initiated deletion, verified owner-only admin access, portrait review/hiding, suspension and moderation history. This change adds admin deletion with exact-UID confirmation, recent owner authentication, protected owner accounts, cloud-data cleanup and Firebase login removal. Failed deletions remain visible for retry. No real customer accounts should be deleted to demonstrate the feature; use disposable test accounts.

Deletion cannot recall contact files or copies already saved by recipients. Offline devices require a later connection to learn of deletion. Minimal deletion markers prevent old sessions from restoring cloud records. Audit and backup retention need a documented schedule and justification; do not promise instantaneous destruction of every copy or unrestricted erasure.

## Proposed final workstream

1. **Privacy foundations.** Complete a data inventory covering account holders and people saved as contacts, lawful bases, private notes, voice/speech providers, portraits, AI processing, processors, international transfers, recipients, backups and retention. Review whether a DPIA is required. Confirm controller/contact details and the ICO fee position. Update the privacy notice and terms to accurately describe the final features. Device permission is not automatically GDPR consent.
2. **Rights and deletion operations.** Provide an accessible contact route for access, correction and erasure requests, including people whose details were saved by someone else. Set ownership, identity checks, deadlines, exceptions, deletion retries and backup expiry procedures. Document limited retention of security/audit records. Exercise deletion with a disposable account across Firebase, D1, R2, Vectorize, published links and an older logged-in device.
3. **Online Safety Act assessment.** Map who can upload/share/access each kind of content and assess scope/exemptions for the actual service. If in scope, complete the applicable illegal-content risk assessment and children's access assessment, then the children's risk assessment and measures if required. Professional branding and sign-in do not by themselves exclude children. Do not describe assessment documents or automated filters as Ofcom approval.
4. **Image and text checks.** Evaluate Google Cloud Vision SafeSearch and an appropriate text-moderation provider against representative examples and cost/privacy requirements. SafeSearch classifies adult, spoof, medical, violence and racy image content; it is not comprehensive illegal-content detection or a violent-text checker. Use a separate text classifier for threats, harassment and other relevant categories. Check shareable profile/card text and portraits server-side before publication, with a reviewable reason, appeal and selective image removal. Define provider-outage behaviour explicitly. Do not extend routine admin visibility to private contact notes or private photos without assessing necessity and explaining it.
5. **Reports, review and appeals.** Add report controls to received/shared cards and public pages, an owner review queue, proportionate actions (hide image, unpublish card, suspend, delete), decisions and appeal handling. Keep the existing ability to remove a portrait without deleting its owner. Define escalation paths and appropriate handling of suspected illegal content; avoid collecting unnecessary copies.
6. **Operational readiness.** Assign a primary reviewer and backup, configure internal safety alerts and rate limits, agree response targets and minimum necessary logs, and run realistic moderation/appeal exercises. Automated flags support human decisions and do not establish that all harmful content is detected. Verify deployed behaviour, access control and deletion separately before wider promotion.

## Sources checked

- [ICO: right to erasure](https://ico.org.uk/for-the-public/your-right-to-get-your-data-deleted/). Erasure is conditional, not absolute; requests generally require a response within one month, subject to applicable extensions.
- [Ofcom: children's access assessment](https://www.ofcom.org.uk/os-toolkit/child-access-assessment/childrens-access-assessment-tool).
- [Ofcom: regulatory documents and current codes](https://www.ofcom.org.uk/online-safety/illegal-and-harmful-content/online-safety-regulatory-documents).
- [Google Cloud Vision: SafeSearch](https://docs.cloud.google.com/vision/docs/detecting-safe-search).

Prior Landing Page Builder notes indicated OpenAI image moderation existed there, while Google SafeSearch integration was blocked by project/account setup. That is historical context, not evidence that either provider is configured for Acquenta. Recheck provider adoption, data terms and current pricing before implementation.
