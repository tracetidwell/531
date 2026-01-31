"""
Warmup template model.
"""
import uuid
from sqlalchemy import Column, String, Boolean, ForeignKey, JSON, Enum as SQLEnum
from app.database import Base
from app.models.program import LiftType


class WarmupTemplate(Base):
    """Custom warmup template for a specific lift."""

    __tablename__ = "warmup_templates"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)

    name = Column(String(255), nullable=False)
    lift_type = Column(SQLEnum(LiftType, name='lifttype', create_type=False), nullable=False)
    is_default = Column(Boolean, default=False, nullable=False)

    # JSON array: [{"weight_type": "bar|fixed|percentage", "value": float|null, "reps": int}, ...]
    sets = Column(JSON, nullable=False)

    def __repr__(self):
        return f"<WarmupTemplate {self.name} for {self.lift_type}>"
