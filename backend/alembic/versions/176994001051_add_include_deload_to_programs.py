"""add_include_deload_to_programs

Revision ID: 176994001051
Revises: seed_exercises_001
Create Date: 2025-12-30 19:39:54.544293

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '176994001051'
down_revision: Union[str, None] = 'seed_exercises_001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add include_deload column to programs table
    # Default to 1 (True) for existing programs to maintain current behavior
    op.add_column('programs', sa.Column('include_deload', sa.Integer(), nullable=False, server_default='1'))


def downgrade() -> None:
    # Remove include_deload column
    op.drop_column('programs', 'include_deload')
