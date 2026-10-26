# ARIA — API Specification

## Document Information

| Field       | Value                                  |
|-------------|----------------------------------------|
| Version     | 1.0.0                                  |
| Date        | 2026-06-15                             |
| Status      | Production                             |
| Authors     | ARIA Platform Team                     |
| Reviewed By | Backend Engineering, Security, Product |

---

## 1. Overview

The ARIA REST API is the single communication layer between all client surfaces (Flutter mobile app, web dashboard, third-party integrations) and the ARIA backend. All AI reasoning, memory retrieval, calendar sync, and task management flows through this API.

| Property           | Value                          |
|--------------------|--------------------------------|
| **Base URL**       | `https://api.aria.ai/v1`       |
| **Protocol**       | HTTPS only (TLS 1.2+)          |
| **Content-Type**   | `application/json`             |
| **Character Encoding** | UTF-8                      |
| **API Versioning** | URI path prefix (`/v1`, `/v2`) |

### API Versioning Strategy

ARIA uses **URI path versioning**. The current stable version is `v1`. When breaking changes are introduced, a new version prefix is released (`/v2`) and the previous version is supported for a minimum of 12 months with a published deprecation notice. Non-breaking additions (new optional fields, new endpoints) are rolled into the existing version without a version bump.

Clients should always pin to an explicit version prefix and monitor the `Deprecation` and `Sunset` response headers.

---

## 2. Authentication

### 2.1 JWT Bearer Tokens

ARIA uses short-lived **access tokens** paired with long-lived **refresh tokens**. This limits the blast radius of a stolen token while keeping the user experience seamless.

| Token Type    | Lifetime | Storage (client) |
|---------------|----------|------------------|
| Access token  | 30 minutes | In-memory only (never persisted to disk) |
| Refresh token | 30 days  | Secure storage (iOS Keychain / Android Keystore) |

The access token is a signed **JWT (RS256)**. It contains the following claims:

```json
{
  "sub": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "tier": "pro",
  "iat": 1750000000,
  "exp": 1750001800,
  "jti": "a1b2c3d4-..."
}
```

**Authorization header format:**

```
Authorization: Bearer <access_token>
```

All endpoints marked **Auth Required: Yes** must include this header. Requests without it, or with an invalid/expired token, receive `401 UNAUTHORIZED`.

### 2.2 Authentication Flow Diagram

```
┌─────────┐                              ┌─────────────┐
│  Client │                              │  ARIA API   │
└────┬────┘                              └──────┬──────┘
     │                                          │
     │  POST /auth/login                        │
     │  { email, password }                     │
     │ ───────────────────────────────────────► │
     │                                          │
     │  200 OK                                  │
     │  { access_token (30m),                   │
     │    refresh_token (30d) }                 │
     │ ◄─────────────────────────────────────── │
     │                                          │
     │  GET /some-endpoint                      │
     │  Authorization: Bearer <access_token>    │
     │ ───────────────────────────────────────► │
     │                                          │
     │  200 OK { data: ... }                    │
     │ ◄─────────────────────────────────────── │
     │                                          │
     │  [30 minutes later — token expires]      │
     │                                          │
     │  GET /some-endpoint                      │
     │  Authorization: Bearer <expired_token>   │
     │ ───────────────────────────────────────► │
     │                                          │
     │  401 TOKEN_EXPIRED                       │
     │ ◄─────────────────────────────────────── │
     │                                          │
     │  POST /auth/refresh                      │
     │  { refresh_token }                       │
     │ ───────────────────────────────────────► │
     │                                          │
     │  200 OK                                  │
     │  { access_token (new, 30m),              │
     │    refresh_token (rotated, 30d) }        │
     │ ◄─────────────────────────────────────── │
     │                                          │
     │  GET /some-endpoint (retry)              │
     │  Authorization: Bearer <new_token>       │
     │ ───────────────────────────────────────► │
     │                                          │
     │  200 OK { data: ... }                    │
     │ ◄─────────────────────────────────────── │
```

> **Refresh token rotation:** Every refresh call issues a new refresh token and invalidates the previous one. The old refresh token is immediately added to the Redis denylist.

### 2.3 OAuth2 Flow for Integrations

When a user connects a third-party service (e.g., Google Calendar), ARIA uses the **Authorization Code Flow with PKCE**:

```
1. Client generates code_verifier (random 64-byte string) and
   code_challenge = BASE64URL(SHA256(code_verifier))

2. Client opens browser to provider's authorization URL:
   https://accounts.google.com/o/oauth2/v2/auth
     ?client_id=ARIA_CLIENT_ID
     &redirect_uri=https://app.aria.ai/oauth/callback
     &response_type=code
     &scope=https://www.googleapis.com/auth/calendar.readonly
     &code_challenge=<code_challenge>
     &code_challenge_method=S256
     &state=<csrf_token>

3. User approves. Provider redirects to:
   https://app.aria.ai/oauth/callback?code=AUTH_CODE&state=<csrf_token>

4. Client validates state, then calls:
   POST /integrations/google_calendar/connect
   { "code": "AUTH_CODE", "redirect_uri": "...", "code_verifier": "..." }

5. ARIA server exchanges code for tokens, encrypts them, stores in integrations table.
   Returns the integration object to the client.
```

---

## 3. Common Conventions

### 3.1 Request/Response Format

All responses use a consistent envelope structure.

**Standard success response:**

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "full_name": "Jane Smith"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:30:00Z"
  }
}
```

**Standard paginated response:**

```json
{
  "data": [
    { "id": "...", "title": "Team standup" },
    { "id": "...", "title": "Product review" }
  ],
  "meta": {
    "total": 47,
    "page": 1,
    "per_page": 20,
    "total_pages": 3,
    "request_id": "req_01HX7K9MGHIJKL",
    "timestamp": "2026-06-15T10:30:00Z"
  }
}
```

### 3.2 Error Response Format

All error responses use a uniform structure regardless of the error type:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed.",
    "details": [
      {
        "field": "email",
        "issue": "Invalid email address format."
      },
      {
        "field": "password",
        "issue": "Password must be at least 8 characters."
      }
    ],
    "request_id": "req_01HX7K9MNOPQRS",
    "docs_url": "https://docs.aria.ai/errors/VALIDATION_ERROR"
  }
}
```

The `details` array is present only when there are field-level validation issues. For most errors it is omitted or empty.

### 3.3 Pagination

Paginated endpoints accept the following query parameters:

| Parameter  | Type    | Default | Maximum | Description               |
|------------|---------|---------|---------|---------------------------|
| `page`     | integer | `1`     | —       | 1-based page number       |
| `per_page` | integer | `20`    | `100`   | Results per page          |

Pagination metadata is always returned in the `meta` object. Clients should use `total_pages` to determine whether additional pages exist rather than checking if `data` is empty.

### 3.4 Filtering & Sorting

Common sort parameters accepted by list endpoints:

| Parameter  | Values          | Default       | Description                  |
|------------|-----------------|---------------|------------------------------|
| `sort_by`  | field name      | `created_at`  | Field to sort by             |
| `sort_dir` | `asc` / `desc`  | `desc`        | Sort direction               |

Field-specific filters are documented per endpoint. Date/time filter parameters accept **ISO 8601** format with timezone offset (e.g., `2026-07-01T00:00:00Z`).

### 3.5 Rate Limiting

Limits are enforced per user per minute and per user per day using a sliding window counter in Redis.

| Tier         | Requests / Minute | Requests / Day |
|--------------|-------------------|----------------|
| `free`       | 60                | 1,000          |
| `pro`        | 300               | Unlimited      |
| `enterprise` | 1,000             | Unlimited      |

All responses include rate limit headers:

| Header                  | Description                                          |
|-------------------------|------------------------------------------------------|
| `X-RateLimit-Limit`     | Maximum requests allowed in the current window       |
| `X-RateLimit-Remaining` | Requests remaining in the current window             |
| `X-RateLimit-Reset`     | Unix timestamp when the current window resets        |
| `Retry-After`           | Seconds to wait (only present on `429` responses)    |

When the limit is exceeded, the API returns `429 RATE_LIMIT_EXCEEDED` and the client must wait until `Retry-After` seconds have elapsed before retrying.

---

## 4. Error Codes

| HTTP Status | Error Code              | Description                                                                       |
|-------------|-------------------------|-----------------------------------------------------------------------------------|
| 400         | `VALIDATION_ERROR`      | One or more request fields failed validation. See `details` array.                |
| 400         | `INVALID_REQUEST`       | Malformed JSON body or missing required fields not caught by schema validation.   |
| 401         | `UNAUTHORIZED`          | No `Authorization` header provided or the token signature is invalid.             |
| 401         | `TOKEN_EXPIRED`         | The JWT access token has passed its `exp` claim. Use the refresh token.           |
| 401         | `REFRESH_TOKEN_EXPIRED` | The refresh token has expired. The user must log in again.                        |
| 401         | `TOKEN_REVOKED`         | The token has been explicitly revoked (logout or session invalidation).           |
| 403         | `FORBIDDEN`             | The authenticated user does not have permission to access this resource.          |
| 403         | `SUBSCRIPTION_REQUIRED` | This feature requires a `pro` or `enterprise` subscription.                       |
| 404         | `NOT_FOUND`             | The requested resource does not exist or has been deleted.                        |
| 409         | `CONFLICT`              | The request conflicts with existing state (e.g., duplicate email on register).    |
| 422         | `UNPROCESSABLE_ENTITY`  | The request is well-formed but cannot be processed (e.g., logical contradictions). |
| 429         | `RATE_LIMIT_EXCEEDED`   | Too many requests. See `Retry-After` header.                                      |
| 500         | `INTERNAL_ERROR`        | An unexpected server-side error occurred. The `request_id` aids debugging.        |
| 503         | `SERVICE_UNAVAILABLE`   | A downstream dependency (Claude API, Qdrant, etc.) is temporarily unavailable.   |

