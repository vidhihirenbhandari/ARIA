# ARIA — System Architecture

---

## Document Information

| Field       | Value                                        |
|-------------|----------------------------------------------|
| Document    | System Architecture                          |
| Version     | 1.0.0                                        |
| Date        | 2026-06-15                                   |
| Status      | Approved                                     |
| Author(s)   | ARIA Engineering Team                        |
| Reviewed By | Engineering Lead, Security Lead, CTO         |
| Next Review | 2026-09-15                                   |

---

## 1. Overview

ARIA's architecture is designed around four governing principles: **event-driven processing**, **a microservices-leaning monolith** (modular services within a single deployable unit for v1.0, designed to extract to independent services at scale), **API-first design** (every capability exposed through a versioned REST API), and **privacy-by-design** (encryption, data minimization, and user control baked in at every layer).

The system is built for the realities of an AI-heavy product: variable-latency external API calls (Claude, Whisper), high read/write throughput on the memory layer (Qdrant), and the need to perform significant background processing (calendar sync, travel monitoring, notification dispatch) without blocking the user-facing request path. Celery task queues absorb background work, Redis handles caching and pub/sub coordination, and the FastAPI server is kept stateless to enable horizontal scaling behind an AWS Application Load Balancer.

Data durability and security are treated as first-class concerns. PostgreSQL is deployed in Multi-AZ configuration with continuous WAL archiving. Qdrant and Redis run within a private VPC subnet with no public exposure. All PII is encrypted at the column level in PostgreSQL and all data is encrypted in transit using TLS 1.3. The architecture supports GDPR and CCPA compliance from day one, including a right-to-erasure implementation that cascades deletes across PostgreSQL, Qdrant, Redis, and S3.

---

## 2. High-Level System Diagram

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT LAYER                                      │
│                                                                                │
│    ┌─────────────────────────┐        ┌─────────────────────────┐             │
│    │   Flutter iOS App       │        │   Flutter Android App   │             │
│    │   (iOS 16+)             │        │   (Android 13+)         │             │
│    └───────────┬─────────────┘        └──────────────┬──────────┘             │
└────────────────┼──────────────────────────────────────┼────────────────────────┘
                 │ HTTPS / TLS 1.3                       │ HTTPS / TLS 1.3
                 │ REST + WebSocket                      │ REST + WebSocket
                 ▼                                       ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                           EDGE / GATEWAY LAYER                                 │
│                                                                                │
│   ┌─────────────────────────────────────────────────────────────────────────┐ │
│   │                     AWS Route 53 (DNS)                                  │ │
│   └─────────────────────────────┬───────────────────────────────────────────┘ │
│                                 │                                              │
│   ┌─────────────────────────────▼───────────────────────────────────────────┐ │
│   │              AWS CloudFront (CDN + TLS Termination)                     │ │
│   └─────────────────────────────┬───────────────────────────────────────────┘ │
│                                 │                                              │
│   ┌─────────────────────────────▼───────────────────────────────────────────┐ │
│   │          AWS WAF (Web Application Firewall — OWASP rules)               │ │
│   └─────────────────────────────┬───────────────────────────────────────────┘ │
│                                 │                                              │
│   ┌─────────────────────────────▼───────────────────────────────────────────┐ │
│   │       AWS ALB (Application Load Balancer — Multi-AZ, HTTPS:443)        │ │
│   └─────────────────────────────┬───────────────────────────────────────────┘ │
└─────────────────────────────────┼──────────────────────────────────────────────┘
                                  │
                                  │ Private VPC subnet routing
                                  ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                         BACKEND SERVICES LAYER (AWS ECS Fargate)               │
│                                                                                │
│  ┌───────────────────────────────────────────────────────────────────────────┐ │
│  │              ARIA API Server (FastAPI / Python 3.12)                      │ │
│  │  - Auth middleware (JWT validation)                                       │ │
│  │  - Request routing to internal services                                   │ │
│  │  - Rate limiting (per-user, per-endpoint)                                 │ │
│  │  - WebSocket connection management                                         │ │
│  │  Runs as: N stateless ECS tasks, auto-scaled by CPU/request metrics      │ │
│  └──────────────────────────────┬────────────────────────────────────────────┘ │
│                                 │                                              │
│         ┌───────────────────────┼───────────────────────┐                     │
│         │                       │                       │                     │
│  ┌──────▼──────┐  ┌─────────────▼────────┐  ┌──────────▼──────────┐         │
│  │  AI Engine  │  │  Memory Service       │  │  Calendar Service   │         │
│  │  Service    │  │  (Embedding +         │  │  (Google + MS       │         │
│  │  (Claude    │  │   Qdrant interface)   │  │   Graph sync)       │         │
│  │   API)      │  │                       │  │                     │         │
│  └──────┬──────┘  └─────────────┬─────────┘  └──────────┬──────────┘         │
│         │                       │                        │                    │
│  ┌──────▼──────┐  ┌─────────────▼─────────┐  ┌──────────▼──────────┐        │
│  │   Travel    │  │  Notification Service  │  │  Voice Processing   │        │
│  │   Service   │  │  (FCM + APNs dispatch) │  │  Service            │        │
│  │  (Amadeus)  │  │                        │  │  (Whisper + NLP)    │        │
│  └──────┬──────┘  └─────────────┬──────────┘  └──────────┬──────────┘        │
│         │                       │                         │                   │
│         └───────────────────────┼─────────────────────────┘                   │
│                                 │                                              │
│  ┌──────────────────────────────▼────────────────────────────────────────────┐ │
│  │          Celery Workers (Background Task Queue — 3 priority levels)        │ │
│  │  - Calendar sync workers       - Travel monitoring workers                 │ │
│  │  - Meeting briefing generator  - Notification dispatch workers             │ │
│  │  - Memory indexing workers     - Analytics pipeline workers                │ │
│  └───────────────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────┬───────────────────────────────────────────────┘
                                 │
                                 ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                              DATA LAYER                                        │
│                                                                                │
│  ┌──────────────────┐  ┌───────────────────┐  ┌────────────────┐             │
│  │   PostgreSQL 16   │  │   Qdrant 1.9      │  │   Redis 7.2    │             │
│  │   (AWS RDS        │  │   (Vector DB —    │  │   (ElastiCache │             │
│  │   Multi-AZ)       │  │   EC2 cluster)    │  │   Cluster)     │             │
│  │                   │  │                   │  │                │             │
│  │  - Users          │  │  - Memory vectors │  │  - Session     │             │
│  │  - Conversations  │  │  - Semantic index │  │    tokens      │             │
│  │  - Tasks          │  │  - User embeddings│  │  - API cache   │             │
│  │  - Calendar events│  │  - Similarity     │  │  - Rate limits │             │
│  │  - Integrations   │  │    search         │  │  - Pub/sub     │             │
│  │  - Travel records │  │                   │  │  - Job queue   │             │
│  └──────────────────┘  └───────────────────┘  └────────────────┘             │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                    AWS S3 (Object Storage)                              │  │
│  │  - Voice audio recordings      - User file uploads                     │  │
│  │  - Data export archives        - App assets / media                    │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬───────────────────────────────────────────────┘
                                 │
                                 ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                          EXTERNAL SERVICES LAYER                               │
│                                                                                │
│  ┌──────────────────┐  ┌─────────────────┐  ┌──────────────────┐             │
│  │  Anthropic       │  │  OpenAI Whisper  │  │  Google Calendar │             │
│  │  Claude API      │  │  (STT API)       │  │  API             │             │
│  │  (Claude 3.5     │  │                  │  │  (OAuth 2.0)     │             │
│  │   Sonnet/Haiku)  │  │                  │  │                  │             │
│  └──────────────────┘  └─────────────────┘  └──────────────────┘             │
│                                                                                │
│  ┌──────────────────┐  ┌─────────────────┐  ┌──────────────────┐             │
│  │  Microsoft       │  │  Amadeus Travel  │  │  Firebase FCM +  │             │
│  │  Graph API       │  │  API             │  │  Apple APNs      │             │
│  │  (Outlook/Teams) │  │  (Flight data)   │  │  (Push notifs)   │             │
│  └──────────────────┘  └─────────────────┘  └──────────────────┘             │
│                                                                                │
│  ┌──────────────────┐  ┌─────────────────┐  ┌──────────────────┐             │
│  │  Gmail API       │  │  Slack API       │  │  Notion API      │             │
│  │  (OAuth 2.0)     │  │  (OAuth 2.0)     │  │  (OAuth 2.0)     │             │
│  └──────────────────┘  └─────────────────┘  └──────────────────┘             │
│                                                                                │
│  ┌──────────────────┐                                                          │
│  │  Twilio          │                                                          │
│  │  (SMS fallback)  │                                                          │
│  └──────────────────┘                                                          │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Component Descriptions

### 3.1 Mobile Application (Flutter)

**Purpose:** The primary user interface for ARIA across iOS and Android platforms, delivering a native-quality experience from a single shared codebase.

**Technology:** Flutter 3.24+, Dart 3.5+; Riverpod for state management; go_router for navigation; Hive for local storage; flutter_local_notifications for local notification scheduling; just_audio for audio capture/playback.

**Key Responsibilities:**
- Render the conversational chat interface with real-time streaming message support via WebSocket.
- Manage local caching of conversations, tasks, and calendar data for offline read access.
- Handle OAuth flows for Google, Apple, Microsoft, Gmail, Slack, and Notion integrations via flutter_appauth.
- Capture voice audio using the device microphone and upload it to S3 via pre-signed URLs.
- Register device push notification tokens with Firebase FCM (Android) and APNs (iOS) and maintain token freshness.

**Interfaces:**
- Outbound: ARIA API Server (HTTPS REST + WebSocket over TLS 1.3).
- Inbound: Firebase FCM push notifications (Android); APNs push notifications (iOS).
- Local: Hive encrypted local database for offline data; SecureStorage for auth tokens.

**Scaling Approach:** No server-side scaling needed; the client itself scales with device distribution. Flutter's compilation model ensures consistent performance across device tiers. Local caching strategy minimizes API dependency for read-heavy views.

---

### 3.2 API Gateway

**Purpose:** The entry point for all client traffic, providing TLS termination, DDoS protection, WAF filtering, and intelligent load balancing across ARIA API Server instances.

**Technology:** AWS Application Load Balancer (ALB) with HTTPS listener; AWS WAF v2 (OWASP managed rule groups + custom rules); AWS CloudFront for CDN and edge TLS termination; AWS Route 53 for DNS with health check-based failover.

**Key Responsibilities:**
- Terminate TLS 1.3 connections and forward traffic to ECS target groups over HTTP within the VPC.
- Apply WAF rules to block SQL injection, XSS, rate-based DDoS, and known bad IPs before requests reach application servers.
- Route `/api/v1/` traffic to the ARIA API Server target group; static asset requests to S3/CloudFront.
- Perform health checks on ECS task instances and remove unhealthy instances from the target group automatically.
- Distribute traffic across multiple Availability Zones for resilience.

**Interfaces:**
- Inbound: Public internet (HTTPS/443, WebSocket upgrade).
- Outbound: ECS task instances in private VPC subnets (HTTP/8000).
- Side: CloudWatch for ALB access logs and metrics; AWS Secrets Manager for SSL certificate management.

**Scaling Approach:** ALB is a managed, fully elastic service — no capacity management required. WAF scales automatically with traffic. CloudFront edge nodes handle geographic distribution transparently.

