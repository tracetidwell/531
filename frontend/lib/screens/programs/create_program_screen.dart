import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/program_models.dart';
import '../../models/exercise_models.dart';
import '../../providers/program_provider.dart';
import '../../providers/exercise_provider.dart';
import '../../widgets/exercise_selector.dart';

class CreateProgramScreen extends ConsumerStatefulWidget {
  const CreateProgramScreen({super.key});

  @override
  ConsumerState<CreateProgramScreen> createState() => _CreateProgramScreenState();
}

class _CreateProgramScreenState extends ConsumerState<CreateProgramScreen> {
  int _currentStep = 0;

  // Program data
  final _nameController = TextEditingController();
  String _templateType = '4_day'; // Default to 4-day template
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  int? _targetCycles;
  bool _includeDeload = true; // Include deload week by default
  final List<String> _selectedDays = [];
  final Map<String, double> _trainingMaxes = {
    'press': 0,
    'deadlift': 0,
    'bench_press': 0,
    'squat': 0,
  };
  final Map<String, List<AccessoryExerciseDetail>> _accessories = {
    '1': [],
    '2': [],
    '3': [],
    '4': [],
  };

  // Track the next circuit group number for each workout type
  final Map<String, int> _nextCircuitGroup = {
    '1': 1,
    '2': 1,
    '3': 1,
    '4': 1,
  };

  bool _isCreating = false;
  String? _dateConflictWarning;

