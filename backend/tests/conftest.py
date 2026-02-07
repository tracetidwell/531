"""
Pytest configuration and fixtures.
"""
import pytest
import os
import uuid
import tempfile
from datetime import date, datetime, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient
from app.database import Base, get_db
from app.main import app

# Import all models to ensure they're registered with Base
from app.models import (
    User, Program, TrainingMax, Exercise, Workout, WorkoutSet, RepMax, WorkoutMainLift
)
from app.models.program import LiftType, ProgramStatus, TrainingMaxReason
from app.models.workout import WorkoutStatus, WeekType, SetType, WeightUnit
from app.models.user import MissedWorkoutPreference
from app.utils.security import get_password_hash

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


# ============================================
# User and Authentication Fixtures
# ============================================

@pytest.fixture
def test_user(db):
    """Create a test user with standard preferences."""
    user = User(
        id=str(uuid.uuid4()),
        first_name="Test",
        last_name="User",
        email="testuser@example.com",
        password_hash=get_password_hash("TestPassword123!"),
        weight_unit_preference=WeightUnit.LBS,
        rounding_increment=5.0,
        missed_workout_preference=MissedWorkoutPreference.ASK
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def auth_headers(test_user, client):
    """Get authentication headers for test user."""
    response = client.post("/api/v1/auth/login", json={
        "email": "testuser@example.com",
        "password": "TestPassword123!"
    })
    assert response.status_code == 200, f"Login failed: {response.json()}"
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def second_user(db):
    """Create a second test user for isolation tests."""
    user = User(
        id=str(uuid.uuid4()),
        first_name="Other",
        last_name="User",
        email="otheruser@example.com",
        password_hash=get_password_hash("OtherPassword123!"),
        weight_unit_preference=WeightUnit.LBS,
        rounding_increment=5.0
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


# ============================================
# Program and Training Max Fixtures
# ============================================

@pytest.fixture
def test_program(db, test_user):
    """Create a basic 4-day program without workouts."""
    program = Program(
        id=str(uuid.uuid4()),
        user_id=test_user.id,
        name="Test 5/3/1 Program",
        template_type="4_day",
        start_date=date.today() - timedelta(days=7),
        training_days=["monday", "tuesday", "thursday", "friday"],
        status=ProgramStatus.ACTIVE,
        include_deload=True
    )
    db.add(program)
    db.commit()
    db.refresh(program)
    return program


@pytest.fixture
def test_program_with_training_maxes(db, test_program):
    """Create a program with training maxes for all lifts."""
    training_maxes = {
        LiftType.SQUAT: 250.0,
        LiftType.DEADLIFT: 300.0,
        LiftType.BENCH_PRESS: 200.0,
        LiftType.PRESS: 100.0
    }

    for lift_type, value in training_maxes.items():
        tm = TrainingMax(
            id=str(uuid.uuid4()),
            program_id=test_program.id,
            lift_type=lift_type,
            value=value,
            effective_date=test_program.start_date,
            cycle_number=1,
            reason=TrainingMaxReason.INITIAL
        )
        db.add(tm)

    db.commit()
    db.refresh(test_program)
    return test_program


# ============================================
# Workout Fixtures
# ============================================

@pytest.fixture
def scheduled_workout(db, test_program_with_training_maxes):
    """Create a scheduled workout ready for completion."""
    workout = Workout(
        id=str(uuid.uuid4()),
        program_id=test_program_with_training_maxes.id,
        scheduled_date=date.today(),
        cycle_number=1,
        week_number=1,
        week_type=WeekType.WEEK_1_5S,
        status=WorkoutStatus.SCHEDULED
    )
    db.add(workout)
    db.flush()

    # Add main lift (squat)
    main_lift = WorkoutMainLift(
        id=str(uuid.uuid4()),
        workout_id=workout.id,
        lift_type=LiftType.SQUAT,
        lift_order=1,
        current_training_max=250.0,
        week_type=WeekType.WEEK_1_5S
    )
    db.add(main_lift)
    db.commit()
    db.refresh(workout)
    return workout


@pytest.fixture
def scheduled_workout_week3(db, test_program_with_training_maxes):
    """Create a scheduled workout for week 3 (5/3/1 week with 1+ AMRAP)."""
    workout = Workout(
        id=str(uuid.uuid4()),
        program_id=test_program_with_training_maxes.id,
        scheduled_date=date.today() + timedelta(days=14),
        cycle_number=1,
        week_number=3,
        week_type=WeekType.WEEK_3_531,
        status=WorkoutStatus.SCHEDULED
    )
    db.add(workout)
    db.flush()

    main_lift = WorkoutMainLift(
        id=str(uuid.uuid4()),
        workout_id=workout.id,
        lift_type=LiftType.SQUAT,
        lift_order=1,
        current_training_max=250.0,
        week_type=WeekType.WEEK_3_531
    )
    db.add(main_lift)
    db.commit()
    db.refresh(workout)
    return workout


@pytest.fixture
def scheduled_workout_deload(db, test_program_with_training_maxes):
    """Create a scheduled deload week workout (no AMRAP)."""
    workout = Workout(
        id=str(uuid.uuid4()),
        program_id=test_program_with_training_maxes.id,
        scheduled_date=date.today() + timedelta(days=21),
        cycle_number=1,
        week_number=4,
        week_type=WeekType.WEEK_4_DELOAD,
        status=WorkoutStatus.SCHEDULED
    )
    db.add(workout)
    db.flush()

    main_lift = WorkoutMainLift(
        id=str(uuid.uuid4()),
        workout_id=workout.id,
        lift_type=LiftType.SQUAT,
        lift_order=1,
        current_training_max=250.0,
        week_type=WeekType.WEEK_4_DELOAD
    )
    db.add(main_lift)
    db.commit()
    db.refresh(workout)
    return workout


@pytest.fixture
def multi_lift_workout(db, test_program_with_training_maxes):
    """Create a workout with multiple main lifts (2-day style)."""
    workout = Workout(
        id=str(uuid.uuid4()),
        program_id=test_program_with_training_maxes.id,
        scheduled_date=date.today(),
        cycle_number=1,
        week_number=1,
        week_type=WeekType.WEEK_1_5S,
        status=WorkoutStatus.SCHEDULED
    )
    db.add(workout)
    db.flush()

    # Add squat as first lift
    squat_lift = WorkoutMainLift(
        id=str(uuid.uuid4()),
        workout_id=workout.id,
        lift_type=LiftType.SQUAT,
        lift_order=1,
        current_training_max=250.0,
        week_type=WeekType.WEEK_1_5S
    )
    db.add(squat_lift)

    # Add bench as second lift
    bench_lift = WorkoutMainLift(
        id=str(uuid.uuid4()),
        workout_id=workout.id,
        lift_type=LiftType.BENCH_PRESS,
        lift_order=2,
        current_training_max=200.0,
        week_type=WeekType.WEEK_1_5S
    )
    db.add(bench_lift)

    db.commit()
    db.refresh(workout)
    return workout


@pytest.fixture
def completed_workout(db, scheduled_workout):
    """Create a completed workout with logged sets."""
    scheduled_workout.status = WorkoutStatus.COMPLETED
    scheduled_workout.completed_date = datetime.utcnow()

    # Add warmup sets
    warmup_weights = [115, 145, 170, 195]  # Based on 250 TM
    for i, weight in enumerate(warmup_weights, 1):
        warmup_set = WorkoutSet(
            id=str(uuid.uuid4()),
            workout_id=scheduled_workout.id,
            set_type=SetType.WARMUP,
            set_number=i,
            lift_type=LiftType.SQUAT,
            prescribed_reps=5,
            actual_reps=5,
            prescribed_weight=float(weight),
            actual_weight=float(weight),
            weight_unit=WeightUnit.LBS,
            is_target_met=True
        )
        db.add(warmup_set)

    # Add working sets (week 1: 65%/75%/85% of 250 = 162.5/187.5/212.5 -> rounded)
    working_weights = [165, 190, 215]
    for i, weight in enumerate(working_weights, 1):
        is_amrap = (i == 3)
        actual_reps = 8 if is_amrap else 5  # Exceeded minimum on AMRAP
        workout_set = WorkoutSet(
            id=str(uuid.uuid4()),
            workout_id=scheduled_workout.id,
            set_type=SetType.AMRAP if is_amrap else SetType.WORKING,
            set_number=i,
            lift_type=LiftType.SQUAT,
            prescribed_reps=5,
            actual_reps=actual_reps,
            prescribed_weight=float(weight),
            actual_weight=float(weight),
            weight_unit=WeightUnit.LBS,
            percentage_of_tm=0.65 + (i - 1) * 0.10,
            is_target_met=True
        )
        db.add(workout_set)

    db.commit()
    db.refresh(scheduled_workout)
    return scheduled_workout


@pytest.fixture
def past_scheduled_workout(db, test_program_with_training_maxes):
    """Create a past scheduled workout (missed)."""
    workout = Workout(
        id=str(uuid.uuid4()),
        program_id=test_program_with_training_maxes.id,
        scheduled_date=date.today() - timedelta(days=3),
        cycle_number=1,
        week_number=1,
        week_type=WeekType.WEEK_1_5S,
        status=WorkoutStatus.SCHEDULED
    )
    db.add(workout)
    db.flush()

    main_lift = WorkoutMainLift(
        id=str(uuid.uuid4()),
        workout_id=workout.id,
        lift_type=LiftType.SQUAT,
        lift_order=1,
        current_training_max=250.0,
        week_type=WeekType.WEEK_1_5S
    )
    db.add(main_lift)
    db.commit()
    db.refresh(workout)
    return workout


# ============================================
# Rep Max Fixtures
# ============================================

@pytest.fixture
def test_rep_max(db, test_user, completed_workout):
    """Create a rep max record."""
    # Get one of the workout sets to reference
    workout_set = db.query(WorkoutSet).filter(
        WorkoutSet.workout_id == completed_workout.id,
        WorkoutSet.set_type == SetType.AMRAP
    ).first()

    rep_max = RepMax(
        id=str(uuid.uuid4()),
        user_id=test_user.id,
        lift_type=LiftType.SQUAT,
        reps=8,
        weight=215.0,
        weight_unit=WeightUnit.LBS,
        calculated_1rm=215.0 * (1 + 8/30),  # Epley formula
        achieved_date=date.today(),
        workout_set_id=workout_set.id if workout_set else str(uuid.uuid4())
    )
    db.add(rep_max)
    db.commit()
    db.refresh(rep_max)
    return rep_max


@pytest.fixture
def multiple_rep_maxes(db, test_user, completed_workout):
    """Create multiple rep max records for different lifts and rep ranges."""
    workout_set = db.query(WorkoutSet).filter(
        WorkoutSet.workout_id == completed_workout.id,
        WorkoutSet.set_type == SetType.AMRAP
    ).first()
    set_id = workout_set.id if workout_set else str(uuid.uuid4())

    rep_maxes = [
        # Squat PRs
        RepMax(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            lift_type=LiftType.SQUAT,
            reps=5,
            weight=225.0,
            weight_unit=WeightUnit.LBS,
            calculated_1rm=225.0 * (1 + 5/30),
            achieved_date=date.today() - timedelta(days=7),
            workout_set_id=set_id
        ),
        RepMax(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            lift_type=LiftType.SQUAT,
            reps=3,
            weight=240.0,
            weight_unit=WeightUnit.LBS,
            calculated_1rm=240.0 * (1 + 3/30),
            achieved_date=date.today() - timedelta(days=3),
            workout_set_id=set_id
        ),
        # Bench PR
        RepMax(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            lift_type=LiftType.BENCH_PRESS,
            reps=5,
            weight=175.0,
            weight_unit=WeightUnit.LBS,
            calculated_1rm=175.0 * (1 + 5/30),
            achieved_date=date.today(),
            workout_set_id=set_id
        ),
    ]

    for rm in rep_maxes:
        db.add(rm)

    db.commit()
    return rep_maxes


# ============================================
# Exercise Fixtures
# ============================================

@pytest.fixture
def test_exercises(db):
    """Create some predefined exercises."""
    exercises = [
        Exercise(
            id=str(uuid.uuid4()),
            name="Barbell Row",
            category="back",
            is_predefined=True
        ),
        Exercise(
            id=str(uuid.uuid4()),
            name="Dumbbell Press",
            category="chest",
            is_predefined=True
        ),
        Exercise(
            id=str(uuid.uuid4()),
            name="Leg Press",
            category="legs",
            is_predefined=True
        ),
    ]

    for exercise in exercises:
        db.add(exercise)

    db.commit()
    return exercises
