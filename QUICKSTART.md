# Quick Start Guide

## Immediate Next Steps

### 1. Start the Backend (Right Now!)

```bash
cd /home/trace/Documents/531/backend

# Activate virtual environment
source venv/bin/activate

# Run database migrations
alembic upgrade head

# Start the development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Visit: `http://localhost:8000/api/v1/docs` to see the API documentation

### 2. What to Build Next

#### Phase 1: Authentication (Week 1)

**Priority endpoints to implement:**

1. **User Registration** (`POST /api/v1/auth/register`)
   - Create file: `backend/app/routers/auth.py`
   - Create file: `backend/app/schemas/auth.py`
   - Create file: `backend/app/services/auth.py`
   - Create file: `backend/app/utils/security.py` (password hashing, JWT)

2. **User Login** (`POST /api/v1/auth/login`)

3. **Token Refresh** (`POST /api/v1/auth/refresh`)

**Files to create:**

```python
# backend/app/utils/security.py
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: timedelta = None):
    # Implementation here
    pass
```

```python
# backend/app/schemas/auth.py
from pydantic import BaseModel, EmailStr

class UserRegister(BaseModel):
    first_name: str
    last_name: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
```

```python
# backend/app/routers/auth.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db

router = APIRouter()

@router.post("/register")
async def register(user: UserRegister, db: Session = Depends(get_db)):
    # Implementation
    pass

@router.post("/login")
async def login(user: UserLogin, db: Session = Depends(get_db)):
    # Implementation
    pass
```

Then add to `backend/app/main.py`:
```python
from app.routers import auth

app.include_router(auth.router, prefix=f"/api/{settings.API_VERSION}/auth", tags=["auth"])
```

#### Phase 2: User & Program Management (Week 2)

1. **User Endpoints**
   - `GET /api/v1/users/me`
   - `PUT /api/v1/users/me`

2. **Program Creation**
   - `POST /api/v1/programs`
   - `GET /api/v1/programs`

#### Phase 3: Workout Execution (Weeks 3-4)

1. **Workout Endpoints**
2. **Set Logging**
3. **AMRAP Detection**

### 3. Testing as You Build

```bash
# Create test file for each feature
# backend/tests/test_auth.py

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_register_user():
    response = client.post(
        "/api/v1/auth/register",
        json={
            "first_name": "John",
            "last_name": "Doe",
            "email": "john@example.com",
            "password": "SecurePass123"
        }
    )
    assert response.status_code == 201
    assert "access_token" in response.json()

# Run tests
pytest
```

### 4. Frontend (Parallel Development)

Once authentication endpoints are working:

```bash
cd /home/trace/Documents/531

# Install Flutter and create project
flutter create --org com.fiveThreeOne --project-name five_three_one_app frontend

cd frontend

# Add dependencies (see frontend/README.md)
flutter pub add flutter_riverpod dio flutter_secure_storage

# Create initial structure
mkdir -p lib/features/auth/{data,domain,presentation}
mkdir -p lib/core/{config,router,theme}
mkdir -p lib/shared/{models,providers,services,widgets}

# Start development
flutter run
```

## Development Workflow

1. **Pick a feature** from the spec (531_detailed_spec.md)
2. **Create the database model** (if new) in `backend/app/models/`
3. **Create migration**: `alembic revision --autogenerate -m "Add feature"`
4. **Apply migration**: `alembic upgrade head`
5. **Create Pydantic schemas** in `backend/app/schemas/`
6. **Implement business logic** in `backend/app/services/`
7. **Create API endpoints** in `backend/app/routers/`
8. **Write tests** in `backend/tests/`
9. **Test manually** via `http://localhost:8000/api/v1/docs`
10. **Build frontend** to consume the API

## Useful Commands

```bash
# Backend
cd backend
source venv/bin/activate
alembic revision --autogenerate -m "message"  # Create migration
alembic upgrade head                           # Apply migrations
alembic downgrade -1                          # Rollback one migration
pytest                                         # Run tests
pytest --cov=app tests/                       # Run tests with coverage

# Frontend
cd frontend
flutter pub get                               # Install dependencies
flutter run                                   # Run app
flutter test                                  # Run tests
flutter build apk                            # Build Android APK

# Docker
docker-compose up -d                         # Start all services
docker-compose logs -f backend              # View backend logs
docker-compose exec backend alembic upgrade head  # Run migrations in container
docker-compose down                         # Stop all services
```

## Tips

- **Use the spec**: Reference `531_detailed_spec.md` for exact API contracts
- **Start simple**: Get one endpoint working end-to-end before building many
- **Test early**: Write tests as you go, not at the end
- **Database first**: Models → Migration → Schema → Service → Router
- **Check examples**: Look at FastAPI docs for patterns
- **Frontend later**: Build working API first, then consume it

## Next Steps After Initial Setup

1. Implement authentication endpoints (register, login, refresh)
2. Test with curl or Postman
3. Create user management endpoints
4. Build program creation workflow
5. Move to Flutter frontend

Good luck! 🚀
