# 5/3/1 Strength Training App - Comprehensive Specification

## 1. Overview

A mobile fitness application for managing the 5/3/1 strength training program created by Jim Wendler. The app helps athletes track their training cycles, log workouts, manage progression, and visualize their strength gains over time.

### Core Value Proposition
- Structured implementation of the proven 5/3/1 methodology
- Intelligent workout tracking with offline support
- Automated progression and training max recommendations
- Personal records tracking across different rep ranges

---

## 2. Technology Stack

### Frontend
- **Framework**: Flutter (cross-platform mobile)
- **State Management**: Riverpod
- **Local Database**: sqflite (for offline support)
- **Key Features**: Offline-first architecture with background sync

### Backend
- **Framework**: FastAPI (Python)
- **Database**: SQLite
- **ORM**: SQLAlchemy
- **Migrations**: Alembic
- **Authentication**: JWT with refresh tokens
- **Containerization**: Docker (single container)

### Testing
- **Backend**: pytest with unit and integration tests for API endpoints
- **Frontend**: Widget tests for critical UI + unit tests for business logic (Riverpod providers)

---

## 3. Architecture Overview

### System Design
```
┌─────────────────┐
│  Flutter App    │
│  (Offline DB)   │ <──── Background Sync ────> ┌──────────────┐
│  sqflite        │                              │ FastAPI      │
└─────────────────┘                              │ Backend      │
                                                 │              │
         ┌────────── JWT Auth ──────────────────┤ SQLite DB    │
         │                                       └──────────────┘
         │
         └──> Access Token (15min) + Refresh Token (7 days)
```

### API Architecture
- RESTful resource-based endpoints
- Standard HTTP methods (GET, POST, PUT, DELETE)
- JWT bearer token authentication
- JSON request/response format

### Data Sync Strategy
- **Offline-first**: All workout logging works offline
- **Background sync**: Automatic sync when connection available
- **Conflict resolution**: Server timestamp wins (last-write-wins)
- **Local cache**: sqflite stores programs, workouts, and user data

---

## 4. User Authentication & Security

### Authentication Flow
1. **Registration**
   - First name
   - Last name
   - Email (unique, used for login)
   - Password (minimum 8 characters, requires uppercase, lowercase, and number)

2. **Login**
   - Email and password
   - Returns JWT access token (15 min expiry) + refresh token (7 day expiry)
   - Refresh token stored securely in Flutter secure storage

3. **Token Refresh**
   - Automatic refresh when access token expires
   - Endpoint: `POST /auth/refresh`

4. **Password Reset**
   - Email-based reset flow
   - Requires SMTP configuration for sending reset links
   - Reset link expires after 1 hour

### Security Requirements
- Passwords hashed using bcrypt
- HTTPS only for API communication
- JWT tokens signed with secret key
- Refresh tokens invalidated on logout

---

## 5. Data Model

### Core Entities

#### User
```python
- id: UUID (primary key)
- first_name: String
- last_name: String
- email: String (unique)
- password_hash: String
- weight_unit_preference: Enum('lbs', 'kg') - default 'lbs'
- rounding_increment: Float - default 5.0 (lbs) or 2.5 (kg)
- missed_workout_preference: Enum('skip', 'reschedule', 'ask') - default 'ask'
- created_at: DateTime
- updated_at: DateTime
```

#### Program
```python
- id: UUID (primary key)
- user_id: UUID (foreign key)
- name: String (e.g., "Winter 2025 - 4 Day")
- template_type: String (e.g., "4_day", "3_day", "2_day") - flexible for future
- start_date: Date
- end_date: Date (nullable) - if set by user
- target_cycles: Integer (nullable) - alternative to end_date
- training_days: JSON - e.g., ["monday", "tuesday", "thursday", "saturday"]
- status: Enum('active', 'completed', 'paused')
- created_at: DateTime
```

#### TrainingMax
```python
- id: UUID (primary key)
- program_id: UUID (foreign key)
- lift_type: Enum('squat', 'deadlift', 'bench_press', 'press')
- value: Float (weight in user's preferred unit)
- effective_date: Date - when this TM became active
- cycle_number: Integer - which cycle this TM applies to
- reason: Enum('initial', 'cycle_completion', 'deload', 'failed_reps', 'manual')
- notes: Text (nullable)
- created_at: DateTime
```

#### TrainingMaxHistory
(Tracks all changes for analytics)
```python
- id: UUID (primary key)
- program_id: UUID (foreign key)
- lift_type: Enum('squat', 'deadlift', 'bench_press', 'press')
- old_value: Float (nullable for first entry)
- new_value: Float
- change_date: DateTime
- reason: Enum('initial', 'cycle_completion', 'deload', 'failed_reps', 'manual')
- notes: Text (nullable)
```

#### ProgramTemplate
(Stores accessory exercises per day)
```python
- id: UUID (primary key)
- program_id: UUID (foreign key)
- day_number: Integer (1-4 for 4-day program)
- main_lift: Enum('squat', 'deadlift', 'bench_press', 'press')
- accessories: JSON - array of {exercise_id, sets, reps, weight_type}
  Example: [
    {"exercise_id": "uuid", "sets": 5, "reps": 12, "weight_type": "percentage"},
    {"exercise_id": "uuid", "sets": 5, "reps": 12, "weight_type": "fixed"}
  ]
```

#### Exercise
(Both predefined from book and custom)
```python
- id: UUID (primary key)
- name: String
- category: Enum('push', 'pull', 'legs', 'core')
- is_predefined: Boolean (from book chapter 16)
- user_id: UUID (nullable - null for predefined, set for custom)
- description: Text (nullable)
- created_at: DateTime
```

#### Workout
```python
- id: UUID (primary key)
- program_id: UUID (foreign key)
- scheduled_date: Date
- completed_date: DateTime (nullable - null until completed)
- cycle_number: Integer (1, 2, 3, ...)
- week_number: Integer (1-4)
- week_type: Enum('week_1_5s', 'week_2_3s', 'week_3_531', 'week_4_deload')
- main_lift: Enum('squat', 'deadlift', 'bench_press', 'press')
- status: Enum('scheduled', 'in_progress', 'completed', 'skipped')
- notes: Text (nullable) - workout-level notes
- created_at: DateTime
```