---

## 5. API Endpoints

---

### 5.1 Authentication Endpoints

---

#### `POST /auth/register`

Register a new ARIA account.

- **Auth Required:** No
- **Rate Limit:** 10 requests / hour per IP

**Request Body:**

| Field      | Type   | Required | Description                               |
|------------|--------|----------|-------------------------------------------|
| `email`    | string | Yes      | User's email address (must be unique)     |
| `password` | string | Yes      | Minimum 8 characters, at least 1 number  |
| `full_name`| string | Yes      | User's display name                       |
| `timezone` | string | No       | IANA timezone (default: `UTC`)            |

**Responses:** `201 Created`, `400 VALIDATION_ERROR`, `409 CONFLICT`

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "jane@example.com",
    "password": "securePass42!",
    "full_name": "Jane Smith",
    "timezone": "America/New_York"
  }'
```

**Example Response — 201 Created:**

```json
{
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "jane@example.com",
      "full_name": "Jane Smith",
      "display_name": null,
      "timezone": "America/New_York",
      "locale": "en-US",
      "subscription_tier": "free",
      "onboarding_completed": false,
      "created_at": "2026-06-15T10:00:00Z"
    },
    "tokens": {
      "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refresh_token": "v1.refresh.550e8400...",
      "token_type": "Bearer",
      "expires_in": 1800
    }
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:00:00Z"
  }
}
```

---

#### `POST /auth/login`

Authenticate with email and password.

- **Auth Required:** No
- **Rate Limit:** 20 requests / hour per IP (progressive backoff after 5 failures)

**Request Body:**

| Field      | Type   | Required | Description        |
|------------|--------|----------|--------------------|
| `email`    | string | Yes      | Registered email   |
| `password` | string | Yes      | Account password   |

**Responses:** `200 OK`, `400 VALIDATION_ERROR`, `401 UNAUTHORIZED`

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "jane@example.com",
    "password": "securePass42!"
  }'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "jane@example.com",
      "full_name": "Jane Smith",
      "display_name": "Jane",
      "timezone": "America/New_York",
      "locale": "en-US",
      "subscription_tier": "pro",
      "subscription_expires_at": "2027-06-15T00:00:00Z",
      "onboarding_completed": true,
      "last_active_at": "2026-06-14T22:10:00Z",
      "created_at": "2026-01-10T08:00:00Z"
    },
    "tokens": {
      "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refresh_token": "v1.refresh.550e8400...",
      "token_type": "Bearer",
      "expires_in": 1800
    }
  },
  "meta": {
    "request_id": "req_01HX7K9MNOPQRS",
    "timestamp": "2026-06-15T10:05:00Z"
  }
}
```

---

#### `POST /auth/refresh`

Exchange a valid refresh token for a new access token. The old refresh token is rotated and invalidated.

- **Auth Required:** No
- **Rate Limit:** 60 requests / hour per IP

**Request Body:**

| Field           | Type   | Required | Description                      |
|-----------------|--------|----------|----------------------------------|
| `refresh_token` | string | Yes      | The current valid refresh token  |

**Responses:** `200 OK`, `401 REFRESH_TOKEN_EXPIRED`, `401 TOKEN_REVOKED`

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "v1.refresh.550e8400..."
  }'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "v1.refresh.660f9511...",
    "token_type": "Bearer",
    "expires_in": 1800
  },
  "meta": {
    "request_id": "req_01HX7K9MUVWXYZ",
    "timestamp": "2026-06-15T10:35:00Z"
  }
}
```

---

#### `POST /auth/logout`

Revoke the current session. The access token and refresh token are added to the Redis denylist.

- **Auth Required:** Yes

**Request Body:**

| Field           | Type   | Required | Description                                          |
|-----------------|--------|----------|------------------------------------------------------|
| `refresh_token` | string | No       | If provided, also revokes the refresh token          |

**Responses:** `204 No Content`, `401 UNAUTHORIZED`

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/auth/logout \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "v1.refresh.550e8400..."
  }'
```

**Example Response — 204 No Content:** *(empty body)*

---

#### `GET /auth/me`

Verify the current access token and retrieve the authenticated user's basic info.

- **Auth Required:** Yes

**Responses:** `200 OK`, `401 UNAUTHORIZED`, `401 TOKEN_EXPIRED`

**Example Request:**

```bash
curl https://api.aria.ai/v1/auth/me \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "jane@example.com",
      "full_name": "Jane Smith",
      "subscription_tier": "pro",
      "onboarding_completed": true
    }
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:06:00Z"
  }
}
```

---

#### `POST /auth/oauth/google`

Exchange a Google OAuth authorization code for ARIA access and refresh tokens. Creates a new ARIA account if the Google email is not yet registered.

- **Auth Required:** No

**Request Body:**

| Field          | Type   | Required | Description                                |
|----------------|--------|----------|--------------------------------------------|
| `code`         | string | Yes      | Authorization code from Google OAuth flow  |
| `redirect_uri` | string | Yes      | Must exactly match the registered redirect URI |

**Responses:** `200 OK`, `400 VALIDATION_ERROR`, `401 UNAUTHORIZED`

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/auth/oauth/google \
  -H "Content-Type: application/json" \
  -d '{
    "code": "4/0AY0e-g5...",
    "redirect_uri": "https://app.aria.ai/oauth/callback"
  }'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "jane@gmail.com",
      "full_name": "Jane Smith",
      "avatar_url": "https://lh3.googleusercontent.com/a/...",
      "subscription_tier": "free",
      "onboarding_completed": false
    },
    "tokens": {
      "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refresh_token": "v1.refresh.550e8400...",
      "token_type": "Bearer",
      "expires_in": 1800
    },
    "is_new_user": true
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:07:00Z"
  }
}
```

---

#### `POST /auth/password/reset-request`

Initiate a password reset by sending an email with a time-limited reset link.

- **Auth Required:** No
- **Rate Limit:** 5 requests / hour per IP (always returns 200 to prevent email enumeration)

**Request Body:**

| Field   | Type   | Required | Description               |
|---------|--------|----------|---------------------------|
| `email` | string | Yes      | The account's email address |

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/auth/password/reset-request \
  -H "Content-Type: application/json" \
  -d '{"email": "jane@example.com"}'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "message": "If an account with that email exists, a reset link has been sent."
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:08:00Z"
  }
}
```

---

#### `POST /auth/password/reset`

Complete a password reset using the token from the reset email.

- **Auth Required:** No

**Request Body:**

| Field        | Type   | Required | Description                        |
|--------------|--------|----------|------------------------------------|
| `token`      | string | Yes      | Reset token from email link        |
| `password`   | string | Yes      | New password (min 8 chars, 1 digit)|

