# Public Acquenta pages

- App: https://acquenta.aurunex.com/
- About: https://acquenta.aurunex.com/about
- Privacy: https://acquenta.aurunex.com/privacy
- Terms: https://acquenta.aurunex.com/terms

Published 18 October 2026 through the existing metcue-worker. The previous workers.dev URL remains available. Static HTML lives in web/about, web/privacy and web/terms and is copied by flutter build web. Keep its policy wording aligned with lib/screens/policy_screen.dart. No extra hosting service is used.

Firebase authorised domains include acquenta.aurunex.com. Google Auth Platform branding name Acquenta and these public URLs were saved, verified and published. Console confirms branding is being shown to users. Existing project/app/client IDs remain unchanged.

Cloudflare custom-domain certificate 435ec128-eb82-474d-b6f3-3df683c67772 is active. Public DNS returned 104.21.73.180 and 172.67.165.60; HTTPS with normal certificate validation verified the app, privacy, terms, about and health routes. The local machine initially cached a DNS failure, so verification used a public DNS result with curl --resolve rather than disabling TLS validation.

Deployment: 31fda4ab-c38b-46c1-bb99-14cc2552f19f. Flutter analysis, 9 focused auth/deletion tests, backend typecheck and 32 backend tests passed. Publication and Google branding verification do not certify privacy-law compliance; the broader privacy/moderation work remains in docs/privacy-moderation-plan-2026-10-18.md.