---

### 3.3 ARIA API Server (FastAPI)

**Purpose:** The central application server — stateless, horizontally scalable, and responsible for request handling, authentication enforcement, business logic orchestration, and delegation to internal services.

**Technology:** Python 3.12, FastAPI 0.115+, Uvicorn (ASGI) with Gunicorn process manager; SQLAlchemy 2.0 (async) for database ORM; Pydantic v2 for request/response validation; python-jose for JWT handling; httpx for async outbound HTTP; python-multipart for file uploads.

**Key Responsibilities:**
- Validate JWT tokens on every protected request via FastAPI dependency injection middleware.
- Route requests to the appropriate internal service module (AI Engine, Calendar Service, Memory Service, etc.).
- Manage WebSocket connections for real-time streaming of AI responses (token-by-token streaming via Claude API).
- Apply per-user rate limits using Redis token bucket counters.
- Emit structured JSON logs and distributed tracing spans (AWS X-Ray) for observability.

**Interfaces:**
- Inbound: AWS ALB (HTTP/8000, WebSocket upgrade).
- Outbound: PostgreSQL (via asyncpg connection pool), Redis, Celery broker (Redis), internal service modules.
- Side: AWS X-Ray SDK for tracing; CloudWatch Logs for structured logging; Secrets Manager for configuration.

**Scaling Approach:** Stateless design enables horizontal scaling — ECS Fargate scales tasks from a baseline of 3 (one per AZ) to 50+ based on CPU utilization and ALB request count metrics. Target tracking scaling policy maintains 60% CPU utilization. Scale-out triggers within 2 minutes; scale-in protected by 10-minute cooldown.

---

### 3.4 AI Engine Service

**Purpose:** The intelligence core of ARIA — responsible for constructing prompts, managing context windows, calling the Claude API, streaming responses, and coordinating memory retrieval to produce contextually rich, accurate AI responses.

**Technology:** Anthropic Python SDK 0.40+; custom prompt construction layer; context window management with automatic truncation; streaming response handler with WebSocket relay; token counting for cost management.

**Key Responsibilities:**
- Assemble the full prompt for each user turn: system prompt (user profile, current date/time, user preferences) + retrieved memories (from Memory Service) + recent conversation history + current user message.
- Call the Anthropic Claude API with appropriate model selection (Claude 3.5 Sonnet for standard queries, Claude 3 Haiku for lightweight classification and extraction tasks).
- Stream token-by-token responses back to the client via WebSocket using Server-Sent Events semantics.
- Extract structured data (action items, entities, intents) from Claude responses using tool use / function calling.
- Track per-user token consumption and enforce API cost caps to prevent runaway spend.

**Interfaces:**
- Inbound: ARIA API Server (internal function call).
- Outbound: Anthropic Claude API (HTTPS); Memory Service (internal); PostgreSQL (conversation persistence).
- Side: Redis (response caching for identical/similar queries within 60 seconds); CloudWatch for token usage metrics.

**Scaling Approach:** The AI Engine is CPU and network-bound (waiting on Claude API). It runs within the same ECS task as the API server in v1.0, sharing horizontal scaling. If Claude API latency becomes a bottleneck, the AI Engine can be extracted to dedicated Fargate tasks with a larger request queue.

---

### 3.5 Memory Service

**Purpose:** ARIA's persistent, semantic memory layer — responsible for storing, indexing, retrieving, and managing all user-specific knowledge including conversation memories, explicit preferences, extracted facts, and observed patterns.

**Technology:** Qdrant Python client 1.9+; sentence-transformers (all-MiniLM-L6-v2 or text-embedding-3-small via OpenAI API) for embedding generation; PostgreSQL for memory metadata (timestamps, source, type, user association); custom ranking algorithm that combines vector similarity with recency weighting.

**Key Responsibilities:**
- Generate vector embeddings for new memories using the embedding model and store them in the user's Qdrant collection.
- Execute semantic similarity searches against Qdrant to retrieve the top-K most relevant memories for a given query.
- Apply a hybrid ranking function that weights vector similarity (70%) and recency (30%) to produce final memory ordering.
- Persist memory metadata (source, timestamp, content hash, category) in PostgreSQL for audit trail and user-facing memory viewer.
- Handle memory deletion requests — both individual (by memory ID) and bulk (user data erasure) — cascading across Qdrant and PostgreSQL.

**Interfaces:**
- Inbound: AI Engine Service (memory retrieval for prompt context), ARIA API Server (memory management CRUD), Celery workers (async memory indexing).
- Outbound: Qdrant cluster (vector storage and search); PostgreSQL (metadata storage).
- Side: Redis (short-term cache for recently retrieved memory sets to avoid redundant Qdrant queries within a session).

**Scaling Approach:** Qdrant runs on dedicated EC2 instances (r6g.xlarge for v1.0) in a 3-node cluster with replication factor 2. As user base grows, Qdrant collection sharding distributes user vectors across nodes. The embedding generation step is the primary CPU bottleneck and is offloaded to Celery workers for async memory writes.

---

### 3.6 Calendar Service

**Purpose:** Manages bidirectional synchronization of calendar data between ARIA's internal state and external calendar providers (Google Calendar, Microsoft Outlook), and exposes calendar-aware reasoning capabilities to the AI Engine.

**Technology:** Google Calendar API v3 Python client; Microsoft Graph API Python client; python-dateutil for timezone handling; icalendar library for iCal format support; custom event normalization layer that maps provider-specific schemas to ARIA's internal CalendarEvent model.

**Key Responsibilities:**
- Establish and maintain OAuth 2.0 connections to Google Calendar and Microsoft Graph on behalf of users.
- Subscribe to provider webhook/push notifications for real-time event change delivery; fall back to polling every 5 minutes if webhooks fail.
- Normalize calendar events from provider-specific formats into ARIA's internal schema and persist to PostgreSQL.
- Propagate user-initiated changes (event creation, modification, deletion via ARIA) back to the source calendar provider within the API round-trip.
- Detect scheduling conflicts and compute free/busy windows for availability queries.

**Interfaces:**
- Inbound: ARIA API Server (calendar queries and mutations); Celery workers (sync jobs).
- Outbound: Google Calendar API (HTTPS); Microsoft Graph API (HTTPS); PostgreSQL (calendar event storage); Redis (event change pub/sub to notify connected WebSocket clients).
- Side: AWS Secrets Manager for per-user OAuth token storage.

**Scaling Approach:** Calendar sync is I/O-bound. Celery workers handle periodic sync jobs per user; webhook processing is handled by a dedicated lightweight endpoint that fans out to workers. Worker pool scales independently of the API server based on queue depth.

---

### 3.7 Travel Service

**Purpose:** Manages user travel itineraries, monitors live flight status, and delivers proactive alerts when disruptions are detected.

**Technology:** Amadeus Travel API Python SDK; custom itinerary parser that extracts structured travel data from user-provided confirmation text; background polling orchestration via Celery; timezone-aware departure/arrival time management.

**Key Responsibilities:**
- Store structured itineraries (flights, hotels, ground transport segments) in PostgreSQL linked to user accounts.
- Schedule recurring Celery tasks to poll Amadeus for flight status updates every 15 minutes per tracked flight.
- Detect disruption events (delay >30 minutes, gate change, cancellation) by comparing current status to last known state.
- Trigger Notification Service to send push alerts on detected disruptions with enriched context (new departure time, alternative options).
- Provide time zone resolution for calendar events during travel periods (automatically applying destination timezone).

**Interfaces:**
- Inbound: ARIA API Server (itinerary CRUD); Celery scheduler (monitoring triggers).
- Outbound: Amadeus Travel API (HTTPS); Notification Service (disruption alerts); PostgreSQL (itinerary storage); Calendar Service (timezone context requests).
- Side: Redis (cache last-known flight state to detect delta changes efficiently).

**Scaling Approach:** Flight monitoring is a cron-like background workload. Celery's eta/countdown scheduling handles per-flight polling. As the number of tracked flights grows, the monitoring worker pool scales horizontally. Amadeus API rate limits are managed via a shared Redis rate limiter with exponential backoff.

---

### 3.8 Notification Service

**Purpose:** The centralized dispatch layer for all push notifications, responsible for routing the right message to the right device at the right time while respecting user notification preferences and quiet hours.

**Technology:** Firebase Admin SDK (Python) for FCM (Android); Apple APNs via httpx2 with JWT-based authentication for iOS; Twilio REST API for SMS fallback; custom preference engine that evaluates notification eligibility before dispatch.

**Key Responsibilities:**
- Receive notification dispatch requests from all internal services (AI Engine, Calendar, Travel, Task, Proactive Engine).
- Evaluate user notification preferences (category toggles, quiet hours) before dispatching any notification.
- Route to FCM (Android), APNs (iOS), or both based on registered device tokens; handle token refresh transparently.
- Track delivery status (sent, delivered, failed) in PostgreSQL for observability and retry logic.
- Manage notification payload construction including deep link URIs and rich notification content (images, action buttons).

**Interfaces:**
- Inbound: All internal services via Celery task queue (async notification requests); ARIA API Server (direct notification test endpoint for admin).
- Outbound: Firebase FCM API (HTTPS); Apple APNs (HTTPS/2); Twilio API (HTTPS, SMS fallback); PostgreSQL (delivery log).
- Side: Redis (device token cache; per-user rate limiting to prevent notification spam).

**Scaling Approach:** Notification dispatch is I/O-bound and highly parallelizable. Celery workers processing the notification queue scale horizontally. Firebase and APNs connections are maintained as long-lived connection pools within worker processes to minimize connection overhead.

---

### 3.9 Voice Processing Service

**Purpose:** Handles the full voice interaction pipeline — from audio upload through transcription to intent extraction and response — enabling hands-free interaction with ARIA.

**Technology:** OpenAI Whisper API (whisper-1 model) for cloud transcription; boto3 for S3 pre-signed URL generation; custom intent classification layer using Claude Haiku for intent extraction; optional TTS via third-party (ElevenLabs or AWS Polly) for voice responses.

**Key Responsibilities:**
- Generate S3 pre-signed upload URLs for the mobile client to upload audio files directly (bypassing the API server for large payloads).
- Trigger Whisper transcription jobs upon S3 upload completion (via S3 event notification → Celery task).
- Return transcribed text to the client for review/edit, then process through the standard AI Engine pipeline.
- Extract structured intents from transcribed text when the command pattern is unambiguous (e.g., "Set a reminder for...") to enable faster action execution without full Claude context assembly.
- Manage audio file lifecycle — uploaded files deleted from S3 after transcription unless explicitly retained.

**Interfaces:**
- Inbound: ARIA API Server (transcription request, pre-signed URL generation); S3 event notification (upload complete trigger via SQS → Celery).
- Outbound: OpenAI Whisper API (HTTPS, audio file upload); AI Engine Service (processed transcript); S3 (audio file management); PostgreSQL (transcription log for audit).
- Side: Redis (pending transcription job state; short-lived audio processing cache).

**Scaling Approach:** Whisper API calls are I/O-bound and externally rate-limited. Celery workers processing voice tasks use a dedicated high-priority queue to ensure voice interactions feel responsive. S3 pre-signed upload URLs allow the mobile client to upload audio directly, bypassing the API server entirely and reducing backend load.

---

