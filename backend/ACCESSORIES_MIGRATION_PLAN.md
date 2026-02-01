# Accessories Migration Plan: Move to Separate Table

## Problem Statement
Currently, accessories are stored as a JSON column in `ProgramTemplate`, which associates them with a specific `main_lift`. This causes issues for 2-day programs where multiple lifts share the same day - the same accessories get duplicated across multiple templates with the same `day_number`.

**Current structure:**
```
ProgramTemplate (id, program_id, day_number, main_lift, accessories)
```

For a 2-day program:
- Day 1: SQUAT template with accessories A, BENCH template with accessories A (duplicated)
- Day 2: DEADLIFT template with accessories B, PRESS template with accessories B (duplicated)

## Solution
Create a new `ProgramDayAccessories` table that stores accessories per day, eliminating duplication.

## New Database Schema

### New Table: `program_day_accessories`
```python
class ProgramDayAccessories(Base):
    __tablename__ = "program_day_accessories"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    program_id = Column(String(36), ForeignKey("programs.id"), nullable=False, index=True)
    day_number = Column(Integer, nullable=False)  # 1-4
    accessories = Column(JSON, nullable=False)
    # Format: [{"exercise_id": "uuid", "sets": 5, "reps": 12, "circuit_group": 1}, ...]

    __table_args__ = (
        UniqueConstraint('program_id', 'day_number', name='uq_program_day_accessories'),
    )
```

### Modified Table: `program_templates`
Remove the `accessories` column (after migration):
```python
class ProgramTemplate(Base):
    __tablename__ = "program_templates"

    id = Column(String(36), primary_key=True)
    program_id = Column(String(36), ForeignKey("programs.id"), nullable=False)
    day_number = Column(Integer, nullable=False)
    main_lift = Column(SQLEnum(LiftType), nullable=False)
    # accessories column REMOVED
```

## Files to Modify

### Backend Models
- **`app/models/program.py`**
  - Add `ProgramDayAccessories` class
  - Remove `accessories` column from `ProgramTemplate` (after migration)

### Backend Schemas
- **`app/schemas/program.py`**
  - Update `ProgramTemplateResponse` to exclude accessories
  - Add `ProgramDayAccessoriesResponse` schema
  - Update `ProgramDetailResponse` to include `day_accessories: List[ProgramDayAccessoriesResponse]`

### Backend Services
- **`app/services/program.py`**
  - `create_program()`: Create `ProgramDayAccessories` records instead of storing in template
  - `update_accessories()`: Update `ProgramDayAccessories` by day_number
  - `get_program_with_details()`: Include day accessories in response
  - `delete_program()`: Cascade delete day accessories

- **`app/services/workout.py`**
  - `_get_accessory_sets()`: Query `ProgramDayAccessories` by day_number instead of by main_lift

### Backend Routers
- **`app/routers/programs.py`**
  - Update accessory endpoints to use day_number instead of lift_type

### Database Migration
- **`alembic/versions/xxx_add_program_day_accessories.py`**
  1. Create `program_day_accessories` table
  2. Migrate data: For each program, group templates by day_number, take accessories from first template of each day
  3. Drop `accessories` column from `program_templates`

### Frontend
- **`lib/models/program.dart`**
  - Add `ProgramDayAccessories` model
  - Update `Program` model to include `dayAccessories`

- **`lib/services/api_service.dart`**
  - Update program creation/update to send accessories by day
  - Update program detail parsing

- **`lib/screens/programs/program_detail_screen.dart`**
  - Already groups by day, simplify to use new structure

- **`lib/screens/programs/program_create_screen.dart`**
  - Already collects accessories by workout/day, adapt to new API

### Tests
- **`tests/test_programs.py`**
  - Update `TestProgramTemplates` to test new `ProgramDayAccessories`
  - Add migration verification tests

## Implementation Order

### Phase 1: Add New Table (Non-Breaking)
1. Create `ProgramDayAccessories` model in `app/models/program.py`
2. Create Alembic migration to add `program_day_accessories` table
3. Run migration

### Phase 2: Dual-Write (Backwards Compatible)
1. Update `create_program()` to write to BOTH old and new location
2. Update `update_accessories()` to write to BOTH locations
3. Deploy and verify

### Phase 3: Read from New Table
1. Update `_get_accessory_sets()` to read from `ProgramDayAccessories`
2. Update `get_program_with_details()` to return day accessories
3. Update frontend to parse new response structure
4. Deploy and verify

### Phase 4: Remove Old Column
1. Update `create_program()` to ONLY write to new table
2. Update schemas to remove accessories from template response
3. Create migration to drop `accessories` column from `program_templates`
4. Clean up frontend code
5. Deploy final version

## Data Migration Strategy

```python
def upgrade():
    # 1. Create new table
    op.create_table(
        'program_day_accessories',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('program_id', sa.String(36), sa.ForeignKey('programs.id'), nullable=False),
        sa.Column('day_number', sa.Integer(), nullable=False),
        sa.Column('accessories', sa.JSON(), nullable=False),
        sa.UniqueConstraint('program_id', 'day_number', name='uq_program_day_accessories')
    )

    # 2. Migrate existing data
    connection = op.get_bind()

    # Get distinct program_id, day_number combinations
    templates = connection.execute(text('''
        SELECT DISTINCT program_id, day_number, accessories
        FROM program_templates
        GROUP BY program_id, day_number
    ''')).fetchall()

    for program_id, day_number, accessories in templates:
        if accessories:
            connection.execute(text('''
                INSERT INTO program_day_accessories (id, program_id, day_number, accessories)
                VALUES (:id, :program_id, :day_number, :accessories)
            '''), {
                'id': str(uuid.uuid4()),
                'program_id': program_id,
                'day_number': day_number,
                'accessories': accessories
            })

    # 3. Drop old column (in separate migration after verification)
    # op.drop_column('program_templates', 'accessories')
```

## Verification Steps

### After Phase 1
```bash
cd backend
pytest tests/test_programs.py -v
# Verify new table exists in database
```

### After Phase 3
```bash
# Run all tests
cd backend && pytest -v

# Manual verification:
# 1. Create a 2-day program with accessories
# 2. Verify accessories appear once per day (not duplicated)
# 3. Edit accessories for a day
# 4. Complete a workout and verify accessories load correctly
```

### After Phase 4
```bash
# Run all tests
cd backend && pytest -v

# Verify column dropped
sqlite3 app.db ".schema program_templates"
# Should NOT show 'accessories' column
```

## Rollback Plan
If issues occur during migration:
1. Phase 2 (dual-write) allows easy rollback - just revert code
2. Data in old `accessories` column preserved until Phase 4
3. If Phase 4 fails, restore column and re-populate from `program_day_accessories`

## API Changes

### Before
```json
{
  "templates": [
    {"day_number": 1, "main_lift": "SQUAT", "accessories": [...]},
    {"day_number": 1, "main_lift": "BENCH_PRESS", "accessories": [...]}  // duplicate
  ]
}
```

### After
```json
{
  "templates": [
    {"day_number": 1, "main_lift": "SQUAT"},
    {"day_number": 1, "main_lift": "BENCH_PRESS"}
  ],
  "day_accessories": [
    {"day_number": 1, "accessories": [...]}  // single source of truth
  ]
}
```
