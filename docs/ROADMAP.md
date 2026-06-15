# ARIA — Development Roadmap

## Document Information

| Field | Value |
|---|---|
| Version | 1.0.0 |
| Date | 2026-06-15 |
| Last Updated | 2026-06-15 |
| Owner | ARIA Core Team |
| Status | Active |

---

## 1. Overview

ARIA is built on a single operating philosophy: **ship fast, measure everything, and iterate ruthlessly toward user value.** This roadmap reflects a phased development approach that begins with a tightly scoped MVP — proving that a conversational AI can meaningfully improve how people manage their time and memory — and expands systematically into a fully featured, enterprise-ready productivity platform.

Each phase has explicit success criteria defined before the work begins. A phase is not "done" when its feature list is checked off; it is done when its success metrics are achieved. This prevents the trap of shipping features that no one uses, and forces honest conversations about whether the product is working.

The phased structure serves multiple goals:

- **De-risk early:** The MVP costs less to build and less to be wrong about. If the core AI-calendar loop does not resonate with users, we learn this in weeks, not months.
- **Compound learning:** Each phase generates data that informs the next. Voice feature prioritization in Phase 1 is informed by MVP usage patterns. Enterprise features in Phase 3 are informed by which Pro users ask for team functionality.
- **Sustainable execution:** Small teams ship reliable software when scope is controlled. We protect quality by not overloading sprints with P2 work while P0s are still rough.

The roadmap covers four stages: MVP (Weeks 1–4), Phase 1 / Public Beta (Months 1–3), Phase 2 / Growth (Months 4–6), and Phase 3 / Scale & Enterprise (Months 7–12). Revenue projections, infrastructure milestones, and risk mitigation strategies accompany each stage.

---

## 2. Guiding Principles

### User Value Over Feature Count
A product with ten features that each solve a real problem is worth more than one with fifty features where most go unused. Every item added to the backlog must answer the question: *which user problem does this solve, and how do we know that problem exists?* Features with no validated user demand are deprioritized regardless of how technically interesting they are.

### Quality Over Quantity — Robust P0s Beat Broken P2s
A broken core experience destroys trust faster than a missing nice-to-have feature. The AI response pipeline, authentication system, and calendar sync must be rock-solid before any stretch features are shipped. If P95 latency on the conversation API is 4 seconds, nothing else on the sprint matters until that is fixed.

### Data-Driven Decisions
Gut instinct has a role in early product discovery. It does not have a role in deciding what to build in Month 5. By Phase 1, every significant product decision is backed by analytics data, user interviews, or both. We define metrics targets *before* shipping features and hold ourselves accountable to them.

### Security and Privacy from Day One, Not Bolted On
ARIA processes some of the most sensitive data a person generates: their calendar, their conversations, their travel plans, their relationships. Security is not a compliance checkbox completed before an audit — it is an architectural property embedded from the first line of code. JWT authentication, data encryption at rest, principle of least privilege in API design, and explicit user consent for data collection are non-negotiable from Week 1. Privacy features (data export, account deletion, memory management) are scheduled in Phase 1, not Phase 3.

---

## 3. MVP — Weeks 1–4

### Goal

Prove the core value proposition: **a conversational AI can manage a user's calendar, tasks, and memory better than existing tools.** The MVP is not a polished consumer product. It is a working prototype used internally by the team to validate that the fundamental loop — user asks ARIA something, ARIA does something useful with calendar and task data, user's day improves — is real. Every feature outside this loop is out of scope for the MVP.

---

### Week 1: Foundation

**Backend**
- [ ] FastAPI project structure with modular routers (`/auth`, `/users`, `/tasks`, `/events`, `/conversations`)
- [ ] Docker Compose local development environment (FastAPI, PostgreSQL 15, Redis, Qdrant)
- [ ] PostgreSQL schema v1: `users`, `sessions`, `conversations`, `messages`, `tasks`, `events`, `memories`
- [ ] Alembic database migrations setup
- [ ] JWT authentication: register, login, token refresh, logout (token blocklist in Redis)
- [ ] Basic CRUD APIs for users, tasks, and events with Pydantic v2 validation
- [ ] Rate limiting middleware (slowapi)
- [ ] Environment configuration (pydantic-settings, `.env` support)
- [ ] Structured logging (JSON format, correlation IDs)

**Mobile (Flutter)**
- [ ] Flutter project structure: feature-first folder layout (`features/auth`, `features/chat`, `features/tasks`, `features/calendar`, `features/settings`)
- [ ] Navigation architecture (go_router, bottom tab bar: Chat, Tasks, Calendar, Settings)
- [ ] Auth screens: Login, Register, Forgot Password
- [ ] HTTP client setup (dio with interceptors for JWT attach + refresh)
- [ ] Secure token storage (flutter_secure_storage)
- [ ] Basic theme system (light mode, typography, color tokens)

**DevOps**
- [ ] GitHub repository with branch protection on `main`
- [ ] GitHub Actions CI pipeline: lint (ruff for Python, flutter analyze), unit tests, Docker build
- [ ] Pre-commit hooks: ruff, black, isort
- [ ] Secrets management: GitHub Secrets for CI, local `.env` excluded from git

---

### Week 2: AI Core

**Backend**
- [ ] Anthropic Claude API integration with tool use (function calling)
- [ ] AI engine service: conversation context assembly, tool dispatch, response parsing
- [ ] Conversation API: `POST /conversations`, `GET /conversations/{id}/messages`, streaming SSE endpoint
- [ ] Claude tool definitions: `create_task`, `update_task`, `query_calendar`, `search_memory`, `create_event`
- [ ] Qdrant vector database setup with collection schema (memories, conversation embeddings)
- [ ] sentence-transformers embedding service (async, batched)
- [ ] Memory storage pipeline: extract facts from AI response → embed → store in Qdrant
- [ ] Memory retrieval pipeline: embed user query → cosine similarity search → inject into prompt
- [ ] Basic intent classification (regex + Claude classification): create_task, check_calendar, ask_question, other

