# ARIA — Database Schema

## Document Information

| Field       | Value                                  |
|-------------|----------------------------------------|
| Version     | 1.0.0                                  |
| Date        | 2026-06-15                             |
| Status      | Production                             |
| Authors     | ARIA Platform Team                     |
| Reviewed By | Backend Engineering, Security          |

---

## 1. Overview

ARIA employs a **dual-database strategy** that assigns each storage concern to the engine best suited for it:

| Engine         | Role                                                       |
|----------------|------------------------------------------------------------|
| **PostgreSQL 15** | Authoritative relational store for all structured entities (users, conversations, events, tasks, travel plans, integrations, audit logs) |
| **Qdrant**      | High-performance vector store for semantic similarity search across memories, conversations, and documents |

The two databases are kept in sync at the application layer. When a memory record is written to PostgreSQL, a corresponding vector embedding is generated and upserted into Qdrant. The PostgreSQL `memories.embedding_id` column stores the Qdrant point ID so records can be cross-referenced efficiently.

### Embedding Model

All embeddings are produced by **`sentence-transformers/all-MiniLM-L6-v2`**, which outputs **384-dimensional** float32 vectors. This model was chosen for its balance of quality, inference speed (< 15 ms on CPU), and compact vector size, which keeps Qdrant memory footprint manageable.

### Redis

Redis is used as a caching and message-broker layer, not a primary database. Its responsibilities include:
- JWT denylist (revoked tokens)
- Rate-limiting counters
- Session state cache (TTL-based)
- Celery task queue for background jobs (embedding generation, calendar sync, notification dispatch)

---

## 2. Design Principles

| Principle | Implementation |
|---|---|
| **UUID primary keys** | All tables use `UUID DEFAULT uuid_generate_v4()` — avoids integer enumeration attacks and supports distributed generation |
| **Soft deletes** | User-facing tables include `deleted_at TIMESTAMPTZ` — records are hidden from application queries via `WHERE deleted_at IS NULL` but retained for audit and recovery |
| **Audit timestamps** | Every table carries `created_at` and `updated_at`, both `TIMESTAMPTZ NOT NULL DEFAULT NOW()`. `updated_at` is maintained automatically by a trigger |
| **JSONB for flexibility** | Semi-structured fields (preferences, entities, metadata, attendees) use `JSONB` for schema-free extensibility while remaining queryable with GIN indexes |
| **Encrypted sensitive columns** | Third-party OAuth tokens are stored as `BYTEA` encrypted with `pgcrypto` AES-256. The encryption key is held in AWS Secrets Manager and injected at runtime |
| **Row-level security (RLS)** | PostgreSQL RLS policies enforce that application queries can only access rows belonging to the authenticated user. The API sets `SET app.current_user_id = '<uuid>'` at the start of each connection |
| **Immutable audit log** | `audit_logs` rows are never updated or soft-deleted. A dedicated DB role with INSERT-only privileges writes to this table |
| **Check constraints over enums** | PostgreSQL `CHECK` constraints are used instead of `ENUM` types to allow non-disruptive value additions via `ALTER TABLE` |

---

## 3. PostgreSQL Schema

### 3.1 Extensions

```sql
-- UUID generation (v4 random UUIDs)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Cryptographic functions: pgp_sym_encrypt / pgp_sym_decrypt for token encryption
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Trigram-based fuzzy text search (used for full-text indexes on names, content)
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
```

> These extensions must be installed by a superuser before running migrations. In AWS RDS / Aurora PostgreSQL they are available in the `pg_available_extensions` view.

---

### 3.2 Table: `users`

```sql
CREATE TABLE users (
    id                      UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    email                   VARCHAR(255) NOT NULL,
    phone                   VARCHAR(20),
    full_name               VARCHAR(255) NOT NULL,
    display_name            VARCHAR(100),
    timezone                VARCHAR(50)  NOT NULL DEFAULT 'UTC',
    locale                  VARCHAR(10)  NOT NULL DEFAULT 'en-US',
    avatar_url              TEXT,
    subscription_tier       VARCHAR(20)  NOT NULL DEFAULT 'free'
                                CHECK (subscription_tier IN ('free', 'pro', 'enterprise')),
    subscription_expires_at TIMESTAMPTZ,
    preferences             JSONB        NOT NULL DEFAULT '{}',
    onboarding_completed    BOOLEAN      NOT NULL DEFAULT false,
    last_active_at          TIMESTAMPTZ,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    deleted_at              TIMESTAMPTZ,

    CONSTRAINT users_email_unique UNIQUE (email)
);

COMMENT ON TABLE users IS
    'Core user identity table. Soft-deleted via deleted_at. '
    'Email is the primary login credential; phone is optional for SMS channels.';

COMMENT ON COLUMN users.id IS
    'UUID v4 primary key. Never exposed in URLs without additional authorization checks.';
COMMENT ON COLUMN users.email IS
    'Unique login email. Stored lowercase (enforced by application layer and expression index).';
COMMENT ON COLUMN users.timezone IS
    'IANA timezone identifier, e.g. "America/New_York". Used when parsing and displaying '
    'all date/time values for this user.';
COMMENT ON COLUMN users.subscription_tier IS
    'Determines rate limits, AI model tier, and feature access. '
    'Values: free | pro | enterprise.';
COMMENT ON COLUMN users.preferences IS
    'Flexible JSONB bag for user preferences. Keys are namespaced, e.g. '
    '{"notifications": {"morning_briefing": true}, "ai_behavior": {"verbosity": "concise"}}.';
COMMENT ON COLUMN users.deleted_at IS
    'Non-null when user has requested account deletion. '
    'Hard deletion runs 30 days later via a scheduled job.';
```

**Preferences schema (illustrative):**

```json
{
  "notifications": {
    "morning_briefing": true,
    "morning_briefing_time": "07:30",
    "meeting_reminders": true,
    "meeting_reminder_minutes": 15,
    "task_reminders": true,
    "travel_alerts": true,
    "proactive_suggestions": true,
    "quiet_hours_enabled": false,
    "quiet_hours_start": "22:00",
    "quiet_hours_end": "07:00"
  },
  "privacy": {
    "data_retention_months": 24,
    "share_analytics": false,
    "share_crash_reports": true
  },
  "ai_behavior": {
    "verbosity": "balanced",
    "proactive_level": "medium",
    "memory_enabled": true,
    "preferred_name": "Aria"
  },
  "display": {
    "theme": "system",
    "language": "en-US",
    "date_format": "MMM d, yyyy",
    "time_format": "12h"
  }
}
```

---

### 3.3 Table: `user_sessions`

