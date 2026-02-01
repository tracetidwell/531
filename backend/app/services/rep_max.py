"""
Rep max service with business logic.
"""
from sqlalchemy.orm import Session
from sqlalchemy import and_
from typing import Dict, Optional
from app.models.rep_max import RepMax
from app.models.program import LiftType
from app.models.user import User
from app.schemas.rep_max import RepMaxRecord, RepMaxByRepsResponse, AllRepMaxesResponse


class RepMaxService:
    """Service for handling rep max operations."""

    @staticmethod
    def get_rep_maxes_by_lift(
        db: Session,
        user: User,
        lift_type: str
    ) -> RepMaxByRepsResponse:
        """
        Get all rep maxes for a specific lift.

        Args:
            db: Database session
            user: Current user
            lift_type: Lift type (squat, deadlift, bench_press, press)

        Returns:
            RepMaxByRepsResponse with rep maxes keyed by rep count
        """
        lift_enum = LiftType(lift_type.upper())

        # Get all rep maxes for this lift
        rep_maxes = db.query(RepMax).filter(
            and_(
                RepMax.user_id == user.id,
                RepMax.lift_type == lift_enum
            )
        ).all()

        # Organize by rep count, keeping only the best (highest calculated 1RM) for each rep count
        best_by_reps: Dict[int, RepMax] = {}
        for rm in rep_maxes:
            if rm.reps not in best_by_reps or rm.calculated_1rm > best_by_reps[rm.reps].calculated_1rm:
                best_by_reps[rm.reps] = rm

        # Convert to response format
        rep_maxes_dict = {
            reps: RepMaxRecord(
                weight=rm.weight,
                calculated_1rm=rm.calculated_1rm,
                achieved_date=rm.achieved_date,
                weight_unit=rm.weight_unit.value
            )
            for reps, rm in best_by_reps.items()
        }

        return RepMaxByRepsResponse(
            lift_type=lift_type,
            rep_maxes=rep_maxes_dict
        )

    @staticmethod
    def get_all_rep_maxes(
        db: Session,
        user: User
    ) -> AllRepMaxesResponse:
        """
        Get all rep maxes for all lifts.

        Args:
            db: Database session
            user: Current user

        Returns:
            AllRepMaxesResponse with rep maxes for all 4 lifts
        """
        result = {}

        for lift in LiftType:
            # Get all rep maxes for this lift
            rep_maxes = db.query(RepMax).filter(
                and_(
                    RepMax.user_id == user.id,
                    RepMax.lift_type == lift
                )
            ).all()

            # Organize by rep count
            best_by_reps: Dict[int, RepMax] = {}
            for rm in rep_maxes:
                if rm.reps not in best_by_reps or rm.calculated_1rm > best_by_reps[rm.reps].calculated_1rm:
                    best_by_reps[rm.reps] = rm

            # Convert to response format
            if best_by_reps:
                rep_maxes_dict = {
                    reps: RepMaxRecord(
                        weight=rm.weight,
                        calculated_1rm=rm.calculated_1rm,
                        achieved_date=rm.achieved_date,
                        weight_unit=rm.weight_unit.value
                    )
                    for reps, rm in best_by_reps.items()
                }
                result[lift.value] = rep_maxes_dict
            else:
                result[lift.value] = None

        return AllRepMaxesResponse(lifts=result)