**Mobile (Flutter)**
- [ ] Chat screen with message bubble rendering (user vs. ARIA)
- [ ] Streaming response rendering (SSE client, incremental text display)
- [ ] Message input bar with send button and character counter
- [ ] Loading states: typing indicator (three-dot animation) while ARIA processes
- [ ] Error state: failed message with retry button

**Testing**
- [ ] Unit tests for AI engine: tool dispatch logic, context assembly, memory injection
- [ ] Unit tests for embedding service: encode, store, retrieve cycle
- [ ] Integration test: full conversation round-trip with mocked Claude API

---

### Week 3: Integrations & Calendar

**Backend**
- [ ] Google Calendar OAuth2 integration (oauth2client, scopes: `calendar.readonly`, `calendar.events`)
- [ ] OAuth callback handler and token storage (encrypted in database)
- [ ] Calendar sync background worker (Celery + Redis broker)
- [ ] Celery beat scheduler: calendar sync every 5 minutes per connected user
- [ ] Events CRUD API: `GET /events`, `POST /events`, `PUT /events/{id}`, `DELETE /events/{id}`
- [ ] Google Calendar → internal schema normalization (title, start, end, attendees, location, video_link)
- [ ] Task management API: priority field (low/medium/high/urgent), status (todo/in_progress/done/cancelled), due_date, reminder_at
- [ ] Push notification infrastructure: Firebase Cloud Messaging (FCM) for Android, APNs token registration for iOS
- [ ] Morning briefing notification: Celery beat job at 7:00 AM user-local-time, generates summary via Claude, sends push

**Mobile (Flutter)**
- [ ] Calendar screen: monthly view (table_calendar) + day detail view
- [ ] Calendar event detail sheet: title, time, location, attendees, video link join button
- [ ] Task screen: grouped by due date, filterable by status and priority, sortable
- [ ] Task creation/edit form: title, notes, priority picker, due date picker, reminder toggle
- [ ] Swipe-to-complete on task list items

---

### Week 4: Polish & Internal Launch

**Backend**
- [ ] Persistent memory pipeline: after each conversation turn, extract memorable facts (name mentions, preferences, decisions, commitments) and store in Qdrant with metadata
- [ ] Meeting detection worker: scan upcoming events, detect meetings within 30 minutes, send pre-meeting push notification with attendee list
- [ ] Basic settings API: update profile (name, timezone), notification preferences, connected accounts list
- [ ] Health check endpoint (`GET /health`) with DB and Redis connectivity checks
- [ ] Error handling middleware: consistent JSON error responses with `error_code` + `message`

**Mobile (Flutter)**
- [ ] Onboarding flow: permission grants (notifications, calendar), integration setup (Google Calendar OAuth), personalization quiz
- [ ] Error handling throughout: network errors, auth errors, empty states, loading states
- [ ] Basic Settings screen: profile section, notification toggles, connected accounts, sign out
- [ ] App icon and splash screen
- [ ] TestFlight build (iOS) + internal APK (Android)

**Launch**
- [ ] Internal dog-fooding launch to team (10–20 people)
- [ ] Crash reporting setup (Sentry for both Flutter and FastAPI)
- [ ] Internal feedback collection (simple Google Form linked from Settings)
- [ ] Bug triage process: P0 (same day), P1 (within 48h), P2 (next sprint)
- [ ] Week 4 retrospective and bug-fix sprint based on internal feedback

---

### MVP Success Criteria

- [ ] Authentication works reliably with zero token refresh failures in 48-hour soak test
- [ ] AI responds accurately to task creation intent >85% of the time across 100 test prompts
- [ ] AI responds accurately to calendar query intent >85% of the time across 100 test prompts
- [ ] Google Calendar sync reflects changes within 5 minutes of modification
- [ ] P50 API response time < 500ms on conversation endpoint
- [ ] P95 API response time < 2 seconds on conversation endpoint (excluding streaming)
- [ ] Zero data loss incidents (tasks, events, memories) during internal testing period
- [ ] Team satisfaction score: 8/10 or higher on internal survey

### MVP Metrics Targets

| Metric | Target |
|---|---|
| Internal users | 10–20 |
| Daily active sessions | ≥ 80% of registered users |
| AI accuracy rate (task/calendar intents) | > 85% |
| Crash rate | < 1% of sessions |
| API uptime | ≥ 99% |
| Calendar sync lag | < 5 minutes |
| P95 API latency | < 2 seconds |

---

## 4. Phase 1 — Months 1–3: Public Beta

### Goal

Launch ARIA to the public. Acquire the first 1,000 registered users. Validate the product-market fit hypothesis — that professionals will pay $9.99/month for a conversational AI that manages their calendar, tasks, and memory — and validate the monetization model with at least 50 paying Pro subscribers.

---

### Month 1: Voice & Proactive Intelligence

#### Voice Commands

- [ ] Whisper STT API integration (OpenAI Whisper large-v3 via API)
- [ ] Voice recording service: audio capture, VAD (voice activity detection), chunked upload
- [ ] Voice processing pipeline: `POST /voice/transcribe` → Whisper → transcript → `POST /voice/process` → AI engine → structured response
- [ ] Audio storage: voice recordings uploaded to S3 with signed URL, auto-deleted after 24h
- [ ] Text-to-speech response: Amazon Polly or ElevenLabs for ARIA voice replies
- [ ] Voice recording UI in Flutter: microphone button in chat input, waveform visualization (audio_waveforms package), auto-stop on 1.5s silence, cancel gesture
- [ ] Transcript review screen: shows Whisper output before sending, allow edit
- [ ] Background voice processing queue (Celery) for longer recordings
- [ ] Voice preferences in Settings: enable/disable TTS response, preferred ARIA voice

#### Proactive Suggestions