```sql
CREATE TABLE user_sessions (
    id                   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id              UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash           VARCHAR(64) NOT NULL,
    refresh_token_hash   VARCHAR(64),
    device_type          VARCHAR(20) CHECK (device_type IN ('ios', 'android', 'web')),
    device_id            VARCHAR(255),
    device_info          JSONB       NOT NULL DEFAULT '{}',
    ip_address           INET,
    user_agent           TEXT,
    is_active            BOOLEAN     NOT NULL DEFAULT true,
    expires_at           TIMESTAMPTZ NOT NULL,
    refresh_expires_at   TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at         TIMESTAMPTZ,

    CONSTRAINT user_sessions_token_hash_unique        UNIQUE (token_hash),
    CONSTRAINT user_sessions_refresh_token_hash_unique UNIQUE (refresh_token_hash)
);

COMMENT ON TABLE user_sessions IS
    'Tracks active JWT sessions. token_hash is SHA-256(access_token). '
    'Used for token revocation (denylist check) and device management.';

COMMENT ON COLUMN user_sessions.token_hash IS
    'SHA-256 hex digest of the raw JWT string. Never store the raw token.';
COMMENT ON COLUMN user_sessions.refresh_token_hash IS
    'SHA-256 hex digest of the refresh token. NULL if session was created '
    'without refresh token support (e.g. short-lived API keys).';
COMMENT ON COLUMN user_sessions.device_info IS
    'JSON metadata about the client device: '
    '{"os_version": "iOS 17.4", "app_version": "2.1.0", "model": "iPhone 15 Pro"}.';
```

---

### 3.4 Table: `memories`

```sql
CREATE TABLE memories (
    id                   UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id              UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content              TEXT         NOT NULL,
    summary              TEXT,
    category             VARCHAR(50)  NOT NULL
                             CHECK (category IN (
                                 'preference', 'fact', 'relationship',
                                 'routine', 'decision', 'event'
                             )),
    subcategory          VARCHAR(50),
    embedding_id         VARCHAR(255),
    importance_score     FLOAT        NOT NULL DEFAULT 0.5
                             CHECK (importance_score >= 0.0 AND importance_score <= 1.0),
    confidence_score     FLOAT        NOT NULL DEFAULT 1.0
                             CHECK (confidence_score >= 0.0 AND confidence_score <= 1.0),
    source               VARCHAR(50)
                             CHECK (source IN (
                                 'conversation', 'calendar', 'email', 'manual', 'inferred'
                             )),
    source_reference_id  UUID,
    tags                 TEXT[]       NOT NULL DEFAULT '{}',
    entities             JSONB        NOT NULL DEFAULT '{}',
    access_count         INTEGER      NOT NULL DEFAULT 0,
    last_accessed_at     TIMESTAMPTZ,
    expires_at           TIMESTAMPTZ,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE memories IS
    'Long-term memory store. Each row is a discrete fact or preference about the user. '
    'Vectors are stored in Qdrant; embedding_id links the two systems.';

COMMENT ON COLUMN memories.embedding_id IS
    'Qdrant point ID in the memories_vectors collection. '
    'Generated asynchronously after INSERT; NULL until embedding job completes.';
COMMENT ON COLUMN memories.importance_score IS
    '0.0 (trivial) to 1.0 (critical). Scored by Claude at extraction time. '
    'Used to rank memories when context window budget is limited.';
COMMENT ON COLUMN memories.entities IS
    'Named entities extracted from content. '
    'Example: {"people": ["Alice"], "places": ["New York"], "dates": ["2026-07-04"]}.';
COMMENT ON COLUMN memories.source_reference_id IS
    'Optional FK to the originating row (conversation, event, etc). '
    'No hard FK constraint because the source table varies.';
COMMENT ON COLUMN memories.expires_at IS
    'Memories may be given an expiry (e.g., a temporary preference). '
    'NULL means no expiry. Expired memories are excluded from retrieval by default.';
```

---

### 3.5 Table: `conversations`

```sql
CREATE TABLE conversations (
    id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title         VARCHAR(255),
    channel       VARCHAR(20) NOT NULL DEFAULT 'app'
                      CHECK (channel IN ('app', 'voice', 'sms', 'api')),
    status        VARCHAR(20) NOT NULL DEFAULT 'active'
                      CHECK (status IN ('active', 'ended', 'archived')),
    summary       TEXT,
    intent_tags   TEXT[]      NOT NULL DEFAULT '{}',
    message_count INTEGER     NOT NULL DEFAULT 0,
    token_count   INTEGER     NOT NULL DEFAULT 0,
    metadata      JSONB       NOT NULL DEFAULT '{}',
    started_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at      TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE conversations IS
    'A conversation is a bounded session of messages between the user and ARIA. '
    'Summaries and intent_tags are generated by Claude when the conversation ends.';

COMMENT ON COLUMN conversations.channel IS
    'Originating channel: app (Flutter UI), voice (Whisper STT), sms, api (external).';
COMMENT ON COLUMN conversations.token_count IS
    'Cumulative Claude API tokens consumed across all messages in this conversation. '
    'Used for billing attribution and context window management.';
COMMENT ON COLUMN conversations.metadata IS
    'Arbitrary channel-specific metadata. '
    'For voice: {"twilio_call_sid": "CA..."}. For sms: {"from_number": "+1..."}.';
```

---

### 3.6 Table: `messages`

```sql
CREATE TABLE messages (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID        NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role            VARCHAR(20) NOT NULL
                        CHECK (role IN ('user', 'assistant', 'system', 'tool')),
    content         TEXT        NOT NULL,
    content_type    VARCHAR(20) NOT NULL DEFAULT 'text'
                        CHECK (content_type IN ('text', 'audio', 'image')),
    audio_url       TEXT,
    intent          VARCHAR(100),
    entities        JSONB       NOT NULL DEFAULT '{}',
    tool_calls      JSONB,
    tool_results    JSONB,
    tokens_used     INTEGER,
    model_used      VARCHAR(100),
    latency_ms      INTEGER,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE messages IS
    'Individual message turns in a conversation. Immutable after creation — '
    'corrections create new messages, not updates.';

COMMENT ON COLUMN messages.role IS
    'Claude API role values: user, assistant, system (injected context), '
    'tool (function call result).';
COMMENT ON COLUMN messages.audio_url IS
    'S3 presigned URL or permanent URL to the source audio file when '
    'content_type = audio. Purged after 24 hours per privacy policy.';
COMMENT ON COLUMN messages.entities IS
    'Named entities extracted from message content. '
    'Example: {"dates": ["tomorrow"], "people": ["Bob"], "amounts": ["$500"]}.';
COMMENT ON COLUMN messages.tool_calls IS
    'Serialized Claude tool_use blocks from the assistant turn. '
    'Array of {id, name, input} objects.';
COMMENT ON COLUMN messages.tool_results IS
    'Serialized tool results returned to Claude. '
    'Array of {tool_use_id, content} objects.';
COMMENT ON COLUMN messages.latency_ms IS
    'End-to-end latency from request sent to Claude to full response received, '
    'in milliseconds. Used for SLA monitoring.';
```

