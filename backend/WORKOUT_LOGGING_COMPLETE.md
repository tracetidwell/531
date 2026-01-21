## Workout Logging System - Implementation Complete

The workout logging feature is now complete! Users can now view their generated workouts with all prescribed sets and log their actual performance.

---

## What Was Implemented

### 1. Workout Schemas

**File:** `backend/app/schemas/workout.py`

Complete Pydantic schemas for workout operations:

- `WorkoutResponse` - Basic workout information (date, cycle, week, lift, status)
- `WorkoutDetailResponse` - Full workout with all prescribed sets:
  - Warmup sets (4 sets with calculated weights)
  - Main working sets (3 sets, last one is AMRAP)
  - Accessory sets (from program template)
  - Current training max
- `SetLogRequest` - Log a single set performance
- `WorkoutCompleteRequest` - Complete workout with all logged sets
- `WorkoutSetResponse` - Individual set (prescribed or logged)

### 2. Workout Service Layer

**File:** `backend/app/services/workout.py`

Complete business logic for workout operations:

**`get_workouts()`** - List workouts with comprehensive filters:
- Filter by program, status, date range, lift type, cycle, week
- Returns workouts ordered by scheduled date
- Only shows user's own workouts

**`get_workout_detail()`** - Get workout with ALL prescribed sets:
- Calculates 4 warmup sets using standard 5/3/1 progression
  - Empty bar × 5
  - 40% TM × 5
  - 50% TM × 5
  - 60% TM × 3
- Calculates 3 main working sets with proper percentages:
  - Week 1: 65%/75%/85% for 5/5/5+
  - Week 2: 70%/80%/90% for 3/3/3+
  - Week 3: 75%/85%/95% for 5/3/1+
  - Week 4 (Deload): 40%/50%/60% for 5/5/5
- Loads accessory sets from program template
- All weights rounded to user's rounding increment

**`complete_workout()`** - Log workout completion:
- Saves all performed sets (warmup, working, accessory)
- Automatically detects AMRAP performance
- Updates rep max records on PRs
- Marks workout as completed with timestamp

**`_detect_amrap_and_update_rep_max()`** - AMRAP detection:
- Identifies last working set (set 3) on non-deload weeks
- Calculates 1RM using Epley formula
- Creates RepMax record if it's a PR for that rep range
- Tracks progress over time

### 3. Workout API Endpoints

**File:** `backend/app/routers/workouts.py`

Three powerful endpoints for workout management:

**`GET /api/v1/workouts`** - List workouts
- Query parameters for filtering:
  - `program_id` - Show workouts from specific program
  - `status` - scheduled, completed, or skipped
  - `start_date` / `end_date` - Date range
  - `main_lift` - press, deadlift, bench_press, or squat
  - `cycle_number` - Filter by cycle
  - `week_number` - Filter by week (1-4)
- Returns list of workouts ordered by date

**`GET /api/v1/workouts/{workout_id}`** - Get workout details
- Returns complete workout with all prescribed sets
- Shows exactly what weights and reps to do
- Includes current training max
- Ready to use before starting workout

**`POST /api/v1/workouts/{workout_id}/complete`** - Complete workout
- Log all performed sets
- Auto-detects AMRAP and updates rep maxes
- Marks workout as completed
- Tracks your progress!

### 4. Main App Integration

**File:** `backend/app/main.py`

Workout router integrated at `/api/v1/workouts`

---

## How It Works

### Viewing Workouts

When a program is created, 16 workouts are automatically generated (4 weeks × 4 days). Users can:

1. **List all workouts** - See upcoming and completed workouts
2. **Filter workouts** - By program, date, lift, cycle, or week
3. **View workout details** - See exactly what to lift before starting

### Prescribed Sets Calculation

When you view a workout detail, the system calculates:

**Warmup Sets (4 sets):**
```
Set 1: Empty bar (45 lbs) × 5 reps
Set 2: 40% of Training Max × 5 reps
Set 3: 50% of Training Max × 5 reps
Set 4: 60% of Training Max × 3 reps
```

**Main Working Sets (3 sets):**

Week 1 (5/5/5+):
```
Set 1: 65% of TM × 5 reps
Set 2: 75% of TM × 5 reps
Set 3: 85% of TM × 5+ reps (AMRAP)
```

Week 2 (3/3/3+):
```
Set 1: 70% of TM × 3 reps
Set 2: 80% of TM × 3 reps
Set 3: 90% of TM × 3+ reps (AMRAP)
```

Week 3 (5/3/1+):
```
Set 1: 75% of TM × 5 reps
Set 2: 85% of TM × 3 reps
Set 3: 95% of TM × 1+ reps (AMRAP)
```

Week 4 (Deload):
```
Set 1: 40% of TM × 5 reps
Set 2: 50% of TM × 5 reps
Set 3: 60% of TM × 5 reps (NO AMRAP)
```

**Accessory Sets:**
- Loaded from program template
- User determines weight for accessories
- Sets and reps from program creation

All weights are rounded to user's rounding increment (default: 5 lbs).

### Logging Workouts

When you complete a workout, you log:
- All warmup sets performed
- All main working sets (including AMRAP)
- All accessory sets

The system automatically:
1. Saves all your logged sets
2. Detects your AMRAP performance
3. Calculates your estimated 1RM
4. Updates rep max records if you hit a PR
5. Marks workout as completed

### AMRAP Detection & Rep Max Tracking

**What is AMRAP?**
- AMRAP = "As Many Reps As Possible"
- Last working set on non-deload weeks
- You do the prescribed weight for max reps

