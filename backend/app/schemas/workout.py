"""
Workout schemas for API requests and responses.
"""
from pydantic import BaseModel, Field
from typing import List, Optional, Dict
from datetime import date, datetime
from app.models.workout import WeekType, WorkoutStatus, SetType
from app.models.program import LiftType


class WorkoutMainLiftResponse(BaseModel):
    """Response model for a main lift in a workout."""
    lift_type: str
    lift_order: int
    current_training_max: float

    class Config:
        from_attributes = True


class WorkoutSetResponse(BaseModel):
    """Response model for a workout set (prescribed or logged)."""
    id: Optional[str] = None
    set_type: str
    set_number: int
    prescribed_reps: Optional[int]
    prescribed_weight: Optional[float]
    percentage_of_tm: Optional[float]
    actual_reps: Optional[int] = None
    actual_weight: Optional[float] = None
    is_target_met: Optional[bool] = None
    notes: Optional[str] = None
    exercise_id: Optional[str] = None
    circuit_group: Optional[int] = None  # For circuit training (null = standalone)

    class Config:
        from_attributes = True


class WorkoutResponse(BaseModel):
    """Basic workout information."""
    id: str
    program_id: str
    scheduled_date: date
    completed_date: Optional[datetime]
    cycle_number: int
    week_number: int
    week_type: str
    main_lifts: List[WorkoutMainLiftResponse]
    status: str
    notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class WorkoutSetsForLift(BaseModel):
    """Sets organized by type for a specific lift."""
    warmup_sets: List[WorkoutSetResponse]
    main_sets: List[WorkoutSetResponse]


class WorkoutDetailResponse(BaseModel):
    """Detailed workout with prescribed sets organized by lift."""
    id: str
    program_id: str
    scheduled_date: date
    completed_date: Optional[datetime]
    cycle_number: int
    week_number: int
    week_type: str
    main_lifts: List[WorkoutMainLiftResponse]
    status: str

    # Prescribed sets organized by lift type
    # Structure: {"squat": {"warmup_sets": [...], "main_sets": [...]}, ...}
    sets_by_lift: Dict[str, WorkoutSetsForLift]

    # Accessory sets at workout level (not per-lift)
    accessory_sets: List[WorkoutSetResponse]

    # Additional info
    notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class SetLogRequest(BaseModel):
    """Request to log a single set."""
    set_type: str = Field(..., description="warmup, working, or accessory")
    set_number: int = Field(..., ge=1, description="Set number (1-based)")
    exercise_id: str = Field(..., description="Exercise ID (for accessories)")
    lift_type: Optional[str] = Field(None, description="Lift type for multi-lift workouts (squat, bench, deadlift, press)")
    actual_reps: int = Field(..., ge=0, description="Actual reps completed")
    actual_weight: float = Field(..., ge=0, description="Actual weight used")
    weight_unit: str = Field(default="lbs", description="lbs or kg")
    notes: Optional[str] = Field(None, max_length=500)


class WorkoutCompleteRequest(BaseModel):
    """Request to complete a workout with all logged sets."""
    sets: List[SetLogRequest] = Field(..., min_length=1, description="All sets performed")
    workout_notes: Optional[str] = Field(None, max_length=1000)
    completed_date: Optional[datetime] = Field(None, description="When workout was completed (defaults to now)")


class WorkoutListFilters(BaseModel):
    """Filters for listing workouts."""
    program_id: Optional[str] = None
    status: Optional[WorkoutStatus] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    main_lifts: Optional[List[LiftType]] = None
    cycle_number: Optional[int] = None
    week_number: Optional[int] = None


class FailedSetInfo(BaseModel):
    """Information about a failed set."""
    set_number: int = Field(..., description="Which set failed (1-3)")
    set_type: str = Field(..., description="working or amrap")
    prescribed_reps: int = Field(..., description="Target reps")
    actual_reps: int = Field(..., description="Actual reps performed")
    prescribed_weight: float = Field(..., description="Target weight")


class LiftAnalysis(BaseModel):
    """Analysis of performance for a single lift."""
    lift_type: str = Field(..., description="The lift type (squat, deadlift, bench_press, press)")
    all_targets_met: bool = Field(..., description="Whether all working set targets were met")
    failed_sets: List[FailedSetInfo] = Field(default_factory=list, description="List of sets that failed to meet target")
    amrap_reps: Optional[int] = Field(None, description="Reps achieved on AMRAP set (if applicable)")
    amrap_minimum: Optional[int] = Field(None, description="Minimum required reps on AMRAP")
    amrap_exceeded_minimum: Optional[bool] = Field(None, description="Whether AMRAP exceeded minimum")
    current_training_max: float = Field(..., description="Current training max for this lift")
    estimated_1rm: Optional[float] = Field(None, description="Estimated 1RM based on AMRAP performance (Epley formula)")
    suggested_training_max: Optional[float] = Field(None, description="Suggested new training max (90% of estimated 1RM)")
    recommendation: Optional[str] = Field(None, description="Recommendation based on performance")
    recommendation_type: Optional[str] = Field(None, description="Type of recommendation: info, warning, or critical")


class CycleFailedRepsAnalysis(BaseModel):
    """Analysis of failed reps across an entire cycle."""
    recommendation: str = Field(..., description="Recommendation type: none, adjust_training_max, deload_then_adjust")
    lifts: List[str] = Field(default_factory=list, description="Affected lift types")
    message: str = Field(..., description="Human-readable recommendation message")


class WorkoutAnalysis(BaseModel):
    """Complete analysis of a workout."""
    overall_success: bool = Field(..., description="Whether all lifts met their targets")
    lifts: List[LiftAnalysis] = Field(..., description="Analysis for each lift in the workout")
    summary: str = Field(..., description="Human-readable summary of workout performance")
    has_recommendations: bool = Field(..., description="Whether there are any recommendations")
    cycle_analysis: Optional[CycleFailedRepsAnalysis] = Field(
        None, description="Cycle-level analysis if there are failures across the cycle"
    )


class WorkoutCompletionResponse(BaseModel):
    """Response for workout completion including analysis."""
    workout: WorkoutResponse = Field(..., description="The completed workout")
    analysis: WorkoutAnalysis = Field(..., description="Analysis of workout performance")


class MissedWorkoutInfo(BaseModel):
    """Information about a missed workout."""
    workout: WorkoutResponse = Field(..., description="The missed workout")
    days_overdue: int = Field(..., description="Days since scheduled date")
    can_reschedule: bool = Field(..., description="Whether rescheduling is possible")


class MissedWorkoutsResponse(BaseModel):
    """Response containing all missed workouts."""
    missed_workouts: List[MissedWorkoutInfo] = Field(..., description="List of missed workouts")
    user_preference: str = Field(..., description="User's missed workout preference (skip/reschedule/ask)")
    count: int = Field(..., description="Number of missed workouts")


class HandleMissedWorkoutRequest(BaseModel):
    """Request to handle a missed workout."""
    action: str = Field(..., description="Action to take: 'skip' or 'reschedule'")
    reschedule_date: Optional[date] = Field(None, description="Date to reschedule to (required if action is 'reschedule')")


class HandleMissedWorkoutResponse(BaseModel):
    """Response after handling a missed workout."""
    workout: WorkoutResponse = Field(..., description="The updated workout")
    action_taken: str = Field(..., description="Action that was taken")
    rescheduled_count: int = Field(0, description="Number of workouts rescheduled (including cascaded)")