**Responses:** `200 OK`, `400 VALIDATION_ERROR`, `401 UNAUTHORIZED` (invalid/expired token)

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/auth/password/reset \
  -H "Content-Type: application/json" \
  -d '{
    "token": "prst_01HX7K9M...",
    "password": "newSecure99!"
  }'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "message": "Password updated successfully. All existing sessions have been revoked."
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:09:00Z"
  }
}
```

---

### 5.2 User Endpoints

---

#### `GET /users/me`

Retrieve the full profile of the authenticated user, including subscription details.

- **Auth Required:** Yes

**Example Request:**

```bash
curl https://api.aria.ai/v1/users/me \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "jane@example.com",
    "phone": "+1-555-0100",
    "full_name": "Jane Smith",
    "display_name": "Jane",
    "timezone": "America/New_York",
    "locale": "en-US",
    "avatar_url": "https://cdn.aria.ai/avatars/jane.jpg",
    "subscription_tier": "pro",
    "subscription_expires_at": "2027-06-15T00:00:00Z",
    "onboarding_completed": true,
    "last_active_at": "2026-06-15T09:58:00Z",
    "created_at": "2026-01-10T08:00:00Z",
    "updated_at": "2026-06-01T12:00:00Z"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:10:00Z"
  }
}
```

---

#### `PUT /users/me`

Update mutable profile fields for the authenticated user.

- **Auth Required:** Yes

**Request Body (all fields optional):**

| Field          | Type   | Description                          |
|----------------|--------|--------------------------------------|
| `full_name`    | string | Legal or preferred full name         |
| `display_name` | string | Short name ARIA uses in conversation |
| `timezone`     | string | IANA timezone identifier             |
| `locale`       | string | BCP 47 locale code (e.g., `en-US`)   |
| `avatar_url`   | string | URL to profile image                 |

**Example Request:**

```bash
curl -X PUT https://api.aria.ai/v1/users/me \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "display_name": "Janie",
    "timezone": "Europe/London"
  }'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "jane@example.com",
    "full_name": "Jane Smith",
    "display_name": "Janie",
    "timezone": "Europe/London",
    "locale": "en-US",
    "updated_at": "2026-06-15T10:11:00Z"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:11:00Z"
  }
}
```

---

#### `GET /users/me/preferences`

Retrieve the user's full preferences object, structured by category.

- **Auth Required:** Yes

**Example Request:**

```bash
curl https://api.aria.ai/v1/users/me/preferences \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "notifications": {
      "morning_briefing": true,
      "morning_briefing_time": "07:30",
      "meeting_reminders": true,
      "meeting_reminder_minutes": 15,
      "task_reminders": true,
      "travel_alerts": true,
      "proactive_suggestions": true,
      "quiet_hours_enabled": true,
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
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:12:00Z"
  }
}
```

---

#### `PUT /users/me/preferences`

Update one or more preference categories. Performs a deep merge — only provided keys are updated.

- **Auth Required:** Yes

**Request Body:** Partial preferences object (any subset of the preferences schema).

**Example Request:**

```bash
curl -X PUT https://api.aria.ai/v1/users/me/preferences \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "notifications": {
      "morning_briefing_time": "06:45",
      "quiet_hours_enabled": false
    },
    "ai_behavior": {
      "verbosity": "concise"
    }
  }'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "notifications": {
      "morning_briefing": true,
      "morning_briefing_time": "06:45",
      "meeting_reminders": true,
      "meeting_reminder_minutes": 15,
      "task_reminders": true,
      "travel_alerts": true,
      "proactive_suggestions": true,
      "quiet_hours_enabled": false,
      "quiet_hours_start": "22:00",
      "quiet_hours_end": "07:00"
    },
    "ai_behavior": {
      "verbosity": "concise",
      "proactive_level": "medium",
      "memory_enabled": true,
      "preferred_name": "Aria"
    }
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:13:00Z"
  }
}
```

---

#### `DELETE /users/me`

Initiate account deletion. The account is soft-deleted immediately and permanently erased 30 days later. All active sessions are revoked instantly.

- **Auth Required:** Yes

**Request Body:**

| Field      | Type   | Required | Description                                   |
|------------|--------|----------|-----------------------------------------------|
| `password` | string | Yes      | Current password (confirms user intent)       |
| `reason`   | string | No       | Optional deletion reason (for internal analytics) |

**Responses:** `200 OK`, `401 UNAUTHORIZED` (wrong password)

**Example Request:**

```bash
curl -X DELETE https://api.aria.ai/v1/users/me \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "password": "securePass42!",
    "reason": "Switching to a different service"
  }'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "message": "Account deletion scheduled. Your data will be permanently deleted on 2026-07-15T10:14:00Z.",
    "deletion_scheduled_at": "2026-07-15T10:14:00Z"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:14:00Z"
  }
}
```

---

#### `GET /users/me/stats`

Retrieve aggregate usage statistics for the authenticated user.

- **Auth Required:** Yes

**Example Request:**

```bash
curl https://api.aria.ai/v1/users/me/stats \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "total_memories": 342,
    "total_conversations": 89,
    "total_messages": 1204,
    "total_tasks": 156,
    "tasks_completed": 121,
    "task_completion_rate": 0.78,
    "total_events": 410,
    "total_travel_plans": 7,
    "integrations_connected": 3,
    "days_active": 157,
    "tokens_used_30d": 284500,
    "member_since": "2026-01-10T08:00:00Z"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:15:00Z"
  }
}
```

---

### 5.3 Memory Endpoints

---

#### `GET /memories`

List the authenticated user's memories with optional filtering.

- **Auth Required:** Yes

**Query Parameters:**

| Parameter  | Type    | Description                                                   |
|------------|---------|---------------------------------------------------------------|
| `category` | string  | Filter by category (e.g., `preference`, `fact`, `routine`)    |
| `tags`     | string  | Comma-separated tags to filter by (OR logic)                  |
| `sort_by`  | string  | `created_at` (default), `importance_score`, `last_accessed_at`|
| `sort_dir` | string  | `asc` / `desc` (default: `desc`)                              |
| `page`     | integer | Page number (default: 1)                                      |
| `per_page` | integer | Results per page (default: 20, max: 100)                      |

**Example Request:**

```bash
curl "https://api.aria.ai/v1/memories?category=preference&sort_by=importance_score&sort_dir=desc&per_page=10" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": [
    {
      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "content": "Prefers oat milk in coffee, not regular dairy.",
      "summary": "Coffee preference: oat milk",
      "category": "preference",
      "subcategory": "food",
      "importance_score": 0.72,
      "confidence_score": 0.95,
      "source": "conversation",
      "tags": ["coffee", "food", "daily-routine"],
      "entities": { "items": ["oat milk", "coffee"] },
      "access_count": 14,
      "last_accessed_at": "2026-06-14T09:00:00Z",
      "expires_at": null,
      "created_at": "2026-02-01T10:30:00Z",
      "updated_at": "2026-02-01T10:30:00Z"
    }
  ],
  "meta": {
    "total": 87,
    "page": 1,
    "per_page": 10,
    "total_pages": 9,
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:16:00Z"
  }
}
```

---

#### `POST /memories`

Create a new memory. The embedding is generated asynchronously; the response is `202 Accepted`.

- **Auth Required:** Yes

**Request Body:**

| Field             | Type    | Required | Description                                              |
|-------------------|---------|----------|----------------------------------------------------------|
| `content`         | string  | Yes      | The memory content (the fact or preference to remember)  |
| `category`        | string  | Yes      | One of: `preference`, `fact`, `relationship`, `routine`, `decision`, `event` |
| `subcategory`     | string  | No       | Finer-grained category (e.g., `food`, `work`, `family`)  |
| `tags`            | array   | No       | Array of string tags                                     |
| `importance_score`| float   | No       | 0.0–1.0 (default: `0.5`)                                 |
| `source`          | string  | No       | `conversation`, `calendar`, `email`, `manual`, `inferred`|

**Responses:** `202 Accepted`, `400 VALIDATION_ERROR`

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/memories \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Has a recurring 1:1 with their manager Sarah every Monday at 2pm.",
    "category": "routine",
    "subcategory": "work",
    "tags": ["meetings", "work", "sarah"],
    "importance_score": 0.8,
    "source": "manual"
  }'
```

**Example Response — 202 Accepted:**

```json
{
  "data": {
    "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
    "content": "Has a recurring 1:1 with their manager Sarah every Monday at 2pm.",
    "category": "routine",
    "subcategory": "work",
    "embedding_id": null,
    "importance_score": 0.8,
    "confidence_score": 1.0,
    "source": "manual",
    "tags": ["meetings", "work", "sarah"],
    "entities": {},
    "access_count": 0,
    "created_at": "2026-06-15T10:17:00Z",
    "updated_at": "2026-06-15T10:17:00Z",
    "_embedding_status": "pending"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:17:00Z"
  }
}
```

---

#### `GET /memories/{id}`

Retrieve a single memory by ID.

- **Auth Required:** Yes

**Path Parameters:**

| Parameter | Type   | Description  |
|-----------|--------|--------------|
| `id`      | UUID   | Memory ID    |

**Responses:** `200 OK`, `404 NOT_FOUND`

**Example Request:**

```bash
curl https://api.aria.ai/v1/memories/b2c3d4e5-f6a7-8901-bcde-f12345678901 \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
    "content": "Has a recurring 1:1 with their manager Sarah every Monday at 2pm.",
    "summary": "Weekly 1:1 with manager Sarah, Mondays 2pm",
    "category": "routine",
    "subcategory": "work",
    "embedding_id": "qdrant-pt-b2c3d4e5",
    "importance_score": 0.8,
    "confidence_score": 1.0,
    "source": "manual",
    "tags": ["meetings", "work", "sarah"],
    "entities": { "people": ["Sarah"], "times": ["Monday 2pm"] },
    "access_count": 3,
    "last_accessed_at": "2026-06-15T09:00:00Z",
    "expires_at": null,
    "created_at": "2026-06-15T10:17:00Z",
    "updated_at": "2026-06-15T10:17:00Z"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:18:00Z"
  }
}
```

---

#### `PUT /memories/{id}`

Update a memory's content or metadata. If `content` is updated, a new embedding is generated asynchronously.

- **Auth Required:** Yes

**Request Body (all fields optional):**

| Field             | Type   | Description                          |
|-------------------|--------|--------------------------------------|
| `content`         | string | Updated memory content               |
| `category`        | string | Updated category                     |
| `subcategory`     | string | Updated subcategory                  |
| `tags`            | array  | Updated tags (replaces existing)     |
| `importance_score`| float  | Updated importance (0.0–1.0)         |

**Responses:** `200 OK`, `404 NOT_FOUND`, `400 VALIDATION_ERROR`

**Example Request:**

```bash
curl -X PUT https://api.aria.ai/v1/memories/b2c3d4e5-f6a7-8901-bcde-f12345678901 \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Has a recurring 1:1 with their manager Sarah every Monday at 3pm (moved from 2pm).",
    "importance_score": 0.85
  }'
```

**Example Response — 200 OK:** *(returns updated memory object, same structure as GET)*

---

#### `DELETE /memories/{id}`

Permanently delete a memory from both PostgreSQL and Qdrant.

- **Auth Required:** Yes

**Responses:** `204 No Content`, `404 NOT_FOUND`

**Example Request:**

