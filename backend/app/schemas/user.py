"""
User-related Pydantic schemas.
"""
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime
from app.models.user import WeightUnit, MissedWorkoutPreference


class UserResponse(BaseModel):
    """Schema for user response."""

    id: str = Field(..., description="User's unique identifier")
    first_name: str = Field(..., description="User's first name")
    last_name: str = Field(..., description="User's last name")
    email: str = Field(..., description="User's email address")
    weight_unit_preference: WeightUnit = Field(..., description="Preferred weight unit")
    rounding_increment: float = Field(..., description="Weight rounding increment")
    missed_workout_preference: MissedWorkoutPreference = Field(..., description="How to handle missed workouts")
    created_at: datetime = Field(..., description="Account creation timestamp")

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": "123e4567-e89b-12d3-a456-426614174000",
                "first_name": "John",
                "last_name": "Doe",
                "email": "john.doe@example.com",
                "weight_unit_preference": "lbs",
                "rounding_increment": 5.0,
                "missed_workout_preference": "ask",
                "created_at": "2024-01-15T10:30:00"
            }
        }


class UserUpdateRequest(BaseModel):
    """Schema for updating user profile."""

    first_name: Optional[str] = Field(None, min_length=1, max_length=100, description="User's first name")
    last_name: Optional[str] = Field(None, min_length=1, max_length=100, description="User's last name")
    weight_unit_preference: Optional[WeightUnit] = Field(None, description="Preferred weight unit")
    rounding_increment: Optional[float] = Field(None, ge=1.0, le=10.0, description="Weight rounding increment")
    missed_workout_preference: Optional[MissedWorkoutPreference] = Field(None, description="How to handle missed workouts")

    class Config:
        json_schema_extra = {
            "example": {
                "first_name": "John",
                "last_name": "Doe",
                "weight_unit_preference": "kg",
                "rounding_increment": 2.5,
                "missed_workout_preference": "reschedule"
            }
        }