- [ ] Rule-based suggestion engine: configurable trigger rules evaluated by Celery beat
  - If meeting in < 2 hours and no agenda noted: suggest briefing prep
  - If task due today and not started: surface at 9 AM
  - If travel event in < 48 hours and packing list not created: prompt
  - If no tasks created in 3 days: "Anything on your mind to capture?"
- [ ] Travel time calculation: Google Maps Distance Matrix API, origin = user home location, estimates leave-by time before meetings with location set
- [ ] Smart task reminders: compute urgency score (due date proximity + task priority + user historical completion patterns)
- [ ] "Did you forget anything?" prompts: triggered when travel event detected in next 24h, generates personalized packing/prep checklist via Claude

#### Memory Enhancement

- [ ] Memory categorization: NLP auto-tagging with categories (person, place, project, preference, decision, commitment, fact)
- [ ] Memory importance scoring: composite score from recency, access frequency, entity type weight, user explicit feedback
- [ ] Memory decay: importance score decreases over time for non-accessed memories (tunable half-life)
- [ ] Memory consolidation: periodic job summarizes clusters of related low-importance memories into a single higher-level memory
- [ ] Memory search UI: dedicated search screen within the app, semantic search via Qdrant
- [ ] Memory management screen: list all memories with category filters, tap to view full text, swipe to delete, edit capability

---

### Month 2: Travel Planning

#### Travel Features

- [ ] Travel intent detection: NLP pattern matching + Claude classification to identify travel-related conversation turns
  - Triggers on: destination mentions, "flight", "hotel", "trip", "conference in [city]", "I need to travel"
- [ ] Multi-turn clarification dialogue: ARIA asks for missing trip details (dates, return date, origin city, budget)
- [ ] Amadeus API integration: flight search (`GET /shopping/flight-offers`), caching results for 15 minutes
- [ ] Hotel search integration: Amadeus hotel search or Booking.com API
- [ ] Travel plan data model: `travel_plans` table with status machine (planning → searching → confirmed → monitoring → completed)
- [ ] Travel plan creation and management UI: list of trips, trip detail screen with tabs (Overview, Flights, Hotels, Itinerary)
- [ ] Trip itinerary builder: day-by-day view, add/edit/delete items via conversation or manual tap
- [ ] Flight monitoring worker: checks flight status every 4 hours via AviationStack or Amadeus Flight Status API
- [ ] Real-time travel disruption notifications:
  - Departure delay > 30 minutes → immediate push
  - Gate change → immediate push
  - Cancellation → immediate push + suggest alternatives
  - Weather alert at destination → push 24h before
- [ ] Destination briefing generation: Claude-generated overview including weather forecast (OpenWeatherMap), local time and UTC offset, currency and exchange rate (Fixer.io), visa requirements summary, top landmarks

#### Meeting Intelligence (Enhanced)

- [ ] Action item extraction: after meeting context is processed, Claude identifies explicit and implicit action items with assignee and deadline
- [ ] Post-meeting follow-up suggestions: "Send the proposal to Acme team?", "Book the follow-up call Sarah mentioned?"
- [ ] Meeting attendee context: for each calendar attendee, search memory + past calendar events to generate relationship context card
- [ ] Meeting notes capture (voice): "Start meeting mode" in app → real-time Whisper transcription (streaming) → transcript displayed live → keyword highlighting for action items, decisions, deadlines
- [ ] Post-meeting processing: transcript → Claude extraction → action items created as tasks, summary stored as memory

---

### Month 3: Beta Launch & Growth

#### Public Launch Preparation

- [ ] App Store submission (iOS): screenshots, app description, privacy policy, age rating
- [ ] Google Play submission (Android): store listing, content rating questionnaire, data safety section
- [ ] Landing page at aria.ai: hero, feature highlights, social proof, pricing, waitlist → open beta CTA
- [ ] Waitlist management: progressive rollout from waitlist to open beta
- [ ] In-app feedback mechanism: floating feedback button → category selection → free text → optional screenshot attach → Zendesk ticket creation
- [ ] Crash reporting: Sentry configured for both Flutter (sentry_flutter) and FastAPI (sentry-sdk), with user context attached
- [ ] Analytics: Amplitude SDK integrated in Flutter, tracking all key events with user properties (plan, platform, timezone)
- [ ] Product Hunt launch: scheduling, hunter outreach, asset preparation, launch day response plan

#### Additional Integrations

- [ ] Microsoft Outlook / Office 365: OAuth2 with Microsoft Graph API, calendar sync parity with Google Calendar
- [ ] Slack integration:
  - OAuth with Slack API (scopes: `channels:read`, `im:read`, `chat:write`)
  - Read and summarize unread DMs on user request
  - Send Slack messages via ARIA command ("Tell John on Slack that I'll be 5 minutes late")
- [ ] Gmail integration:
  - OAuth with Gmail API (scopes: `gmail.readonly`, `gmail.compose`)
  - Email summarization: "What important emails did I get today?"
  - Draft reply generation: "Draft a reply to Sarah's email about the budget"

#### Monetization Infrastructure

- [ ] Stripe integration: Products and Prices configured (Free, Pro monthly, Pro annual)
- [ ] Subscription management API: `POST /billing/subscribe`, `POST /billing/cancel`, `GET /billing/status`
- [ ] Usage metering: message count per user per day tracked in Redis, enforced at conversation API layer
- [ ] Free tier enforcement: 50 messages/day hard limit, 100 memory limit with soft warning at 80
- [ ] Paywall screens: upgrade prompt modal triggered on limit approach, feature-gate screens for Pro features
- [ ] Billing portal: Stripe Customer Portal link generated server-side, opened in in-app browser
- [ ] Webhook handler: Stripe webhooks for `customer.subscription.created`, `customer.subscription.deleted`, `invoice.payment_failed`
- [ ] Subscription status synced to user record in PostgreSQL (source of truth: Stripe)

---

### Phase 1 Success Criteria