```bash
curl -X DELETE https://api.aria.ai/v1/memories/b2c3d4e5-f6a7-8901-bcde-f12345678901 \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

#### `POST /memories/search`

Semantic search across the user's memories using vector similarity (Qdrant) with optional metadata pre-filtering.

- **Auth Required:** Yes

**Request Body:**

| Field              | Type    | Required | Description                                                   |
|--------------------|---------|----------|---------------------------------------------------------------|
| `query`            | string  | Yes      | Natural language search query                                 |
| `limit`            | integer | No       | Max results to return (default: 10, max: 50)                  |
| `category_filter`  | string  | No       | Restrict search to a specific category                        |
| `tag_filter`       | array   | No       | Restrict to memories with any of these tags                   |
| `min_importance`   | float   | No       | Minimum importance score threshold (0.0–1.0)                  |
| `include_expired`  | boolean | No       | Include memories past their `expires_at` (default: `false`)   |

**Responses:** `200 OK`, `400 VALIDATION_ERROR`

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/memories/search \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What do I know about my meetings with Sarah?",
    "limit": 5,
    "min_importance": 0.5
  }'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "results": [
      {
        "memory": {
          "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
          "content": "Has a recurring 1:1 with their manager Sarah every Monday at 3pm.",
          "category": "routine",
          "importance_score": 0.85,
          "tags": ["meetings", "work", "sarah"]
        },
        "similarity_score": 0.923,
        "rank": 1
      },
      {
        "memory": {
          "id": "c3d4e5f6-a7b8-9012-cdef-012345678902",
          "content": "Sarah prefers async updates over in-person meetings when possible.",
          "category": "fact",
          "importance_score": 0.6,
          "tags": ["work", "sarah", "communication"]
        },
        "similarity_score": 0.841,
        "rank": 2
      }
    ],
    "query_embedding_generated": true,
    "total_searched": 342
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:19:00Z"
  }
}
```

---

#### `GET /memories/categories`

List all memory categories with document counts for the authenticated user.

- **Auth Required:** Yes

**Example Request:**

```bash
curl https://api.aria.ai/v1/memories/categories \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": [
    { "category": "preference", "count": 98 },
    { "category": "fact", "count": 74 },
    { "category": "routine", "count": 61 },
    { "category": "relationship", "count": 52 },
    { "category": "decision", "count": 37 },
    { "category": "event", "count": 20 }
  ],
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:20:00Z"
  }
}
```

---

### 5.4 Conversation Endpoints

---

#### `GET /conversations`

List the authenticated user's conversations.

- **Auth Required:** Yes

**Query Parameters:**

| Parameter  | Type    | Description                                              |
|------------|---------|----------------------------------------------------------|
| `status`   | string  | Filter by status: `active`, `ended`, `archived`          |
| `channel`  | string  | Filter by channel: `app`, `voice`, `sms`, `api`          |
| `page`     | integer | Page number (default: 1)                                 |
| `per_page` | integer | Results per page (default: 20, max: 100)                 |

**Example Request:**

```bash
curl "https://api.aria.ai/v1/conversations?status=ended&per_page=5" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": [
    {
      "id": "d4e5f6a7-b8c9-0123-defa-123456789012",
      "title": "Planning Tokyo trip",
      "channel": "app",
      "status": "ended",
      "summary": "Discussed travel plans for Tokyo in July, including flights and hotel options.",
      "intent_tags": ["travel", "planning", "tokyo"],
      "message_count": 18,
      "token_count": 4200,
      "started_at": "2026-06-10T14:00:00Z",
      "ended_at": "2026-06-10T14:35:00Z",
      "created_at": "2026-06-10T14:00:00Z"
    }
  ],
  "meta": {
    "total": 89,
    "page": 1,
    "per_page": 5,
    "total_pages": 18,
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:21:00Z"
  }
}
```

---

#### `POST /conversations`

Start a new conversation. Optionally provide an initial message to receive the first assistant response immediately.

- **Auth Required:** Yes

**Request Body:**

| Field             | Type   | Required | Description                                     |
|-------------------|--------|----------|-------------------------------------------------|
| `channel`         | string | No       | `app` (default), `voice`, `sms`, `api`          |
| `title`           | string | No       | Optional conversation title                     |
| `initial_message` | string | No       | If provided, ARIA will respond immediately      |

**Responses:** `201 Created`

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/conversations \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "app",
    "initial_message": "What do I have on my calendar this week?"
  }'
```

**Example Response — 201 Created:**

```json
{
  "data": {
    "conversation": {
      "id": "e5f6a7b8-c9d0-1234-efab-234567890123",
      "channel": "app",
      "status": "active",
      "message_count": 2,
      "started_at": "2026-06-15T10:22:00Z"
    },
    "user_message": {
      "id": "f6a7b8c9-d0e1-2345-fabc-345678901234",
      "role": "user",
      "content": "What do I have on my calendar this week?",
      "created_at": "2026-06-15T10:22:00Z"
    },
    "assistant_message": {
      "id": "a7b8c9d0-e1f2-3456-abcd-456789012345",
      "role": "assistant",
      "content": "Here's what's on your calendar this week:\n\n**Monday, June 16**\n- 1:1 with Sarah — 3:00 PM (1 hour)\n\n**Tuesday, June 17**\n- Product review — 10:00 AM (2 hours)\n- Team standup — 3:00 PM (30 min)\n\n**Wednesday, June 18**\n- No events\n\n**Thursday, June 19**\n- Board prep call — 9:00 AM (1 hour)\n\n**Friday, June 20**\n- Sprint retrospective — 2:00 PM (1 hour)\n\nWould you like me to create a briefing for any of these meetings?",
      "tokens_used": 387,
      "model_used": "claude-sonnet-4-5",
      "latency_ms": 1240,
      "created_at": "2026-06-15T10:22:01Z"
    },
    "memories_used": 3,
    "tool_calls": ["get_calendar_events"]
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:22:01Z"
  }
}
```

---

#### `GET /conversations/{id}`

Retrieve a conversation with its most recent 20 messages.

- **Auth Required:** Yes

**Example Request:**

```bash
curl https://api.aria.ai/v1/conversations/e5f6a7b8-c9d0-1234-efab-234567890123 \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:** *(conversation object with embedded `messages` array of last 20 messages)*

---

#### `GET /conversations/{id}/messages`

Retrieve paginated message history for a conversation.

- **Auth Required:** Yes

**Query Parameters:**

| Parameter  | Type    | Default | Description              |
|------------|---------|---------|--------------------------|
| `page`     | integer | 1       | Page number              |
| `per_page` | integer | 20      | Messages per page (max 100) |

**Example Request:**

```bash
curl "https://api.aria.ai/v1/conversations/e5f6a7b8-c9d0-1234-efab-234567890123/messages?page=1&per_page=50" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

#### `POST /conversations/{id}/messages`

Send a message to an active conversation and receive ARIA's response.

- **Auth Required:** Yes

**Request Body:**

| Field          | Type   | Required | Description                                    |
|----------------|--------|----------|------------------------------------------------|
| `content`      | string | Yes      | The user's message text                        |
| `content_type` | string | No       | `text` (default), `image` (future)             |

**Responses:** `200 OK`, `404 NOT_FOUND`, `422 UNPROCESSABLE_ENTITY` (conversation not active)

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/conversations/e5f6a7b8-c9d0-1234-efab-234567890123/messages \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Can you set a reminder for the board prep call?"
  }'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "user_message": {
      "id": "b8c9d0e1-f2a3-4567-bcde-567890123456",
      "role": "user",
      "content": "Can you set a reminder for the board prep call?",
      "created_at": "2026-06-15T10:23:00Z"
    },
    "assistant_message": {
      "id": "c9d0e1f2-a3b4-5678-cdef-678901234567",
      "role": "assistant",
      "content": "Done! I've set a reminder for the Board prep call on Thursday, June 19 at 8:30 AM — 30 minutes before it starts. I'll send you a push notification and include any relevant prep materials I can find.",
      "tokens_used": 204,
      "model_used": "claude-sonnet-4-5",
      "latency_ms": 890,
      "created_at": "2026-06-15T10:23:01Z"
    },
    "memories_used": 1,
    "tool_calls": ["create_task_reminder"]
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:23:01Z"
  }
}
```

---

#### `POST /conversations/{id}/end`

End a conversation, triggering summary and intent tag generation via Claude.

- **Auth Required:** Yes

