"""
Warmup template-related Pydantic schemas.
"""
from pydantic import BaseModel, Field, field_validator
from typing import List, Optional
from app.models.program import LiftType


class WarmupSet(BaseModel):
    """Schema for a single warmup set."""

    weight_type: str = Field(
        ...,
        description="Type of weight: 'bar', 'fixed', or 'percentage'"
    )
    value: Optional[float] = Field(
        None,
        description="Weight value (null for 'bar', fixed weight for 'fixed', percentage for 'percentage')"
    )
    reps: int = Field(..., ge=1, description="Number of reps")

    @field_validator('weight_type')
    @classmethod
    def validate_weight_type(cls, v):
        valid_types = ['bar', 'fixed', 'percentage']
        if v not in valid_types:
            raise ValueError(f"weight_type must be one of {valid_types}")
        return v

    @field_validator('value')
    @classmethod
    def validate_value(cls, v, info):
        weight_type = info.data.get('weight_type')
        if weight_type == 'bar' and v is not None:
            raise ValueError("value must be null when weight_type is 'bar'")
        if weight_type in ['fixed', 'percentage'] and v is None:
            raise ValueError(f"value is required when weight_type is '{weight_type}'")
        if weight_type == 'percentage' and (v < 0 or v > 100):
            raise ValueError("percentage value must be between 0 and 100")
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "weight_type": "percentage",
                "value": 50,
                "reps": 5
            }
        }


class WarmupTemplateResponse(BaseModel):
    """Schema for warmup template response."""

    id: str = Field(..., description="Warmup template ID")
    name: str = Field(..., description="Template name")
    lift_type: LiftType = Field(..., description="Lift this template applies to")
    is_default: bool = Field(..., description="Whether this is the default template for this lift")
    sets: List[WarmupSet] = Field(..., description="Array of warmup sets")

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": "uuid-here",
                "name": "My Squat Warmup",
                "lift_type": "squat",
                "is_default": True,
                "sets": [
                    {"weight_type": "bar", "value": None, "reps": 10},
                    {"weight_type": "fixed", "value": 135, "reps": 5},
                    {"weight_type": "percentage", "value": 50, "reps": 5},
                    {"weight_type": "percentage", "value": 70, "reps": 2}
                ]
            }
        }


class WarmupTemplateCreateRequest(BaseModel):
    """Schema for creating a warmup template."""

    name: str = Field(..., min_length=1, max_length=255, description="Template name")
    lift_type: LiftType = Field(..., description="Lift this template applies to")
    is_default: bool = Field(False, description="Whether this should be the default template for this lift")
    sets: List[WarmupSet] = Field(
        ...,
        min_length=1,
        description="Array of warmup sets (at least one required)"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "name": "My Squat Warmup",
                "lift_type": "squat",
                "is_default": False,
                "sets": [
                    {"weight_type": "bar", "value": None, "reps": 10},
                    {"weight_type": "fixed", "value": 135, "reps": 5},
                    {"weight_type": "percentage", "value": 50, "reps": 5},
                    {"weight_type": "percentage", "value": 70, "reps": 2}
                ]
            }
        }
