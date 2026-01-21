"""
Tests for program management endpoints.
"""
import pytest
from datetime import date, timedelta
from app.models.user import User
from app.models.exercise import Exercise, ExerciseCategory
from app.models.program import Program, ProgramStatus, LiftType
from app.models.workout import Workout
from app.utils.security import get_password_hash
import uuid


@pytest.fixture
def test_user(db):
    """Create a test user."""
    user = User(
        id=str(uuid.uuid4()),
        first_name="Test",
        last_name="User",
        email="testuser@example.com",
        password_hash=get_password_hash("TestPassword123!")
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def auth_token(test_user, client):
    """Get authentication token for test user."""
    response = client.post("/api/v1/auth/login", json={
        "email": "testuser@example.com",
        "password": "TestPassword123!"
    })
    assert response.status_code == 200
    return response.json()["access_token"]


@pytest.fixture
def test_exercises(db):
    """Create test exercises for accessories."""
    exercises = [
        Exercise(
            id=str(uuid.uuid4()),
            name="Test Push Exercise",
            category=ExerciseCategory.PUSH,
            is_predefined=True,
            description="Test push exercise"
        ),
        Exercise(
            id=str(uuid.uuid4()),
            name="Test Pull Exercise",
            category=ExerciseCategory.PULL,
            is_predefined=True,
            description="Test pull exercise"
        ),
        Exercise(
            id=str(uuid.uuid4()),
            name="Test Legs Exercise",
            category=ExerciseCategory.LEGS,
            is_predefined=True,
            description="Test legs exercise"
        ),
        Exercise(
            id=str(uuid.uuid4()),
            name="Test Core Exercise",
            category=ExerciseCategory.CORE,
            is_predefined=True,
            description="Test core exercise"
        ),
    ]

    for exercise in exercises:
        db.add(exercise)

    db.commit()

    # Return dict mapping category to exercise ID
    return {
        "push": exercises[0].id,
        "pull": exercises[1].id,
        "legs": exercises[2].id,
        "core": exercises[3].id,
    }


class TestProgramCreation:
    """Tests for creating programs."""

    def test_create_program_success(self, client, auth_token, test_exercises):
        """Test creating a new program successfully."""
        start_date = date.today()

        program_data = {
            "name": "My First 5/3/1 Program",
            "template_type": "4_day",
            "start_date": start_date.isoformat(),
            "training_days": ["monday", "tuesday", "thursday", "friday"],
            "training_maxes": {
                "press": 100,
                "deadlift": 300,
                "bench_press": 200,
                "squat": 250
            },
            "accessories": {
                "1": [
                    {"exercise_id": test_exercises["push"], "sets": 5, "reps": 10},
                    {"exercise_id": test_exercises["core"], "sets": 3, "reps": 15}
                ],
                "2": [
                    {"exercise_id": test_exercises["pull"], "sets": 5, "reps": 10}
                ],
                "3": [
                    {"exercise_id": test_exercises["push"], "sets": 5, "reps": 10}
                ],
                "4": [
                    {"exercise_id": test_exercises["legs"], "sets": 3, "reps": 12}
                ]
            }
        }

        response = client.post(
            "/api/v1/programs",
            json=program_data,
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 201
        data = response.json()

        assert data["name"] == "My First 5/3/1 Program"
        assert data["template_type"] == "4_day"
        assert data["status"] == "active"
        assert data["current_cycle"] == 1
        assert data["current_week"] == 1
        assert data["training_maxes"]["press"]["value"] == 100
        assert data["training_maxes"]["deadlift"]["value"] == 300
        assert data["training_maxes"]["bench_press"]["value"] == 200
        assert data["training_maxes"]["squat"]["value"] == 250
        assert data["workouts_generated"] == 16  # 4 weeks * 4 days

    def test_create_program_without_auth(self, client, test_exercises):
        """Test that creating program without auth fails."""
        program_data = {
            "name": "Test Program",
            "start_date": date.today().isoformat(),
            "training_days": ["monday", "tuesday", "thursday", "friday"],
            "training_maxes": {
                "press": 100,
                "deadlift": 300,
                "bench_press": 200,
                "squat": 250
            },
            "accessories": {"1": [], "2": [], "3": [], "4": []}
        }

        response = client.post("/api/v1/programs", json=program_data)
        assert response.status_code == 403

    def test_create_second_active_program_fails(self, client, auth_token, test_exercises, db, test_user):
        """Test that user cannot create second active program."""
        # Create first program
        program1 = Program(
            user_id=test_user.id,
            name="First Program",
            template_type="4_day",
            start_date=date.today(),
            training_days=["monday", "tuesday", "thursday", "friday"],
            status=ProgramStatus.ACTIVE
        )
        db.add(program1)
        db.commit()

        # Try to create second program
        program_data = {
            "name": "Second Program",
            "start_date": date.today().isoformat(),
            "training_days": ["monday", "wednesday", "friday", "saturday"],
            "training_maxes": {
                "press": 110,
                "deadlift": 310,
                "bench_press": 210,
                "squat": 260
            },
            "accessories": {"1": [], "2": [], "3": [], "4": []}
        }

        response = client.post(
            "/api/v1/programs",
            json=program_data,
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 400
        assert "already have an active program" in response.json()["detail"]

    def test_create_program_invalid_training_days(self, client, auth_token, test_exercises):
        """Test that program with wrong number of training days fails."""
        program_data = {
            "name": "Test Program",
            "start_date": date.today().isoformat(),
            "training_days": ["monday", "tuesday"],  # Only 2 days instead of 4
            "training_maxes": {
                "press": 100,
                "deadlift": 300,
                "bench_press": 200,
                "squat": 250
            },
            "accessories": {"1": [], "2": [], "3": [], "4": []}
        }

        response = client.post(
            "/api/v1/programs",
            json=program_data,
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 422  # Validation error


class TestProgramRetrieval:
    """Tests for retrieving programs."""

    def test_list_programs(self, client, auth_token, db, test_user):
        """Test listing all user programs."""
        # Create multiple programs
        program1 = Program(
            user_id=test_user.id,
            name="Program 1",
            template_type="4_day",
            start_date=date.today() - timedelta(days=90),
            training_days=["monday", "tuesday", "thursday", "friday"],
            status=ProgramStatus.COMPLETED
        )
        program2 = Program(
            user_id=test_user.id,
            name="Program 2",
            template_type="4_day",
            start_date=date.today(),
            training_days=["monday", "wednesday", "friday", "saturday"],
            status=ProgramStatus.ACTIVE
        )

        db.add(program1)
        db.add(program2)
        db.commit()

        response = client.get(
            "/api/v1/programs",
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        assert len(data) == 2
        # Should be in reverse chronological order (newest first)
        assert data[0]["name"] == "Program 2"
        assert data[1]["name"] == "Program 1"

    def test_get_program_detail(self, client, auth_token, db, test_user):
        """Test getting detailed program information."""
        program = Program(
            user_id=test_user.id,
            name="Test Program",
            template_type="4_day",
            start_date=date.today(),
            training_days=["monday", "tuesday", "thursday", "friday"],
            status=ProgramStatus.ACTIVE
        )

        db.add(program)
        db.commit()
        db.refresh(program)

        response = client.get(
            f"/api/v1/programs/{program.id}",
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        assert data["id"] == program.id
        assert data["name"] == "Test Program"
        assert data["status"] == "active"
        assert data["training_days"] == ["monday", "tuesday", "thursday", "friday"]

    def test_get_program_not_found(self, client, auth_token):
        """Test getting non-existent program."""
        fake_id = str(uuid.uuid4())

        response = client.get(
            f"/api/v1/programs/{fake_id}",
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 404

    def test_get_other_user_program_fails(self, client, db):
        """Test that user cannot access another user's program."""
        # Create another user
        other_user = User(
            id=str(uuid.uuid4()),
            first_name="Other",
            last_name="User",
            email="otheruser@example.com",
            password_hash=get_password_hash("OtherPassword123!")
        )
        db.add(other_user)
        db.commit()

        # Create program for other user
        program = Program(
            user_id=other_user.id,
            name="Other User Program",
            template_type="4_day",
            start_date=date.today(),
            training_days=["monday", "tuesday", "thursday", "friday"],
            status=ProgramStatus.ACTIVE
        )
        db.add(program)
        db.commit()
        db.refresh(program)

        # Get token for first user
        response = client.post("/api/v1/auth/login", json={
            "email": "testuser@example.com",
            "password": "TestPassword123!"
        })
        token = response.json()["access_token"]

        # Try to access other user's program
        response = client.get(
            f"/api/v1/programs/{program.id}",
            headers={"Authorization": f"Bearer {token}"}
        )

        assert response.status_code == 404  # Should not find


class TestProgramUpdate:
    """Tests for updating programs."""

    def test_update_program_name(self, client, auth_token, db, test_user):
        """Test updating program name."""
        program = Program(
            user_id=test_user.id,
            name="Old Name",
            template_type="4_day",
            start_date=date.today(),
            training_days=["monday", "tuesday", "thursday", "friday"],
            status=ProgramStatus.ACTIVE
        )
        db.add(program)
        db.commit()
        db.refresh(program)

        response = client.put(
            f"/api/v1/programs/{program.id}",
            json={"name": "New Name"},
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "New Name"

    def test_update_program_status(self, client, auth_token, db, test_user):
        """Test updating program status."""
        program = Program(
            user_id=test_user.id,
            name="Test Program",
            template_type="4_day",
            start_date=date.today(),
            training_days=["monday", "tuesday", "thursday", "friday"],
            status=ProgramStatus.ACTIVE
        )
        db.add(program)
        db.commit()
        db.refresh(program)

        response = client.put(
            f"/api/v1/programs/{program.id}",
            json={"status": "paused"},
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "paused"

    def test_update_program_end_date(self, client, auth_token, db, test_user):
        """Test updating program end date."""
        program = Program(
            user_id=test_user.id,
            name="Test Program",
            template_type="4_day",
            start_date=date.today(),
            training_days=["monday", "tuesday", "thursday", "friday"],
            status=ProgramStatus.ACTIVE
        )
        db.add(program)
        db.commit()
        db.refresh(program)

        end_date = date.today() + timedelta(days=90)

        response = client.put(
            f"/api/v1/programs/{program.id}",
            json={"end_date": end_date.isoformat()},
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()
        assert data["end_date"] == end_date.isoformat()
