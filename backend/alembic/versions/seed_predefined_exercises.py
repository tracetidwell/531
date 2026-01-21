"""Seed predefined exercises from book Chapter 16

Revision ID: seed_exercises_001
Revises: f8ace9e0f86e
Create Date: 2025-12-29 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from datetime import datetime
import uuid


# revision identifiers, used by Alembic.
revision = 'seed_exercises_001'
down_revision = 'f8ace9e0f86e'
branch_labels = None
depends_on = None


def upgrade():
    """
    Seed predefined assistance exercises from Jim Wendler's 5/3/1 book, Chapter 16.
    These exercises are available to all users.
    """

    # Define predefined exercises from the book
    exercises = [
        # PUSH exercises (upper body pressing)
        {
            'id': str(uuid.uuid4()),
            'name': 'Dips',
            'category': 'push',
            'description': 'Bodyweight or weighted dips for triceps, chest, and shoulders. Can be done with parallel bars or rings.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Pushups',
            'category': 'push',
            'description': 'Standard pushups or variations (ring pushups, blast strap pushups, weighted vest). Great upper body pressing exercise.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Dumbbell Bench Press',
            'category': 'push',
            'description': 'Dumbbell bench press for upper body pressing. Works each arm independently and great for regular barbell bench press.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Dumbbell Military Press',
            'category': 'push',
            'description': 'Standing or seated dumbbell shoulder press. Works shoulders and can be used as a core exercise.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Dumbbell Incline Press',
            'category': 'push',
            'description': 'Incline dumbbell press at any angle (30, 45, or 60 degrees). Use slight elbow tuck when pressing and lowering.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Barbell Incline Press',
            'category': 'push',
            'description': 'Barbell incline press for bench press and military press assistance. Any angle works.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },

        # PULL exercises (upper body pulling)
        {
            'id': str(uuid.uuid4()),
            'name': 'Chin-ups',
            'category': 'pull',
            'description': 'Chin-ups or pull-ups with various grips (wide, medium, close, overhand, underhand, neutral). One of the best upper back, lat, and biceps exercises.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Kroc Rows',
            'category': 'pull',
            'description': 'Dumbbell rows done with high reps (20-40) with the heaviest dumbbell you can handle. Builds upper back and lat strength.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Dumbbell Rows',
            'category': 'pull',
            'description': 'Standard dumbbell rows for upper back and lat development. Start with 1-2 warm-up sets of 10 reps, then go all-out on set of 20-40 reps.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Barbell Rows',
            'category': 'pull',
            'description': 'Barbell rows for upper back and lat strength. Great for bench press and deadlift. Ask yourself why you\'re doing them.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Barbell Shrugs',
            'category': 'pull',
            'description': 'Barbell shrugs for high reps with as heavy weight as possible. Builds traps. Do all-out set of 20-40 reps after warm-up sets.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },

        # LEGS exercises
        {
            'id': str(uuid.uuid4()),
            'name': 'Lunges',
            'category': 'legs',
            'description': 'Walking lunges, backwards lunges, or static lunges (side lunges are lame). Great for building leg strength and mass. Use dumbbells, barbells, weight vest, or bodyweight.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Step-ups',
            'category': 'legs',
            'description': 'Step-ups for legs. Use a box that puts your leg at about parallel to the ground. Single leg movements reveal coordination and strength problems.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Leg Press',
            'category': 'legs',
            'description': 'Leg press machine for leg strength and building. Use full range of motion and never use knee wraps.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Back Raise',
            'category': 'legs',
            'description': 'Back raises (back extensions) on glute-ham raise bench or 45-degree back raise. Push butt way back, arch back, and use full range of motion.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Good Morning',
            'category': 'legs',
            'description': 'Good mornings with good people with good mornings is training for exercise with the biggest opportunity for comedy. Not too shabby if you suck at those.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Glute-Ham Raise',
            'category': 'legs',
            'description': 'Glute-ham raises work the low back, glutes, and hamstrings. Start with back raise motion, then do full range reps adding weight if needed.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },

        # CORE exercises
        {
            'id': str(uuid.uuid4()),
            'name': 'Hanging Leg Raises',
            'category': 'core',
            'description': 'Hanging leg raises with straight legs, bringing feet to the bar. Return to complete stop. Do 2-3 sets of 10-15 reps with bodyweight.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Dumbbell Side Bends',
            'category': 'core',
            'description': 'Dumbbell side bends for abs, low back, and obliques. Use strict form with heavy weight. Do sets of 15-20.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
        {
            'id': str(uuid.uuid4()),
            'name': 'Ab Wheel',
            'category': 'core',
            'description': 'Abdominal wheel rollouts on knees or feet. Do sets of 25-50 reps on knees. Don\'t sag or A-frame.',
            'is_predefined': True,
            'user_id': None,
            'created_at': datetime.utcnow()
        },
    ]

    # Insert exercises into the database
    op.bulk_insert(
        sa.table('exercises',
            sa.column('id', sa.String),
            sa.column('name', sa.String),
            sa.column('category', sa.String),
            sa.column('description', sa.String),
            sa.column('is_predefined', sa.Boolean),
            sa.column('user_id', sa.String),
            sa.column('created_at', sa.DateTime),
        ),
        exercises
    )


def downgrade():
    """Remove predefined exercises."""
    op.execute("DELETE FROM exercises WHERE is_predefined = 1")