**How it works:**
1. System identifies set 3 as AMRAP (except deload week)
2. You log actual reps completed
3. System calculates 1RM using Epley formula: `1RM = weight × (1 + reps/30)`
4. If it's a PR for that rep count, creates RepMax record
5. Tracks your progress over time!

**Example:**
- Week 1, Set 3: 200 lbs × 8 reps
- Calculated 1RM: 200 × (1 + 8/30) = 253 lbs
- If 200×8 is your best 8-rep set, it gets saved as a RepMax record

---

## API Usage Examples

### 1. List All Your Workouts

```bash
curl http://localhost:8000/api/v1/workouts \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 2. List Workouts for a Specific Program

```bash
curl "http://localhost:8000/api/v1/workouts?program_id=PROGRAM_ID" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 3. View This Week's Workouts

```bash
curl "http://localhost:8000/api/v1/workouts?start_date=2025-01-06&end_date=2025-01-12" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 4. Get Workout Details (Before Starting)

```bash
curl http://localhost:8000/api/v1/workouts/WORKOUT_ID \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response includes:**
```json
{
  "id": "workout-uuid",
  "scheduled_date": "2025-01-06",
  "week_number": 1,
  "week_type": "week_1_5s",
  "main_lift": "squat",
  "current_training_max": 300,
  "warmup_sets": [
    {"set_number": 1, "prescribed_weight": 45, "prescribed_reps": 5},
    {"set_number": 2, "prescribed_weight": 120, "prescribed_reps": 5},
    {"set_number": 3, "prescribed_weight": 150, "prescribed_reps": 5},
    {"set_number": 4, "prescribed_weight": 180, "prescribed_reps": 3}
  ],
  "main_sets": [
    {"set_number": 1, "prescribed_weight": 195, "prescribed_reps": 5},
    {"set_number": 2, "prescribed_weight": 225, "prescribed_reps": 5},
    {"set_number": 3, "prescribed_weight": 255, "prescribed_reps": null}
  ],
  "accessory_sets": [...]
}
```

### 5. Complete a Workout

```bash
curl -X POST http://localhost:8000/api/v1/workouts/WORKOUT_ID/complete \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sets": [
      {"set_type": "warmup", "set_number": 1, "exercise_id": "squat-id", "actual_reps": 5, "actual_weight": 45, "weight_unit": "lbs"},
      {"set_type": "warmup", "set_number": 2, "exercise_id": "squat-id", "actual_reps": 5, "actual_weight": 120, "weight_unit": "lbs"},
      {"set_type": "warmup", "set_number": 3, "exercise_id": "squat-id", "actual_reps": 5, "actual_weight": 150, "weight_unit": "lbs"},
      {"set_type": "warmup", "set_number": 4, "exercise_id": "squat-id", "actual_reps": 3, "actual_weight": 180, "weight_unit": "lbs"},
      {"set_type": "working", "set_number": 1, "exercise_id": "squat-id", "actual_reps": 5, "actual_weight": 195, "weight_unit": "lbs"},
      {"set_type": "working", "set_number": 2, "exercise_id": "squat-id", "actual_reps": 5, "actual_weight": 225, "weight_unit": "lbs"},
      {"set_type": "working", "set_number": 3, "exercise_id": "squat-id", "actual_reps": 8, "actual_weight": 255, "weight_unit": "lbs", "notes": "AMRAP - felt great!"},
      {"set_type": "accessory", "set_number": 1, "exercise_id": "lunges-id", "actual_reps": 10, "actual_weight": 50, "weight_unit": "lbs"}
    ],
    "workout_notes": "Great workout! Hit 8 reps on AMRAP set."
  }'
```

---

## Testing in Swagger UI

1. **Restart your server** to load the new endpoints:
   ```bash
   uvicorn app.main:app --reload
   ```

2. **Go to Swagger UI**: http://localhost:8000/api/v1/docs

3. **Create a program** (if you haven't):
   - Use `POST /api/v1/programs`
   - This generates 16 workouts automatically

4. **List workouts**:
   - Use `GET /api/v1/workouts`
   - Copy a workout ID

5. **View workout details**:
   - Use `GET /api/v1/workouts/{workout_id}`
   - See all prescribed sets with weights and reps

6. **Complete the workout**:
   - Use `POST /api/v1/workouts/{workout_id}/complete`
   - Log all your sets
   - System auto-detects AMRAP and updates rep maxes!

---

## Key Features

✅ **Automatic Set Calculation** - Warmup and working sets calculated from training max
✅ **Week-Specific Progressions** - Correct percentages for each week (5/5/5+, 3/3/3+, 5/3/1+, Deload)
✅ **AMRAP Detection** - Last set on non-deload weeks is AMRAP
✅ **Rep Max Tracking** - Auto-updates PR records from AMRAP performance
✅ **Comprehensive Filtering** - Find workouts by program, date, lift, cycle, week
✅ **Rounding Support** - Weights rounded to user's preference (default: 5 lbs)
✅ **Accessory Integration** - Loads accessories from program template

---

## What's Next?

The workout logging system is complete! Users can now:
- ✅ View upcoming workouts
- ✅ See exactly what to lift (prescribed sets)
- ✅ Log their performance
- ✅ Track rep maxes automatically

**Potential future enhancements:**
- Training max progression after cycle completion
- Generate next cycle automatically
- Workout history and analytics
- Export workout data
- Rest timer integration
- Plate calculator display

---

## Files Created/Modified

### Created:
- `backend/app/schemas/workout.py` - Workout request/response models
- `backend/app/services/workout.py` - Workout business logic
- `backend/app/routers/workouts.py` - Workout API endpoints

### Modified:
- `backend/app/main.py` - Added workout router

---

**Implementation Status: ✅ COMPLETE**

Users can now create programs AND actually use them to track their training!
