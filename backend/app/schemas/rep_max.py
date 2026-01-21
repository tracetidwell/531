"""
Rep max (personal records) schemas.
"""
from pydantic import BaseModel, Field, ConfigDict
from datetime import date
from typing import Dict, Optional


class RepMaxRecord(BaseModel):
    """Individual rep max record."""
    weight: float = Field(..., description="Weight lifted")
    calculated_1rm: float = Field(..., description="Calculated 1RM using Epley formula")
    achieved_date: date = Field(..., description="Date the PR was achieved")
    weight_unit: str = Field(..., description="Weight unit (lbs or kg)")

    model_config = ConfigDict(from_attributes=True)


class RepMaxByRepsResponse(BaseModel):
    """Rep maxes organized by rep count for a single lift."""
    lift_type: str = Field(..., description="Lift type (squat, deadlift, bench_press, press)")
    rep_maxes: Dict[int, RepMaxRecord] = Field(
        ...,
        description="Rep maxes keyed by rep count (1-12)"
    )

    model_config = ConfigDict(from_attributes=True)


class AllRepMaxesResponse(BaseModel):
    """All rep maxes for all lifts."""
    squat: Optional[Dict[int, RepMaxRecord]] = Field(None, description="Squat rep maxes")
    deadlift: Optional[Dict[int, RepMaxRecord]] = Field(None, description="Deadlift rep maxes")
    bench_press: Optional[Dict[int, RepMaxRecord]] = Field(None, description="Bench press rep maxes")
    press: Optional[Dict[int, RepMaxRecord]] = Field(None, description="Press rep maxes")

    model_config = ConfigDict(from_attributes=True)