### 3.10 Background Workers (Celery)

**Purpose:** The async task execution backbone of ARIA — processing all non-real-time work including calendar sync, travel monitoring, memory indexing, meeting briefing generation, and notification dispatch without blocking the user-facing API.

**Technology:** Celery 5.4+; Redis as message broker and result backend; Flower for task monitoring dashboard; three priority queues: `high` (voice transcription, notification dispatch), `default` (memory indexing, calendar sync), `low` (analytics, cleanup, export generation); ECS Fargate for worker deployment (separate task definition from API server).

**Key Responsibilities:**
- Process the three-tier priority queue system, ensuring high-priority tasks (voice responses, urgent notifications) are not blocked by low-priority bulk work.
- Execute scheduled periodic tasks using Celery Beat: calendar sync (every 5 minutes per active user), travel monitoring (every 15 minutes per tracked flight), meeting briefing generation (30 minutes before events), token refresh (24 hours before OAuth token expiry).
- Implement retry policies: exponential backoff for external API failures; dead letter queue for tasks that fail after maximum retries; alerting on dead letter queue depth.
- Handle long-running tasks (bulk data export, memory re-indexing) gracefully with progress tracking and timeout enforcement.
- Process S3 event notifications for voice upload completion via SQS integration.

**Interfaces:**
- Inbound: Redis task queue (from all internal services and API server); Celery Beat scheduler (cron-based triggers); SQS (S3 event notifications for voice uploads).
- Outbound: All external APIs (Claude, Whisper, Google Calendar, Microsoft Graph, Amadeus, FCM, APNs, Twilio); all data stores (PostgreSQL, Qdrant, Redis, S3).
- Side: Flower dashboard (task monitoring); CloudWatch (custom metrics for queue depth, task duration, failure rate).

**Scaling Approach:** Worker processes are independently scalable from the API server. ECS auto-scaling policy targets 5 tasks per 1000 items in queue depth across all priority levels. High-priority worker pool (dedicated to `high` queue) maintains minimum 3 workers at all times to ensure voice and notification SLAs are met.

---

### 3.11 PostgreSQL Database

**Purpose:** The primary relational data store for all structured ARIA data — users, conversations, tasks, calendar events, integrations, travel records, notification logs, and system configuration.

**Technology:** PostgreSQL 16 on AWS RDS; Multi-AZ deployment (synchronous standby replica in secondary AZ); PgBouncer for connection pooling (transaction mode, pool size 100 per app instance); automated daily snapshots + continuous WAL archiving to S3 (via AWS Backup); read replica for analytics and reporting queries.

**Key Responsibilities:**
- Store and serve all transactional data for ARIA's core features.
- Enforce referential integrity and business rules through database constraints and triggers.
- Support efficient time-range queries on messages, events, and notifications using BRIN indexes on timestamp columns.
- Provide full-text search on conversation content using `tsvector` / `tsquery` (pg_trgm extension) as a supplement to Qdrant semantic search.
- Enable point-in-time recovery via continuous WAL archiving for RPO compliance.

**Key Schema Tables:**
- `users` — account information, preferences, subscription tier, PII (encrypted)
- `user_sessions` — active JWT refresh token tracking
- `conversations` — chat session metadata
- `messages` — individual chat messages with role, content, token count, and timestamps
- `tasks` — user tasks with status, due date, priority, and completion timestamp
- `calendar_integrations` — per-user OAuth connections to calendar providers
- `calendar_events` — normalized event records synced from providers
- `memory_metadata` — metadata for Qdrant vector entries (id mapping, source, type, created_at)
- `travel_itineraries` — trip records with segments, status, and last-checked timestamp
- `notification_log` — delivery tracking for all dispatched notifications
- `integration_tokens` — encrypted OAuth tokens for third-party integrations (Gmail, Slack, Notion)
- `audit_log` — security-sensitive events (login, data export, account deletion)

**Interfaces:**
- Inbound: API Server (via asyncpg connection pool through PgBouncer); Celery workers (via SQLAlchemy sync engine).
- Side: AWS RDS Multi-AZ (automatic failover); AWS Backup (snapshot management); Read replica (analytics queries via separate connection string).

**Scaling Approach:** Vertical scaling (instance class upgrades) is the primary scaling lever for v1.0. Read replica absorbs analytics and reporting load. PgBouncer ensures the connection count remains manageable as ECS task count grows. Horizontal sharding is not planned until >50TB data volume or >50K concurrent connections — both projected beyond 18-month horizon. Partitioning applied to `messages` and `calendar_events` tables by `created_at` month from launch.

---

### 3.12 Qdrant Vector Database

**Purpose:** The vector search engine powering ARIA's semantic memory system — storing high-dimensional embeddings of user memories and enabling millisecond-level nearest-neighbor similarity search across millions of vectors.

**Technology:** Qdrant 1.9 open-source; deployed on EC2 r6g.xlarge instances (memory-optimized ARM); 3-node cluster with replication factor 2; one collection per deployment (`aria_memories`) with user-level filtering using Qdrant payload filters; vectors dimensioned at 384 (all-MiniLM-L6-v2) or 1536 (text-embedding-3-small).

**Key Responsibilities:**
- Store vector embeddings for every memory entry, indexed by user_id payload field for efficient per-user search.
- Serve approximate nearest-neighbor (ANN) search queries with configurable ef (search depth) for latency vs. accuracy tradeoff.
- Support filtered search — "find the top 10 memories semantically similar to this query for user_id = X" — without full-collection scan.
- Support memory deletion by point ID (individual memory) and payload-filtered bulk deletion (user erasure).
- Provide collection statistics (vector count, index size) for monitoring dashboards.

**Collection Design:**
- Single collection `aria_memories` with HNSW index configuration (m=16, ef_construct=100).
- Payload fields: `user_id` (indexed keyword), `memory_type` (indexed keyword: conversation, preference, fact, pattern), `source_id` (UUID of source message), `created_at` (integer Unix timestamp for range filtering), `content_preview` (first 200 chars for debugging).
- Vector named `content_embedding` — 384-dimensional float32.

**Interfaces:**
- Inbound: Memory Service (Qdrant Python client); Celery memory indexing workers.
- Outbound: None (data store only).
- Side: Qdrant cluster inter-node replication; CloudWatch agent on EC2 for disk/memory/CPU metrics.

**Scaling Approach:** Qdrant cluster starts with 3 nodes (1 leader, 2 followers). Horizontal scaling adds nodes and reshards the collection — supported natively by Qdrant without downtime. At 100K users with 50K vectors each = 5B vectors, estimated storage ~200GB at 384 dimensions (float32 = 1.5 bytes/dim + payload overhead). Memory requirement drives instance sizing (r6g.2xlarge or larger at scale).

---

### 3.13 Redis Cache

**Purpose:** Shared, distributed cache and pub/sub message broker serving multiple roles: session token storage, API response caching, rate limit counters, Celery task queue broker, and real-time event pub/sub for WebSocket notifications.

**Technology:** Redis 7.2 on AWS ElastiCache (Cluster Mode Enabled, 3 shards × 2 replicas); redis-py async client (redis.asyncio); custom cache key namespace conventions per service; LRU eviction policy with maxmemory set to 80% of available instance memory.

**Key Responsibilities:**
- Store JWT refresh token hashes with TTL matching token expiry (30 days) for token revocation support.
- Cache frequently accessed data: user profile, connected integrations list, upcoming calendar events (TTL: 5 minutes), last conversation context (TTL: 24 hours).
- Maintain per-user, per-endpoint rate limit counters using Redis INCR + EXPIRE atomic operations (sliding window approach).
- Serve as the Celery message broker — storing task payloads and routing messages to the appropriate worker queue.
- Support pub/sub for real-time event broadcasting — when a Celery worker completes a task that affects the client's live view (e.g., calendar sync completion), it publishes an event that the WebSocket connection handler receives and forwards to the connected client.

**Interfaces:**
- Inbound: API Server (caching, rate limits, session); Celery workers (task queue); Notification Service (pub/sub).
- Outbound: None (data store only).
- Side: AWS ElastiCache cluster replication; CloudWatch for cache hit rate, memory utilization, and connection count.

**Scaling Approach:** ElastiCache Cluster Mode distributes data across 3 shards automatically. As load grows, online resharding adds shards without downtime. Separate ElastiCache instances used for production and staging to prevent cross-environment contamination.

---

### 3.14 S3 Object Storage

**Purpose:** Durable, scalable object storage for all binary and large-text assets that do not belong in the relational database — voice recordings, user file uploads, data export archives, and application media.

**Technology:** AWS S3 Standard storage class; S3 Intelligent-Tiering for cost optimization on infrequently accessed objects; pre-signed URLs for direct client-to-S3 uploads (bypassing the API server); S3 Lifecycle rules for automatic deletion of temporary files (voice recordings: deleted after 24 hours post-transcription); S3 Event Notifications via SQS for processing triggers.

**Key Responsibilities:**
- Receive direct mobile client uploads (voice audio) via pre-signed PUT URLs with 10-minute expiry.
- Store user data export archives with a download link delivered via email (expires after 7 days).
- Trigger SQS → Celery worker pipeline upon voice file upload completion.
- Serve static application assets (onboarding images, AI model response media) via CloudFront CDN.
- Store database backup archives (managed by AWS Backup) and WAL segments (managed by RDS automated backup).

**Interfaces:**
- Inbound: Mobile clients (direct upload via pre-signed URL); API Server (pre-signed URL generation, export write); Celery workers (export generation write).
- Outbound: SQS (S3 event notifications); CloudFront (static asset serving).
- Side: S3 Versioning enabled on user data buckets; S3 Object Lock not required for v1.0; KMS encryption for all S3 buckets (SSE-KMS with customer-managed key).

**Scaling Approach:** S3 is a managed, effectively unlimited capacity service. No scaling configuration required. Request throughput scales automatically with AWS infrastructure. Multi-region replication configured for user data bucket for additional durability (us-east-1 primary, us-west-2 replica).

---

## 4. Data Flow Diagrams

### 4.1 User Message Processing Flow

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Mobile  │     │   ALB    │     │  FastAPI │     │  Auth    │     │  AI      │
│  Client  │     │   WAF    │     │  Server  │     │  Middle  │     │  Engine  │
└────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │                 │                │
     │ POST /messages │                │                 │                │
     │ {text, conv_id}│                │                 │                │
     │───────────────►│                │                 │                │
     │                │  Forward req   │                 │                │
     │                │───────────────►│                 │                │
     │                │                │  Validate JWT   │                │
     │                │                │────────────────►│                │
     │                │                │  User context   │                │
     │                │                │◄────────────────│                │
     │                │                │                 │                │
     │                │                │  Invoke AI Engine                │
     │                │                │────────────────────────────────►│
     │                │                │                 │                │
     │                │                │                 │  ┌─────────────▼──────┐
     │                │                │                 │  │  Memory Service    │
     │                │                │                 │  │  Qdrant search:    │
     │                │                │                 │  │  top-10 relevant   │
     │                │                │                 │  │  memories for user │
     │                │                │                 │  └─────────────┬──────┘
     │                │                │                 │                │
     │                │                │                 │  Memories + conversation history
     │                │                │                 │  assembled into prompt context
     │                │                │                 │                │
     │                │                │                 │  ┌─────────────▼──────┐
     │                │                │                 │  │  Anthropic Claude  │
     │                │                │                 │  │  API call          │
     │                │                │                 │  │  (streaming=True)  │
     │                │                │                 │  └─────────────┬──────┘
     │                │                │                 │                │
     │  WS: stream tokens to client ◄──────────────────────────────────── │
     │  (each token forwarded as     │                 │                │
     │   SSE frame over WebSocket)   │                 │                │
     │                │                │                 │                │
     │                │                │  Response complete               │
     │                │                │◄────────────────────────────────│
     │                │                │                 │                │
     │                │                │  ┌──────────────────────────────────────┐
     │                │                │  │  Async (Celery): Store assistant     │
     │                │                │  │  message in PostgreSQL; extract and  │
     │                │                │  │  index new memories in Qdrant        │
     │                │                │  └──────────────────────────────────────┘
     │  Final response                │                 │                │
     │◄───────────────────────────────│                 │                │
     │                │                │                 │                │