#### WorkoutSet
(Normalized storage for logged sets)
```python
- id: UUID (primary key)
- workout_id: UUID (foreign key)
- exercise_id: UUID (foreign key) - references Exercise
- set_type: Enum('warmup', 'working', 'accessory', 'amrap')
- set_number: Integer
- prescribed_reps: Integer (nullable)
- actual_reps: Integer
- prescribed_weight: Float (nullable)
- actual_weight: Float
- weight_unit: Enum('lbs', 'kg')
- percentage_of_tm: Float (nullable - for main lifts)
- is_target_met: Boolean - true if actual_reps >= prescribed_reps
- notes: Text (nullable) - per-exercise notes
- created_at: DateTime
```

#### WarmupTemplate
(Custom warmup protocols)
```python
- id: UUID (primary key)
- user_id: UUID (foreign key)
- name: String (e.g., "My Squat Warmup")
- lift_type: Enum('squat', 'deadlift', 'bench_press', 'press')
- sets: JSON - array of {weight_type, value, reps}
  Example: [
    {"weight_type": "bar", "value": null, "reps": 10},
    {"weight_type": "fixed", "value": 135, "reps": 5},
    {"weight_type": "percentage", "value": 50, "reps": 5},
    {"weight_type": "percentage", "value": 70, "reps": 2}
  ]
- is_default: Boolean - if true, auto-applied to this lift
```

#### RepMax
(Personal records at different rep ranges)
```python
- id: UUID (primary key)
- user_id: UUID (foreign key)
- lift_type: Enum('squat', 'deadlift', 'bench_press', 'press')
- reps: Integer (1-12)
- weight: Float
- weight_unit: Enum('lbs', 'kg')
- calculated_1rm: Float - using Epley formula
- achieved_date: Date
- workout_set_id: UUID (foreign key) - reference to the AMRAP set
- created_at: DateTime
```

---

## 6. Core Features

### 6.1 User Registration & Login

**Registration Flow**
1. User enters first name, last name, email, password
2. Validation:
   - Email format valid and unique
   - Password meets requirements (8+ chars, upper, lower, number)
   - First name and last name are not empty
3. Create user account with default preferences (lbs, 5 lb rounding)
4. Return JWT tokens

**Login Flow**
1. User enters email and password
2. Verify credentials
3. Return access token (15min) + refresh token (7 days)
4. Store refresh token securely on device

**Password Reset Flow**
1. User requests reset (enters email)
2. System sends reset link to email (1 hour expiry)
3. User clicks link, sets new password
4. All existing refresh tokens invalidated

---

### 6.2 Program Setup

**Initial Program Creation**
1. User selects program type (currently only "4-day" available)
2. User selects which days to train:
   - Display week calendar
   - User taps 4 days (e.g., Mon, Tue, Thu, Sat)
   - System assigns lifts to days in standard order:
     - Day 1: Press
     - Day 2: Deadlift
     - Day 3: Bench Press
     - Day 4: Squat

