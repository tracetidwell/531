"""
Tests for rep max (personal records) endpoints.
"""
import pytest
from datetime import date, timedelta


class TestGetAllRepMaxes:
    """Tests for GET /api/v1/rep-maxes endpoint."""

    def test_get_all_rep_maxes_success(self, client, auth_headers, test_rep_max):
        """Test getting all rep maxes returns data."""
        response = client.get("/api/v1/rep-maxes", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "lifts" in data
        # Should have SQUAT data from test_rep_max fixture
        assert "SQUAT" in data["lifts"]

    def test_get_all_rep_maxes_structure(
        self, client, auth_headers, multiple_rep_maxes
    ):
        """Test response structure has all lift types."""
        response = client.get("/api/v1/rep-maxes", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()

        # Should have lifts dict
        assert "lifts" in data
        lifts = data["lifts"]

        # Should have entries for lifts with PRs
        assert "SQUAT" in lifts
        assert "BENCH_PRESS" in lifts

    def test_get_all_rep_maxes_rep_max_fields(
        self, client, auth_headers, test_rep_max
    ):
        """Test rep max response includes correct fields."""
        response = client.get("/api/v1/rep-maxes", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()

        squat_maxes = data["lifts"]["SQUAT"]
        # Should have entry for 8 reps (from test_rep_max fixture)
        assert "8" in squat_maxes
        rm_data = squat_maxes["8"]
        assert "weight" in rm_data
        assert "calculated_1rm" in rm_data
        assert "achieved_date" in rm_data
        assert "weight_unit" in rm_data

    def test_get_all_rep_maxes_empty(self, client, auth_headers, test_user):
        """Test getting rep maxes when none exist."""
        response = client.get("/api/v1/rep-maxes", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "lifts" in data
        # All lifts should be null or empty
        for lift in ["SQUAT", "DEADLIFT", "BENCH_PRESS", "PRESS"]:
            assert data["lifts"].get(lift) is None or data["lifts"].get(lift) == {}

    def test_get_all_rep_maxes_unauthorized(self, client):
        """Test getting rep maxes without auth returns 403."""
        response = client.get("/api/v1/rep-maxes")
        assert response.status_code == 403

    def test_get_all_rep_maxes_best_per_rep_count(
        self, client, auth_headers, multiple_rep_maxes, db
    ):
        """Test only best PR per rep count is returned."""
        from app.models import RepMax
        from app.models.program import LiftType
        from app.models.workout import WeightUnit
        import uuid

        # Get user from fixture
        user_id = multiple_rep_maxes[0].user_id

        # Add a worse 5-rep squat PR (lower 1RM)
        worse_pr = RepMax(
            id=str(uuid.uuid4()),
            user_id=user_id,
            lift_type=LiftType.SQUAT,
            reps=5,
            weight=200.0,  # Lower than existing 225
            weight_unit=WeightUnit.LBS,
            calculated_1rm=200.0 * (1 + 5/30),
            achieved_date=date.today() - timedelta(days=14),
            workout_set_id=str(uuid.uuid4())
        )
        db.add(worse_pr)
        db.commit()

        response = client.get("/api/v1/rep-maxes", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()

        # Should return the better PR (225 lbs)
        squat_5_rm = data["lifts"]["SQUAT"]["5"]
        assert squat_5_rm["weight"] == 225.0


class TestGetRepMaxesByLift:
    """Tests for GET /api/v1/rep-maxes/{lift_type} endpoint."""

    def test_get_rep_maxes_by_lift_success(
        self, client, auth_headers, test_rep_max
    ):
        """Test getting rep maxes for specific lift."""
        response = client.get("/api/v1/rep-maxes/squat", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["lift_type"] == "squat"
        assert "rep_maxes" in data

    def test_get_rep_maxes_by_lift_has_records(
        self, client, auth_headers, test_rep_max
    ):
        """Test rep maxes by lift returns actual records."""
        response = client.get("/api/v1/rep-maxes/squat", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        # Should have 8-rep max from fixture
        assert "8" in data["rep_maxes"]
        assert data["rep_maxes"]["8"]["weight"] == 215.0

    def test_get_rep_maxes_by_lift_empty(self, client, auth_headers, test_user):
        """Test getting rep maxes for lift with no records."""
        response = client.get("/api/v1/rep-maxes/deadlift", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["lift_type"] == "deadlift"
        assert data["rep_maxes"] == {} or data["rep_maxes"] is None

    def test_get_rep_maxes_invalid_lift(self, client, auth_headers, test_user):
        """Test getting rep maxes for invalid lift type."""
        response = client.get("/api/v1/rep-maxes/invalid", headers=auth_headers)
        assert response.status_code == 422  # Validation error

    def test_get_rep_maxes_by_lift_unauthorized(self, client):
        """Test getting rep maxes by lift without auth returns 403."""
        response = client.get("/api/v1/rep-maxes/squat")
        assert response.status_code == 403

    def test_get_rep_maxes_all_valid_lifts(
        self, client, auth_headers, test_user
    ):
        """Test all valid lift types are accepted."""
        valid_lifts = ["squat", "deadlift", "bench_press", "press"]
        for lift in valid_lifts:
            response = client.get(
                f"/api/v1/rep-maxes/{lift}",
                headers=auth_headers
            )
            assert response.status_code == 200
            assert response.json()["lift_type"] == lift