  @override
  void initState() {
    super.initState();
    // Load existing programs to check for conflicts
    Future.microtask(() async {
      await ref.read(programProvider.notifier).loadPrograms();
      _checkDateConflicts();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _checkDateConflicts() {
    final programs = ref.read(programProvider).programs;

    DateTime? newEnd = _endDate;
    // Calculate end date from target cycles if not set
    if (newEnd == null && _targetCycles != null) {
      final weeksPerCycle = _getWeeksPerCycle();
      newEnd = _startDate.add(Duration(days: 7 * weeksPerCycle * _targetCycles!));
    }

    for (final existing in programs) {
      DateTime? existingEnd = existing.endDate;
      // Calculate end date from target cycles if not set
      if (existingEnd == null && existing.targetCycles != null) {
        final existingWeeksPerCycle = getWeeksPerCycleForProgram(
          existing.templateType,
          existing.includeDeload
        );
        existingEnd = existing.startDate.add(Duration(days: 7 * existingWeeksPerCycle * existing.targetCycles!));
      }

      bool hasOverlap = false;

      if (newEnd != null && existingEnd != null) {
        // Both have end dates
        hasOverlap = _startDate.isBefore(existingEnd.add(const Duration(days: 1))) &&
                     existing.startDate.isBefore(newEnd.add(const Duration(days: 1)));
      } else if (newEnd != null && existingEnd == null) {
        // New has end, existing is open-ended
        hasOverlap = _startDate.isAfter(existing.startDate) ||
                     _startDate.isAtSameMomentAs(existing.startDate) ||
                     newEnd.isAfter(existing.startDate) ||
                     newEnd.isAtSameMomentAs(existing.startDate);
      } else if (newEnd == null && existingEnd != null) {
        // New is open-ended, existing has end
        hasOverlap = _startDate.isBefore(existingEnd.add(const Duration(days: 1)));
      } else {
        // Both are open-ended
        hasOverlap = _startDate.isAfter(existing.startDate) ||
                     _startDate.isAtSameMomentAs(existing.startDate);
      }

      if (hasOverlap) {
        final existingEndStr = existingEnd != null
            ? '${existingEnd.month}/${existingEnd.day}/${existingEnd.year}'
            : 'ongoing';
        setState(() {
          _dateConflictWarning =
              'Conflicts with "${existing.name}" (${existing.startDate.month}/${existing.startDate.day}/${existing.startDate.year} to $existingEndStr)';
        });
        return;
      }
    }

    setState(() {
      _dateConflictWarning = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Program'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Home',
          ),
        ],
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Theme.of(context).colorScheme.primary,
          ),
        ),
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back'),
                    ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isCreating ? null : details.onStepContinue,
                    child: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_currentStep == 4 ? 'Create Program' : 'Next'),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Info'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _buildProgramInfoStep(),
            ),
            Step(
              title: const Text('Days'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _buildTrainingDaysStep(),
            ),
            Step(
              title: const Text('Maxes'),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: _buildTrainingMaxesStep(),
            ),
            Step(
              title: const Text('Accessories'),
              isActive: _currentStep >= 3,
              state: _currentStep > 3 ? StepState.complete : StepState.indexed,
              content: _buildAccessoriesStep(),
            ),
            Step(
              title: const Text('Review'),
              isActive: _currentStep >= 4,
              state: StepState.indexed,
              content: _buildReviewStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Program Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Program Name',
            hintText: 'e.g., Winter 2025 - 4 Day',
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Program Template',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(
              value: '2_day',
              label: Text('2-Day'),
              icon: Icon(Icons.looks_two),
            ),
            ButtonSegment<String>(
              value: '3_day',
              label: Text('3-Day'),
              icon: Icon(Icons.looks_3),
            ),
            ButtonSegment<String>(
              value: '4_day',
              label: Text('4-Day'),
              icon: Icon(Icons.looks_4),
            ),
          ],
          selected: {_templateType},
          onSelectionChanged: (Set<String> selection) {
            setState(() {
              _templateType = selection.first;
              // Clear selected days when template changes
              _selectedDays.clear();
            });
          },
        ),
        const SizedBox(height: 8),
        Text(
          _getTemplateDescription(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: const Text('Start Date'),
          subtitle: Text(
            '${_startDate.month}/${_startDate.day}/${_startDate.year}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setState(() => _startDate = date);
              _checkDateConflicts();
            }
          },
        ),
        if (_dateConflictWarning != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _dateConflictWarning!,
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.repeat),
          title: const Text('Duration (Optional)'),
          subtitle: Text(
            _targetCycles != null
                ? '$_targetCycles cycles'
                : 'No end date',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showCyclesPicker(),
        ),
      ],
    );
  }

  int _getRequiredDays() {
    switch (_templateType) {
      case '2_day':
        return 2;
      case '3_day':
        return 3;
      case '4_day':
      default:
        return 4;
    }
  }

  int _getRequiredWorkoutTypes() {
    // Returns the number of workout types (for accessories)
    // 3-day programs have 4 workout types (one per lift)
    switch (_templateType) {
      case '2_day':
        return 2;
      case '3_day':
        return 4;  // Changed: 3-day has 4 workout types
      case '4_day':
      default:
        return 4;
    }
  }

  String _getTemplateDescription() {
    switch (_templateType) {
      case '2_day':
        return '2 training days per week - Each day has 2 main lifts';
      case '3_day':
        return '3 training days per week - Mix of single and double lift days';
      case '4_day':
      default:
        return '4 training days per week - One main lift per day';
    }
  }

  Widget _buildTrainingDaysStep() {
    final daysOfWeek = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];

    final requiredDays = _getRequiredDays();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select $requiredDays Training Days',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_selectedDays.length}/$requiredDays days selected',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 16),
        ...daysOfWeek.map((day) {
          final isSelected = _selectedDays.contains(day);
          return CheckboxListTile(
            title: Text(
              day[0].toUpperCase() + day.substring(1),
              style: const TextStyle(fontSize: 16),
            ),
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true && _selectedDays.length < requiredDays) {
                  _selectedDays.add(day);
                } else if (value == false) {
                  _selectedDays.remove(day);
                }
              });
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTrainingMaxesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Training Maxes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your training max (90% of 1RM) for each lift',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 24),
        _buildTrainingMaxInput('Press', 'press'),
        const SizedBox(height: 16),
        _buildTrainingMaxInput('Deadlift', 'deadlift'),
        const SizedBox(height: 16),
        _buildTrainingMaxInput('Bench Press', 'bench_press'),
        const SizedBox(height: 16),
        _buildTrainingMaxInput('Squat', 'squat'),
      ],
    );
  }

  Widget _buildTrainingMaxInput(String label, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Training Max',
            suffixText: 'lbs',
            hintText: '0',
          ),
          onChanged: (value) {
            setState(() {
              _trainingMaxes[key] = double.tryParse(value) ?? 0;
            });
          },
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getWorkoutTypes() {
    // Returns list of workout types with their main lifts
    // Each map has: {workoutNumber: String, lifts: List<String>, displayName: String}

    if (_templateType == '2_day') {
      return [
        {
          'workoutNumber': '1',
          'lifts': ['squat', 'bench_press'],
          'displayName': 'Squat + Bench Press',
        },
        {
          'workoutNumber': '2',
          'lifts': ['deadlift', 'press'],
          'displayName': 'Deadlift + Press',
        },
      ];
    } else {
      // 3-day and 4-day both have 4 workout types (one per lift)
      return [
        {
          'workoutNumber': '1',
          'lifts': ['press'],
          'displayName': 'Press',
        },
        {
          'workoutNumber': '2',
          'lifts': ['deadlift'],
          'displayName': 'Deadlift',
        },
        {
          'workoutNumber': '3',
          'lifts': ['bench_press'],
          'displayName': 'Bench Press',
        },
        {
          'workoutNumber': '4',
          'lifts': ['squat'],
          'displayName': 'Squat',
        },
      ];
    }
  }

  Widget _buildAccessoriesStep() {
    final workoutTypes = _getWorkoutTypes();

    // Description based on template type
    final String description = _templateType == '2_day'
        ? 'Select 2-6 accessory exercises for each workout type.'
        : 'Select 1-3 accessory exercises for each main lift.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accessory Exercises',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 24),

        // Show accessories for each workout type
        ...workoutTypes.map((workoutType) {
          return _buildWorkoutTypeAccessories(
            workoutType['workoutNumber'] as String,
            workoutType['displayName'] as String,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildWorkoutTypeAccessories(String workoutNumber, String workoutDisplayName) {
    final accessories = _accessories[workoutNumber] ?? [];

    // For 2-day programs: 2 main lifts per workout, so allow 2-6 accessories
    // For 3-day/4-day programs: 1 main lift per workout, so allow 1-3 accessories
    final maxAccessories = _templateType == '2_day' ? 6 : 3;

    // Group exercises: standalone (null circuit) and by circuit number
    final standaloneExercises = accessories
        .asMap()
        .entries
        .where((e) => e.value.circuitGroup == null)
        .toList();

    // Get unique circuit groups
    final circuitGroups = accessories
        .where((a) => a.circuitGroup != null)
        .map((a) => a.circuitGroup!)
        .toSet()
        .toList()
      ..sort();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    workoutDisplayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action buttons row
            if (accessories.length < maxAccessories)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Exercise'),
                    onPressed: () => _addAccessoryExercise(workoutNumber),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.repeat, size: 18),
                    label: const Text('Add Circuit'),
                    onPressed: () => _addCircuit(workoutNumber),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            if (accessories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No accessories selected for this workout',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              )
            else ...[
              // Show standalone exercises first
              if (standaloneExercises.isNotEmpty) ...[
                ...standaloneExercises.map((entry) {
                  return _buildAccessoryItem(workoutNumber, entry.key, entry.value);
                }),
              ],

              // Show circuit groups
              ...circuitGroups.map((circuitNum) {
                final circuitExercises = accessories
                    .asMap()
                    .entries
                    .where((e) => e.value.circuitGroup == circuitNum)
                    .toList();
                return _buildCircuitCard(workoutNumber, circuitNum, circuitExercises);
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _addCircuit(String workoutNumber) async {
    final circuitNum = _nextCircuitGroup[workoutNumber] ?? 1;

    // First, let user select the first exercise for the circuit
    final exercise = await showDialog<Exercise>(
      context: context,
      builder: (context) => const ExerciseSelectorDialog(),
    );

    if (exercise != null) {
      final accessoryDetail = AccessoryExerciseDetail(
        exercise: exercise,
        sets: 5,
        reps: 12,
        circuitGroup: circuitNum,
      );

      final edited = await _showSetRepEditDialog(accessoryDetail);
      if (edited != null) {
        setState(() {
          _accessories[workoutNumber]?.add(edited);
          _nextCircuitGroup[workoutNumber] = circuitNum + 1;
        });
      }
    }
  }

  Widget _buildCircuitCard(
    String workoutNumber,
    int circuitNum,
    List<MapEntry<int, AccessoryExerciseDetail>> circuitExercises,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade300, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circuit header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Icon(Icons.repeat, size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Text(
                  'Circuit $circuitNum',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: Icon(Icons.add, size: 16, color: Colors.orange.shade800),
                  label: Text(
                    'Add to Circuit',
                    style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                  ),
                  onPressed: () => _addExerciseToCircuit(workoutNumber, circuitNum),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: Colors.orange.shade800),
                  onPressed: () => _deleteCircuit(workoutNumber, circuitNum),
                  tooltip: 'Delete Circuit',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          // Circuit exercises
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: circuitExercises.map((entry) {
                return _buildCircuitExerciseItem(workoutNumber, entry.key, entry.value, circuitNum);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircuitExerciseItem(
    String workoutNumber,
    int index,
    AccessoryExerciseDetail accessory,
    int circuitNum,
  ) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.orange.shade200,
          child: Text(
            accessory.exercise.category.name[0].toUpperCase(),
            style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
          ),
        ),
        title: Text(accessory.exercise.name, style: const TextStyle(fontSize: 14)),
        subtitle: Text('${accessory.sets} × ${accessory.reps}', style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editAccessoryExercise(workoutNumber, index, accessory),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              onPressed: () => _removeFromCircuit(workoutNumber, index),
              tooltip: 'Remove from circuit',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addExerciseToCircuit(String workoutNumber, int circuitNum) async {
    final exercise = await showDialog<Exercise>(
      context: context,
      builder: (context) => const ExerciseSelectorDialog(),
    );

    if (exercise != null) {
      final accessoryDetail = AccessoryExerciseDetail(
        exercise: exercise,
        sets: 5,
        reps: 12,
        circuitGroup: circuitNum,
      );

      final edited = await _showSetRepEditDialog(accessoryDetail);
      if (edited != null) {
        setState(() {
          _accessories[workoutNumber]?.add(edited);
        });
      }
    }
  }

  void _deleteCircuit(String workoutNumber, int circuitNum) {
    setState(() {
      // Remove all exercises in this circuit
      _accessories[workoutNumber]?.removeWhere((a) => a.circuitGroup == circuitNum);
    });
  }

  void _removeFromCircuit(String workoutNumber, int index) {
    setState(() {
      // Make the exercise standalone (remove from circuit)
      final accessory = _accessories[workoutNumber]?[index];
      if (accessory != null) {
        _accessories[workoutNumber]?[index] = accessory.copyWith(clearCircuitGroup: true);
      }
    });
  }

  Widget _buildAccessoryItem(
    String workoutNumber,
    int index,
    AccessoryExerciseDetail accessory,
  ) {
    return Card(
      color: Colors.grey[100],
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(accessory.exercise.category.name[0].toUpperCase()),
        ),
        title: Text(accessory.exercise.name),
        subtitle: Text('${accessory.sets} sets × ${accessory.reps} reps'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editAccessoryExercise(workoutNumber, index, accessory),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: () {
                setState(() {
                  _accessories[workoutNumber]?.removeAt(index);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addAccessoryExercise(String workoutNumber) async {
    final exercise = await showDialog<Exercise>(
      context: context,
      builder: (context) => const ExerciseSelectorDialog(),
    );

    if (exercise != null) {
      // Default to 5 sets × 12 reps per 5/3/1 methodology
      final accessoryDetail = AccessoryExerciseDetail(
        exercise: exercise,
        sets: 5,
        reps: 12,
      );

      // Show edit dialog to customize sets/reps
      final edited = await _showSetRepEditDialog(accessoryDetail);
      if (edited != null) {
        setState(() {
          _accessories[workoutNumber]?.add(edited);
        });
      }
    }
  }

  Future<void> _editAccessoryExercise(
    String workoutNumber,
    int index,
    AccessoryExerciseDetail currentAccessory,
  ) async {
    final edited = await _showSetRepEditDialog(currentAccessory);
    if (edited != null) {
      setState(() {
        _accessories[workoutNumber]?[index] = edited;
      });
    }
  }

  Future<AccessoryExerciseDetail?> _showSetRepEditDialog(
    AccessoryExerciseDetail current,
  ) async {
    final setsController = TextEditingController(text: current.sets.toString());
    final repsController = TextEditingController(text: current.reps.toString());

    return showDialog<AccessoryExerciseDetail>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(current.exercise.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current.circuitGroup != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.repeat, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Circuit ${current.circuitGroup}',
                        style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            TextField(
              controller: setsController,
              decoration: const InputDecoration(labelText: 'Sets'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: repsController,
              decoration: const InputDecoration(labelText: 'Reps'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final sets = int.tryParse(setsController.text) ?? current.sets;
              final reps = int.tryParse(repsController.text) ?? current.reps;

              Navigator.of(context).pop(
                AccessoryExerciseDetail(
                  exercise: current.exercise,
                  sets: sets,
                  reps: reps,
                  circuitGroup: current.circuitGroup, // Preserve circuit group
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    // Calculate end date for display
    DateTime? calculatedEndDate = _endDate;
    if (calculatedEndDate == null && _targetCycles != null) {
      final weeksPerCycle = _getWeeksPerCycle();
      calculatedEndDate = _startDate.add(Duration(days: 7 * weeksPerCycle * _targetCycles!));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Your Program',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewItem('Name', _nameController.text),
                const Divider(),
                _buildReviewItem(
                  'Template',
                  _templateType == '2_day'
                      ? '2-Day Program'
                      : _templateType == '3_day'
                          ? '3-Day Program'
                          : '4-Day Program',
                ),
                const Divider(),
                _buildReviewItem(
                  'Start Date',
                  '${_startDate.month}/${_startDate.day}/${_startDate.year}',
                ),
                const Divider(),
                _buildReviewItem(
                  'End Date',
                  calculatedEndDate != null
                      ? '${calculatedEndDate.month}/${calculatedEndDate.day}/${calculatedEndDate.year}'
                      : 'Open-ended',
                ),
                const Divider(),
                _buildReviewItem(
                  'Duration',
                  _targetCycles != null
                      ? '$_targetCycles cycles (${_targetCycles! * 4} weeks)'
                      : 'Open-ended',
                ),
                const Divider(),
                _buildReviewItem(
                  'Training Days',
                  _selectedDays
                      .map((d) => d.substring(0, 3).toUpperCase())
                      .join(', '),
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Training Maxes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                _buildReviewItem('Press', '${_trainingMaxes['press']} lbs'),
                _buildReviewItem('Deadlift', '${_trainingMaxes['deadlift']} lbs'),
                _buildReviewItem('Bench Press', '${_trainingMaxes['bench_press']} lbs'),
                _buildReviewItem('Squat', '${_trainingMaxes['squat']} lbs'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  int _getWeeksPerCycle() {
    // 3-day programs use 5-week cycles, others use 4 weeks (or 3 without deload)
    if (_templateType == '3_day') {
      return 5;
    }
    return _includeDeload ? 4 : 3;
  }

  // Static helper to calculate weeks per cycle for any program
  static int getWeeksPerCycleForProgram(String templateType, bool includeDeload) {
    if (templateType == '3_day') {
      return 5;
    }
    return includeDeload ? 4 : 3;
  }

  void _showCyclesPicker() {
    final weeksPerCycle = _getWeeksPerCycle();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Program Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Open-ended'),
              subtitle: const Text('No end date'),
              onTap: () {
                setState(() => _targetCycles = null);
                Navigator.pop(context);
                _checkDateConflicts();
              },
            ),
            ...List.generate(12, (index) {
              final cycles = index + 1;
              final totalWeeks = cycles * weeksPerCycle;
              return ListTile(
                title: Text('$cycles ${cycles == 1 ? 'cycle' : 'cycles'}'),
                subtitle: Text('$totalWeeks weeks'),
                onTap: () {
                  setState(() => _targetCycles = cycles);
                  Navigator.pop(context);
                  _checkDateConflicts();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _onStepContinue() async {
    if (_currentStep == 0) {
      if (_nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a program name')),
        );
        return;
      }
      if (_dateConflictWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_dateConflictWarning!),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else if (_currentStep == 1) {
      final requiredDays = _getRequiredDays();
      if (_selectedDays.length != requiredDays) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select exactly $requiredDays training days')),
        );
        return;
      }
    } else if (_currentStep == 2) {
      if (_trainingMaxes.values.any((v) => v <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter all training maxes')),
        );
        return;
      }
    } else if (_currentStep == 4) {
      // Create program
      await _createProgram();
      return;
    }

    setState(() {
      _currentStep++;
    });
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    } else {
      context.pop();
    }
  }

  Future<void> _createProgram() async {
    setState(() => _isCreating = true);

    try {
      // Calculate end date from target cycles if not explicitly set
      DateTime? calculatedEndDate = _endDate;
      if (calculatedEndDate == null && _targetCycles != null) {
        // Calculate weeks based on template type (3-day uses 5 weeks, others use 3-4)
        final weeksPerCycle = _getWeeksPerCycle();
        calculatedEndDate = _startDate.add(Duration(days: 7 * weeksPerCycle * _targetCycles!));
      }

      // Convert accessories to API format (exercise_id, sets, reps, circuit_group)
      // Include all workout types required for the template type
      final requiredWorkoutTypes = _getRequiredWorkoutTypes();
      final accessoriesForApi = <String, List<AccessoryExercise>>{};
      for (int i = 1; i <= requiredWorkoutTypes; i++) {
        final workoutKey = i.toString();
        final workoutAccessories = _accessories[workoutKey] ?? [];
        accessoriesForApi[workoutKey] = workoutAccessories
            .map((detail) => AccessoryExercise(
                  exerciseId: detail.exercise.id,
                  sets: detail.sets,
                  reps: detail.reps,
                  circuitGroup: detail.circuitGroup,
                ))
            .toList();
      }

      final request = CreateProgramRequest(
        name: _nameController.text,
        templateType: _templateType,
        startDate: _startDate,
        endDate: calculatedEndDate,
        targetCycles: _targetCycles,
        includeDeload: _includeDeload,
        trainingDays: _selectedDays,
        trainingMaxes: _trainingMaxes,
        accessories: accessoriesForApi,
      );

      await ref.read(programProvider.notifier).createProgram(request);

      if (mounted) {
        // Show success dialog with navigation options
        final shouldGoHome = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success!'),
            content: const Text('Your program has been created successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('View Programs'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Go Home'),
              ),
            ],
          ),
        );

        if (mounted) {
          if (shouldGoHome == true) {
            context.go('/');
          } else {
            context.pop(); // Go back to program list
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }
}
