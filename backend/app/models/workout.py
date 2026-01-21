"""
Workout and workout set models.
"""
import uuid
import enum
from datetime import datetime, date
from sqlalchemy import Column, String, Integer, Float, Date, DateTime, ForeignKey, Text, Boolean, Enum as SQLEnum
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.program import LiftType


class WorkoutStatus(str, enum.Enum):
    """Workout status."""
    SCHEDULED = "scheduled"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    SKIPPED = "skipped"


class WeekType(str, enum.Enum):
    """5/3/1 week type."""
    WEEK_1_5S = "week_1_5s"
    WEEK_2_3S = "week_2_3s"
    WEEK_3_531 = "week_3_531"
    WEEK_4_DELOAD = "week_4_deload"


class SetType(str, enum.Enum):
    """Type of set."""
    WARMUP = "warmup"
    WORKING = "working"
    ACCESSORY = "accessory"
    AMRAP = "amrap"


class WeightUnit(str, enum.Enum):
    """Weight unit for a set."""
    LBS = "lbs"
    KG = "kg"


class WorkoutMainLift(Base):
    """Junction table for multiple main lifts per workout."""

    __tablename__ = "workout_main_lifts"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    workout_id = Column(String(36), ForeignKey("workouts.id"), nullable=False, index=True)
    lift_type = Column(SQLEnum(LiftType, native_enum=False, values_callable=lambda x: [e.value for e in x]), nullable=False)
    lift_order = Column(Integer, nullable=False, default=1)
    current_training_max = Column(Float, nullable=False)
    # Week type for this specific lift (used in 3-day programs where each lift progresses independently)
    # For 4-day/2-day programs, this will match the workout's week_type
    week_type = Column(SQLEnum(WeekType, native_enum=False, values_callable=lambda x: [e.value for e in x]), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<WorkoutMainLift {self.lift_type} order={self.lift_order}>"


class Workout(Base):
    """Workout session model."""

    __tablename__ = "workouts"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    program_id = Column(String(36), ForeignKey("programs.id"), nullable=False, index=True)

    scheduled_date = Column(Date, nullable=False, index=True)
    completed_date = Column(DateTime, nullable=True)

    cycle_number = Column(Integer, nullable=False)
    week_number = Column(Integer, nullable=False)  # 1-4
    week_type = Column(SQLEnum(WeekType, native_enum=False, values_callable=lambda x: [e.value for e in x]), nullable=False)

    status = Column(SQLEnum(WorkoutStatus, native_enum=False, values_callable=lambda x: [e.value for e in x]), default=WorkoutStatus.SCHEDULED, nullable=False)

    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationship to main lifts
    main_lifts = relationship("WorkoutMainLift", backref="workout", cascade="all, delete-orphan", order_by="WorkoutMainLift.lift_order")

    def __repr__(self):
        return f"<Workout Cycle {self.cycle_number} Week {self.week_number}>"


class WorkoutSet(Base):
    """Individual set within a workout."""

    __tablename__ = "workout_sets"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    workout_id = Column(String(36), ForeignKey("workouts.id"), nullable=False, index=True)
    exercise_id = Column(String(36), ForeignKey("exercises.id"), nullable=False)

    set_type = Column(SQLEnum(SetType, native_enum=False, values_callable=lambda x: [e.value for e in x]), nullable=False)
    set_number = Column(Integer, nullable=False)
    lift_type = Column(SQLEnum(LiftType, native_enum=False, values_callable=lambda x: [e.value for e in x]), nullable=True)  # Which main lift this set belongs to

    prescribed_reps = Column(Integer, nullable=True)
    actual_reps = Column(Integer, nullable=False)

    prescribed_weight = Column(Float, nullable=True)
    actual_weight = Column(Float, nullable=False)

    weight_unit = Column(SQLEnum(WeightUnit, native_enum=False, values_callable=lambda x: [e.value for e in x]), nullable=False)
    percentage_of_tm = Column(Float, nullable=True)  # For main lifts
    is_target_met = Column(Boolean, nullable=False)  # True if actual_reps >= prescribed_reps

    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<WorkoutSet {self.set_type} Set {self.set_number}>"
