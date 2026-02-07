"""
Analytics service for training data insights.
"""
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import desc
from typing import Dict, List, Optional
from collections import defaultdict
from fastapi import HTTPException, status

from app.models.program import Program, TrainingMaxHistory, LiftType
from app.models.workout import Workout, WorkoutSet, WorkoutMainLift, SetType, WorkoutStatus
from app.models.user import User
from app.schemas.analytics import (
    TrainingMaxProgressionResponse,
    TrainingMaxDataPoint,
    WorkoutHistoryResponse,
    WorkoutHistoryItem,
    WorkoutKeyStats
)
from app.utils.calculations import calculate_1rm


class AnalyticsService:
    """Service for analytics and insights."""

    @staticmethod
    def get_training_max_progression(
        db: Session,
        user: User,
        program_id: str
    ) -> TrainingMaxProgressionResponse:
        """
        Get training max progression for all lifts in a program.

        Args:
            db: Database session
            user: Current user
            program_id: Program ID

        Returns:
            TrainingMaxProgressionResponse with progression data for all lifts

        Raises:
            HTTPException: If program not found or doesn't belong to user
        """
        # Verify program ownership
        program = db.query(Program).filter(
            Program.id == program_id,
            Program.user_id == user.id
        ).first()

        if not program:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Program not found"
            )

        # Query all training max history for this program
        history = db.query(TrainingMaxHistory).filter(
            TrainingMaxHistory.program_id == program_id
        ).order_by(
            TrainingMaxHistory.lift_type,
            TrainingMaxHistory.change_date
        ).all()

        # Group by lift type
        progression_data: Dict[str, List[TrainingMaxDataPoint]] = defaultdict(list)

        for record in history:
            # Calculate cycle number from the date
            # We can derive this from the change_date and program start_date
            # For simplicity, we'll use a counter per lift
            data_point = TrainingMaxDataPoint(
                date=record.change_date.date().isoformat(),
                value=record.new_value,
                cycle=len(progression_data[record.lift_type.value]) + 1
            )
            progression_data[record.lift_type.value].append(data_point)

        return TrainingMaxProgressionResponse(data=dict(progression_data))

    @staticmethod
    def get_workout_history(
        db: Session,
        user: User,
        program_id: str,
        lift_type: Optional[LiftType] = None,
        limit: int = 20,
        offset: int = 0
    ) -> WorkoutHistoryResponse:
        """
        Get workout history with key statistics.

        Args:
            db: Database session
            user: Current user
            program_id: Program ID
            lift_type: Optional filter by lift type
            limit: Number of results to return (default 20)
            offset: Offset for pagination (default 0)

        Returns:
            WorkoutHistoryResponse with paginated workout history

        Raises:
            HTTPException: If program not found or doesn't belong to user
        """
        # Verify program ownership
        program = db.query(Program).filter(
            Program.id == program_id,
            Program.user_id == user.id
        ).first()

        if not program:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Program not found"
            )

        # Build query for completed workouts, eager load main_lifts
        query = db.query(Workout).filter(
            Workout.program_id == program_id,
            Workout.status == WorkoutStatus.COMPLETED
        ).options(joinedload(Workout.main_lifts))

        if lift_type:
            # Filter workouts that have this specific lift
            query = query.join(WorkoutMainLift).filter(
                WorkoutMainLift.lift_type == lift_type
            )

        # Get total count
        total = query.count()

        # Get paginated workouts
        workouts = query.order_by(
            desc(Workout.completed_date)
        ).limit(limit).offset(offset).all()

        # Build response items with key stats
        # Note: For multi-lift workouts, we create one history item per lift
        workout_items = []
        for workout in workouts:
            # For each main lift in the workout
            for main_lift in workout.main_lifts:
                # Get AMRAP set for this specific lift (last working set, set 3)
                amrap_set = db.query(WorkoutSet).filter(
                    WorkoutSet.workout_id == workout.id,
                    WorkoutSet.set_type == SetType.WORKING,
                    WorkoutSet.set_number == 3
                ).first()

                # Calculate key stats from AMRAP set
                key_stats = WorkoutKeyStats(
                    amrap_reps=None,
                    amrap_weight=None,
                    calculated_1rm=None
                )

                if amrap_set:
                    key_stats.amrap_reps = amrap_set.actual_reps
                    key_stats.amrap_weight = amrap_set.actual_weight
                    key_stats.calculated_1rm = calculate_1rm(
                        amrap_set.actual_weight,
                        amrap_set.actual_reps
                    )

                # Get the date and convert to ISO format string
                workout_date = workout.completed_date.date() if workout.completed_date else workout.scheduled_date

                workout_item = WorkoutHistoryItem(
                    id=workout.id,
                    date=workout_date.isoformat(),
                    lift=main_lift.lift_type,
                    cycle=workout.cycle_number,
                    week=workout.week_number,
                    week_type=workout.week_type,
                    key_stats=key_stats,
                    notes=workout.notes
                )
                workout_items.append(workout_item)

        return WorkoutHistoryResponse(
            workouts=workout_items,
            total=total,
            limit=limit,
            offset=offset
        )
