# Cycle Progression - Implementation Complete

The cycle progression feature is now complete! Users can now continue their 5/3/1 training indefinitely by completing cycles and automatically progressing their training maxes.

---

## What Was Implemented

### 1. Cycle Completion

**File:** `backend/app/services/program.py` - `complete_cycle()` method

Automatically increases training maxes per Jim Wendler's 5/3/1 methodology:
- **Upper body lifts** (Press, Bench Press): +5 lbs
- **Lower body lifts** (Squat, Deadlift): +10 lbs

What it does:
- ✅ Gets current training maxes for all 4 lifts
- ✅ Creates new TrainingMax records for next cycle with increased values
- ✅ Records progression in TrainingMaxHistory table
- ✅ Returns details of all increases

### 2. Next Cycle Generation

**File:** `backend/app/services/program.py` - `generate_next_cycle()` method

Generates the next 4-week cycle of workouts:
- ✅ Verifies training maxes exist for next cycle
- ✅ Calculates start date (1 week after last workout)
- ✅ Generates 16 new workouts (4 weeks × 4 days)
- ✅ Uses updated training maxes for weight calculations

### 3. API Endpoints

**File:** `backend/app/routers/programs.py`

Two new endpoints for seamless cycle progression:

**`POST /api/v1/programs/{id}/complete-cycle`**
- Increases training maxes
- Returns progression details

**`POST /api/v1/programs/{id}/generate-next-cycle`**
- Creates next 16 workouts
- Uses new training maxes

---

## How It Works

### The 5/3/1 Cycle Progression

**After completing 4 weeks (1 cycle):**

1. **Complete Cycle** → Training maxes increase
   - Press: 100 lbs → 105 lbs (+5)
   - Bench: 200 lbs → 205 lbs (+5)
   - Squat: 250 lbs → 260 lbs (+10)
   - Deadlift: 300 lbs → 310 lbs (+10)

2. **Generate Next Cycle** → New workouts created
   - Cycle 2 workouts scheduled
   - All sets calculated with new training maxes
   - Program continues seamlessly!

### Typical User Flow

```
Week 1-4: Complete Cycle 1 (16 workouts)
  ↓
Call: POST /complete-cycle
  → Training maxes increase
  → TrainingMaxHistory records created
  ↓
Call: POST /generate-next-cycle
  → Cycle 2 generated (16 more workouts)
  ↓
Week 5-8: Complete Cycle 2
  ↓
Repeat indefinitely!
```

---

## API Usage Examples

### 1. Complete Current Cycle

```bash
curl -X POST http://localhost:8000/api/v1/programs/PROGRAM_ID/complete-cycle \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response:**
```json
{
  "cycle_completed": 1,
  "next_cycle": 2,
  "training_max_updates": {
    "press": {
      "old_value": 100,
      "new_value": 105,
      "increase": 5
    },
    "bench_press": {
      "old_value": 200,
      "new_value": 205,
      "increase": 5
    },
    "squat": {
      "old_value": 250,
      "new_value": 260,
      "increase": 10
    },
    "deadlift": {
      "old_value": 300,
      "new_value": 310,
      "increase": 10
    }
  }
}
```

### 2. Generate Next Cycle

```bash
curl -X POST http://localhost:8000/api/v1/programs/PROGRAM_ID/generate-next-cycle \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response:**
```json
{
  "cycle_number": 2,
  "start_date": "2025-02-03",
  "workouts_generated": 16
}
```

### 3. Verify New Workouts

```bash
# List workouts for Cycle 2
curl "http://localhost:8000/api/v1/workouts?program_id=PROGRAM_ID&cycle_number=2" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

You should see 16 new workouts with higher weights!

---

## Testing the Feature

**Restart your server:**
```bash
uvicorn app.main:app --reload
```

**In Swagger UI** (http://localhost:8000/api/v1/docs):

### Step 1: Complete Cycle 1

1. Find your program ID from when you created it
2. Go to `POST /api/v1/programs/{program_id}/complete-cycle`
3. Click "Try it out"
4. Paste your program ID
5. Execute

**Expected Result:**
```json
{
  "cycle_completed": 1,
  "next_cycle": 2,
  "training_max_updates": {
    "press": {"old_value": 100, "new_value": 105, "increase": 5},
    ...
  }
}
```

### Step 2: Generate Cycle 2

1. Go to `POST /api/v1/programs/{program_id}/generate-next-cycle`
2. Click "Try it out"
3. Same program ID
4. Execute

**Expected Result:**
```json
{
  "cycle_number": 2,
  "start_date": "2025-02-03",
  "workouts_generated": 16
}
```

### Step 3: Verify New Workouts

1. Go to `GET /api/v1/workouts`
2. Filter by: `cycle_number=2`
3. Execute

You should see 16 brand new workouts!

### Step 4: Check a Cycle 2 Workout

1. Copy a workout ID from Cycle 2
2. Go to `GET /api/v1/workouts/{workout_id}`
3. Execute

**You should see HIGHER prescribed weights:**
- Week 1, Set 1: 68 lbs (was 65 lbs) → 105 × 65% = 68
- Week 1, Set 2: 79 lbs (was 75 lbs) → 105 × 75% = 79
- Week 1, Set 3: 89 lbs (was 85 lbs) → 105 × 85% = 89

### Step 5: Verify Training Max History

```bash
source venv/bin/activate
python -c "
from app.database import engine
from sqlalchemy import text
from sqlalchemy.orm import sessionmaker

