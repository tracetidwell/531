"""
Analytics-related Pydantic schemas.
"""
from pydantic import BaseModel, Field
from typing import Dict, List, Optional
from app.models.program import LiftType
from app.models.workout import WeekType


class TrainingMaxDataPoint(BaseModel):
    """Single data point in training max progression."""

    date: str = Field(..., description="Date when this training max became effective (YYYY-MM-DD)")
    value: float = Field(..., description="Training max value")
    cycle: int = Field(..., description="Cycle number")

    class Config:
        json_schema_extra = {
            "example": {
                "date": "2024-01-01",
                "value": 275.0,
                "cycle": 1
            }
        }


class TrainingMaxProgressionResponse(BaseModel):
    """Response for training max progression analytics."""

    data: Dict[str, List[TrainingMaxDataPoint]] = Field(
        ...,
        description="Training max progression data grouped by lift type"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "data": {
                    "squat": [
                        {"date": "2024-01-01", "value": 275.0, "cycle": 1},
                        {"date": "2024-01-29", "value": 285.0, "cycle": 2},
                        {"date": "2024-02-26", "value": 295.0, "cycle": 3}
                    ],
                    "deadlift": [
                        {"date": "2024-01-01", "value": 325.0, "cycle": 1},
                        {"date": "2024-01-29", "value": 335.0, "cycle": 2}
                    ]
                }
            }
        }


class WorkoutKeyStats(BaseModel):
    """Key statistics from a workout (AMRAP performance)."""

    amrap_reps: Optional[int] = Field(None, description="Reps completed in AMRAP set")
    amrap_weight: Optional[float] = Field(None, description="Weight used in AMRAP set")
    calculated_1rm: Optional[float] = Field(None, description="Calculated 1RM from AMRAP set")

    class Config:
        json_schema_extra = {
            "example": {
                "amrap_reps": 8,
                "amrap_weight": 270.0,
                "calculated_1rm": 342.0
            }
        }


class WorkoutHistoryItem(BaseModel):
    """Single workout in history."""

    id: str = Field(..., description="Workout ID")
    date: str = Field(..., description="Date workout was completed (YYYY-MM-DD)")
    lift: LiftType = Field(..., description="Main lift performed")
    cycle: int = Field(..., description="Cycle number")
    week: int = Field(..., description="Week number (1-4)")
    week_type: WeekType = Field(..., description="Week type (5s, 3s, 5/3/1, deload)")
    key_stats: WorkoutKeyStats = Field(..., description="Key performance statistics")
    notes: Optional[str] = Field(None, description="Workout notes")

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": "uuid-here",
                "date": "2024-12-15",
                "lift": "squat",
                "cycle": 3,
                "week": 2,
                "week_type": "week_2_3s",
                "key_stats": {
                    "amrap_reps": 8,
                    "amrap_weight": 270.0,
                    "calculated_1rm": 342.0
                },
                "notes": "Felt strong today!"
            }
        }


class WorkoutHistoryResponse(BaseModel):
    """Response for workout history analytics."""

    workouts: List[WorkoutHistoryItem] = Field(..., description="List of workout history items")
    total: int = Field(..., description="Total number of workouts matching criteria")
    limit: int = Field(..., description="Number of results per page")
    offset: int = Field(..., description="Offset for pagination")

    class Config:
        json_schema_extra = {
            "example": {
                "workouts": [
                    {
                        "id": "uuid-here",
                        "date": "2024-12-15",
                        "lift": "squat",
                        "cycle": 3,
                        "week": 2,
                        "week_type": "week_2_3s",
                        "key_stats": {
                            "amrap_reps": 8,
                            "amrap_weight": 270.0,
                            "calculated_1rm": 342.0
                        },
                        "notes": "Felt strong!"
                    }
                ],
                "total": 45,
                "limit": 20,
                "offset": 0
            }
        }
