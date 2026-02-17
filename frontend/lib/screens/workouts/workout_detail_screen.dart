import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/workout_models.dart';
import '../../models/exercise_models.dart';
import '../../providers/program_provider.dart';
import '../../providers/exercise_provider.dart';

class WorkoutDetailScreen extends ConsumerStatefulWidget {
  final String workoutId;

  const WorkoutDetailScreen({
    super.key,
    required this.workoutId,
  });

  @override
  ConsumerState<WorkoutDetailScreen> createState() =>
      _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends ConsumerState<WorkoutDetailScreen> {
  WorkoutDetail? _workoutDetail;
  bool _isLoading = true;
  String? _error;
  Map<String, Exercise> _exercises = {};

  @override
  void initState() {
    super.initState();
    _loadWorkoutDetail();
  }

  Future<void> _loadWorkoutDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);

      // Get the workout detail
      final workoutDetail = await apiService.getWorkoutDetail(widget.workoutId);

      // Collect all exercise IDs from accessory sets
      final allExerciseIds = <String>{};
      for (final set in workoutDetail.accessorySets) {
        if (set.exerciseId != null) {
          allExerciseIds.add(set.exerciseId!);
        }
      }

      // Load all exercises at once
      if (allExerciseIds.isNotEmpty) {
        await ref.read(exerciseProvider.notifier).loadExercises();
        final allExercises = ref.read(exerciseProvider).exercises;

        final exerciseMap = <String, Exercise>{};
        for (final exercise in allExercises) {
          if (allExerciseIds.contains(exercise.id)) {
            exerciseMap[exercise.id] = exercise;
          }
        }

        setState(() {
          _workoutDetail = workoutDetail;
          _exercises = exerciseMap;
          _isLoading = false;
        });
      } else {
        setState(() {
          _workoutDetail = workoutDetail;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getWorkoutTitle() {
    if (_workoutDetail == null) return 'Workout Details';

    final status = _workoutDetail!.status;
    final scheduledDate = _workoutDetail!.scheduledDate;
    final completedDate = _workoutDetail!.completedDate;

    // For completed workouts, use completion date
    if (status == 'COMPLETED' && completedDate != null) {
      final date = completedDate;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final workoutDay = DateTime(date.year, date.month, date.day);

      if (workoutDay == today) {
        return 'Today\'s Completed Workout';
      } else {
        // Format: "Workout - Jan 10, 2026"
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return 'Workout - ${months[date.month - 1]} ${date.day}, ${date.year}';
      }
    }

    // For scheduled workouts, use scheduled date
    if (status == 'SCHEDULED') {
      final date = scheduledDate;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final workoutDay = DateTime(date.year, date.month, date.day);

      if (workoutDay == today) {
        return 'Today\'s Workout';
      } else {
        // Format: "Workout - Jan 10, 2026"
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return 'Workout - ${months[date.month - 1]} ${date.day}, ${date.year}';
      }
    }

    return 'Workout Details';
  }

  String _formatCompletionDate() {
    if (_workoutDetail?.completedDate == null) return '';

    final date = _workoutDetail!.completedDate!;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_workoutDetail != null
            ? DateFormat('EEEE, MMM d').format(_workoutDetail!.scheduledDate)
            : 'Workout Details'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Home',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _workoutDetail != null &&
              _workoutDetail!.status == 'SCHEDULED'
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading workout',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadWorkoutDetail,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_workoutDetail == null) {
      return const Center(child: Text('No workout found'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          _buildWorkoutOverview(),
          const SizedBox(height: 100), // Space for bottom bar
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final workout = _workoutDetail!;
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final isCompleted = workout.status == 'COMPLETED';

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Completion status banner for completed workouts
          if (workout.status == 'COMPLETED' && workout.completedDate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Completed on ${_formatCompletionDate()}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            _getWorkoutTitle(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            dateFormat.format(workout.scheduledDate),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                Icons.repeat,
                'Cycle ${workout.cycleNumber}',
              ),
              _buildInfoChip(
                Icons.calendar_today,
                _getDisplayWeekType(workout.weekType),
              ),
              _buildInfoChip(
                Icons.fitness_center,
                '${workout.mainLifts.length} ${workout.mainLifts.length == 1 ? "Lift" : "Lifts"}',
              ),
            ],
          ),
          if (isCompleted && workout.completedDate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Text(
                    'Completed on ${DateFormat('MMM d, yyyy').format(workout.completedDate!)}',
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.blue.shade900,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutOverview() {
    final workout = _workoutDetail!;

    // Aggregate all sets from all lifts
    int allWarmupSetsCount = 0;
    int allMainSetsCount = 0;
    int allAccessorySetsCount = workout.accessorySets.length;

    for (final sets in workout.setsByLift.values) {
      allWarmupSetsCount += sets.warmupSets.length;
      allMainSetsCount += sets.mainSets.length;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary at top
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  Icons.local_fire_department,
                  '$allWarmupSetsCount',
                  'Warmup',
                  Colors.orange,
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                _buildSummaryItem(
                  Icons.fitness_center,
                  '$allMainSetsCount',
                  'Working',
                  Colors.blue,
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                _buildSummaryItem(
                  Icons.add_circle_outline,
                  '$allAccessorySetsCount',
                  'Accessory',
                  Colors.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main Lift Cards (one per lift) - main lifts only, no accessories
          for (final mainLift in workout.mainLifts)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildMainLiftCard(mainLift, workout.setsByLift[mainLift.liftType]!),
            ),

          // Accessory exercises section - displayed after all main lifts
          ..._buildAllAccessoriesSection(workout),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String count, String label, MaterialColor color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color.shade900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildMainLiftCard(WorkoutMainLift mainLift, WorkoutSetsForLift sets) {
    final warmupSets = sets.warmupSets;
    final mainSets = sets.mainSets;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    color: Colors.blue.shade900,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mainLift.displayLiftType,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Main Lift - ${mainLift.currentTrainingMax.toInt()} lbs TM',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Warmup summary
            if (warmupSets.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.local_fire_department, size: 18, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Warmup: ${warmupSets.length} sets',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: warmupSets.map((set) {
                  final isCompleted = _workoutDetail!.status == 'COMPLETED';
                  final displayText = isCompleted
                      ? '${set.actualWeight?.toInt() ?? 0} lbs × ${set.actualReps ?? 0}${set.isTargetMet == true ? " ✓" : set.isTargetMet == false ? " ⚠" : ""}'
                      : '${set.prescribedWeight?.toInt() ?? 0} lbs × ${set.prescribedReps}';
                  return _buildCompactSetChip(
                    displayText,
                    Colors.orange.shade50,
                    Colors.orange.shade700,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Working sets summary
            Row(
              children: [
                Icon(Icons.fitness_center, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Working Sets: ${mainSets.length} sets',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...mainSets.map((set) {
              final isAmrap = set.setType == 'amrap';
              final isCompleted = _workoutDetail!.status == 'COMPLETED';
              final percentage = set.percentageOfTm != null
                  ? '${(set.percentageOfTm! * 100).toInt()}%'
                  : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${set.setNumber}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (percentage.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              percentage,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (isCompleted) ...[
                          // Actual performance
                          Icon(Icons.fitness_center, size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '${set.actualWeight?.toInt() ?? 0} lbs × ${set.actualReps ?? 0}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (set.isTargetMet != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              set.isTargetMet! ? Icons.check_circle : Icons.warning,
                              size: 14,
                              color: set.isTargetMet! ? Colors.green : Colors.orange,
                            ),
                          ],
                        ] else ...[
                          // Prescribed
                          Text(
                            '${set.prescribedWeight?.toInt() ?? 0} lbs',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '×',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isAmrap ? '${set.prescribedReps}+' : '${set.prescribedReps}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                        if (isAmrap) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'AMRAP',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isCompleted) ...[
                      // Show target below for completed workouts
                      Padding(
                        padding: const EdgeInsets.only(left: 44, top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.flag_outlined, size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Target: ${set.prescribedWeight?.toInt() ?? 0} lbs × ${isAmrap ? "${set.prescribedReps}+" : set.prescribedReps}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),

          ],
        ),
      ),
    );
  }

  List<Widget> _buildAllAccessoriesSection(WorkoutDetail workout) {
    // Accessory sets are now at workout level
    if (workout.accessorySets.isEmpty) {
      return [];
    }

    // _buildAccessoryCircuits already handles spacing between circuits
    return _buildAccessoryCircuits(workout.accessorySets);
  }

  List<Widget> _buildAccessoryCircuits(List<WorkoutSet> accessorySets) {
    // Group accessory sets by exercise first
    final groupedByExercise = <String, List<WorkoutSet>>{};
    for (final set in accessorySets) {
      final key = set.exerciseId ?? 'exercise_${accessorySets.indexOf(set)}';
      groupedByExercise.putIfAbsent(key, () => []).add(set);
    }

    // Now separate by circuit group
    final standaloneExercises = <String, List<WorkoutSet>>{};
    final circuitGroups = <int, Map<String, List<WorkoutSet>>>{};

    for (final entry in groupedByExercise.entries) {
      final exerciseId = entry.key;
      final sets = entry.value;
      final circuitGroup = sets.first.circuitGroup;

      if (circuitGroup == null) {
        standaloneExercises[exerciseId] = sets;
      } else {
        circuitGroups.putIfAbsent(circuitGroup, () => {});
        circuitGroups[circuitGroup]![exerciseId] = sets;
      }
    }

    final widgets = <Widget>[];

    // Build standalone exercises (if any)
    if (standaloneExercises.isNotEmpty) {
      widgets.add(_buildStandaloneAccessoriesCard(standaloneExercises));
    }

    // Build circuit cards for each circuit group
    final sortedCircuitNums = circuitGroups.keys.toList()..sort();
    for (final circuitNum in sortedCircuitNums) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 12));
      }
      widgets.add(_buildCircuitCard(circuitNum, circuitGroups[circuitNum]!));
    }

    return widgets;
  }

  Widget _buildStandaloneAccessoriesCard(Map<String, List<WorkoutSet>> exercises) {
    final isCompleted = _workoutDetail!.status == 'COMPLETED';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade300, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: Colors.green.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Icon(Icons.fitness_center, size: 20, color: Colors.green.shade800),
                const SizedBox(width: 8),
                Text(
                  'Accessory Exercises',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.green.shade900,
                  ),
                ),
              ],
            ),
          ),
          // Exercises
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: exercises.entries.toList().asMap().entries.map((indexedEntry) {
                final index = indexedEntry.key;
                final entry = indexedEntry.value;
                final exerciseId = entry.key;
                final sets = entry.value;
                final exercise = _exercises[exerciseId];
                final exerciseName = exercise?.name ?? 'Accessory Exercise';

                return Padding(
                  padding: EdgeInsets.only(bottom: index < exercises.length - 1 ? 12 : 0),
                  child: _buildCircuitExerciseRow(
                    exerciseName: exerciseName,
                    sets: sets,
                    exerciseNumber: index + 1,
                    isCompleted: isCompleted,
                    color: Colors.green,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircuitCard(int circuitNum, Map<String, List<WorkoutSet>> exercises) {
    final isCompleted = _workoutDetail!.status == 'COMPLETED';
    final exerciseCount = exercises.length;

    return Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Icon(Icons.repeat, size: 20, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Text(
                  'Circuit $circuitNum',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$exerciseCount exercises',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Instruction text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Alternate between exercises with minimal rest',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Circuit exercises
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: exercises.entries.toList().asMap().entries.map((indexedEntry) {
                final index = indexedEntry.key;
                final entry = indexedEntry.value;
                final exerciseId = entry.key;
                final sets = entry.value;
                final exercise = _exercises[exerciseId];
                final exerciseName = exercise?.name ?? 'Accessory Exercise';
                final isLast = index == exercises.length - 1;

                return Column(
                  children: [
                    _buildCircuitExerciseRow(
                      exerciseName: exerciseName,
                      sets: sets,
                      exerciseNumber: index + 1,
                      isCompleted: isCompleted,
                    ),
                    if (!isLast) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Icon(Icons.arrow_downward, size: 16, color: Colors.orange.shade400),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.orange.shade200,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircuitExerciseRow({
    required String exerciseName,
    required List<WorkoutSet> sets,
    required int exerciseNumber,
    required bool isCompleted,
    MaterialColor color = Colors.orange,
  }) {
    final setCount = sets.length;
    final prescribedReps = sets.first.prescribedReps ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Exercise number badge
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$exerciseNumber',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color.shade900,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exerciseName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              if (isCompleted) ...[
                // Show actual performance
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: sets.map((set) {
                    final reps = set.actualReps ?? 0;
                    final weight = set.actualWeight?.toInt() ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.shade200),
                      ),
                      child: Text(
                        '$reps @ $weight lbs',
                        style: TextStyle(
                          fontSize: 12,
                          color: color.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                Text(
                  'Target: $setCount × $prescribedReps reps',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ] else ...[
                // Show prescribed
                Row(
                  children: [
                    Icon(Icons.fitness_center, size: 14, color: color.shade700),
                    const SizedBox(width: 6),
                    Text(
                      '$setCount sets × $prescribedReps reps',
                      style: TextStyle(
                        fontSize: 13,
                        color: color.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSetChip(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }


  Widget _buildBottomBar() {
    final workout = _workoutDetail!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: () {
                context.push('/workouts/${workout.id}/log');
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(
                workout.mainLifts.length > 1
                    ? 'Start Workout (${workout.mainLifts.length} Lifts)'
                    : 'Start Workout',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showSkipConfirmationDialog,
              icon: Icon(Icons.skip_next, color: Colors.grey[600]),
              label: Text(
                'Skip Workout',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSkipConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Workout?'),
        content: const Text(
          'Are you sure you want to skip this workout? '
          'This marks the workout as intentionally skipped (e.g., due to travel, illness, or scheduling conflicts).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Skip Workout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _skipWorkout();
    }
  }

  Future<void> _skipWorkout() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.skipWorkout(widget.workoutId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout skipped'),
            backgroundColor: Colors.orange,
          ),
        );
        // Go back to previous screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to skip workout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getDisplayWeekType(String weekType) {
    switch (weekType) {
      case 'week_1_5s':
        return 'Week 1: 5s';
      case 'week_2_3s':
        return 'Week 2: 3s';
      case 'week_3_531':
        return 'Week 3: 5/3/1';
      case 'week_4_deload':
        return 'Week 4: Deload';
      default:
        return weekType;
    }
  }
}
