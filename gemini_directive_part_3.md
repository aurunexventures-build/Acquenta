ENGINEERING DIRECTIVE: CONTEXT-AWARE MEMORY RECALL & VIRTUAL CARD PLATFORM

**Target Assignee:** Anti-Gravity  
**Target Codebase:** `/ContactCardBuilder` (Flutter cross-platform client)  
**Infrastructure Stack:** Cloudflare Edge (Workers, D1, Vectorize, Workers AI) + Firebase Authentication  
**Status:** Architecture Approval & Phase 2 Execution Directive  

---

## 1. Executive Summary & Problem Scope

The initial Flutter MVP established core multi-persona cards, RFC vCard generation, and local weighted token scoring. However, in real-world networking scenarios, users attend high-density conferences and forget names. A year later, they search conversational concepts (e.g., *"the developer I met at Cam's meetup who builds mobile frontends"*).

Anti-Gravity must transition `/ContactCardBuilder` from a static digital card repository into an **Offline-First Neural Networking Copilot**. Key requirements include:
1. Low-friction voice and vision capture in noisy venues.
2. Two-stage hybrid search combining local SQLite FTS5 with cloud semantic vector embeddings.
3. Bidirectional delta synchronization between Drift (SQLite) and Cloudflare D1.
4. Reciprocal sharing allowing card recipients to beam their contact details back without installing an app.

---

## 2. Feature & Protocol Specifications

### 2.1 The Reciprocal Memory Drop & Native Context Stamping
* **Web Card Landing Page:** Cards shared via QR code, NFC, or wallet pass open a web URL (`https://card.domain.com/c/:cardId?event=:eventId`).
* **Reciprocal Capture Form:** Position a 5-second form directly below the "Save Contact" button: *"Share your details back with [User]"* (Fields: Full Name, Email/LinkedIn, Quick Note). Submissions push an interaction record into the user's Cloudflare D1 inbox.
* **Native vCard Context:** Upgrade `VCardService` so that every exported contact auto-populates the standard `NOTE:` and `CATEGORIES:` fields:
  ```text
  NOTE:Met at Cam's Tech Talk 2026. Discussion: Flutter architecture, message queues, and cross-platform UI. Stack: Flutter, Dart, RabbitMQ, Go.
  CATEGORIES:Cam's Tech Talk 2026,Flutter,Dart,Networking