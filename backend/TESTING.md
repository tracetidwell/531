# Backend Testing Guide

## Overview

This document describes the testing infrastructure for the 5/3/1 Training App backend.

## Test Structure

```
backend/tests/
├── conftest.py              # Shared fixtures and configuration
├── test_auth.py             # Authentication tests (register, login, refresh)
├── test_programs.py         # Program CRUD tests
├── test_exercises.py        # Exercise listing and creation tests
├── test_workouts.py         # Workout listing, detail, skip tests
├── test_workout_completion.py # Workout completion, AMRAP, PR detection
├── test_rep_maxes.py        # Rep max/PR retrieval tests
├── test_analytics.py        # Training max progression tests
├── test_warmup_templates.py # Warmup template CRUD tests
└── test_calculations.py     # Unit tests for calculation utilities
```

## Running Tests

### Quick Start

```bash
# Run all tests
./run_tests.sh

# Run all tests with verbose output
./run_tests.sh -v

# Run with coverage report
./run_tests.sh --cov
```

### Manual Commands

```bash
# Run all tests
pytest

# Run with verbose output
pytest -v

# Run specific test file
pytest tests/test_workouts.py

# Run specific test class
pytest tests/test_workouts.py::TestWorkoutListing

# Run specific test
pytest tests/test_workouts.py::TestWorkoutListing::test_list_workouts_success

# Run tests matching pattern
pytest -k "amrap"

# Run with coverage
pytest --cov=app --cov-report=term-missing

# Run with HTML coverage report
pytest --cov=app --cov-report=html
# Open htmlcov/index.html in browser
```

## Test Categories

### Unit Tests
Test individual functions in isolation:
- `test_calculations.py` - Epley formula, weight calculations, warmup generation

### Integration Tests
Test API endpoints with database:
- `test_auth.py` - Authentication flow
- `test_programs.py` - Program CRUD
- `test_exercises.py` - Exercise management
- `test_workouts.py` - Workout operations
- `test_rep_maxes.py` - Personal records
- `test_analytics.py` - Analytics endpoints
- `test_warmup_templates.py` - Warmup templates

### Complex Flow Tests
Test multi-step business logic:
- `test_workout_completion.py` - Complete workout → AMRAP detection → PR creation → Analysis

## Test Database

Tests use an isolated SQLite database (not your development/production PostgreSQL):

```python
# From conftest.py
DATABASE_URL = f"sqlite:///{test_db_path}"
```

Each test gets a clean database via the `cleanup_db` fixture.

## Writing New Tests

### Basic Test Structure

```python
import pytest
from fastapi.testclient import TestClient

class TestFeatureName:
    """Tests for feature name."""

    def test_success_case(self, client, auth_headers):
        """Test the happy path."""
        response = client.get("/api/v1/endpoint", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "expected_key" in data

    def test_unauthorized(self, client):
        """Test without authentication."""
        response = client.get("/api/v1/endpoint")
        assert response.status_code == 403

    def test_not_found(self, client, auth_headers):
        """Test with invalid ID."""
        response = client.get("/api/v1/endpoint/invalid-id", headers=auth_headers)
        assert response.status_code == 404
```

### Available Fixtures

| Fixture | Description |
|---------|-------------|
| `db` | SQLAlchemy database session |
| `client` | FastAPI TestClient |
| `test_user` | Pre-created test user |
| `auth_headers` | Authentication headers for test user |
| `test_program_with_workouts` | Complete program with training maxes |
| `scheduled_workout` | Workout ready for completion |
| `completed_workout_with_sets` | Completed workout with logged sets |

### Testing Authenticated Endpoints

```python
def test_protected_endpoint(self, client, auth_headers):
    response = client.get("/api/v1/protected", headers=auth_headers)
    assert response.status_code == 200
```

### Testing with Database Objects

```python
def test_with_program(self, client, auth_headers, test_program_with_workouts):
    program_id = test_program_with_workouts.id
    response = client.get(
        f"/api/v1/programs/{program_id}",
        headers=auth_headers
    )
    assert response.status_code == 200
```

## Key Business Logic to Test

### AMRAP Detection
- Triggered on set 3 of non-deload weeks (weeks 1-3)
- Creates RepMax record if reps exceed previous PR

### Rep Max PR Creation
- Uses Epley formula: `1RM = weight × (1 + reps/30)`
- Only creates PR if weight > existing record for same rep count

### Training Max Progression
- Upper body (Press, Bench): +5 lbs per cycle
- Lower body (Squat, Deadlift): +10 lbs per cycle

### Week Types
- Week 1 (5s): 65%/75%/85% × 5/5/5+
- Week 2 (3s): 70%/80%/90% × 3/3/3+
- Week 3 (5/3/1): 75%/85%/95% × 5/3/1+
- Week 4 (Deload): 40%/50%/60% × 5/5/5 (no AMRAP)

## Coverage Goals

| Module | Target |
|--------|--------|
| `app/services/workout.py` | 80%+ |
| `app/services/program.py` | 80%+ |
| `app/services/auth.py` | 90%+ |
| `app/routers/*` | 90%+ |
| `app/utils/calculations.py` | 95%+ |

## Troubleshooting

### Tests failing with database errors
```bash
# Ensure clean state
rm -f /tmp/test_*.db
pytest --cache-clear
```

### Import errors
```bash
# Ensure you're in the backend directory
cd backend
pip install -r requirements.txt
```

### Slow tests
```bash
# Run only fast tests
pytest -m "not slow"
```
