### Block 1

## Strategic Architecture & Implementation Blueprint



## 1. Edge Case Engineering: When Memory & Reality Collide

Networking recall fails in predictable ways. A system designed for high-density environments must account for incomplete data, ambiguous queries, and connection drift.

                    ┌───────────────────────────────┐
                    │      High-Noise Capture       │
                    │ (Loud Hall, 10s voice memo,   │
                    │  partial badge snap, NFC tap) │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│                  On-Device Local-First Buffer (Drift)                 │
│  - Raw Audio / Text / Image Blob cached                               │
│  - Heuristic Event Stamp (Active Event Mode or Geofenced Calendar)   │
│  - Immediate L1 Full-Text Indexing (FTS5 / BM25)                     │
└───────────────────────────────────┬───────────────────────────────────┘
                                    │ (Background / When Online)
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│              Cloudflare Workers + Workers AI Pipeline                 │
│  1. Whisper Transcription (if audio)                                  │
│  2. Structured Extraction (LLM -> JSON: Tech, Role, Action Items)     │
│  3. Vector Embedding Generation (@cf/baai/bge-small-en-v1.5)          │
└──────────────────┬────────────────────────────────┬───────────────────┘
                   │                                │
                   ▼                                ▼
       ┌───────────────────────┐        ┌───────────────────────┐
       │     Cloudflare D1     │        │  Cloudflare Vectorize │
       │ (Relational Data &    │        │ (Dense Vector Index   │
       │  Contact Timelines)   │        │  for Semantic Search) │
       └───────────────────────┘        └───────────────────────┘

---

### Block 2

## ENGINEERING DIRECTIVE: CONTEXT-AWARE MEMORY RECALL & VIRTUAL CARD PLATFORM

Target Assignee: Anti-Gravity

Project Base:  (Flutter cross-platform client)   MD

Infrastructure Target: Cloudflare Edge (Workers, D1, Vectorize, Workers AI) + Firebase Authentication

Status: Architecture Approval & Phase 2 Execution Directive



## 1. System Objective & The Core Problem

The MVP built in  established basic card creation, multi-persona management, and token-based scoring. While functional, keyword matching fails the foundational scenario: a user attends a conference, meets dozens of builders, and a year later searches natural conceptual fragments (e.g., "Who was the developer I met at Cam's meetup who builds mobile frontends?") without remembering the contact's name.   MD+ 1

Anti-Gravity must transition the codebase from a static digital card holder to an Offline-First Neural Networking Copilot. This system combines zero-friction capture in loud environments, two-stage hybrid retrieval (Local BM25 + Cloud Vector Semantic Search), and a viral reciprocal exchange engine that requires no app installation for the receiver.



## 2. Core Feature Specifications



## 2.1 The Reciprocal Memory Drop & Native vCard Context Injection

* Web Landing Interface: When a card is shared via QR code, NFC tag, or mobile wallet pass, the generated URL () renders an ultra-fast web profile.


* Instant Reciprocal Capture: Beneath the "Save Contact" button, provide a lightweight form: "Share your details back with [User] in 5 seconds" (fields: Full Name, Email/LinkedIn, 1-line note). On submit, a webhook pushes an interaction record directly into the user’s inbox table.


* RFC-Compliant Context Stamping: Enhance  to ensure all exports populate the native  and  fields:   MD

PlaintextNOTE:Met at Cam's Tech Talk 2026. Discussion: Flutter architecture, message queues, and cross-platform UI. Stack: Flutter, Dart, RabbitMQ, Go.
CATEGORIES:Cam's Tech Talk 2026,Flutter,Dart,Networking

---

### Block 3

Markdown () is the optimal format for both Anti-Gravity and automation pipelines like Integromat or Make, as it preserves database schemas, TypeScript blocks, and indentation without rich-text encoding errors.

Save the following raw code block directly as  in the root of your project directory, or run the terminal command provided at the bottom to generate the file instantly.

Markdown# ENGINEERING DIRECTIVE: CONTEXT-AWARE MEMORY RECALL & VIRTUAL CARD PLATFORM

**Target Assignee:** Anti-Gravity  
**Target Codebase:** `/ContactCardBuilder` (Flutter cross-platform client)  
**Infrastructure Stack:** Cloudflare Edge (Workers, D1, Vectorize, Workers AI) + Firebase Authentication  
**Status:** Architecture Approval & Phase 2 Execution Directive  

---

## 1. Executive Summary & Problem Scope

The initial Flutter MVP established core multi-persona cards, RFC vCard generation, and local weighted token scoring. However, in real-world networking scenarios, users attend high-density conferences and forget names. A year later, they search conversational concepts (e.g., *"the developer I met at Cam's meetup who builds mobile frontends"*)[cite: 1].

Anti-Gravity must transition `/ContactCardBuilder`[cite: 1] from a static digital card repository into an **Offline-First Neural Networking Copilot**. Key requirements include:
1. Low-friction voice and vision capture in noisy venues.
2. Two-stage hybrid search combining local SQLite FTS5 with cloud semantic vector embeddings.
3. Bidirectional delta synchronization between Drift (SQLite) and Cloudflare D1.
4. Reciprocal sharing allowing card recipients to beam their contact details back without installing an app.

---

## 2. Feature & Protocol Specifications

### 2.1 The Reciprocal Memory Drop & Native Context Stamping
* **Web Card Landing Page:** Cards shared via QR code, NFC, or wallet pass open a web URL (`https://card.domain.com/c/:cardId?event=:eventId`).
* **Reciprocal Capture Form:** Position a 5-second form directly below the "Save Contact" button: *"Share your details back with [User]"* (Fields: Full Name, Email/LinkedIn, Quick Note). Submissions push an interaction record into the user's Cloudflare D1 inbox.
* **Native vCard Context:** Upgrade `VCardService`[cite: 1] so that every exported contact auto-populates the standard `NOTE:` and `CATEGORIES:` fields[cite: 1]:
  ```text
  NOTE:Met at Cam's Tech Talk 2026. Discussion: Flutter architecture, message queues, and cross-platform UI. Stack: Flutter, Dart, RabbitMQ, Go.
  CATEGORIES:Cam's Tech Talk 2026,Flutter,Dart,Networking