3. Set Training Maxes for each lift:
   - Option A: Enter 1RM directly
   - Option B: Enter rep max (weight + reps), system calculates 1RM using Epley formula:
     ```
     1RM = weight × (1 + reps/30)
     ```
   - Display calculated 1RM for confirmation
   - Training Max = 90% of 1RM (Jim Wendler's recommendation)

4. Select Accessory Exercises (per day):
   - View predefined exercises from book (Chapter 16)
   - Or add custom exercises
   - Select 1-3 accessories per training day
   - Set sets/reps (default: 5 sets × 12 reps, user adjustable)

5. Set Program Duration:
   - Option A: End date
   - Option B: Number of cycles (e.g., 4 cycles = 16 weeks)
   - Option C: Open-ended (no end date)

6. Generate Calendar:
   - Create 4-week schedule based on training days
   - Each day assigned to appropriate lift and week type
   - Schedule accessories for each day

---

### 6.3 Calendar View

**Week View** (Default)
- Current week displayed (Sun-Sat or Mon-Sun based on locale)
- Each training day shows:
  - Main lift name (e.g., "Squat Day")
  - Cycle and week number (e.g., "Cycle 2, Week 3")
  - Week type indicator (5s, 3s, 5/3/1, Deload)
  - Status badge (Scheduled, Completed, Skipped)
- Color coding:
  - Completed: Green
  - Today: Highlighted
  - Future: Default
  - Skipped: Gray

**Month View**
- Calendar grid showing full month
- Training days marked with lift icon
- Tap day to see details
- Completed days have checkmark

**Workout Detail View** (tap on scheduled workout)
- Display workout summary:
  - Main lift with training max
  - Week type (e.g., "Week 3: 5/3/1")
  - Prescribed sets/reps with percentages:
    ```
    Set 1: 75% × 5 (225 lbs) - 45+25+5 per side
    Set 2: 85% × 3 (255 lbs) - 45+35+5+2.5 per side
    Set 3: 95% × 1+ (285 lbs) - 45+45+5+2.5 per side
    ```
  - Warmup sets with weights
  - Accessory exercises with sets/reps
- Actions:
  - "Start Workout" button → Enter workout mode
  - "View History" → See previous performances of this lift
  - "Skip Workout" → Mark as skipped (triggers missed workout handling)

---

### 6.4 Workout Execution

**Starting Workout**
1. User taps "Start Workout" from calendar
2. App enters workout mode (keeps screen awake)
3. Display sequential progression through sets

**Warmup Sets**
- Display each warmup set with auto-calculated weight
- Default protocol (Jim Wendler):
  - Empty bar × 5
  - 40% × 5
  - 50% × 5
  - 60% × 3
- Show plate calculator for each warmup
- User checks off each warmup (or enters actual reps/weight if tracked)
- Rest timer starts automatically (default: 90 seconds)

**Working Sets (Main Lift)**
- Display set with prescribed reps and weight
- Calculate weight based on week and set:
  - **Week 1 (5s)**: 65%×5, 75%×5, 85%×5+
  - **Week 2 (3s)**: 70%×3, 80%×3, 90%×3+
  - **Week 3 (5/3/1)**: 75%×5, 85%×3, 95%×1+
  - **Week 4 (Deload)**: 40%×5, 50%×5, 60%×5
- Show plate calculator (e.g., "45 + 25 + 10 per side")
- User enters actual reps completed
- For AMRAP sets (marked with +):
  - Prompt: "How many reps did you complete?"
  - Store as AMRAP set type
  - Calculate if new rep max achieved
- Rest timer starts (default: 3 minutes for main lifts)

**Failed Rep Detection**
- If user enters fewer reps than prescribed on a working set:
  - Flag set as target not met
  - Track as failed rep occurrence
- After workout:
  - **Single lift failed**: Suggest reviewing training max for that lift
  - **Multiple lifts failed**: Recommend scheduling a deload week, then adjusting training maxes

**Accessory Exercises**
- Display each accessory with sets/reps (default: 5×12)
- User logs each set (weight and reps)
- Rest timer (default: 60-90 seconds)
- Can add notes per exercise (e.g., "Grip failing on rows")

**Workout Completion**
1. All sets logged
2. Optional: Add workout-level notes
3. Tap "Complete Workout"
4. System:
   - Marks workout as completed with timestamp
   - Calculates any new rep maxes from AMRAP sets
   - Updates local database
   - Queues sync to backend when online

---

### 6.5 Rest Timer

**Default Rest Periods**
- Warmup sets: 60 seconds
- Main lift working sets: 2-3 minutes (configurable)
- Accessory exercises: 60-90 seconds (configurable)

**Timer Behavior**
- Auto-starts when set is logged
- Display countdown prominently
- Audio/vibration alert when complete
- User can:
  - Skip timer
  - Add 30 seconds
  - Reset timer
  - Customize default times in settings

---

### 6.6 Missed Workout Handling

**User Preference Setting** (in profile)
- Option 1: Always skip missed workouts
- Option 2: Always reschedule to next available day
- Option 3: Ask me each time (default)

**Workflow When Workout Missed**
1. If today's workout not completed and day has passed:
   - If preference = "skip": Mark as skipped, continue schedule
   - If preference = "reschedule":
     - Push workout to next available training day
     - Shift all subsequent workouts forward by 1 training day as needed. If the next day has nothing scheduled, the workout can simply be rescheduled. If the next day has something scheduled, it will also need to be pushed.
   - If preference = "ask":
     - Show dialog: "You missed [Lift] on [Date]. What would you like to do?"
     - Options: "Skip it" or "Reschedule"

---

### 6.7 Cycle Completion & Training Max Updates

**After Week 4 (Deload) Completion**
1. Display "Cycle Complete!" message
2. Show current training maxes
3. Suggest new training maxes:
   - Lower body (Squat, Deadlift): +10 lbs
   - Upper body (Bench Press, Press): +5 lbs
4. Allow user to adjust recommendations
5. User confirms new training maxes
6. System:
   - Creates new TrainingMax records with cycle_number incremented
   - Logs change in TrainingMaxHistory
   - Generates next cycle's workouts
   - Updates calendar

**Manual Training Max Adjustment**
- Available in settings at any time
- User can adjust TM for any lift
- System prompts for reason (optional)
- Recalculates all future scheduled workouts with new TM
- Logs change in history

---

### 6.8 Progress Tracking & Analytics

**Training Max History Chart**
- Line graph per lift showing TM progression over time
- X-axis: Date or Cycle number
- Y-axis: Weight
- Display all 4 lifts on same chart (different colors) or separate charts
- Tap data point to see details (date, value, reason for change)

**Workout History List**
- Chronological list of completed workouts
- Each entry shows:
  - Date completed
  - Lift name and cycle/week
  - Key stats (e.g., "AMRAP: 10 reps @ 225 lbs")
  - Notes (if any)
- Filter by:
  - Lift type
  - Date range
  - Cycle number
- Search functionality

**Rep Max Records (Personal Records)**
- Dedicated screen per lift (Squat, Deadlift, Bench, Press)
- Table displaying rep maxes for 1-12 reps:
  ```
  Rep Max Records - Squat

  Reps | Weight  | Calculated 1RM | Date
  -----|---------|----------------|------------
  1    | 315 lbs | 315 lbs        | 12/15/2024
  2    | 305 lbs | 325 lbs        | 12/01/2024
  3    | 295 lbs | 325 lbs        | 11/20/2024
  5    | 275 lbs | 321 lbs        | 11/15/2024
  8    | 245 lbs | 310 lbs        | 10/30/2024
  10   | 225 lbs | 300 lbs        | 10/15/2024
  ```
- Auto-populated from AMRAP sets
- Calculated 1RM using Epley formula: `weight × (1 + reps/30)`
- Highlight when new PR achieved during workout

---

### 6.9 Settings & Preferences

**User Profile**
- First name and last name (editable)
- Email (display only, used for login)
- Change password

**Units & Rounding**
- Weight unit preference: lbs or kg
- Rounding increment:
  - Default: 5 lbs or 2.5 kg
  - User can set: 1, 2.5, 5, 10 lbs or 1.25, 2.5, 5 kg
- Note: Changing rounding recalculates all future workout weights

**Workout Preferences**
- Missed workout behavior: Skip / Reschedule / Ask
- Rest timer defaults (warmup, working sets, accessories)
- Screen stay-awake during workouts
- Sound/vibration for timer

**Custom Warmup Templates**
- Create named warmup templates
- Assign to specific lifts
- Define sets with:
  - Weight type: bar / fixed weight / percentage of TM
  - Reps
- Set as default for a lift

**Data Management**
- Export workout history to CSV
- View data sync status
- Force sync with backend

---

### 6.10 Data Export

**CSV Export Format**
User can export complete workout history as CSV file.

**Columns:**
```
workout_date, lift, cycle, week, week_type, set_type, set_number,
prescribed_reps, actual_reps, prescribed_weight, actual_weight,
weight_unit, training_max, notes
```

**Example:**
```csv
2024-12-15,Squat,2,3,week_3_531,warmup,1,5,5,45,45,lbs,300,
2024-12-15,Squat,2,3,week_3_531,working,1,5,5,225,225,lbs,300,
2024-12-15,Squat,2,3,week_3_531,working,2,3,3,255,255,lbs,300,
2024-12-15,Squat,2,3,week_3_531,amrap,3,1,8,285,285,lbs,300,"Felt strong!"
```

---

## 7. UI/UX Specifications

### Navigation Structure
```
Main Navigation (Bottom Nav Bar)
├── Calendar (default screen after login)
├── Progress (charts + history)
├── Records (rep maxes)
└── Settings
```

### Screen Specifications

#### 1. Login/Registration Screen
- Clean, minimal design
- Toggle between Login and Register
- **Login fields**: Email, Password
- **Registration fields**: First Name, Last Name, Email, Password
- "Forgot Password?" link
- Remember me checkbox (stores refresh token)

#### 2. Calendar Screen
- Week/Month toggle at top
- Current cycle/week indicator
- Training day cards showing:
  - Lift icon
  - "Cycle X, Week Y"
  - Status badge
  - Tap to expand details
- "Start Workout" button (primary action)

#### 3. Workout Execution Screen
- Progress indicator (Set X of Y)
- Large, clear display of current set:
  - Weight with plate calculator
  - Prescribed reps
  - Rest timer (circular progress)
- Number pad for entering actual reps
- "Next Set" / "Complete Workout" buttons
- Notes icon (floating action button)

#### 4. Progress Screen
- Tabs: Charts | History
- **Charts Tab:**
  - Training Max progression (line chart)
  - Lift selector dropdown
  - Date range selector
- **History Tab:**
  - Filterable list of workouts
  - Search bar
  - Each workout card expandable

#### 5. Records Screen
- Lift selector (4 tabs or dropdown)
- Table of rep maxes (1-12 reps)
- New PR celebrations (badge/animation)

#### 6. Settings Screen
- Grouped sections:
  - Account
  - Units & Rounding
  - Workout Preferences
  - Custom Warmups
  - Data Management
  - About/Help

### Design Guidelines
- **Color Scheme**:
  - Primary: Strength-themed (deep blue or dark gray)
  - Accent: Motivational (orange or red)
  - Success: Green (completed workouts)
  - Warning: Yellow (missed targets)
- **Typography**:
  - Large, readable fonts for workout screen
  - Clear hierarchy (headings vs. body)
- **Interactions**:
  - Swipe gestures for navigation
  - Haptic feedback on key actions
  - Smooth transitions between screens
- **Accessibility**:
  - High contrast mode support
  - Screen reader compatibility
  - Adjustable text size

---

## 8. Business Logic & Calculations

### 8.1 1RM Calculation (Epley Formula)
```python
def calculate_1rm(weight: float, reps: int) -> float:
    """
    Calculate one-rep max using Epley formula.
    Formula: 1RM = weight × (1 + reps/30)
    """
    if reps == 1:
        return weight
    return weight * (1 + reps / 30)
```

### 8.2 Training Max Calculation
```python
def calculate_training_max(one_rm: float) -> float:
    """
    Calculate training max as 90% of 1RM per Jim Wendler.
    """
    return one_rm * 0.90
```

### 8.3 Working Weight Calculation
```python
def calculate_working_weight(
    training_max: float,
    week: int,
    set_number: int,
    rounding_increment: float = 5.0
) -> float:
    """
    Calculate working weight for a given week and set.

    Week 1 (5s): 65%, 75%, 85%
    Week 2 (3s): 70%, 80%, 90%
    Week 3 (5/3/1): 75%, 85%, 95%
    Week 4 (Deload): 40%, 50%, 60%
    """
    percentages = {
        1: [0.65, 0.75, 0.85],  # Week 1
        2: [0.70, 0.80, 0.90],  # Week 2
        3: [0.75, 0.85, 0.95],  # Week 3
        4: [0.40, 0.50, 0.60],  # Week 4 (deload)
    }

    percentage = percentages[week][set_number - 1]
    raw_weight = training_max * percentage

    # Round to nearest increment
    return round(raw_weight / rounding_increment) * rounding_increment
```

### 8.4 Warmup Weight Calculation
```python
def calculate_warmup_weights(
    training_max: float,
    rounding_increment: float = 5.0,
    bar_weight: float = 45.0
) -> list[dict]:
    """
    Calculate standard 5/3/1 warmup progression.
    """
    warmups = [
        {"percentage": 0.0, "reps": 5},    # Empty bar
        {"percentage": 0.40, "reps": 5},   # 40%
        {"percentage": 0.50, "reps": 5},   # 50%
        {"percentage": 0.60, "reps": 3},   # 60%
    ]

    result = []
    for warmup in warmups:
        if warmup["percentage"] == 0.0:
            weight = bar_weight
        else:
            raw_weight = training_max * warmup["percentage"]
            weight = round(raw_weight / rounding_increment) * rounding_increment

        result.append({
            "weight": weight,
            "reps": warmup["reps"],
            "percentage": warmup["percentage"]
        })

    return result
```

### 8.5 Plate Calculator
```python
def calculate_plates(
    target_weight: float,
    bar_weight: float = 45.0,
    available_plates: list[float] = [45, 35, 25, 10, 5, 2.5]
) -> list[float]:
    """
    Calculate which plates to load per side of bar.
    Uses greedy algorithm to minimize number of plates.
    """
    weight_per_side = (target_weight - bar_weight) / 2

    if weight_per_side <= 0:
        return []

    plates = []
    remaining = weight_per_side

    for plate in sorted(available_plates, reverse=True):
        while remaining >= plate:
            plates.append(plate)
            remaining -= plate

    return plates

def format_plate_display(plates: list[float]) -> str:
    """
    Format plates for display: "45 + 25 + 10 per side"
    """
    if not plates:
        return "Bar only"

    plate_str = " + ".join(str(int(p) if p.is_integer() else p) for p in plates)
    return f"{plate_str} per side"
```

### 8.6 Rep Max Detection
```python
def check_and_update_rep_max(
    user_id: str,
    lift_type: str,
    reps: int,
    weight: float,
    weight_unit: str,
    workout_set_id: str,
    achieved_date: date
) -> tuple[bool, dict]:
    """
    Check if AMRAP set resulted in new rep max.
    Returns (is_new_pr, rep_max_record)
    """
    if reps < 1 or reps > 12:
        return False, {}

    calculated_1rm = calculate_1rm(weight, reps)

    # Query existing rep max for this rep count
    existing = get_rep_max(user_id, lift_type, reps)

    is_new_pr = False
    if not existing or calculated_1rm > existing.calculated_1rm:
        is_new_pr = True
        rep_max = create_rep_max(
            user_id=user_id,
            lift_type=lift_type,
            reps=reps,
            weight=weight,
            weight_unit=weight_unit,
            calculated_1rm=calculated_1rm,
            achieved_date=achieved_date,
            workout_set_id=workout_set_id
        )
        return is_new_pr, rep_max

    return False, {}
```

### 8.7 Failed Rep Recommendation Logic
```python
def analyze_failed_reps(program_id: str, cycle: int) -> dict:
    """
    Analyze failed reps in current cycle and provide recommendations.
    """
    failed_sets = get_failed_sets_in_cycle(program_id, cycle)

    if not failed_sets:
        return {"recommendation": "none"}

    # Group by lift
    failed_by_lift = {}
    for set in failed_sets:
        lift = set.workout.main_lift
        if lift not in failed_by_lift:
            failed_by_lift[lift] = []
        failed_by_lift[lift].append(set)

    if len(failed_by_lift) == 1:
        # Single lift failed
        lift = list(failed_by_lift.keys())[0]
        return {
            "recommendation": "adjust_training_max",
            "lifts": [lift],
            "message": f"Consider reducing training max for {lift} by 10%"
        }
    else:
        # Multiple lifts failed
        return {
            "recommendation": "deload_then_adjust",
            "lifts": list(failed_by_lift.keys()),
            "message": "Consider taking a deload week, then reducing training maxes by 10%"
        }
```

### 8.8 Weight Unit Conversion
```python
def convert_weight(weight: float, from_unit: str, to_unit: str) -> float:
    """
    Convert between lbs and kg.
    """
    if from_unit == to_unit:
        return weight

    if from_unit == "lbs" and to_unit == "kg":
        return weight * 0.453592

    if from_unit == "kg" and to_unit == "lbs":
        return weight / 0.453592

    raise ValueError(f"Invalid units: {from_unit} to {to_unit}")
```

---

## 9. API Endpoints

### Authentication Endpoints

#### POST /auth/register
```json
Request:
{
  "first_name": "string",
  "last_name": "string",
  "email": "string",
  "password": "string"
}

Response (201):
{
  "user_id": "uuid",
  "first_name": "string",
  "last_name": "string",
  "email": "string",
  "access_token": "jwt_string",
  "refresh_token": "jwt_string",
  "token_type": "bearer"
}
```

#### POST /auth/login
```json
Request:
{
  "email": "string",
  "password": "string"
}

Response (200):
{
  "user_id": "uuid",
  "first_name": "string",
  "last_name": "string",
  "email": "string",
  "access_token": "jwt_string",
  "refresh_token": "jwt_string",
  "token_type": "bearer"
}
```

#### POST /auth/refresh
```json
Request:
{
  "refresh_token": "jwt_string"
}

Response (200):
{
  "access_token": "jwt_string",
  "token_type": "bearer"
}
```

#### POST /auth/request-password-reset
```json
Request:
{
  "email": "string"
}

Response (200):
{
  "message": "Password reset email sent"
}
```

#### POST /auth/reset-password
```json
Request:
{
  "reset_token": "string",
  "new_password": "string"
}

Response (200):
{
  "message": "Password reset successful"
}
```

---

### User Endpoints

#### GET /users/me
```json
Response (200):
{
  "id": "uuid",
  "first_name": "string",
  "last_name": "string",
  "email": "string",
  "weight_unit_preference": "lbs",
  "rounding_increment": 5.0,
  "missed_workout_preference": "ask",
  "created_at": "datetime"
}
```

#### PUT /users/me
```json
Request:
{
  "first_name": "string (optional)",
  "last_name": "string (optional)",
  "weight_unit_preference": "lbs|kg (optional)",
  "rounding_increment": "float (optional)",
  "missed_workout_preference": "skip|reschedule|ask (optional)"
}

Response (200):
{
  "id": "uuid",
  "first_name": "string",
  "last_name": "string",
  "email": "string",
  ...updated fields
}
```

---

### Program Endpoints

#### GET /programs
```json
Response (200):
{
  "programs": [
    {
      "id": "uuid",
      "name": "string",
      "template_type": "4_day",
      "start_date": "date",
      "end_date": "date (nullable)",
      "status": "active",
      "current_cycle": 2,
      "training_days": ["monday", "wednesday", "friday", "saturday"]
    }
  ]
}
```

#### POST /programs
```json
Request:
{
  "name": "string",
  "template_type": "4_day",
  "start_date": "date",
  "end_date": "date (optional)",
  "target_cycles": "int (optional)",
  "training_days": ["monday", "tuesday", "thursday", "saturday"],
  "training_maxes": {
    "squat": 300.0,
    "deadlift": 350.0,
    "bench_press": 225.0,
    "press": 150.0
  },
  "accessories": {
    "1": [  // Day 1 accessories
      {"exercise_id": "uuid", "sets": 5, "reps": 12},
      {"exercise_id": "uuid", "sets": 5, "reps": 12}
    ],
    "2": [...],
    "3": [...],
    "4": [...]
  }
}

Response (201):
{
  "id": "uuid",
  "name": "string",
  ...all program fields,
  "workouts_generated": 16  // 4 weeks initially
}
```

#### GET /programs/{program_id}
```json
Response (200):
{
  "id": "uuid",
  "name": "string",
  "template_type": "4_day",
  "start_date": "date",
  "status": "active",
  "current_cycle": 2,
  "current_week": 3,
  "training_maxes": {
    "squat": {"value": 300.0, "effective_date": "date"},
    "deadlift": {"value": 350.0, "effective_date": "date"},
    ...
  },
  "accessories": {...}
}
```

#### PUT /programs/{program_id}
```json
Request:
{
  "name": "string (optional)",
  "status": "active|completed|paused (optional)",
  "end_date": "date (optional)"
}

Response (200):
{
  ...updated program
}
```

---

### Training Max Endpoints

#### GET /programs/{program_id}/training-maxes
```json
Response (200):
{
  "training_maxes": {
    "squat": {
      "current": 300.0,
      "effective_date": "date",
      "cycle": 3
    },
    "deadlift": {...},
    "bench_press": {...},
    "press": {...}
  }
}
```

#### POST /programs/{program_id}/training-maxes
```json
Request:
{
  "lift_type": "squat",
  "value": 310.0,
  "reason": "cycle_completion|deload|failed_reps|manual",
  "notes": "string (optional)"
}

Response (201):
{
  "id": "uuid",
  "lift_type": "squat",
  "value": 310.0,
  "effective_date": "date",
  "cycle_number": 4,
  "reason": "cycle_completion"
}
```

#### GET /programs/{program_id}/training-max-history
```json
Response (200):
{
  "history": [
    {
      "id": "uuid",
      "lift_type": "squat",
      "old_value": 300.0,
      "new_value": 310.0,
      "change_date": "datetime",
      "reason": "cycle_completion",
      "notes": "string (nullable)"
    },
    ...
  ]
}
```

---

### Workout Endpoints

#### GET /programs/{program_id}/workouts
```json
Query params: ?start_date=2024-01-01&end_date=2024-12-31&status=scheduled,completed

Response (200):
{
  "workouts": [
    {
      "id": "uuid",
      "scheduled_date": "date",
      "completed_date": "datetime (nullable)",
      "cycle_number": 2,
      "week_number": 3,
      "week_type": "week_3_531",
      "main_lift": "squat",
      "status": "completed",
      "notes": "string (nullable)"
    },
    ...
  ]
}
```

#### GET /workouts/{workout_id}
```json
Response (200):
{
  "id": "uuid",
  "scheduled_date": "date",
  "cycle_number": 2,
  "week_number": 3,
  "week_type": "week_3_531",
  "main_lift": "squat",
  "training_max": 300.0,
  "status": "scheduled",
  "working_sets": [
    {
      "set_number": 1,
      "percentage": 75,
      "prescribed_weight": 225.0,
      "prescribed_reps": 5,
      "is_amrap": false
    },
    {
      "set_number": 2,
      "percentage": 85,
      "prescribed_weight": 255.0,
      "prescribed_reps": 3,
      "is_amrap": false
    },
    {
      "set_number": 3,
      "percentage": 95,
      "prescribed_weight": 285.0,
      "prescribed_reps": 1,
      "is_amrap": true
    }
  ],
  "warmup_sets": [
    {"weight": 45, "reps": 5},
    {"weight": 120, "reps": 5},
    {"weight": 150, "reps": 5},
    {"weight": 180, "reps": 3}
  ],
  "accessories": [
    {
      "exercise_id": "uuid",
      "exercise_name": "Leg Press",
      "sets": 5,
      "reps": 12
    }
  ]
}
```

#### POST /workouts/{workout_id}/start
```json
Request: {}

Response (200):
{
  "id": "uuid",
  "status": "in_progress",
  "started_at": "datetime"
}
```

#### POST /workouts/{workout_id}/complete
```json
Request:
{
  "notes": "string (optional)",
  "sets": [
    {
      "exercise_id": "uuid",
      "set_type": "warmup|working|accessory|amrap",
      "set_number": 1,
      "prescribed_reps": 5,
      "actual_reps": 5,
      "prescribed_weight": 225.0,
      "actual_weight": 225.0,
      "notes": "string (optional)"
    },
    ...
  ]
}

Response (200):
{
  "id": "uuid",
  "status": "completed",
  "completed_date": "datetime",
  "new_rep_maxes": [
    {
      "lift_type": "squat",
      "reps": 8,
      "weight": 285.0,
      "calculated_1rm": 357.0,
      "is_new_pr": true
    }
  ],
  "failed_reps_analysis": {
    "recommendation": "none|adjust_training_max|deload_then_adjust",
    "lifts": [],
    "message": "string"
  }
}
```

#### POST /workouts/{workout_id}/skip
```json
Request: {}

Response (200):
{
  "id": "uuid",
  "status": "skipped"
}
```

---

### Exercise Endpoints

#### GET /exercises
```json
Query params: ?category=push&is_predefined=true

Response (200):
{
  "exercises": [
    {
      "id": "uuid",
      "name": "Dumbbell Bench Press",
      "category": "push",
      "is_predefined": true,
      "description": "string (nullable)"
    },
    ...
  ]
}
```

#### POST /exercises
```json
Request:
{
  "name": "string",
  "category": "push|pull|legs|core",
  "description": "string (optional)"
}

Response (201):
{
  "id": "uuid",
  "name": "string",
  "category": "push",
  "is_predefined": false,
  "user_id": "uuid"
}
```

---

### Warmup Template Endpoints

#### GET /warmup-templates
```json
Response (200):
{
  "templates": [
    {
      "id": "uuid",
      "name": "My Squat Warmup",
      "lift_type": "squat",
      "is_default": true,
      "sets": [
        {"weight_type": "bar", "value": null, "reps": 10},
        {"weight_type": "fixed", "value": 135, "reps": 5},
        {"weight_type": "percentage", "value": 50, "reps": 5},
        {"weight_type": "percentage", "value": 70, "reps": 2}
      ]
    }
  ]
}
```

#### POST /warmup-templates
```json
Request:
{
  "name": "string",
  "lift_type": "squat|deadlift|bench_press|press",
  "is_default": false,
  "sets": [
    {"weight_type": "bar|fixed|percentage", "value": "float (nullable)", "reps": "int"}
  ]
}

Response (201):
{
  "id": "uuid",
  ...template fields
}
```

---

### Rep Max Endpoints

#### GET /rep-maxes
```json
Query params: ?lift_type=squat

Response (200):
{
  "rep_maxes": {
    "squat": {
      "1": {"weight": 315, "calculated_1rm": 315, "date": "2024-12-15"},
      "2": {"weight": 305, "calculated_1rm": 325, "date": "2024-12-01"},
      "3": {"weight": 295, "calculated_1rm": 325, "date": "2024-11-20"},
      ...
      "12": {"weight": 225, "calculated_1rm": 315, "date": "2024-10-01"}
    }
  }
}
```

---

### Analytics Endpoints

#### GET /programs/{program_id}/analytics/training-max-progression
```json
Response (200):
{
  "data": {
    "squat": [
      {"date": "2024-01-01", "value": 275.0, "cycle": 1},
      {"date": "2024-01-29", "value": 285.0, "cycle": 2},
      {"date": "2024-02-26", "value": 295.0, "cycle": 3}
    ],
    "deadlift": [...],
    ...
  }
}
```

#### GET /programs/{program_id}/analytics/workout-history
```json
Query params: ?lift_type=squat&limit=20&offset=0

Response (200):
{
  "workouts": [
    {
      "id": "uuid",
      "date": "date",
      "lift": "squat",
      "cycle": 3,
      "week": 2,
      "week_type": "week_2_3s",
      "key_stats": {
        "amrap_reps": 8,
        "amrap_weight": 270.0,
        "calculated_1rm": 342.0
      },
      "notes": "string (nullable)"
    },
    ...
  ],
  "total": 45,
  "limit": 20,
  "offset": 0
}
```

---

### Data Export Endpoints

#### GET /export/workout-history
```json
Query params: ?format=csv&start_date=2024-01-01&end_date=2024-12-31

Response (200):
Content-Type: text/csv
Content-Disposition: attachment; filename="531_workout_history.csv"

[CSV file download]
```

---

## 10. Testing Strategy

### Backend Testing (pytest)

#### Unit Tests
- **Business Logic Functions**:
  - `test_calculate_1rm()` - Epley formula accuracy
  - `test_calculate_training_max()` - 90% of 1RM
  - `test_calculate_working_weight()` - Percentages for each week
  - `test_weight_rounding()` - Correct rounding to increments
  - `test_plate_calculator()` - Optimal plate loading
  - `test_rep_max_detection()` - New PR identification
  - `test_failed_reps_analysis()` - Recommendation logic

- **Data Models**:
  - User creation and validation
  - Program creation with relationships
  - Training max updates and history
  - Workout set logging

#### Integration Tests
- **Authentication Flow**:
  - `test_register_user()` - Account creation
  - `test_login()` - JWT token generation
  - `test_token_refresh()` - Refresh token flow
  - `test_password_reset()` - Email reset workflow

- **Program Management**:
  - `test_create_program()` - Full program setup
  - `test_program_with_training_maxes()` - TM initialization
  - `test_workout_generation()` - Calendar creation
  - `test_cycle_completion()` - TM update at cycle end

- **Workout Execution**:
  - `test_start_workout()` - Status change to in_progress
  - `test_complete_workout()` - Set logging and completion
  - `test_amrap_set_creates_rep_max()` - PR detection
  - `test_failed_reps_recommendation()` - Analysis logic

- **API Contracts**:
  - Test all endpoints for:
    - Correct status codes
    - Response schema validation
    - Authentication requirements
    - Error handling (400, 401, 404, 500)

#### Test Database
- Use in-memory SQLite for tests
- Fixtures for common test data (users, programs, workouts)
- Teardown between tests to ensure isolation

#### Coverage Target
- Aim for 80%+ code coverage
- 100% coverage of business logic functions
- All API endpoints have integration tests

---

### Frontend Testing (Flutter)

#### Unit Tests
- **Riverpod Providers/Notifiers**:
  - Authentication state management
  - Program state updates
  - Workout logging state
  - Settings persistence

- **Data Models**:
  - JSON serialization/deserialization
  - Validation logic
  - 1RM calculations (client-side for offline)

- **Utilities**:
  - Date formatting
  - Weight unit conversions
  - Plate calculator

#### Widget Tests
- **Critical UI Components**:
  - Login/Registration forms
  - Calendar view (week/month)
  - Workout execution screen
  - Set entry form with number pad
  - Rest timer widget
  - Training max input forms
  - Rep max table display

- **Widget Interactions**:
  - Form validation
  - Button state changes
  - Navigation flows
  - Error message displays

#### Integration Tests (Optional for MVP)
- Full user flows:
  - Complete program setup
  - Execute a full workout
  - View progress charts

#### Testing Tools
- `flutter_test` package
- `mockito` for mocking API calls
- `riverpod` test utilities

---

## 11. Deployment & Infrastructure

### Development Environment

#### Backend (Docker)
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Expose port
EXPOSE 8000

# Run with uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

#### Docker Compose (Optional for local dev)
```yaml
version: '3.8'

services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    volumes:
      - ./backend:/app
      - ./data:/app/data  # SQLite database volume
    environment:
      - DATABASE_URL=sqlite:///./data/531.db
      - JWT_SECRET_KEY=${JWT_SECRET_KEY}
      - SMTP_HOST=${SMTP_HOST}
      - SMTP_PORT=${SMTP_PORT}
      - SMTP_USER=${SMTP_USER}
      - SMTP_PASSWORD=${SMTP_PASSWORD}
```

#### Environment Variables
```bash
# .env file
DATABASE_URL=sqlite:///./data/531.db
JWT_SECRET_KEY=<generate strong secret>
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

# Email (for password reset)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
FROM_EMAIL=noreply@531app.com

# App settings
API_VERSION=v1
CORS_ORIGINS=["http://localhost:3000"]
```

---

### Self-Hosting Considerations

#### Requirements
- Docker and Docker Compose installed
- SMTP server access (or email service) for password resets
- SSL certificate for HTTPS (Let's Encrypt recommended)

#### Installation Steps
1. Clone repository
2. Create `.env` file with configuration
3. Run `docker-compose up -d`
4. Access API at `http://localhost:8000`
5. API documentation at `http://localhost:8000/docs` (Swagger UI)

#### Database Backups
- SQLite database file location: `./data/531.db`
- Recommended: Daily automated backups
- Simple backup script:
  ```bash
  #!/bin/bash
  DATE=$(date +%Y%m%d_%H%M%S)
  cp ./data/531.db ./backups/531_backup_$DATE.db
  # Keep last 30 days
  find ./backups -name "531_backup_*.db" -mtime +30 -delete
  ```

#### Updates
- Pull latest code
- Run database migrations: `alembic upgrade head`
- Restart Docker containers

---

### Production Deployment (Future)

#### Recommended Stack
- **Hosting**: DigitalOcean, AWS Lightsail, or self-hosted VPS
- **Reverse Proxy**: Nginx with SSL (Let's Encrypt)
- **Database**: Continue with SQLite for simplicity, or migrate to PostgreSQL for scale
- **Monitoring**: Basic logging, optional Sentry for error tracking

#### Security Checklist
- [ ] HTTPS enforced
- [ ] JWT secret key is strong and not committed to repo
- [ ] CORS configured properly
- [ ] Rate limiting on authentication endpoints
- [ ] Database backups automated
- [ ] Environment variables secured
- [ ] API documentation disabled in production (or password-protected)

---

## 12. Future Extensibility

### Planned Features (Post-MVP)

#### 2-Day & 3-Day Programs
- Database already designed for flexibility (`template_type` field)
- UI will need program type selector during setup
- Different workout-to-day mappings

#### Additional Program Templates
- Boring But Big (BBB) - 5×10 supplemental work
- Triumvirate - 3 accessories per day
- Periodization Bible - varied rep schemes
- Templates stored as program variants, different accessory schemes

#### Advanced Analytics
- Volume tracking (total weight lifted per cycle)
- Estimated 1RM trends from AMRAP performance
- Lift ratio analysis (e.g., bench:squat ratio)
- Time-under-tension calculations

#### Social Features
- Share workouts with friends
- Follow other users' programs (optional)
- Leaderboards (opt-in)

#### Additional Features
- Video form guides for exercises
- Custom notes with rich text
- Photo attachments (progress pics)
- Body weight tracking
- Integration with fitness trackers (optional)

---

### Architecture Considerations for Growth

#### Database Migration Path
If user base grows significantly:
- Migrate from SQLite to PostgreSQL
- Alembic migrations will handle schema changes
- Update `DATABASE_URL` in environment

#### API Versioning
- Already using `/api/v1` prefix structure
- Future breaking changes can introduce `/api/v2`
- Maintain backward compatibility for mobile app versions

#### Mobile App Updates
- Use feature flags for gradual rollouts
- Maintain backward compatibility with older app versions
- Consider minimum supported API version

---

## 13. Open Questions & Decisions Needed

### Before Implementation
- [x] Confirm predefined exercise list from Chapter 16
- [x] Finalize color scheme and design system for Flutter UI
- [ ] Set up SMTP service for password resets (Gmail, SendGrid, etc.)
- [ ] Choose charting library for Flutter (fl_chart recommended)
- [ ] Decide on app name and branding

### During Development
- Test offline sync extensively (edge cases: conflicts, network interruptions)
- Validate 5/3/1 percentages with the book to ensure accuracy
- Get user feedback on plate calculator (is it helpful or cluttered?)

---

## 14. Summary & Next Steps

This specification provides a comprehensive blueprint for building the 5/3/1 strength training app. Key highlights:

✅ **Core Features Defined**: Program setup, workout execution, progress tracking, rep maxes
✅ **Technical Stack Chosen**: Flutter + Riverpod, FastAPI + SQLite, Docker, JWT auth
✅ **Data Model Designed**: Flexible schema supporting current and future program variants
✅ **Business Logic Detailed**: All calculations (1RM, TM, weights, plates, reps) specified
✅ **API Contracts Specified**: RESTful endpoints with request/response schemas
✅ **Testing Strategy Outlined**: Unit and integration tests for backend and frontend
✅ **Self-Hosting Ready**: Docker setup with clear deployment instructions

### Recommended Implementation Phases

**Phase 1: MVP Backend** (Weeks 1-2)
- User authentication (register, login, JWT)
- Program CRUD
- Workout generation and retrieval
- Training max management

**Phase 2: MVP Frontend** (Weeks 3-5)
- Login/registration screens
- Program setup wizard
- Calendar view with workout details
- Basic workout execution (log sets)

**Phase 3: Workout Execution Polish** (Week 6)
- Rest timer
- Plate calculator
- AMRAP detection
- Workout completion flow

**Phase 4: Progress Tracking** (Week 7)
- Training max history charts
- Workout history list
- Rep max records screen

**Phase 5: Offline Support & Sync** (Week 8)
- sqflite integration
- Background sync logic
- Conflict resolution

**Phase 6: Testing & Polish** (Week 9-10)
- Comprehensive testing
- Bug fixes
- UI/UX refinements
- Documentation

---

**This specification is now ready for development.**
