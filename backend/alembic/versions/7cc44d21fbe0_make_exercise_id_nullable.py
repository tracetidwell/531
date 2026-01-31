"""make_exercise_id_nullable

Revision ID: 7cc44d21fbe0
Revises: 202601130001
Create Date: 2026-01-30 20:42:54.261972

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7cc44d21fbe0'
down_revision: Union[str, None] = '202601130001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column('workout_sets', 'exercise_id',
                    existing_type=sa.String(36),
                    nullable=True)


def downgrade() -> None:
    op.alter_column('workout_sets', 'exercise_id',
                    existing_type=sa.String(36),
                    nullable=False)
