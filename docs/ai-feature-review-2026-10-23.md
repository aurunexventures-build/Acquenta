# Acquenta AI feature review — 23 October 2026

Scope: current Flutter/Worker checkout. Reviewed AI-facing API routes, model calls, search and fallback logic, voice entry points, card creation, memory capture, OCR, reconnect messages, duplicate handling and reminders. This is a feature/architecture review, not an exhaustive security audit. No application behaviour or appearance was changed.

## Is typed search actually using AI?

Yes. `ConnectionsProvider._scheduleAi` waits 700 ms after typing stops, then calls the authenticated `/api/v1/search/semantic` endpoint. Signed-in, meaningful queries of at least three characters qualify. A completed identical query for the same wallet revision can reuse an account-scoped 60-second cache.

For wallets containing up to 50 contacts, Groq interprets the request and ranks compact representations of all those saved contacts in one call. The configured text model is `openai/gpt-oss-120b`, hosted by Groq. For larger wallets, AI expands the query, Cloudflare embeddings/Vectorize retrieve up to 50 candidates, and Groq ranks those candidates.

The backend accepts only supplied contact IDs and checks supporting quotes against the saved evidence supplied to the model. The client uses the latest locally saved record for each matching ID and applies selected filters. This grounds the result; it does not guarantee every ranking judgment is correct. AI-generated relevance scores are not calibrated probabilities.

If the AI provider is unavailable or limited, the app labels the semantic/local fallback. The local cognitive mapping and the thinking animation are UI/offline support, separate from the real model call.

Code entry points:
- `lib/providers/connections_provider.dart` — debounce, cache, AI status, local/current-record filtering.
- `backend/src/index.ts` — authenticated search orchestration and retrieval.
- `backend/src/recall_ai.ts` — interpretation, ranking and evidence validation.
- `backend/src/text_ai.ts` — Groq provider/model and request limits.

## What already uses AI

| Area | Current implementation |
| --- | --- |
| Smart Recall and Connections search | Automatic Groq interpretation/ranking, plus embeddings and local fallback. |
| Talk to Create | Groq-assisted conversational field extraction and card drafting. |
| Skills and introductions | AI extraction/organisation and copyediting through dedicated endpoints. |
| Add a connection memory | AI turns supplied notes into editable skills, meeting context, memory cues and reasons to reconnect. |
| Native card-creation voice | Groq Whisper transcription and Orpheus speech playback. |
| Connections spoken search | Cloud transcription, followed by text cleanup and search. |

## Reliability gaps to address first

1. **Voice is inconsistent across screens.** Smart Recall, memory capture and shared text composers use `VoiceMagicBar`, which wraps device/browser `SpeechToText`. Web Talk to Create also selects the device voice implementation. Connections spoken search already uses the cloud recording/transcription service. Unifying these would make accent handling and error states more consistent. It cannot guarantee perfect transcription.
2. **Short search terms are blocked from cloud AI.** The current gate skips queries shorter than three characters. Consequently terms such as “AI” and “UX” remain local. “IT” is also treated as an English stopword. Add intent-aware handling for professional abbreviations.
3. **Non-Latin query gating needs work.** Local tokenisation uses an ASCII-oriented word filter; a query containing only a non-Latin script can become empty and never reach cloud AI. Keep original multilingual text for cloud interpretation and improve local tokenisation separately.
4. **Long-memory retrieval is lossy.** Each AI candidate is compacted/truncated to 1,200 characters, and only the four most recent interaction texts are included in that compact input. Important facts buried in older/longer notes can be missed. Retrieve query-relevant excerpts with source references.
5. **Large-wallet recall needs its own evaluation.** More than 50 contacts uses candidate retrieval rather than examining the entire wallet with the model. Test recall quality with hundreds of varied contacts, cold indexes and ambiguous professions before promising exhaustive results.
6. **Date-dependent questions need structured context.** Pass current date/timezone and relevant meeting, interaction and reminder timestamps explicitly before relying on requests such as “last week” or “who should I follow up with tomorrow?”
7. **Expand evaluation beyond a few examples.** Maintain a compact regression set covering colloquial terms, constraints/exclusions, names, abbreviations, mixed-language queries, empty results, stale responses, quota fallback and more than 50 contacts. Measure relevance and latency separately.

## Recommended additional AI features

| Priority | Feature | Concrete experience | Existing foundation |
| --- | --- | --- | --- |
| 1 | Conversational recall | “Find a developer” → “Only people I met in London” → “Who knows Flutter?” preserves the earlier constraints. | Existing query interpretation/ranking. Search currently receives only one query, without conversation history. |
| 2 | Personalised reconnect drafts | “Draft a short message to Mei about the accessibility project we discussed.” Review/copy/share the draft. | Saved meeting notes and interaction history. `ReconnectService.draft` currently uses a fixed greeting template. |
| 3 | Meeting brief | “Remind me what I know about Mei before our meeting.” Summarise saved conversations, open follow-ups and useful talking points with references. | Existing connection details, memories, interactions and follow-up fields. |
| 4 | Smarter card scanning | Parse recognised text into name, company, role, links and skills; show a review before saving. | On-device ML Kit OCR exists. `CardOcrService.extract` currently uses first-line and regex rules, and the recogniser is Latin-script only. Text-only AI parsing can reuse the existing provider. |
| 5 | AI-assisted memory actions | “We discussed a collaboration; remind me next Tuesday.” Propose a structured memory and a dated follow-up for review. | Existing cue-generation, reminders and calendar export. Scheduling is currently structured/manual, not an AI action planner. |
| 6 | Ambiguous duplicate suggestions | Suggest that a nickname or changed-company record may be an existing contact, showing the supporting fields and conflicts. | Existing duplicate checks match exact normalised email/phone or name-plus-company. Existing reviewed merging/history preservation can remain in control. |

## Implementation direction

Reuse the current Groq integration rather than introducing a separate provider for each feature. Share transcription, structured-output validation, account scoping, metering, caching and clear fallback states. Use AI on demand for summaries/drafts; retain inexpensive exact matching and deterministic date/saving logic where appropriate.

Keep generated facts distinguishable from saved facts. Drafts, merge suggestions and reminder changes should remain reviewable. Sending messages should remain an explicit user action.

Suggested sequence: consistent voice and retrieval reliability → conversational recall → personalised reconnect drafts → meeting briefs → smarter capture and duplicate suggestions. The current interface can be retained throughout.

## Verification boundary

This review inspected current source. No additional live calls, model benchmark, deployment, code changes or paid-service connection were performed for this review. Earlier live recall checks are historical evidence, not a new benchmark here.