```

**Step-by-step Description:**

1. **Client sends message**: The Flutter app sends a POST request to `/api/v1/conversations/{id}/messages` with the user's text and conversation ID. The WebSocket connection is already established for streaming.
2. **WAF + ALB routing**: The request passes WAF inspection and is routed to an available FastAPI ECS task.
3. **JWT validation**: The auth middleware extracts the Bearer token from the Authorization header, validates the signature and expiry using the JWT secret from Secrets Manager, and hydrates the user context (user_id, subscription tier, feature flags).
4. **Rate limit check**: Redis INCR check confirms the user has not exceeded their message rate limit (e.g., 60 messages/minute on paid tier).
5. **AI Engine invocation**: The API server delegates to the AI Engine module with the user message, user context, and conversation history.
6. **Memory retrieval**: The AI Engine calls the Memory Service to retrieve the top-10 semantically relevant memories for the user's query using Qdrant ANN search. This typically completes in 100–300ms.
7. **Prompt assembly**: The AI Engine builds the full prompt: system instructions (user name, preferences, current datetime) + retrieved memories (formatted as context) + last 20 conversation turns + current user message.
8. **Claude API call**: The AI Engine calls the Anthropic API with `stream=True`. Each token returned in the stream is immediately forwarded to the client over the WebSocket connection.
9. **Async post-processing**: After the response is complete, a Celery task is queued to: (a) persist the assistant message to PostgreSQL, (b) extract new memory candidates from the exchange, (c) embed and store new memories in Qdrant.
10. **Client receives response**: The Flutter UI renders tokens progressively as they arrive, giving the perception of a fast, live response.

---

### 4.2 Voice Command Flow

```
┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
│  Mobile  │      │  FastAPI │      │   AWS    │      │  Celery  │      │  Whisper │
│  Client  │      │  Server  │      │   S3     │      │  Worker  │      │   API    │
└────┬─────┘      └────┬─────┘      └────┬─────┘      └────┬─────┘      └────┬─────┘
     │                 │                  │                  │                  │
     │ 1. Tap mic icon │                  │                  │                  │
     │ (record audio)  │                  │                  │                  │
     │                 │                  │                  │                  │
     │ 2. GET /voice/upload-url           │                  │                  │
     │────────────────►│                  │                  │                  │
     │ 3. Pre-signed   │ Generate signed  │                  │                  │
     │    PUT URL      │ PUT URL (10 min) │                  │                  │
     │◄────────────────│─────────────────►│                  │                  │
     │                 │                  │                  │                  │
     │ 4. PUT audio.webm directly to S3   │                  │                  │
     │───────────────────────────────────►│                  │                  │
     │                 │                  │                  │                  │
     │                 │                  │ 5. S3 Event      │                  │
     │                 │                  │    Notification  │                  │
     │                 │                  │    → SQS → Celery│                  │
     │                 │                  │─────────────────►│                  │
     │                 │                  │                  │                  │
     │                 │                  │                  │ 6. Whisper API   │
     │                 │                  │                  │    transcription │
     │                 │                  │                  │    (audio bytes) │
     │                 │                  │                  │─────────────────►│
     │                 │                  │                  │ 7. Transcript    │
     │                 │                  │                  │◄─────────────────│
     │                 │                  │                  │                  │
     │                 │ 8. WebSocket push: transcript ready │                  │
     │◄────────────────│◄─────────────────────────────────── │                  │
     │                 │                  │                  │                  │
     │ 9. User reviews │                  │                  │                  │
     │    transcript   │                  │                  │                  │
     │ (optional edit) │                  │                  │                  │
     │                 │                  │                  │                  │
     │ 10. Submit transcript as text message                 │                  │
     │────────────────►│                  │                  │                  │
     │                 │                  │                  │                  │
     │  → Standard message processing flow (Section 4.1)    │                  │
     │                 │                  │                  │                  │
     │                 │ 11. Celery: Delete audio from S3 after 24h            │
     │                 │──────────────────►                  │                  │
```

---

### 4.3 Meeting Detection & Briefing Flow

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│  Celery  │   │ Calendar │   │  Memory  │   │ AI Engine│   │  Notif.  │
│  Beat    │   │ Service  │   │ Service  │   │ (Claude) │   │ Service  │
└────┬─────┘   └────┬─────┘   └────┬─────┘   └────┬─────┘   └────┬─────┘
     │               │               │               │               │
     │ Every minute: scan for events starting in 30 min             │
     │──────────────►│               │               │               │
     │               │               │               │               │
     │               │ Query PostgreSQL: events WHERE                │
     │               │ start_time BETWEEN now+25min AND now+35min   │
     │               │ AND briefing_sent = false                     │
     │               │               │               │               │
     │               │ For each matched event:        │               │
     │               │               │               │               │
     │               │ Get attendee list              │               │
     │               │ ──────────────►               │               │
     │               │               │ Semantic search:              │
     │               │               │ "past interactions with       │
     │               │               │ [attendee names]"             │
     │               │               │──────────────►│               │
     │               │               │ Top memories  │               │
     │               │               │◄──────────────│               │
     │               │               │               │               │
     │               │ Assemble briefing context:    │               │
     │               │ - Event title, time, attendees│               │
     │               │ - Past meeting summaries       │               │
     │               │ - Open action items            │               │
     │               │ - Event description/agenda     │               │
     │               │───────────────────────────────►               │
     │               │               │               │               │
     │               │               │               │ Claude API:   │
     │               │               │               │ Generate      │
     │               │               │               │ briefing text │
     │               │               │               │               │
     │               │               │               │ Briefing      │
     │               │               │ Briefing text ◄───────────────│
     │               │◄──────────────│               │               │
     │               │               │               │               │
     │               │ Send briefing notification     │               │
     │               │────────────────────────────────────────────►  │
     │               │               │               │  FCM/APNs    │
     │               │               │               │  dispatch     │
     │               │               │               │  → Mobile     │
     │               │               │               │               │
     │               │ Mark briefing_sent = true in PostgreSQL       │
     │               │ Store briefing in Memory Service              │
```

---

### 4.4 Memory Retrieval Flow

```
  User message text
         │
         ▼
┌────────────────────┐
│   AI Engine        │
│   receives query   │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│  Embedding Model   │    Generate 384-dim vector for query text
│  (all-MiniLM-L6   │    using sentence-transformers
│   or OAI embed)   │    ~50–100ms latency
└────────┬───────────┘
         │  query_vector = [0.021, -0.154, ..., 0.089]
         ▼
┌────────────────────────────────────────────────────────┐
│   Qdrant ANN Search                                    │
│                                                        │
│   collection: aria_memories                            │
│   filter: { user_id: "usr_abc123" }                    │
│   vector: query_vector                                 │
│   limit: 20                                            │
│   with_payload: true                                   │
│   score_threshold: 0.65                               │
│                                                        │
│   Returns: top-20 candidate memories with scores       │
│   ~100–300ms latency (P95)                             │
└────────┬───────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────┐
│   Hybrid Ranking Layer                                 │
│                                                        │
│   final_score = (similarity_score × 0.70)             │
│               + (recency_score × 0.30)                │
│                                                        │
│   recency_score = 1 / (1 + log(days_since_created))   │
│                                                        │
│   Sort by final_score DESC, take top 10               │
└────────┬───────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────┐
│   Redis Cache Write                                    │
│                                                        │
│   Cache key: memory:{user_id}:{query_hash}            │
│   TTL: 300 seconds (5 minutes)                        │
│   (Avoids redundant Qdrant calls for same query       │
│    within same session)                               │
└────────┬───────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────┐
│   Context Injection into LLM Prompt                    │
│                                                        │
│   [SYSTEM]                                             │
│   ... user profile ...                                 │
│                                                        │
│   RELEVANT CONTEXT FROM MEMORY:                        │
│   [1] (score: 0.92, 3 days ago): "User mentioned      │
│       preference for morning meetings..."             │
│   [2] (score: 0.87, 12 days ago): "User had a call    │
│       with Sarah about Q3 planning..."                │
│   ... (up to 10 memories)                             │
│                                                        │
│   [USER] {current message}                             │
└────────────────────────────────────────────────────────┘
         │
         ▼
   Claude API call with enriched context
```

---

### 4.5 Travel Monitoring Flow

```
┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌──────────┐
│  Celery     │   │   Travel    │   │   Amadeus   │   │   Redis     │   │  Notif.  │
│  Beat       │   │   Service   │   │   API       │   │   Cache     │   │  Service │
└──────┬──────┘   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘   └────┬─────┘
       │                  │                  │                  │               │
       │ Every 15 min:    │                  │                  │               │
       │ flight_monitor   │                  │                  │               │
       │ task triggered   │                  │                  │               │
       │─────────────────►│                  │                  │               │
       │                  │                  │                  │               │
       │                  │ Query PostgreSQL: active flights     │               │
       │                  │ WHERE depart_time > NOW()           │               │
       │                  │ AND depart_time < NOW() + 24h       │               │
       │                  │                  │                  │               │
       │                  │ For each flight: │                  │               │
       │                  │                  │                  │               │
       │                  │ Get last known   │                  │               │
       │                  │ state            │                  │               │
       │                  │─────────────────────────────────────►               │
       │                  │ Cached state     │                  │               │
       │                  │◄─────────────────────────────────── │               │
       │                  │                  │                  │               │
       │                  │ GET /flights/{flight_number}/status │               │
       │                  │─────────────────►│                  │               │
       │                  │ Live flight data │                  │               │
       │                  │◄─────────────────│                  │               │
       │                  │                  │                  │               │
       │                  │ Compare current state vs. cached:   │               │
       │                  │ delay_delta = new_depart - old_depart               │
       │                  │                  │                  │               │
       │                  │ IF delay_delta > 30 min OR          │               │
       │                  │    status changed to CANCELLED OR   │               │
       │                  │    gate changed:                    │               │
       │                  │                  │                  │               │
       │                  │─────────────────────────────────────►               │
       │                  │ Update cached state (new TTL: 15min)│               │
       │                  │                  │                  │               │
       │                  │ Update PostgreSQL flight record      │               │
       │                  │                  │                  │               │
       │                  │ Trigger disruption notification      │               │
       │                  │────────────────────────────────────────────────────►│
       │                  │                  │                  │               │
       │                  │                  │                  │  FCM/APNs     │
       │                  │                  │                  │  push alert:  │
       │                  │                  │                  │  "Your flight │
       │                  │                  │                  │  UA 456 is    │
       │                  │                  │                  │  delayed 45   │
       │                  │                  │                  │  minutes"     │
       │                  │                  │                  │  → Mobile     │
```