| Metric | Target |
|---|---|
| Registered users | 1,000 |
| MAU | 700 (70% of registered) |
| D30 retention | ≥ 40% |
| Pro conversion rate | ≥ 5% (50 paying users) |
| MRR | ≥ $500 |
| NPS | ≥ 30 |
| App Store rating (iOS) | ≥ 4.0 stars |
| Play Store rating | ≥ 4.0 stars |
| P95 API latency | < 2 seconds |
| System uptime | ≥ 99.5% |
| Voice command success rate | ≥ 80% |

---

## 5. Phase 2 — Months 4–6: Growth & Differentiation

### Goal

Scale to 10,000 MAU. Launch Pro tier at scale. Differentiate ARIA from generic AI assistants through superior long-term memory, proactive intelligence, and a rich integration ecosystem. Begin building the foundation for Enterprise.

---

### Month 4: Advanced AI Capabilities

#### Memory Intelligence

- [ ] Long-term memory consolidation: nightly job compresses clusters of older, lower-importance memories into higher-level semantic summaries; preserves access frequency and original timestamps as metadata
- [ ] Memory graph: graph data structure (stored in PostgreSQL with adjacency table) representing relationships between memory entities (people, projects, places, organizations, decisions)
- [ ] Memory graph visualization: interactive graph UI in app (memory network screen)
- [ ] Personalization model: learn user's communication preferences (formal vs. casual), typical working hours, priority weighting style, preferred response length
- [ ] Contextual memory injection: retrieval system selects memories based on combination of semantic similarity, recency, entity overlap with current conversation, and importance score
- [ ] Memory health score: user-facing metric showing memory coverage (how well ARIA knows the user) with improvement suggestions ("Tell ARIA about your team members")

#### Proactive AI Enhancement

- [ ] Behavioral pattern learning: track time-of-day activity patterns, weekly recurring events, most frequent task types → build user routine model
- [ ] Predictive scheduling suggestions: "You usually block focus time on Tuesday mornings — your calendar is open, want me to protect 9–11 AM?"
- [ ] Anomaly detection: identify deviations from learned patterns and surface gently → "You haven't added any tasks this week — everything going smoothly?"
- [ ] Contextual morning briefings: briefing content adapts to day type
  - Travel day: lead with flight info, airport timing, packing reminder
  - Heavy meeting day: lead with meeting prep, schedule overview, suggest calendar cleanup
  - Light day: lead with backlog tasks, suggest proactive work
  - Weekend: minimal briefing, only if user has opted in

#### Multi-language Support

- [ ] UI localization: English (en), Spanish (es), French (fr), German (de), Portuguese (pt-BR), Japanese (ja)
- [ ] Flutter l10n setup with ARB files, auto-detection from device locale, manual override in Settings
- [ ] Multi-language STT: Whisper language auto-detection + user preferred language setting
- [ ] Multi-language TTS: Polly/ElevenLabs voice selection per language
- [ ] Cross-language memory search: embed queries and memories in language-agnostic embedding space (multilingual-e5-large)
- [ ] ARIA system prompt localization: responses in user's preferred language

---

### Month 5: Platform Expansion

#### Third-Party Integration Expansion

- [ ] Notion integration:
  - OAuth with Notion API
  - Read pages and databases on request ("What's in my Notion project plan?")
  - Write tasks to Notion databases
  - Sync ARIA tasks to a Notion database (bidirectional, optional)
- [ ] GitHub integration:
  - OAuth with GitHub API
  - PR notifications: "You have 3 PRs awaiting review"
  - Issue tracking: create GitHub issues from ARIA conversation
  - Daily digest: assigned issues and open PR summary
- [ ] Zoom / Google Meet integration:
  - Detect video conference links in calendar events
  - One-tap join reminder notification
  - Meeting start notification with join link in briefing
- [ ] Spotify integration:
  - OAuth with Spotify API
  - "Play focus music" → starts user's focus playlist
  - Travel mood music: "Play something for a long flight"
- [ ] Uber / Lyft integration:
  - OAuth with Uber/Lyft API
  - "Book a ride to the airport" → estimates, user confirms → books
  - Pre-meeting ride suggestion: "Your meeting is at 3 PM downtown. Book a ride?"
- [ ] Integration marketplace UI: settings screen listing all available integrations with connected/disconnected state, one-tap OAuth flows, permission scopes explained

#### Widgets & Extensions

- [ ] iOS home screen widget: small (next event + 1 task), medium (full day summary), large (tasks + events + memory of the day)
- [ ] Android home screen widget: equivalent sizes using Glance API (Jetpack Compose for widgets, accessed via Flutter platform channel)
- [ ] Apple Watch app: WatchKit extension with glanceable briefing complication, quick voice command via Watch microphone, task completion from wrist
- [ ] Browser extension (Chrome/Safari): "Capture to ARIA" button, clip selected text as memory, create task from current page URL + title

---

### Month 6: Analytics & Enterprise Prep

#### User Analytics Dashboard (In-App)

- [ ] Weekly productivity report: tasks completed, meetings attended, response time trends, memory items added
- [ ] Monthly executive summary: month-over-month task completion rate, meeting load, AI interaction count
- [ ] Meeting load analysis: time spent in meetings per week, meeting-to-focus-time ratio, busiest meeting days
- [ ] Task completion trends: completion rate by priority, average time from creation to completion, overdue task patterns
- [ ] Travel frequency insights: trips per month, most visited cities, average trip duration
- [ ] Memory growth over time: memory item count chart, category breakdown, memory utilization score

#### Enterprise Foundations

- [ ] SSO (SAML 2.0): service provider configuration, OKTA and Azure AD tested and certified
- [ ] SCIM provisioning: auto-provision/deprovision users when connected to identity provider
- [ ] Admin dashboard (web): user list with activity data, license assignment, usage analytics, billing overview
- [ ] Team workspaces: workspace entity with member roles (Admin, Manager, Member), shared event visibility, delegated task management (Manager can assign tasks to Members)
- [ ] Data export: GDPR-compliant full account export (JSON + CSV), includes all conversations, tasks, events, memories; downloadable within 24 hours of request
- [ ] Advanced audit logs: all data access and modification events logged with user, timestamp, IP, action; exportable by Admin; 1-year retention

