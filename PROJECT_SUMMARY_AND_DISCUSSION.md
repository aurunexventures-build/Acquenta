# Project Summary & Strategic Discussion Document: Virtual Visiting Card & Context-Aware Memory Recall Platform

**Date:** October 2026  
**Project:** Contact Card Builder (Virtual Visiting Card with Context Memory)  
**Author / Pair:** Anit Singh & Antigravity Assistant  
**Purpose:** Comprehensive recap of discussions, competitive analysis, architectural decisions, and specific queries for consultation with Gemini regarding optimal approaches for extended/semantic search.

---

## 1. Initial Prompt & Problem Definition

### 1.1 The Core Need
Create a virtual visiting card (digital business card) application built on **Flutter** (targeting Android first, with cross-platform readiness for iOS and Web).

### 1.2 Essential Feature Requirements
1. **Multiple Card Personas:** Allow users to build and switch between multiple distinct cards:
   - Professional / Work Card
   - Personal Card
   - Side Project / Indie Builder Card
   - Event / Conference-specific Card
2. **Rich Links & Handles:** Multiple customizable links (GitHub, LinkedIn, Twitter/X, Portfolio, WhatsApp, Phone, Email, Custom URLs).
3. **No Fluff:** Skip gimmicks like virtual video conference backgrounds for now to keep the user experience ultra-fast and focused.
4. **Local-First with Cloud Roadmap:** Keep the MVP local-first (ready for Firebase Authentication and Cloudflare D1/Workers as the cloud backend).

### 1.3 The Core Problem Statement ("Context-Aware Memory Recall")
> *"Let's say there are two people, Cam and Anit. Anit is a side project developer who builds applications on Android, Flutter, and various other things. Cam met him at an event hosted by Cam's Tech Talk. Cam saved his number and LinkedIn. A year later, Cam is trying to build an app and wants to reach out to the person he met, but cannot recall his name! Cam only remembers: 'I met someone at Cam's Tech Talk who builds Android and Flutter side projects.'*
> 
> *Our application must bridge this gap: whenever a card is shared or received, it should record the event context, discussion notes, and tech stack. Later, when the user searches natural queries like 'XYZ person at Cam's Tech Talk who does Flutter', the app must instantly return who that person was."*

---

## 2. Competitive Market Analysis & Pricing Summary

We conducted a deep-dive analysis into the top digital business card platforms:

| Platform | Core Strengths | Weaknesses / Gaps | Pricing Breakdown |
| :--- | :--- | :--- | :--- |
| **HiHello** | Polished UI, 4 free cards, virtual backgrounds, email signatures. | Team/Business plans become expensive quickly; gated scan limits. | **Free** (4 cards)<br>**Pro:** \$6–\$8/mo<br>**Business/Enterprise:** Custom quote (\$5–\$8/user/mo) |
| **Popl** | NFC hardware leader, event lead capture, AI meeting voice memos. | Aggressive paywall on contacts (paywalls after 5 contacts on free tier); enterprise focus. | **Free** (1 card, heavy paywall)<br>**Pro:** \$6.40–\$7.99/mo<br>**Teams/Enterprise:** \$4,000–\$15,000+/yr |
| **Blinq** | Apple/Google Wallet integration, clean UI, Active Directory sync. | AI lead capture is an expensive add-on (\$199/mo); limited free cards (2). | **Free** (2 cards)<br>**Premium:** \$7.33–\$9.99/mo<br>**Business:** \$4.99–\$6.99/card/mo |
| **Mobilo** | 4-in-1 switchable NFC modes (Card, Lead Gen, Social, Custom URL), team leaderboards. | No viable free plan; ongoing subscription required for CRM features. | **Hardware:** \$9.50–\$69.50 one-time<br>**Pro/Teams:** \$3–\$5.50/user/mo |
| **Dot Cards** | One-time hardware purchase, no monthly fee for basic profiles. | Limited advanced CRM analytics and team management features. | **Hardware:** \$20–\$40 one-time<br>**Software:** Free forever (Dot Pro optional \$4–\$5/mo) |
| **Uniqode (Beaconstac)** | High security (SOC 2, HIPAA, GDPR), dynamic QR engine, GPS scan analytics. | Steep learning curve, strictly annual enterprise billing. | **Annual only:** \$9/mo (Essential) to \$399+/mo (Enterprise) |

### Key Market Gaps Identified
1. **Paywall Fatigue:** Users strongly resent losing access to contacts they scanned or met in person.
2. **Missing Search by Memory/Work:** None of the major apps allow querying: *"Who was the Flutter developer I met at that meetup last year?"* They all index by alphabetical name.
3. **Bring-Your-Own NFC Tag:** Major apps charge \$30–\$50 for a \$0.50 NFC chip. Giving users an open in-app NFC writer is an instant differentiator.

---

## 3. Architecture & MVP Implementation Summary

We designed and built the complete Flutter MVP in `/ContactCardBuilder`:

### 3.1 Data Models
* `ContactCard`: Supports multiple cards per user with category, full contact info, tech stack (`List<String>`), links (`List<CardLink>`), theme colors, and primary card flag.
* `EventContext`: Records `eventName`, `location`, `date`, `notes` (discussion memory), and `tags` (skills/topics).
* `SavedConnection`: Represents a contact collected at an event, binding contact details with their full `EventContext`.
* `CardLink`: Handles distinct link types (GitHub, LinkedIn, Twitter, Portfolio, WhatsApp, custom URL) with automatic icons.

