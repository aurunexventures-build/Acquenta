# AI improvements — 24 October 2026

Implemented without changing the wallet/card design:

- Shared voice controls now use the existing server-side Groq transcription route, including Smart Recall, memory capture and text composers. Recording activity remains visible, screen-awake handling is shared, and interrupted or stale recordings cannot replace newer typed text.
- Signed-in web Talk to Create uses cloud transcription. Browser replies remain text-only; native speech retains the existing Orpheus voice.
- Smart Recall accepts short and multilingual input, supports explicit “Refine this search” context (up to four prior requests), includes context in cache identity, and clears context for new searches/account changes. Local fallback retains the combined wording.
- Ranking selects relevant excerpts throughout saved interaction history rather than always keeping the first 1,200 characters and last four notes. Aggregate evidence size is bounded. Larger-wallet candidates include literal saved-note hits alongside vector matches. This remains candidate retrieval, not a guarantee that every large-wallet match is found.
- Reconnect offers an explicit “Draft with AI” action. The server loads the current user's saved contact, and the user can review, edit and copy the result. It does not send messages. Edits made while generation runs are preserved.
- Voice recall skips the extra automatic wording-cleanup request; the recall model interprets the transcript directly. Manual AI tidy remains available.

Validation: full Flutter suite 162 passed; backend suite 72 passed; final targeted Flutter suite 25 passed; Flutter analysis and backend typecheck clean. Live disposable-account checks verified contextual Flutter narrowing, a Hindi request, AI abbreviation, reconnect generation and missing-contact rejection. Mobile browser QA verified visible context and one Flutter result. Test accounts/data were removed afterward.

Deployment: backend version fe60dec4aee54c0b98916ac627e79b65. Final local browser revision c87e011468166eb1. No new iPhone build was installed. Actual microphone/accent quality on a physical device still needs user retesting; automated browser QA used typed input.

Deferred: meeting briefs, AI-assisted scan parsing, fuzzy duplicate suggestions and AI scheduling actions.
