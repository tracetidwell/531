"""
Authentication service with business logic.
"""
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from typing import Optional
from app.models.user import User
from app.schemas.auth import UserRegisterRequest, UserLoginRequest, TokenResponse
from app.utils.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
    validate_password_strength
)


class AuthService:
    """Service for handling authentication operations."""

    @staticmethod
    def register_user(db: Session, user_data: UserRegisterRequest) -> TokenResponse:
        """
        Register a new user.

        Args:
            db: Database session
            user_data: User registration data

        Returns:
            TokenResponse with user info and tokens

        Raises:
            HTTPException: If email already exists or password is weak
        """
        # Check if email already exists
        existing_user = db.query(User).filter(User.email == user_data.email.lower()).first()
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )

        # Validate password strength
        is_valid, error_message = validate_password_strength(user_data.password)
        if not is_valid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=error_message
            )

        # Hash password
        hashed_password = get_password_hash(user_data.password)

        # Create new user
        new_user = User(
            first_name=user_data.first_name.strip(),
            last_name=user_data.last_name.strip(),
            email=user_data.email.lower(),
            password_hash=hashed_password
        )

        db.add(new_user)
        db.commit()
        db.refresh(new_user)

        # Generate tokens
        access_token = create_access_token(data={"sub": new_user.id})
        refresh_token = create_refresh_token(data={"sub": new_user.id})

        return TokenResponse(
            user_id=new_user.id,
            first_name=new_user.first_name,
            last_name=new_user.last_name,
            email=new_user.email,
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer"
        )

    @staticmethod
    def login_user(db: Session, login_data: UserLoginRequest) -> TokenResponse:
        """
        Authenticate a user and return tokens.

        Args:
            db: Database session
            login_data: User login credentials

        Returns:
            TokenResponse with user info and tokens

        Raises:
            HTTPException: If credentials are invalid
        """
        # Find user by email
        user = db.query(User).filter(User.email == login_data.email.lower()).first()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )

        # Verify password
        if not verify_password(login_data.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )

        # Generate tokens
        access_token = create_access_token(data={"sub": user.id})
        refresh_token = create_refresh_token(data={"sub": user.id})

        return TokenResponse(
            user_id=user.id,
            first_name=user.first_name,
            last_name=user.last_name,
            email=user.email,
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer"
        )

    @staticmethod
    def refresh_access_token(db: Session, refresh_token: str) -> dict:
        """
        Generate a new access token using a refresh token.

        Args:
            db: Database session
            refresh_token: The refresh token

        Returns:
            Dictionary with new access_token and token_type

        Raises:
            HTTPException: If refresh token is invalid or expired
        """
        # Decode refresh token
        payload = decode_token(refresh_token)

        if not payload:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired refresh token"
            )

        # Verify it's a refresh token
        if payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type"
            )

        # Get user ID from token
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token payload"
            )

        # Verify user still exists
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found"
            )

        # Generate new access token
        new_access_token = create_access_token(data={"sub": user.id})

        return {
            "access_token": new_access_token,
            "token_type": "bearer"
        }

    @staticmethod
    def get_current_user(db: Session, token: str) -> User:
        """
        Get the current authenticated user from access token.

        Args:
            db: Database session
            token: The access token

        Returns:
            The authenticated User object

        Raises:
            HTTPException: If token is invalid or user not found
        """
        # Decode token
        payload = decode_token(token)

        if not payload:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Verify it's an access token
        if payload.get("type") != "access":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Get user ID from token
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Get user from database
        user = db.query(User).filter(User.id == user_id).first()
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found",
                headers={"WWW-Authenticate": "Bearer"},
            )

        return user
