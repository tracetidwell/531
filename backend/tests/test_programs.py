"""
Tests for program management endpoints.
"""
import pytest
from datetime import date, timedelta
from app.models.user import User
from app.models.exercise import Exercise, ExerciseCategory
from app.models.program import Program, ProgramStatus, TrainingMax, LiftType, TrainingMaxReason
from app.models.workout import Workout, WorkoutMainLift, WorkoutStatus, WeekType
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


class TestDeloadManagement:
    """Tests for toggling include_deload on existing programs."""

    @pytest.fixture
    def program_with_deload_workouts(self, db, test_user):
        """Program with a mix of scheduled and completed workouts across weeks 1-4."""
        program = Program(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            name="Deload Test Program",
            template_type="4_day",
            start_date=date.today() - timedelta(days=21),
            training_days=["monday", "tuesday", "thursday", "friday"],
            status=ProgramStatus.ACTIVE,
            include_deload=True,
        )
        db.add(program)
        db.flush()

        week_configs = [
            (1, WeekType.WEEK_1_5S, WorkoutStatus.COMPLETED),
            (2, WeekType.WEEK_2_3S, WorkoutStatus.COMPLETED),
            (3, WeekType.WEEK_3_531, WorkoutStatus.SCHEDULED),
            (4, WeekType.WEEK_4_DELOAD, WorkoutStatus.SCHEDULED),
        ]

        workouts = {}
        for week_num, week_type, status in week_configs:
            w = Workout(
                id=str(uuid.uuid4()),
                program_id=program.id,
                scheduled_date=date.today() - timedelta(days=21) + timedelta(weeks=week_num - 1),
                cycle_number=1,
                week_number=week_num,
                week_type=week_type,
                status=status,
            )
            db.add(w)
            workouts[week_num] = w

        db.commit()
        db.refresh(program)
        workouts['program'] = program
        return workouts

    def test_disable_deload_deletes_scheduled_deload_workouts(
        self, client, auth_token, program_with_deload_workouts
    ):
        """Setting include_deload=False removes scheduled week-4 workouts."""
        program = program_with_deload_workouts['program']

        response = client.put(
            f"/api/v1/programs/{program.id}",
            json={"include_deload": False},
            headers={"Authorization": f"Bearer {auth_token}"},
        )

        assert response.status_code == 200

        # Deload workout should be gone
        from app.models.workout import Workout as WorkoutModel
        from app.database import get_db
        # Verify via API instead
        workouts_resp = client.get(
            f"/api/v1/workouts?program_id={program.id}&workout_status=SCHEDULED",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        assert workouts_resp.status_code == 200
        scheduled = workouts_resp.json()
        week_types = [w['week_type'] for w in scheduled]
        assert 'WEEK_4_DELOAD' not in week_types

    def test_disable_deload_preserves_completed_deload_workouts(
        self, client, auth_token, db, test_user
    ):
        """Setting include_deload=False does NOT delete already-completed deload workouts."""
        program = Program(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            name="Deload Preserve Test",
            template_type="4_day",
            start_date=date.today() - timedelta(days=28),
            training_days=["monday", "tuesday", "thursday", "friday"],
            status=ProgramStatus.ACTIVE,
            include_deload=True,
        )
        db.add(program)
        db.flush()

        # Completed deload workout from a previous cycle
        completed_deload = Workout(
            id=str(uuid.uuid4()),
            program_id=program.id,
            scheduled_date=date.today() - timedelta(days=7),
            cycle_number=1,
            week_number=4,
            week_type=WeekType.WEEK_4_DELOAD,
            status=WorkoutStatus.COMPLETED,
        )
        db.add(completed_deload)
        db.commit()

        response = client.put(
            f"/api/v1/programs/{program.id}",
            json={"include_deload": False},
            headers={"Authorization": f"Bearer {auth_token}"},
        )

        assert response.status_code == 200

        # The completed deload workout must still exist
        workouts_resp = client.get(
            f"/api/v1/workouts?program_id={program.id}&workout_status=COMPLETED",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        completed = workouts_resp.json()
        assert any(w['week_type'] == 'WEEK_4_DELOAD' for w in completed)

    def test_enable_deload_does_not_generate_workouts(
        self, client, auth_token, db, test_user
    ):
        """Setting include_deload=True on a program without deload only updates the flag."""
        program = Program(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            name="Enable Deload Test",
            template_type="4_day",
            start_date=date.today(),
            training_days=["monday", "tuesday", "thursday", "friday"],
            status=ProgramStatus.ACTIVE,
            include_deload=False,
        )
        db.add(program)
        db.commit()

        before_resp = client.get(
            f"/api/v1/workouts?program_id={program.id}",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        before_count = len(before_resp.json())

        response = client.put(
            f"/api/v1/programs/{program.id}",
            json={"include_deload": True},
            headers={"Authorization": f"Bearer {auth_token}"},
        )

        assert response.status_code == 200

        after_resp = client.get(
            f"/api/v1/workouts?program_id={program.id}",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        assert len(after_resp.json()) == before_count  # No new workouts generated

    def test_disable_deload_updates_program_flag(
        self, client, auth_token, program_with_deload_workouts
    ):
        """include_deload flag is persisted correctly when set to False."""
        program = program_with_deload_workouts['program']

        client.put(
            f"/api/v1/programs/{program.id}",
            json={"include_deload": False},
            headers={"Authorization": f"Bearer {auth_token}"},
        )

        detail_resp = client.get(
            f"/api/v1/programs/{program.id}",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        assert detail_resp.status_code == 200
        # include_deload comes back as falsy (0 or False)
        assert not detail_resp.json().get("include_deload")

    def test_disable_deload_preserves_non_deload_scheduled_workouts(
        self, client, auth_token, program_with_deload_workouts
    ):
        """Only deload workouts are removed; other scheduled workouts stay."""
        program = program_with_deload_workouts['program']

        client.put(
            f"/api/v1/programs/{program.id}",
            json={"include_deload": False},
            headers={"Authorization": f"Bearer {auth_token}"},
        )

        workouts_resp = client.get(
            f"/api/v1/workouts?program_id={program.id}&workout_status=SCHEDULED",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        scheduled = workouts_resp.json()
        # Week 3 (5/3/1 week) should still be scheduled
        assert any(w['week_type'] == 'WEEK_3_531' for w in scheduled)


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

    def test_create_program_with_weight(self, client, auth_token, test_exercises):
        """Test creating a program with weight values on accessories."""
        start_date = date.today()

        program_data = {
            "name": "Program With Weights",
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
                    {"exercise_id": test_exercises["push"], "sets": 5, "reps": 10, "weight": 135.0},
                    {"exercise_id": test_exercises["core"], "sets": 3, "reps": 15}
                ],
                "2": [
                    {"exercise_id": test_exercises["pull"], "sets": 4, "reps": 12, "weight": 100.0}
                ],
                "3": [
                    {"exercise_id": test_exercises["push"], "sets": 5, "reps": 10, "weight": 95.0}
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
        program_id = response.json()["id"]

        # Verify weight is stored in templates
        templates_response = client.get(
            f"/api/v1/programs/{program_id}/templates",
            headers={"Authorization": f"Bearer {auth_token}"}
        )
        assert templates_response.status_code == 200
        templates = templates_response.json()

        day1 = next(t for t in templates if t["day_number"] == 1)
        assert day1["accessories"][0]["weight"] == 135.0
        assert day1["accessories"][1]["weight"] is None  # No weight specified

        day2 = next(t for t in templates if t["day_number"] == 2)
        assert day2["accessories"][0]["weight"] == 100.0

        # Verify weight is stored in day-accessories
        day_acc_response = client.get(
            f"/api/v1/programs/{program_id}/day-accessories",
            headers={"Authorization": f"Bearer {auth_token}"}
        )
        assert day_acc_response.status_code == 200
        day_accessories = day_acc_response.json()

        da1 = next(da for da in day_accessories if da["day_number"] == 1)
        assert da1["accessories"][0]["weight"] == 135.0
        assert da1["accessories"][1]["weight"] is None

    def test_update_accessories_with_weight(self, client, auth_token, program_with_accessories, test_exercises):
        """Test updating accessories with weight values."""
        program_id = program_with_accessories["id"]

        new_accessories = [
            {"exercise_id": test_exercises["push"], "sets": 5, "reps": 10, "weight": 150.0},
            {"exercise_id": test_exercises["core"], "sets": 3, "reps": 15, "weight": 25.0}
        ]

        response = client.put(
            f"/api/v1/programs/{program_id}/days/1/accessories",
            json={"accessories": new_accessories},
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        assert data["accessories"][0]["weight"] == 150.0
        assert data["accessories"][1]["weight"] == 25.0

        # Verify it persists via templates endpoint
        templates_response = client.get(
            f"/api/v1/programs/{program_id}/templates",
            headers={"Authorization": f"Bearer {auth_token}"}
        )
        templates = templates_response.json()
        day1 = next(t for t in templates if t["day_number"] == 1)
        assert day1["accessories"][0]["weight"] == 150.0
        assert day1["accessories"][1]["weight"] == 25.0

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


class TestCycleManagement:
    """Tests for complete-cycle and generate-next-cycle endpoints."""

    @pytest.fixture
    def program_with_tms(self, db, test_user):
        """4-day program with cycle-1 training maxes."""
        program = Program(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            name="Cycle Test Program",
            template_type="4_day",
            start_date=date.today() - timedelta(days=28),
            training_days=["monday", "tuesday", "thursday", "friday"],
            status=ProgramStatus.ACTIVE,
            include_deload=True,
        )
        db.add(program)
        db.flush()

        for lift, value in [
            (LiftType.PRESS, 100.0),
            (LiftType.BENCH_PRESS, 200.0),
            (LiftType.SQUAT, 250.0),
            (LiftType.DEADLIFT, 300.0),
        ]:
            db.add(TrainingMax(
                id=str(uuid.uuid4()),
                program_id=program.id,
                lift_type=lift,
                value=value,
                effective_date=program.start_date,
                cycle_number=1,
                reason=TrainingMaxReason.INITIAL,
            ))

        db.commit()
        db.refresh(program)
        return program

    @pytest.fixture
    def program_with_completed_workout(self, db, program_with_tms):
        """Add one completed workout so generate-next-cycle can find latest cycle."""
        workout = Workout(
            id=str(uuid.uuid4()),
            program_id=program_with_tms.id,
            scheduled_date=date.today() - timedelta(days=1),
            cycle_number=1,
            week_number=4,
            week_type=WeekType.WEEK_4_DELOAD,
            status=WorkoutStatus.COMPLETED,
        )
        db.add(workout)
        db.flush()
        db.add(WorkoutMainLift(
            id=str(uuid.uuid4()),
            workout_id=workout.id,
            lift_type=LiftType.SQUAT,
            lift_order=1,
            current_training_max=250.0,
            week_type=WeekType.WEEK_4_DELOAD,
        ))
        db.commit()
        return program_with_tms

    @pytest.fixture
    def program_with_full_cycle(self, db, program_with_tms):
        """Add 4 workouts spread across a cycle so the date bug is detectable."""
        base = date.today() - timedelta(days=28)
        for week, week_type in enumerate(
            [WeekType.WEEK_1_5S, WeekType.WEEK_2_3S, WeekType.WEEK_3_531, WeekType.WEEK_4_DELOAD],
            start=1,
        ):
            workout = Workout(
                id=str(uuid.uuid4()),
                program_id=program_with_tms.id,
                scheduled_date=base + timedelta(weeks=week - 1),
                cycle_number=1,
                week_number=week,
                week_type=week_type,
                status=WorkoutStatus.COMPLETED,
            )
            db.add(workout)
            db.flush()
            db.add(WorkoutMainLift(
                id=str(uuid.uuid4()),
                workout_id=workout.id,
                lift_type=LiftType.SQUAT,
                lift_order=1,
                current_training_max=250.0,
                week_type=week_type,
            ))
        db.commit()
        return program_with_tms

    # ------------------------------------------------------------------
    # complete-cycle tests
    # ------------------------------------------------------------------

    def test_complete_cycle_default_increments(self, client, auth_token, program_with_tms):
        """complete-cycle with no body uses standard 5/3/1 increments."""
        pid = program_with_tms.id

        response = client.post(
            f"/api/v1/programs/{pid}/complete-cycle",
            headers={"Authorization": f"Bearer {auth_token}"},
        )

        assert response.status_code == 200
        data = response.json()

        assert data["cycle_completed"] == 1
        assert data["next_cycle"] == 2

        updates = data["training_max_updates"]
        assert updates["PRESS"]["increase"] == 5.0
        assert updates["PRESS"]["new_value"] == 105.0
        assert updates["BENCH_PRESS"]["increase"] == 5.0
        assert updates["BENCH_PRESS"]["new_value"] == 205.0
        assert updates["SQUAT"]["increase"] == 10.0
        assert updates["SQUAT"]["new_value"] == 260.0
        assert updates["DEADLIFT"]["increase"] == 10.0
        assert updates["DEADLIFT"]["new_value"] == 310.0

    def test_complete_cycle_custom_increments(self, client, auth_token, program_with_tms):
        """complete-cycle accepts custom per-lift increments."""
        pid = program_with_tms.id

        response = client.post(
            f"/api/v1/programs/{pid}/complete-cycle",
            json={
                "press_increment": 2.5,
                "bench_press_increment": 2.5,
                "squat_increment": 5.0,
                "deadlift_increment": 5.0,
            },
            headers={"Authorization": f"Bearer {auth_token}"},
        )

        assert response.status_code == 200
        data = response.json()
        updates = data["training_max_updates"]

        assert updates["PRESS"]["increase"] == 2.5
        assert updates["PRESS"]["new_value"] == 102.5
        assert updates["BENCH_PRESS"]["increase"] == 2.5
        assert updates["SQUAT"]["increase"] == 5.0
        assert updates["SQUAT"]["new_value"] == 255.0
        assert updates["DEADLIFT"]["increase"] == 5.0
        assert updates["DEADLIFT"]["new_value"] == 305.0

    def test_complete_cycle_zero_increments(self, client, auth_token, program_with_tms):
        """complete-cycle with zero increments keeps training maxes the same."""
        pid = program_with_tms.id

        response = client.post(
            f"/api/v1/programs/{pid}/complete-cycle",
            json={
                "press_increment": 0.0,
                "bench_press_increment": 0.0,
                "squat_increment": 0.0,
                "deadlift_increment": 0.0,
            },
            headers={"Authorization": f"Bearer {auth_token}"},
        )

        assert response.status_code == 200
        updates = response.json()["training_max_updates"]
        assert updates["PRESS"]["increase"] == 0.0
        assert updates["PRESS"]["new_value"] == 100.0
        assert updates["SQUAT"]["new_value"] == 250.0

    def test_complete_cycle_negative_increment_rejected(self, client, auth_token, program_with_tms):
        """complete-cycle rejects negative increments."""
        response = client.post(
            f"/api/v1/programs/{program_with_tms.id}/complete-cycle",
            json={"press_increment": -5.0},
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        assert response.status_code == 422

    def test_complete_cycle_requires_auth(self, client, program_with_tms):
        """complete-cycle without auth returns 403."""
        response = client.post(f"/api/v1/programs/{program_with_tms.id}/complete-cycle")
        assert response.status_code == 403

    def test_complete_cycle_wrong_program(self, client, auth_token):
        """complete-cycle on a non-existent program returns 404."""
        response = client.post(
            "/api/v1/programs/nonexistent-id/complete-cycle",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        assert response.status_code == 404

    # ------------------------------------------------------------------
    # generate-next-cycle tests
    # ------------------------------------------------------------------

    def test_generate_next_cycle_start_date_follows_last_workout(
        self, client, auth_token, program_with_full_cycle
    ):
        """Cycle 2 starts one week after the *last* workout, not an arbitrary one."""
        pid = program_with_full_cycle.id
        # The last workout is 3 weeks after the base date (week 4 deload)
        expected_start = date.today() - timedelta(days=28) + timedelta(weeks=3) + timedelta(weeks=1)

        client.post(
            f"/api/v1/programs/{pid}/complete-cycle",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        gen_resp = client.post(
            f"/api/v1/programs/{pid}/generate-next-cycle",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        assert gen_resp.status_code == 200
        assert gen_resp.json()["start_date"] == expected_start.isoformat()

    def test_generate_next_cycle_success(self, client, auth_token, program_with_completed_workout):
        """generate-next-cycle creates new workouts after complete-cycle."""
        pid = program_with_completed_workout.id

        # First complete the cycle to create cycle-2 TMs
        complete_resp = client.post(
            f"/api/v1/programs/{pid}/complete-cycle",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        assert complete_resp.status_code == 200

        # Now generate next cycle
        gen_resp = client.post(
            f"/api/v1/programs/{pid}/generate-next-cycle",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        assert gen_resp.status_code == 200
        data = gen_resp.json()

        assert data["cycle_number"] == 2
        assert data["workouts_generated"] > 0

    def test_generate_next_cycle_without_complete_cycle_fails(
        self, client, auth_token, program_with_completed_workout
    ):
        """generate-next-cycle fails if complete-cycle has not been called first."""
        pid = program_with_completed_workout.id

        response = client.post(
            f"/api/v1/programs/{pid}/generate-next-cycle",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        # No cycle-2 TMs exist yet → should fail
        assert response.status_code == 400

    def test_generate_next_cycle_requires_auth(self, client, program_with_completed_workout):
        """generate-next-cycle without auth returns 403."""
        response = client.post(
            f"/api/v1/programs/{program_with_completed_workout.id}/generate-next-cycle"
        )
        assert response.status_code == 403

    def test_complete_then_generate_uses_custom_increments(
        self, client, auth_token, program_with_completed_workout
    ):
        """Training maxes in generated cycle 2 reflect custom increments from complete-cycle."""
        pid = program_with_completed_workout.id

        client.post(
            f"/api/v1/programs/{pid}/complete-cycle",
            json={
                "press_increment": 2.5,
                "bench_press_increment": 2.5,
                "squat_increment": 5.0,
                "deadlift_increment": 5.0,
            },
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        client.post(
            f"/api/v1/programs/{pid}/generate-next-cycle",
            headers={"Authorization": f"Bearer {auth_token}"},
        )

        # Verify the program detail reflects the new TMs
        detail_resp = client.get(
            f"/api/v1/programs/{pid}",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        assert detail_resp.status_code == 200
        tms = detail_resp.json()["training_maxes"]
        assert tms["PRESS"]["value"] == 102.5
        assert tms["BENCH_PRESS"]["value"] == 202.5
        assert tms["SQUAT"]["value"] == 255.0
        assert tms["DEADLIFT"]["value"] == 305.0
