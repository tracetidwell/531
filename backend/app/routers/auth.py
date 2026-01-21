"""
Authentication API endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.auth import (
    UserRegisterRequest,
    UserLoginRequest,
    TokenResponse,
    RefreshTokenRequest,
    RefreshTokenResponse,
    MessageResponse
)
from app.services.auth import AuthService

router = APIRouter()


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user",
    description="Create a new user account with email and password. Returns authentication tokens."
)
async def register(
    user_data: UserRegisterRequest,
    db: Session = Depends(get_db)
) -> TokenResponse:
    """
    Register a new user account.

    Requirements:
    - Email must be unique
    - Password must be at least 8 characters with uppercase, lowercase, and number
    - First name and last name are required

    Returns authentication tokens upon successful registration.
    """
    return AuthService.register_user(db, user_data)


@router.post(
    "/login",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Login user",
    description="Authenticate a user with email and password. Returns authentication tokens."
)
async def login(
    login_data: UserLoginRequest,
    db: Session = Depends(get_db)
) -> TokenResponse:
    """
    Authenticate a user and return tokens.

    Provide email and password to receive:
    - Access token (expires in 15 minutes)
    - Refresh token (expires in 7 days)

    Use the access token for authenticated API requests.
    """
    return AuthService.login_user(db, login_data)


@router.post(
    "/refresh",
    response_model=RefreshTokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Refresh access token",
    description="Get a new access token using a valid refresh token."
)
async def refresh_token(
    token_data: RefreshTokenRequest,
    db: Session = Depends(get_db)
) -> RefreshTokenResponse:
    """
    Refresh an expired access token.

    Provide a valid refresh token to receive a new access token.
    The refresh token itself is not refreshed and will expire after 7 days.
    """
    result = AuthService.refresh_access_token(db, token_data.refresh_token)
    return RefreshTokenResponse(**result)


@router.post(
    "/request-password-reset",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Request password reset",
    description="Request a password reset email. (Not yet implemented)"
)
async def request_password_reset(
    db: Session = Depends(get_db)
) -> MessageResponse:
    """
    Request a password reset email.

    TODO: Implement email sending functionality with SMTP configuration.

    Will send an email with a reset token that expires in 1 hour.
    """
    # TODO: Implement password reset email functionality
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Password reset via email not yet implemented. Please contact support."
    )


@router.post(
    "/reset-password",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Reset password",
    description="Reset password using reset token. (Not yet implemented)"
)
async def reset_password(
    db: Session = Depends(get_db)
) -> MessageResponse:
    """
    Reset password using a reset token from email.

    TODO: Implement password reset confirmation functionality.

    Requires a valid reset token (received via email) and a new password.
    """
    # TODO: Implement password reset confirmation
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Password reset confirmation not yet implemented. Please contact support."
    )