---

### 3.7 Table: `events`

```sql
CREATE TABLE events (
    id                       UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                  UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title                    VARCHAR(500) NOT NULL,
    description              TEXT,
    location                 TEXT,
    location_coordinates     POINT,
    start_time               TIMESTAMPTZ  NOT NULL,
    end_time                 TIMESTAMPTZ  NOT NULL,
    all_day                  BOOLEAN      NOT NULL DEFAULT false,
    timezone                 VARCHAR(50),
    recurrence_rule          TEXT,
    attendees                JSONB        NOT NULL DEFAULT '[]',
    organizer_email          VARCHAR(255),
    conference_url           TEXT,
    source                   VARCHAR(50)  NOT NULL DEFAULT 'manual'
                                 CHECK (source IN (
                                     'google_calendar', 'outlook', 'manual', 'inferred'
                                 )),
    external_id              VARCHAR(500),
    external_calendar_id     VARCHAR(500),
    sync_status              VARCHAR(20)  NOT NULL DEFAULT 'synced'
                                 CHECK (sync_status IN (
                                     'synced', 'pending', 'conflict', 'error'
                                 )),
    briefing_generated       BOOLEAN      NOT NULL DEFAULT false,
    action_items_extracted   BOOLEAN      NOT NULL DEFAULT false,
    status                   VARCHAR(20)  NOT NULL DEFAULT 'confirmed'
                                 CHECK (status IN ('confirmed', 'tentative', 'cancelled')),
    created_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    deleted_at               TIMESTAMPTZ
);

COMMENT ON TABLE events IS
    'Calendar events from all sources. External events are synced from Google Calendar / '
    'Outlook via OAuth integrations. Manually created events originate from the ARIA UI.';

COMMENT ON COLUMN events.recurrence_rule IS
    'iCal RRULE string, e.g. "RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR". '
    'Recurring event instances are stored as individual rows for simplicity.';
COMMENT ON COLUMN events.attendees IS
    'JSON array of attendee objects: '
    '[{"name": "Alice Smith", "email": "alice@co.com", "status": "accepted"}].';
COMMENT ON COLUMN events.location_coordinates IS
    'PostgreSQL POINT type (longitude, latitude) for geo queries. '
    'Populated by geocoding location text asynchronously.';
COMMENT ON COLUMN events.briefing_generated IS
    'True once Claude has generated a pre-meeting briefing for this event. '
    'Briefing content is stored in the cache layer (Redis / S3).';
```

---

### 3.8 Table: `tasks`

```sql
CREATE TABLE tasks (
    id                  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title               VARCHAR(500) NOT NULL,
    description         TEXT,
    due_date            TIMESTAMPTZ,
    due_date_all_day    BOOLEAN      NOT NULL DEFAULT false,
    priority            VARCHAR(20)  NOT NULL DEFAULT 'medium'
                            CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status              VARCHAR(20)  NOT NULL DEFAULT 'pending'
                            CHECK (status IN (
                                'pending', 'in_progress', 'completed',
                                'cancelled', 'snoozed'
                            )),
    tags                TEXT[]       NOT NULL DEFAULT '{}',
    parent_task_id      UUID         REFERENCES tasks(id) ON DELETE SET NULL,
    related_event_id    UUID         REFERENCES events(id) ON DELETE SET NULL,
    source              VARCHAR(50)  NOT NULL DEFAULT 'manual'
                            CHECK (source IN (
                                'conversation', 'email', 'calendar', 'manual'
                            )),
    source_reference_id UUID,
    estimated_minutes   INTEGER,
    recurrence_rule     TEXT,
    reminder_at         TIMESTAMPTZ,
    assigned_to         UUID         REFERENCES users(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    completed_at        TIMESTAMPTZ,
    deleted_at          TIMESTAMPTZ
);

COMMENT ON TABLE tasks IS
    'Action items and to-dos. Supports parent/child hierarchy via parent_task_id '
    'for subtasks. Tasks can be linked to calendar events via related_event_id.';

COMMENT ON COLUMN tasks.parent_task_id IS
    'Self-referential FK for subtask hierarchy. '
    'Top-level tasks have parent_task_id = NULL.';
COMMENT ON COLUMN tasks.estimated_minutes IS
    'User or AI-estimated duration in minutes. Used by the scheduling assistant.';
COMMENT ON COLUMN tasks.assigned_to IS
    'Reserved for future team/shared workspace functionality. '
    'Currently always equals user_id or NULL.';
COMMENT ON COLUMN tasks.source_reference_id IS
    'Polymorphic reference to the originating entity (conversation row, email row, etc). '
    'No hard FK; application enforces referential integrity.';
```

---

### 3.9 Table: `travel_plans`

```sql
CREATE TABLE travel_plans (
    id                      UUID           PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID           NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    trip_name               VARCHAR(255)   NOT NULL,
    origin_city             VARCHAR(100),
    origin_airport_code     VARCHAR(3),
    destination_city        VARCHAR(100)   NOT NULL,
    destination_airport_code VARCHAR(3),
    departure_date          DATE           NOT NULL,
    return_date             DATE,
    status                  VARCHAR(20)    NOT NULL DEFAULT 'planning'
                                CHECK (status IN (
                                    'planning', 'booked', 'active',
                                    'completed', 'cancelled'
                                )),
    purpose                 VARCHAR(50)
                                CHECK (purpose IN ('business', 'leisure', 'mixed')),
    travelers               INTEGER        NOT NULL DEFAULT 1
                                CHECK (travelers >= 1),
    budget_currency         VARCHAR(3)     NOT NULL DEFAULT 'USD',
    budget_amount           DECIMAL(10,2),
    itinerary               JSONB          NOT NULL DEFAULT '[]',
    flights                 JSONB          NOT NULL DEFAULT '[]',
    hotels                  JSONB          NOT NULL DEFAULT '[]',
    notes                   TEXT,
    monitoring_enabled      BOOLEAN        NOT NULL DEFAULT true,
    created_at              TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    deleted_at              TIMESTAMPTZ
);

COMMENT ON TABLE travel_plans IS
    'End-to-end trip records. itinerary, flights, and hotels are JSONB arrays '
    'rather than child tables to allow flexible, evolving schema without migrations.';

COMMENT ON COLUMN travel_plans.itinerary IS
    'Day-by-day activity plan. Example element: '
    '{"date": "2026-07-10", "activities": [{"time": "10:00", "description": "Museum visit", "location": "MoMA"}]}.';
COMMENT ON COLUMN travel_plans.flights IS
    'Booked flight segments. Example element: '
    '{"airline": "Delta", "flight_number": "DL401", "departure": "2026-07-10T08:00:00Z", '
    '"arrival": "2026-07-10T11:30:00Z", "origin": "JFK", "destination": "LAX", '
    '"confirmation_code": "ABC123", "class": "economy"}.';
COMMENT ON COLUMN travel_plans.hotels IS
    'Booked accommodations. Example element: '
    '{"name": "The Standard", "address": "848 Washington St, New York, NY", '
    '"check_in": "2026-07-10", "check_out": "2026-07-13", '
    '"confirmation_code": "HTL987", "nightly_rate": 289.00, "currency": "USD"}.';
COMMENT ON COLUMN travel_plans.monitoring_enabled IS
    'When true, ARIA actively monitors for flight delays, weather disruptions, '
    'and gate changes, and sends proactive alerts.';
```