**Responses:** `200 OK`, `404 NOT_FOUND`

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/conversations/e5f6a7b8-c9d0-1234-efab-234567890123/end \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "id": "e5f6a7b8-c9d0-1234-efab-234567890123",
    "status": "ended",
    "summary": "User asked about their weekly calendar. ARIA listed 5 events across Mon–Fri. User requested a task reminder for the Thursday board prep call, which was created.",
    "intent_tags": ["calendar", "task-management", "reminders"],
    "message_count": 4,
    "token_count": 591,
    "ended_at": "2026-06-15T10:23:30Z"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:23:30Z"
  }
}
```

---

#### `DELETE /conversations/{id}`

Soft-delete a conversation and all its messages.

- **Auth Required:** Yes
- **Responses:** `204 No Content`, `404 NOT_FOUND`

---

### 5.5 Events (Calendar) Endpoints

---

#### `GET /events`

List calendar events with optional date range and source filtering.

- **Auth Required:** Yes

**Query Parameters:**

| Parameter           | Type    | Description                                                   |
|---------------------|---------|---------------------------------------------------------------|
| `start_date`        | datetime | Filter events starting at or after this time                 |
| `end_date`          | datetime | Filter events starting before this time                      |
| `source`            | string  | Filter by source: `google_calendar`, `outlook`, `manual`     |
| `include_cancelled` | boolean | Include cancelled events (default: `false`)                   |
| `page`              | integer | Page number (default: 1)                                      |
| `per_page`          | integer | Results per page (default: 20, max: 100)                      |

**Example Request:**

```bash
curl "https://api.aria.ai/v1/events?start_date=2026-06-15T00:00:00Z&end_date=2026-06-22T00:00:00Z" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": [
    {
      "id": "d0e1f2a3-b4c5-6789-defa-789012345678",
      "title": "1:1 with Sarah",
      "description": "Weekly manager sync",
      "location": "Conference Room B",
      "start_time": "2026-06-16T15:00:00-04:00",
      "end_time": "2026-06-16T16:00:00-04:00",
      "all_day": false,
      "timezone": "America/New_York",
      "attendees": [
        { "name": "Jane Smith", "email": "jane@example.com", "status": "accepted" },
        { "name": "Sarah Manager", "email": "sarah@example.com", "status": "accepted" }
      ],
      "source": "google_calendar",
      "status": "confirmed",
      "briefing_generated": false,
      "created_at": "2026-06-01T08:00:00Z"
    }
  ],
  "meta": {
    "total": 5,
    "page": 1,
    "per_page": 20,
    "total_pages": 1,
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:24:00Z"
  }
}
```

---

#### `POST /events`

Create a new calendar event manually.

- **Auth Required:** Yes

**Request Body:**

| Field            | Type    | Required | Description                                    |
|------------------|---------|----------|------------------------------------------------|
| `title`          | string  | Yes      | Event title (max 500 characters)               |
| `start_time`     | datetime| Yes      | Start time in ISO 8601 with timezone           |
| `end_time`       | datetime| Yes      | End time in ISO 8601 with timezone             |
| `description`    | string  | No       | Event description                              |
| `location`       | string  | No       | Location text                                  |
| `attendees`      | array   | No       | Array of `{name, email}` objects               |
| `all_day`        | boolean | No       | If `true`, times are ignored (default: `false`)|
| `recurrence_rule`| string  | No       | iCal RRULE string                              |

**Responses:** `201 Created`, `400 VALIDATION_ERROR`

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/events \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Dentist appointment",
    "start_time": "2026-07-02T10:00:00-04:00",
    "end_time": "2026-07-02T11:00:00-04:00",
    "location": "Dr. Brown Dental, 45 Main St"
  }'
```

**Example Response — 201 Created:** *(full event object)*

---

#### `GET /events/{id}`

Retrieve a single event by ID.

- **Auth Required:** Yes
- **Responses:** `200 OK`, `404 NOT_FOUND`

---

#### `PUT /events/{id}`

Update a calendar event. For externally-synced events, changes are also pushed to the source calendar if write scope is granted.

- **Auth Required:** Yes
- **Responses:** `200 OK`, `404 NOT_FOUND`, `403 FORBIDDEN` (no write permission for external calendar)

---

#### `DELETE /events/{id}`

Soft-delete an event. For synced events, also deletes from the source calendar if write scope is granted.

- **Auth Required:** Yes
- **Responses:** `204 No Content`, `404 NOT_FOUND`

---

#### `GET /events/upcoming`

Retrieve upcoming events within a configurable time window. Optimized for home screen widgets and notification pre-fetching.

- **Auth Required:** Yes

**Query Parameters:**

| Parameter | Type    | Default | Description                              |
|-----------|---------|---------|------------------------------------------|
| `hours`   | integer | `24`    | Lookahead window in hours (max: 168 / 7 days) |
| `limit`   | integer | `10`    | Maximum events to return (max: 50)       |

**Example Request:**

```bash
curl "https://api.aria.ai/v1/events/upcoming?hours=48&limit=5" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": [
    {
      "id": "d0e1f2a3-b4c5-6789-defa-789012345678",
      "title": "1:1 with Sarah",
      "start_time": "2026-06-16T15:00:00-04:00",
      "end_time": "2026-06-16T16:00:00-04:00",
      "location": "Conference Room B",
      "attendee_count": 2,
      "briefing_ready": false,
      "minutes_until_start": 1738
    }
  ],
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:25:00Z"
  }
}
```

---

#### `POST /events/sync`

Trigger an immediate calendar sync from connected integrations.

- **Auth Required:** Yes

**Request Body:**

| Field      | Type   | Required | Description                                             |
|------------|--------|----------|---------------------------------------------------------|
| `provider` | string | No       | Specific provider to sync (omit to sync all)            |

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/events/sync \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "synced_providers": ["google_calendar", "outlook"],
    "created": 3,
    "updated": 12,
    "deleted": 1,
    "errors": [],
    "sync_completed_at": "2026-06-15T10:25:30Z"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:25:30Z"
  }
}
```

---

#### `GET /events/{id}/briefing`

Retrieve or generate a pre-meeting briefing for an event. The briefing includes context about attendees (from memories), relevant documents, and suggested action items. Cached after first generation.

- **Auth Required:** Yes

**Responses:** `200 OK`, `404 NOT_FOUND`, `503 SERVICE_UNAVAILABLE` (Claude API unavailable)

**Example Request:**

```bash
curl https://api.aria.ai/v1/events/d0e1f2a3-b4c5-6789-defa-789012345678/briefing \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "briefing": {
      "event_id": "d0e1f2a3-b4c5-6789-defa-789012345678",
      "generated_at": "2026-06-15T09:00:00Z",
      "from_cache": true,
      "overview": "This is your weekly 1:1 with Sarah, your engineering manager. These typically cover sprint progress, blockers, and career development.",
      "key_topics_to_discuss": [
        "Progress on the ARIA v2.0 auth refactor",
        "Timeline for the Q3 roadmap review",
        "Feedback on the new onboarding flow"
      ],
      "recent_context": "In your last 1:1 (June 9), Sarah mentioned she wants updates on the Qdrant migration timeline."
    },
    "action_items": [
      {
        "title": "Prepare sprint velocity numbers",
        "priority": "high",
        "source": "briefing_generation"
      }
    ],
    "attendee_context": [
      {
        "email": "sarah@example.com",
        "name": "Sarah Manager",
        "known_facts": [
          "Prefers async updates over in-person meetings when possible.",
          "Is focused on team velocity metrics this quarter."
        ]
      }
    ]
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:26:00Z"
  }
}
```

---

### 5.6 Task Endpoints

---

#### `GET /tasks`

List the authenticated user's tasks with filtering and sorting.

- **Auth Required:** Yes

**Query Parameters:**

| Parameter    | Type     | Description                                              |
|--------------|----------|----------------------------------------------------------|
| `status`     | string   | Filter by: `pending`, `in_progress`, `completed`, `cancelled`, `snoozed` |
| `priority`   | string   | Filter by: `low`, `medium`, `high`, `urgent`             |
| `due_before` | datetime | Tasks due before this time                               |
| `due_after`  | datetime | Tasks due after this time                                |
| `tags`       | string   | Comma-separated tags (OR logic)                          |
| `page`       | integer  | Page number (default: 1)                                 |
| `per_page`   | integer  | Results per page (default: 20, max: 100)                 |

**Example Request:**

```bash
curl "https://api.aria.ai/v1/tasks?status=pending&priority=high&sort_by=due_date&sort_dir=asc" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": [
    {
      "id": "e1f2a3b4-c5d6-7890-efab-890123456789",
      "title": "Prepare board prep materials",
      "description": "Compile Q2 metrics and roadmap updates",
      "due_date": "2026-06-18T17:00:00-04:00",
      "due_date_all_day": false,
      "priority": "high",
      "status": "pending",
      "tags": ["work", "board", "q2"],
      "parent_task_id": null,
      "related_event_id": "d0e1f2a3-b4c5-6789-defa-789012345678",
      "estimated_minutes": 120,
      "reminder_at": "2026-06-18T09:00:00-04:00",
      "source": "conversation",
      "created_at": "2026-06-15T10:23:00Z"
    }
  ],
  "meta": {
    "total": 23,
    "page": 1,
    "per_page": 20,
    "total_pages": 2,
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:27:00Z"
  }
}
```

---

#### `POST /tasks`

Create a new task.

- **Auth Required:** Yes

**Request Body:**

| Field             | Type     | Required | Description                                  |
|-------------------|----------|----------|----------------------------------------------|
| `title`           | string   | Yes      | Task title (max 500 characters)              |
| `description`     | string   | No       | Optional detailed description                |
| `due_date`        | datetime | No       | Due date/time in ISO 8601                    |
| `priority`        | string   | No       | `low`, `medium` (default), `high`, `urgent`  |
| `tags`            | array    | No       | String tags                                  |
| `parent_task_id`  | UUID     | No       | Parent task ID for subtask hierarchy         |
| `estimated_minutes`| integer | No       | Estimated duration in minutes                |
| `reminder_at`     | datetime | No       | When to send a reminder notification         |

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/tasks \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Book flight to Tokyo",
    "description": "Economy class, depart July 10, return July 20",
    "due_date": "2026-06-20T17:00:00-04:00",
    "priority": "high",
    "tags": ["travel", "tokyo"],
    "estimated_minutes": 30
  }'
```

**Example Response — 201 Created:** *(full task object)*

---

#### `GET /tasks/{id}`

Retrieve a single task by ID.

- **Auth Required:** Yes
- **Responses:** `200 OK`, `404 NOT_FOUND`

---

#### `PUT /tasks/{id}`

Update any mutable field on a task.

- **Auth Required:** Yes
- **Responses:** `200 OK`, `404 NOT_FOUND`

---

#### `DELETE /tasks/{id}`

Soft-delete a task.

- **Auth Required:** Yes
- **Responses:** `204 No Content`, `404 NOT_FOUND`

---

#### `PUT /tasks/{id}/complete`

Mark a task as completed. Sets `status = 'completed'` and `completed_at = NOW()`.

- **Auth Required:** Yes

**Example Request:**

