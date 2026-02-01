"""Drop accessories column from program_templates

Revision ID: 202602010002
Revises: 202602010001
Create Date: 2026-02-01

Phase 4 of accessories migration: Remove the deprecated accessories column
from program_templates table. Accessories are now stored in program_day_accessories.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '202602010002'
down_revision: Union[str, None] = '202602010001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Drop the accessories column from program_templates
    # Data has already been migrated to program_day_accessories table
    op.drop_column('program_templates', 'accessories')


def downgrade() -> None:
    # Re-add the accessories column (data will need to be restored manually)
    op.add_column(
        'program_templates',
        sa.Column('accessories', sa.JSON(), nullable=True)
    )
