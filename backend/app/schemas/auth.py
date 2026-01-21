"""
Authentication-related Pydantic schemas.
"""
from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional
from datetime import datetime


class UserRegisterRequest(BaseModel):
    """Schema for user registration request."""

    first_name: str = Field(..., min_length=1, max_length=100, description="User's first name")
    last_name: str = Field(..., min_length=1, max_length=100, description="User's last name")
    email: EmailStr = Field(..., description="User's email address (used for login)")
    password: str = Field(..., min_length=8, description="User's password")

    @field_validator('first_name', 'last_name')
    @classmethod
    def validate_name(cls, v: str) -> str:
        """Validate that name is not empty after stripping whitespace."""
        if not v.strip():
            raise ValueError("Name cannot be empty or whitespace only")
        return v.strip()

    class Config:
        json_schema_extra = {
            "example": {
                "first_name": "John",
                "last_name": "Doe",
                "email": "john.doe@example.com",
                "password": "SecurePass123"
            }
        }


class UserLoginRequest(BaseModel):
    """Schema for user login request."""

    email: EmailStr = Field(..., description="User's email address")
    password: str = Field(..., description="User's password")

    class Config:
        json_schema_extra = {
            "example": {
                "email": "john.doe@example.com",
                "password": "SecurePass123"
            }
        }


class TokenResponse(BaseModel):
    """Schema for token response."""

    user_id: str = Field(..., description="User's unique identifier")
    first_name: str = Field(..., description="User's first name")
    last_name: str = Field(..., description="User's last name")
    email: str = Field(..., description="User's email address")
    access_token: str = Field(..., description="JWT access token (15 min expiry)")
    refresh_token: str = Field(..., description="JWT refresh token (7 day expiry)")
    token_type: str = Field(default="bearer", description="Token type")

    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "123e4567-e89b-12d3-a456-426614174000",
                "first_name": "John",
                "last_name": "Doe",
                "email": "john.doe@example.com",
                "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "token_type": "bearer"
            }
        }


class RefreshTokenRequest(BaseModel):
    """Schema for token refresh request."""

    refresh_token: str = Field(..., description="The refresh token")

    class Config:
        json_schema_extra = {
            "example": {
                "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
            }
        }


class RefreshTokenResponse(BaseModel):
    """Schema for token refresh response."""

    access_token: str = Field(..., description="New JWT access token")
    token_type: str = Field(default="bearer", description="Token type")

    class Config:
        json_schema_extra = {
            "example": {
                "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "token_type": "bearer"
            }
        }


class PasswordResetRequest(BaseModel):
    """Schema for password reset request."""

    email: EmailStr = Field(..., description="User's email address")

    class Config:
        json_schema_extra = {
            "example": {
                "email": "john.doe@example.com"
            }
        }


class PasswordResetConfirm(BaseModel):
    """Schema for password reset confirmation."""

    reset_token: str = Field(..., description="Password reset token from email")
    new_password: str = Field(..., min_length=8, description="New password")

    class Config:
        json_schema_extra = {
            "example": {
                "reset_token": "abc123def456",
                "new_password": "NewSecurePass123"
            }
        }


class MessageResponse(BaseModel):
    """Generic message response."""

    message: str = Field(..., description="Response message")

    class Config:
        json_schema_extra = {
            "example": {
                "message": "Operation completed successfully"
            }
        }