---

## 5. Technology Stack Decisions

| Technology Choice | Alternative Considered | Decision Rationale |
|-------------------|----------------------|-------------------|
| **Flutter** (mobile) | React Native | Flutter compiles to native ARM bytecode — significantly better performance on mid-range Android devices, which are disproportionately used by ARIA's global target market. Single codebase with no JavaScript bridge eliminates a class of runtime errors. Dart's strong typing and Flutter's widget testing tooling provide better engineering confidence for a small team. React Native's ecosystem is larger but the JavaScript bridge and varying native module quality create unpredictable performance on complex screens like streaming chat. |
| **FastAPI** (backend) | Django, Express (Node.js) | FastAPI's native async support (via asyncio) is essential for ARIA's architecture: concurrent streaming from Claude API, non-blocking calendar sync, and WebSocket management all benefit from async throughout. Django's ORM is synchronous by default and requires workarounds for async contexts. Express/Node.js was considered but Python dominates the AI/ML ecosystem — using Python keeps the entire backend in a single language and allows direct use of the Anthropic SDK, sentence-transformers, and Celery without cross-language FFI. FastAPI's automatic OpenAPI schema generation is also a significant developer productivity benefit. |
| **PostgreSQL** (primary DB) | MongoDB | ARIA's data is fundamentally relational: users have integrations, conversations have messages, tasks have assignees, flights belong to itineraries. The foreign key constraints and referential integrity that PostgreSQL enforces prevent entire categories of data consistency bugs that are difficult to guard against in MongoDB. PostgreSQL's full-text search (via pg_trgm) provides a useful supplement to Qdrant semantic search for exact-match queries. MongoDB was considered for its flexible schema, but ARIA's schemas are well-defined and the operational simplicity of a single PostgreSQL deployment outweighs MongoDB's schema flexibility benefits at this stage. |
| **Qdrant** (vector DB) | Pinecone, Weaviate | Qdrant is open-source and self-hosted, eliminating per-vector pricing that would make the memory feature cost-prohibitive at scale (Pinecone charges per write/read operation). Qdrant's Rust-based implementation provides excellent performance-per-dollar on EC2 ARM instances (Graviton). Pinecone's managed service is simpler to operate but its pricing model becomes expensive beyond 1M vectors per user tier, and it lacks the data sovereignty guarantees required for GDPR compliance (all data must remain in the EU for EU users). Weaviate has a richer semantic feature set but adds complexity (GraphQL API, module system) that ARIA does not need. Qdrant's Python client is well-maintained and the filtering capability (Qdrant payload filters) is exactly what ARIA needs for per-user memory isolation. |
| **Redis** (cache + broker) | Memcached, AWS SQS | Redis's data structure richness (sorted sets for rate limiting, pub/sub for WebSocket events, lists for Celery queues, hashes for session data) makes it the clear choice over Memcached, which supports only simple key-value storage. AWS SQS was considered as the Celery broker for managed operation, but Redis as broker eliminates a separate service dependency and provides the pub/sub channel ARIA needs for WebSocket event propagation — SQS cannot do real-time pub/sub. AWS ElastiCache for Redis provides managed operation with the same reliability as SQS. |
| **Celery** (task queue) | RQ (Redis Queue), AWS SQS + Lambda | Celery's priority queue support (three named queues), Celery Beat for scheduled tasks, and mature retry/error handling are essential for ARIA's background processing model. RQ is simpler but lacks priority queues and scheduled task support without additional libraries. AWS SQS + Lambda was evaluated for serverless background processing but Lambda's cold start latency (100–500ms) and maximum execution time (15 minutes) create issues for long-running tasks like data export and bulk memory re-indexing. Celery on ECS Fargate gives full control over execution model and is well-understood by the Python engineering team. |
| **AWS** (cloud infrastructure) | GCP, Azure | AWS is the dominant choice for three reasons: (1) AWS has the most mature managed service ecosystem for ARIA's stack (ECS Fargate, RDS, ElastiCache, ALB, WAF, Secrets Manager, X-Ray, CloudWatch), reducing operational overhead for a small team; (2) AWS's data residency guarantees (EU regions) satisfy GDPR requirements; (3) Team expertise is strongest in AWS, reducing ramp-up time. GCP was a close second and would have been preferred if the team had stronger GCP experience (Cloud Run's serverless container model is excellent). Azure was not seriously considered due to team unfamiliarity and Microsoft's tighter ecosystem constraints. |
| **Anthropic Claude API** (LLM) | OpenAI GPT-4o, Google Gemini Ultra | Claude 3.5 Sonnet benchmarks best on multi-step reasoning tasks and produces more reliably structured output when using tool use / function calling — critical for ARIA's action extraction features. Claude's Constitutional AI training results in safer default behavior with less prompt injection risk (important when user-provided content flows into prompts). Anthropic's API has proven stable and well-documented. GPT-4o was a competitive alternative and remains available as a fallback. Gemini Ultra showed strong benchmark performance but Google's API reliability and SDK maturity lagged at evaluation time. Cost-per-token is comparable across all three for the selected model tiers. |

---

## 6. API Design Principles

### REST Conventions

ARIA's API follows REST conventions with pragmatic decisions over strict adherence:

- **Resources are nouns**: `/api/v1/conversations`, `/api/v1/tasks`, `/api/v1/memories`
- **HTTP verbs used semantically**: GET (read), POST (create), PUT (full replace), PATCH (partial update), DELETE (remove)
- **Nested resources for ownership**: `/api/v1/conversations/{id}/messages` (messages belong to a conversation)
- **Action endpoints where REST is awkward**: `/api/v1/tasks/{id}/complete`, `/api/v1/integrations/google-calendar/sync`
- **Consistent pluralization**: all collection endpoints use plural nouns

### Versioning Strategy

- URL-based versioning: `/api/v1/`, `/api/v2/`
- Major versions increment when breaking changes are introduced.
- Minor and patch changes are non-breaking and do not increment the version.
- A minimum of 6 months deprecation notice before removing any v1.x endpoint.
- Version sunset communicated via `Sunset` and `Deprecation` HTTP headers on deprecated endpoints.

### Authentication

- All protected endpoints require `Authorization: Bearer {access_token}` header.
- Access tokens are JWTs signed with RS256 (RSA private key stored in Secrets Manager).
- Token structure: `{ sub: user_id, email, tier, iat, exp, jti }` — `jti` enables per-token revocation.
- Refresh tokens stored server-side (Redis) and rotated on each use; stolen token window is minimized.
- OAuth 2.0 flows (Authorization Code + PKCE) used for all third-party integrations.

### Error Response Format

All errors return a consistent JSON structure:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable error description",
    "details": [
      { "field": "due_date", "issue": "must be a future date" }
    ],
    "request_id": "req_01J4KXYZ..."
  }
}
```

Standard error codes: `VALIDATION_ERROR` (400), `UNAUTHORIZED` (401), `FORBIDDEN` (403), `NOT_FOUND` (404), `RATE_LIMITED` (429), `AI_SERVICE_UNAVAILABLE` (503), `INTERNAL_ERROR` (500). The `request_id` is propagated through all system layers and appears in logs for debugging.

### Pagination Conventions

Cursor-based pagination for all list endpoints:

```
GET /api/v1/conversations?limit=20&cursor=eyJpZCI6IjEyMyJ9
```

Response includes:
```json
{
  "data": [...],
  "pagination": {
    "limit": 20,
    "next_cursor": "eyJpZCI6IjE0MyJ9",
    "has_more": true,
    "total_count": 847
  }
}
```

Cursor encodes the last seen record's sort key (typically `created_at` + `id`), base64-encoded. Offset-based pagination is not used for large collections because it degrades at high offsets.

### Rate Limiting Approach

| Tier | Messages/minute | API calls/minute | Voice requests/hour |
|------|-----------------|-----------------|---------------------|
| Free | 20 | 60 | 5 |
| Pro ($19.99/month) | 60 | 300 | 30 |
| Team ($49.99/user/month) | 120 | 600 | 60 |

Rate limits are enforced per-user using Redis sliding window counters. Responses include headers:
- `X-RateLimit-Limit`: requests allowed per window
- `X-RateLimit-Remaining`: requests remaining in current window
- `X-RateLimit-Reset`: Unix timestamp when window resets
- HTTP 429 with `Retry-After` header when limit is exceeded.

---

## 7. Scalability Architecture

### 7.1 Horizontal Scaling

**Stateless API Servers:**
The FastAPI API server stores no local state — all state lives in PostgreSQL, Redis, or S3. This means ECS Fargate can scale the API server task count freely based on demand. Target tracking scaling policy: 60% average CPU utilization as the steady-state target. Minimum 3 tasks (one per Availability Zone) at all times for high availability. Scale-out: add 2 tasks per alarm breach; scale-in: remove 1 task per 10-minute cooldown window.

**Read Replicas for PostgreSQL:**
A PostgreSQL read replica (Multi-AZ standby promotes to primary on failure; separate read replica for read traffic) handles analytics queries, reporting, and the memory viewer's metadata queries. SQLAlchemy is configured with two engine URLs: `write_engine` (primary) for all INSERT/UPDATE/DELETE, `read_engine` (replica) for SELECT-only operations in the Memory and Calendar services.

**Qdrant Cluster:**
3-node Qdrant cluster with collection replication factor 2. Reads distributed across all nodes; writes replicated synchronously to 2 nodes. Qdrant's distributed search fans out to all shards and merges results. At 3× user growth, adding nodes and triggering a reshard operation distributes load without downtime.

**Redis Cluster:**
ElastiCache Redis Cluster Mode with 3 shards × 2 replicas (6 nodes total). Hash slots distributed across shards automatically. Client-side cluster routing via redis-py's cluster client. Online resharding supported without service interruption.

---

### 7.2 Caching Strategy

**L1: In-process Cache (API Server)**
Using Python's `functools.lru_cache` and a custom per-request cache for data that does not change within a single request:
- JWT public key (for RS256 verification) — cached indefinitely until key rotation.
- Feature flag configuration — cached for 60 seconds.
- User subscription tier (fetched once per request, cached in request context).

**L2: Redis Shared Cache**

| Data Type | Cache Key Pattern | TTL | Invalidation Trigger |
|-----------|------------------|-----|----------------------|
| User profile | `user:{user_id}:profile` | 5 minutes | Profile update event |
| Today's calendar events | `user:{user_id}:events:today` | 5 minutes | Calendar webhook received |
| Upcoming 7-day events | `user:{user_id}:events:week` | 15 minutes | Calendar sync complete |
| Connected integrations | `user:{user_id}:integrations` | 10 minutes | Integration connect/revoke |
| Memory retrieval results | `memory:{user_id}:{query_hash}` | 5 minutes | Any new memory stored |
| Last conversation context | `user:{user_id}:conv_context` | 24 hours | New message processed |
| Flight last-known state | `flight:{flight_id}:state` | 15 minutes | Next poll cycle |
| Rate limit counters | `ratelimit:{user_id}:{endpoint}` | 60 seconds | Sliding window INCR/EXPIRE |

**Cache Invalidation Patterns:**
- **Write-through**: Data written to PostgreSQL is simultaneously written to Redis (AI Engine, Calendar Service).
- **Event-based**: Calendar webhook events trigger Redis key deletion for affected user's event cache.
- **TTL expiry**: Most cache entries are short-lived enough that TTL expiry is the primary invalidation mechanism; explicit invalidation is used only for correctness-critical data (user profile changes, integration status).

---

### 7.3 Async Processing

**Celery Task Queue Design:**

Three priority queues processed by dedicated worker pools:

| Queue | Priority | Workers (min/max) | Typical Tasks |
|-------|----------|-------------------|--------------|
| `high` | Highest | 3 / 20 | Voice transcription completion, urgent notifications (travel disruptions), real-time meeting briefings |
| `default` | Medium | 3 / 30 | Memory indexing, calendar sync jobs, standard notifications, action item extraction |
| `low` | Lowest | 1 / 10 | Analytics events, data export generation, old data cleanup, token refresh |

Workers consume from `high` first, then `default`, then `low`. A Celery routing configuration maps task function names to the appropriate queue.

**Task Retry Policies:**

```python
@celery.task(
    bind=True,
    max_retries=3,
    default_retry_delay=30,         # 30 seconds initial delay
    retry_backoff=True,             # Exponential backoff
    retry_backoff_max=300,          # Cap at 5 minutes
    autoretry_for=(ExternalAPIError, NetworkError),
    acks_late=True                  # Only ack after successful processing
)
```

**Dead Letter Queue Handling:**
Tasks that exhaust max_retries are routed to a `dead_letter` queue and trigger a CloudWatch alarm. The on-call engineer reviews dead letter tasks via Flower dashboard. Common causes are documented in runbooks with resolution steps. Dead letter tasks are retained for 7 days for manual inspection and replay.

**Scheduled Tasks (Celery Beat):**

| Task | Schedule | Priority Queue |
|------|----------|---------------|
| Calendar sync (active users) | Every 5 minutes | default |
| Travel flight monitoring | Every 15 minutes | high |
| Meeting briefing generator | Every 1 minute (checks 30-min window) | high |
| OAuth token refresh (expiring in 24h) | Every 6 hours | low |
| Old audio file cleanup (S3) | Daily at 03:00 UTC | low |
| Analytics aggregation | Daily at 04:00 UTC | low |
| Memory re-indexing (flagged entries) | Weekly at 02:00 UTC Sunday | low |

---

### 7.4 Database Optimization

**Connection Pooling (PgBouncer):**
PgBouncer runs as a sidecar container in each API server ECS task (or as a dedicated ECS service for the worker fleet). Transaction mode pooling with 25 server connections per PgBouncer instance (100 connections total across 4 ECS tasks). PostgreSQL `max_connections` set to 200, leaving headroom for direct admin connections and Celery workers.

**Query Optimization Strategies:**
- All foreign key columns indexed.
- Composite indexes on frequently joined columns: `(user_id, created_at DESC)` on `messages`, `(user_id, status, due_date)` on `tasks`, `(user_id, start_time)` on `calendar_events`.
- EXPLAIN ANALYZE run on all queries during development; slow query log threshold set to 100ms in production.
- N+1 query prevention enforced via SQLAlchemy relationship loading strategy review in code review checklist.
- Database-level pagination using keyset pagination (WHERE id > :last_id ORDER BY id LIMIT :limit) instead of OFFSET for large tables.

**Partitioning for High-Volume Tables:**
- `messages` table: range partitioned by `created_at` per month. Partition pruning ensures queries for recent messages touch only 1–2 partitions.
- `calendar_events` table: range partitioned by `start_time` per quarter.
- `notification_log` table: range partitioned by `created_at` per month; partitions older than 6 months dropped automatically via Lifecycle policy trigger.
- Partition maintenance (CREATE PARTITION for next period, DROP oldest expired partition) handled by a monthly Celery task.

**Archive Strategy:**
Messages and calendar events older than 24 months are moved from the active partitioned table to a compressed `_archive` table using a Celery batch job running in the `low` priority queue. Archive tables have the same schema but no indexes except on `(user_id, created_at)`. Data remains queryable for user data export and remains subject to the same deletion policies.

---

## 8. Security Architecture

### 8.1 Authentication & Authorization

**JWT Access + Refresh Token Pattern:**

```
Access Token:  RSA-256 signed, 15-minute expiry
               Payload: { sub, email, tier, iat, exp, jti }
               Stored: Client memory only (never persisted to disk)