---

### 3.10 Table: `integrations`

```sql
CREATE TABLE integrations (
    id                      UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider                VARCHAR(50) NOT NULL
                                CHECK (provider IN (
                                    'google_calendar', 'outlook', 'gmail',
                                    'slack', 'notion', 'github'
                                )),
    provider_user_id        VARCHAR(255),
    provider_email          VARCHAR(255),
    access_token_encrypted  BYTEA       NOT NULL,
    refresh_token_encrypted BYTEA,
    token_type              VARCHAR(50) NOT NULL DEFAULT 'Bearer',
    scopes                  TEXT[]      NOT NULL DEFAULT '{}',
    expires_at              TIMESTAMPTZ,
    is_active               BOOLEAN     NOT NULL DEFAULT true,
    sync_enabled            BOOLEAN     NOT NULL DEFAULT true,
    last_sync_at            TIMESTAMPTZ,
    last_sync_status        VARCHAR(20)
                                CHECK (last_sync_status IN (
                                    'success', 'partial', 'failed', 'running'
                                )),
    sync_error              TEXT,
    metadata                JSONB       NOT NULL DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT integrations_user_provider_unique UNIQUE (user_id, provider)
);

COMMENT ON TABLE integrations IS
    'OAuth 2.0 integration credentials for third-party services. '
    'Tokens are encrypted at rest using pgcrypto AES-256 with a key from AWS Secrets Manager.';

COMMENT ON COLUMN integrations.access_token_encrypted IS
    'AES-256 encrypted OAuth access token. '
    'Decrypt with: pgp_sym_decrypt(access_token_encrypted, :encryption_key).';
COMMENT ON COLUMN integrations.scopes IS
    'OAuth scopes granted by the user. '
    'Example: ["https://www.googleapis.com/auth/calendar.readonly", '
    '"https://www.googleapis.com/auth/calendar.events"].';
COMMENT ON COLUMN integrations.provider_user_id IS
    'User identifier from the external provider (e.g., Google sub claim). '
    'Used to detect re-connection of the same external account.';
```

---

### 3.11 Table: `permissions`

```sql
CREATE TABLE permissions (
    id               UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permission_type  VARCHAR(50) NOT NULL
                         CHECK (permission_type IN (
                             'calendar_read', 'calendar_write', 'contacts_read',
                             'location', 'microphone', 'camera',
                             'notifications', 'background_refresh'
                         )),
    platform         VARCHAR(20) NOT NULL
                         CHECK (platform IN ('ios', 'android', 'web')),
    status           VARCHAR(20) NOT NULL DEFAULT 'not_requested'
                         CHECK (status IN (
                             'granted', 'denied', 'not_requested', 'restricted'
                         )),
    granted_at       TIMESTAMPTZ,
    denied_at        TIMESTAMPTZ,
    last_checked_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT permissions_user_type_platform_unique
        UNIQUE (user_id, permission_type, platform)
);

COMMENT ON TABLE permissions IS
    'Device permission states as reported by the mobile client. '
    'The app updates these rows after each OS permission prompt result. '
    'ARIA uses this to decide whether to prompt the user to grant a permission '
    'before attempting a feature that requires it.';

COMMENT ON COLUMN permissions.status IS
    'granted: user approved. denied: user declined. '
    'not_requested: ARIA has not yet asked. restricted: OS policy prevents granting '
    '(e.g., parental controls on iOS).';
```

---

### 3.12 Table: `notifications`

```sql
CREATE TABLE notifications (
    id                   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id              UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type                 VARCHAR(50) NOT NULL
                             CHECK (type IN (
                                 'meeting_reminder', 'travel_alert', 'task_due',
                                 'morning_briefing', 'action_item',
                                 'proactive_suggestion', 'system'
                             )),
    title                VARCHAR(255) NOT NULL,
    body                 TEXT        NOT NULL,
    data                 JSONB       NOT NULL DEFAULT '{}',
    priority             VARCHAR(20) NOT NULL DEFAULT 'normal'
                             CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    channel              VARCHAR(20) NOT NULL DEFAULT 'push'
                             CHECK (channel IN ('push', 'in_app', 'sms', 'email')),
    scheduled_for        TIMESTAMPTZ,
    sent_at              TIMESTAMPTZ,
    delivered_at         TIMESTAMPTZ,
    read_at              TIMESTAMPTZ,
    dismissed_at         TIMESTAMPTZ,
    related_entity_type  VARCHAR(50)
                             CHECK (related_entity_type IN (
                                 'event', 'task', 'travel_plan', 'memory'
                             )),
    related_entity_id    UUID,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE notifications IS
    'All outbound notifications sent or scheduled for users. '
    'Tracks full delivery lifecycle: scheduled → sent → delivered → read/dismissed.';

COMMENT ON COLUMN notifications.data IS
    'Channel-specific payload. For push: {"apns_category": "MEETING_REMINDER", "event_id": "..."}. '
    'For sms: {"to": "+1...", "twilio_sid": "SM..."}.';
COMMENT ON COLUMN notifications.related_entity_type IS
    'Polymorphic entity type for deep linking. '
    'The app uses this + related_entity_id to navigate on tap.';
```

---

### 3.13 Table: `audit_logs`

