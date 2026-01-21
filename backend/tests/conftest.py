"""
Pytest configuration and fixtures.
"""
import pytest
import os
import tempfile
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient
from app.database import Base, get_db
from app.main import app

# Import all models to ensure they're registered with Base
from app.models import (
    User, Program, TrainingMax, TrainingMaxHistory, ProgramTemplate,
    Exercise, Workout, WorkoutSet, WarmupTemplate, RepMax
)

# Use a temporary file-based SQLite database for tests
test_db_fd, test_db_path = tempfile.mkstemp(suffix=".db")

SQLALCHEMY_DATABASE_URL = f"sqlite:///{test_db_path}"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def pytest_configure(config):
    """Create database tables before running tests."""
    Base.metadata.create_all(bind=engine)


def pytest_unconfigure(config):
    """Clean up database after all tests."""
    Base.metadata.drop_all(bind=engine)
    os.close(test_db_fd)
    os.unlink(test_db_path)


@pytest.fixture(scope="function", autouse=True)
def cleanup_db():
    """Clean up database after each test."""
    yield
    # Clear all data but keep tables
    with engine.begin() as conn:
        for table in reversed(Base.metadata.sorted_tables):
            conn.execute(table.delete())


@pytest.fixture(scope="function")
def db():
    """Get a database session for tests."""
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(scope="function")
def client():
    """Create a test client with database override."""
    def override_get_db():
        try:
            db = TestingSessionLocal()
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()