---

### Phase 2 Success Criteria

| Metric | Target |
|---|---|
| MAU | 10,000 |
| D30 retention | ≥ 50% |
| Pro conversion rate | ≥ 8% |
| MRR | ≥ $8,000 |
| NPS | ≥ 45 |
| Enterprise pilot customers | 3 |
| P95 API latency | < 1.5 seconds |
| System uptime | ≥ 99.9% |
| Integration connections per user (avg) | ≥ 2.5 |

---

## 6. Phase 3 — Months 7–12: Scale & Enterprise

### Goal

Reach $100,000 MRR. Launch the Enterprise tier at scale. Build ARIA into a platform with a public API and developer ecosystem. Achieve SOC 2 Type II certification. Expand into new markets and use cases.

---

### Months 7–8: Enterprise Launch

#### Enterprise Features

- [ ] Enterprise admin portal: full-featured web application (separate from mobile app) for IT administrators
  - User management: invite, deactivate, role assignment, license tracking
  - Usage analytics: per-user and aggregate AI message count, feature adoption, active days
  - Billing: invoice history, seat count management, purchase order support
  - Security settings: SSO enforcement, MFA requirement, allowed IP ranges, session timeout configuration
- [ ] Role-based access control (RBAC):
  - Admin: full workspace control, billing, user management
  - Manager: team task assignment, view team members' shared events, delegate
  - Member: standard user capabilities within workspace
- [ ] Centralized billing and invoicing: Stripe Invoicing with NET-30 terms for Enterprise, PO number field, PDF invoice download
- [ ] Custom data retention policies: Admin-configurable retention windows for conversations (30/60/90/180/365 days), memories (per category), voice recordings (override default 24h to 0h if privacy required)
- [ ] Private cloud / VPC deployment option: Terraform modules and deployment runbooks for customer-managed AWS accounts; ARIA Backend + Qdrant + PostgreSQL deployed in customer VPC with no data leaving their environment
- [ ] Dedicated customer success onboarding: kickoff call template, configuration checklist, 30/60/90 day check-in schedule
- [ ] Enterprise SLA: 99.9% monthly uptime commitment, service credits (10% for <99.9%, 25% for <99.5%), status page (status.aria.ai)
- [ ] SOC 2 Type I audit initiation: engage audit firm, complete readiness assessment, remediate gaps, submit for Type I report

#### Team Collaboration

- [ ] Shared meeting briefings: all calendar attendees within a workspace receive the same meeting briefing with shared context
- [ ] Team task assignment: create tasks and assign to workspace members, assignee receives push notification
- [ ] Shared travel itineraries: travel plans shareable with workspace members (view-only or collaborative edit)
- [ ] Team availability view: Freebusy overlay from all workspace members' calendars, visible to Admins and Managers
- [ ] @mentions and shared context: @mention a workspace member in ARIA conversation to pull in shared memories and context relevant to that person

---

### Months 9–10: ML Personalization & API Platform

#### On-Device ML

- [ ] On-device intent classification (Privacy Mode): CoreML (iOS) / TFLite (Android) model for local intent classification; in Privacy Mode, intent classified on-device, only the classified intent (not raw text) is sent to server
- [ ] Local embedding generation option: on-device BERT model (MobileBERT) generates embeddings locally; embeddings sent to Qdrant without raw text leaving device
- [ ] Differential privacy for model improvements: user-consented aggregate usage data collected with ε-differential privacy guarantees before contributing to model fine-tuning
- [ ] Model fine-tuning pipeline: adapter-based fine-tuning (LoRA) on aggregate anonymized data to improve intent classification accuracy and memory extraction quality
- [ ] Privacy dashboard: user-facing screen explaining what data is processed on-device vs. server, opt-out controls for each data type

#### ARIA API Platform

- [ ] Public REST API: versioned (`/v1/`), documented with OpenAPI 3.1, covers conversations, tasks, events, memories, voice
- [ ] API key management: user/org can generate named API keys with scoped permissions and expiry dates, revocable from dashboard
- [ ] Webhook system: outbound HTTP webhooks for events (`task.created`, `task.completed`, `event.upcoming`, `memory.created`, `travel.alert`), configurable per endpoint with HMAC signature verification
- [ ] Developer documentation site (docs.aria.ai): Mintlify or Docusaurus, quickstart guide, API reference, code samples in Python/JavaScript/Go, interactive playground
- [ ] Partner program launch: application process for integration partners, co-marketing opportunities, revenue share for partners driving Enterprise referrals
- [ ] API rate limits and billing: tiered rate limits (free: 100 req/day, paid: 10,000 req/day, Enterprise: custom), usage tracked per API key, overage billing via Stripe Metered Billing

---

### Months 11–12: Market Expansion

#### Advanced Travel

- [ ] Automated booking with approval flow: ARIA finds best flight option → presents for approval → user approves → API calls booking endpoint → confirmation stored in app
- [ ] Travel expense tracking: capture receipts via photo (OCR with Amazon Textract), categorize expenses, generate expense report (PDF)
- [ ] Visa and entry requirement checking: integration with Sherpa or Timatic API, provides destination-specific visa requirements based on user's nationality (stored in profile)
- [ ] Travel insurance recommendations: partner API integration, surface options based on trip details and user preference
- [ ] Loyalty program tracking: user enters airline/hotel loyalty numbers, ARIA tracks points balance and tier status, factors into flight/hotel recommendations (e.g., prefer airlines where user has status)

#### Platform Intelligence

