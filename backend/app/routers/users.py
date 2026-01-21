"""
User management API endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.user import UserResponse, UserUpdateRequest
from app.models.user import User
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.get(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Get current user",
    description="Get the profile of the currently authenticated user."
)
async def get_current_user_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> UserResponse:
    """
    Get the current user's profile information.

    Requires authentication via Bearer token.

    Returns:
    - User ID
    - First and last name
    - Email
    - Preferences (weight unit, rounding increment, missed workout handling)
    - Account creation timestamp
    """
    return UserResponse.model_validate(current_user)


@router.put(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Update current user",
    description="Update the profile of the currently authenticated user."
)
async def update_current_user_profile(
    update_data: UserUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> UserResponse:
    """
    Update the current user's profile information.

    Requires authentication via Bearer token.

    Updatable fields:
    - First name
    - Last name
    - Weight unit preference (lbs/kg)
    - Rounding increment
    - Missed workout preference (skip/reschedule/ask)

    Note: Email cannot be updated as it's used for login.
    """
    # Update only provided fields
    update_dict = update_data.model_dump(exclude_unset=True)

    for field, value in update_dict.items():
        setattr(current_user, field, value)

    db.commit()
    db.refresh(current_user)

    return UserResponse.model_validate(current_user)
