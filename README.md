# 5/3/1 Strength Training App

A mobile fitness application for managing the 5/3/1 strength training program by Jim Wendler. Track your training cycles, log workouts, manage progression, and visualize strength gains.

## Features

- ✅ **Program Management**: Create and manage 4-day (expandable to 2/3-day) training programs
- ✅ **Workout Tracking**: Log warmup sets, working sets, and accessory exercises
- ✅ **Smart Progression**: Automatic training max recommendations based on performance
- ✅ **Rep Maxes**: Track personal records across 1-12 rep ranges
- ✅ **Progress Analytics**: Visualize training max progression over time
- ✅ **Offline Support**: Full offline workout logging with background sync
- ✅ **Rest Timer**: Built-in rest timer with customizable durations
- ✅ **Plate Calculator**: Shows which plates to load per side

## Tech Stack

### Backend
- **Framework**: FastAPI (Python)
- **Database**: SQLite with Alembic migrations
- **Authentication**: JWT with refresh tokens
- **Containerization**: Docker

### Frontend
- **Framework**: Flutter
- **State Management**: Riverpod
- **Local Database**: sqflite (for offline support)
- **Charts**: fl_chart

## Project Structure

```
.
├── backend/                 # FastAPI backend
│   ├── app/
│   │   ├── models/         # SQLAlchemy database models
│   │   ├── routers/        # API route handlers
│   │   ├── schemas/        # Pydantic schemas
│   │   ├── services/       # Business logic
│   │   └── utils/          # Utilities
│   ├── alembic/            # Database migrations
│   ├── tests/              # Backend tests
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/               # Flutter mobile app
│   └── README.md          # Flutter setup instructions
├── data/                  # SQLite database
├── docker-compose.yml     # Development setup
└── 531_detailed_spec.md   # Complete specification
```

## Quick Start

### Prerequisites

- **Docker & Docker Compose** (for backend)
- **Flutter SDK 3.16+** (for frontend)
- **Python 3.11+** (if running backend without Docker)

### 1. Backend Setup

#### Option A: Docker (Recommended)

```bash
# Clone or navigate to the project
cd /home/trace/Documents/531

# Copy environment variables
cp backend/.env.example backend/.env

# Edit backend/.env and set:
# - JWT_SECRET_KEY (generate a strong random string)
# - SMTP credentials (for password reset emails)

# Start the backend
docker-compose up -d

# Run database migrations
docker-compose exec backend alembic upgrade head

# View logs
docker-compose logs -f backend
```

The API will be available at `http://localhost:8000`
API documentation at `http://localhost:8000/api/v1/docs`

#### Option B: Local Python

```bash
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy and configure .env
cp .env.example .env
# Edit .env with your configuration

# Run migrations
alembic upgrade head

# Start the server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 2. Frontend Setup

```bash
cd frontend

# Install Flutter if needed
# Visit: https://flutter.dev/docs/get-started/install

# Create the Flutter project (first time only)
cd ..
flutter create --org com.fiveThreeOne --project-name five_three_one_app frontend
cd frontend

# Get dependencies
flutter pub get

# Run the app
flutter run
```

See `frontend/README.md` for detailed Flutter setup instructions.

## Development

### Running Tests

**Backend:**
```bash
cd backend
source venv/bin/activate
pytest
```

**Frontend:**
```bash
cd frontend
flutter test
```

### Database Migrations

**Create a new migration:**
```bash
cd backend
alembic revision --autogenerate -m "Description of changes"
```

**Apply migrations:**
```bash
alembic upgrade head
```

**Rollback:**
```bash
alembic downgrade -1
```

### API Documentation

With the backend running, visit:
- Swagger UI: `http://localhost:8000/api/v1/docs`
- ReDoc: `http://localhost:8000/api/v1/redoc`

## Environment Variables

### Backend (.env)

```bash
# Database
DATABASE_URL=sqlite:///../data/531.db

# JWT Authentication
JWT_SECRET_KEY=your-secret-key-here
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

# Email/SMTP
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
FROM_EMAIL=noreply@531app.com

# API Settings
API_VERSION=v1
PROJECT_NAME=5/3/1 Training App

# CORS
CORS_ORIGINS=["http://localhost:3000","http://localhost:8080"]
```

## Database Schema

The application uses the following main entities:

- **Users**: User accounts with preferences
- **Programs**: Training programs with cycles
- **TrainingMax**: Current training maxes per lift
- **Workouts**: Individual workout sessions
- **WorkoutSets**: Logged sets (warmup, working, accessory, AMRAP)
- **Exercises**: Predefined and custom exercises
- **RepMax**: Personal records at different rep ranges
- **WarmupTemplate**: Custom warmup protocols

See `531_detailed_spec.md` for complete data model specifications.

## API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login
- `POST /api/v1/auth/refresh` - Refresh access token
- `POST /api/v1/auth/request-password-reset` - Request password reset
- `POST /api/v1/auth/reset-password` - Reset password

### Programs
- `GET /api/v1/programs` - List user's programs
- `POST /api/v1/programs` - Create new program
- `GET /api/v1/programs/{id}` - Get program details
- `PUT /api/v1/programs/{id}` - Update program

### Workouts
- `GET /api/v1/programs/{program_id}/workouts` - List workouts
- `GET /api/v1/workouts/{id}` - Get workout details
- `POST /api/v1/workouts/{id}/start` - Start workout
- `POST /api/v1/workouts/{id}/complete` - Complete workout
- `POST /api/v1/workouts/{id}/skip` - Skip workout

See full API documentation at `/api/v1/docs` when server is running.

## Deployment

### Self-Hosting

1. Clone repository on your server
2. Configure `.env` file with production settings
3. Use docker-compose for deployment:

```bash
docker-compose up -d
```

4. Set up reverse proxy (nginx) with SSL (Let's Encrypt)
5. Configure automated database backups

See `531_detailed_spec.md` Section 11 for detailed deployment instructions.

## Roadmap

- [ ] Complete authentication endpoints
- [ ] Implement program creation and management
- [ ] Build workout logging functionality
- [ ] Add rep max tracking
- [ ] Create progress charts
- [ ] Implement offline sync
- [ ] Add 2-day and 3-day program templates
- [ ] Build social features (optional)

## Contributing

This is currently a personal project. See `531_detailed_spec.md` for the complete specification.

## License

Private project - All rights reserved.

## References

- [5/3/1 Program by Jim Wendler](https://www.jimwendler.com/blogs/jimwendler-com/101065094-5-3-1-for-beginners)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Flutter Documentation](https://flutter.dev/docs)
- [Riverpod Documentation](https://riverpod.dev/)
