"""
Tests for exercise endpoints.
"""
import pytest
from app.models.user import User
from app.models.exercise import Exercise, ExerciseCategory
from app.utils.security import get_password_hash
import uuid


@pytest.fixture
def test_user(db):
    """Create a test user."""
    user = User(
        id=str(uuid.uuid4()),
        first_name="Test",
        last_name="User",
        email="exerciseuser@example.com",
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
        "email": "exerciseuser@example.com",
        "password": "TestPassword123!"
    })
    assert response.status_code == 200
    return response.json()["access_token"]


@pytest.fixture
def predefined_exercises(db):
    """Create some predefined exercises."""
    exercises = [
        Exercise(
            id=str(uuid.uuid4()),
            name="Dips",
            category=ExerciseCategory.PUSH,
            is_predefined=True,
            description="Bodyweight or weighted dips"
        ),
        Exercise(
            id=str(uuid.uuid4()),
            name="Chin-ups",
            category=ExerciseCategory.PULL,
            is_predefined=True,
            description="Pull-ups or chin-ups"
        ),
        Exercise(
            id=str(uuid.uuid4()),
            name="Lunges",
            category=ExerciseCategory.LEGS,
            is_predefined=True,
            description="Walking or static lunges"
        ),
        Exercise(
            id=str(uuid.uuid4()),
            name="Ab Wheel",
            category=ExerciseCategory.CORE,
            is_predefined=True,
            description="Abdominal wheel rollouts"
        ),
    ]

    for exercise in exercises:
        db.add(exercise)

    db.commit()
    return exercises


class TestExerciseListing:
    """Tests for listing exercises."""

    def test_list_all_exercises(self, client, auth_token, predefined_exercises):
        """Test listing all available exercises."""
        response = client.get(
            "/api/v1/exercises",
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        assert len(data) >= 4  # At least the 4 predefined exercises
        # Predefined exercises should come first (sorted by is_predefined desc)
        assert data[0]["is_predefined"] is True

    def test_list_exercises_by_category(self, client, auth_token, predefined_exercises):
        """Test filtering exercises by category."""
        response = client.get(
            "/api/v1/exercises?category=push",
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        assert len(data) >= 1
        for exercise in data:
            assert exercise["category"] == "push"

    def test_list_only_predefined_exercises(self, client, auth_token, predefined_exercises, db, test_user):
        """Test filtering for only predefined exercises."""
        # Create a custom exercise for the user
        custom_exercise = Exercise(
            id=str(uuid.uuid4()),
            name="My Custom Exercise",
            category=ExerciseCategory.PUSH,
            is_predefined=False,
            user_id=test_user.id,
            description="Custom exercise"
        )
        db.add(custom_exercise)
        db.commit()

        response = client.get(
            "/api/v1/exercises?is_predefined=true",
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        # Should only get predefined exercises
        for exercise in data:
            assert exercise["is_predefined"] is True

    def test_list_only_custom_exercises(self, client, auth_token, predefined_exercises, db, test_user):
        """Test filtering for only custom exercises."""
        # Create a custom exercise for the user
        custom_exercise = Exercise(
            id=str(uuid.uuid4()),
            name="My Custom Exercise",
            category=ExerciseCategory.PULL,
            is_predefined=False,
            user_id=test_user.id,
            description="Custom exercise"
        )
        db.add(custom_exercise)
        db.commit()

        response = client.get(
            "/api/v1/exercises?is_predefined=false",
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        assert len(data) == 1
        assert data[0]["name"] == "My Custom Exercise"
        assert data[0]["is_predefined"] is False

    def test_list_exercises_without_auth_fails(self, client, predefined_exercises):
        """Test that listing exercises without auth fails."""
        response = client.get("/api/v1/exercises")
        assert response.status_code == 403


class TestExerciseCreation:
    """Tests for creating custom exercises."""

    def test_create_custom_exercise(self, client, auth_token):
        """Test creating a custom exercise."""
        exercise_data = {
            "name": "Band Pull-Aparts",
            "category": "pull",
            "description": "Resistance band pull-aparts for rear delts"
        }

        response = client.post(
            "/api/v1/exercises",
            json=exercise_data,
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 201
        data = response.json()

        assert data["name"] == "Band Pull-Aparts"
        assert data["category"] == "pull"
        assert data["description"] == "Resistance band pull-aparts for rear delts"
        assert data["is_predefined"] is False
        assert "id" in data
        assert "created_at" in data

    def test_create_custom_exercise_all_categories(self, client, auth_token):
        """Test creating custom exercises for all categories."""
        categories = ["push", "pull", "legs", "core"]

        for category in categories:
            exercise_data = {
                "name": f"Custom {category.title()} Exercise",
                "category": category,
                "description": f"A custom {category} exercise"
            }

            response = client.post(
                "/api/v1/exercises",
                json=exercise_data,
                headers={"Authorization": f"Bearer {auth_token}"}
            )

            assert response.status_code == 201
            data = response.json()
            assert data["category"] == category

    def test_create_custom_exercise_without_auth_fails(self, client):
        """Test that creating exercise without auth fails."""
        exercise_data = {
            "name": "Test Exercise",
            "category": "push",
            "description": "Test description"
        }

        response = client.post("/api/v1/exercises", json=exercise_data)
        assert response.status_code == 403

    def test_create_custom_exercise_invalid_category(self, client, auth_token):
        """Test that invalid category is rejected."""
        exercise_data = {
            "name": "Test Exercise",
            "category": "invalid_category",
            "description": "Test description"
        }

        response = client.post(
            "/api/v1/exercises",
            json=exercise_data,
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 422  # Validation error

    def test_create_custom_exercise_without_description(self, client, auth_token):
        """Test creating exercise without description (should be optional)."""
        exercise_data = {
            "name": "Minimal Exercise",
            "category": "push"
        }

        response = client.post(
            "/api/v1/exercises",
            json=exercise_data,
            headers={"Authorization": f"Bearer {auth_token}"}
        )

        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Minimal Exercise"

    def test_user_sees_own_custom_exercises_only(self, client, db, predefined_exercises):
        """Test that users only see their own custom exercises."""
        # Create two users
        user1 = User(
            id=str(uuid.uuid4()),
            first_name="User",
            last_name="One",
            email="user1@example.com",
            password_hash=get_password_hash("Password123!")
        )
        user2 = User(
            id=str(uuid.uuid4()),
            first_name="User",
            last_name="Two",
            email="user2@example.com",
            password_hash=get_password_hash("Password123!")
        )
        db.add(user1)
        db.add(user2)
        db.commit()

        # Create custom exercise for user1
        custom_ex1 = Exercise(
            id=str(uuid.uuid4()),
            name="User1 Custom Exercise",
            category=ExerciseCategory.PUSH,
            is_predefined=False,
            user_id=user1.id
        )
        db.add(custom_ex1)
        db.commit()

        # Login as user2
        response = client.post("/api/v1/auth/login", json={
            "email": "user2@example.com",
            "password": "Password123!"
        })
        user2_token = response.json()["access_token"]

        # User2 should NOT see User1's custom exercise
        response = client.get(
            "/api/v1/exercises?is_predefined=false",
            headers={"Authorization": f"Bearer {user2_token}"}
        )

        assert response.status_code == 200
        data = response.json()

        # Should be empty - user2 has no custom exercises
        assert len(data) == 0

        # But user2 should still see predefined exercises
        response = client.get(
            "/api/v1/exercises?is_predefined=true",
            headers={"Authorization": f"Bearer {user2_token}"}
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 4  # At least the predefined exercises