Refresh Token: 256-bit random, 30-day expiry
               Stored: Server-side in Redis (hashed); client stores in SecureStorage
               Rotation: On every use, old token invalidated immediately
               Revocation: Delete from Redis; all active access tokens expire within 15 min
```

**Token Rotation Policy:**
- Refresh token rotated on every `/auth/refresh` call.
- If a refresh token is used more than once (possible stolen token replay), all sessions for that user are immediately invalidated and the user is notified via email.
- Access token JTI (JWT ID) stored in Redis with 15-minute TTL to support immediate revocation (e.g., on password change or logout-all-devices).

**OAuth2 Flows for Third-party Integrations:**
- Authorization Code + PKCE flow used for all OAuth integrations (Google Calendar, Gmail, Microsoft Graph, Slack, Notion).
- PKCE prevents authorization code interception attacks — mandatory for mobile clients.
- OAuth state parameter validated server-side to prevent CSRF.
- Access and refresh tokens from third-party providers stored encrypted in PostgreSQL (`integration_tokens` table) using AES-256-GCM with a user-specific key derived from a master key in Secrets Manager.

**Permission Model (RBAC):**
- For v1.0: two roles — `user` (standard permissions) and `admin` (internal ARIA team).
- Future Team plan: `team_owner`, `team_member`, `team_viewer` roles.
- Permissions enforced at the FastAPI dependency layer — every protected endpoint declares its required permission, checked against the JWT claims and database role record.

---

### 8.2 Data Encryption

**Encryption at Rest:**
- RDS PostgreSQL: AES-256 encryption via AWS KMS (customer-managed key, CMK). Key rotation annually.
- ElastiCache Redis: AES-256 encryption at rest (AWS managed key).
- S3 Buckets: Server-side encryption (SSE-KMS) with customer-managed key. Bucket policies deny unencrypted PUT requests.
- Qdrant EC2 volumes: EBS volumes encrypted with AWS KMS CMK.

**Encryption in Transit:**
- All external HTTPS connections: TLS 1.3 minimum, TLS 1.2 as fallback only for legacy client compatibility. TLS 1.0 and 1.1 disabled at ALB.
- Internal VPC communication: TLS enforced for all inter-service communication (API → PostgreSQL via ssl=require, API → Redis via TLS, API → Qdrant via HTTPS).
- AWS certificate via ACM, auto-renewed.

**Database Column Encryption for PII:**
The following PostgreSQL columns are encrypted at the application layer using `sqlalchemy-utils` EncryptedType with AES-256-GCM:
- `users.email`, `users.name`, `users.phone`
- `messages.content` (conversation text)
- `integration_tokens.access_token`, `integration_tokens.refresh_token`
- `travel_itineraries.passenger_name`, `travel_itineraries.passport_number` (when provided)

Column-level encryption uses a per-tenant key derived via HKDF from a master key stored in AWS Secrets Manager. Key derivation parameters: `HKDF(master_key, salt=user_id, info="aria_field_encryption_v1", hash=SHA-256, length=32)`.

**API Key Storage:**
- All third-party API keys (Anthropic, OpenAI, Amadeus, Twilio) stored in AWS Secrets Manager.
- Accessed at application startup via `boto3.client('secretsmanager')` and cached in environment memory — never written to disk or logs.
- Automatic rotation policy configured where supported by provider.

---

### 8.3 Network Security

**VPC Architecture:**
```
AWS VPC (10.0.0.0/16)
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24) — 3 AZs
│   └── ALB (public-facing)
│   └── NAT Gateways (for private subnet outbound)
│
└── Private Subnets (10.0.10.0/24, 10.0.11.0/24, 10.0.12.0/24) — 3 AZs
    └── ECS Fargate tasks (API Server, Workers)
    └── RDS PostgreSQL (Multi-AZ)
    └── ElastiCache Redis Cluster
    └── Qdrant EC2 instances
```

No database or cache service has a public IP address. All outbound traffic from ECS tasks to the internet (Claude API, external APIs) routes through NAT Gateways in public subnets.

**Security Groups:**
- `sg-alb`: Allow inbound 443 from 0.0.0.0/0; allow outbound to `sg-api` on port 8000.
- `sg-api`: Allow inbound from `sg-alb` on 8000; allow outbound to `sg-postgres` (5432), `sg-redis` (6379), `sg-qdrant` (6333), and internet (via NAT).
- `sg-postgres`: Allow inbound from `sg-api` on 5432 only.
- `sg-redis`: Allow inbound from `sg-api` on 6379 only.
- `sg-qdrant`: Allow inbound from `sg-api` on 6333 only.

**NACLs:** VPC Network ACLs configured as defense-in-depth — deny inbound from known malicious IP ranges (updated monthly from threat intelligence feeds), deny outbound to unexpected port ranges from data subnet.

**WAF Rules:**
- AWS Managed Rules: Core rule set (OWASP Top 10), SQL injection rule set, Linux OS rule set.
- Custom rules: Block requests with payloads >1MB to `/api/v1/conversations`; rate-based rule blocking IPs with >1000 requests in 5 minutes; geographic restrictions (block countries on OFAC list).
- WAF logging enabled to S3 for security analysis.

**DDoS Protection:** AWS Shield Standard (included) for network and transport layer protection. AWS Shield Advanced evaluated for launch (provides layer 7 protection and DDoS response team access).

---

### 8.4 Privacy & Compliance

**GDPR Compliance Measures:**

| Requirement | Implementation |
|-------------|---------------|
| Consent | Explicit consent checkbox at registration; consent record stored in `users.consent_log` JSON column with timestamp and consent version |
| Data Minimization | Only PII required for feature operation collected; no behavioral analytics beyond ARIA's own feature improvement |
| Right of Access | `/api/v1/account/data-export` endpoint generates complete user data archive |
| Right to Rectification | Profile edit, memory edit, task edit all available through standard UI |
| Right to Erasure | `/api/v1/account/delete` triggers cascading async deletion across all systems within 30 days |
| Right to Portability | Data export in JSON format; CSV available for specific data types (tasks, events) |
| Data Residency | EU users routed to eu-west-1 (Ireland) deployment via Route 53 geolocation routing |
| DPA | Data Processing Agreement template available for B2B customers; DPA with all sub-processors maintained |

**Right to Erasure Implementation:**
The account deletion pipeline is an async Celery workflow with the following steps:
1. Mark user account as `deletion_pending` in PostgreSQL.
2. Revoke all active JWT refresh tokens (Redis delete).
3. Revoke all third-party OAuth tokens (API call to each provider).
4. Delete all Qdrant vectors for user (payload-filtered bulk delete).
5. Delete all S3 objects for user (S3 prefix deletion).
6. Anonymize PostgreSQL records: replace PII columns with `[DELETED]`, delete `messages.content`, delete integration tokens.
7. Mark account `deletion_complete`; send confirmation email.
8. After 30 days: hard delete the anonymized user record.

**CCPA Compliance:**
- "Do Not Sell My Personal Information" toggle available in Privacy Settings (ARIA does not sell user data as a matter of policy, but the toggle is required for CCPA compliance).
- California-specific privacy disclosures in Privacy Policy.
- Verified request process for data access/deletion requests received by email.
- Privacy contact: privacy@aria.ai.

**Audit Logging:**
Security-sensitive events logged to `audit_log` table with: event_type, user_id, ip_address (hashed), user_agent, timestamp, outcome. Events logged: login, logout, password change, MFA change, data export request, account deletion request, integration connect, integration revoke, memory bulk delete. Audit logs retained for 2 years; immutable (append-only, no update/delete on table via row security policy).

---

### 8.5 Third-party Integration Security

**OAuth Token Encryption at Rest:**
All OAuth access tokens and refresh tokens from Google, Microsoft, Slack, Gmail, and Notion are stored in PostgreSQL with application-layer AES-256-GCM encryption. The encryption key is unique per user (derived from user_id + master key in Secrets Manager). Tokens are decrypted only in memory when making API calls and are never logged or included in error responses.

**Token Refresh Handling:**
A Celery periodic task scans for OAuth tokens expiring within 24 hours and proactively refreshes them before expiry. This prevents integration failures during active user sessions. If refresh fails (e.g., user revoked access at the provider), the integration is marked `requires_reauth` and the user is notified via push notification and in-app banner.

**Scope Limitation Principle:**
ARIA requests only the minimum OAuth scopes required for each integration:
- **Google Calendar**: `https://www.googleapis.com/auth/calendar` (read/write events only)
- **Gmail**: `https://www.googleapis.com/auth/gmail.modify` (read, send, label — not delete)
- **Slack**: `channels:history`, `chat:write`, `users:read` — no admin scopes
- **Notion**: `read_content`, `insert_content`, `update_content` — no workspace admin