- [ ] Cross-user privacy-preserving trend insights: aggregated, differentially private insights surfaced to users ("Users with similar meeting loads find Tuesday focus blocks most effective")
- [ ] Industry-specific memory templates: pre-built memory ontologies for legal (matter, client, deadline), medical (patient, appointment, prescription), finance (deal, counterparty, close date) — Enterprise feature
- [ ] Custom AI persona configuration: Enterprise customers can configure ARIA's name, greeting style, and system prompt additions to match company brand
- [ ] Multi-AI model support: user or Admin can select underlying LLM: Anthropic Claude (default), OpenAI GPT-4o, Google Gemini Pro; ARIA abstracts the model layer via a unified prompt interface
- [ ] SOC 2 Type II certification: complete Type II audit period (minimum 6 months of evidence), receive certification, publish on trust center page

---

### Phase 3 Success Criteria

| Metric | Target |
|---|---|
| MAU | 50,000 |
| Enterprise customers | ≥ 20 |
| D30 retention | ≥ 60% |
| MRR | ≥ $100,000 |
| ARR run rate | ≥ $1,200,000 |
| NPS | ≥ 55 |
| API platform developers | ≥ 100 |
| System uptime | ≥ 99.95% |
| SOC 2 Type II | Certified |

---

## 7. Monetization Strategy

### 7.1 Pricing Tiers

#### Free Tier — $0/month

Designed to deliver genuine value while creating natural upgrade pressure through usage limits.

| Feature | Free Limit |
|---|---|
| AI messages | 50 per day |
| Memory storage | 100 items |
| Calendar integrations | 1 (Google Calendar only) |
| Task management | Basic (no priority, no sub-tasks) |
| Conversation history | 3 days rolling |
| Voice commands | 5 per day |
| Travel planning | Not available |
| Meeting intelligence | Pre-meeting notification only (no briefing) |
| Integrations | None (Slack, Gmail, Notion locked) |
| Support | Community forum |

#### Pro Tier — $9.99/month (or $7.99/month billed annually — 20% discount)

Designed for individual professionals who want ARIA as a daily driver.

| Feature | Pro |
|---|---|
| AI messages | Unlimited |
| Memory storage | Unlimited |
| Calendar integrations | All (Google, Outlook, Apple) |
| Voice commands | Unlimited |
| Travel planning | Full (search, itinerary, monitoring) |
| Meeting intelligence | Full briefings, voice capture, action item extraction |
| Integrations | All (Slack, Gmail, Notion, GitHub, Zoom, Spotify, Uber) |
| iOS / Android widget | Included |
| Conversation history | Unlimited |
| API access | Read-only (personal use) |
| Priority API routing | Yes (lower latency queue) |
| Support | Email, 24-hour response SLA |
| Analytics dashboard | Weekly/monthly productivity reports |

#### Enterprise Tier — $29.99/user/month (minimum 5 users, billed annually)

Designed for teams and organizations that need collaboration, compliance, and control.

| Feature | Enterprise |
|---|---|
| Everything in Pro | Included |
| Team workspace | Shared events, delegated tasks, @mentions |
| SSO | SAML 2.0, OKTA, Azure AD |
| SCIM provisioning | Automated user lifecycle |
| Admin dashboard | Full user management, usage analytics, billing |
| Custom data retention | Admin-configurable per data type |
| Audit logs | 1-year retention, exportable |
| RBAC | Admin / Manager / Member roles |
| Dedicated support | Named Slack channel, 4-hour response SLA |
| Customer success manager | Onboarding + quarterly business reviews |
| SLA | 99.9% uptime with service credits |
| Private cloud deployment | Customer-managed VPC option |
| Custom AI persona | Name, style, system prompt additions |
| API access | Full read/write (organizational use) |
| SOC 2 Type II | Certification available upon request |
| Volume discounts | 10% at 50+ seats, 20% at 200+ seats |

---

### 7.2 Monetization Assumptions

These assumptions are stated explicitly so they can be tested and updated with real data.

| Assumption | Value | Validation Method |
|---|---|---|
| Free-to-Pro conversion rate | 5–10% within 90 days | Cohort analysis by signup month |
| Annual plan uptake among Pro subscribers | 40% | Billing data at subscription creation |
| Avg Enterprise deal size (ARR) | $3,000 (10 users × $29.99 × 12 months) | CRM deal tracking |
| Enterprise sales cycle | 60–90 days | Pipeline velocity tracking |
| Net Revenue Retention (Enterprise) | 120% (20% expansion from seat growth and upsells) | Annual cohort NRR calculation |
| Pro subscriber churn rate | 5% monthly | Stripe subscription events |
| CAC (paid acquisition, Pro) | < $30 | Blended CAC by channel from attribution |

---

### 7.3 Revenue Projections

| Metric | Month 3 | Month 6 | Month 12 |
|---|---|---|---|
| Free users | 950 | 9,200 | 47,500 |
| Pro subscribers | 50 | 800 | 2,000 |
| Enterprise seats | 0 | 50 | 500 |
| Pro MRR | $500 | $8,000 | $20,000 |
| Enterprise MRR | $0 | $1,500 | $14,995 |
| **Total MRR** | **$500** | **$9,500** | **$34,995** |
| **Total ARR (run rate)** | **$6,000** | **$114,000** | **$419,940** |

> Note: Month 12 ARR run rate grows to $1.2M+ as Enterprise deals signed in Q4 annualize into Year 2. These projections assume organic growth plus a modest paid acquisition budget of $5,000/month starting Month 4.

---

### 7.4 Unit Economics

| Metric | Target | Notes |
|---|---|---|
| CAC (paid, Pro user) | < $30 | All-in cost including ad spend, referral credits |
| CAC (organic, Pro user) | < $5 | Content + App Store optimization cost amortized |
| LTV (Pro, 18-month avg retention) | > $150 | $9.99 × 15 months (accounting for 5% monthly churn) |
| LTV:CAC ratio | > 5:1 | Industry benchmark for SaaS health: 3:1 minimum |
| Payback period (paid Pro) | < 4 months | CAC / (MRR × gross margin) |
| Gross margin target | > 70% | API costs (Claude, Whisper) are primary COGS |
| API cost per active Pro user/month | < $2.00 | Claude API + Whisper + Polly + AWS |

