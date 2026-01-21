"""add_week_type_to_workout_main_lift

Revision ID: 0a4c558a44bb
Revises: 202601100001
Create Date: 2026-01-11 09:29:07.418900

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0a4c558a44bb'
down_revision: Union[str, None] = '202601100001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add week_type column to workout_main_lifts table
    # This allows each lift to have its own week type (needed for 3-day programs)
    # For existing records, this will be NULL - they can use the workout's week_type
    op.add_column('workout_main_lifts',
                  sa.Column('week_type',
                           sa.Enum('WEEK_1_5S', 'WEEK_2_3S', 'WEEK_3_531', 'WEEK_4_DELOAD', name='weektype'),
                           nullable=True))


def downgrade() -> None:
    # Remove week_type column from workout_main_lifts
    op.drop_column('workout_main_lifts', 'week_type')