**Integration Permission Revocation:**
When a user revokes an integration in ARIA:
1. ARIA calls the provider's token revocation endpoint to invalidate the token at source.
2. Encrypted tokens deleted from PostgreSQL immediately.
3. Redis cache for integration status cleared.
4. Any pending Celery tasks for this integration cancelled.
5. User notified of successful revocation.

---

## 9. Deployment Architecture

### 9.1 Environments

**Development (Local Docker Compose):**
```yaml
services:
  api:         # FastAPI server (hot reload with watchfiles)
  worker:      # Celery workers (high + default + low queues)
  beat:        # Celery Beat scheduler
  postgres:    # PostgreSQL 16 (data persisted in Docker volume)
  redis:       # Redis 7.2 (single node, no cluster)
  qdrant:      # Qdrant (single node)
  flower:      # Celery monitoring dashboard
  pgadmin:     # PostgreSQL admin UI (dev only)
```
All secrets in `.env` file (gitignored). External API calls to Anthropic, Google, etc. go to live APIs (developers use personal API keys). Whisper calls use a local Whisper model for cost control during development.

**Staging (AWS ECS on EC2):**
Identical infrastructure to production but smaller instance sizes (t3.medium vs m6i.xlarge). Staging environment uses a separate AWS account to prevent blast radius from staging mistakes. CI/CD deploys to staging automatically on every merge to `main`. Staging data is synthetic (generated test users, no real PII). Staging uses live external APIs with test credentials where available.

**Production (AWS ECS Fargate — Multi-AZ):**
All ECS tasks run on Fargate (serverless compute — no EC2 instance management). Three Availability Zones (us-east-1a, 1b, 1c). Minimum task counts enforced so that losing one AZ does not drop below minimum required capacity. Production AWS account separate from staging. CloudTrail enabled for all API calls. Config Rules enforce security baselines (e.g., no public S3 buckets, all volumes encrypted, no root account API keys active).

---

### 9.2 CI/CD Pipeline

**GitHub Actions Pipeline:**

```
On: Pull Request to main
  ├── [1] Lint & Format Check
  │   ├── ruff (Python linting)
  │   ├── mypy (type checking)
  │   └── flutter analyze + dart format --set-exit-if-changed
  │
  ├── [2] Unit Tests
  │   ├── pytest (backend, coverage ≥80%)
  │   └── flutter test (mobile, coverage ≥70%)
  │
  ├── [3] Integration Tests
  │   ├── pytest with Docker Compose (PostgreSQL + Redis + Qdrant in CI)
  │   └── API contract tests (Schemathesis against OpenAPI spec)
  │
  └── [4] Security Scan
      ├── Bandit (Python SAST)
      ├── Trivy (Docker image vulnerability scan)
      └── pip-audit (dependency CVE check)

On: Merge to main
  ├── [5] Build Docker Images
  │   ├── docker build --platform linux/arm64 (API server image)
  │   └── docker build --platform linux/arm64 (Celery worker image)
  │
  ├── [6] Push to AWS ECR
  │   ├── Tag: {git_sha} (immutable)
  │   └── Tag: latest (mutable, staging only)
  │
  ├── [7] Deploy to Staging (ECS)
  │   ├── aws ecs update-service (API service)
  │   ├── aws ecs update-service (Worker service)
  │   └── Wait for deployment stability (health check)
  │
  ├── [8] Staging Smoke Tests
  │   ├── Auth flow test
  │   ├── Create conversation, send message
  │   └── Create task, calendar event
  │
  └── [9] Manual Gate: Production Deployment (requires approval)
      ├── aws ecs update-service (production API)
      ├── aws ecs update-service (production Workers)
      ├── ECS deployment circuit breaker enabled (automatic rollback on health failure)
      ├── CloudWatch synthetic canary verifies post-deployment
      └── Rollback: aws ecs update-service --force-new-deployment (previous task definition)
```

**Mobile CI (Flutter):**
- PR: `flutter test`, `flutter analyze`
- Main merge: `flutter build apk --release` (Android), `flutter build ipa` (iOS)
- TestFlight / Firebase App Distribution upload for internal testing
- Production releases to App Store and Google Play require manual version bump and approval

---

### 9.3 Infrastructure as Code

All AWS infrastructure defined in Terraform (v1.9+) organized into modules:

| Terraform Module | Resources Managed |
|-----------------|-------------------|
| `modules/vpc` | VPC, subnets (public/private), route tables, NAT gateways, internet gateway, VPC flow logs |
| `modules/ecs` | ECS cluster, task definitions (API, Worker, Beat), IAM roles, ECR repositories, ECS services, auto-scaling policies |
| `modules/rds` | RDS PostgreSQL instance, Multi-AZ standby, read replica, subnet group, parameter group, security group, automated backup policy |
| `modules/elasticache` | ElastiCache Redis Cluster, subnet group, security group, parameter group |
| `modules/qdrant` | EC2 instances (3-node cluster), EBS volumes, security group, IAM instance profile, user data script for Qdrant installation |
| `modules/s3` | S3 buckets (user data, audio, exports, logs), bucket policies, lifecycle rules, KMS key, replication configuration |
| `modules/cloudfront` | CloudFront distribution, cache behaviors, origin access identity, SSL certificate, WAF association |
| `modules/route53` | Hosted zone, A/AAAA records, health checks, geolocation routing policy (US vs EU) |
| `modules/waf` | WAFv2 WebACL, managed rule groups, custom rules, WAF logging configuration |
| `modules/secrets` | Secrets Manager secrets (API keys, DB credentials), rotation configuration |
| `modules/monitoring` | CloudWatch dashboards, alarms, log groups, X-Ray sampling rules, SNS topics for alerts |

Terraform state stored in S3 (with DynamoDB lock table). State environments isolated by Terraform workspace (`development`, `staging`, `production`). Modules parameterized for environment-specific sizing.

---

### 9.4 Monitoring & Observability

**Metrics (CloudWatch + Grafana):**

Grafana (running on ECS) connects to CloudWatch as a data source and presents a unified dashboard:

| Dashboard Panel | Metric Source | Alert Threshold |
|-----------------|--------------|-----------------|
| API Request Rate (RPS) | ALB RequestCount | None (informational) |
| API Latency P50/P95/P99 | ALB TargetResponseTime | Alert if P95 > 3s sustained 5 min |
| AI Response Latency | Custom CloudWatch metric from API | Alert if P95 > 6s sustained 5 min |
| Error Rate (5xx) | ALB HTTPCode_Target_5XX | Alert if > 1% of requests over 5 min |
| ECS CPU Utilization | ECS CPUUtilization | Alert if > 85% sustained 10 min |
| ECS Memory Utilization | ECS MemoryUtilization | Alert if > 85% sustained 10 min |
| PostgreSQL Connections | RDS DatabaseConnections | Alert if > 80% of max_connections |
| Redis Memory Usage | ElastiCache FreeableMemory | Alert if < 20% free |
| Celery Queue Depth | Custom metric (Celery queue length) | Alert if high queue > 100 items |
| Qdrant Vector Count | Custom metric from Qdrant API | Informational |
| Claude API Latency | Custom metric from AI Engine | Alert if P95 > 5s |
| Voice Transcription Success Rate | Custom metric | Alert if < 95% |

**Logging (CloudWatch Logs):**
All application logs written as structured JSON with standard fields: `timestamp`, `level`, `service`, `request_id`, `user_id` (hashed for privacy), `message`, `duration_ms`, `error` (if applicable). Log groups:
- `/aria/api-server` — API request/response logs
- `/aria/celery-workers` — Task execution logs
- `/aria/security-audit` — Audit trail events
- `/aria/external-api` — Third-party API call logs (response times, error codes)

CloudWatch Log Insights used for ad-hoc debugging. Log retention: 30 days for application logs, 2 years for audit logs.

**Distributed Tracing (AWS X-Ray):**
X-Ray SDK integrated in FastAPI via middleware. Each incoming request generates a trace with segments for: Auth validation, database queries, Redis operations, external API calls (Claude, Google, Whisper), and Celery task dispatch. Trace IDs propagated to Celery workers via task metadata. X-Ray service map shows latency breakdown and error rates per component.

**Alerting (PagerDuty):**
CloudWatch alarms SNS → PagerDuty integration. Alert severity levels:
- **Critical** (immediate page): API error rate > 5%, all ECS tasks unhealthy, PostgreSQL unreachable, P99 latency > 10s.
- **Warning** (email + Slack): API error rate 1–5%, ECS CPU > 85%, Redis memory > 80%, Celery dead letter queue depth > 10.
- **Informational** (Slack only): Deployment started/completed, auto-scaling events, certificate approaching expiry.

On-call rotation: 24×7 coverage with 2 engineers (primary + secondary). PagerDuty escalation policy: primary paged first; if no acknowledgement in 5 minutes, secondary paged; if no acknowledgement in 15 minutes, engineering manager paged.

**Uptime Monitoring (Synthetic Monitoring):**
CloudWatch Synthetics canary runs every 5 minutes from us-east-1:
- Canary 1: GET `/api/v1/health` — basic health check.
- Canary 2: Full auth flow + create message + verify response — end-to-end smoke test.
- Canary 3: Create task + verify in task list — feature-specific smoke test.

Results published to CloudWatch dashboard. Failure triggers Critical alert immediately.

---

## 10. Disaster Recovery

### Recovery Objectives

| Objective | Target | Rationale |
|-----------|--------|-----------|
| Recovery Point Objective (RPO) | 1 hour | Continuous WAL archiving to S3 ensures at most 1 hour of data loss in worst-case PostgreSQL failure |
| Recovery Time Objective (RTO) | 4 hours | Multi-AZ RDS failover is automatic (<2 min); Qdrant and Redis restoration from backup is manual; full platform restoration documented and practiced |

