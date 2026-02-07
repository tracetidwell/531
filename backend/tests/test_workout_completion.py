"""
Tests for workout completion, AMRAP detection, PR creation, and analysis.
"""
from app.models.program import LiftType


class TestWorkoutCompletion:
    """Tests for POST /api/v1/workouts/{workout_id}/complete endpoint."""

    def test_complete_workout_basic(self, client, auth_headers, scheduled_workout):
        """Test completing a workout with all sets logged."""
        sets_data = [
            # Warmup sets
            {"set_type": "warmup", "set_number": 1, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 115},
            {"set_type": "warmup", "set_number": 2, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 145},
            {"set_type": "warmup", "set_number": 3, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 170},
            {"set_type": "warmup", "set_number": 4, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 195},
            # Working sets
            {"set_type": "working", "set_number": 1, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 165},
            {"set_type": "working", "set_number": 2, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 190},
            {"set_type": "amrap", "set_number": 3, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 8, "actual_weight": 215},
        ]

        response = client.post(
            f"/api/v1/workouts/{scheduled_workout.id}/complete",
            json={"sets": sets_data},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert data["workout"]["status"] == "COMPLETED"
        assert "analysis" in data

    def test_complete_workout_with_notes(
        self, client, auth_headers, scheduled_workout
    ):
        """Test completing workout with notes."""
        sets_data = [
            {"set_type": "working", "set_number": 1, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 165},
            {"set_type": "working", "set_number": 2, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 190},
            {"set_type": "amrap", "set_number": 3, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 8, "actual_weight": 215},
        ]

        response = client.post(
            f"/api/v1/workouts/{scheduled_workout.id}/complete",
            json={
                "sets": sets_data,
                "workout_notes": "Felt strong today!"
            },
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert data["workout"]["notes"] == "Felt strong today!"

    def test_complete_already_completed(
        self, client, auth_headers, completed_workout
    ):
        """Test cannot complete an already completed workout."""
        sets_data = [
            {"set_type": "working", "set_number": 1, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 165},
        ]

        response = client.post(
            f"/api/v1/workouts/{completed_workout.id}/complete",
            json={"sets": sets_data},
            headers=auth_headers
        )
        assert response.status_code == 400

    def test_complete_workout_unauthorized(self, client, scheduled_workout):
        """Test completing workout without auth returns 403."""
        sets_data = [
            {"set_type": "working", "set_number": 1, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 165},
        ]

        response = client.post(
            f"/api/v1/workouts/{scheduled_workout.id}/complete",
            json={"sets": sets_data}
        )
        assert response.status_code == 403


class TestMultiLiftWorkoutCompletion:
    """Tests for completing workouts with multiple main lifts."""

    def test_complete_multi_lift_workout(
        self, client, auth_headers, multi_lift_workout
    ):
        """Test completing a workout with multiple main lifts."""
        sets_data = [
            # Squat sets
            {"set_type": "working", "set_number": 1, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 165},
            {"set_type": "working", "set_number": 2, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 190},
            {"set_type": "amrap", "set_number": 3, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 8, "actual_weight": 215},
            # Bench sets
            {"set_type": "working", "set_number": 1, "exercise_id": "bench", "lift_type": "BENCH_PRESS", "actual_reps": 5, "actual_weight": 130},
            {"set_type": "working", "set_number": 2, "exercise_id": "bench", "lift_type": "BENCH_PRESS", "actual_reps": 5, "actual_weight": 150},
            {"set_type": "amrap", "set_number": 3, "exercise_id": "bench", "lift_type": "BENCH_PRESS", "actual_reps": 7, "actual_weight": 170},
        ]

        response = client.post(
            f"/api/v1/workouts/{multi_lift_workout.id}/complete",
            json={"sets": sets_data},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert data["workout"]["status"] == "COMPLETED"
        # Analysis should include both lifts
        assert "analysis" in data
        assert len(data["analysis"]["lifts"]) == 2


class TestWorkoutAnalysis:
    """Tests for workout performance analysis."""

    def test_analysis_all_targets_met(
        self, client, auth_headers, scheduled_workout
    ):
        """Test analysis when all targets are met."""
        sets_data = [
            {"set_type": "working", "set_number": 1, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 165},
            {"set_type": "working", "set_number": 2, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 190},
            {"set_type": "amrap", "set_number": 3, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 8, "actual_weight": 215},
        ]

        response = client.post(
            f"/api/v1/workouts/{scheduled_workout.id}/complete",
            json={"sets": sets_data},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        analysis = data["analysis"]
        assert analysis["overall_success"] is True
        assert len(analysis["lifts"]) == 1
        assert analysis["lifts"][0]["all_targets_met"] is True

    def test_analysis_failed_working_set(
        self, client, auth_headers, scheduled_workout
    ):
        """Test analysis when working set reps are missed."""
        sets_data = [
            {"set_type": "working", "set_number": 1, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 165},
            {"set_type": "working", "set_number": 2, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 3, "actual_weight": 190},  # Failed
            {"set_type": "amrap", "set_number": 3, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 4, "actual_weight": 215},
        ]

        response = client.post(
            f"/api/v1/workouts/{scheduled_workout.id}/complete",
            json={"sets": sets_data},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        analysis = data["analysis"]
        # Should flag failed sets
        assert analysis["lifts"][0]["all_targets_met"] is False

    def test_analysis_has_summary(
        self, client, auth_headers, scheduled_workout
    ):
        """Test analysis includes summary."""
        sets_data = [
            {"set_type": "working", "set_number": 1, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 165},
            {"set_type": "working", "set_number": 2, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 190},
            {"set_type": "amrap", "set_number": 3, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 8, "actual_weight": 215},
        ]

        response = client.post(
            f"/api/v1/workouts/{scheduled_workout.id}/complete",
            json={"sets": sets_data},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "summary" in data["analysis"]
        assert isinstance(data["analysis"]["summary"], str)


class TestAMRAPDetection:
    """Tests for AMRAP set detection and rep max creation."""

    def test_amrap_detection_week_1(
        self, client, auth_headers, scheduled_workout, db, test_user
    ):
        """Test AMRAP detection on week 1 (5+ reps minimum)."""
        sets_data = [
            {"set_type": "working", "set_number": 1, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 165},
            {"set_type": "working", "set_number": 2, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 190},
            {"set_type": "amrap", "set_number": 3, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 10, "actual_weight": 215},
        ]

        response = client.post(
            f"/api/v1/workouts/{scheduled_workout.id}/complete",
            json={"sets": sets_data},
            headers=auth_headers
        )
        assert response.status_code == 200

        # Check that rep max was created
        from app.models import RepMax
        rep_max = db.query(RepMax).filter(
            RepMax.user_id == test_user.id,
            RepMax.lift_type == LiftType.SQUAT,
            RepMax.reps == 10
        ).first()
        assert rep_max is not None
        assert rep_max.weight == 215.0

    def test_amrap_detection_deload_week_no_pr(
        self, client, auth_headers, scheduled_workout_deload, db
    ):
        """Test no AMRAP/PR on deload week."""
        sets_data = [
            {"set_type": "working", "set_number": 1, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 100},
            {"set_type": "working", "set_number": 2, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 125},
            {"set_type": "working", "set_number": 3, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 150},
        ]

        # Count existing rep maxes
        from app.models import RepMax
        initial_count = db.query(RepMax).count()

        response = client.post(
            f"/api/v1/workouts/{scheduled_workout_deload.id}/complete",
            json={"sets": sets_data},
            headers=auth_headers
        )
        assert response.status_code == 200

        # Verify no new rep max was created (deload week)
        final_count = db.query(RepMax).count()
        assert final_count == initial_count


class TestRepMaxPRCreation:
    """Tests for personal record creation on workout completion."""

    def test_pr_created_first_time(
        self, client, auth_headers, scheduled_workout, db, test_user
    ):
        """Test PR is created for first-time rep count."""
        # Ensure no existing rep maxes
        from app.models import RepMax
        db.query(RepMax).filter(RepMax.user_id == test_user.id).delete()
        db.commit()

        sets_data = [
            {"set_type": "working", "set_number": 1, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 165},
            {"set_type": "working", "set_number": 2, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 190},
            {"set_type": "amrap", "set_number": 3, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 7, "actual_weight": 215},
        ]

        response = client.post(
            f"/api/v1/workouts/{scheduled_workout.id}/complete",
            json={"sets": sets_data},
            headers=auth_headers
        )
        assert response.status_code == 200

        # Check that rep max was created
        rep_max = db.query(RepMax).filter(
            RepMax.user_id == test_user.id,
            RepMax.lift_type == LiftType.SQUAT,
            RepMax.reps == 7
        ).first()
        assert rep_max is not None
        assert rep_max.weight == 215.0

    def test_pr_calculated_1rm_epley(
        self, client, auth_headers, scheduled_workout, db, test_user
    ):
        """Test 1RM is calculated using Epley formula."""
        from app.models import RepMax
        db.query(RepMax).filter(RepMax.user_id == test_user.id).delete()
        db.commit()

        weight = 200.0
        reps = 8

        sets_data = [
            {"set_type": "working", "set_number": 1, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 165},
            {"set_type": "working", "set_number": 2, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": 5, "actual_weight": 190},
            {"set_type": "amrap", "set_number": 3, "exercise_id": "squat", "lift_type": "SQUAT", "actual_reps": reps, "actual_weight": weight},
        ]

        response = client.post(
            f"/api/v1/workouts/{scheduled_workout.id}/complete",
            json={"sets": sets_data},
            headers=auth_headers
        )
        assert response.status_code == 200

        rep_max = db.query(RepMax).filter(
            RepMax.user_id == test_user.id,
            RepMax.reps == reps
        ).first()

        if rep_max:
            # Epley formula: weight * (1 + reps/30)
            expected_1rm = weight * (1 + reps / 30)
            assert abs(rep_max.calculated_1rm - expected_1rm) < 0.01


class TestWeekTypeSetGeneration:
    """Tests for correct set generation based on week type."""

    def test_week_1_percentages(self, client, auth_headers, scheduled_workout):
        """Test week 1 uses 65%/75%/85% percentages."""
        response = client.get(
            f"/api/v1/workouts/{scheduled_workout.id}",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        main_sets = data["sets_by_lift"]["SQUAT"]["main_sets"]

        # Week 1 percentages: 65%, 75%, 85%
        expected_percentages = [0.65, 0.75, 0.85]
        for i, workout_set in enumerate(main_sets):
            if workout_set.get("percentage_of_tm"):
                assert abs(workout_set["percentage_of_tm"] - expected_percentages[i]) < 0.01

    def test_week_3_percentages(self, client, auth_headers, scheduled_workout_week3):
        """Test week 3 uses 75%/85%/95% percentages."""
        response = client.get(
            f"/api/v1/workouts/{scheduled_workout_week3.id}",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        main_sets = data["sets_by_lift"]["SQUAT"]["main_sets"]

        # Week 3 percentages: 75%, 85%, 95%
        expected_percentages = [0.75, 0.85, 0.95]
        for i, workout_set in enumerate(main_sets):
            if workout_set.get("percentage_of_tm"):
                assert abs(workout_set["percentage_of_tm"] - expected_percentages[i]) < 0.01

    def test_week_3_reps_531(self, client, auth_headers, scheduled_workout_week3):
        """Test week 3 uses 5/3/1 rep scheme."""
        response = client.get(
            f"/api/v1/workouts/{scheduled_workout_week3.id}",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        main_sets = data["sets_by_lift"]["SQUAT"]["main_sets"]

        # Week 3 reps: 5, 3, 1
        expected_reps = [5, 3, 1]
        for i, workout_set in enumerate(main_sets):
            assert workout_set["prescribed_reps"] == expected_reps[i]

    def test_deload_week_lower_percentages(
        self, client, auth_headers, scheduled_workout_deload
    ):
        """Test deload week uses 40%/50%/60% percentages."""
        response = client.get(
            f"/api/v1/workouts/{scheduled_workout_deload.id}",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        main_sets = data["sets_by_lift"]["SQUAT"]["main_sets"]

        # Deload percentages: 40%, 50%, 60%
        expected_percentages = [0.40, 0.50, 0.60]
        for i, workout_set in enumerate(main_sets):
            if workout_set.get("percentage_of_tm"):
                assert abs(workout_set["percentage_of_tm"] - expected_percentages[i]) < 0.01
