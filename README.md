# 5/3/1 Strength Training App

A cross-platform mobile and web app for running Jim Wendler's 5/3/1 strength training program. The app manages multi-week training cycles, generates prescribed sets/weights automatically, logs workouts, and tracks strength progress over time.

## Features

- **Program Management**: Create 2-, 3-, or 4-day training programs with configurable training days, optional deload weeks, and per-day main lift assignments
- **Workout Logging**: Log warmup sets, working sets, AMRAP sets, and accessory exercises with actual reps and weight
- **Auto-Progression**: Training maxes update automatically at cycle completion based on program rules and AMRAP performance
- **Rep Max Tracking**: Record and track personal bests across 1–12 rep ranges
- **Progress Analytics**: Chart training max history per lift to visualize strength gains over time
- **Warmup Templates**: Customizable warmup protocols generated as a percentage of the day's training max
- **Accessory Exercises**: Per-day accessory work with configurable sets, reps, and weight
- **Plate Calculator**: Displays which plates to load per side for any given weight
- **Rest Timer**: Built-in rest timer with audio cues
- **Offline Support**: Full offline workout logging with background sync

## Architecture

```
frontend/          Flutter app (mobile + web)
  lib/
    screens/       UI screens (auth, home, programs, workouts, progress, settings)
    providers/     Riverpod state providers
    services/      API client (Dio), audio, workout session management
    models/        Dart data classes
    widgets/       Reusable UI components

backend/           FastAPI REST API
  app/
    routers/       HTTP route handlers (auth, users, programs, workouts, exercises,
                   rep_maxes, warmup_templates, analytics)
    services/      Business logic layer
    models/        SQLAlchemy ORM models
    schemas/       Pydantic request/response schemas
    utils/         JWT security, dependencies, weight calculations
  alembic/         Database migrations
  tests/           Pytest test suite

Book/              Scanned reference pages from the 5/3/1 book (01–33 chapters)
data/              SQLite database file (development)
docker-compose.yml Local development stack
```

### Backend

| Layer | Technology |
|---|---|
| Framework | FastAPI (Python 3.11) |
| ORM | SQLAlchemy 2.0 |
| Migrations | Alembic |
| Auth | JWT (python-jose) with refresh tokens |
| Database (dev) | SQLite |
| Database (prod) | PostgreSQL (RDS) |
| Containerization | Docker |

### Frontend

| Layer | Technology |
|---|---|
| Framework | Flutter 3.16+ (Dart) |
| State Management | Riverpod |
| HTTP Client | Dio |
| Charts | fl_chart |
| Secure Storage | flutter_secure_storage |
| Navigation | go_router |

### Production Deployment (AWS)

```
[Route 53] → [CloudFront] → [S3]           (Flutter web build)
                  ↓
            [ALB] → [ECS Fargate]           (FastAPI, Docker)
                         ↓
                    [RDS PostgreSQL]
```

For mobile-only deployments, App Runner replaces ALB + ECS and provides automatic HTTPS. See `scripts/aws/aws_instructions.md` for full setup steps.

## Data Model

| Entity | Purpose |
|---|---|
| `User` | Account with email/password and preferences |
| `Program` | Training program (template type, training days, deload flag) |
| `TrainingMax` | Current 1RM training max per lift per program |
| `TrainingMaxHistory` | Audit log of all training max changes |
| `ProgramTemplate` | Which main lift maps to each training day |
| `ProgramDayAccessories` | Accessory exercises configured per day |
| `Workout` | A single session (cycle/week/status) |
| `WorkoutMainLift` | Junction between workout and its main lift(s) |
| `WorkoutSet` | Individual logged set (warmup / working / AMRAP / accessory) |
| `Exercise` | Exercise library (predefined + custom) |
| `RepMax` | PR at a given rep range |
| `WarmupTemplate` | Custom warmup percentage schemes |

## Quick Start

### Prerequisites

- Docker & Docker Compose (backend)
- Flutter SDK 3.16+ (frontend)
- Python 3.11+ (if running backend without Docker)

### 1. Backend

```bash
# Copy and configure environment
cp backend/.env.example backend/.env
# Set JWT_SECRET_KEY and SMTP credentials in backend/.env

# Start with Docker
docker-compose up -d
docker-compose exec backend alembic upgrade head

# OR run locally
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API: `http://localhost:8000`
Swagger docs: `http://localhost:8000/api/v1/docs`

### 2. Frontend

```bash
cd frontend
flutter pub get
flutter run
```

The app expects the backend at `http://localhost:8000/api/v1` by default. To override:

```bash
flutter run --dart-define=API_BASE_URL=https://your-backend.example.com/api/v1
```

## Development

### Running Tests

```bash
# Backend
cd backend && source venv/bin/activate
pytest
pytest --cov=app tests/   # with coverage

# Frontend
cd frontend
flutter test
```

### Database Migrations

```bash
cd backend
alembic revision --autogenerate -m "description"  # generate
alembic upgrade head                               # apply
alembic downgrade -1                               # rollback one
```

## Environment Variables

```bash
# backend/.env
DATABASE_URL=sqlite:///../data/531.db
JWT_SECRET_KEY=<strong-random-string>
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
FROM_EMAIL=noreply@531app.com
API_VERSION=v1
PROJECT_NAME=5/3/1 Training App
```

## API Reference

| Tag | Endpoints |
|---|---|
| Auth | `POST /auth/register`, `/auth/login`, `/auth/refresh`, `/auth/request-password-reset`, `/auth/reset-password` |
| Users | `GET/PUT /users/me` |
| Programs | `GET/POST /programs`, `GET/PUT/DELETE /programs/{id}`, training max and template sub-routes |
| Workouts | `GET /programs/{id}/workouts`, `GET/PUT /workouts/{id}`, `/workouts/{id}/start`, `/complete`, `/skip` |
| Exercises | `GET/POST /exercises`, `GET/PUT/DELETE /exercises/{id}` |
| Rep Maxes | `GET/POST /rep-maxes`, `GET/PUT/DELETE /rep-maxes/{id}` |
| Warmup Templates | `GET/POST /warmup-templates`, `GET/PUT/DELETE /warmup-templates/{id}` |
| Analytics | `GET /analytics/training-max-history`, `/analytics/workout-summary` |

Full interactive docs available at `/api/v1/docs` when the server is running.

## References

- [5/3/1 by Jim Wendler](https://www.jimwendler.com/)
- [FastAPI docs](https://fastapi.tiangolo.com/)
- [Flutter docs](https://flutter.dev/docs)
- [Riverpod docs](https://riverpod.dev/)
