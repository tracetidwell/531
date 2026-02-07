"""
Tests for analytics endpoints.
"""
from datetime import date


class TestTrainingMaxProgression:
    """Tests for GET /api/v1/analytics/programs/{program_id}/training-max-progression."""

    def test_get_tm_progression_success(
        self, client, auth_headers, test_program_with_training_maxes
    ):
        """Test getting training max progression returns data."""
        program_id = test_program_with_training_maxes.id
        response = client.get(
            f"/api/v1/analytics/programs/{program_id}/training-max-progression",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "data" in data

    def test_get_tm_progression_has_all_lifts(
        self, client, auth_headers, test_program_with_training_maxes, db
    ):
        """Test TM progression includes lifts that have history records."""
        from app.models.program import TrainingMaxHistory, LiftType, TrainingMaxReason
        from datetime import datetime
        import uuid

        program_id = test_program_with_training_maxes.id

        # Add training max history records
        for lift_type in [LiftType.SQUAT, LiftType.DEADLIFT]:
            history = TrainingMaxHistory(
                id=str(uuid.uuid4()),
                program_id=program_id,
                lift_type=lift_type,
                old_value=200.0,
                new_value=250.0,
                reason=TrainingMaxReason.INITIAL,
                change_date=datetime.utcnow()
            )
            db.add(history)
        db.commit()

        response = client.get(
            f"/api/v1/analytics/programs/{program_id}/training-max-progression",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()

        # Should have progressions for lifts with history
        progressions = data["data"]
        assert "SQUAT" in progressions
        assert "DEADLIFT" in progressions

    def test_get_tm_progression_data_points(
        self, client, auth_headers, test_program_with_training_maxes, db
    ):
        """Test TM progression data point structure."""
        from app.models.program import TrainingMaxHistory, LiftType, TrainingMaxReason
        from datetime import datetime
        import uuid

        program_id = test_program_with_training_maxes.id

        # Add training max history record
        history = TrainingMaxHistory(
            id=str(uuid.uuid4()),
            program_id=program_id,
            lift_type=LiftType.SQUAT,
            old_value=200.0,
            new_value=250.0,
            reason=TrainingMaxReason.INITIAL,
            change_date=datetime.utcnow()
        )
        db.add(history)
        db.commit()

        response = client.get(
            f"/api/v1/analytics/programs/{program_id}/training-max-progression",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()

        squat_progression = data["data"]["SQUAT"]
        assert len(squat_progression) >= 1

        # Check data point structure
        point = squat_progression[0]
        assert "date" in point
        assert "value" in point
        assert "cycle" in point

    def test_get_tm_progression_program_not_found(self, client, auth_headers):
        """Test getting TM progression for non-existent program."""
        response = client.get(
            "/api/v1/analytics/programs/nonexistent-id/training-max-progression",
            headers=auth_headers
        )
        assert response.status_code == 404

    def test_get_tm_progression_other_user_program(
        self, client, auth_headers, second_user, db
    ):
        """Test cannot access other user's program analytics."""
        from app.models import Program
        from app.models.program import ProgramStatus
        import uuid

        # Create program for second user
        other_program = Program(
            id=str(uuid.uuid4()),
            user_id=second_user.id,
            name="Other User Program",
            template_type="4_day",
            start_date=date.today(),
            training_days=["monday", "wednesday", "friday"],
            status=ProgramStatus.ACTIVE
        )
        db.add(other_program)
        db.commit()

        response = client.get(
            f"/api/v1/analytics/programs/{other_program.id}/training-max-progression",
            headers=auth_headers
        )
        assert response.status_code == 404

    def test_get_tm_progression_unauthorized(
        self, client, test_program_with_training_maxes
    ):
        """Test getting TM progression without auth returns 403."""
        program_id = test_program_with_training_maxes.id
        response = client.get(
            f"/api/v1/analytics/programs/{program_id}/training-max-progression"
        )
        assert response.status_code == 403


class TestWorkoutHistory:
    """Tests for GET /api/v1/analytics/programs/{program_id}/workout-history."""

    def test_get_workout_history_success(
        self, client, auth_headers, completed_workout
    ):
        """Test getting workout history returns data."""
        program_id = completed_workout.program_id
        response = client.get(
            f"/api/v1/analytics/programs/{program_id}/workout-history",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "workouts" in data
        assert "total" in data

    def test_get_workout_history_includes_completed(
        self, client, auth_headers, completed_workout
    ):
        """Test workout history includes completed workouts."""
        program_id = completed_workout.program_id
        response = client.get(
            f"/api/v1/analytics/programs/{program_id}/workout-history",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["workouts"]) >= 1

    def test_get_workout_history_filter_by_lift(
        self, client, auth_headers, completed_workout
    ):
        """Test filtering workout history by lift type."""
        program_id = completed_workout.program_id
        response = client.get(
            f"/api/v1/analytics/programs/{program_id}/workout-history",
            params={"lift_type": "SQUAT"},
            headers=auth_headers
        )
        assert response.status_code == 200

    def test_get_workout_history_pagination(
        self, client, auth_headers, completed_workout
    ):
        """Test workout history pagination."""
        program_id = completed_workout.program_id
        response = client.get(
            f"/api/v1/analytics/programs/{program_id}/workout-history",
            params={"limit": 5, "offset": 0},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["workouts"]) <= 5

    def test_get_workout_history_program_not_found(self, client, auth_headers):
        """Test getting workout history for non-existent program."""
        response = client.get(
            "/api/v1/analytics/programs/nonexistent-id/workout-history",
            headers=auth_headers
        )
        assert response.status_code == 404

    def test_get_workout_history_unauthorized(
        self, client, completed_workout
    ):
        """Test getting workout history without auth returns 403."""
        program_id = completed_workout.program_id
        response = client.get(
            f"/api/v1/analytics/programs/{program_id}/workout-history"
        )
        assert response.status_code == 403
