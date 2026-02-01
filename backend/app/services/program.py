"""
Program service with business logic.
"""
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from typing import List, Dict
from datetime import date, timedelta, datetime
from app.models.program import (
    Program, ProgramTemplate, TrainingMax, TrainingMaxHistory,
    LiftType, ProgramStatus, TrainingMaxReason
)
from app.models.workout import Workout, WorkoutMainLift, WeekType, WorkoutStatus
from app.models.user import User
from app.schemas.program import (
    ProgramCreateRequest, ProgramResponse, ProgramDetailResponse,
    ProgramUpdateRequest, TrainingMaxResponse, AccessoriesUpdateRequest
)


class ProgramService:
    """Service for handling program operations."""

    # Standard lift order for 4-day program
    FOUR_DAY_LIFT_ORDER = [LiftType.PRESS, LiftType.DEADLIFT, LiftType.BENCH_PRESS, LiftType.SQUAT]

    # 2-day program: Each day has TWO main lifts
    # Day 1: Squat + Bench Press (lower + upper push)
    # Day 2: Deadlift + Press (lower + upper push)
    TWO_DAY_LIFT_ORDER = [
        [LiftType.SQUAT, LiftType.BENCH_PRESS],  # Day 1
        [LiftType.DEADLIFT, LiftType.PRESS]      # Day 2
    ]

    # 3-day program: Combination of single and double lift days
    # Day 1: Squat + Bench Press (lower + upper push)
    # Day 2: Deadlift (lower - solo day)
    # Day 3: Press (upper push - solo day)
    # 3-day program uses a rolling progression over 5 weeks
    # Each lift progresses through: 5s -> 3s -> 5/3/1 -> Deload across different weeks
    THREE_DAY_LIFT_SCHEDULE = {
        # Format: (week_number, lift_type, week_type)
        1: [(LiftType.PRESS, WeekType.WEEK_1_5S), (LiftType.DEADLIFT, WeekType.WEEK_1_5S), (LiftType.BENCH_PRESS, WeekType.WEEK_1_5S)],
        2: [(LiftType.SQUAT, WeekType.WEEK_1_5S), (LiftType.PRESS, WeekType.WEEK_2_3S), (LiftType.DEADLIFT, WeekType.WEEK_2_3S)],
        3: [(LiftType.BENCH_PRESS, WeekType.WEEK_2_3S), (LiftType.SQUAT, WeekType.WEEK_2_3S), (LiftType.PRESS, WeekType.WEEK_3_531)],
        4: [(LiftType.DEADLIFT, WeekType.WEEK_3_531), (LiftType.BENCH_PRESS, WeekType.WEEK_3_531), (LiftType.SQUAT, WeekType.WEEK_3_531)],
        5: [(LiftType.PRESS, WeekType.WEEK_4_DELOAD), (LiftType.DEADLIFT, WeekType.WEEK_4_DELOAD), (LiftType.BENCH_PRESS, WeekType.WEEK_4_DELOAD), (LiftType.SQUAT, WeekType.WEEK_4_DELOAD)]
    }

    THREE_DAY_LIFT_ORDER = [
        [LiftType.SQUAT, LiftType.BENCH_PRESS],  # Day 1
        [LiftType.DEADLIFT],                      # Day 2
        [LiftType.PRESS]                          # Day 3
    ]

    @staticmethod
    def get_weeks_per_cycle(template_type: str, include_deload: bool) -> int:
        """
        Get the number of weeks per cycle based on template type.

        Args:
            template_type: Program template type ("4_day", "3_day", "2_day")
            include_deload: Whether deload week is included

        Returns:
            Number of weeks per cycle
        """
        if template_type == "3_day":
            # 3-day programs use 5-week cycles
            return 5
        else:
            # 4-day and 2-day programs use 3 or 4 week cycles
            return 3 if not include_deload else 4

    @staticmethod
    def create_program(db: Session, user: User, program_data: ProgramCreateRequest) -> ProgramDetailResponse:
        """
        Create a new training program with training maxes and workouts.

        Args:
            db: Database session
            user: Current user
            program_data: Program creation data

        Returns:
            ProgramDetailResponse with created program

        Raises:
            HTTPException: If user already has an active program
        """
        # Check for date conflicts with existing programs
        existing_programs = db.query(Program).filter(
            Program.user_id == user.id
        ).all()

        new_start = program_data.start_date
        new_end = program_data.end_date

        # If no end date, calculate it from target_cycles
        # Cycle length varies by template: 3-day uses 5 weeks, others use 3-4 weeks
        if not new_end and program_data.target_cycles:
            weeks_per_cycle = ProgramService.get_weeks_per_cycle(
                program_data.template_type,
                program_data.include_deload
            )
            new_end = new_start + timedelta(weeks=weeks_per_cycle * program_data.target_cycles)

        for existing in existing_programs:
            existing_start = existing.start_date
            existing_end = existing.end_date

            # If existing program has no end date, calculate from target_cycles
            if not existing_end and existing.target_cycles:
                existing_weeks_per_cycle = ProgramService.get_weeks_per_cycle(
                    existing.template_type,
                    bool(existing.include_deload)
                )
                existing_end = existing_start + timedelta(weeks=existing_weeks_per_cycle * existing.target_cycles)

            # Check for overlap
            # Two date ranges overlap if: start1 <= end2 AND start2 <= end1
            # But we need to handle cases where one or both ranges have no end date

            has_overlap = False

            if new_end and existing_end:
                # Both have end dates - standard overlap check
                has_overlap = new_start <= existing_end and existing_start <= new_end
            elif new_end and not existing_end:
                # New has end, existing is open-ended
                # Overlap if new starts before or during existing
                has_overlap = new_start >= existing_start or new_end >= existing_start
            elif not new_end and existing_end:
                # New is open-ended, existing has end
                # Overlap if new starts before existing ends
                has_overlap = new_start <= existing_end
            else:
                # Both are open-ended - always overlap if new starts on or after existing
                has_overlap = new_start >= existing_start

            if has_overlap:
                existing_date_range = f"{existing_start.strftime('%Y-%m-%d')} to "
                if existing_end:
                    existing_date_range += existing_end.strftime('%Y-%m-%d')
                else:
                    existing_date_range += "ongoing"

                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Program dates conflict with existing program '{existing.name}' ({existing_date_range}). Please choose different dates."
                )

        # Create program
        program = Program(
            user_id=user.id,
            name=program_data.name,
            template_type=program_data.template_type,
            start_date=program_data.start_date,
            end_date=program_data.end_date,
            target_cycles=program_data.target_cycles,
            training_days=program_data.training_days,
            include_deload=1 if program_data.include_deload else 0,
            status=ProgramStatus.ACTIVE
        )

        db.add(program)
        db.flush()  # Get program ID

        # Create training maxes for each lift
        training_maxes_dict = {}
        for lift in LiftType:
            tm_value = getattr(program_data.training_maxes, lift.value.lower())

            training_max = TrainingMax(
                program_id=program.id,
                lift_type=lift,
                value=tm_value,
                effective_date=program_data.start_date,
                cycle_number=1,
                reason=TrainingMaxReason.INITIAL
            )

            db.add(training_max)
            training_maxes_dict[lift.value] = TrainingMaxResponse(
                value=tm_value,
                effective_date=program_data.start_date,
                cycle=1
            )

        # Create program templates (accessories per workout type)
        # Workout types represent main lift combinations, not calendar days
        if program_data.template_type == '2_day':
            # 2-day program: 2 workout types, each with TWO main lifts
            # Workout type 1: Squat + Bench Press
            # Workout type 2: Deadlift + Press
            for workout_num in range(1, 3):  # Workout types 1 and 2
                workout_key = str(workout_num)
                lifts = ProgramService.TWO_DAY_LIFT_ORDER[workout_num - 1]

                # Get accessories for this workout type
                accessories_data = program_data.accessories.get(workout_key, [])
                accessories_json = [
                    {
                        "exercise_id": acc.exercise_id,
                        "sets": acc.sets,
                        "reps": acc.reps,
                        "weight_type": "fixed",
                        "circuit_group": acc.circuit_group
                    }
                    for acc in accessories_data
                ]

                # Create a template for each main lift in this workout type
                for lift in lifts:
                    template = ProgramTemplate(
                        program_id=program.id,
                        day_number=workout_num,  # Still use for database compatibility
                        main_lift=lift,
                        accessories=accessories_json  # Same accessories for both lifts
                    )
                    db.add(template)
        elif program_data.template_type == '3_day':
            # 3-day program: 4 workout types (one per lift)
            # Workout types now represent individual lifts since they rotate across days
            # Workout type 1: Press
            # Workout type 2: Deadlift
            # Workout type 3: Bench Press
            # Workout type 4: Squat
            lift_map = {
                '1': LiftType.PRESS,
                '2': LiftType.DEADLIFT,
                '3': LiftType.BENCH_PRESS,
                '4': LiftType.SQUAT
            }

            for workout_key, lift in lift_map.items():
                # Get accessories for this specific lift
                accessories_data = program_data.accessories.get(workout_key, [])
                accessories_json = [
                    {
                        "exercise_id": acc.exercise_id,
                        "sets": acc.sets,
                        "reps": acc.reps,
                        "weight_type": "fixed",
                        "circuit_group": acc.circuit_group
                    }
                    for acc in accessories_data
                ]

                template = ProgramTemplate(
                    program_id=program.id,
                    day_number=int(workout_key),  # Store workout type as day_number
                    main_lift=lift,
                    accessories=accessories_json
                )
                db.add(template)
        else:
            # 4-day program: 4 workout types (one per lift)
            # Workout type 1: Press
            # Workout type 2: Deadlift
            # Workout type 3: Bench Press
            # Workout type 4: Squat
            for workout_num in range(1, 5):
                workout_key = str(workout_num)
                lift = ProgramService.FOUR_DAY_LIFT_ORDER[workout_num - 1]

                # Get accessories for this workout type
                accessories_data = program_data.accessories.get(workout_key, [])
                accessories_json = [
                    {
                        "exercise_id": acc.exercise_id,
                        "sets": acc.sets,
                        "reps": acc.reps,
                        "weight_type": "fixed",
                        "circuit_group": acc.circuit_group
                    }
                    for acc in accessories_data
                ]

                template = ProgramTemplate(
                    program_id=program.id,
                    day_number=workout_num,  # Store workout type as day_number
                    main_lift=lift,
                    accessories=accessories_json
                )

                db.add(template)

        # Generate first cycle's workouts (4 weeks)
        workouts_created = ProgramService._generate_workouts(
            db, program, program_data.start_date, cycle_number=1
        )

        db.commit()
        db.refresh(program)

        return ProgramDetailResponse(
            id=program.id,
            name=program.name,
            template_type=program.template_type,
            start_date=program.start_date,
            end_date=program.end_date,
            status=program.status,
            training_days=program.training_days,
            current_cycle=1,
            current_week=1,
            training_maxes=training_maxes_dict,
            workouts_generated=workouts_created,
            created_at=program.created_at
        )

    @staticmethod
    def _generate_workouts(
        db: Session,
        program: Program,
        start_date: date,
        cycle_number: int
    ) -> int:
        """
        Generate workouts for a cycle.

        - 3-day programs: 5 weeks with rolling progression (each lift has its own week_type)
        - 2-day/4-day programs: 3-4 weeks (all lifts share the same week_type per week)

        Args:
            db: Database session
            program: Program instance
            start_date: Start date for this cycle
            cycle_number: Cycle number

        Returns:
            Number of workouts created
        """
        # Handle 3-day programs differently (rolling 5-week progression)
        if program.template_type == '3_day':
            return ProgramService._generate_3_day_workouts(db, program, start_date, cycle_number)

        # Standard 2-day/4-day progression
        week_types = [
            WeekType.WEEK_1_5S,
            WeekType.WEEK_2_3S,
            WeekType.WEEK_3_531,
            WeekType.WEEK_4_DELOAD
        ]

        # Skip deload week if program doesn't include it
        if not program.include_deload:
            week_types = week_types[:3]  # Only weeks 1-3

        current_date = start_date
        workouts_created = 0

        for week_num, week_type in enumerate(week_types, start=1):
            # Create workouts for each training day this week
            for day_offset in range(7):
                check_date = current_date + timedelta(days=day_offset)
                day_name = check_date.strftime('%A').lower()

                if day_name in program.training_days:
                    # Find which day number this is (0-indexed in training_days list)
                    day_index = program.training_days.index(day_name)

                    # Determine which lifts should be performed on this day
                    if program.template_type == '2_day':
                        lifts = ProgramService.TWO_DAY_LIFT_ORDER[day_index]
                    elif program.template_type == '3_day':
                        lifts = ProgramService.THREE_DAY_LIFT_ORDER[day_index]
                    else:
                        # 4-day program: One lift per training day
                        lifts = [ProgramService.FOUR_DAY_LIFT_ORDER[day_index]]

                    # Create ONE workout for this training day
                    workout = Workout(
                        program_id=program.id,
                        scheduled_date=check_date,
                        cycle_number=cycle_number,
                        week_number=week_num,
                        week_type=week_type,
                        status=WorkoutStatus.SCHEDULED
                    )
                    db.add(workout)
                    db.flush()  # Get workout.id for foreign key

                    # Create WorkoutMainLift records for each lift on this day
                    for order, lift in enumerate(lifts, start=1):
                        # Get current training max for this lift and cycle
                        training_max_record = db.query(TrainingMax).filter(
                            TrainingMax.program_id == program.id,
                            TrainingMax.lift_type == lift,
                            TrainingMax.cycle_number == cycle_number
                        ).first()

                        if not training_max_record:
                            raise HTTPException(
                                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                                detail=f"Training max not found for {lift.value} in cycle {cycle_number}"
                            )

                        workout_main_lift = WorkoutMainLift(
                            workout_id=workout.id,
                            lift_type=lift,
                            lift_order=order,
                            current_training_max=training_max_record.value,
                            week_type=week_type  # For 2-day/4-day, all lifts share same week_type
                        )
                        db.add(workout_main_lift)

                    workouts_created += 1

            # Move to next week
            current_date += timedelta(days=7)

        return workouts_created

    @staticmethod
    def _generate_3_day_workouts(
        db: Session,
        program: Program,
        start_date: date,
        cycle_number: int
    ) -> int:
        """
        Generate workouts for 3-day program with rolling progression (5 weeks).
        Each lift progresses independently through 5s -> 3s -> 5/3/1 -> Deload.

        Args:
            db: Database session
            program: Program instance
            start_date: Start date for this cycle
            cycle_number: Cycle number

        Returns:
            Number of workouts created
        """
        current_date = start_date
        workouts_created = 0

        # Iterate through 5 weeks
        for week_num in range(1, 6):
            # Get the lifts scheduled for this week from the predefined schedule
            week_lifts = ProgramService.THREE_DAY_LIFT_SCHEDULE[week_num]

            # Build a mapping of lift_type -> week_type for this week
            lift_week_types = {lift_type: week_type for lift_type, week_type in week_lifts}

            # Create workouts for each training day this week
            for day_offset in range(7):
                check_date = current_date + timedelta(days=day_offset)
                day_name = check_date.strftime('%A').lower()

                if day_name in program.training_days:
                    # Find which day number this is within the week (0, 1, 2 for Mon/Wed/Fri)
                    day_index = program.training_days.index(day_name)

                    # Get the lift for this training day from the week's schedule
                    # The schedule lists lifts in order (Mon=0, Wed=1, Fri=2)
                    if day_index >= len(week_lifts):
                        # Week 5 has 4 lifts but only 3 training days - skip if beyond list
                        if week_num != 5:
                            continue
                        # For week 5 deload, we might have 4 lifts for 3 days
                        # In this case, combine first two lifts on day 0
                        if day_index == 0 and len(week_lifts) == 4:
                            lifts_this_day = [week_lifts[0][0], week_lifts[1][0]]  # Press + Deadlift
                            lift_week_type_map = {
                                week_lifts[0][0]: week_lifts[0][1],
                                week_lifts[1][0]: week_lifts[1][1]
                            }
                            workout_week_type = week_lifts[0][1]  # Use first lift's week_type
                        elif day_index == 1 and len(week_lifts) == 4:
                            lifts_this_day = [week_lifts[2][0]]  # Bench
                            lift_week_type_map = {week_lifts[2][0]: week_lifts[2][1]}
                            workout_week_type = week_lifts[2][1]
                        elif day_index == 2 and len(week_lifts) == 4:
                            lifts_this_day = [week_lifts[3][0]]  # Squat
                            lift_week_type_map = {week_lifts[3][0]: week_lifts[3][1]}
                            workout_week_type = week_lifts[3][1]
                        else:
                            continue
                    else:
                        # Normal case: one lift per day
                        lift_type, week_type = week_lifts[day_index]
                        lifts_this_day = [lift_type]
                        lift_week_type_map = {lift_type: week_type}
                        workout_week_type = week_type

                    # Create workout
                    workout = Workout(
                        program_id=program.id,
                        scheduled_date=check_date,
                        cycle_number=cycle_number,
                        week_number=week_num,
                        week_type=workout_week_type,  # Representative week type
                        status=WorkoutStatus.SCHEDULED
                    )
                    db.add(workout)
                    db.flush()

                    # Create WorkoutMainLift records for each lift
                    for order, lift in enumerate(lifts_this_day, start=1):
                        # Get current training max
                        training_max_record = db.query(TrainingMax).filter(
                            TrainingMax.program_id == program.id,
                            TrainingMax.lift_type == lift,
                            TrainingMax.cycle_number == cycle_number
                        ).first()

                        if not training_max_record:
                            raise HTTPException(
                                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                                detail=f"Training max not found for {lift.value} in cycle {cycle_number}"
                            )

                        workout_main_lift = WorkoutMainLift(
                            workout_id=workout.id,
                            lift_type=lift,
                            lift_order=order,
                            current_training_max=training_max_record.value,
                            week_type=lift_week_type_map[lift]  # Each lift gets its own week_type
                        )
                        db.add(workout_main_lift)

                    workouts_created += 1

            # Move to next week
            current_date += timedelta(days=7)

        return workouts_created

    @staticmethod
    def get_user_programs(db: Session, user: User) -> List[ProgramResponse]:
        """
        Get all programs for a user.

        Args:
            db: Database session
            user: Current user

        Returns:
            List of ProgramResponse
        """
        programs = db.query(Program).filter(
            Program.user_id == user.id
        ).order_by(Program.created_at.desc()).all()

        return [ProgramResponse.model_validate(p) for p in programs]

    @staticmethod
    def get_program_detail(db: Session, user: User, program_id: str) -> ProgramDetailResponse:
        """
        Get detailed program information.

        Args:
            db: Database session
            user: Current user
            program_id: Program ID

        Returns:
            ProgramDetailResponse

        Raises:
            HTTPException: If program not found or not owned by user
        """
        program = db.query(Program).filter(
            Program.id == program_id,
            Program.user_id == user.id
        ).first()

        if not program:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Program not found"
            )

        # Get current training maxes
        training_maxes_dict = {}
        for lift in LiftType:
            tm = db.query(TrainingMax).filter(
                TrainingMax.program_id == program.id,
                TrainingMax.lift_type == lift
            ).order_by(TrainingMax.cycle_number.desc()).first()

            if tm:
                training_maxes_dict[lift.value] = TrainingMaxResponse(
                    value=tm.value,
                    effective_date=tm.effective_date,
                    cycle=tm.cycle_number
                )

        # Count workouts
        workout_count = db.query(Workout).filter(
            Workout.program_id == program.id
        ).count()

        # Get current cycle/week (simplified - just use latest workout)
        latest_workout = db.query(Workout).filter(
            Workout.program_id == program.id
        ).order_by(Workout.cycle_number.desc(), Workout.week_number.desc()).first()

        current_cycle = latest_workout.cycle_number if latest_workout else 1
        current_week = latest_workout.week_number if latest_workout else 1

        return ProgramDetailResponse(
            id=program.id,
            name=program.name,
            template_type=program.template_type,
            start_date=program.start_date,
            end_date=program.end_date,
            target_cycles=program.target_cycles,
            status=program.status,
            training_days=program.training_days,
            current_cycle=current_cycle,
            current_week=current_week,
            training_maxes=training_maxes_dict,
            workouts_generated=workout_count,
            created_at=program.created_at
        )

    @staticmethod
    def get_program_templates(
        db: Session,
        user: User,
        program_id: str
    ) -> List[dict]:
        """
        Get all templates (training days with accessories) for a program.

        Args:
            db: Database session
            user: Current user
            program_id: Program ID

        Returns:
            List of template dictionaries with day_number, main_lift, and accessories

        Raises:
            HTTPException: If program not found
        """
        # Verify program ownership
        program = db.query(Program).filter(
            Program.id == program_id,
            Program.user_id == user.id
        ).first()

        if not program:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Program not found"
            )

        # Get all templates for this program
        templates = db.query(ProgramTemplate).filter(
            ProgramTemplate.program_id == program_id
        ).order_by(ProgramTemplate.day_number).all()

        return [
            {
                "day_number": t.day_number,
                "main_lift": t.main_lift.value,
                "accessories": t.accessories or []
            }
            for t in templates
        ]

    @staticmethod
    def update_program(
        db: Session,
        user: User,
        program_id: str,
        update_data: ProgramUpdateRequest
    ) -> ProgramResponse:
        """
        Update a program.

        Args:
            db: Database session
            user: Current user
            program_id: Program ID
            update_data: Update data

        Returns:
            Updated ProgramResponse

        Raises:
            HTTPException: If program not found
        """
        program = db.query(Program).filter(
            Program.id == program_id,
            Program.user_id == user.id
        ).first()

        if not program:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Program not found"
            )

        # Update only provided fields
        update_dict = update_data.model_dump(exclude_unset=True)
        for field, value in update_dict.items():
            setattr(program, field, value)

        db.commit()
        db.refresh(program)

        return ProgramResponse.model_validate(program)

    @staticmethod
    def update_accessories(
        db: Session,
        user: User,
        program_id: str,
        day_number: int,
        update_data: AccessoriesUpdateRequest
    ) -> dict:
        """
        Update accessory exercises for a specific training day.

        Args:
            db: Database session
            user: Current user
            program_id: Program ID
            day_number: Training day number (1-4)
            update_data: New accessories configuration

        Returns:
            Success message with updated accessories

        Raises:
            HTTPException: If program or template not found
        """
        # Verify program ownership
        program = db.query(Program).filter(
            Program.id == program_id,
            Program.user_id == user.id
        ).first()

        if not program:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Program not found"
            )

        # Find ALL templates for this day (2-day programs have multiple lifts per day)
        templates = db.query(ProgramTemplate).filter(
            ProgramTemplate.program_id == program_id,
            ProgramTemplate.day_number == day_number
        ).all()

        if not templates:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No template found for day {day_number}"
            )

        # Convert accessories to JSON format
        accessories_json = [
            {
                "exercise_id": acc.exercise_id,
                "sets": acc.sets,
                "reps": acc.reps,
                "circuit_group": acc.circuit_group
            }
            for acc in update_data.accessories
        ]

        # Update ALL templates for this day (keeps accessories in sync for multi-lift days)
        lifts_updated = []
        for template in templates:
            template.accessories = accessories_json
            lifts_updated.append(template.main_lift.value)
        db.commit()

        return {
            "message": f"Updated accessories for day {day_number}",
            "day_number": day_number,
            "lifts_updated": lifts_updated,
            "accessories": accessories_json
        }

    @staticmethod
    def complete_cycle(
        db: Session,
        user: User,
        program_id: str
    ) -> dict:
        """
        Complete current cycle and increase training maxes.

        Per Jim Wendler's 5/3/1:
        - Upper body (Press, Bench): +5 lbs
        - Lower body (Squat, Deadlift): +10 lbs

        Args:
            db: Database session
            user: Current user
            program_id: Program ID

        Returns:
            Dict with updated training maxes

        Raises:
            HTTPException: If program not found
        """
        # Get program and verify ownership
        program = db.query(Program).filter(
            Program.id == program_id,
            Program.user_id == user.id
        ).first()

        if not program:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Program not found"
            )

        # Get current training maxes
        current_tms = db.query(TrainingMax).filter(
            TrainingMax.program_id == program.id
        ).order_by(TrainingMax.cycle_number.desc()).all()

        if not current_tms:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="No training maxes found"
            )

        # Group by lift type to get latest for each
        latest_tms = {}
        for tm in current_tms:
            if tm.lift_type not in latest_tms:
                latest_tms[tm.lift_type] = tm

        # Determine next cycle number
        next_cycle = max(tm.cycle_number for tm in current_tms) + 1

        # Standard progression increments per 5/3/1
        increments = {
            LiftType.PRESS: 5.0,          # Upper body: +5 lbs
            LiftType.BENCH_PRESS: 5.0,    # Upper body: +5 lbs
            LiftType.SQUAT: 10.0,         # Lower body: +10 lbs
            LiftType.DEADLIFT: 10.0       # Lower body: +10 lbs
        }

        # Create new training maxes with increases
        new_tms = {}
        for lift_type, old_tm in latest_tms.items():
            increment = increments[lift_type]
            new_value = old_tm.value + increment

            # Create new training max record
            new_tm = TrainingMax(
                program_id=program.id,
                lift_type=lift_type,
                value=new_value,
                effective_date=date.today(),
                cycle_number=next_cycle,
                reason=TrainingMaxReason.CYCLE_COMPLETION
            )
            db.add(new_tm)

            # Create history record
            history = TrainingMaxHistory(
                program_id=program.id,
                lift_type=lift_type,
                old_value=old_tm.value,
                new_value=new_value,
                change_date=datetime.utcnow(),
                reason=TrainingMaxReason.CYCLE_COMPLETION,
                notes=f"Cycle {next_cycle - 1} completed, auto-progression"
            )
            db.add(history)

            new_tms[lift_type.value] = {
                "old_value": old_tm.value,
                "new_value": new_value,
                "increase": increment
            }

        db.commit()

        return {
            "cycle_completed": next_cycle - 1,
            "next_cycle": next_cycle,
            "training_max_updates": new_tms
        }

    @staticmethod
    def generate_next_cycle(
        db: Session,
        user: User,
        program_id: str
    ) -> dict:
        """
        Generate next 4-week cycle of workouts.

        Args:
            db: Database session
            user: Current user
            program_id: Program ID

        Returns:
            Dict with cycle info and workouts created

        Raises:
            HTTPException: If program not found or no training maxes
        """
        # Get program and verify ownership
        program = db.query(Program).filter(
            Program.id == program_id,
            Program.user_id == user.id
        ).first()

        if not program:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Program not found"
            )

        # Get latest cycle number
        latest_workout = db.query(Workout).filter(
            Workout.program_id == program.id
        ).order_by(Workout.cycle_number.desc()).first()

        if not latest_workout:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No existing workouts found. Cannot generate next cycle."
            )

        next_cycle = latest_workout.cycle_number + 1

        # Check if training maxes exist for next cycle
        tms_for_next_cycle = db.query(TrainingMax).filter(
            TrainingMax.program_id == program.id,
            TrainingMax.cycle_number == next_cycle
        ).count()

        if tms_for_next_cycle == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"No training maxes found for cycle {next_cycle}. Complete current cycle first."
            )

        # Calculate start date for next cycle
        # Cycles are 3 or 4 weeks depending on include_deload
        weeks_in_cycle = 3 if not program.include_deload else 4
        start_date = latest_workout.scheduled_date + timedelta(days=7)

        # Generate workouts for next cycle (3 or 4 weeks)
        workouts_created = ProgramService._generate_workouts(
            db,
            program,
            start_date,
            next_cycle
        )

        db.commit()

        return {
            "cycle_number": next_cycle,
            "start_date": start_date,
            "workouts_generated": workouts_created
        }

    @staticmethod
    def delete_program(db: Session, user: User, program_id: str) -> None:
        """
        Delete a program and all associated data.

        Args:
            db: Database session
            user: Current user
            program_id: Program ID

        Raises:
            HTTPException: If program not found or doesn't belong to user
        """
        from app.models.workout import WorkoutSet

        # Get program and verify ownership
        program = db.query(Program).filter(
            Program.id == program_id,
            Program.user_id == user.id
        ).first()

        if not program:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Program not found"
            )

        # Delete all related data in proper order
        # 1. Delete workout sets and workout main lifts (both reference workouts)
        workouts = db.query(Workout).filter(Workout.program_id == program_id).all()
        for workout in workouts:
            db.query(WorkoutSet).filter(WorkoutSet.workout_id == workout.id).delete()
            db.query(WorkoutMainLift).filter(WorkoutMainLift.workout_id == workout.id).delete()

        # 2. Delete workouts (references program)
        db.query(Workout).filter(Workout.program_id == program_id).delete()

        # 3. Delete program templates (references program)
        db.query(ProgramTemplate).filter(ProgramTemplate.program_id == program_id).delete()

        # 4. Delete training maxes (references program)
        db.query(TrainingMax).filter(TrainingMax.program_id == program_id).delete()

        # 5. Delete training max history (references program)
        db.query(TrainingMaxHistory).filter(TrainingMaxHistory.program_id == program_id).delete()

        # 6. Finally, delete the program itself
        db.delete(program)
        db.commit()
