"""
Exercise-related Pydantic schemas.
"""
from pydantic import BaseModel, Field
from typing import Optional
from app.models.exercise import ExerciseCategory


class ExerciseResponse(BaseModel):
    """Schema for exercise response."""

    id: str = Field(..., description="Exercise ID")
    name: str = Field(..., description="Exercise name")
    category: ExerciseCategory = Field(..., description="Exercise category")
    is_predefined: bool = Field(..., description="Whether this is a predefined exercise from the book")
    description: Optional[str] = Field(None, description="Exercise description")

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": "uuid-here",
                "name": "Dumbbell Bench Press",
                "category": "push",
                "is_predefined": True,
                "description": "Bench press with dumbbells"
            }
        }


class ExerciseCreateRequest(BaseModel):
    """Schema for creating a custom exercise."""

    name: str = Field(..., min_length=1, max_length=255, description="Exercise name")
    category: ExerciseCategory = Field(..., description="Exercise category")
    description: Optional[str] = Field(None, max_length=500, description="Exercise description")

    class Config:
        json_schema_extra = {
            "example": {
                "name": "My Custom Exercise",
                "category": "push",
                "description": "A custom accessory exercise"
            }
        }
