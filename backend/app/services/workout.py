"""
Workout service with business logic.
"""
from sqlalchemy.orm import Session, joinedload
from fastapi import HTTPException, status
from typing import List, Optional, Dict
from datetime import datetime, date
from app.models.workout import Workout, WorkoutSet, WorkoutMainLift, WorkoutStatus, WeekType, SetType
from app.models.program import Program, TrainingMax, ProgramTemplate, LiftType
from app.models.exercise import Exercise
from app.models.rep_max import RepMax
from app.models.user import User, WeightUnit
from datetime import timedelta
from app.schemas.workout import (
    WorkoutResponse, WorkoutDetailResponse, WorkoutSetResponse,
    WorkoutCompleteRequest, SetLogRequest, WorkoutMainLiftResponse,
    WorkoutSetsForLift, WorkoutCompletionResponse, WorkoutAnalysis,
    LiftAnalysis, FailedSetInfo, MissedWorkoutInfo, MissedWorkoutsResponse,
    HandleMissedWorkoutRequest, HandleMissedWorkoutResponse,
    CycleFailedRepsAnalysis
)
from app.utils.calculations import (
    calculate_working_weight, get_prescribed_reps,
    calculate_warmup_weights, calculate_1rm, calculate_training_max
)


class WorkoutService:
    """Service for handling workout operations."""

    @staticmethod
    def get_workouts(
        db: Session,
        user: User,
        program_id: Optional[str] = None,
        workout_status: Optional[str] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        main_lifts: Optional[List[str]] = None,
        cycle_number: Optional[int] = None,
        week_number: Optional[int] = None
    ) -> List[WorkoutResponse]:
        """
        Get workouts for user with optional filters.

        Args:
            db: Database session
            user: Current user
            program_id: Filter by program
            workout_status: Filter by status (scheduled, completed, skipped)
            start_date: Filter by date >= start_date
            end_date: Filter by date <= end_date
            main_lifts: Filter by main lifts (workouts containing any of these lifts)
            cycle_number: Filter by cycle
            week_number: Filter by week

        Returns:
            List of WorkoutResponse
        """
        # Base query - only user's programs, eager load main_lifts
        query = db.query(Workout).join(Program).filter(
            Program.user_id == user.id
        ).options(joinedload(Workout.main_lifts))

        # Apply filters
        if program_id:
            query = query.filter(Workout.program_id == program_id)

        if workout_status:
            # Convert string to enum for comparison
            try:
                status_enum = WorkoutStatus(workout_status.upper())
                query = query.filter(Workout.status == status_enum)
            except ValueError:
                pass  # Invalid status, ignore filter

        if start_date:
            query = query.filter(Workout.scheduled_date >= start_date)

        if end_date:
            query = query.filter(Workout.scheduled_date <= end_date)

        if main_lifts:
            # Filter workouts that have any of the specified main lifts
            query = query.join(WorkoutMainLift).filter(
                WorkoutMainLift.lift_type.in_(main_lifts)
            ).distinct()

        if cycle_number:
            query = query.filter(Workout.cycle_number == cycle_number)

        if week_number:
            query = query.filter(Workout.week_number == week_number)

        # Order by scheduled date
        workouts = query.order_by(Workout.scheduled_date).all()

        return [WorkoutResponse.model_validate(w) for w in workouts]

    @staticmethod
    def get_workout_detail(
        db: Session,
        user: User,
        workout_id: str
    ) -> WorkoutDetailResponse:
        """
        Get detailed workout with prescribed sets organized by lift.

        Args:
            db: Database session
            user: Current user
            workout_id: Workout ID

        Returns:
            WorkoutDetailResponse with all prescribed sets organized by lift

        Raises:
            HTTPException: If workout not found or not owned by user
        """
        # Get workout and verify ownership, eager load main_lifts
        workout = db.query(Workout).join(Program).filter(
            Workout.id == workout_id,
            Program.user_id == user.id
        ).options(joinedload(Workout.main_lifts)).first()

        if not workout:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workout not found"
            )

        # Build sets for each main lift
        sets_by_lift = {}
        accessory_sets = []

        # For completed workouts, fetch actual logged sets from database
        if workout.status == WorkoutStatus.COMPLETED:
            # Query all workout sets for this workout
            workout_sets = db.query(WorkoutSet).filter(
                WorkoutSet.workout_id == workout_id
            ).order_by(WorkoutSet.set_number).all()

            # Group sets by lift type (for warmup/main) and collect accessories separately
            sets_by_lift_type = {}
            for workout_set in workout_sets:
                # Convert to response format
                set_response = WorkoutSetResponse(
                    set_type=workout_set.set_type.value,
                    set_number=workout_set.set_number,
                    prescribed_reps=workout_set.prescribed_reps,
                    prescribed_weight=workout_set.prescribed_weight,
                    percentage_of_tm=workout_set.percentage_of_tm,
                    actual_reps=workout_set.actual_reps,
                    actual_weight=workout_set.actual_weight,
                    is_target_met=workout_set.is_target_met,
                    exercise_id=workout_set.exercise_id if workout_set.set_type == SetType.ACCESSORY else None,
                    circuit_group=None  # circuit_group not stored in DB, only used for prescribed sets
                )

                # Accessory sets go to workout level (will deduplicate later)
                if workout_set.set_type == SetType.ACCESSORY:
                    accessory_sets.append((workout_set.exercise_id, workout_set.set_number, set_response))
                else:
                    # Warmup and main sets go under their lift type
                    lift_type = workout_set.lift_type
                    if lift_type:
                        lift_type_str = lift_type.value
                        if lift_type_str not in sets_by_lift_type:
                            sets_by_lift_type[lift_type_str] = {
                                'warmup': [],
                                'main': []
                            }

                        if workout_set.set_type == SetType.WARMUP:
                            sets_by_lift_type[lift_type_str]['warmup'].append(set_response)
                        elif workout_set.set_type in [SetType.WORKING, SetType.AMRAP]:
                            sets_by_lift_type[lift_type_str]['main'].append(set_response)

            # Deduplicate accessory sets by (exercise_id, set_number)
            # This handles historical data where accessories were duplicated per main lift
            seen_accessory_keys = set()
            deduplicated_accessories = []
            for exercise_id, set_number, set_response in accessory_sets:
                key = (exercise_id, set_number)
                if key not in seen_accessory_keys:
                    seen_accessory_keys.add(key)
                    deduplicated_accessories.append(set_response)
            accessory_sets = deduplicated_accessories

            # Build final structure for main lifts
            for main_lift in workout.main_lifts:
                lift_type_str = main_lift.lift_type.value
                lift_sets = sets_by_lift_type.get(lift_type_str, {'warmup': [], 'main': []})

                sets_by_lift[lift_type_str] = WorkoutSetsForLift(
                    warmup_sets=lift_sets['warmup'],
                    main_sets=lift_sets['main']
                )
        else:
            # For scheduled workouts, calculate prescribed sets
            for main_lift in workout.main_lifts:
                lift_type_str = main_lift.lift_type.value

                # Calculate prescribed sets for this lift
                warmup_sets = WorkoutService._calculate_warmup_sets(
                    main_lift.current_training_max,
                    user.rounding_increment
                )

                main_sets = WorkoutService._calculate_main_sets(
                    main_lift.current_training_max,
                    workout.week_number,
                    workout.week_type,
                    user.rounding_increment
                )

                sets_by_lift[main_lift.lift_type.value] = WorkoutSetsForLift(
                    warmup_sets=warmup_sets,
                    main_sets=main_sets
                )

            # Get accessory sets once at workout level (from first main lift's template)
            if workout.main_lifts:
                accessory_sets = WorkoutService._get_accessory_sets(
                    db,
                    workout.program_id,
                    workout.main_lifts[0].lift_type
                )

        return WorkoutDetailResponse(
            id=workout.id,
            program_id=workout.program_id,
            scheduled_date=workout.scheduled_date,
            completed_date=workout.completed_date,
            cycle_number=workout.cycle_number,
            week_number=workout.week_number,
            week_type=workout.week_type.value,
            main_lifts=[
                WorkoutMainLiftResponse.model_validate(ml) for ml in workout.main_lifts
            ],
            status=workout.status.value,
            sets_by_lift=sets_by_lift,
            accessory_sets=accessory_sets,
            notes=workout.notes,
            created_at=workout.created_at
        )

    @staticmethod
    def _calculate_warmup_sets(
        training_max: float,
        rounding_increment: float
    ) -> List[WorkoutSetResponse]:
        """Calculate warmup sets for workout."""
        warmups = calculate_warmup_weights(training_max, rounding_increment)

        return [
            WorkoutSetResponse(
                set_type="warmup",
                set_number=i + 1,
                prescribed_reps=warmup["reps"],
                prescribed_weight=warmup["weight"],
                percentage_of_tm=warmup["percentage"]
            )
            for i, warmup in enumerate(warmups)
        ]

    @staticmethod
    def _calculate_main_sets(
        training_max: float,
        week_number: int,
        week_type: WeekType,
        rounding_increment: float
    ) -> List[WorkoutSetResponse]:
        """Calculate main working sets for workout."""
        main_sets = []

        for set_num in range(1, 4):  # 3 main working sets
            weight = calculate_working_weight(
                training_max,
                week_number,
                set_num,
                rounding_increment
            )

            reps = get_prescribed_reps(week_number, set_num)

            # Last set is AMRAP (except deload week)
            is_amrap = (set_num == 3 and week_type != WeekType.WEEK_4_DELOAD)

            main_sets.append(
                WorkoutSetResponse(
                    set_type="amrap" if is_amrap else "working",
                    set_number=set_num,
                    prescribed_reps=reps,  # AMRAP still has minimum reps (5, 3, or 1)
                    prescribed_weight=weight,
                    percentage_of_tm=None  # Could calculate if needed
                )
            )

        return main_sets

    @staticmethod
    def _get_accessory_sets(
        db: Session,
        program_id: str,
        lift_type: LiftType
    ) -> List[WorkoutSetResponse]:
        """Get prescribed accessory sets from program template for a specific lift."""
        # Find the program template for this lift
        # Query by both program_id and main_lift to support 2-day, 3-day, and 4-day programs
        template = db.query(ProgramTemplate).filter(
            ProgramTemplate.program_id == program_id,
            ProgramTemplate.main_lift == lift_type
        ).first()

        if not template or not template.accessories:
            return []

        # Build accessory sets from template
        accessory_sets = []
        for acc in template.accessories:
            # Each accessory has multiple sets
            for set_num in range(1, acc["sets"] + 1):
                accessory_sets.append(
                    WorkoutSetResponse(
                        set_type="accessory",
                        set_number=set_num,
                        prescribed_reps=acc["reps"],
                        prescribed_weight=None,  # User determines weight for accessories
                        percentage_of_tm=None,
                        exercise_id=acc.get("exercise_id"),
                        circuit_group=acc.get("circuit_group")  # For circuit training
                    )
                )

        return accessory_sets

    @staticmethod
    def _calculate_prescribed_values(
        set_log,
        workout: Workout,
        current_tm: float,
        rounding_increment: float,
        warmup_sets: list,
        program_template
    ) -> dict:
        """
        Calculate prescribed reps and weight based on set type.

        Args:
            set_log: The logged set from completion request
            workout: The workout being completed
            current_tm: Current training max
            rounding_increment: User's rounding preference
            warmup_sets: Pre-calculated warmup sets
            program_template: Program template for accessory info

        Returns:
            Dict with prescribed_reps, prescribed_weight, percentage_of_tm
        """
        result = {
            "prescribed_reps": None,
            "prescribed_weight": None,
            "percentage_of_tm": None
        }

        set_type = set_log.set_type
        set_number = set_log.set_number

        # Working sets (including AMRAP)
        if set_type in ["working", "amrap"]:
            result["prescribed_reps"] = get_prescribed_reps(
                workout.week_number,
                set_number
            )
            result["prescribed_weight"] = calculate_working_weight(
                current_tm,
                workout.week_number,
                set_number,
                rounding_increment
            )
            # Calculate percentage
            percentages = {
                1: [0.65, 0.75, 0.85],
                2: [0.70, 0.80, 0.90],
                3: [0.75, 0.85, 0.95],
                4: [0.40, 0.50, 0.60],
            }
            result["percentage_of_tm"] = percentages[workout.week_number][set_number - 1]

        # Warmup sets
        elif set_type == "warmup":
            # Warmup sets are 1-indexed, array is 0-indexed
            if 1 <= set_number <= len(warmup_sets):
                warmup_data = warmup_sets[set_number - 1]
                result["prescribed_reps"] = warmup_data["reps"]
                result["prescribed_weight"] = warmup_data["weight"]
                result["percentage_of_tm"] = warmup_data["percentage"]

        # Accessory sets
        elif set_type == "accessory":
            # Try to get prescribed reps from program template
            if program_template and program_template.accessories:
                # Find the accessory exercise in the template
                for acc in program_template.accessories:
                    if acc.get("exercise_id") == set_log.exercise_id:
                        result["prescribed_reps"] = acc.get("reps")
                        break
            # Weight is user-determined for accessories (no prescribed weight)

        return result

    @staticmethod
    def complete_workout(
        db: Session,
        user: User,
        workout_id: str,
        completion_data: WorkoutCompleteRequest
    ) -> WorkoutCompletionResponse:
        """
        Complete a workout by logging all sets.

        Args:
            db: Database session
            user: Current user
            workout_id: Workout ID
            completion_data: Logged sets and notes

        Returns:
            WorkoutCompletionResponse with workout data and performance analysis

        Raises:
            HTTPException: If workout not found or already completed
        """
        # Get workout and verify ownership, eager load main_lifts
        workout = db.query(Workout).join(Program).filter(
            Workout.id == workout_id,
            Program.user_id == user.id
        ).options(joinedload(Workout.main_lifts)).first()

        if not workout:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workout not found"
            )

        if workout.status == WorkoutStatus.COMPLETED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Workout already completed"
            )

        # Build training maxes lookup by lift type
        training_maxes_by_lift = {}
        warmup_sets_by_lift = {}
        program_templates_by_lift = {}

        for main_lift in workout.main_lifts:
            lift_type = main_lift.lift_type
            current_tm = main_lift.current_training_max

            training_maxes_by_lift[lift_type] = current_tm

            # Pre-calculate warmup sets for this lift
            warmup_sets_by_lift[lift_type] = calculate_warmup_weights(
                current_tm,
                user.rounding_increment
            )

            # Get program template for this lift
            program_template = db.query(ProgramTemplate).filter(
                ProgramTemplate.program_id == workout.program_id,
                ProgramTemplate.main_lift == lift_type
            ).first()
            program_templates_by_lift[lift_type] = program_template

        # Save all sets and track AMRAP sets (one per lift)
        amrap_workout_set_ids_by_lift = {}
        for set_log in completion_data.sets:
            # Determine which lift this set belongs to
            lift_type = LiftType(set_log.lift_type) if set_log.lift_type else None
            if not lift_type and len(workout.main_lifts) == 1:
                # Single-lift workout, use the only lift
                lift_type = workout.main_lifts[0].lift_type

            if not lift_type:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="lift_type is required for multi-lift workouts"
                )

            current_tm = training_maxes_by_lift.get(lift_type, 0)
            warmup_sets_calculated = warmup_sets_by_lift.get(lift_type, [])
            program_template = program_templates_by_lift.get(lift_type)

            # Calculate prescribed values based on set type
            prescribed_values = WorkoutService._calculate_prescribed_values(
                set_log=set_log,
                workout=workout,
                current_tm=current_tm,
                rounding_increment=user.rounding_increment,
                warmup_sets=warmup_sets_calculated,
                program_template=program_template
            )

            # Calculate if target was met (actual_reps >= prescribed_reps)
            is_target_met = True  # Default for sets without prescribed reps
            if prescribed_values["prescribed_reps"] is not None:
                is_target_met = set_log.actual_reps >= prescribed_values["prescribed_reps"]

            # exercise_id should be NULL for main lifts (frontend sends "main_lift" placeholder)
            exercise_id = set_log.exercise_id
            if exercise_id == "main_lift" or exercise_id == "main lift":
                exercise_id = None

            workout_set = WorkoutSet(
                workout_id=workout.id,
                exercise_id=exercise_id,
                set_type=SetType(set_log.set_type.upper()),
                set_number=set_log.set_number,
                lift_type=lift_type,  # Save which lift this set belongs to
                prescribed_reps=prescribed_values["prescribed_reps"],
                actual_reps=set_log.actual_reps,
                prescribed_weight=prescribed_values["prescribed_weight"],
                actual_weight=set_log.actual_weight,
                weight_unit=WeightUnit(set_log.weight_unit.upper()),
                percentage_of_tm=prescribed_values["percentage_of_tm"],
                is_target_met=is_target_met,
                notes=set_log.notes
            )

            db.add(workout_set)

            # Track the AMRAP set (last working set on non-deload weeks) per lift
            print(f"DEBUG PR: set_type={set_log.set_type}, set_number={set_log.set_number}, week_type={workout.week_type}, lift={lift_type}")
            if (set_log.set_type in ["working", "amrap"] and
                set_log.set_number == 3 and
                workout.week_type != WeekType.WEEK_4_DELOAD):
                db.flush()  # Get the workout_set ID
                amrap_workout_set_ids_by_lift[lift_type] = workout_set.id
                print(f"DEBUG PR: Tracked AMRAP for {lift_type}: workout_set_id={workout_set.id}")

        # Detect AMRAP and update rep maxes for each lift
        for lift_type, amrap_workout_set_id in amrap_workout_set_ids_by_lift.items():
            WorkoutService._detect_amrap_and_update_rep_max(
                db,
                user,
                lift_type,
                amrap_workout_set_id
            )

        # Update workout status
        workout.status = WorkoutStatus.COMPLETED
        workout.completed_date = completion_data.completed_date or datetime.utcnow()
        if completion_data.workout_notes:
            workout.notes = completion_data.workout_notes

        db.commit()
        db.refresh(workout)

        # Get all logged sets for analysis
        logged_sets = db.query(WorkoutSet).filter(
            WorkoutSet.workout_id == workout.id
        ).all()

        # Generate performance analysis
        analysis = WorkoutService.analyze_workout_performance(db, workout, logged_sets, user.id)

        return WorkoutCompletionResponse(
            workout=WorkoutResponse.model_validate(workout),
            analysis=analysis
        )

    @staticmethod
    def _detect_amrap_and_update_rep_max(
        db: Session,
        user: User,
        lift_type: LiftType,
        amrap_workout_set_id: str
    ):
        """
        Detect AMRAP set and update rep max if performance is good.

        AMRAP is the last working set (set 3) on non-deload weeks.
        """
        # Get the AMRAP workout set
        amrap_set = db.query(WorkoutSet).filter(
            WorkoutSet.id == amrap_workout_set_id
        ).first()

        print(f"DEBUG PR: _detect_amrap called for {lift_type}, amrap_set={amrap_set}")

        if not amrap_set:
            print(f"DEBUG PR: No amrap_set found for id={amrap_workout_set_id}")
            return

        print(f"DEBUG PR: amrap_set weight={amrap_set.actual_weight}, reps={amrap_set.actual_reps}")

        # Calculate 1RM from AMRAP performance
        calculated_1rm = calculate_1rm(amrap_set.actual_weight, amrap_set.actual_reps)
        print(f"DEBUG PR: Calculated 1RM={calculated_1rm}")

        # Only update if this is a new PR for this rep range
        existing_rep_max = db.query(RepMax).filter(
            RepMax.user_id == user.id,
            RepMax.lift_type == lift_type,
            RepMax.reps == amrap_set.actual_reps
        ).order_by(RepMax.achieved_date.desc()).first()

        print(f"DEBUG PR: existing_rep_max={existing_rep_max}")

        # Update if no existing record or if this is heavier
        should_update = (
            not existing_rep_max or
            amrap_set.actual_weight > existing_rep_max.weight
        )

        print(f"DEBUG PR: should_update={should_update}")

        if should_update:
            # Get workout to access completed_date
            workout = db.query(Workout).join(WorkoutSet).filter(
                WorkoutSet.id == amrap_workout_set_id
            ).first()

            # Use date from completed_date, or today
            achieved = workout.completed_date.date() if workout and workout.completed_date else date.today()

            rep_max = RepMax(
                user_id=user.id,
                lift_type=lift_type,
                reps=amrap_set.actual_reps,
                weight=amrap_set.actual_weight,
                weight_unit=amrap_set.weight_unit,
                calculated_1rm=calculated_1rm,
                achieved_date=achieved,
                workout_set_id=amrap_set.id
            )

            db.add(rep_max)

    @staticmethod
    def skip_workout(
        db: Session,
        user: User,
        workout_id: str
    ) -> WorkoutResponse:
        """
        Skip a workout, marking it as intentionally skipped.

        Args:
            db: Database session
            user: Current user
            workout_id: Workout ID

        Returns:
            Updated WorkoutResponse

        Raises:
            HTTPException: If workout not found, not owned by user, or already completed/skipped
        """
        # Get workout and verify ownership, eager load main_lifts
        workout = db.query(Workout).join(Program).filter(
            Workout.id == workout_id,
            Program.user_id == user.id
        ).options(joinedload(Workout.main_lifts)).first()

        if not workout:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workout not found"
            )

        if workout.status == WorkoutStatus.COMPLETED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot skip a completed workout"
            )

        if workout.status == WorkoutStatus.SKIPPED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Workout already skipped"
            )

        # Update workout status to skipped
        workout.status = WorkoutStatus.SKIPPED

        db.commit()
        db.refresh(workout)

        return WorkoutResponse.model_validate(workout)

    @staticmethod
    def analyze_workout_performance(
        db: Session,
        workout: Workout,
        logged_sets: List[WorkoutSet],
        user_id: str
    ) -> WorkoutAnalysis:
        """
        Analyze workout performance and generate recommendations.

        Based on 5/3/1 methodology:
        - If you fail to hit minimum reps on AMRAP, TM may be too high
        - Recommendations are based on best estimated 1RM from recent rep max history
        - TM should be 90% of the best calculated 1RM across all rep ranges

        Args:
            db: Database session
            workout: The completed workout
            logged_sets: All logged sets for this workout
            user_id: The user's ID for querying rep max history

        Returns:
            WorkoutAnalysis with per-lift analysis and recommendations
        """
        lift_analyses = []
        overall_success = True
        has_recommendations = False

        # Group sets by lift type
        sets_by_lift: Dict[LiftType, List[WorkoutSet]] = {}
        for ws in logged_sets:
            if ws.lift_type:
                sets_by_lift.setdefault(ws.lift_type, []).append(ws)

        # Get training maxes for each lift
        tm_by_lift = {ml.lift_type: ml.current_training_max for ml in workout.main_lifts}

        # Analyze each lift
        for lift_type, sets in sets_by_lift.items():
            # Filter to working sets only (not warmup or accessory)
            working_sets = [s for s in sets if s.set_type in [SetType.WORKING, SetType.AMRAP]]

            if not working_sets:
                continue

            # Check for failed sets
            failed_sets = []
            amrap_set = None
            all_targets_met = True

            for ws in working_sets:
                if not ws.is_target_met:
                    all_targets_met = False
                    failed_sets.append(FailedSetInfo(
                        set_number=ws.set_number,
                        set_type=ws.set_type.value,
                        prescribed_reps=ws.prescribed_reps or 0,
                        actual_reps=ws.actual_reps,
                        prescribed_weight=ws.prescribed_weight or 0
                    ))

                # Track AMRAP set (set 3 on non-deload weeks)
                if ws.set_type == SetType.AMRAP or (ws.set_number == 3 and workout.week_type != WeekType.WEEK_4_DELOAD):
                    amrap_set = ws

            if not all_targets_met:
                overall_success = False

            # Generate recommendation based on performance
            recommendation = None
            recommendation_type = None
            current_tm = tm_by_lift.get(lift_type, 0)
            lift_display = WorkoutService._get_lift_display_name(lift_type)

            # Check AMRAP performance
            amrap_reps = amrap_set.actual_reps if amrap_set else None
            amrap_minimum = amrap_set.prescribed_reps if amrap_set else None
            amrap_exceeded = None
            estimated_1rm = None
            suggested_new_tm = None

            if amrap_set and amrap_minimum:
                amrap_exceeded = amrap_reps >= amrap_minimum
                amrap_weight = amrap_set.actual_weight

                # Calculate estimated 1RM from this workout's AMRAP performance
                this_workout_1rm = calculate_1rm(amrap_weight, amrap_reps) if amrap_reps > 0 else 0

                # Get the best estimated 1RM from rep max history (past 4 weeks)
                # This looks at ALL rep ranges (1-12) and finds the highest calculated 1RM
                best_historical_1rm = WorkoutService.get_best_estimated_1rm(
                    db, user_id, lift_type, weeks=4
                )

                # Use the best available 1RM estimate
                if best_historical_1rm:
                    estimated_1rm = best_historical_1rm
                else:
                    estimated_1rm = this_workout_1rm

                # New TM should be 90% of the best calculated 1RM (per 5/3/1 methodology)
                suggested_new_tm = calculate_training_max(estimated_1rm) if estimated_1rm > 0 else None

                # Failed to hit minimum on AMRAP - critical issue
                if not amrap_exceeded:
                    if suggested_new_tm:
                        recommendation = (
                            f"You completed {amrap_reps} rep{'s' if amrap_reps != 1 else ''} at {int(amrap_weight)} lbs "
                            f"on your {amrap_minimum}+ set for {lift_display}. "
                            f"Based on your recent rep max history, your best estimated 1RM is {int(estimated_1rm)} lbs. "
                            f"Reset your training max to {int(suggested_new_tm)} lbs (90% of estimated 1RM) "
                            f"to ensure continued progress."
                        )
                    else:
                        recommendation = (
                            f"You completed {amrap_reps} rep{'s' if amrap_reps != 1 else ''} at {int(amrap_weight)} lbs "
                            f"on your {amrap_minimum}+ set for {lift_display}. "
                            f"Consider reducing your training max to ensure continued progress."
                        )
                    recommendation_type = "critical"
                    has_recommendations = True

                # Hit minimum but barely (exactly minimum or 1 rep over on 1+ day)
                elif amrap_reps <= amrap_minimum + 1 and workout.week_type == WeekType.WEEK_3_531:
                    rec_msg = f"You hit {amrap_reps} reps on your 1+ set for {lift_display}. This is close to the minimum."
                    if suggested_new_tm and suggested_new_tm < current_tm:
                        rec_msg += f" Based on recent history (best 1RM: {int(estimated_1rm)} lbs), consider resetting TM to {int(suggested_new_tm)} lbs if progress stalls."
                    else:
                        rec_msg += " Monitor your next cycle closely."
                    recommendation = rec_msg
                    recommendation_type = "warning"
                    has_recommendations = True

                # Crushed it - good sign
                elif amrap_reps >= amrap_minimum + 5:
                    recommendation = (
                        f"Excellent performance on {lift_display}! "
                        f"You hit {amrap_reps} reps on your {amrap_minimum}+ set "
                        f"(estimated 1RM: {int(this_workout_1rm)} lbs). "
                        f"Your training max is well calibrated."
                    )
                    recommendation_type = "info"

            # Failed on working sets (not just AMRAP) - also concerning
            if len(failed_sets) > 0 and recommendation_type != "critical":
                failed_set_nums = ", ".join([f"Set {fs.set_number}" for fs in failed_sets])
                recommendation = (
                    f"You missed target reps on {failed_set_nums} for {lift_display}. "
                    f"Consider whether fatigue, form issues, or training max may be factors. "
                    f"If this continues, reduce TM by 10%."
                )
                recommendation_type = "warning"
                has_recommendations = True

            lift_analyses.append(LiftAnalysis(
                lift_type=lift_type.value,
                all_targets_met=all_targets_met,
                failed_sets=failed_sets,
                amrap_reps=amrap_reps,
                amrap_minimum=amrap_minimum,
                amrap_exceeded_minimum=amrap_exceeded,
                current_training_max=current_tm,
                estimated_1rm=estimated_1rm,
                suggested_training_max=suggested_new_tm,
                recommendation=recommendation,
                recommendation_type=recommendation_type
            ))

        # Generate overall summary
        if overall_success:
            if any(la.recommendation_type == "info" for la in lift_analyses):
                summary = "Great workout! You hit all your targets and showed strong performance."
            else:
                summary = "Solid workout. All targets met."
        else:
            failed_lifts = [la.lift_type for la in lift_analyses if not la.all_targets_met]
            if len(failed_lifts) == 1:
                summary = f"Workout complete with some missed targets on {WorkoutService._get_lift_display_name(LiftType(failed_lifts[0]))}."
            else:
                summary = f"Workout complete with missed targets on {len(failed_lifts)} lifts. Review recommendations below."

        # Get cycle-level analysis if there are failures
        cycle_analysis = None
        if not overall_success:
            cycle_data = WorkoutService.analyze_cycle_failed_reps(
                db, workout.program_id, workout.cycle_number
            )
            if cycle_data["recommendation"] != "none":
                cycle_analysis = CycleFailedRepsAnalysis(
                    recommendation=cycle_data["recommendation"],
                    lifts=cycle_data["lifts"],
                    message=cycle_data["message"]
                )
                has_recommendations = True

        return WorkoutAnalysis(
            overall_success=overall_success,
            lifts=lift_analyses,
            summary=summary,
            has_recommendations=has_recommendations,
            cycle_analysis=cycle_analysis
        )

    @staticmethod
    def _get_lift_display_name(lift_type: LiftType) -> str:
        """Get human-readable name for a lift type."""
        names = {
            LiftType.SQUAT: "Squat",
            LiftType.DEADLIFT: "Deadlift",
            LiftType.BENCH_PRESS: "Bench Press",
            LiftType.PRESS: "Overhead Press"
        }
        return names.get(lift_type, lift_type.value)

    @staticmethod
    def get_best_estimated_1rm(
        db: Session,
        user_id: str,
        lift_type: LiftType,
        weeks: int = 4
    ) -> Optional[float]:
        """
        Get the best estimated 1RM for a lift based on rep max history.

        Looks at all rep max records (personal records from AMRAP sets) over
        the specified time period and returns the highest calculated 1RM.

        Args:
            db: Database session
            user_id: User ID
            lift_type: The lift type to check
            weeks: Number of weeks to look back (default 4)

        Returns:
            The highest calculated 1RM, or None if no records found
        """
        cutoff_date = date.today() - timedelta(weeks=weeks)

        # Query all rep maxes for this lift in the time period
        rep_maxes = db.query(RepMax).filter(
            RepMax.user_id == user_id,
            RepMax.lift_type == lift_type,
            RepMax.achieved_date >= cutoff_date
        ).all()

        if not rep_maxes:
            return None

        # Find the highest calculated 1RM across all rep ranges
        best_1rm = max(rm.calculated_1rm for rm in rep_maxes)
        return best_1rm

    @staticmethod
    def get_suggested_training_max(
        db: Session,
        user_id: str,
        lift_type: LiftType,
        weeks: int = 4
    ) -> Optional[float]:
        """
        Get the suggested training max based on recent rep max history.

        Per 5/3/1 methodology: TM = 90% of estimated 1RM

        Args:
            db: Database session
            user_id: User ID
            lift_type: The lift type
            weeks: Number of weeks to look back

        Returns:
            Suggested training max (90% of best estimated 1RM), or None
        """
        best_1rm = WorkoutService.get_best_estimated_1rm(db, user_id, lift_type, weeks)
        if best_1rm is None:
            return None
        return calculate_training_max(best_1rm)

    @staticmethod
    def analyze_cycle_failed_reps(
        db: Session,
        program_id: str,
        cycle_number: int
    ) -> Dict[str, any]:
        """
        Analyze failed reps across all workouts in a cycle.

        Per Jim Wendler's 5/3/1 methodology:
        - Single lift failing: Consider reducing TM for that lift by 10%
        - Multiple lifts failing: Consider a deload week, then reduce all TMs

        Args:
            db: Database session
            program_id: Program ID
            cycle_number: Cycle number to analyze

        Returns:
            Dict with recommendation type, affected lifts, and message
        """
        # Get all completed workouts in this cycle
        completed_workouts = db.query(Workout).filter(
            Workout.program_id == program_id,
            Workout.cycle_number == cycle_number,
            Workout.status == WorkoutStatus.COMPLETED
        ).all()

        if not completed_workouts:
            return {"recommendation": "none", "lifts": [], "message": ""}

        workout_ids = [w.id for w in completed_workouts]

        # Get all failed working sets (is_target_met = False) in these workouts
        failed_sets = db.query(WorkoutSet).filter(
            WorkoutSet.workout_id.in_(workout_ids),
            WorkoutSet.set_type.in_([SetType.WORKING, SetType.AMRAP]),
            WorkoutSet.is_target_met == False
        ).all()

        if not failed_sets:
            return {"recommendation": "none", "lifts": [], "message": ""}

        # Group by lift type
        failed_by_lift: Dict[LiftType, List[WorkoutSet]] = {}
        for ws in failed_sets:
            if ws.lift_type:
                failed_by_lift.setdefault(ws.lift_type, []).append(ws)

        failed_lift_names = [
            WorkoutService._get_lift_display_name(lt) for lt in failed_by_lift.keys()
        ]

        if len(failed_by_lift) == 1:
            # Single lift failed in this cycle
            lift = list(failed_by_lift.keys())[0]
            lift_name = WorkoutService._get_lift_display_name(lift)
            failed_count = len(failed_by_lift[lift])
            return {
                "recommendation": "adjust_training_max",
                "lifts": [lift.value],
                "message": (
                    f"You've missed {failed_count} working set target(s) for {lift_name} "
                    f"this cycle. Consider reducing your training max by 10% to ensure "
                    f"continued progress and proper recovery."
                )
            }
        else:
            # Multiple lifts failed
            return {
                "recommendation": "deload_then_adjust",
                "lifts": [lt.value for lt in failed_by_lift.keys()],
                "message": (
                    f"You've missed targets on multiple lifts ({', '.join(failed_lift_names)}) "
                    f"this cycle. Consider taking a deload week, then reducing your training maxes "
                    f"by 10% across all affected lifts."
                )
            }

    @staticmethod
    def get_missed_workouts(
        db: Session,
        user: User
    ) -> MissedWorkoutsResponse:
        """
        Get all missed workouts for a user.

        A workout is considered "missed" if:
        - Its status is SCHEDULED
        - Its scheduled_date is before today

        Args:
            db: Database session
            user: Current user

        Returns:
            MissedWorkoutsResponse with list of missed workouts
        """
        today = date.today()

        # Find all scheduled workouts with past dates
        missed = db.query(Workout).join(Program).filter(
            Program.user_id == user.id,
            Workout.status == WorkoutStatus.SCHEDULED,
            Workout.scheduled_date < today
        ).options(joinedload(Workout.main_lifts)).order_by(
            Workout.scheduled_date
        ).all()

        missed_infos = []
        for workout in missed:
            days_overdue = (today - workout.scheduled_date).days
            # Can reschedule if less than 14 days overdue
            can_reschedule = days_overdue <= 14

            missed_infos.append(MissedWorkoutInfo(
                workout=WorkoutResponse.model_validate(workout),
                days_overdue=days_overdue,
                can_reschedule=can_reschedule
            ))

        return MissedWorkoutsResponse(
            missed_workouts=missed_infos,
            user_preference=user.missed_workout_preference.value,
            count=len(missed_infos)
        )

    @staticmethod
    def handle_missed_workout(
        db: Session,
        user: User,
        workout_id: str,
        request: HandleMissedWorkoutRequest
    ) -> HandleMissedWorkoutResponse:
        """
        Handle a missed workout by skipping or rescheduling.

        Args:
            db: Database session
            user: Current user
            workout_id: The missed workout ID
            request: Action to take (skip or reschedule)

        Returns:
            HandleMissedWorkoutResponse with result

        Raises:
            HTTPException: If workout not found, not owned, or invalid action
        """
        # Get workout and verify ownership
        workout = db.query(Workout).join(Program).filter(
            Workout.id == workout_id,
            Program.user_id == user.id
        ).options(joinedload(Workout.main_lifts)).first()

        if not workout:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workout not found"
            )

        if workout.status != WorkoutStatus.SCHEDULED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Workout is not in scheduled status"
            )

        today = date.today()
        if workout.scheduled_date >= today:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Workout is not missed (scheduled for today or future)"
            )

        if request.action == "skip":
            # Simply skip the workout
            workout.status = WorkoutStatus.SKIPPED
            db.commit()
            db.refresh(workout)

            return HandleMissedWorkoutResponse(
                workout=WorkoutResponse.model_validate(workout),
                action_taken="skipped",
                rescheduled_count=0
            )

        elif request.action == "reschedule":
            # Determine reschedule date
            reschedule_to = request.reschedule_date or today

            if reschedule_to < today:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Cannot reschedule to a past date"
                )

            # Calculate how many days to shift
            days_shift = (reschedule_to - workout.scheduled_date).days

            # Get all scheduled workouts for this program from this workout onwards
            future_workouts = db.query(Workout).filter(
                Workout.program_id == workout.program_id,
                Workout.status == WorkoutStatus.SCHEDULED,
                Workout.scheduled_date >= workout.scheduled_date
            ).order_by(Workout.scheduled_date).all()

            # Shift all future workouts by the same amount
            rescheduled_count = 0
            for w in future_workouts:
                w.scheduled_date = w.scheduled_date + timedelta(days=days_shift)
                rescheduled_count += 1

            db.commit()
            db.refresh(workout)

            return HandleMissedWorkoutResponse(
                workout=WorkoutResponse.model_validate(workout),
                action_taken="rescheduled",
                rescheduled_count=rescheduled_count
            )

        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid action. Must be 'skip' or 'reschedule'"
            )

    @staticmethod
    def auto_handle_missed_workouts(
        db: Session,
        user: User
    ) -> List[HandleMissedWorkoutResponse]:
        """
        Automatically handle all missed workouts based on user preference.

        Only processes if user preference is 'skip' or 'reschedule'.
        If preference is 'ask', returns empty list (user must handle manually).

        Args:
            db: Database session
            user: Current user

        Returns:
            List of HandleMissedWorkoutResponse for each handled workout
        """
        from app.models.user import MissedWorkoutPreference

        if user.missed_workout_preference == MissedWorkoutPreference.ASK:
            return []

        missed_response = WorkoutService.get_missed_workouts(db, user)
        results = []

        for missed_info in missed_response.missed_workouts:
            if user.missed_workout_preference == MissedWorkoutPreference.SKIP:
                request = HandleMissedWorkoutRequest(action="skip")
            else:  # RESCHEDULE
                request = HandleMissedWorkoutRequest(
                    action="reschedule",
                    reschedule_date=date.today()
                )

            result = WorkoutService.handle_missed_workout(
                db, user, missed_info.workout.id, request
            )
            results.append(result)

        return results
