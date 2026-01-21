"""
Program management API endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.schemas.program import (
    ProgramCreateRequest,
    ProgramResponse,
    ProgramDetailResponse,
    ProgramUpdateRequest
)
from app.services.program import ProgramService
from app.models.user import User
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.post(
    "",
    response_model=ProgramDetailResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new program",
    description="Create a new training program with training maxes, training days, and accessories."
)
async def create_program(
    program_data: ProgramCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> ProgramDetailResponse:
    """
    Create a new 5/3/1 training program.

    Requirements:
    - User can only have one active program at a time
    - Must specify 4 training days
    - Must set training maxes for all 4 lifts
    - Must select 1-3 accessories per training day

    The system will:
    - Generate the first 4-week cycle of workouts
    - Assign main lifts to training days (Press, Deadlift, Bench, Squat)
    - Create training max records
    - Set up program templates with accessories
    """
    return ProgramService.create_program(db, current_user, program_data)


@router.get(
    "",
    response_model=List[ProgramResponse],
    status_code=status.HTTP_200_OK,
    summary="List all programs",
    description="Get all programs for the current user (active, completed, paused)."
)
async def list_programs(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> List[ProgramResponse]:
    """
    Get all programs for the current user.

    Programs are returned in reverse chronological order (newest first).
    Includes programs of all statuses: active, completed, and paused.
    """
    return ProgramService.get_user_programs(db, current_user)


@router.get(
    "/{program_id}",
    response_model=ProgramDetailResponse,
    status_code=status.HTTP_200_OK,
    summary="Get program details",
    description="Get detailed information about a specific program."
)
async def get_program(
    program_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> ProgramDetailResponse:
    """
    Get detailed program information.

    Returns:
    - Program details (name, dates, status)
    - Current training maxes for all lifts
    - Current cycle and week
    - Number of workouts generated
    """
    return ProgramService.get_program_detail(db, current_user, program_id)


@router.put(
    "/{program_id}",
    response_model=ProgramResponse,
    status_code=status.HTTP_200_OK,
    summary="Update program",
    description="Update program name, status, or end date."
)
async def update_program(
    program_id: str,
    update_data: ProgramUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> ProgramResponse:
    """
    Update a program.

    Updatable fields:
    - name: Change program name
    - status: Change status (active, paused, completed)
    - end_date: Set or update end date
    """
    return ProgramService.update_program(db, current_user, program_id, update_data)


@router.post(
    "/{program_id}/complete-cycle",
    status_code=status.HTTP_200_OK,
    summary="Complete cycle and increase training maxes",
    description="Finish current cycle and automatically increase training maxes per 5/3/1 methodology."
)
async def complete_cycle(
    program_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> dict:
    """
    Complete the current cycle and increase training maxes.

    Per Jim Wendler's 5/3/1 methodology:
    - Upper body lifts (Press, Bench Press): +5 lbs
    - Lower body lifts (Squat, Deadlift): +10 lbs

    This endpoint:
    - Creates new TrainingMax records for the next cycle
    - Records the progression in TrainingMaxHistory
    - Does NOT generate new workouts (use generate-next-cycle for that)

    Returns:
    - cycle_completed: The cycle number that was just finished
    - next_cycle: The new cycle number
    - training_max_updates: Details of each lift's progression

    Example response:
    ```json
    {
      "cycle_completed": 1,
      "next_cycle": 2,
      "training_max_updates": {
        "press": {"old_value": 100, "new_value": 105, "increase": 5},
        "bench_press": {"old_value": 200, "new_value": 205, "increase": 5},
        "squat": {"old_value": 250, "new_value": 260, "increase": 10},
        "deadlift": {"old_value": 300, "new_value": 310, "increase": 10}
      }
    }
    ```
    """
    return ProgramService.complete_cycle(db, current_user, program_id)


@router.post(
    "/{program_id}/generate-next-cycle",
    status_code=status.HTTP_200_OK,
    summary="Generate next 4-week cycle",
    description="Create 16 new workouts for the next cycle using updated training maxes."
)
async def generate_next_cycle(
    program_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> dict:
    """
    Generate the next 4-week cycle of workouts.

    Prerequisites:
    - You must call /complete-cycle first to increase training maxes
    - Training maxes must exist for the next cycle

    This endpoint:
    - Generates 16 new workouts (4 weeks × 4 days)
    - Uses the updated training maxes from complete-cycle
    - Schedules workouts starting 1 week after the last workout

    Returns:
    - cycle_number: The cycle number that was generated
    - start_date: When the new cycle begins
    - workouts_generated: Number of workouts created (should be 16)

    Typical flow:
    1. Complete all workouts in Cycle 1
    2. Call POST /complete-cycle → Training maxes increase
    3. Call POST /generate-next-cycle → Cycle 2 workouts created
    4. Continue training!
    """
    return ProgramService.generate_next_cycle(db, current_user, program_id)


@router.delete(
    "/{program_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete program",
    description="Delete a program and all associated data (workouts, training maxes, etc.)."
)
async def delete_program(
    program_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> None:
    """
    Delete a program and all its associated data.

    This will permanently delete:
    - The program itself
    - All workouts and workout sets
    - All training maxes and training max history
    - All program templates

    This action cannot be undone.
    """
    ProgramService.delete_program(db, current_user, program_id)
