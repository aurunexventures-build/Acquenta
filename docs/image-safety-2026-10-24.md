# Acquenta photo safety — 24 October 2026

Status: active backend deployment `8cfa2ae1cbe140499ef3e3d085919168`. Migration 0009 applied remotely. A dedicated Google API credential named **Acquenta Image Safety**, ID `acquenta-image-safety`, was created in project `aurunex-landing-page-builder` (268435158417), restricted to `vision.googleapis.com`, and stored as `GOOGLE_VISION_API_KEY` only in Acquenta's Worker. Landing Page Builder's key was unchanged. The existing OpenAI text-moderation integration is used only for text detected in photos; the primary image provider is Google. Google project billing/quota remain shared.

## Behaviour

- New portrait and private-connection uploads request Google SafeSearch and OCR. Adult, racy or violence scores of POSSIBLE or higher block the image. Medical/spoof scores alone do not block. Unknown, incomplete or failed results block upload. Animated PNG/WebP uploads are rejected.
- Extracted text runs through the same narrow local policy rules and OpenAI moderation used by Landing Page Builder. No extracted text is retained. Missing text-moderation credentials fail closed when OCR detects text.
- Safety runs before writing image bytes or a photo record. Flagged uploads are rejected without retaining their bytes or deleting accounts. This implementation does not port Landing Page Builder's private flagged-image review gallery or approval workflow.
- Legacy server-hosted photos are screened before serving, after owner/public-portrait eligibility and admin controls. Rejected legacy objects remain private until separate removal. Local previews, exported copies and already downloaded client images cannot be retrospectively recalled by server screening.
- Signed-in photo selection checks before changing the selected picture. Errors leave the prior selection intact. The client photo cache namespace was versioned to avoid trusting older unchecked caches. Signed-out/offline local photos are checked on upload; this is server upload/serving enforcement, not device-gallery scanning.
- Passed/rejected fingerprints are cached per account for 24 hours; unavailable results for one minute. Cache identity includes the policy/model. Stored decisions contain hashes, verdicts/categories and timestamps, not image bytes or OCR text.

## Limits and retention

Atomic reservations allow ten new checks/account/UTC day, 200/day service-wide and **100/month** for Acquenta. The low monthly cap leaves room alongside Landing Page Builder's existing 900/month cap when both use the same Google project; it is not a billing guarantee for other project consumers. Failed requests count. Reaching limits blocks new checks, without a paid-provider fallback. Account deletion removes decisions and anonymises usage rows without reducing global totals. No automatic age-based cleanup of decision/usage rows has been added.

## Verification

Backend typecheck and 88 backend tests passed. Full Flutter suite passed with 162 tests, followed by five focused photo tests including the newly added safe-error/cache test. Flutter analysis clean. Real Google checks accepted a synthetic plain-blue image (~1.3 s) and a benign text image (~2.4 s, including OCR/text screening). Public portrait serving and unauthorised upload rejection were verified. The disposable test account and R2 photos were deleted. Harmful-image blocking, malformed/provider-error responses, quota enforcement and legacy rejection were verified with mocked provider output; no harmful real images were used. No iPhone installation was performed for this update.
