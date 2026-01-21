"""
Program-related Pydantic schemas.
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional, Dict, List
from datetime import date, datetime
from app.models.program import ProgramStatus, LiftType


class TrainingMaxInput(BaseModel):
    """Schema for setting training max for a lift."""

    squat: float = Field(..., gt=0, description="Training max for squat (in user's preferred unit)")
    deadlift: float = Field(..., gt=0, description="Training max for deadlift")
    bench_press: float = Field(..., gt=0, description="Training max for bench press")
    press: float = Field(..., gt=0, description="Training max for overhead press")

    class Config:
        json_schema_extra = {
            "example": {
                "squat": 300.0,
                "deadlift": 350.0,
                "bench_press": 225.0,
                "press": 150.0
            }
        }


class AccessoryExerciseInput(BaseModel):
    """Schema for an accessory exercise in a program."""

    exercise_id: str = Field(..., description="ID of the exercise")
    sets: int = Field(default=5, ge=1, le=10, description="Number of sets")
    reps: int = Field(default=12, ge=1, le=50, description="Number of reps")
    circuit_group: Optional[int] = Field(
        default=None,
        ge=1,
        description="Circuit group number (exercises with same number are done as a circuit). None = standalone exercise."
    )

    class Config:
        json_schema_extra = {
            "example": {
                "exercise_id": "uuid-here",
                "sets": 5,
                "reps": 12,
                "circuit_group": 1
            }
        }


class ProgramCreateRequest(BaseModel):
    """Schema for creating a new program."""

    name: str = Field(..., min_length=1, max_length=255, description="Program name")
    template_type: str = Field(default="4_day", description="Program template (2_day, 3_day, or 4_day)")
    start_date: date = Field(..., description="Program start date")
    end_date: Optional[date] = Field(None, description="Program end date (optional)")
    target_cycles: Optional[int] = Field(None, ge=1, le=52, description="Number of cycles to run (optional)")
    training_days: List[str] = Field(..., min_length=2, max_length=4, description="Days to train (2-4 days)")
    include_deload: bool = Field(default=True, description="Include deload week (week 4) in each cycle")
    training_maxes: TrainingMaxInput = Field(..., description="Training maxes for each lift")
    accessories: Dict[str, List[AccessoryExerciseInput]] = Field(
        ...,
        description="Accessories per day (keys: '1','2' for 2_day, '1','2','3' for 3_day, or '1','2','3','4' for 4_day)"
    )

    @field_validator('training_days')
    @classmethod
    def validate_training_days(cls, v: List[str], info) -> List[str]:
        """Validate training days based on template type."""
        valid_days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']

        # Get template_type from values if available
        template_type = info.data.get('template_type', '4_day')

        # Validate based on template type
        expected_days = {
            '2_day': 2,
            '3_day': 3,
            '4_day': 4
        }.get(template_type, 4)

        if len(v) != expected_days:
            raise ValueError(f"Template '{template_type}' requires exactly {expected_days} training days")

        for day in v:
            if day.lower() not in valid_days:
                raise ValueError(f"Invalid day: {day}. Must be one of: {valid_days}")

        # Check for duplicates
        if len(set(d.lower() for d in v)) != len(v):
            raise ValueError("Training days must be unique")

        return [d.lower() for d in v]

    @field_validator('accessories')
    @classmethod
    def validate_accessories(cls, v: Dict[str, List[AccessoryExerciseInput]], info) -> Dict[str, List[AccessoryExerciseInput]]:
        """Validate accessories for each workout type based on template type."""
        template_type = info.data.get('template_type', '4_day')

        # Determine required workout types based on template
        # Workout types represent main lift combinations, not calendar days:
        # - 2-day: 2 workout types (Squat+Bench, Deadlift+Press)
        # - 3-day: 4 workout types (one per lift, since lifts rotate across days)
        # - 4-day: 4 workout types (one per lift)
        required_workout_types_map = {
            '2_day': {'1', '2'},
            '3_day': {'1', '2', '3', '4'},  # Changed: 3-day needs 4 workout types (one per lift)
            '4_day': {'1', '2', '3', '4'}
        }
        required_workout_types = required_workout_types_map.get(template_type, {'1', '2', '3', '4'})

        if set(v.keys()) != required_workout_types:
            raise ValueError(f"Template '{template_type}' requires accessories for workout types: {required_workout_types}")

        for workout_type, exercises in v.items():
            if len(exercises) > 5:  # Allow up to 5 accessories per workout type
                raise ValueError(f"Workout type {workout_type} must have 0-5 accessory exercises")

        return v

    @field_validator('template_type')
    @classmethod
    def validate_template_type(cls, v: str) -> str:
        """Validate template type."""
        valid_templates = ['2_day', '3_day', '4_day']
        if v not in valid_templates:
            raise ValueError(f"Template must be one of: {valid_templates}")
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "name": "Winter 2025 Program",
                "template_type": "4_day",
                "start_date": "2025-01-01",
                "end_date": None,
                "target_cycles": 4,
                "training_days": ["monday", "tuesday", "thursday", "saturday"],
                "training_maxes": {
                    "squat": 300.0,
                    "deadlift": 350.0,
                    "bench_press": 225.0,
                    "press": 150.0
                },
                "accessories": {
                    "1": [
                        {"exercise_id": "uuid-1", "sets": 5, "reps": 12},
                        {"exercise_id": "uuid-2", "sets": 5, "reps": 12}
                    ],
                    "2": [
                        {"exercise_id": "uuid-3", "sets": 5, "reps": 12}
                    ],
                    "3": [
                        {"exercise_id": "uuid-4", "sets": 5, "reps": 12},
                        {"exercise_id": "uuid-5", "sets": 5, "reps": 12}
                    ],
                    "4": [
                        {"exercise_id": "uuid-6", "sets": 5, "reps": 12}
                    ]
                }
            }
        }


class TrainingMaxResponse(BaseModel):
    """Schema for training max response."""

    value: float = Field(..., description="Current training max value")
    effective_date: date = Field(..., description="Date when this TM became effective")
    cycle: int = Field(..., description="Cycle number")

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "value": 300.0,
                "effective_date": "2025-01-01",
                "cycle": 1
            }
        }


class ProgramResponse(BaseModel):
    """Schema for program response."""

    id: str = Field(..., description="Program ID")
    name: str = Field(..., description="Program name")
    template_type: str = Field(..., description="Program template type")
    start_date: date = Field(..., description="Start date")
    end_date: Optional[date] = Field(None, description="End date")
    status: ProgramStatus = Field(..., description="Program status")
    training_days: List[str] = Field(..., description="Training days")
    created_at: datetime = Field(..., description="Creation timestamp")

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": "uuid-here",
                "name": "Winter 2025 Program",
                "template_type": "4_day",
                "start_date": "2025-01-01",
                "end_date": None,
                "status": "active",
                "training_days": ["monday", "tuesday", "thursday", "saturday"],
                "created_at": "2025-01-01T10:00:00"
            }
        }


class ProgramDetailResponse(BaseModel):
    """Schema for detailed program response with training maxes."""

    id: str = Field(..., description="Program ID")
    name: str = Field(..., description="Program name")
    template_type: str = Field(..., description="Program template type")
    start_date: date = Field(..., description="Start date")
    end_date: Optional[date] = Field(None, description="End date")
    target_cycles: Optional[int] = Field(None, description="Number of cycles to run")
    status: ProgramStatus = Field(..., description="Program status")
    training_days: List[str] = Field(..., description="Training days")
    current_cycle: int = Field(default=1, description="Current cycle number")
    current_week: int = Field(default=1, description="Current week number")
    training_maxes: Dict[str, TrainingMaxResponse] = Field(..., description="Current training maxes")
    workouts_generated: int = Field(..., description="Number of workouts generated")
    created_at: datetime = Field(..., description="Creation timestamp")

    class Config:
        json_schema_extra = {
            "example": {
                "id": "uuid-here",
                "name": "Winter 2025 Program",
                "template_type": "4_day",
                "start_date": "2025-01-01",
                "end_date": None,
                "target_cycles": 4,
                "status": "active",
                "training_days": ["monday", "tuesday", "thursday", "saturday"],
                "current_cycle": 1,
                "current_week": 1,
                "training_maxes": {
                    "squat": {"value": 300.0, "effective_date": "2025-01-01", "cycle": 1},
                    "deadlift": {"value": 350.0, "effective_date": "2025-01-01", "cycle": 1},
                    "bench_press": {"value": 225.0, "effective_date": "2025-01-01", "cycle": 1},
                    "press": {"value": 150.0, "effective_date": "2025-01-01", "cycle": 1}
                },
                "workouts_generated": 16,
                "created_at": "2025-01-01T10:00:00"
            }
        }


class ProgramUpdateRequest(BaseModel):
    """Schema for updating a program."""

    name: Optional[str] = Field(None, min_length=1, max_length=255, description="Program name")
    status: Optional[ProgramStatus] = Field(None, description="Program status")
    end_date: Optional[date] = Field(None, description="End date")
    target_cycles: Optional[int] = Field(None, ge=1, le=52, description="Number of cycles to run")

    class Config:
        json_schema_extra = {
            "example": {
                "name": "Updated Program Name",
                "status": "paused",
                "target_cycles": 4
            }
        }
