"""
Exercise model.
"""
import uuid
import enum
from datetime import datetime
from sqlalchemy import Column, String, Boolean, ForeignKey, Text, DateTime, Enum as SQLEnum
from app.database import Base


class ExerciseCategory(str, enum.Enum):
    """Exercise category."""
    PUSH = "PUSH"
    PULL = "PULL"
    LEGS = "LEGS"
    CORE = "CORE"


class Exercise(Base):
    """Exercise model for both predefined and custom exercises."""

    __tablename__ = "exercises"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))

    name = Column(String(255), nullable=False)
    category = Column(SQLEnum(ExerciseCategory, name='exercisecategory', create_type=False), nullable=False)
    is_predefined = Column(Boolean, default=False, nullable=False)

    # Null for predefined exercises, set for custom user exercises
    user_id = Column(String(36), ForeignKey("users.id"), nullable=True, index=True)

    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<Exercise {self.name}>"
