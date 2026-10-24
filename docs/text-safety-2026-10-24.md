# Acquenta text safety — 24 October 2026

Active backend: `ea3a5dd6645c41459402bcc2f5078141`. Migration 0010 applied remotely. Google Natural Language API enabled in the existing `aurunex-landing-page-builder` project; a separate **Acquenta Text Safety** key (`acquenta-text-safety`) is restricted to `language.googleapis.com` and stored in Acquenta's Worker as `GOOGLE_TEXT_MODERATION_API_KEY`. The Vision key and Landing Page Builder credentials were not altered. Billing/quota remain shared at Google-project level.

## Enforcement

- Deterministic local and server profanity rules reject standalone profanity, common inflections and selected disguises, including `Fuck`, `Fuck off`, `f.u.c.k` and `f*ck`. Matching uses word boundaries, so legitimate strings such as Scunthorpe, Dickinson and Assistant are allowed. This is a deliberately bounded vocabulary, not a guarantee of detecting all profanity or languages.
- Google `documents:moderateText` checks contextual harm after local validation. Blocking categories/thresholds: Toxic .75, Derogatory .70, Violent .85, Sexual .80, Insult .75, Profanity .50. Topic categories such as Health, Religion, Finance, Politics and Legal do not by themselves block a profession or card. Malformed, incomplete, failed or unknown responses never become approvals.
- Signed-in UI card/profile saves call the safety preflight before replacing local saved content. The form stays editable on rejection. Offline saves still run deterministic profanity checks; contextual cloud checks apply on later sync or publication.
- Server checks cover own-card sync, profile writes, explicit publishing, the actual stored card selected for publishing, legacy published-card reads and public reciprocal-form name/event/note submissions. All incoming own cards are checked before applying sync record/tombstone writes. A rejection does not delete the previous card/account.
- Names, job titles, companies, headlines, bios, skills, location and displayed link labels are checked. Emails, phone numbers, URL identifiers, private purpose/primary settings and private connection notes are excluded. Private connection sync is not blanket-moderated.
- AI-generated card drafts go through the same save path. Safety is not implemented as a search-query or private-memory censorship filter. Previously exported copies and offline legacy cards cannot be retrospectively recalled.

## Limits and data

Google's published free tier is 50,000 text-moderation units/month, with 100 Unicode characters rounded up per unit. Acquenta reserves at most **5,000 units/month** and 100 new checks/account/UTC day; failed requests count and limits block further checks without paid fallback. Long content is chunked with overlap and the reserved unit count includes overlap. Other consumers of the Google project can affect shared usage; this is an application cap, not an account billing guarantee.

Unchanged account/content/policy fingerprints are cached 24 hours; provider failures one minute. Only hashes, verdicts and timestamps are retained for checks, not original text. Account deletion removes check records and anonymises usage without refunding global totals. No new retention scheduler or administrator override UI was added.

## Verification

117 backend tests and the full 176-test Flutter suite passed. Final targeted suite: 20 passed; analysis/typecheck clean. Direct live Google probes accepted software engineer, finance consultant and sexual-health counsellor; contextual abuse was flagged. Deployed API checks returned 422 for standalone profanity, the abusive phrase, an obfuscated spelling and contextual abuse. Profile writes, preflight and public reciprocal submissions were blocked; previous published content remained intact. Disposable accounts were deleted. Real mobile browser QA confirmed the visible profanity rejection, correction without losing the form, successful signed-in text preflight (200), and saving the corrected card with no browser errors. Preview revision: 48d6191619a3e77f. A preflight regression was fixed: unsaved local timestamps/IDs are not validated by the text-only endpoint; actual sync continues validating the complete record. Landing Page Builder's own text rules were not changed.

Sources: https://docs.cloud.google.com/natural-language/docs/moderating-text and https://cloud.google.com/products/natural-language/pricing (checked 24 October 2026).
