"""
Analytics API endpoints.
"""
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from typing import Optional

from app.database import get_db
from app.schemas.analytics import TrainingMaxProgressionResponse, WorkoutHistoryResponse
from app.services.analytics import AnalyticsService
from app.models.user import User
from app.models.program import LiftType
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.get(
    "/programs/{program_id}/training-max-progression",
    response_model=TrainingMaxProgressionResponse,
    status_code=status.HTTP_200_OK,
    summary="Get training max progression",
    description="Get training max progression over time for all lifts in a program."
)
async def get_training_max_progression(
    program_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> TrainingMaxProgressionResponse:
    """
    Get training max progression analytics.

    Returns historical training max data for all lifts in the program,
    showing how training maxes have changed over time across cycles.

    Data is grouped by lift type (squat, deadlift, bench_press, press)
    and includes the date, value, and cycle number for each change.

    This is useful for visualizing progress charts.
    """
    return AnalyticsService.get_training_max_progression(db, current_user, program_id)


@router.get(
    "/programs/{program_id}/workout-history",
    response_model=WorkoutHistoryResponse,
    status_code=status.HTTP_200_OK,
    summary="Get workout history",
    description="Get detailed workout history with performance statistics."
)
async def get_workout_history(
    program_id: str,
    lift_type: Optional[LiftType] = Query(None, description="Filter by lift type"),
    limit: int = Query(20, ge=1, le=100, description="Number of results per page"),
    offset: int = Query(0, ge=0, description="Offset for pagination"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> WorkoutHistoryResponse:
    """
    Get workout history with key statistics.

    Returns completed workouts with AMRAP performance data including:
    - Reps completed in AMRAP set
    - Weight used in AMRAP set
    - Calculated 1RM from AMRAP performance

    Supports filtering by lift type and pagination.

    Workouts are returned in reverse chronological order (most recent first).
    """
    return AnalyticsService.get_workout_history(
        db, current_user, program_id, lift_type, limit, offset
    )
