"""Add program_day_accessories table and migrate data

Revision ID: 202602010001
Revises: 7cc44d21fbe0
Create Date: 2026-02-01

This migration creates the program_day_accessories table to store accessories
per day rather than per main_lift. This eliminates duplication in 2-day programs
where multiple lifts share the same day.
"""
from typing import Sequence, Union
import uuid
import json

from alembic import op
import sqlalchemy as sa
from sqlalchemy import text


# revision identifiers, used by Alembic.
revision: str = '202602010001'
down_revision: Union[str, None] = '7cc44d21fbe0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create the new table
    op.create_table(
        'program_day_accessories',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('program_id', sa.String(36), sa.ForeignKey('programs.id'), nullable=False),
        sa.Column('day_number', sa.Integer(), nullable=False),
        sa.Column('accessories', sa.JSON(), nullable=False),
        sa.UniqueConstraint('program_id', 'day_number', name='uq_program_day_accessories')
    )
    op.create_index('ix_program_day_accessories_program_id', 'program_day_accessories', ['program_id'])

    # 2. Migrate existing data from program_templates
    # For each unique (program_id, day_number), take the accessories from the first template
    connection = op.get_bind()

    # Get all distinct program_id, day_number combinations with their accessories
    # We use MIN(id) to get a consistent "first" template for each day
    results = connection.execute(text('''
        SELECT pt.program_id, pt.day_number, pt.accessories
        FROM program_templates pt
        INNER JOIN (
            SELECT program_id, day_number, MIN(id) as first_id
            FROM program_templates
            GROUP BY program_id, day_number
        ) first_templates ON pt.id = first_templates.first_id
    ''')).fetchall()

    for program_id, day_number, accessories in results:
        # Only insert if there are actual accessories
        # Parse accessories if it's a string (SQLite stores JSON as text)
        if isinstance(accessories, str):
            parsed_accessories = json.loads(accessories) if accessories else []
        else:
            parsed_accessories = accessories or []

        if parsed_accessories:
            new_id = str(uuid.uuid4())
            # Serialize back to JSON string for the insert
            accessories_json = json.dumps(parsed_accessories)
            connection.execute(
                text('''
                    INSERT INTO program_day_accessories (id, program_id, day_number, accessories)
                    VALUES (:id, :program_id, :day_number, :accessories)
                '''),
                {
                    'id': new_id,
                    'program_id': program_id,
                    'day_number': day_number,
                    'accessories': accessories_json
                }
            )

    # Note: We're NOT dropping the accessories column from program_templates yet.
    # That will happen in Phase 4 after verifying the migration worked correctly.


def downgrade() -> None:
    # Note: Downgrade does NOT restore data to program_templates.accessories
    # since that column still exists and wasn't modified.
    op.drop_index('ix_program_day_accessories_program_id', table_name='program_day_accessories')
    op.drop_table('program_day_accessories')