```bash
curl -X PUT https://api.aria.ai/v1/tasks/e1f2a3b4-c5d6-7890-efab-890123456789/complete \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "id": "e1f2a3b4-c5d6-7890-efab-890123456789",
    "title": "Prepare board prep materials",
    "status": "completed",
    "completed_at": "2026-06-15T10:28:00Z",
    "updated_at": "2026-06-15T10:28:00Z"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:28:00Z"
  }
}
```

---

#### `PUT /tasks/{id}/snooze`

Snooze a task until a specified time, changing its status to `snoozed`.

- **Auth Required:** Yes

**Request Body:**

| Field   | Type     | Required | Description                        |
|---------|----------|----------|------------------------------------|
| `until` | datetime | Yes      | When the task becomes active again |

**Example Request:**

```bash
curl -X PUT https://api.aria.ai/v1/tasks/e1f2a3b4-c5d6-7890-efab-890123456789/snooze \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{"until": "2026-06-17T09:00:00-04:00"}'
```

**Example Response — 200 OK:** *(updated task object with `status: "snoozed"`)*

---

#### `GET /tasks/overdue`

Retrieve all incomplete tasks with a `due_date` in the past.

- **Auth Required:** Yes

**Example Request:**

```bash
curl https://api.aria.ai/v1/tasks/overdue \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": [
    {
      "id": "f2a3b4c5-d6e7-8901-fabc-901234567890",
      "title": "Send Q1 report to stakeholders",
      "due_date": "2026-04-01T17:00:00-04:00",
      "priority": "urgent",
      "status": "pending",
      "days_overdue": 75
    }
  ],
  "meta": {
    "total": 2,
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:29:00Z"
  }
}
```

---

#### `GET /tasks/today`

Retrieve tasks due today plus all overdue tasks, ordered by priority then due date. Optimized for the daily briefing widget.

- **Auth Required:** Yes

**Example Request:**

```bash
curl https://api.aria.ai/v1/tasks/today \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "today": [
      {
        "id": "e1f2a3b4-c5d6-7890-efab-890123456789",
        "title": "Prepare board prep materials",
        "due_date": "2026-06-15T17:00:00-04:00",
        "priority": "high",
        "status": "pending"
      }
    ],
    "overdue": [
      {
        "id": "f2a3b4c5-d6e7-8901-fabc-901234567890",
        "title": "Send Q1 report to stakeholders",
        "due_date": "2026-04-01T17:00:00-04:00",
        "priority": "urgent",
        "status": "pending",
        "days_overdue": 75
      }
    ],
    "today_count": 1,
    "overdue_count": 1
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:29:30Z"
  }
}
```

---

### 5.7 Travel Endpoints

---

#### `GET /travel/plans`

List the authenticated user's travel plans.

- **Auth Required:** Yes

**Query Parameters:**

| Parameter  | Type    | Description                                                          |
|------------|---------|----------------------------------------------------------------------|
| `status`   | string  | Filter by: `planning`, `booked`, `active`, `completed`, `cancelled`  |
| `page`     | integer | Page number (default: 1)                                             |
| `per_page` | integer | Results per page (default: 20, max: 100)                             |

**Example Request:**

```bash
curl "https://api.aria.ai/v1/travel/plans?status=booked" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": [
    {
      "id": "a3b4c5d6-e7f8-9012-abcd-012345678901",
      "trip_name": "Tokyo Vacation",
      "origin_city": "New York",
      "origin_airport_code": "JFK",
      "destination_city": "Tokyo",
      "destination_airport_code": "NRT",
      "departure_date": "2026-07-10",
      "return_date": "2026-07-20",
      "status": "booked",
      "purpose": "leisure",
      "travelers": 2,
      "budget_currency": "USD",
      "budget_amount": 8000.00,
      "monitoring_enabled": true,
      "created_at": "2026-06-01T10:00:00Z"
    }
  ],
  "meta": {
    "total": 3,
    "page": 1,
    "per_page": 20,
    "total_pages": 1,
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:30:00Z"
  }
}
```

---

#### `POST /travel/plans`

Create a new travel plan.

- **Auth Required:** Yes

**Request Body:**

| Field                | Type    | Required | Description                                    |
|----------------------|---------|----------|------------------------------------------------|
| `trip_name`          | string  | Yes      | Human-readable trip name                       |
| `destination_city`   | string  | Yes      | Primary destination city                       |
| `departure_date`     | date    | Yes      | Departure date (YYYY-MM-DD)                    |
| `origin_city`        | string  | No       | Departure city                                 |
| `return_date`        | date    | No       | Return date for round trips                    |
| `purpose`            | string  | No       | `business`, `leisure`, `mixed`                 |
| `travelers`          | integer | No       | Number of travelers (default: 1)               |
| `budget_amount`      | number  | No       | Budget amount                                  |
| `budget_currency`    | string  | No       | ISO 4217 currency code (default: `USD`)        |

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/travel/plans \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "trip_name": "Tokyo Vacation",
    "destination_city": "Tokyo",
    "departure_date": "2026-07-10",
    "origin_city": "New York",
    "return_date": "2026-07-20",
    "purpose": "leisure",
    "travelers": 2,
    "budget_amount": 8000.00,
    "budget_currency": "USD"
  }'
```

**Example Response — 201 Created:** *(full travel plan object)*

---

#### `GET /travel/plans/{id}`

Retrieve a single travel plan including full itinerary, flights, and hotels.

- **Auth Required:** Yes
- **Responses:** `200 OK`, `404 NOT_FOUND`

---

#### `PUT /travel/plans/{id}`

Update a travel plan's top-level fields.

- **Auth Required:** Yes
- **Responses:** `200 OK`, `404 NOT_FOUND`

---

#### `DELETE /travel/plans/{id}`

Soft-delete a travel plan.

- **Auth Required:** Yes
- **Responses:** `204 No Content`, `404 NOT_FOUND`

---

#### `POST /travel/search/flights`

Search for available flights using the configured travel API provider (Amadeus / Duffel). Results are not stored.

- **Auth Required:** Yes
- **Subscription Required:** `pro` or `enterprise`

**Request Body:**

| Field          | Type    | Required | Description                                               |
|----------------|---------|----------|-----------------------------------------------------------|
| `origin`       | string  | Yes      | IATA airport code (e.g., `JFK`)                           |
| `destination`  | string  | Yes      | IATA airport code (e.g., `NRT`)                           |
| `departure_date`| date   | Yes      | Departure date (YYYY-MM-DD)                               |
| `return_date`  | date    | No       | Return date for round trips (YYYY-MM-DD)                  |
| `passengers`   | integer | No       | Number of passengers (default: 1)                         |
| `cabin_class`  | string  | No       | `economy`, `premium_economy`, `business`, `first`         |
| `max_results`  | integer | No       | Maximum results to return (default: 10, max: 50)          |

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/travel/search/flights \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "origin": "JFK",
    "destination": "NRT",
    "departure_date": "2026-07-10",
    "return_date": "2026-07-20",
    "passengers": 2,
    "cabin_class": "economy",
    "max_results": 5
  }'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "results": [
      {
        "id": "offer_abc123",
        "airline": "Japan Airlines",
        "airline_code": "JL",
        "flight_numbers": ["JL006"],
        "departure_time": "2026-07-10T14:00:00-04:00",
        "arrival_time": "2026-07-11T17:35:00+09:00",
        "duration_minutes": 815,
        "stops": 0,
        "cabin_class": "economy",
        "price_per_person": 742.00,
        "total_price": 1484.00,
        "currency": "USD",
        "baggage_included": true,
        "booking_url": "https://www.jal.com/..."
      },
      {
        "id": "offer_def456",
        "airline": "United Airlines",
        "airline_code": "UA",
        "flight_numbers": ["UA837"],
        "departure_time": "2026-07-10T11:00:00-04:00",
        "arrival_time": "2026-07-11T15:05:00+09:00",
        "duration_minutes": 845,
        "stops": 0,
        "cabin_class": "economy",
        "price_per_person": 689.00,
        "total_price": 1378.00,
        "currency": "USD",
        "baggage_included": false,
        "booking_url": "https://www.united.com/..."
      }
    ],
    "search_id": "srch_01HX7K9M...",
    "searched_at": "2026-06-15T10:31:00Z"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:31:00Z"
  }
}
```

---

#### `POST /travel/search/hotels`

Search for available hotels.

- **Auth Required:** Yes
- **Subscription Required:** `pro` or `enterprise`

**Request Body:**

