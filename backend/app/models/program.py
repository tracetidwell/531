"""
Program and training max models.
"""
import uuid
import enum
from datetime import datetime, date
from sqlalchemy import Column, String, Integer, Float, Date, DateTime, ForeignKey, Text, JSON, Enum as SQLEnum, UniqueConstraint
from sqlalchemy.orm import relationship
from app.database import Base


class ProgramStatus(str, enum.Enum):
    """Program status."""
    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"
    PAUSED = "PAUSED"


class LiftType(str, enum.Enum):
    """Main lift types."""
    SQUAT = "SQUAT"
    DEADLIFT = "DEADLIFT"
    BENCH_PRESS = "BENCH_PRESS"
    PRESS = "PRESS"


class TrainingMaxReason(str, enum.Enum):
    """Reason for training max change."""
    INITIAL = "INITIAL"
    CYCLE_COMPLETION = "CYCLE_COMPLETION"
    DELOAD = "DELOAD"
    FAILED_REPS = "FAILED_REPS"
    MANUAL = "MANUAL"


class Program(Base):
    """Training program model."""

    __tablename__ = "programs"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)

    name = Column(String(255), nullable=False)
    template_type = Column(String(50), nullable=False)  # e.g., "4_day", "3_day", "2_day"

    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=True)
    target_cycles = Column(Integer, nullable=True)

    training_days = Column(JSON, nullable=False)  # ["monday", "tuesday", "thursday", "saturday"]
    include_deload = Column(Integer, default=1, nullable=False)  # 1 = include deload week, 0 = skip deload
    status = Column(SQLEnum(ProgramStatus, name='programstatus', create_type=False), default=ProgramStatus.ACTIVE, nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<Program {self.name}>"


class TrainingMax(Base):
    """Current training max for a lift."""

    __tablename__ = "training_maxes"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    program_id = Column(String(36), ForeignKey("programs.id"), nullable=False, index=True)

    lift_type = Column(SQLEnum(LiftType, name='lifttype', create_type=False), nullable=False)
    value = Column(Float, nullable=False)
    effective_date = Column(Date, nullable=False)
    cycle_number = Column(Integer, nullable=False)
    reason = Column(SQLEnum(TrainingMaxReason, name='trainingmaxreason', create_type=False), nullable=False)
    notes = Column(Text, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<TrainingMax {self.lift_type}: {self.value}>"


class TrainingMaxHistory(Base):
    """Historical record of training max changes."""

    __tablename__ = "training_max_history"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    program_id = Column(String(36), ForeignKey("programs.id"), nullable=False, index=True)

    lift_type = Column(SQLEnum(LiftType, name='lifttype', create_type=False), nullable=False)
    old_value = Column(Float, nullable=True)  # Null for first entry
    new_value = Column(Float, nullable=False)
    change_date = Column(DateTime, default=datetime.utcnow, nullable=False)
    reason = Column(SQLEnum(TrainingMaxReason, name='trainingmaxreason', create_type=False), nullable=False)
    notes = Column(Text, nullable=True)

    def __repr__(self):
        return f"<TrainingMaxHistory {self.lift_type}: {self.old_value} -> {self.new_value}>"


class ProgramTemplate(Base):
    """Program template storing main lift per day."""

    __tablename__ = "program_templates"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    program_id = Column(String(36), ForeignKey("programs.id"), nullable=False, index=True)

    day_number = Column(Integer, nullable=False)  # 1-4 for 4-day program
    main_lift = Column(SQLEnum(LiftType, name='lifttype', create_type=False), nullable=False)
    # PHASE 4: accessories column removed - use ProgramDayAccessories table instead

    def __repr__(self):
        return f"<ProgramTemplate Day {self.day_number}: {self.main_lift}>"


class ProgramDayAccessories(Base):
    """Accessories for a program day (single source of truth, not per-lift)."""

    __tablename__ = "program_day_accessories"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    program_id = Column(String(36), ForeignKey("programs.id"), nullable=False, index=True)
    day_number = Column(Integer, nullable=False)  # 1-4
    accessories = Column(JSON, nullable=False)  # [{"exercise_id": "uuid", "sets": 5, "reps": 12, "weight_type": "fixed"}, ...]

    __table_args__ = (
        UniqueConstraint('program_id', 'day_number', name='uq_program_day_accessories'),
    )

    def __repr__(self):
        return f"<ProgramDayAccessories Program {self.program_id} Day {self.day_number}>"