Session = sessionmaker(bind=engine)
db = Session()

result = db.execute(text('''
  SELECT lift_type, old_value, new_value, reason, notes
  FROM training_max_history
  ORDER BY change_date DESC
''')).fetchall()

print('Training Max History:')
for row in result:
    print(f'  {row[0]}: {row[1]} → {row[2]} ({row[3]})')
    print(f'    Notes: {row[4]}')

db.close()
"
```

**Expected Output:**
```
Training Max History:
  deadlift: 300.0 → 310.0 (cycle_progression)
    Notes: Cycle 1 completed, auto-progression
  squat: 250.0 → 260.0 (cycle_progression)
    Notes: Cycle 1 completed, auto-progression
  bench_press: 200.0 → 205.0 (cycle_progression)
    Notes: Cycle 1 completed, auto-progression
  press: 100.0 → 105.0 (cycle_progression)
    Notes: Cycle 1 completed, auto-progression
```

---

## Key Features

✅ **Automatic Progression** - Training maxes increase by correct amounts (5/10 lbs)
✅ **History Tracking** - All progressions recorded in TrainingMaxHistory
✅ **Seamless Workflow** - Two simple API calls to continue program
✅ **Validation** - Can't generate next cycle without completing current cycle
✅ **Proper Scheduling** - Next cycle starts 1 week after last workout
✅ **Accurate Calculations** - New workouts use updated training maxes

---

## Training Max Progression Rules

Per Jim Wendler's 5/3/1 methodology:

| Lift | Increment |
|------|-----------|
| Press (Overhead) | +5 lbs |
| Bench Press | +5 lbs |
| Squat | +10 lbs |
| Deadlift | +10 lbs |

**Why these amounts?**
- Upper body lifts progress slower (smaller muscle groups)
- Lower body lifts can handle bigger jumps (larger muscle groups)
- Conservative progression ensures long-term success

**Example progression over 6 cycles:**

| Cycle | Press | Bench | Squat | Deadlift |
|-------|-------|-------|-------|----------|
| 1 | 100 | 200 | 250 | 300 |
| 2 | 105 | 205 | 260 | 310 |
| 3 | 110 | 210 | 270 | 320 |
| 4 | 115 | 215 | 280 | 330 |
| 5 | 120 | 220 | 290 | 340 |
| 6 | 125 | 225 | 300 | 350 |

In 6 cycles (24 weeks / 6 months):
- Press: +25 lbs
- Bench: +25 lbs
- Squat: +50 lbs
- Deadlift: +50 lbs

---

## What Happens Behind the Scenes

### When you call `/complete-cycle`:

1. **Fetch Current Training Maxes**
   - Gets latest TM for each lift
   - From current cycle

2. **Calculate Increases**
   - Press/Bench: old_value + 5
   - Squat/Deadlift: old_value + 10

3. **Create New TrainingMax Records**
   - One for each lift
   - cycle_number = current + 1
   - reason = "cycle_progression"

4. **Create History Records**
   - Tracks old → new values
   - Notes: "Cycle X completed, auto-progression"

5. **Return Summary**
   - Shows all increases
   - Ready for next cycle

### When you call `/generate-next-cycle`:

1. **Verify Prerequisites**
   - Training maxes exist for next cycle
   - (You must call complete-cycle first!)

2. **Calculate Start Date**
   - Gets last workout date
   - Adds 7 days (1 week rest)

3. **Generate 16 Workouts**
   - 4 weeks × 4 days
   - Uses new training maxes
   - Same accessories as Cycle 1

4. **Return Confirmation**
   - Cycle number
   - Start date
   - Workout count

---

## Error Handling

### "No training maxes found for cycle X"

**Cause:** You tried to generate next cycle before completing current cycle

**Solution:** Call `/complete-cycle` first!

### "No existing workouts found"

**Cause:** Trying to generate next cycle on a brand new program

**Solution:** This should never happen - workouts are created with program

### "Program not found"

**Cause:** Invalid program ID or not your program

**Solution:** Verify program ID and authentication

---

## Files Created/Modified

### Modified:
- `backend/app/services/program.py` - Added `complete_cycle()` and `generate_next_cycle()` methods
- `backend/app/routers/programs.py` - Added 2 new endpoints

---

## Summary

**Before:** Users could create programs and log workouts, but couldn't continue past Cycle 1

**After:** Users can now:
1. Complete Cycle 1 (4 weeks)
2. Increase training maxes automatically
3. Generate Cycle 2 with higher weights
4. Continue indefinitely!

The app is now **fully functional** for long-term 5/3/1 training! 🎉

---

**Implementation Status: ✅ COMPLETE**

Users can now run the 5/3/1 program for as many cycles as they want, with automatic progression built in!
