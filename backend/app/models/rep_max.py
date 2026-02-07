"""
Rep max (personal records) model.
"""
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Integer, Float, Date, DateTime, ForeignKey, Enum as SQLEnum
from app.database import Base
from app.models.program import LiftType
from app.models.workout import WeightUnit


class RepMax(Base):
    """Personal record for a specific rep range."""

    __tablename__ = "rep_maxes"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)

    lift_type = Column(SQLEnum(LiftType, name='lifttype', create_type=False), nullable=False, index=True)
    reps = Column(Integer, nullable=False)  # 1-12
    weight = Column(Float, nullable=False)
    weight_unit = Column(SQLEnum(WeightUnit, name='weightunit', create_type=False), nullable=False)

    calculated_1rm = Column(Float, nullable=False)  # Using Epley formula
    achieved_date = Column(Date, nullable=False)

    # Reference to the AMRAP set that created this PR
    workout_set_id = Column(String(36), ForeignKey("workout_sets.id"), nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<RepMax {self.lift_type} {self.reps}RM: {self.weight} {self.weight_unit}>"