**Cost Management Notes:** Claude Haiku used for simple intents (task creation, calendar queries) at ~$0.003/1K tokens. Claude Sonnet used for complex reasoning (travel planning, meeting briefings) only. Caching of repeated prompts (system prompt, user profile) via Anthropic Prompt Caching reduces costs ~40%.

---

### 7.5 Growth Strategy

#### Organic Growth
- **App Store Optimization (ASO):** keyword optimization for "AI calendar assistant", "smart task manager", "AI productivity app"; screenshots A/B tested quarterly; review solicitation prompt after positive interactions
- **Content marketing:** ARIA Productivity Blog covering topics: meeting efficiency, async communication, travel productivity, AI tools for professionals. Target 4 posts/month. SEO-optimized.
- **Product Hunt launch:** planned for Month 3 beta launch. Goal: Top 5 Product of the Day. Drives initial spike + backlinks.
- **Twitter/X and LinkedIn:** founders post authentic builds-in-public content during MVP and Phase 1. Target 5,000 followers by Month 6.

#### Referral Program
- Pro subscribers receive a unique referral link
- Referred user signs up for Pro → referrer gets 1 month free (credit applied to next invoice)
- Referred user gets 14-day Pro trial (extended from default 7-day)
- Referral tracking via PostHog + Stripe metadata
- Target: 15% of new Pro subscriptions from referral by Month 6

#### B2B / Enterprise Pipeline
- Outbound via LinkedIn Sales Navigator: target Chief of Staff, Executive Assistant, Operations Manager at 50–500 person companies
- Conference sponsorships: productivity and operations conferences (Asana Together, Notion Ambassador events)
- Partner referrals: Notion, Slack integration partners refer enterprise customers who need AI layer on top

#### Partnership Co-Marketing
- Integration partners (Notion, Slack, Amadeus) co-author blog posts and case studies
- Featured in partner app directories and marketplaces
- Joint webinars with top integration partners on productivity themes

---

## 8. Technical Debt & Infrastructure Milestones

### Phase 1 Infrastructure (Months 1–3)

Move from local Docker Compose to a production-grade AWS environment.

- [ ] **AWS ECS Fargate deployment:** FastAPI containers managed by ECS; task definitions in Terraform; rolling deployments with health check grace period
- [ ] **RDS PostgreSQL 15 Multi-AZ:** db.t3.medium → db.r6g.large at 1,000 users; automated backups (7-day retention); parameter group tuning (shared_buffers, work_mem)
- [ ] **ElastiCache Redis cluster:** cache.t3.medium; used for session tokens, rate limiting, Celery broker, query caching
- [ ] **Qdrant on EC2 with EBS:** t3.large with gp3 EBS volume; Qdrant snapshots to S3 daily
- [ ] **S3 buckets:** voice recordings (lifecycle: delete after 24h), user profile images, app assets; all server-side encrypted (SSE-S3)
- [ ] **CloudFront CDN:** for static assets, landing page, and Flutter web build
- [ ] **Terraform IaC:** all AWS resources defined in Terraform; state stored in S3 with DynamoDB locking; per-environment workspaces (dev, staging, prod)
- [ ] **Secrets Manager:** all secrets (DB password, API keys, JWT secret) stored in AWS Secrets Manager, accessed at runtime by ECS tasks
- [ ] **ACM certificates:** wildcard cert for *.aria.ai, auto-renewed
- [ ] **VPC:** private subnets for ECS and RDS, public subnets for ALB only, NAT Gateway for outbound

---

### Phase 2 Infrastructure (Months 4–6)

Harden for 10,000 MAU and introduce observability.

- [ ] **Auto-scaling:** ECS service auto-scaling based on CPU utilization (target: 60%) and ALB request count per target (target: 1,000 req/min per task); scale-out in 1 minute, scale-in after 5 minutes cooldown
- [ ] **PgBouncer connection pooling:** transaction mode; sits between ECS and RDS; handles 1,000+ concurrent API workers with RDS max_connections of 200
- [ ] **PostgreSQL read replicas:** 1 read replica for analytics queries, reporting API endpoints, and admin dashboard; replica lag alarm at > 30 seconds
- [ ] **Qdrant cluster (3 nodes):** replication factor 2 for HA; sharding across nodes; EBS-backed persistent storage; Qdrant backup to S3 every 6 hours
- [ ] **WAF rules (OWASP Top 10):** AWS WAF on CloudFront and ALB; rules for SQL injection, XSS, rate-based rules (5,000 req/5min per IP), bot detection
- [ ] **AWS Shield Standard:** enabled on all CloudFront distributions and ALB; automatic DDoS mitigation for L3/L4 attacks
- [ ] **Structured logging:** all FastAPI logs in JSON with fields: timestamp, level, request_id, user_id, endpoint, duration_ms, status_code; shipped to CloudWatch Logs
- [ ] **CloudWatch dashboards:** API error rate, P50/P95/P99 latency per endpoint, ECS CPU/memory, RDS connections, Qdrant query latency
- [ ] **Datadog APM integration:** distributed tracing across FastAPI → PostgreSQL → Qdrant → Claude API; flame graphs for latency investigation; alert rules for error rate spikes

---

### Phase 3 Infrastructure (Months 7–12)

Multi-region, compliance-ready, enterprise-grade infrastructure.

