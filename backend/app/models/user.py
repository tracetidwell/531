"""
User model.
"""
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Float, DateTime, Enum as SQLEnum
from app.database import Base
import enum


class WeightUnit(str, enum.Enum):
    """Weight unit preference."""
    LBS = "LBS"
    KG = "KG"


class MissedWorkoutPreference(str, enum.Enum):
    """How to handle missed workouts."""
    SKIP = "SKIP"
    RESCHEDULE = "RESCHEDULE"
    ASK = "ASK"


class User(Base):
    """User account model."""

    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)

    # Preferences
    weight_unit_preference = Column(
        SQLEnum(WeightUnit, name='weightunit', create_type=False),
        default=WeightUnit.LBS,
        nullable=False
    )
    rounding_increment = Column(Float, default=5.0, nullable=False)
    missed_workout_preference = Column(
        SQLEnum(MissedWorkoutPreference, name='missedworkoutpreference', create_type=False),
        default=MissedWorkoutPreference.ASK,
        nullable=False
    )

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<User {self.email}>"