### 3.2 Services & State Management
* `StorageService`: Local persistence using `SharedPreferences` with automatic seeding of realistic test data (Cam Robertson, Anit Singh, Elena Rostova, Marcus Vance, Priya Sharma).
* `VCardService`: RFC-compliant vCard 3.0 generation. **Key innovation:** embeds the event name, date met, discussion notes, and tech stack into the native contact `NOTE:` and `CATEGORIES:` fields. When exported to Apple Contacts or Google Contacts, the networking memory is never lost.
* `SearchService`: Contextual memory recall engine using weighted multi-signal scoring (phrase matching, token matching, skill tag weights, note snippet extraction).
* `CardsProvider` & `ConnectionsProvider`: State management via `provider`. Includes an **Active Event Mode** toggle (e.g. *"Currently Networking at Cam's Tech Talk"*) which auto-stamps all shared cards and saved contacts.

### 3.3 Screens & UI Components
* **My Cards Tab:** Carousel of cards, Active Event banner, quick QR share dialog, card creator/editor.
* **Connections Tab:** Rolodex of people met at conferences, categorized by event and date, 1-tap call/email/LinkedIn actions.
* **Smart Recall Tab:** Natural language memory search bar with sample query chips, event filter chips, tech stack filter chips, and match explanation badges.
* **Card Editor & Detail Screens:** Custom color palette, link editor, interactive skill tag manager.

### 3.4 Verification & Build Status
* `flutter analyze`: **0 errors, 0 warnings**.
* `flutter test`: **100% passing tests**, verifying that queries like `"Cam's Tech Talk Flutter"` rank Anit Singh as the top match.
* `flutter build web`: **Compiled in 15 seconds**.
* Android Toolchain: Configured with **Java 21 LTS (`openjdk@21`)** and **Android SDK 36**.
* `flutter build apk --debug`: **Successfully built native Android APK** at `build/app/outputs/flutter-apk/app-debug.apk`.

---

## 4. Questions & Topics for Gemini Consultation (Extended Search & Architecture)

When discussing with Gemini to determine the absolute best approach for **Extended Search & Memory Recall**, here are the specific architectural options and questions to evaluate:

### Question 1: What is the optimal architecture for "Extended / Semantic Search" in a mobile app?
* **Option A: On-Device BM25 / Full-Text Search (SQLite FTS5 / Drift)**
  * *Pros:* 100% offline, zero server cost, instant (<10ms).
  * *Cons:* Requires exact word/stem matching; struggles with pure conceptual synonyms (e.g. searching "app creator" might miss "mobile architect" unless stemmed).
* **Option B: On-Device Small Embedding Model (e.g. MobileBERT / MiniLM via ONNX Runtime or TensorFlow Lite / MediaPipe in Flutter)**
  * *Pros:* True semantic similarity offline (e.g. "someone who codes phone software" matches "Flutter developer").
  * *Cons:* Model binary size (20–40MB), RAM usage, battery consumption on cold start.
* **Option C: Hybrid Cloud Architecture (Cloudflare Workers AI + Vectorize + D1)**
  * *Pros:* Uses Cloudflare Workers AI (`@cf/baai/bge-small-en-v1.5`) to generate embeddings and Cloudflare Vectorize for nearest-neighbor similarity search. Super lightweight on the client, leverages our planned Cloudflare stack, zero infrastructure maintenance.
  * *Cons:* Requires internet connectivity at the moment of searching.
* **Option D: Two-Stage Hybrid Search (BM25 + Semantic Re-ranking)**
  * Local BM25 for instant offline results; when online, queries Cloudflare Workers AI for deeper contextual ranking.

### Question 2: How should Networking Context be captured during fast-paced in-person events?
* In a loud conference hall, typing detailed notes takes too long.
* What are the most frictionless capture mechanisms?
  1. **Quick Voice Memo (Audio to Text):** Whisper / on-device speech-to-text allowing a 5-second voice note (*"Met Anit, Flutter dev building side project apps"*), which an LLM parses into structured tags (`Role`, `Tech Stack`, `Event`).
  2. **Photo OCR of Paper Badges / Business Cards:** Fast local ML Kit OCR extracting name, company, and QR link.
  3. **Event Geofence / Calendar Auto-detect:** Automatically defaulting the `EventName` based on the user's Google/Apple calendar entry for that day/time.

### Question 3: Cloudflare & Firebase Architecture Integration
* User wants **Firebase for Authentication** and **Cloudflare for Database/Backend**.
* What is the cleanest pattern for connecting Flutter to Firebase Auth + Cloudflare D1/KV:
  * Passing Firebase JWT tokens to Cloudflare Worker endpoints via `Authorization: Bearer <token>`, where the Worker verifies the Firebase JWT using Google's public JWKS keys before executing D1 queries.
  * How should offline-first synchronization be structured between local SQLite/SharedPreferences and Cloudflare D1?

---

## 5. Summary Matrix of Next Steps

| Work Stream | Current Status | Next Action |
| :--- | :--- | :--- |
| **Flutter MVP** | Complete & Tested | Ready to run on device/emulator. |
| **Android Build** | Verified (Debug APK built) | Ready for testing or release signing configuration. |
| **Extended Search** | Multi-signal keyword & token scoring active | Awaiting Gemini recommendation on Vector/Embeddings vs. SQLite FTS5 vs. Cloudflare Workers AI. |
| **Backend Integration**| Seeded locally | Implement Cloudflare Worker with Firebase JWT verification and D1 schema. |
