# ARIA — Adaptive Real-time Intelligence System

> Your personal AI assistant that knows your schedule, remembers your preferences, and acts before you ask.

---

## What is ARIA?

ARIA is a production-ready AI personal assistant mobile application designed to reduce cognitive overhead in daily life. It integrates with your calendar, email, maps, and communication tools to provide proactive, context-aware assistance — not just reactive responses to explicit commands.

Unlike generic chatbots, ARIA builds a persistent memory of your preferences, routines, and relationships. It detects upcoming meetings, monitors travel disruptions, surfaces relevant information at the right moment, and learns from every interaction to become progressively more useful over time.

---

## Key Features

| Feature | Description |
|---|---|
| **Conversational AI** | Natural language interaction powered by Claude, with full conversation history and context |
| **Persistent Memory** | Semantic vector memory stores facts, preferences, and past decisions for long-term personalization |
| **Meeting Intelligence** | Detects meetings from calendar, prepares briefings, captures action items, sends follow-ups |
| **Smart Task Management** | Creates, prioritizes, and tracks tasks with deadline inference and dependency detection |
| **Travel Planning** | End-to-end trip planning with real-time flight/hotel search and disruption alerts |
| **Proactive Notifications** | Pushes timely reminders and suggestions without requiring explicit prompts |
| **Voice Commands** | Always-on wake-word detection with sub-300ms response latency |
| **Privacy Controls** | Granular data control, on-device processing options, and full audit logs |
| **Third-party Integrations** | Google Calendar, Outlook, Gmail, Slack, Notion, and more |

---

## Technology Stack

### Mobile
- **React Native** (iOS + Android) with Expo
- **TypeScript** throughout
- **React Query** for server state management
- **Zustand** for local state
- **Expo AV** for audio recording/playback

### Backend
- **FastAPI** (Python 3.11+) — async, high-throughput API server
- **PostgreSQL 15** — primary relational database
- **Qdrant** — vector database for semantic memory search
- **Redis** — caching, session management, pub/sub for real-time events
- **Celery + Redis** — asynchronous task queue for background jobs

### AI / ML
- **Anthropic Claude API** — conversational reasoning and tool use
- **Whisper (OpenAI)** — speech-to-text transcription
- **sentence-transformers** — local embedding generation
- **LangChain** — orchestration for multi-step agent flows

### Infrastructure
- **AWS** (ECS Fargate, RDS, ElastiCache, S3, CloudFront)
- **Docker + Docker Compose** for local development
- **GitHub Actions** for CI/CD
- **Terraform** for infrastructure as code

---

## Project Structure

```
ARIA/
├── README.md
├── docs/
│   ├── PRD.md                 # Product Requirements Document
│   ├── ARCHITECTURE.md        # System architecture and design
│   ├── DATABASE_SCHEMA.md     # Full database schema (PostgreSQL + Qdrant)
│   ├── API_SPEC.md            # RESTful API specification
│   ├── ROADMAP.md             # Development roadmap and milestones
│   └── USER_JOURNEYS.md       # End-to-end user journey maps
├── mobile/                    # React Native application
│   ├── src/
│   │   ├── screens/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/
│   │   ├── store/
│   │   └── utils/
│   ├── app.json
│   └── package.json
├── backend/                   # FastAPI server
│   ├── app/
│   │   ├── api/
│   │   │   └── v1/
│   │   │       ├── auth.py
│   │   │       ├── conversations.py
│   │   │       ├── tasks.py
│   │   │       ├── events.py
│   │   │       ├── memories.py
│   │   │       ├── travel.py
│   │   │       ├── integrations.py
│   │   │       └── notifications.py
│   │   ├── core/
│   │   │   ├── config.py
│   │   │   ├── security.py
│   │   │   └── database.py
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/
│   │   │   ├── ai_engine.py
│   │   │   ├── memory_service.py
│   │   │   ├── calendar_service.py
│   │   │   └── travel_service.py
│   │   └── workers/
│   ├── alembic/               # Database migrations
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
├── infra/                     # Terraform / IaC
│   ├── modules/
│   └── environments/
├── scripts/                   # Dev and ops scripts
└── docker-compose.yml
```