```sql
CREATE TABLE audit_logs (
    id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id      UUID        REFERENCES users(id) ON DELETE SET NULL,
    action       VARCHAR(100) NOT NULL,
    entity_type  VARCHAR(50),
    entity_id    UUID,
    details      JSONB       NOT NULL DEFAULT '{}',
    ip_address   INET,
    user_agent   TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE audit_logs IS
    'Immutable audit trail for security-sensitive actions. '
    'Written by a dedicated DB role with INSERT-only privileges on this table. '
    'No UPDATE or DELETE is permitted at the database level for compliance.';

COMMENT ON COLUMN audit_logs.action IS
    'Predefined action codes. Examples: '
    'data_export, data_delete, integration_connect, integration_disconnect, '
    'permission_grant, password_change, login_success, login_failure, '
    'subscription_change, api_key_create, api_key_revoke.';
COMMENT ON COLUMN audit_logs.details IS
    'Action-specific metadata. '
    'For data_export: {"exported_entities": ["memories", "conversations"], "format": "json"}. '
    'For login_failure: {"reason": "invalid_password", "attempts": 3}.';
```

---

## 4. Indexes

```sql
-- ============================================================
-- users
-- ============================================================
CREATE UNIQUE INDEX idx_users_email_lower
    ON users (LOWER(email))
    WHERE deleted_at IS NULL;

CREATE INDEX idx_users_subscription_tier
    ON users (subscription_tier)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_users_last_active_at
    ON users (last_active_at DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_users_deleted_at
    ON users (deleted_at)
    WHERE deleted_at IS NOT NULL;

-- GIN index for JSONB preference queries
CREATE INDEX idx_users_preferences_gin
    ON users USING GIN (preferences);


-- ============================================================
-- user_sessions
-- ============================================================
CREATE INDEX idx_user_sessions_user_id
    ON user_sessions (user_id);

CREATE INDEX idx_user_sessions_token_hash
    ON user_sessions (token_hash)
    WHERE is_active = true;

CREATE INDEX idx_user_sessions_refresh_token_hash
    ON user_sessions (refresh_token_hash)
    WHERE is_active = true AND refresh_token_hash IS NOT NULL;

-- Composite: find active sessions by user + device
CREATE INDEX idx_user_sessions_user_device
    ON user_sessions (user_id, device_id)
    WHERE is_active = true;

CREATE INDEX idx_user_sessions_expires_at
    ON user_sessions (expires_at)
    WHERE is_active = true;


-- ============================================================
-- memories
-- ============================================================
CREATE INDEX idx_memories_user_id
    ON memories (user_id);

CREATE INDEX idx_memories_user_category
    ON memories (user_id, category);

-- Partial index for non-expired memories (most common query pattern)
CREATE INDEX idx_memories_user_active
    ON memories (user_id, importance_score DESC, created_at DESC)
    WHERE expires_at IS NULL OR expires_at > NOW();

CREATE INDEX idx_memories_embedding_id
    ON memories (embedding_id)
    WHERE embedding_id IS NOT NULL;

CREATE INDEX idx_memories_source
    ON memories (user_id, source)
    WHERE source IS NOT NULL;

-- GIN index for tags array
CREATE INDEX idx_memories_tags_gin
    ON memories USING GIN (tags);

-- GIN index for entities JSONB
CREATE INDEX idx_memories_entities_gin
    ON memories USING GIN (entities);

-- Trigram index for fuzzy content search
CREATE INDEX idx_memories_content_trgm
    ON memories USING GIN (content gin_trgm_ops);

CREATE INDEX idx_memories_last_accessed_at
    ON memories (user_id, last_accessed_at DESC NULLS LAST);


-- ============================================================
-- conversations
-- ============================================================
CREATE INDEX idx_conversations_user_id
    ON conversations (user_id);

CREATE INDEX idx_conversations_user_status
    ON conversations (user_id, status);

-- Most recent conversations first
CREATE INDEX idx_conversations_user_started_at
    ON conversations (user_id, started_at DESC);

CREATE INDEX idx_conversations_channel
    ON conversations (user_id, channel);

-- GIN index for intent_tags array
CREATE INDEX idx_conversations_intent_tags_gin
    ON conversations USING GIN (intent_tags);


-- ============================================================
-- messages
-- ============================================================
CREATE INDEX idx_messages_conversation_id
    ON messages (conversation_id);

CREATE INDEX idx_messages_user_id
    ON messages (user_id);

-- Chronological retrieval within conversation
CREATE INDEX idx_messages_conversation_created
    ON messages (conversation_id, created_at ASC);

CREATE INDEX idx_messages_role
    ON messages (conversation_id, role);

-- GIN indexes for JSONB columns
CREATE INDEX idx_messages_entities_gin
    ON messages USING GIN (entities);

CREATE INDEX idx_messages_tool_calls_gin
    ON messages USING GIN (tool_calls)
    WHERE tool_calls IS NOT NULL;

-- Trigram for content search
CREATE INDEX idx_messages_content_trgm
    ON messages USING GIN (content gin_trgm_ops);


-- ============================================================
-- events
-- ============================================================
CREATE INDEX idx_events_user_id
    ON events (user_id)
    WHERE deleted_at IS NULL;

-- Time-range queries (most common access pattern)
CREATE INDEX idx_events_user_time_range
    ON events (user_id, start_time ASC, end_time ASC)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_events_start_time
    ON events (start_time)
    WHERE deleted_at IS NULL AND status != 'cancelled';

-- External ID lookup for sync deduplication
CREATE INDEX idx_events_external_id
    ON events (external_id, external_calendar_id)
    WHERE external_id IS NOT NULL;

CREATE INDEX idx_events_source
    ON events (user_id, source)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_events_briefing_pending
    ON events (user_id, start_time)
    WHERE briefing_generated = false
      AND deleted_at IS NULL
      AND status = 'confirmed';

-- GIN index on attendees JSONB
CREATE INDEX idx_events_attendees_gin
    ON events USING GIN (attendees);

-- Trigram on title for search
CREATE INDEX idx_events_title_trgm
    ON events USING GIN (title gin_trgm_ops);


-- ============================================================
-- tasks
-- ============================================================
CREATE INDEX idx_tasks_user_id
    ON tasks (user_id)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_tasks_user_status
    ON tasks (user_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_tasks_user_due_date
    ON tasks (user_id, due_date ASC NULLS LAST)
    WHERE deleted_at IS NULL AND status NOT IN ('completed', 'cancelled');

CREATE INDEX idx_tasks_user_priority
    ON tasks (user_id, priority, due_date ASC NULLS LAST)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_tasks_parent_task_id
    ON tasks (parent_task_id)
    WHERE parent_task_id IS NOT NULL;

CREATE INDEX idx_tasks_related_event_id
    ON tasks (related_event_id)
    WHERE related_event_id IS NOT NULL;

-- Overdue tasks: status=pending + due_date in the past
CREATE INDEX idx_tasks_overdue
    ON tasks (user_id, due_date)
    WHERE status IN ('pending', 'in_progress')
      AND due_date IS NOT NULL
      AND deleted_at IS NULL;

-- GIN for tags
CREATE INDEX idx_tasks_tags_gin
    ON tasks USING GIN (tags);


-- ============================================================
-- travel_plans
-- ============================================================
CREATE INDEX idx_travel_plans_user_id
    ON travel_plans (user_id)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_travel_plans_user_status
    ON travel_plans (user_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_travel_plans_departure_date
    ON travel_plans (user_id, departure_date)
    WHERE deleted_at IS NULL;

-- Active trips with monitoring enabled
CREATE INDEX idx_travel_plans_monitoring
    ON travel_plans (departure_date, return_date)
    WHERE monitoring_enabled = true
      AND status IN ('booked', 'active')
      AND deleted_at IS NULL;


-- ============================================================
-- integrations
-- ============================================================
CREATE INDEX idx_integrations_user_id
    ON integrations (user_id);

CREATE INDEX idx_integrations_provider
    ON integrations (provider)
    WHERE is_active = true;

-- Sync scheduler: find integrations due for sync
CREATE INDEX idx_integrations_last_sync_at
    ON integrations (last_sync_at ASC NULLS FIRST)
    WHERE is_active = true AND sync_enabled = true;


-- ============================================================
-- permissions
-- ============================================================
CREATE INDEX idx_permissions_user_id
    ON permissions (user_id);

CREATE INDEX idx_permissions_user_type_platform
    ON permissions (user_id, permission_type, platform);


-- ============================================================
-- notifications
-- ============================================================
CREATE INDEX idx_notifications_user_id
    ON notifications (user_id);

CREATE INDEX idx_notifications_user_read
    ON notifications (user_id, created_at DESC)
    WHERE read_at IS NULL;

CREATE INDEX idx_notifications_scheduled
    ON notifications (scheduled_for)
    WHERE sent_at IS NULL AND scheduled_for IS NOT NULL;

CREATE INDEX idx_notifications_user_type
    ON notifications (user_id, type, created_at DESC);

CREATE INDEX idx_notifications_related_entity
    ON notifications (related_entity_type, related_entity_id)
    WHERE related_entity_id IS NOT NULL;


-- ============================================================
-- audit_logs
-- ============================================================
CREATE INDEX idx_audit_logs_user_id
    ON audit_logs (user_id);

CREATE INDEX idx_audit_logs_action
    ON audit_logs (action, created_at DESC);

CREATE INDEX idx_audit_logs_entity
    ON audit_logs (entity_type, entity_id)
    WHERE entity_id IS NOT NULL;

CREATE INDEX idx_audit_logs_created_at
    ON audit_logs (created_at DESC);
```

