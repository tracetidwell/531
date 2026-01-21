# WorkoutMainLift Table Migration Plan

## Overview

Restructure the database to support multiple main lifts per workout using a WorkoutMainLift junction table. This fixes the current issue where 2-day programs create duplicate Workout records on the same training day.

**Current Problem:** Single `main_lift` enum column → 2 separate Workout records for 2-day programs → accessory duplication
**Solution:** One Workout per training day + multiple WorkoutMainLift records

## Critical Files to Modify

### Backend (7 files)
1. `/home/trace/Documents/531/backend/app/models/workout.py` - Add WorkoutMainLift model, remove main_lift column
2. `/home/trace/Documents/531/backend/app/services/program.py` - Update workout generation (lines 306-322)
3. `/home/trace/Documents/531/backend/app/services/workout.py` - Update all methods (get_workouts, get_workout_detail, complete_workout, _get_accessory_sets)
4. `/home/trace/Documents/531/backend/app/schemas/workout.py` - Update API schemas (main_lift → main_lifts array)
5. `/home/trace/Documents/531/backend/app/routers/workouts.py` - Update query parameters
6. `/home/trace/Documents/531/backend/alembic/versions/XXXXXX_add_workout_main_lift_table.py` - New migration
7. `/home/trace/Documents/531/backend/app/services/analytics.py` - Check/update main_lift references

### Frontend (5 files)
1. `/home/trace/Documents/531/frontend/lib/models/workout_models.dart` - Update Workout, WorkoutDetail models
2. `/home/trace/Documents/531/frontend/lib/screens/workouts/workout_detail_screen.dart` - Display sets per lift
3. `/home/trace/Documents/531/frontend/lib/screens/workouts/workout_calendar_screen.dart` - Update line 483
4. `/home/trace/Documents/531/frontend/lib/screens/workouts/workout_history_screen.dart` - Update display logic
5. `/home/trace/Documents/531/frontend/lib/screens/progress/progress_screen.dart` - Update filtering

## Implementation Steps

### Phase 1: Backend Models & Schema

**Step 1.1: Create WorkoutMainLift model**
- File: `/home/trace/Documents/531/backend/app/models/workout.py`
- Add new model class:
  ```python
  class WorkoutMainLift(Base):
      __tablename__ = "workout_main_lifts"
      id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
      workout_id = Column(String(36), ForeignKey("workouts.id"), nullable=False, index=True)
      lift_type = Column(SQLEnum(LiftType, ...), nullable=False)
      lift_order = Column(Integer, nullable=False, default=1)
      current_training_max = Column(Float, nullable=False)
      created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
  ```

**Step 1.2: Update Workout model**
- File: `/home/trace/Documents/531/backend/app/models/workout.py`
- Remove: `main_lift = Column(SQLEnum(LiftType), nullable=False)` (line 57)
- Add: `main_lifts = relationship("WorkoutMainLift", backref="workout", cascade="all, delete-orphan")`

**Step 1.3: Update API schemas**
- File: `/home/trace/Documents/531/backend/app/schemas/workout.py`
- Add WorkoutMainLiftResponse schema
- Update WorkoutResponse: `main_lift: str` → `main_lifts: List[WorkoutMainLiftResponse]`
- Update WorkoutDetailResponse: similar change + new `sets_by_lift` structure
- Update WorkoutListFilters: `main_lift` → `main_lifts: Optional[List[LiftType]]`

### Phase 2: Backend Logic

**Step 2.1: Update workout generation**
- File: `/home/trace/Documents/531/backend/app/services/program.py` (lines 306-322)
- Current: Creates separate Workout per lift for 2-day programs
- New: Create single Workout + multiple WorkoutMainLift records
- Logic:
  ```python
  # Create ONE workout for training day
  workout = Workout(program_id, scheduled_date, cycle, week, week_type, status)
  db.add(workout)
  db.flush()

  # Create WorkoutMainLift for each lift
  for order, lift in enumerate(lifts, start=1):
      tm = get_training_max(program, lift, cycle)
      wml = WorkoutMainLift(workout.id, lift, order, tm.value)
      db.add(wml)
  ```

