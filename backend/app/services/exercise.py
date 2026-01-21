"""
Exercise service with business logic.
"""
from sqlalchemy.orm import Session
from typing import List, Optional
from app.models.exercise import Exercise, ExerciseCategory
from app.models.user import User
from app.schemas.exercise import ExerciseResponse, ExerciseCreateRequest


class ExerciseService:
    """Service for handling exercise operations."""

    @staticmethod
    def get_exercises(
        db: Session,
        user: User,
        category: Optional[ExerciseCategory] = None,
        is_predefined: Optional[bool] = None
    ) -> List[ExerciseResponse]:
        """
        Get exercises (predefined and user's custom).

        Args:
            db: Database session
            user: Current user
            category: Optional category filter
            is_predefined: Optional filter for predefined exercises

        Returns:
            List of ExerciseResponse
        """
        query = db.query(Exercise).filter(
            (Exercise.is_predefined == True) | (Exercise.user_id == user.id)
        )

        if category:
            query = query.filter(Exercise.category == category)

        if is_predefined is not None:
            query = query.filter(Exercise.is_predefined == is_predefined)

        exercises = query.order_by(
            Exercise.is_predefined.desc(),  # Predefined first
            Exercise.name
        ).all()

        return [ExerciseResponse.model_validate(ex) for ex in exercises]

    @staticmethod
    def create_custom_exercise(
        db: Session,
        user: User,
        exercise_data: ExerciseCreateRequest
    ) -> ExerciseResponse:
        """
        Create a custom exercise for the user.

        Args:
            db: Database session
            user: Current user
            exercise_data: Exercise creation data

        Returns:
            ExerciseResponse
        """
        exercise = Exercise(
            name=exercise_data.name,
            category=exercise_data.category,
            description=exercise_data.description,
            is_predefined=False,
            user_id=user.id
        )

        db.add(exercise)
        db.commit()
        db.refresh(exercise)

        return ExerciseResponse.model_validate(exercise)
