"""
Test script for 3-day program creation and workout generation.
"""
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app.database import get_db, engine, Base
from app.models.user import User
from app.models.program import Program, ProgramTemplate, LiftType
from app.models.workout import Workout
from app.models.exercise import Exercise
from app.services.program import ProgramService
from app.schemas.program import ProgramCreateRequest, TrainingMaxInput, AccessoryExerciseInput
from sqlalchemy.orm import Session
from datetime import date

# Create tables
Base.metadata.create_all(bind=engine)

def test_3_day_program():
    """Test 3-day program creation and workout generation."""
    db: Session = next(get_db())

    try:
        # Create test user
        import time
        timestamp = int(time.time())
        user = User(
            id=f"test-user-3day-{timestamp}",
            first_name="Test",
            last_name="User3Day",
            email=f"test3day-{timestamp}@example.com",
            password_hash="fake_hash"
        )
        db.add(user)
        db.commit()

        # Create some exercises for accessories
        categories = ["push", "pull", "legs", "core", "push", "pull"]
        exercises = []
        for i in range(6):
            exercise = Exercise(
                id=f"exercise-{timestamp}-{i+1}",
                name=f"Accessory Exercise {i+1}",
                category=categories[i],
                description=f"Test exercise {i+1}"
            )
            exercises.append(exercise)
            db.add(exercise)
        db.commit()

        print("✓ Test user and exercises created")

        # Test 1: 3-day program WITH deload
        print("\n=== Test 1: 3-day Program WITH Deload ===")

        program_data = ProgramCreateRequest(
            name="3-Day Program With Deload",
            template_type="3_day",
            start_date=date(2025, 1, 6),
            end_date=date(2025, 2, 2),  # 4 weeks
            target_cycles=1,
            training_days=["monday", "wednesday", "friday"],
            include_deload=True,
            training_maxes=TrainingMaxInput(
                squat=300.0,
                deadlift=350.0,
                bench_press=225.0,
                press=150.0
            ),
            accessories={
                "1": [
                    AccessoryExerciseInput(exercise_id=exercises[0].id, sets=5, reps=12),
                    AccessoryExerciseInput(exercise_id=exercises[1].id, sets=5, reps=12)
                ],
                "2": [
                    AccessoryExerciseInput(exercise_id=exercises[2].id, sets=5, reps=12)
                ],
                "3": [
                    AccessoryExerciseInput(exercise_id=exercises[3].id, sets=5, reps=12)
                ]
            }
        )

        program_response = ProgramService.create_program(db, user, program_data)

        # Fetch the actual program from the database to verify
        program = db.query(Program).filter(Program.id == program_response.id).first()

        print(f"✓ Created program: {program.name}")
        print(f"  - Template type: {program.template_type}")
        print(f"  - Training days: {program.training_days}")
        print(f"  - Include deload: {bool(program.include_deload)}")

        # Check program templates
        templates = db.query(ProgramTemplate).filter(
            ProgramTemplate.program_id == program.id
        ).order_by(ProgramTemplate.day_number).all()

        print(f"\n✓ Program Templates: {len(templates)} total")
        for template in templates:
            print(f"  - Day {template.day_number}: {template.main_lift.value}")

        # Verify template structure
        assert len(templates) == 4, f"Expected 4 templates, got {len(templates)}"

        # Day 1 should have 2 templates (Squat and Bench Press)
        day_1_templates = [t for t in templates if t.day_number == 1]
        assert len(day_1_templates) == 2, f"Day 1 should have 2 templates, got {len(day_1_templates)}"
        day_1_lifts = {t.main_lift for t in day_1_templates}
        assert day_1_lifts == {LiftType.SQUAT, LiftType.BENCH_PRESS}, f"Day 1 lifts incorrect: {day_1_lifts}"

        # Day 2 should have 1 template (Deadlift)
        day_2_templates = [t for t in templates if t.day_number == 2]
        assert len(day_2_templates) == 1, f"Day 2 should have 1 template, got {len(day_2_templates)}"
        assert day_2_templates[0].main_lift == LiftType.DEADLIFT, f"Day 2 should be Deadlift, got {day_2_templates[0].main_lift}"

        # Day 3 should have 1 template (Press)
        day_3_templates = [t for t in templates if t.day_number == 3]
        assert len(day_3_templates) == 1, f"Day 3 should have 1 template, got {len(day_3_templates)}"
        assert day_3_templates[0].main_lift == LiftType.PRESS, f"Day 3 should be Press, got {day_3_templates[0].main_lift}"

        print("\n✓ Template structure verified:")
        print("  - Day 1: Squat + Bench Press (2 lifts)")
        print("  - Day 2: Deadlift (1 lift)")
        print("  - Day 3: Press (1 lift)")

        # Check workouts
        workouts = db.query(Workout).filter(
            Workout.program_id == program.id
        ).order_by(Workout.scheduled_date).all()

        print(f"\n✓ Workouts: {len(workouts)} total")

        # Expected: 4 workouts per week × 4 weeks = 16 workouts
        assert len(workouts) == 16, f"Expected 16 workouts (4 per week × 4 weeks), got {len(workouts)}"

        # Verify workout distribution by week
        weeks = {1: 0, 2: 0, 3: 0, 4: 0}
        for workout in workouts:
            weeks[workout.week_number] += 1

        print(f"  - Week 1 (5s): {weeks[1]} workouts")
        print(f"  - Week 2 (3s): {weeks[2]} workouts")
        print(f"  - Week 3 (5/3/1): {weeks[3]} workouts")
        print(f"  - Week 4 (Deload): {weeks[4]} workouts")

        assert all(count == 4 for count in weeks.values()), f"Each week should have 4 workouts, got {weeks}"

        # Verify all lifts are covered each week
        for week_num in range(1, 5):
            week_workouts = [w for w in workouts if w.week_number == week_num]
            week_lifts = {w.main_lift for w in week_workouts}
            assert week_lifts == {LiftType.SQUAT, LiftType.DEADLIFT, LiftType.BENCH_PRESS, LiftType.PRESS}, \
                f"Week {week_num} missing lifts: expected all 4, got {week_lifts}"

        print("\n✓ All 4 lifts covered each week")

        # Test 2: 3-day program WITHOUT deload
        print("\n=== Test 2: 3-day Program WITHOUT Deload ===")

        program_data_no_deload = ProgramCreateRequest(
            name="3-Day Program No Deload",
            template_type="3_day",
            start_date=date(2025, 2, 3),
            end_date=date(2025, 2, 23),  # 3 weeks
            target_cycles=1,
            training_days=["tuesday", "thursday", "saturday"],
            include_deload=False,
            training_maxes=TrainingMaxInput(
                squat=300.0,
                deadlift=350.0,
                bench_press=225.0,
                press=150.0
            ),
            accessories={
                "1": [
                    AccessoryExerciseInput(exercise_id=exercises[0].id, sets=5, reps=12)
                ],
                "2": [
                    AccessoryExerciseInput(exercise_id=exercises[1].id, sets=5, reps=12)
                ],
                "3": [
                    AccessoryExerciseInput(exercise_id=exercises[2].id, sets=5, reps=12)
                ]
            }
        )

        program_response_no_deload = ProgramService.create_program(db, user, program_data_no_deload)

        # Fetch the actual program from the database to verify
        program_no_deload = db.query(Program).filter(Program.id == program_response_no_deload.id).first()

        print(f"✓ Created program: {program_no_deload.name}")
        print(f"  - Include deload: {bool(program_no_deload.include_deload)}")

        # Check workouts
        workouts_no_deload = db.query(Workout).filter(
            Workout.program_id == program_no_deload.id
        ).order_by(Workout.scheduled_date).all()

        print(f"\n✓ Workouts: {len(workouts_no_deload)} total")

        # Expected: 4 workouts per week × 3 weeks = 12 workouts
        assert len(workouts_no_deload) == 12, f"Expected 12 workouts (4 per week × 3 weeks), got {len(workouts_no_deload)}"

        # Verify no week 4 workouts
        week_numbers = {w.week_number for w in workouts_no_deload}
        assert week_numbers == {1, 2, 3}, f"Should only have weeks 1-3, got {week_numbers}"

        # Verify workout distribution
        weeks_no_deload = {1: 0, 2: 0, 3: 0}
        for workout in workouts_no_deload:
            weeks_no_deload[workout.week_number] += 1

        print(f"  - Week 1 (5s): {weeks_no_deload[1]} workouts")
        print(f"  - Week 2 (3s): {weeks_no_deload[2]} workouts")
        print(f"  - Week 3 (5/3/1): {weeks_no_deload[3]} workouts")

        assert all(count == 4 for count in weeks_no_deload.values()), \
            f"Each week should have 4 workouts, got {weeks_no_deload}"

        print("\n✓ Deload week correctly excluded")

        print("\n" + "="*50)
        print("ALL TESTS PASSED ✓")
        print("="*50)
        print("\nSummary:")
        print("- 3-day template creates 4 program templates (2+1+1)")
        print("- Day 1 has Squat + Bench Press")
        print("- Day 2 has Deadlift")
        print("- Day 3 has Press")
        print("- WITH deload: 16 workouts (4 weeks × 4 workouts)")
        print("- WITHOUT deload: 12 workouts (3 weeks × 4 workouts)")

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    test_3_day_program()
