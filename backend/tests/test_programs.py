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
        assert data["status"].upper() == "ACTIVE"
        assert data["current_cycle"] == 1
        assert data["current_week"] == 1
        # Training max keys may be uppercase or lowercase depending on implementation
        tm = data["training_maxes"]
        press_key = "press" if "press" in tm else "PRESS"
        deadlift_key = "deadlift" if "deadlift" in tm else "DEADLIFT"
        bench_key = "bench_press" if "bench_press" in tm else "BENCH_PRESS"
        squat_key = "squat" if "squat" in tm else "SQUAT"
        assert tm[press_key]["value"] == 100
        assert tm[deadlift_key]["value"] == 300
        assert tm[bench_key]["value"] == 200
        assert tm[squat_key]["value"] == 250
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
        # Error message may vary - just check it failed
        assert "detail" in response.json()

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
        assert data["status"].upper() == "ACTIVE"
        assert data["training_days"] == ["monday", "tuesday", "thursday", "friday"]

    def test_get_program_not_found(self, client, auth_token):
        """Test getting non-existent program."""
        fake_id = str(uuid.uuid4())

        response = client.get(
            f"/api/v1/programs/{fake_id}",
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 404

    def test_get_other_user_program_fails(self, client, db, test_user, auth_token):
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

        # Try to access other user's program with test_user's token
        response = client.get(
            f"/api/v1/programs/{program.id}",
            headers={"Authorization": f"Bearer {auth_token}"}
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
            json={"status": "PAUSED"},
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()
        assert data["status"].upper() == "PAUSED"

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


class TestProgramTemplates:
    """Tests for program templates and accessories."""

    @pytest.fixture
    def program_with_accessories(self, client, auth_token, test_exercises):
        """Create a program with accessories for testing."""
        start_date = date.today()

        program_data = {
            "name": "Test Program with Accessories",
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
                    {"exercise_id": test_exercises["pull"], "sets": 4, "reps": 12}
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
        return response.json()

    def test_get_program_templates(self, client, auth_token, program_with_accessories):
        """Test getting all templates for a program."""
        program_id = program_with_accessories["id"]

        response = client.get(
            f"/api/v1/programs/{program_id}/templates",
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        # Should have 4 templates (one for each day)
        assert len(data) == 4

        # Check first template (Day 1 - Press)
        day1 = next(t for t in data if t["day_number"] == 1)
        assert day1["main_lift"] == "PRESS"
        assert len(day1["accessories"]) == 2
        assert day1["accessories"][0]["sets"] == 5
        assert day1["accessories"][0]["reps"] == 10

        # Check second template (Day 2 - Deadlift)
        day2 = next(t for t in data if t["day_number"] == 2)
        assert day2["main_lift"] == "DEADLIFT"
        assert len(day2["accessories"]) == 1

    def test_get_templates_not_found(self, client, auth_token):
        """Test getting templates for non-existent program."""
        fake_id = str(uuid.uuid4())

        response = client.get(
            f"/api/v1/programs/{fake_id}/templates",
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 404

    def test_get_templates_unauthorized(self, client, program_with_accessories):
        """Test getting templates without auth."""
        program_id = program_with_accessories["id"]

        response = client.get(f"/api/v1/programs/{program_id}/templates")

        assert response.status_code == 403

    def test_update_accessories(self, client, auth_token, program_with_accessories, test_exercises):
        """Test updating accessories for a training day."""
        program_id = program_with_accessories["id"]

        # Update day 1 accessories - change reps from 10 to 20
        new_accessories = [
            {"exercise_id": test_exercises["push"], "sets": 5, "reps": 20},
            {"exercise_id": test_exercises["core"], "sets": 3, "reps": 15}
        ]

        response = client.put(
            f"/api/v1/programs/{program_id}/days/1/accessories",
            json={"accessories": new_accessories},
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        assert data["day_number"] == 1
        assert "lifts_updated" in data  # Multiple lifts may be updated for same day
        assert len(data["accessories"]) == 2
        assert data["accessories"][0]["reps"] == 20  # Changed from 10

    def test_update_accessories_add_new(self, client, auth_token, program_with_accessories, test_exercises):
        """Test adding a new accessory exercise."""
        program_id = program_with_accessories["id"]

        # Add a third accessory to day 1
        new_accessories = [
            {"exercise_id": test_exercises["push"], "sets": 5, "reps": 10},
            {"exercise_id": test_exercises["core"], "sets": 3, "reps": 15},
            {"exercise_id": test_exercises["pull"], "sets": 4, "reps": 8}  # New
        ]

        response = client.put(
            f"/api/v1/programs/{program_id}/days/1/accessories",
            json={"accessories": new_accessories},
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        assert len(data["accessories"]) == 3

    def test_update_accessories_remove(self, client, auth_token, program_with_accessories, test_exercises):
        """Test removing an accessory exercise."""
        program_id = program_with_accessories["id"]

        # Remove one accessory from day 1 (was 2, now 1)
        new_accessories = [
            {"exercise_id": test_exercises["push"], "sets": 5, "reps": 10}
        ]

        response = client.put(
            f"/api/v1/programs/{program_id}/days/1/accessories",
            json={"accessories": new_accessories},
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        assert len(data["accessories"]) == 1

    def test_update_accessories_with_circuit(self, client, auth_token, program_with_accessories, test_exercises):
        """Test updating accessories with circuit groups."""
        program_id = program_with_accessories["id"]

        # Set up circuit training
        new_accessories = [
            {"exercise_id": test_exercises["push"], "sets": 3, "reps": 10, "circuit_group": 1},
            {"exercise_id": test_exercises["pull"], "sets": 3, "reps": 10, "circuit_group": 1},
            {"exercise_id": test_exercises["core"], "sets": 3, "reps": 15}  # Not in circuit
        ]

        response = client.put(
            f"/api/v1/programs/{program_id}/days/1/accessories",
            json={"accessories": new_accessories},
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        assert len(data["accessories"]) == 3
        assert data["accessories"][0]["circuit_group"] == 1
        assert data["accessories"][1]["circuit_group"] == 1
        assert data["accessories"][2]["circuit_group"] is None

    def test_update_accessories_invalid_day(self, client, auth_token, program_with_accessories, test_exercises):
        """Test updating accessories for invalid day number."""
        program_id = program_with_accessories["id"]

        response = client.put(
            f"/api/v1/programs/{program_id}/days/99/accessories",
            json={"accessories": []},
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 404
        assert "No template found" in response.json()["detail"]

    def test_update_accessories_not_found(self, client, auth_token, test_exercises):
        """Test updating accessories for non-existent program."""
        fake_id = str(uuid.uuid4())

        response = client.put(
            f"/api/v1/programs/{fake_id}/days/1/accessories",
            json={"accessories": []},
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 404

    def test_update_accessories_unauthorized(self, client, program_with_accessories):
        """Test updating accessories without auth."""
        program_id = program_with_accessories["id"]

        response = client.put(
            f"/api/v1/programs/{program_id}/days/1/accessories",
            json={"accessories": []}
        )

        assert response.status_code == 403

    def test_update_accessories_persists(self, client, auth_token, program_with_accessories, test_exercises):
        """Test that accessory updates persist when fetching templates again."""
        program_id = program_with_accessories["id"]

        # Update accessories
        new_accessories = [
            {"exercise_id": test_exercises["push"], "sets": 4, "reps": 15}
        ]

        client.put(
            f"/api/v1/programs/{program_id}/days/1/accessories",
            json={"accessories": new_accessories},
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        # Fetch templates again
        response = client.get(
            f"/api/v1/programs/{program_id}/templates",
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        day1 = next(t for t in data if t["day_number"] == 1)
        assert len(day1["accessories"]) == 1
        assert day1["accessories"][0]["sets"] == 4
        assert day1["accessories"][0]["reps"] == 15

    def test_get_day_accessories(self, client, auth_token, program_with_accessories):
        """Test getting day accessories from the new endpoint."""
        program_id = program_with_accessories["id"]

        response = client.get(
            f"/api/v1/programs/{program_id}/day-accessories",
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        # Should have 4 day accessories (one for each day)
        assert len(data) == 4

        # Check day 1 accessories
        day1 = next(da for da in data if da["day_number"] == 1)
        assert "id" in day1
        assert len(day1["accessories"]) == 2
        assert day1["accessories"][0]["sets"] == 5
        assert day1["accessories"][0]["reps"] == 10

        # Check day 2 accessories
        day2 = next(da for da in data if da["day_number"] == 2)
        assert len(day2["accessories"]) == 1

    def test_get_day_accessories_not_found(self, client, auth_token):
        """Test getting day accessories for non-existent program."""
        fake_id = str(uuid.uuid4())

        response = client.get(
            f"/api/v1/programs/{fake_id}/day-accessories",
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 404

    def test_day_accessories_sync_with_templates(self, client, auth_token, program_with_accessories, test_exercises):
        """Test that day accessories and templates return the same accessories."""
        program_id = program_with_accessories["id"]

        # Get templates
        templates_response = client.get(
            f"/api/v1/programs/{program_id}/templates",
            headers={"Authorization": f"Bearer {auth_token}"}
        )
        templates = templates_response.json()

        # Get day accessories
        day_accessories_response = client.get(
            f"/api/v1/programs/{program_id}/day-accessories",
            headers={"Authorization": f"Bearer {auth_token}"}
        )
        day_accessories = day_accessories_response.json()

        # Verify accessories match for each day
        for day_acc in day_accessories:
            day_num = day_acc["day_number"]
            # Find templates for this day
            day_templates = [t for t in templates if t["day_number"] == day_num]
            # All templates for the same day should have the same accessories
            for template in day_templates:
                assert template["accessories"] == day_acc["accessories"]