---

## Quick Start

### Prerequisites

- Node.js 18+, npm or yarn
- Python 3.11+
- Docker and Docker Compose
- Expo CLI (`npm install -g expo-cli`)
- An Anthropic API key

### 1. Clone and install dependencies

```bash
git clone https://github.com/your-org/aria.git
cd aria

# Backend
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Mobile
cd ../mobile
npm install
```

### 2. Configure environment

```bash
# Backend
cp backend/.env.example backend/.env
# Edit .env with your database credentials, API keys, etc.

# Mobile
cp mobile/.env.example mobile/.env
# Set EXPO_PUBLIC_API_URL to your backend URL
```

### 3. Start infrastructure services

```bash
docker-compose up -d postgres redis qdrant
```

### 4. Initialize the database

```bash
cd backend
alembic upgrade head
python scripts/seed_data.py  # optional dev data
```

### 5. Start the backend server

```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

### 6. Start the mobile app

```bash
cd mobile
expo start
# Scan the QR code with Expo Go, or press 'i' for iOS simulator / 'a' for Android emulator
```

---

## Documentation

| Document | Description |
|---|---|
| [PRD](docs/PRD.md) | Product requirements, user stories, success metrics |
| [Architecture](docs/ARCHITECTURE.md) | System design, component diagrams, technology decisions |
| [Database Schema](docs/DATABASE_SCHEMA.md) | Full database schema with DDL |
| [API Specification](docs/API_SPEC.md) | All REST endpoints with request/response schemas |
| [Roadmap](docs/ROADMAP.md) | Development phases, milestones, monetization |
| [User Journeys](docs/USER_JOURNEYS.md) | End-to-end user journey maps |

---

## Development Workflow

1. **Branching**: Use `feature/<short-description>`, `fix/<issue>`, or `chore/<task>` prefixes
2. **Commits**: Follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`)
3. **PRs**: All PRs require one approval and passing CI before merge
4. **Testing**: Maintain >80% unit test coverage; E2E tests cover all P0 user journeys
5. **Releases**: Tagged releases via GitHub Actions; semantic versioning (`MAJOR.MINOR.PATCH`)

---

## Environment Variables

### Backend (`.env`)

```
# Database
DATABASE_URL=postgresql+asyncpg://aria:password@localhost:5432/aria_db
QDRANT_URL=http://localhost:6333
REDIS_URL=redis://localhost:6379

# Auth
SECRET_KEY=your-secret-key-min-32-chars
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=30

# AI
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...         # for Whisper STT

# Integrations
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
MICROSOFT_CLIENT_ID=...
MICROSOFT_CLIENT_SECRET=...

# AWS
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
S3_BUCKET_NAME=aria-media

# Push notifications
APNS_KEY_ID=...
APNS_TEAM_ID=...
FCM_SERVER_KEY=...
```

---

## Testing

```bash
# Backend unit tests
cd backend
pytest tests/unit/ -v --cov=app

# Backend integration tests (requires running services)
pytest tests/integration/ -v

# Mobile unit tests
cd mobile
npm test

# E2E tests (requires full stack running)
cd e2e
npx detox test --configuration ios.sim.debug
```

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes with tests
4. Run the full test suite
5. Submit a pull request with a clear description

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on code style, commit messages, and the PR review process.

---

## License

Copyright © 2024 ARIA Technologies, Inc. All rights reserved.

This software is proprietary. See [LICENSE](LICENSE) for details.

---

## Contact

- **Product**: product@aria.ai
- **Engineering**: engineering@aria.ai
- **Security issues**: security@aria.ai (please do not open public issues for vulnerabilities)