**Step 2.2: Update workout service methods**
- File: `/home/trace/Documents/531/backend/app/services/workout.py`

**Changes:**
1. `get_workouts()` (lines 26-83):
   - Add helper: `_build_workout_response(workout, db)` to eager-load main_lifts
   - Update filter: Join WorkoutMainLift when filtering by main_lifts

2. `get_workout_detail()` (lines 85-166):
   - Load all WorkoutMainLift records for workout
   - Calculate sets for EACH lift
   - Return `sets_by_lift: Dict[str, Dict[str, List[WorkoutSetResponse]]]`
   - Structure: `{"squat": {"warmup_sets": [...], "main_sets": [...], "accessory_sets": [...]}, ...}`

3. `_get_accessory_sets()` (lines 222-255):
   - Change signature: `workout: Workout` → `lift_type: LiftType`
   - Query: `ProgramTemplate.main_lift == lift_type`

4. `complete_workout()` (lines 332-461):
   - Load all WorkoutMainLift records
   - Build training_maxes lookup: `{lift_type: tm_value}`
   - Handle AMRAP detection per lift
   - **Note:** May need to add `lift_type` to SetLogRequest schema to properly associate sets with lifts in multi-lift workouts

**Step 2.3: Update router**
- File: `/home/trace/Documents/531/backend/app/routers/workouts.py`
- Change query parameter: `main_lift: Optional[str]` → `main_lifts: Optional[List[str]]`

**Step 2.4: Update analytics (if needed)**
- File: `/home/trace/Documents/531/backend/app/services/analytics.py`
- Check lines 126-127, 167 for main_lift references
- Update to join WorkoutMainLift table if filtering by lift

### Phase 3: Database Migration

**Step 3.1: Create Alembic migration**
- File: `/home/trace/Documents/531/backend/alembic/versions/XXXXXX_add_workout_main_lift_table.py`
- `upgrade()`:
  1. Create workout_main_lifts table
  2. Create indexes on workout_id and (workout_id, lift_type)
  3. Drop main_lift column from workouts table
- `downgrade()`:
  1. Add main_lift column back to workouts (nullable=True)
  2. Drop workout_main_lifts table

**Step 3.2: Run migration**
- User will delete existing programs first (no data migration needed)
- Execute: `cd backend && alembic upgrade head`

### Phase 4: Frontend Models

**Step 4.1: Update workout models**
- File: `/home/trace/Documents/531/frontend/lib/models/workout_models.dart`

**Changes:**
1. Add new WorkoutMainLift class:
   ```dart
   class WorkoutMainLift {
     final String liftType;
     final int liftOrder;
     final double currentTrainingMax;

     String get displayLiftType { /* switch statement */ }
   }
   ```

2. Update Workout class:
   - Change: `final String mainLift` → `final List<WorkoutMainLift> mainLifts`
   - Update fromJson: Parse `main_lifts` array
   - Update getter: `displayMainLifts` returns joined string (e.g., "Squat + Bench Press")

3. Update WorkoutDetail class:
   - Change: `final String mainLift` → `final List<WorkoutMainLift> mainLifts`
   - Add: `final Map<String, WorkoutSetsForLift> setsByLift`
   - Update fromJson: Parse new structure

4. Add WorkoutSetsForLift helper class:
   ```dart
   class WorkoutSetsForLift {
     final List<WorkoutSet> warmupSets;
     final List<WorkoutSet> mainSets;
     final List<WorkoutSet> accessorySets;
   }
   ```

### Phase 5: Frontend UI Updates

**Step 5.1: Update workout detail screen**
- File: `/home/trace/Documents/531/frontend/lib/screens/workouts/workout_detail_screen.dart`
- Major refactor: Show sets for each lift separately
- Load state changes: `WorkoutDetail _workoutDetail` (no need for list anymore)
- UI structure:
  ```
  For each mainLift in workout.mainLifts:
    - Lift header with TM
    - Warmup sets for this lift
    - Main sets for this lift
    - Accessory sets for this lift
  ```