---

## 5. Foreign Key Relationships

### 5.1 Relationship Summary

| Parent Table    | Child Table       | FK Column(s)                        | Cardinality | On Delete        |
|-----------------|-------------------|-------------------------------------|-------------|------------------|
| `users`         | `user_sessions`   | `user_id`                           | 1 : many    | CASCADE          |
| `users`         | `memories`        | `user_id`                           | 1 : many    | CASCADE          |
| `users`         | `conversations`   | `user_id`                           | 1 : many    | CASCADE          |
| `conversations` | `messages`        | `conversation_id`                   | 1 : many    | CASCADE          |
| `users`         | `messages`        | `user_id`                           | 1 : many    | CASCADE          |
| `users`         | `events`          | `user_id`                           | 1 : many    | CASCADE          |
| `users`         | `tasks`           | `user_id`                           | 1 : many    | CASCADE          |
| `tasks`         | `tasks`           | `parent_task_id`                    | 0..1 : many | SET NULL         |
| `events`        | `tasks`           | `related_event_id`                  | 0..1 : many | SET NULL         |
| `users`         | `travel_plans`    | `user_id`                           | 1 : many    | CASCADE          |
| `users`         | `integrations`    | `user_id`                           | 1 : many    | CASCADE          |
| `users`         | `permissions`     | `user_id`                           | 1 : many    | CASCADE          |
| `users`         | `notifications`   | `user_id`                           | 1 : many    | CASCADE          |
| `users`         | `audit_logs`      | `user_id`                           | 1 : many    | SET NULL         |

### 5.2 Entity Relationship Diagram (ASCII)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                  users                                      │
│  id (PK) | email | full_name | subscription_tier | preferences | ...        │
└──────────────────────────────────┬──────────────────────────────────────────┘
           │ 1                     │ 1
           │                       │
    ┌──────┴─────┐          ┌──────┴──────┐
    │            │          │             │
   many         many       many          many
    │            │          │             │
    ▼            ▼          ▼             ▼
┌───────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐
│user_      │ │memories  │ │events    │ │tasks         │
│sessions   │ │          │ │          │ │              │
└───────────┘ └──────────┘ └────┬─────┘ └──┬───────────┘
                                │           │ parent_task_id
                                │           │ (self-ref)
                                │       ┌───┘
                                │       │ 0..1 : many
                                │       ▼
                                │  ┌──────────┐
                                │  │  tasks   │ (subtasks)
                                │  └──────────┘
                                │
           ┌────────────────────┼────────────────────┐
           │                    │                    │
          many                 many                 many
           │                    │                    │
           ▼                    ▼                    ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐
│  conversations   │  │  travel_plans    │  │ integrations │
│                  │  └──────────────────┘  └──────────────┘
└────────┬─────────┘
         │ 1
         │
        many
         │
         ▼
┌──────────────────┐
│    messages      │
└──────────────────┘

           users ─── 1:many ──► permissions
           users ─── 1:many ──► notifications
           users ─── 1:many ──► audit_logs
