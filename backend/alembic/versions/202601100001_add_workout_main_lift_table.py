"""add_workout_main_lift_table

Revision ID: 202601100001
Revises: 176994001051
Create Date: 2026-01-10 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '202601100001'
down_revision: Union[str, None] = '176994001051'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """
    Create workout_main_lifts junction table and remove main_lift from workouts.
    This supports multiple main lifts per workout (e.g., 2-day programs).
    """
    # Create workout_main_lifts table
    op.create_table(
        'workout_main_lifts',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('workout_id', sa.String(length=36), nullable=False),
        sa.Column('lift_type', sa.String(length=50), nullable=False),
        sa.Column('lift_order', sa.Integer(), nullable=False),
        sa.Column('current_training_max', sa.Float(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['workout_id'], ['workouts.id'], ),
        sa.PrimaryKeyConstraint('id')
    )

    # Create indexes for performance
    op.create_index('ix_workout_main_lifts_workout_id', 'workout_main_lifts', ['workout_id'])
    op.create_index('ix_workout_main_lifts_workout_id_lift_type', 'workout_main_lifts', ['workout_id', 'lift_type'])

    # Drop main_lift column from workouts table
    # SQLite requires batch operations for ALTER TABLE DROP COLUMN
    with op.batch_alter_table('workouts', schema=None) as batch_op:
        batch_op.drop_column('main_lift')


def downgrade() -> None:
    """
    Restore main_lift column to workouts and remove workout_main_lifts table.
    """
    # Add main_lift column back to workouts (nullable since no data to populate)
    with op.batch_alter_table('workouts', schema=None) as batch_op:
        batch_op.add_column(sa.Column('main_lift', sa.String(length=50), nullable=True))

    # Drop indexes
    op.drop_index('ix_workout_main_lifts_workout_id_lift_type', table_name='workout_main_lifts')
    op.drop_index('ix_workout_main_lifts_workout_id', table_name='workout_main_lifts')

    # Drop workout_main_lifts table
    op.drop_table('workout_main_lifts')