**Step 5.2: Update calendar screen**
- File: `/home/trace/Documents/531/frontend/lib/screens/workouts/workout_calendar_screen.dart`
- Line 483: Change `workouts.map((w) => w.displayMainLift).join(' + ')` → `workouts.first.displayMainLifts`
- Line 402: Change `workout.displayMainLift` → `workout.displayMainLifts`

**Step 5.3: Update history screen**
- File: `/home/trace/Documents/531/frontend/lib/screens/workouts/workout_history_screen.dart`
- Line 348: Change `workout.displayMainLift` → `workout.displayMainLifts`
- Line 54: Update filter parameter if needed

**Step 5.4: Update progress screen**
- File: `/home/trace/Documents/531/frontend/lib/screens/progress/progress_screen.dart`
- Line 487: Change `workout.displayMainLift` → `workout.displayMainLifts`
- Update color mapping logic if needed

**Step 5.5: Update workout logging screen**
- File: `/home/trace/Documents/531/frontend/lib/screens/workouts/workout_logging_screen.dart`
- Load workout detail and iterate through setsByLift structure
- Update set progression to handle multiple lifts

### Phase 6: Testing

**Backend Tests:**
1. Create 2-day program → verify 1 Workout + 2 WorkoutMainLift records created
2. Create 4-day program → verify 1 Workout + 1 WorkoutMainLift per day
3. Get workout detail for 2-day workout → verify sets_by_lift structure
4. Complete multi-lift workout → verify all sets saved correctly
5. Filter by main_lifts array → verify correct workouts returned

**Frontend Tests:**
1. Load workout list → verify parsing of main_lifts array
2. Display workout card → verify multiple lifts shown as "Lift1 + Lift2"
3. View workout detail → verify sets organized by lift
4. Complete workout → verify submission works

**Manual Testing:**
1. Delete all programs via UI
2. Create new 2-day program (Squat+Bench, Deadlift+Press)
3. View calendar → should see combined tiles
4. Click day → should see both lifts with their sets
5. Complete workout → log sets for both lifts
6. Verify history shows both lifts

## Key Design Decisions

### 1. Denormalize Training Max
- Store `current_training_max` in WorkoutMainLift (not just a reference)
- Rationale: Performance - avoids extra join to training_maxes table
- Trade-off: Slight data duplication vs query performance

### 2. Sets Organized by Lift
- Backend returns: `sets_by_lift: {lift_type: {warmup_sets, main_sets, accessory_sets}}`
- Frontend displays sets grouped by lift
- Rationale: Clear organization for multi-lift workouts

### 3. Lift Order Column
- Ensures consistent display order (e.g., "Squat + Bench" not "Bench + Squat")
- Important for UX consistency

### 4. No Data Migration
- User will delete and recreate programs
- Simplifies migration script (just drop old column, add new table)

## Edge Cases & Considerations

### Set-to-Lift Association in Completion
**Issue:** When completing multi-lift workout, which sets belong to which lift?
**Solution:** Frontend should send sets in order (all squat sets, then all bench sets). Backend uses order to associate. Alternative: Add `lift_type` field to SetLogRequest schema (more explicit).

### AMRAP Detection
- Must track AMRAP per lift in multi-lift workouts
- Update `_detect_amrap_and_update_rep_max()` to accept lift_type parameter

### Query Performance
- Use SQLAlchemy `joinedload(Workout.main_lifts)` to avoid N+1 queries
- Add composite index on (workout_id, lift_type) in migration

### Analytics Impact
- Any analytics queries filtering by main_lift need to join WorkoutMainLift table
- Check `/home/trace/Documents/531/backend/app/services/analytics.py` lines 126-127, 167

## Rollback Plan

**Before migration:** Don't run Alembic migration yet
**After migration:** Run `alembic downgrade -1`
**With data:** User can delete and recreate programs (no data loss)

## Success Criteria

✅ 2-day program creates 1 Workout record per training day (not 2)
✅ Accessories attached to workout, not individual lifts (no duplication)
✅ Calendar shows combined tiles: "Deadlift + Press"
✅ Workout detail displays sets organized by lift
✅ Can complete multi-lift workouts and log all sets
✅ History and progress screens work with new structure