### Backup Strategy

**PostgreSQL:**
- Automated daily snapshots via AWS RDS (retained 35 days).
- Continuous WAL archiving to S3 (retained 7 days) for point-in-time recovery to any 5-minute window.
- Multi-AZ synchronous standby replica provides zero-data-loss failover for AZ-level failures.
- Monthly backup restoration test into isolated environment to verify RPO/RTO.

**Qdrant:**
- Daily snapshot via Qdrant's snapshot API to S3 (retained 14 days).
- Snapshot restore documented in runbook: estimated 2–4 hours for full restoration at 50B vectors.
- For minor data loss (< 1 day), Qdrant can be reconstructed by replaying recent memories from PostgreSQL `memory_metadata` table and re-embedding — this is the preferred approach for small-scale incidents.

**Redis:**
- ElastiCache Redis cluster persistence via AOF (Append-Only File) with `appendfsync everysec` — at most 1 second of data loss.
- Redis is largely reconstructable from PostgreSQL (sessions, rate limit counters are transient; cache can be cold-started).
- Redis data loss is generally recoverable without backup restore because all persistent data lives in PostgreSQL.

**S3:**
- S3 Versioning enabled on user data bucket — accidental deletions recoverable for 90 days.
- Cross-region replication to us-west-2 for user data bucket — additional durability against region-level failure.
- S3 SLA: 99.99% availability, 11 nines durability.

### Multi-AZ Failover

RDS Multi-AZ: AWS automatically promotes the standby replica to primary within 60–120 seconds on primary AZ failure. Connection string uses the RDS endpoint which automatically resolves to the new primary. PgBouncer reconnects automatically after brief connection failures.

ECS Fargate: If an AZ fails, ALB stops routing to tasks in the failed AZ within 30 seconds (health check failure). Remaining tasks in healthy AZs serve traffic. Auto-scaling policy adds replacement tasks in healthy AZs within 2 minutes.

### Runbooks for Common Failure Scenarios

**Runbook 1: PostgreSQL Primary Failure**
1. RDS Multi-AZ promotes standby automatically (60–120 seconds). Monitor: CloudWatch `RDS:ReplicaLag` alarm.
2. PgBouncer reconnects to new primary (connection pool refresh). Verify: test query via bastion host.
3. If automatic failover fails: manually promote via AWS Console or `aws rds failover-db-cluster`. ETA: 5 minutes.
4. After failover: verify read replica reconnected to new primary. Rebuild read replica if detached.

**Runbook 2: Qdrant Node Failure**
1. 3-node cluster tolerates 1 node failure with replication factor 2. Verify: remaining nodes serving search via health endpoint.
2. Replace failed node: launch new EC2 from AMI, configure Qdrant, add to cluster. ETA: 20–30 minutes.
3. Cluster rebalances automatically after node addition. Monitor: Qdrant cluster status API.
4. If majority quorum lost (2 of 3 nodes fail): restore from S3 snapshot to new 3-node cluster. ETA: 2–4 hours.

**Runbook 3: Redis Cluster Failure**
1. ElastiCache Multi-AZ promotes replica to primary automatically (1–2 minutes). Monitor: ElastiCache events.
2. API server and workers reconnect automatically (redis-py cluster client handles topology changes).
3. Expected impact: Celery tasks temporarily unable to be processed (<2 minutes); rate limit counters reset (temporary burst allowed); session cache cold (users re-fetch profile from PostgreSQL).

**Runbook 4: Anthropic Claude API Outage**
1. AI Engine detects Claude API errors (5xx or timeout). CloudWatch alarm triggers.
2. Graceful degradation: API returns 503 with user-facing message: "AI features are temporarily unavailable. Your message has been saved and will be processed when service is restored."
3. Celery task queues the user message for async processing when Claude API recovers.
4. Non-AI features (calendar, tasks, travel) continue operating normally.
5. Monitor Anthropic status page: https://status.anthropic.com. Alert PagerDuty if outage exceeds 30 minutes.

**Runbook 5: Full Region Failure (us-east-1)**
1. Route 53 health checks detect ALB failure; failover routing activates eu-west-1 (EU) or us-west-2 standby.
2. Note: Cross-region standby is not configured in v1.0 (cost/complexity). This is a documented gap.
3. In full region failure: ARIA is unavailable until us-east-1 recovers or infrastructure is manually re-provisioned in alternate region from Terraform.
4. Target: v2.0 to include active-passive multi-region deployment. ETA: 6 months post-launch.

---

## Appendix

### A.1 Sequence Diagram: Authentication Flow

```
Flutter App          FastAPI             PostgreSQL         Redis
    │                    │                    │                │
    │  POST /auth/register                    │                │
    │  {email, password, name}                │                │
    │───────────────────►│                    │                │
    │                    │ Hash password      │                │
    │                    │ (bcrypt, cost=12)  │                │
    │                    │ INSERT users       │                │
    │                    │───────────────────►│                │
    │                    │ user_id returned   │                │
    │                    │◄───────────────────│                │
    │                    │ Send verification email (Celery async)
    │                    │ Generate access_token (JWT RS256, 15min)
    │                    │ Generate refresh_token (256-bit random, 30d)
    │                    │ Store refresh_token hash           │
    │                    │───────────────────────────────────►│
    │                    │                    │                │
    │  201 { access_token, refresh_token }    │                │
    │◄───────────────────│                    │                │
    │                    │                    │                │
    │  (15 minutes later: access token expires)               │
    │                    │                    │                │
    │  POST /auth/refresh                     │                │
    │  { refresh_token }                      │                │
    │───────────────────►│                    │                │
    │                    │ Lookup refresh_token hash          │
    │                    │───────────────────────────────────►│
    │                    │ Token found, valid  │               │
    │                    │◄───────────────────────────────────│
    │                    │ DELETE old refresh_token hash      │
    │                    │ STORE new refresh_token hash       │
    │                    │───────────────────────────────────►│
    │                    │ Generate new access_token          │
    │                    │ Generate new refresh_token         │
    │                    │                    │                │
    │  200 { access_token, refresh_token }    │                │
    │◄───────────────────│                    │                │
```

---

### A.2 Database Connection Architecture

```
                        ┌─────────────────────────────────────┐
                        │         ECS Fargate Tasks           │
                        │                                     │
                        │  ┌─────────────┐  ┌─────────────┐  │
                        │  │ API Server  │  │ API Server  │  │
                        │  │  Task 1     │  │  Task 2     │  │
                        │  └──────┬──────┘  └──────┬──────┘  │
                        │         │ asyncpg         │ asyncpg │
                        │         │ pool (10 conns) │ pool    │
                        └─────────┼─────────────────┼─────────┘
                                  │                 │
                        ┌─────────▼─────────────────▼─────────┐
                        │         PgBouncer                   │
                        │  (Transaction mode pooling)         │
                        │  Server pool: 25 connections        │
                        │  Client pool: unlimited             │
                        │  Port: 6432                         │
                        └─────────────────┬───────────────────┘
                                          │
                          ┌───────────────┼───────────────┐
                          │               │               │
                ┌─────────▼──────┐        │    ┌──────────▼────────┐
                │  PostgreSQL    │        │    │  PostgreSQL        │
                │  Primary       │        │    │  Read Replica      │
                │  (Multi-AZ)    │        │    │  (Analytics)       │
                │  Port: 5432    │        │    │  Port: 5432        │
                └─────────────── ┘  WAL   │    └────────────────────┘
                         │         stream  │
                ┌─────────▼──────┐        │
                │  PostgreSQL    │        │
                │  Standby       │◄───────┘
                │  Replica       │
                │  (Multi-AZ)    │
                └────────────────┘

                ┌──────────────────────────────────────────┐
                │         Celery Workers (ECS Fargate)     │
                │                                          │
                │  SQLAlchemy sync engine                  │
                │  Direct connection to Primary:5432       │
                │  (Celery workers use sync SQLAlchemy,    │
                │   not async — worker processes are       │
                │   single-threaded per task)              │
                └──────────────────────────────────────────┘
```

---

### A.3 Qdrant Collection Design Rationale

**Single Collection vs. Per-User Collection:**

ARIA uses a **single collection** (`aria_memories`) for all users, with user isolation enforced via payload filtering. This design decision was made for the following reasons:

1. **Operational simplicity**: A single collection means a single index, single replication configuration, and single monitoring target. Per-user collections at 100K users = 100K collections to manage — operationally untenable.

2. **Qdrant's filtering performance**: Qdrant uses a specialized HNSW graph with payload filtering integrated into the traversal algorithm. Filtering by `user_id` (a keyword payload field with cardinality = number of users) is highly efficient because Qdrant indexes keyword payload fields and pre-filters candidate vectors before graph traversal.

3. **Resource efficiency**: A single collection with HNSW indexing uses memory proportional to the number of vectors, not the number of partitions. Per-user collections would each maintain a separate HNSW graph with significant memory overhead per empty or small-population collection.

**Collection Configuration:**

```python
collection_config = {
    "vectors": {
        "content_embedding": {
            "size": 384,               # all-MiniLM-L6-v2 output dimension
            "distance": "Cosine"       # Cosine similarity for semantic text search
        }
    },
    "hnsw_config": {
        "m": 16,                       # Number of edges per node (accuracy vs. memory tradeoff)
        "ef_construct": 100,           # Build-time search breadth (higher = better quality, slower build)
        "full_scan_threshold": 10000,  # Below this vector count, use full scan instead of HNSW
        "on_disk": True               # Store HNSW graph on disk for memory efficiency at scale
    },
    "optimizers_config": {
        "default_segment_number": 4,  # Parallel segments for search performance
        "max_segment_size": 200000,   # Max vectors per segment before splitting
        "memmap_threshold": 50000     # Vectors above this threshold use memory-mapped files
    },
    "replication_factor": 2,          # Data replicated to 2 nodes; tolerate 1 node failure
    "write_consistency_factor": 1     # Writes acknowledged by 1 node (performance; 2 for strict)
}
```

**Payload Indexes (for filter performance):**
```python
# Created at collection initialization
qdrant_client.create_payload_index(
    collection_name="aria_memories",
    field_name="user_id",
    field_schema=PayloadSchemaType.KEYWORD
)
qdrant_client.create_payload_index(
    collection_name="aria_memories",
    field_name="memory_type",
    field_schema=PayloadSchemaType.KEYWORD
)
qdrant_client.create_payload_index(
    collection_name="aria_memories",
    field_name="created_at",
    field_schema=PayloadSchemaType.INTEGER
)
```

**Search Query Pattern:**

```python
search_results = qdrant_client.search(
    collection_name="aria_memories",
    query_vector=("content_embedding", query_embedding),
    query_filter=Filter(
        must=[
            FieldCondition(
                key="user_id",
                match=MatchValue(value=user_id)
            ),
            FieldCondition(
                key="created_at",
                range=Range(gte=cutoff_timestamp)  # Optional: limit to last N days
            )
        ]
    ),
    limit=20,
    score_threshold=0.65,    # Minimum cosine similarity to include in results
    with_payload=True,
    with_vectors=False       # Don't return vectors to save bandwidth
)
```

This query pattern returns the top 20 semantically relevant memories for a specific user with cosine similarity ≥ 0.65, typically completing in 100–300ms at P95 for a collection with up to 5B total vectors.