| Field                | Type    | Required | Description                              |
|----------------------|---------|----------|------------------------------------------|
| `destination`        | string  | Yes      | City name or airport code                |
| `check_in`           | date    | Yes      | Check-in date (YYYY-MM-DD)               |
| `check_out`          | date    | Yes      | Check-out date (YYYY-MM-DD)              |
| `guests`             | integer | No       | Number of guests (default: 1)            |
| `max_results`        | integer | No       | Maximum results (default: 10, max: 50)   |
| `max_price_per_night`| number  | No       | Maximum nightly rate in USD              |

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/travel/search/hotels \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "destination": "Tokyo",
    "check_in": "2026-07-11",
    "check_out": "2026-07-20",
    "guests": 2,
    "max_price_per_night": 300,
    "max_results": 5
  }'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "results": [
      {
        "id": "hotel_ghi789",
        "name": "Park Hyatt Tokyo",
        "address": "3-7-1-2 Nishi Shinjuku, Shinjuku, Tokyo",
        "star_rating": 5,
        "review_score": 9.2,
        "review_count": 4821,
        "price_per_night": 289.00,
        "total_price": 2601.00,
        "currency": "USD",
        "amenities": ["pool", "spa", "gym", "restaurant", "bar", "concierge"],
        "free_cancellation": true,
        "cancellation_deadline": "2026-07-07T23:59:00+09:00",
        "booking_url": "https://www.hyatt.com/..."
      }
    ],
    "search_id": "srch_01HX7K9N...",
    "searched_at": "2026-06-15T10:32:00Z"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:32:00Z"
  }
}
```

---

#### `PUT /travel/plans/{id}/itinerary`

Replace the full itinerary for a travel plan.

- **Auth Required:** Yes

**Request Body:**

| Field       | Type  | Required | Description                                 |
|-------------|-------|----------|---------------------------------------------|
| `itinerary` | array | Yes      | Array of day objects with date and activities |

**Example Request:**

```bash
curl -X PUT https://api.aria.ai/v1/travel/plans/a3b4c5d6-e7f8-9012-abcd-012345678901/itinerary \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "itinerary": [
      {
        "date": "2026-07-11",
        "activities": [
          { "time": "14:00", "description": "Check in to Park Hyatt Tokyo", "location": "Shinjuku" },
          { "time": "19:00", "description": "Dinner at Sukiyabashi Jiro", "location": "Ginza" }
        ]
      },
      {
        "date": "2026-07-12",
        "activities": [
          { "time": "09:00", "description": "Visit Tsukiji Outer Market", "location": "Tsukiji" },
          { "time": "14:00", "description": "Explore Shibuya and Harajuku", "location": "Shibuya" }
        ]
      }
    ]
  }'
```

**Example Response — 200 OK:** *(full travel plan object with updated itinerary)*

---

#### `POST /travel/plans/{id}/monitor`

Enable or disable real-time travel monitoring for a trip. When enabled, ARIA monitors for flight delays, gate changes, and weather disruptions.

- **Auth Required:** Yes

**Request Body:**

| Field    | Type    | Required | Description                           |
|----------|---------|----------|---------------------------------------|
| `enable` | boolean | Yes      | `true` to enable, `false` to disable  |

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/travel/plans/a3b4c5d6-e7f8-9012-abcd-012345678901/monitor \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{"enable": true}'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "trip_id": "a3b4c5d6-e7f8-9012-abcd-012345678901",
    "monitoring_enabled": true,
    "message": "Real-time monitoring is now active for Tokyo Vacation. You will receive alerts for flight changes, delays, and disruptions."
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:33:00Z"
  }
}
```

---

### 5.8 Integration Endpoints

---

#### `GET /integrations`

List all integrations — both connected (active) and available (not yet connected).

- **Auth Required:** Yes

**Example Request:**

```bash
curl https://api.aria.ai/v1/integrations \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": [
    {
      "provider": "google_calendar",
      "display_name": "Google Calendar",
      "icon_url": "https://cdn.aria.ai/integrations/google_calendar.png",
      "connected": true,
      "provider_email": "jane@gmail.com",
      "scopes": ["https://www.googleapis.com/auth/calendar.readonly"],
      "is_active": true,
      "sync_enabled": true,
      "last_sync_at": "2026-06-15T09:00:00Z",
      "last_sync_status": "success",
      "connected_at": "2026-01-15T10:00:00Z"
    },
    {
      "provider": "outlook",
      "display_name": "Microsoft Outlook",
      "icon_url": "https://cdn.aria.ai/integrations/outlook.png",
      "connected": false
    },
    {
      "provider": "gmail",
      "display_name": "Gmail",
      "icon_url": "https://cdn.aria.ai/integrations/gmail.png",
      "connected": false
    },
    {
      "provider": "slack",
      "display_name": "Slack",
      "icon_url": "https://cdn.aria.ai/integrations/slack.png",
      "connected": false
    }
  ],
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:34:00Z"
  }
}
```

---

#### `GET /integrations/{provider}`

Retrieve detailed status for a specific integration.

- **Auth Required:** Yes
- **Path Parameters:** `provider` — e.g., `google_calendar`, `outlook`
- **Responses:** `200 OK`, `404 NOT_FOUND` (not connected)

---

#### `POST /integrations/{provider}/connect`

Connect a third-party integration by exchanging the OAuth authorization code for tokens.

- **Auth Required:** Yes

**Request Body:**

| Field          | Type   | Required | Description                                        |
|----------------|--------|----------|----------------------------------------------------|
| `code`         | string | Yes      | OAuth authorization code from the provider         |
| `redirect_uri` | string | Yes      | Must match the redirect URI used in the auth flow  |

**Responses:** `201 Created`, `400 VALIDATION_ERROR`, `409 CONFLICT` (already connected)

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/integrations/google_calendar/connect \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "code": "4/0AY0e-g5XnFBtGs...",
    "redirect_uri": "https://app.aria.ai/oauth/callback"
  }'
```

**Example Response — 201 Created:**

```json
{
  "data": {
    "provider": "google_calendar",
    "connected": true,
    "provider_email": "jane@gmail.com",
    "scopes": ["https://www.googleapis.com/auth/calendar.readonly"],
    "sync_enabled": true,
    "message": "Google Calendar connected successfully. Initial sync will complete in a few minutes."
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:35:00Z"
  }
}
```

---

#### `PUT /integrations/{provider}`

Update an existing integration's settings.

- **Auth Required:** Yes

**Request Body (all optional):**

| Field          | Type    | Description                                   |
|----------------|---------|-----------------------------------------------|
| `sync_enabled` | boolean | Enable or disable background sync             |
| `metadata`     | object  | Provider-specific configuration metadata      |

---

#### `DELETE /integrations/{provider}`

Disconnect an integration. Tokens are immediately deleted from the database; queued sync jobs for this provider are cancelled.

- **Auth Required:** Yes

**Example Request:**

```bash
curl -X DELETE https://api.aria.ai/v1/integrations/google_calendar \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "message": "Google Calendar has been disconnected. Synced events remain in ARIA but will no longer be updated."
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:36:00Z"
  }
}
```

---

#### `POST /integrations/{provider}/sync`

Trigger an immediate manual sync for a specific integration.

- **Auth Required:** Yes
- **Responses:** `202 Accepted` (sync enqueued), `404 NOT_FOUND` (not connected)

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/integrations/google_calendar/sync \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 202 Accepted:**

```json
{
  "data": {
    "message": "Sync enqueued for google_calendar.",
    "job_id": "job_01HX7K9MABCDEF",
    "estimated_duration_seconds": 15
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:36:30Z"
  }
}
```

---

### 5.9 Permission Endpoints

---

#### `GET /permissions`

Retrieve all recorded device permission statuses for the authenticated user.

- **Auth Required:** Yes

**Example Request:**

```bash
curl https://api.aria.ai/v1/permissions \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": [
    {
      "id": "b4c5d6e7-f8a9-0123-bcde-234567890123",
      "permission_type": "calendar_read",
      "platform": "ios",
      "status": "granted",
      "granted_at": "2026-01-15T10:05:00Z",
      "last_checked_at": "2026-06-15T09:00:00Z"
    },
    {
      "id": "c5d6e7f8-a9b0-1234-cdef-345678901234",
      "permission_type": "microphone",
      "platform": "ios",
      "status": "granted",
      "granted_at": "2026-01-15T10:06:00Z",
      "last_checked_at": "2026-06-15T09:00:00Z"
    },
    {
      "id": "d6e7f8a9-b0c1-2345-defa-456789012345",
      "permission_type": "location",
      "platform": "ios",
      "status": "denied",
      "denied_at": "2026-01-15T10:07:00Z",
      "last_checked_at": "2026-06-15T09:00:00Z"
    }
  ],
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:37:00Z"
  }
}
```

---

#### `PUT /permissions/{permission_type}`

Update the recorded status for a specific permission type. Called by the mobile client after an OS permission prompt resolves.

- **Auth Required:** Yes

**Path Parameters:** `permission_type` — e.g., `calendar_read`, `microphone`, `notifications`

**Request Body:**

| Field      | Type   | Required | Description                                                   |
|------------|--------|----------|---------------------------------------------------------------|
| `status`   | string | Yes      | `granted`, `denied`, `not_requested`, `restricted`            |
| `platform` | string | Yes      | `ios`, `android`, `web`                                       |

**Example Request:**

```bash
curl -X PUT https://api.aria.ai/v1/permissions/notifications \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "status": "granted",
    "platform": "ios"
  }'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "permission_type": "notifications",
    "platform": "ios",
    "status": "granted",
    "granted_at": "2026-06-15T10:38:00Z",
    "last_checked_at": "2026-06-15T10:38:00Z"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:38:00Z"
  }
}
```

---

### 5.10 Notification Endpoints

---

#### `GET /notifications`

Retrieve the authenticated user's notifications.

- **Auth Required:** Yes

**Query Parameters:**

| Parameter  | Type    | Description                                                          |
|------------|---------|----------------------------------------------------------------------|
| `type`     | string  | Filter by type: `meeting_reminder`, `task_due`, `travel_alert`, etc. |
| `read`     | boolean | `false` returns only unread; `true` only read; omit for all          |
| `page`     | integer | Page number (default: 1)                                             |
| `per_page` | integer | Results per page (default: 20, max: 100)                             |

**Example Request:**

```bash
curl "https://api.aria.ai/v1/notifications?read=false&per_page=10" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Example Response — 200 OK:**