```

---

## 6. Triggers & Functions

### 6.1 Auto-Update `updated_at` Trigger

Applied to all tables with an `updated_at` column to ensure it is always current.

```sql
-- Reusable trigger function
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all relevant tables
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_user_sessions_updated_at
    BEFORE UPDATE ON user_sessions
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_memories_updated_at
    BEFORE UPDATE ON memories
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_conversations_updated_at
    BEFORE UPDATE ON conversations
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_events_updated_at
    BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_tasks_updated_at
    BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_travel_plans_updated_at
    BEFORE UPDATE ON travel_plans
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_integrations_updated_at
    BEFORE UPDATE ON integrations
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
```

---

### 6.2 Soft-Delete Cascade

When a user is soft-deleted (i.e., `deleted_at` is set to a non-null timestamp), this function propagates the soft delete to all user-owned entities that support it. Hard-delete child tables (like `user_sessions`) are cleared immediately via their `ON DELETE CASCADE` constraints once the hard delete runs after the retention period.

```sql
CREATE OR REPLACE FUNCTION fn_cascade_user_soft_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- Only trigger when deleted_at transitions from NULL to a value
    IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN

        UPDATE memories
           SET deleted_at = NEW.deleted_at
         WHERE user_id = NEW.id
           AND deleted_at IS NULL;

        UPDATE events
           SET deleted_at = NEW.deleted_at
         WHERE user_id = NEW.id
           AND deleted_at IS NULL;

        UPDATE tasks
           SET deleted_at = NEW.deleted_at
         WHERE user_id = NEW.id
           AND deleted_at IS NULL;

        UPDATE travel_plans
           SET deleted_at = NEW.deleted_at
         WHERE user_id = NEW.id
           AND deleted_at IS NULL;

        -- Deactivate all sessions immediately
        UPDATE user_sessions
           SET is_active = false
         WHERE user_id = NEW.id
           AND is_active = true;

        -- Deactivate all integrations
        UPDATE integrations
           SET is_active = false,
               sync_enabled = false
         WHERE user_id = NEW.id;

        -- Log the cascade
        INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details)
        VALUES (
            NEW.id,
            'data_delete',
            'user',
            NEW.id,
            jsonb_build_object(
                'trigger', 'soft_delete_cascade',
                'scheduled_hard_delete_at', NEW.deleted_at + INTERVAL '30 days'
            )
        );

    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_soft_delete_cascade
    AFTER UPDATE OF deleted_at ON users
    FOR EACH ROW
    EXECUTE FUNCTION fn_cascade_user_soft_delete();
