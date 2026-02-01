"""
Tests for workout listing, detail, and skip endpoints.
"""
import pytest
from datetime import date, timedelta


class TestWorkoutListing:
    """Tests for GET /api/v1/workouts endpoint."""

    def test_list_workouts_success(self, client, auth_headers, scheduled_workout):
        """Test listing workouts returns workouts."""
        response = client.get("/api/v1/workouts", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    def test_list_workouts_filter_by_status_completed(
        self, client, auth_headers, completed_workout
    ):
        """Test filtering workouts by COMPLETED status."""
        response = client.get(
            "/api/v1/workouts",
            params={"workout_status": "COMPLETED"},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        for workout in data:
            assert workout["status"] == "COMPLETED"

    def test_list_workouts_filter_by_status_scheduled(
        self, client, auth_headers, scheduled_workout
    ):
        """Test filtering workouts by SCHEDULED status."""
        response = client.get(
            "/api/v1/workouts",
            params={"workout_status": "SCHEDULED"},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        for workout in data:
            assert workout["status"] == "SCHEDULED"

    def test_list_workouts_filter_by_date_range(
        self, client, auth_headers, scheduled_workout
    ):
        """Test filtering workouts by date range."""
        today = date.today()
        response = client.get(
            "/api/v1/workouts",
            params={
                "start_date": (today - timedelta(days=1)).isoformat(),
                "end_date": (today + timedelta(days=1)).isoformat()
            },
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        # Should include today's workout
        assert len(data) >= 1

    def test_list_workouts_filter_by_cycle(
        self, client, auth_headers, scheduled_workout
    ):
        """Test filtering workouts by cycle number."""
        response = client.get(
            "/api/v1/workouts",
            params={"cycle_number": 1},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        for workout in data:
            assert workout["cycle_number"] == 1

    def test_list_workouts_filter_by_week(
        self, client, auth_headers, scheduled_workout
    ):
        """Test filtering workouts by week number."""
        response = client.get(
            "/api/v1/workouts",
            params={"week_number": 1},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        for workout in data:
            assert workout["week_number"] == 1

    def test_list_workouts_empty_result(
        self, client, auth_headers, scheduled_workout
    ):
        """Test filtering with no matches returns empty list."""
        response = client.get(
            "/api/v1/workouts",
            params={"cycle_number": 999},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert data == []

    def test_list_workouts_unauthorized(self, client, scheduled_workout):
        """Test listing workouts without auth returns 403."""
        response = client.get("/api/v1/workouts")
        assert response.status_code == 403

    def test_list_workouts_other_user_excluded(
        self, client, auth_headers, scheduled_workout, second_user, db
    ):
        """Test that other user's workouts are not visible."""
        from app.models import Program, Workout, WorkoutMainLift
        from app.models.program import LiftType, ProgramStatus
        from app.models.workout import WorkoutStatus, WeekType
        import uuid

        # Create a program and workout for second user
        other_program = Program(
            id=str(uuid.uuid4()),
            user_id=second_user.id,
            name="Other User Program",
            template_type="4_day",
            start_date=date.today(),
            training_days=["monday"],
            status=ProgramStatus.ACTIVE
        )
        db.add(other_program)
        db.flush()

        other_workout = Workout(
            id=str(uuid.uuid4()),
            program_id=other_program.id,
            scheduled_date=date.today(),
            cycle_number=1,
            week_number=1,
            week_type=WeekType.WEEK_1_5S,
            status=WorkoutStatus.SCHEDULED
        )
        db.add(other_workout)
        db.commit()

        # List workouts for test_user
        response = client.get("/api/v1/workouts", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()

        # Should not include other user's workout
        workout_ids = [w["id"] for w in data]
        assert other_workout.id not in workout_ids


class TestWorkoutDetail:
    """Tests for GET /api/v1/workouts/{workout_id} endpoint."""

    def test_get_workout_detail_scheduled(
        self, client, auth_headers, scheduled_workout
    ):
        """Test getting scheduled workout detail."""
        response = client.get(
            f"/api/v1/workouts/{scheduled_workout.id}",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == scheduled_workout.id
        assert data["status"] == "SCHEDULED"
        assert "sets_by_lift" in data
        assert "accessory_sets" in data

    def test_get_workout_detail_completed(
        self, client, auth_headers, completed_workout
    ):
        """Test getting completed workout detail includes actual values."""
        response = client.get(
            f"/api/v1/workouts/{completed_workout.id}",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "COMPLETED"
        assert data["completed_date"] is not None

    def test_get_workout_detail_has_main_lifts(
        self, client, auth_headers, scheduled_workout
    ):
        """Test workout detail includes main lifts."""
        response = client.get(
            f"/api/v1/workouts/{scheduled_workout.id}",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "main_lifts" in data
        assert len(data["main_lifts"]) >= 1
        assert "lift_type" in data["main_lifts"][0]
        assert "current_training_max" in data["main_lifts"][0]

    def test_get_workout_detail_has_sets_by_lift(
        self, client, auth_headers, scheduled_workout
    ):
        """Test workout detail includes sets organized by lift."""
        response = client.get(
            f"/api/v1/workouts/{scheduled_workout.id}",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "sets_by_lift" in data
        # Should have entry for SQUAT (the main lift)
        assert "SQUAT" in data["sets_by_lift"]
        lift_sets = data["sets_by_lift"]["SQUAT"]
        assert "warmup_sets" in lift_sets
        assert "main_sets" in lift_sets

    def test_get_workout_detail_warmup_sets(
        self, client, auth_headers, scheduled_workout
    ):
        """Test warmup sets are calculated correctly."""
        response = client.get(
            f"/api/v1/workouts/{scheduled_workout.id}",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        warmup_sets = data["sets_by_lift"]["SQUAT"]["warmup_sets"]
        # Should have 4 warmup sets
        assert len(warmup_sets) == 4
        # First warmup should be lighter than last
        assert warmup_sets[0]["prescribed_weight"] < warmup_sets[-1]["prescribed_weight"]

    def test_get_workout_detail_main_sets_week_1(
        self, client, auth_headers, scheduled_workout
    ):
        """Test main sets for week 1 (5s week)."""
        response = client.get(
            f"/api/v1/workouts/{scheduled_workout.id}",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        main_sets = data["sets_by_lift"]["SQUAT"]["main_sets"]
        # Should have 3 working sets
        assert len(main_sets) == 3
        # Week 1 reps should be 5
        for workout_set in main_sets:
            assert workout_set["prescribed_reps"] == 5

    def test_get_workout_detail_not_found(self, client, auth_headers):
        """Test getting non-existent workout returns 404."""
        response = client.get(
            "/api/v1/workouts/nonexistent-id",
            headers=auth_headers
        )
        assert response.status_code == 404

    def test_get_workout_detail_other_user(
        self, client, auth_headers, second_user, db
    ):
        """Test cannot access other user's workout."""
        from app.models import Program, Workout
        from app.models.program import ProgramStatus
        from app.models.workout import WorkoutStatus, WeekType
        import uuid

        other_program = Program(
            id=str(uuid.uuid4()),
            user_id=second_user.id,
            name="Other Program",
            template_type="4_day",
            start_date=date.today(),
            training_days=["monday"],
            status=ProgramStatus.ACTIVE
        )
        db.add(other_program)
        db.flush()

        other_workout = Workout(
            id=str(uuid.uuid4()),
            program_id=other_program.id,
            scheduled_date=date.today(),
            cycle_number=1,
            week_number=1,
            week_type=WeekType.WEEK_1_5S,
            status=WorkoutStatus.SCHEDULED
        )
        db.add(other_workout)
        db.commit()

        response = client.get(
            f"/api/v1/workouts/{other_workout.id}",
            headers=auth_headers
        )
        assert response.status_code == 404

    def test_get_workout_detail_unauthorized(self, client, scheduled_workout):
        """Test getting workout detail without auth returns 403."""
        response = client.get(f"/api/v1/workouts/{scheduled_workout.id}")
        assert response.status_code == 403


class TestWorkoutSkip:
    """Tests for POST /api/v1/workouts/{workout_id}/skip endpoint."""

    def test_skip_workout_success(self, client, auth_headers, scheduled_workout):
        """Test skipping a scheduled workout."""
        response = client.post(
            f"/api/v1/workouts/{scheduled_workout.id}/skip",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "SKIPPED"

    def test_skip_already_completed(self, client, auth_headers, completed_workout):
        """Test cannot skip an already completed workout."""
        response = client.post(
            f"/api/v1/workouts/{completed_workout.id}/skip",
            headers=auth_headers
        )
        assert response.status_code == 400

    def test_skip_workout_not_found(self, client, auth_headers):
        """Test skipping non-existent workout returns 404."""
        response = client.post(
            "/api/v1/workouts/nonexistent-id/skip",
            headers=auth_headers
        )
        assert response.status_code == 404

    def test_skip_workout_unauthorized(self, client, scheduled_workout):
        """Test skipping workout without auth returns 403."""
        response = client.post(f"/api/v1/workouts/{scheduled_workout.id}/skip")
        assert response.status_code == 403


class TestMissedWorkouts:
    """Tests for missed workout endpoints."""

    def test_get_missed_workouts(
        self, client, auth_headers, past_scheduled_workout
    ):
        """Test getting missed workouts."""
        response = client.get(
            "/api/v1/workouts/missed",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "missed_workouts" in data
        assert "count" in data

    def test_missed_workout_days_overdue(
        self, client, auth_headers, past_scheduled_workout
    ):
        """Test missed workout includes days_overdue."""
        response = client.get(
            "/api/v1/workouts/missed",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        if data["count"] > 0:
            missed = data["missed_workouts"][0]
            assert "days_overdue" in missed
            assert missed["days_overdue"] >= 1

    def test_handle_missed_skip(
        self, client, auth_headers, past_scheduled_workout
    ):
        """Test handling missed workout with skip action."""
        response = client.post(
            f"/api/v1/workouts/{past_scheduled_workout.id}/handle-missed",
            json={"action": "skip"},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert data["action_taken"] == "skipped"
        assert data["workout"]["status"] == "SKIPPED"

    def test_handle_missed_reschedule(
        self, client, auth_headers, past_scheduled_workout
    ):
        """Test handling missed workout with reschedule action."""
        new_date = (date.today() + timedelta(days=1)).isoformat()
        response = client.post(
            f"/api/v1/workouts/{past_scheduled_workout.id}/handle-missed",
            json={"action": "reschedule", "reschedule_date": new_date},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert data["action_taken"] == "rescheduled"

    def test_handle_missed_invalid_action(
        self, client, auth_headers, past_scheduled_workout
    ):
        """Test handling missed workout with invalid action."""
        response = client.post(
            f"/api/v1/workouts/{past_scheduled_workout.id}/handle-missed",
            json={"action": "invalid"},
            headers=auth_headers
        )
        assert response.status_code == 400

    def test_get_missed_workouts_unauthorized(self, client):
        """Test getting missed workouts without auth returns 403."""
        response = client.get("/api/v1/workouts/missed")
        assert response.status_code == 403
