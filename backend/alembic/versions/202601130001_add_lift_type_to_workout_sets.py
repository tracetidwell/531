"""add_lift_type_to_workout_sets

Revision ID: 202601130001
Revises: 202601100001
Create Date: 2026-01-13

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '202601130001'
down_revision = '0a4c558a44bb'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add lift_type column to workout_sets table
    op.add_column('workout_sets', sa.Column('lift_type', sa.String(length=50), nullable=True))


def downgrade() -> None:
    # Remove lift_type column from workout_sets table
    op.drop_column('workout_sets', 'lift_type')