- [ ] **Multi-region deployment:** primary region US-East-1 (existing); secondary region EU-West-1 (for GDPR data residency); each region has independent ECS, RDS, Qdrant, ElastiCache
- [ ] **Global load balancing:** Route 53 latency-based routing; health-check failover from EU to US if EU region health check fails (for non-GDPR users only)
- [ ] **Database sharding strategy:** evaluate sharding options for PostgreSQL (Citus extension vs. application-level tenant sharding) as user count approaches 100K; decision doc required before implementation
- [ ] **Kafka for event streaming:** replace Celery for high-throughput event publishing (calendar sync events, usage metering events, notification triggers); Kafka MSK on AWS; retain existing Celery for low-throughput scheduled jobs
- [ ] **SOC 2 Type II audit:** complete 6-month evidence collection period; audit firm conducts fieldwork; report issued; published on trust center (trust.aria.ai)
- [ ] **GDPR compliance infrastructure:** EU region with no cross-Atlantic data transfer for EU users; data residency selector during onboarding; DSAR (Data Subject Access Request) handling workflow (72-hour response SLA); erasure workflow tested quarterly
- [ ] **Penetration test:** annual external pentest by certified firm (HackerOne or equivalent); critical findings remediated within 7 days, high within 30 days

---

## 9. Risk Register

| Risk | Probability | Impact | Mitigation Strategy |
|---|---|---|---|
| **Anthropic API pricing increase or rate limit tightening** | Medium | High | Implement model abstraction layer from Phase 1 so switching to OpenAI GPT-4o or Google Gemini requires only prompt adapter changes. Monitor cost per user monthly with alerting. Negotiate usage commitments for volume discounts. |
| **Apple App Store policy changes for AI/voice apps** | Medium | High | Stay current with App Store Review Guidelines Section 5.6 (Kids) and emerging AI policy. Maintain Android parity so a temporary iOS hold does not halt growth. Engage Apple Developer Relations proactively. |
| **GDPR enforcement action** | Low | Very High | EU data residency from Phase 3 (EU-West-1 region). GDPR-compliant data export and erasure from Phase 1. Privacy by design reviews before each phase launch. Engage EU privacy counsel for review. |
| **Competitor feature parity (Apple Intelligence, Google Gemini)** | High | Medium | Platform AI is general-purpose. ARIA's differentiation is long-term personalized memory + multi-service orchestration. Double down on memory depth and proactive intelligence. Monitor competitor releases quarterly. |
| **Key person dependency (small team)** | Medium | High | Document all systems (architecture decision records, runbooks). Cross-train on critical systems (no single person owns auth or AI engine). Hiring plan activates when MRR > $10K. |
| **Data breach (user conversations or credentials)** | Low | Very High | Encryption at rest (AES-256) and in transit (TLS 1.3). Principle of least privilege for all services. Annual penetration testing. Incident response plan documented and tested. Cyber liability insurance. |
| **Third-party API deprecation (Google Calendar API v3)** | Low | High | Abstract all third-party integrations behind internal service interfaces. Monitor Google API deprecation notices. Outlook integration provides redundancy for calendar. |
| **Whisper STT quality insufficient for complex commands** | Medium | Medium | Fallback to text input always available. Implement confidence-based disambiguation ("Did you mean: [X]?"). Monitor voice command success rate; if <75%, prioritize model upgrade or post-processing. |
| **Payment processor issues (Stripe downtime)** | Low | Medium | Stripe has 99.99% uptime SLA. Grace period logic: allow 3-day payment retry before downgrading to Free. Status page monitoring with alerting on Stripe status feed. |
| **Amadeus API partnership required for production** | Medium | Medium | Begin partnership application in Month 1 before travel features launch in Month 2. Have Skyscanner API as backup. Clearly label travel search as "beta" until partnership confirmed. |

---

## 10. Dependencies & Assumptions

### Critical External Dependencies

| Dependency | Risk Level | Contingency |
|---|---|---|
| **Anthropic Claude API** — core AI engine; all conversational intelligence depends on availability and response quality | High | Model abstraction layer; OpenAI GPT-4o as drop-in fallback; aggressive caching of common responses |
| **Google Calendar API** — primary calendar integration; free tier limit: 1M queries/day | Medium | Microsoft Graph API as alternative; enforce per-user request budgets in Celery workers |
| **Amadeus Travel API** — flight and hotel search; production access requires partnership agreement | Medium | Apply for partnership in Month 1; Skyscanner API as interim fallback |
| **Firebase Cloud Messaging / APNs** — all push notifications route through these channels | Low | Both are infrastructure-grade; dual-platform redundancy inherent |
| **App Store / Play Store approval** — required for public launch; AI and voice apps receive additional scrutiny | Medium | Submit review-ready build 3 weeks before launch target to allow for revision cycles |
| **Stripe** — all billing; account suspension would halt revenue collection | Low | Stripe Radar fraud protection; maintain clean dispute record; emergency Paddle account ready |
| **Whisper STT** — voice command feature; API availability impacts voice UX | Medium | Text input always available as fallback; local Whisper model (medium) as self-hosted option if API costs escalate |
| **AWS** — full infrastructure dependency | Low | Multi-region reduces blast radius; AWS has >99.95% historical uptime on core services |

### Key Assumptions

| Assumption | What Would Invalidate It | Review Point |
|---|---|---|
| Users are willing to grant calendar + microphone permissions | Permission grant rate < 50% in onboarding analytics | MVP internal launch |
| Claude Haiku is sufficient quality for simple task/calendar intents at lower cost | AI accuracy rate < 80% on intent tests | Week 2 testing |
| $9.99/month price point is acceptable to the target market | Conversion rate < 3% after 3 months of free trial exposure | Month 4 review |
| The team can maintain a < 4-week feature shipping cadence | Two consecutive missed sprint targets | Phase 1 retrospective |
| Voice command adds meaningful value beyond text | Voice feature DAU < 20% of active users after 60 days | Month 5 review |
| Travel planning is a strong Pro-tier upsell vector | Travel feature correlation with conversion < text/calendar features | Phase 1 cohort analysis |
| Enterprise customers will pay $29.99/user/month | Enterprise pilot win rate < 20% of qualified leads | Phase 2 enterprise pilot results |