```json
{
  "data": [
    {
      "id": "e7f8a9b0-c1d2-3456-efab-567890123456",
      "type": "meeting_reminder",
      "title": "1:1 with Sarah in 15 minutes",
      "body": "Conference Room B — 3:00 PM — 1 attendee",
      "priority": "high",
      "channel": "push",
      "related_entity_type": "event",
      "related_entity_id": "d0e1f2a3-b4c5-6789-defa-789012345678",
      "sent_at": "2026-06-16T14:45:00Z",
      "delivered_at": "2026-06-16T14:45:02Z",
      "read_at": null,
      "created_at": "2026-06-16T14:45:00Z"
    }
  ],
  "meta": {
    "total": 4,
    "page": 1,
    "per_page": 10,
    "total_pages": 1,
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:39:00Z"
  }
}
```

---

#### `PUT /notifications/{id}/read`

Mark a single notification as read.

- **Auth Required:** Yes
- **Responses:** `200 OK`, `404 NOT_FOUND`

**Example Request:**

```bash
curl -X PUT https://api.aria.ai/v1/notifications/e7f8a9b0-c1d2-3456-efab-567890123456/read \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

#### `PUT /notifications/read-all`

Mark all unread notifications as read for the authenticated user.

- **Auth Required:** Yes

**Example Response — 200 OK:**

```json
{
  "data": {
    "marked_read": 4
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:40:00Z"
  }
}
```

---

#### `DELETE /notifications/{id}`

Delete a single notification.

- **Auth Required:** Yes
- **Responses:** `204 No Content`, `404 NOT_FOUND`

---

#### `PUT /notifications/preferences`

Update the user's notification delivery preferences.

- **Auth Required:** Yes

**Request Body (all fields optional):**

| Field                  | Type    | Description                                              |
|------------------------|---------|----------------------------------------------------------|
| `enabled_types`        | array   | List of notification types to enable (all others disabled) |
| `quiet_hours_start`    | string  | Time in `HH:MM` format (24h) for quiet hours start       |
| `quiet_hours_end`      | string  | Time in `HH:MM` format (24h) for quiet hours end         |
| `push_enabled`         | boolean | Master toggle for push notifications                     |
| `sms_enabled`          | boolean | Master toggle for SMS notifications                      |

**Example Request:**

```bash
curl -X PUT https://api.aria.ai/v1/notifications/preferences \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "enabled_types": ["meeting_reminder", "task_due", "travel_alert", "morning_briefing"],
    "quiet_hours_start": "22:00",
    "quiet_hours_end": "07:00",
    "push_enabled": true,
    "sms_enabled": false
  }'
```

**Example Response — 200 OK:** *(updated preferences object)*

---

#### `POST /notifications/device-token`

Register or update a push notification device token (APNs for iOS, FCM for Android).

- **Auth Required:** Yes

**Request Body:**

| Field      | Type   | Required | Description                              |
|------------|--------|----------|------------------------------------------|
| `token`    | string | Yes      | The device token from APNs or FCM        |
| `platform` | string | Yes      | `ios` or `android`                       |

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/notifications/device-token \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "token": "d3a4f5e6b7c8...",
    "platform": "ios"
  }'
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "message": "Device token registered successfully.",
    "platform": "ios"
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:41:00Z"
  }
}
```

---

### 5.11 Voice Endpoints

---

#### `POST /voice/transcribe`

Transcribe an audio file using OpenAI Whisper. Accepts common audio formats (m4a, mp3, wav, ogg, webm).

- **Auth Required:** Yes
- **Content-Type:** `multipart/form-data`
- **Max file size:** 25 MB
- **Subscription Required:** Voice transcription available on all tiers; batch transcription on `pro`+

**Form Fields:**

| Field      | Type   | Required | Description                                        |
|------------|--------|----------|----------------------------------------------------|
| `audio`    | file   | Yes      | Audio file (m4a, mp3, wav, ogg, webm)              |
| `language` | string | No       | BCP 47 language hint (e.g., `en`, `ja`). Auto-detected if omitted |

**Responses:** `200 OK`, `400 VALIDATION_ERROR` (invalid file format), `413` (file too large)

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/voice/transcribe \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -F "audio=@recording.m4a" \
  -F "language=en"
```

**Example Response — 200 OK:**

```json
{
  "data": {
    "transcript": "Add a task to follow up with the design team about the new onboarding screens by Friday.",
    "confidence": 0.97,
    "duration_seconds": 4.8,
    "language_detected": "en",
    "word_count": 19
  },
  "meta": {
    "request_id": "req_01HX7K9MABCDEF",
    "timestamp": "2026-06-15T10:42:00Z"
  }
}
```

---

#### `POST /voice/process`

Process a voice transcript through the ARIA conversation engine. Equivalent to sending a text message, but optimized for voice input: ARIA is aware the input came from speech and calibrates response length accordingly.

- **Auth Required:** Yes

**Request Body:**

| Field             | Type   | Required | Description                                          |
|-------------------|--------|----------|------------------------------------------------------|
| `transcript`      | string | Yes      | The transcribed text from voice input                |
| `conversation_id` | UUID   | No       | Existing conversation to continue; creates new if omitted |

**Example Request:**

```bash
curl -X POST https://api.aria.ai/v1/voice/process \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "transcript": "Add a task to follow up with the design team about the new onboarding screens by Friday.",
    "conversation_id": "e5f6a7b8-c9d0-1234-efab-234567890123"
  }'
```

**Example Response — 200 OK:** *(same schema as `POST /conversations/{id}/messages`)*

---

#### `GET /voice/tts`

Convert text to speech using ARIA's voice synthesis engine. Returns an audio stream.

- **Auth Required:** Yes
- **Response Content-Type:** `audio/mpeg`
- **Subscription Required:** `pro` or `enterprise`

**Query Parameters:**

| Parameter | Type   | Description                                        |
|-----------|--------|----------------------------------------------------|
| `text`    | string | Text to synthesize (max 500 characters)            |
| `voice`   | string | Voice preset to use (default: `aria`). Options: `aria`, `nova`, `echo` |

**Example Request:**

```bash
curl "https://api.aria.ai/v1/voice/tts?text=Your%20meeting%20starts%20in%2015%20minutes.&voice=aria" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." \
  --output response.mp3
```

**Response:** Binary MP3 audio stream (`audio/mpeg`) with headers:
```
Content-Type: audio/mpeg
Content-Disposition: inline; filename="aria_tts.mp3"
Cache-Control: no-store
X-Audio-Duration: 2.4
```

---

## 6. Webhook Events (Future)

ARIA plans to expose an outbound webhook system in v1.1. Partner integrations and enterprise customers will be able to register a HTTPS endpoint to receive real-time event notifications.

**Planned Webhook Event Types:**

| Event Type                  | Description                                               |
|-----------------------------|-----------------------------------------------------------|
| `task.created`              | A new task was created (by the user or by ARIA)           |
| `task.completed`            | A task was marked completed                               |
| `task.overdue`              | A task has passed its due date without being completed    |
| `event.created`             | A new calendar event was added                            |
| `event.updated`             | An existing event was modified                            |
| `event.upcoming`            | An event is starting within 60 minutes                    |
| `event.cancelled`           | An event was cancelled                                    |
| `travel.disruption_detected`| A flight delay, cancellation, or gate change was detected |
| `travel.status_changed`     | A travel plan's status changed (e.g., planning → booked)  |
| `memory.created`            | A new memory was extracted and stored                     |
| `conversation.ended`        | A conversation ended and a summary was generated          |
| `integration.sync_failed`   | A calendar or integration sync failed                     |

**Webhook Delivery:**
- HTTPS POST to registered endpoint
- Payload signed with HMAC-SHA256 using the client's webhook secret
- Signature in `X-ARIA-Signature-256` header
- 3 retries with exponential backoff (5s, 30s, 5min)
- Delivery timeout: 10 seconds

---

## 7. SDKs & Client Libraries

Official ARIA SDK support is planned for the following languages:

| Language / Platform | Package                   | Status        | Minimum Version       |
|---------------------|---------------------------|---------------|-----------------------|
| Python              | `aria-sdk`                | In development | Python 3.10+          |
| TypeScript / JS     | `@aria-ai/sdk`            | In development | Node 18+ / Edge runtime |
| Swift               | `ARIAKit` (Swift Package) | Planned Q4 2026 | iOS 16+, Swift 5.9   |

All SDKs will:
- Handle token refresh automatically (including race condition protection)
- Expose typed response models
- Support async/await patterns natively
- Include retry logic with exponential backoff for 429 and 503 responses
- Provide streaming support for conversation message responses

---

## Appendix

### A. OpenAPI Specification

The machine-readable OpenAPI 3.0 specification is maintained alongside this document:

```
/home/user/ARIA/docs/openapi.yaml
```

The spec is auto-generated from FastAPI's router definitions and augmented with example payloads. It can be viewed interactively at:

- **Development:** `http://localhost:8000/docs` (Swagger UI)
- **Development:** `http://localhost:8000/redoc` (ReDoc)
- **Production:** Access restricted to `enterprise` tier API keys at `https://api.aria.ai/docs`

### B. Postman Collection

A maintained Postman collection covering all endpoints with pre-request scripts for automatic token refresh is available at:

```
/home/user/ARIA/docs/ARIA_API.postman_collection.json
```

Environment templates for `local`, `staging`, and `production` are included.

### C. Changelog

| Version | Date       | Changes                                                              |
|---------|------------|----------------------------------------------------------------------|
| 1.0.0   | 2026-06-15 | Initial production release. All endpoints documented.               |