```

---

### 6.3 Conversation Message Count

Automatically increments `conversations.message_count` and accumulates `token_count` on every new message insert, keeping the aggregate columns current without requiring a separate UPDATE statement from the application.

```sql
CREATE OR REPLACE FUNCTION fn_update_conversation_counts()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE conversations
       SET message_count = message_count + 1,
           token_count   = token_count + COALESCE(NEW.tokens_used, 0),
           updated_at    = NOW()
     WHERE id = NEW.conversation_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_messages_update_conversation_counts
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_conversation_counts();
```

---

### 6.4 Memory Access Tracking

Updates `memories.access_count` and `last_accessed_at` whenever a memory is read by the retrieval system. This is called via a stored procedure from the application rather than a row-level trigger, to avoid write amplification on every SELECT.

```sql
CREATE OR REPLACE PROCEDURE proc_record_memory_access(
    p_memory_ids UUID[]
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE memories
       SET access_count    = access_count + 1,
           last_accessed_at = NOW()
     WHERE id = ANY(p_memory_ids);
END;
$$;
```

---

## 7. Qdrant Vector Collections

All Qdrant collections use **HNSW** (Hierarchical Navigable Small World) indexing with the default parameters (`m=16`, `ef_construct=100`), which provide an optimal balance of recall and query latency for ARIA's dataset sizes.

### 7.1 Collection: `memories_vectors`

This is the primary semantic memory store. Every memory inserted into PostgreSQL gets an embedding generated here.

```json
{
  "name": "memories_vectors",
  "vectors": {
    "size": 384,
    "distance": "Cosine",
    "hnsw_config": {
      "m": 16,
      "ef_construct": 100,
      "full_scan_threshold": 10000
    },
    "quantization_config": {
      "scalar": {
        "type": "int8",
        "quantile": 0.99,
        "always_ram": true
      }
    }
  },
  "payload_schema": {
    "user_id": { "data_type": "keyword", "indexed": true },
    "memory_id": { "data_type": "keyword", "indexed": true },
    "category": { "data_type": "keyword", "indexed": true },
    "subcategory": { "data_type": "keyword", "indexed": true },
    "importance_score": { "data_type": "float", "indexed": true },
    "tags": { "data_type": "keyword[]", "indexed": true },
    "source": { "data_type": "keyword", "indexed": true },
    "created_at": { "data_type": "datetime", "indexed": true },
    "expires_at": { "data_type": "datetime", "indexed": true }
  },
  "optimizers_config": {
    "default_segment_number": 4,
    "max_segment_size": 200000,
    "memmap_threshold": 100000,
    "indexing_threshold": 20000
  },
  "replication_factor": 2,
  "write_consistency_factor": 1
}
```

**Payload Fields:**

| Field            | Type       | Description                                                                     |
|------------------|------------|---------------------------------------------------------------------------------|
| `user_id`        | keyword    | Must always be present in every query filter — enforces user data isolation     |
| `memory_id`      | keyword    | UUID of the corresponding `memories` row in PostgreSQL                          |
| `category`       | keyword    | Memory category for pre-filtering before vector search                          |
| `subcategory`    | keyword    | Optional finer-grained category                                                 |
| `importance_score` | float    | Enables boosting or filtering by importance (e.g., `>= 0.6`)                   |
| `tags`           | keyword[]  | User-assigned and AI-extracted tags; multi-value keyword filter                 |
| `source`         | keyword    | Origin of the memory (conversation, calendar, etc.)                             |
| `created_at`     | datetime   | ISO 8601 timestamp; used for recency-weighted retrieval                         |
| `expires_at`     | datetime   | ISO 8601 timestamp; `null` for permanent memories; filtered at query time       |

**Canonical Query Pattern:**

```python
from qdrant_client.models import Filter, FieldCondition, MatchValue, Range
from datetime import datetime, timezone

results = client.search(
    collection_name="memories_vectors",
    query_vector=embedding,          # 384-dim float32 array
    query_filter=Filter(
        must=[
            FieldCondition(
                key="user_id",
                match=MatchValue(value=str(user_id))
            )
        ],
        should=[
            FieldCondition(
                key="category",
                match=MatchValue(value="preference")
            )
        ],
        must_not=[
            FieldCondition(
                key="expires_at",
                range=Range(lt=datetime.now(timezone.utc).isoformat())
            )
        ]
    ),
    limit=10,
    score_threshold=0.70,
    with_payload=True
)
```

> **Security rule:** `user_id` MUST be present in the `must` filter on every query without exception. Omitting this filter would allow cross-user memory leakage.

---

### 7.2 Collection: `conversation_embeddings`

Stores sentence-level embeddings of conversation summaries, enabling ARIA to retrieve relevant prior conversations when answering follow-up questions.

```json
{
  "name": "conversation_embeddings",
  "vectors": {
    "size": 384,
    "distance": "Cosine",
    "hnsw_config": {
      "m": 16,
      "ef_construct": 100
    }
  },
  "payload_schema": {
    "user_id": { "data_type": "keyword", "indexed": true },
    "conversation_id": { "data_type": "keyword", "indexed": true },
    "channel": { "data_type": "keyword", "indexed": true },
    "intent_tags": { "data_type": "keyword[]", "indexed": true },
    "started_at": { "data_type": "datetime", "indexed": true },
    "ended_at": { "data_type": "datetime", "indexed": true },
    "message_count": { "data_type": "integer", "indexed": false }
  }
}
```

**Usage:** Embeddings are generated from the conversation `summary` field when a conversation transitions to `status = 'ended'`. This index is queried when the user asks ARIA to recall prior discussions: *"What did we talk about regarding my trip to Tokyo?"*

---

### 7.3 Collection: `document_embeddings`

Stores chunk-level embeddings of indexed documents (email attachments, manually uploaded files, shared documents). Documents are split into overlapping chunks of ~512 tokens with a 64-token overlap before embedding.

```json
{
  "name": "document_embeddings",
  "vectors": {
    "size": 384,
    "distance": "Cosine",
    "hnsw_config": {
      "m": 32,
      "ef_construct": 200
    }
  },
  "payload_schema": {
    "user_id": { "data_type": "keyword", "indexed": true },
    "document_id": { "data_type": "keyword", "indexed": true },
    "document_type": { "data_type": "keyword", "indexed": true },
    "source": { "data_type": "keyword", "indexed": true },
    "filename": { "data_type": "keyword", "indexed": false },
    "chunk_index": { "data_type": "integer", "indexed": false },
    "total_chunks": { "data_type": "integer", "indexed": false },
    "page_number": { "data_type": "integer", "indexed": false },
    "created_at": { "data_type": "datetime", "indexed": true }
  }
}
```

**Payload Fields:**

| Field          | Type      | Description                                                               |
|----------------|-----------|---------------------------------------------------------------------------|
| `user_id`      | keyword   | Mandatory isolation filter                                                |
| `document_id`  | keyword   | Logical document grouper; all chunks share the same document_id           |
| `document_type`| keyword   | `pdf`, `docx`, `txt`, `email`, `spreadsheet`                              |
| `source`       | keyword   | `gmail`, `outlook`, `manual_upload`, `slack`                              |
| `chunk_index`  | integer   | Zero-based chunk index within the document                                |
| `total_chunks` | integer   | Total chunks for this document (enables "is this the last chunk?" checks) |
| `page_number`  | integer   | Source page for PDFs; null for plain text                                 |
| `created_at`   | datetime  | When the document was indexed                                             |

> `m=32` and `ef_construct=200` are set higher than the other collections because document chunks tend to be more numerous and query recall is more critical for document QA.

---

## 8. Data Retention Policies

| Data Type          | Retention Period                       | Deletion Method                                     | Compliance Basis                       |
|--------------------|----------------------------------------|-----------------------------------------------------|----------------------------------------|
| User accounts      | Active + 30 days after deletion request | Soft delete → scheduled hard delete job             | GDPR Art. 17 (right to erasure)        |
| Messages           | 24 months (configurable by user)       | Soft delete → batch hard delete after period        | GDPR data minimisation principle       |
| Memories           | Indefinite (user-controlled)           | User-initiated delete via API or app                | User consent; privacy by design        |
| Conversations      | 24 months (configurable by user)       | Soft delete → batch hard delete after period        | GDPR data minimisation principle       |
| Events             | 12 months after event end_time         | Soft delete → scheduled hard delete job             | User expectation; storage efficiency   |
| Tasks              | 12 months after completed_at / deleted_at | Soft delete → scheduled hard delete job          | User expectation; storage efficiency   |
| Travel plans       | 6 months after return_date             | Soft delete → scheduled hard delete job             | Storage efficiency                     |
| Integration tokens | Immediately on disconnect              | Hard delete (encrypted BYTEA wiped)                 | Security best practice                 |
| Audit logs         | 7 years                                | Hard delete after retention period via batch job    | Legal/compliance (SOX, GDPR Art. 30)   |
| User sessions      | 30 days after expires_at               | Automated cleanup job (DELETE WHERE expires_at < NOW() - 30d) | Security                     |
| Notifications      | 90 days                                | Automated cleanup job                               | Storage management                     |
| Voice recordings   | 24 hours                               | Automated S3 lifecycle rule (ExpireObjects)         | Privacy by design                      |
| Vector embeddings  | Mirrors PostgreSQL row lifecycle        | Deleted from Qdrant when PostgreSQL row is hard-deleted | Consistency                        |

### Retention Job Schedule

```
Data cleanup jobs run via Celery Beat:

- sessions_cleanup          → runs every 6 hours
- notifications_cleanup     → runs daily at 02:00 UTC
- voice_recordings_purge    → S3 lifecycle policy (no job needed)
- messages_retention_check  → runs weekly at 03:00 UTC Sunday
- user_hard_delete_job      → runs daily at 04:00 UTC
  (picks up users where deleted_at < NOW() - 30 days)
- audit_log_archival        → runs monthly, first Sunday at 05:00 UTC
  (archives rows older than 7 years to S3 Glacier, then hard-deletes)
```

---

## 9. Migration Strategy

### 9.1 Tool

ARIA uses **Alembic** (SQLAlchemy's migration framework) for all schema changes against PostgreSQL. Qdrant collection management is handled by a separate initialization script (`scripts/qdrant_init.py`) since Qdrant does not have a standard migration tool.

### 9.2 Naming Conventions

Migration files follow the pattern:

```
alembic/versions/{timestamp}_{snake_case_description}.py
```

Examples:
```
alembic/versions/20260101_120000_initial_schema.py
alembic/versions/20260215_090000_add_travel_monitoring_flag.py
alembic/versions/20260301_140000_add_messages_intent_column.py
```

### 9.3 Migration Rules

| Rule | Description |
|------|-------------|
| **One concern per migration** | Each migration file addresses a single logical change (new table, new column, new index) |
| **Always write downgrade()** | Every migration must have a working `downgrade()` function that fully reverses the change |
| **No data migrations in DDL migrations** | Data backfills are separate migration files clearly named `_backfill_` |
| **Test in staging first** | All migrations run against a production-snapshot database in staging before deploying to production |
| **Lock-safe operations** | For large tables, use `ADD COLUMN ... DEFAULT NULL` then backfill, never `ADD COLUMN ... DEFAULT value NOT NULL` on a live table |
| **Index creation** | Use `CREATE INDEX CONCURRENTLY` to avoid table locks in production |

### 9.4 Deployment Process

```
1. Generate migration:
   alembic revision --autogenerate -m "description"

2. Review generated file — do NOT trust autogenerate blindly.

3. Run in staging:
   alembic upgrade head

4. Verify schema state:
   alembic current
   alembic check

5. Run in production (maintenance window for large changes):
   alembic upgrade head

6. Rollback (if needed):
   alembic downgrade -1
```

### 9.5 Baseline

The initial migration (`20260101_120000_initial_schema.py`) contains the full schema including all extensions, tables, indexes, and triggers as defined in this document. Subsequent migrations are incremental.
