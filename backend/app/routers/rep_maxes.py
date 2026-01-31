"""
Rep max (personal records) API endpoints.
"""
from fastapi import APIRouter, Depends, Path, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.rep_max import RepMaxByRepsResponse, AllRepMaxesResponse
from app.services.rep_max import RepMaxService
from app.models.user import User
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.get(
    "",
    response_model=AllRepMaxesResponse,
    status_code=status.HTTP_200_OK,
    summary="Get all rep maxes",
    description="Get personal records (rep maxes) for all lifts across all rep ranges (1-12)."
)
async def get_all_rep_maxes(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> AllRepMaxesResponse:
    """
    Get all personal records for the current user.

    Returns rep maxes for all 4 main lifts (squat, deadlift, bench_press, press)
    organized by rep count (1-12 reps).

    For each rep count, only the best performance (highest calculated 1RM) is returned.

    Example response:
    ```json
    {
      "lifts": {
        "SQUAT": {
          "1": {"weight": 315, "calculated_1rm": 315, "achieved_date": "2024-12-15", "weight_unit": "lbs"},
          "5": {"weight": 275, "calculated_1rm": 321, "achieved_date": "2024-11-15", "weight_unit": "lbs"}
        },
        "DEADLIFT": {...},
        "BENCH_PRESS": {...},
        "PRESS": null
      }
    }
    ```

    If no records exist for a lift, its value will be null.
    """
    return RepMaxService.get_all_rep_maxes(db, current_user)


@router.get(
    "/{lift_type}",
    response_model=RepMaxByRepsResponse,
    status_code=status.HTTP_200_OK,
    summary="Get rep maxes for specific lift",
    description="Get personal records for a specific lift across all rep ranges (1-12)."
)
async def get_rep_maxes_by_lift(
    lift_type: str = Path(
        ...,
        description="Lift type",
        pattern="^(squat|deadlift|bench_press|press)$"
    ),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> RepMaxByRepsResponse:
    """
    Get personal records for a specific lift.

    Returns rep maxes organized by rep count (1-12) for the specified lift.
    For each rep count, only the best performance (highest calculated 1RM) is returned.

    Valid lift types:
    - squat
    - deadlift
    - bench_press
    - press

    Example response:
    ```json
    {
      "lift_type": "squat",
      "rep_maxes": {
        "1": {"weight": 315, "calculated_1rm": 315, "achieved_date": "2024-12-15", "weight_unit": "lbs"},
        "3": {"weight": 295, "calculated_1rm": 325, "achieved_date": "2024-11-20", "weight_unit": "lbs"},
        "5": {"weight": 275, "calculated_1rm": 321, "achieved_date": "2024-11-15", "weight_unit": "lbs"},
        "10": {"weight": 225, "calculated_1rm": 300, "achieved_date": "2024-10-15", "weight_unit": "lbs"}
      }
    }
    ```

    These records are automatically populated from AMRAP sets when you complete workouts.
    """
    return RepMaxService.get_rep_maxes_by_lift(db, current_user, lift_type)
