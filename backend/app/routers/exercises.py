"""
Exercise API endpoints.
"""
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import get_db
from app.schemas.exercise import ExerciseResponse, ExerciseCreateRequest
from app.services.exercise import ExerciseService
from app.models.user import User
from app.models.exercise import ExerciseCategory
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.get(
    "",
    response_model=List[ExerciseResponse],
    status_code=status.HTTP_200_OK,
    summary="List exercises",
    description="Get all available exercises (predefined from book + user's custom exercises)."
)
async def list_exercises(
    category: Optional[ExerciseCategory] = Query(None, description="Filter by category"),
    is_predefined: Optional[bool] = Query(None, description="Filter by predefined status"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> List[ExerciseResponse]:
    """
    Get all available exercises.

    Returns:
    - Predefined exercises from the book (Chapter 16)
    - User's custom exercises

    Optional filters:
    - category: Filter by exercise category (push, pull, legs, core)
    - is_predefined: True for book exercises, False for custom only
    """
    return ExerciseService.get_exercises(db, current_user, category, is_predefined)


@router.post(
    "",
    response_model=ExerciseResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create custom exercise",
    description="Create a new custom exercise for the current user."
)
async def create_exercise(
    exercise_data: ExerciseCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> ExerciseResponse:
    """
    Create a custom exercise.

    Allows users to add exercises not in the book's predefined list.
    Custom exercises are only visible to the user who created them.
    """
    return ExerciseService.create_custom_exercise(db, current_user, exercise_data)
