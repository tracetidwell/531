"""
Tests for authentication endpoints.
"""
import pytest
from fastapi import status


class TestUserRegistration:
    """Tests for user registration endpoint."""

    def test_register_user_success(self, client):
        """Test successful user registration."""
        response = client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john.doe@example.com",
                "password": "SecurePass123"
            }
        )

        assert response.status_code == status.HTTP_201_CREATED

        data = response.json()
        assert "user_id" in data
        assert data["first_name"] == "John"
        assert data["last_name"] == "Doe"
        assert data["email"] == "john.doe@example.com"
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"

    def test_register_duplicate_email(self, client):
        """Test registration with duplicate email fails."""
        # Register first user
        client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john.doe@example.com",
                "password": "SecurePass123"
            }
        )

        # Try to register with same email
        response = client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "Jane",
                "last_name": "Smith",
                "email": "john.doe@example.com",
                "password": "AnotherPass123"
            }
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "Email already registered" in response.json()["detail"]

    def test_register_weak_password(self, client):
        """Test registration with weak password fails."""
        # Too short
        response = client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john@example.com",
                "password": "short"
            }
        )
        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

        # No uppercase
        response = client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john@example.com",
                "password": "lowercase123"
            }
        )
        assert response.status_code == status.HTTP_400_BAD_REQUEST

        # No lowercase
        response = client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john@example.com",
                "password": "UPPERCASE123"
            }
        )
        assert response.status_code == status.HTTP_400_BAD_REQUEST

        # No number
        response = client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john@example.com",
                "password": "NoNumbers"
            }
        )
        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_register_invalid_email(self, client):
        """Test registration with invalid email format fails."""
        response = client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "not-an-email",
                "password": "SecurePass123"
            }
        )

        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    def test_register_empty_name(self, client):
        """Test registration with empty name fails."""
        response = client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "   ",
                "last_name": "Doe",
                "email": "john@example.com",
                "password": "SecurePass123"
            }
        )

        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


class TestUserLogin:
    """Tests for user login endpoint."""

    def test_login_success(self, client):
        """Test successful user login."""
        # First register a user
        client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john.doe@example.com",
                "password": "SecurePass123"
            }
        )

        # Now login
        response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "john.doe@example.com",
                "password": "SecurePass123"
            }
        )

        assert response.status_code == status.HTTP_200_OK

        data = response.json()
        assert data["email"] == "john.doe@example.com"
        assert data["first_name"] == "John"
        assert data["last_name"] == "Doe"
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"

    def test_login_wrong_password(self, client):
        """Test login with wrong password fails."""
        # Register user
        client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john@example.com",
                "password": "SecurePass123"
            }
        )

        # Try to login with wrong password
        response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "john@example.com",
                "password": "WrongPassword123"
            }
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        assert "Invalid email or password" in response.json()["detail"]

    def test_login_nonexistent_user(self, client):
        """Test login with non-existent email fails."""
        response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "nonexistent@example.com",
                "password": "SomePassword123"
            }
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        assert "Invalid email or password" in response.json()["detail"]

    def test_login_case_insensitive_email(self, client):
        """Test that email login is case-insensitive."""
        # Register with lowercase email
        client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john.doe@example.com",
                "password": "SecurePass123"
            }
        )

        # Login with uppercase email
        response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "JOHN.DOE@EXAMPLE.COM",
                "password": "SecurePass123"
            }
        )

        assert response.status_code == status.HTTP_200_OK


class TestTokenRefresh:
    """Tests for token refresh endpoint."""

    def test_refresh_token_success(self, client):
        """Test successful token refresh."""
        # Register and get tokens
        register_response = client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john@example.com",
                "password": "SecurePass123"
            }
        )

        refresh_token = register_response.json()["refresh_token"]

        # Refresh the access token
        response = client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token}
        )

        assert response.status_code == status.HTTP_200_OK

        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"

    def test_refresh_token_invalid(self, client):
        """Test refresh with invalid token fails."""
        response = client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": "invalid.token.here"}
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_refresh_token_with_access_token(self, client):
        """Test that using access token for refresh fails."""
        # Register and get tokens
        register_response = client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john@example.com",
                "password": "SecurePass123"
            }
        )

        access_token = register_response.json()["access_token"]

        # Try to refresh using access token (should fail)
        response = client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": access_token}
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        assert "Invalid token type" in response.json()["detail"]


class TestAuthenticatedEndpoints:
    """Tests for authenticated endpoints."""

    def test_get_current_user(self, client):
        """Test getting current user profile."""
        # Register user
        register_response = client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john@example.com",
                "password": "SecurePass123"
            }
        )

        access_token = register_response.json()["access_token"]

        # Get user profile
        response = client.get(
            "/api/v1/users/me",
            headers={"Authorization": f"Bearer {access_token}"}
        )

        assert response.status_code == status.HTTP_200_OK

        data = response.json()
        assert data["first_name"] == "John"
        assert data["last_name"] == "Doe"
        assert data["email"] == "john@example.com"
        assert data["weight_unit_preference"] == "lbs"
        assert data["rounding_increment"] == 5.0
        assert data["missed_workout_preference"] == "ask"

    def test_get_current_user_unauthorized(self, client):
        """Test accessing protected endpoint without token fails."""
        response = client.get("/api/v1/users/me")

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_update_current_user(self, client):
        """Test updating current user profile."""
        # Register user
        register_response = client.post(
            "/api/v1/auth/register",
            json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john@example.com",
                "password": "SecurePass123"
            }
        )

        access_token = register_response.json()["access_token"]

        # Update profile
        response = client.put(
            "/api/v1/users/me",
            headers={"Authorization": f"Bearer {access_token}"},
            json={
                "first_name": "Jane",
                "weight_unit_preference": "kg",
                "rounding_increment": 2.5,
                "missed_workout_preference": "reschedule"
            }
        )

        assert response.status_code == status.HTTP_200_OK

        data = response.json()
        assert data["first_name"] == "Jane"
        assert data["last_name"] == "Doe"  # Unchanged
        assert data["weight_unit_preference"] == "kg"
        assert data["rounding_increment"] == 2.5
        assert data["missed_workout_preference"] == "reschedule"
