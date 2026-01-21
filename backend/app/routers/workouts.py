"""
Workout API endpoints.
"""
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import date
from app.database import get_db
from app.schemas.workout import (
    WorkoutResponse, WorkoutDetailResponse, WorkoutCompleteRequest,
    WorkoutCompletionResponse, MissedWorkoutsResponse, HandleMissedWorkoutRequest,
    HandleMissedWorkoutResponse
)
from app.services.workout import WorkoutService
from app.models.user import User
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.get(
    "",
    response_model=List[WorkoutResponse],
    status_code=status.HTTP_200_OK,
    summary="List workouts",
    description="Get workouts for the current user with optional filters."
)
async def list_workouts(
    program_id: Optional[str] = Query(None, description="Filter by program ID"),
    workout_status: Optional[str] = Query(None, description="Filter by status (scheduled, completed, skipped)"),
    start_date: Optional[date] = Query(None, description="Filter by date >= start_date"),
    end_date: Optional[date] = Query(None, description="Filter by date <= end_date"),
    main_lifts: Optional[List[str]] = Query(None, description="Filter by main lifts (press, deadlift, bench_press, squat)"),
    cycle_number: Optional[int] = Query(None, description="Filter by cycle number"),
    week_number: Optional[int] = Query(None, ge=1, le=4, description="Filter by week number (1-4)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> List[WorkoutResponse]:
    """
    Get workouts for the current user.

    Optional filters:
    - program_id: Show workouts from specific program
    - status: scheduled, completed, or skipped
    - start_date/end_date: Date range
    - main_lifts: Filter by lift types (workouts containing any of these lifts)
    - cycle_number: Filter by cycle
    - week_number: Filter by week (1-4)

    Returns workouts ordered by scheduled date.
    """
    return WorkoutService.get_workouts(
        db,
        current_user,
        program_id=program_id,
        workout_status=workout_status,
        start_date=start_date,
        end_date=end_date,
        main_lifts=main_lifts,
        cycle_number=cycle_number,
        week_number=week_number
    )


@router.get(
    "/{workout_id}",
    response_model=WorkoutDetailResponse,
    status_code=status.HTTP_200_OK,
    summary="Get workout details",
    description="Get detailed workout information including all prescribed sets."
)
async def get_workout(
    workout_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> WorkoutDetailResponse:
    """
    Get detailed workout information.

    Returns:
    - Workout info (date, cycle, week, lift)
    - Warmup sets (4 sets with prescribed weights/reps)
    - Main working sets (3 sets, last one is AMRAP on non-deload weeks)
    - Accessory sets (from program template)
    - Current training max

    Use this before starting a workout to see what you need to lift.
    """
    return WorkoutService.get_workout_detail(db, current_user, workout_id)


@router.post(
    "/{workout_id}/complete",
    response_model=WorkoutCompletionResponse,
    status_code=status.HTTP_200_OK,
    summary="Complete workout",
    description="Log all sets, mark workout as completed, and get performance analysis."
)
async def complete_workout(
    workout_id: str,
    completion_data: WorkoutCompleteRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> WorkoutCompletionResponse:
    """
    Complete a workout by logging all performed sets.

    Required:
    - sets: List of all sets performed (warmup, working, accessory)
      - Each set needs: set_type, set_number, exercise_id, actual_reps, actual_weight
    - workout_notes: Optional notes about the workout

    The system will:
    - Save all logged sets
    - Detect AMRAP performance on last working set
    - Update rep max records if you hit a PR
    - Mark workout as completed
    - Analyze performance and generate recommendations

    Response includes:
    - workout: The completed workout details
    - analysis: Performance analysis with per-lift breakdown and recommendations
      - Recommendations based on AMRAP performance
      - Suggestions for training max adjustments if needed

    Example sets:
    ```json
    {
      "sets": [
        {"set_type": "warmup", "set_number": 1, "exercise_id": "...", "actual_reps": 5, "actual_weight": 45},
        {"set_type": "warmup", "set_number": 2, "exercise_id": "...", "actual_reps": 5, "actual_weight": 95},
        {"set_type": "working", "set_number": 1, "exercise_id": "...", "actual_reps": 5, "actual_weight": 155},
        {"set_type": "working", "set_number": 2, "exercise_id": "...", "actual_reps": 5, "actual_weight": 180},
        {"set_type": "working", "set_number": 3, "exercise_id": "...", "actual_reps": 8, "actual_weight": 200},
        {"set_type": "accessory", "set_number": 1, "exercise_id": "...", "actual_reps": 10, "actual_weight": 50}
      ],
      "workout_notes": "Felt strong today!"
    }
    ```
    """
    return WorkoutService.complete_workout(db, current_user, workout_id, completion_data)


@router.post(
    "/{workout_id}/skip",
    response_model=WorkoutResponse,
    status_code=status.HTTP_200_OK,
    summary="Skip workout",
    description="Mark a workout as intentionally skipped."
)
async def skip_workout(
    workout_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> WorkoutResponse:
    """
    Skip a workout.

    Use this when you intentionally decide not to complete a workout
    (e.g., due to travel, illness, or scheduling conflicts).

    This is different from a missed workout (unintentional).

    The workout status will be changed to 'skipped'.

    Note: Cannot skip a workout that is already completed or skipped.
    """
    return WorkoutService.skip_workout(db, current_user, workout_id)


@router.get(
    "/missed",
    response_model=MissedWorkoutsResponse,
    summary="Get missed workouts",
    description="Get all workouts that are past their scheduled date but not completed."
)
async def get_missed_workouts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> MissedWorkoutsResponse:
    """
    Get all missed workouts for the current user.

    A workout is considered "missed" if:
    - Its status is still 'scheduled'
    - Its scheduled_date is before today

    The response includes:
    - List of missed workouts with days overdue
    - User's missed workout preference (skip/reschedule/ask)
    - Whether each workout can still be rescheduled (within 14 days)
    """
    return WorkoutService.get_missed_workouts(db, current_user)


@router.post(
    "/{workout_id}/handle-missed",
    response_model=HandleMissedWorkoutResponse,
    summary="Handle missed workout",
    description="Skip or reschedule a missed workout."
)
async def handle_missed_workout(
    workout_id: str,
    request: HandleMissedWorkoutRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> HandleMissedWorkoutResponse:
    """
    Handle a missed workout by either skipping or rescheduling it.

    Actions:
    - **skip**: Mark the workout as skipped. It won't affect other workouts.
    - **reschedule**: Move the workout to a new date. All future scheduled
      workouts in the same program will also be shifted by the same number of days.

    For reschedule:
    - If no reschedule_date is provided, defaults to today
    - Cannot reschedule to a past date
    - All future workouts cascade (shift by same number of days)

    Example:
    ```json
    {"action": "skip"}
    ```
    or
    ```json
    {"action": "reschedule", "reschedule_date": "2026-01-20"}
    ```
    """
    return WorkoutService.handle_missed_workout(db, current_user, workout_id, request)
