import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/workout_models.dart';
import '../../models/exercise_models.dart';
import '../../models/workout_analysis_models.dart';
import '../../services/workout_session_service.dart';
import '../../services/audio_service.dart';
import '../../providers/program_provider.dart';
import '../../providers/exercise_provider.dart';

class WorkoutLoggingScreen extends ConsumerStatefulWidget {
  final String workoutId;

  const WorkoutLoggingScreen({
    super.key,
    required this.workoutId,
  });

  @override
  ConsumerState<WorkoutLoggingScreen> createState() =>
      _WorkoutLoggingScreenState();
}

class _WorkoutLoggingScreenState extends ConsumerState<WorkoutLoggingScreen>
    with WidgetsBindingObserver {
  WorkoutDetail? _workoutDetail;
  bool _isLoading = true;
  String? _error;
  Map<String, Exercise> _exercises = {};

  List<WorkoutSet> _allSets = [];
  Map<int, String> _setIndexToLiftType = {}; // Maps set index to lift type
  int _currentSetIndex = 0;
  final List<Map<String, dynamic>> _loggedSets = [];

  // Rest timer
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _isResting = false;

  // Current set input
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();

  // Session restoration

  // Audio service for timer beep
  final _audioService = AudioService();

  /// Interleaves circuit exercises so they alternate (Ex1 set1, Ex2 set1, Ex1 set2, Ex2 set2, etc.)
  /// Standalone exercises (circuitGroup == null) come first, then circuits in order.
  List<WorkoutSet> _interleaveCircuitSets(List<WorkoutSet> accessorySets) {
    if (accessorySets.isEmpty) return [];

    // Group by exercise and circuit
    final exerciseGroups = <String, List<WorkoutSet>>{};
    for (final set in accessorySets) {
      final key = set.exerciseId ?? 'unknown_${accessorySets.indexOf(set)}';
      exerciseGroups.putIfAbsent(key, () => []).add(set);
    }

    // Separate standalone and circuit exercises
    final standaloneGroups = <String, List<WorkoutSet>>{};
    final circuitGroups = <int, Map<String, List<WorkoutSet>>>{};

    for (final entry in exerciseGroups.entries) {
      final exerciseId = entry.key;
      final sets = entry.value;
      final circuitGroup = sets.first.circuitGroup;

      if (circuitGroup == null) {
        standaloneGroups[exerciseId] = sets;
      } else {
        circuitGroups.putIfAbsent(circuitGroup, () => {});
        circuitGroups[circuitGroup]![exerciseId] = sets;
      }
    }

    final result = <WorkoutSet>[];

    // Add standalone exercises first (in original order)
    for (final sets in standaloneGroups.values) {
      result.addAll(sets);
    }

    // Add circuit exercises interleaved
    final sortedCircuits = circuitGroups.keys.toList()..sort();
    for (final circuitNum in sortedCircuits) {
      final circuitExercises = circuitGroups[circuitNum]!;
      final exerciseIds = circuitExercises.keys.toList();

      if (exerciseIds.isEmpty) continue;

      // Find the maximum number of sets in this circuit
      int maxSets = 0;
      for (final sets in circuitExercises.values) {
        if (sets.length > maxSets) maxSets = sets.length;
      }

      // Interleave: for each set number, add one set from each exercise
      for (int setNum = 0; setNum < maxSets; setNum++) {
        for (final exerciseId in exerciseIds) {
          final sets = circuitExercises[exerciseId]!;
          if (setNum < sets.length) {
            result.add(sets[setNum]);
          }
        }
      }
    }

    return result;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWorkoutDetail();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimer?.cancel();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save session when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveSession();
    }
  }

  /// Save current workout progress to local storage.
  Future<void> _saveSession() async {
    if (_workoutDetail == null || _allSets.isEmpty) return;

    await WorkoutSessionService.saveSession(
      workoutId: widget.workoutId,
      currentSetIndex: _currentSetIndex,
      loggedSets: _loggedSets,
      restSecondsRemaining: _restSecondsRemaining,
      isResting: _isResting,
    );
  }

  /// Restore session from local storage if available.
  Future<void> _restoreSession() async {
    final session = await WorkoutSessionService.loadSession(widget.workoutId);
    if (session == null || session.loggedSets.isEmpty) return;

    // Show restoration dialog
    if (!mounted) return;

    final shouldRestore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore, color: Colors.blue),
            SizedBox(width: 12),
            Text('Resume Workout?'),
          ],
        ),
        content: Text(
          'You have ${session.loggedSets.length} set(s) saved from a previous session. '
          'Would you like to continue where you left off?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await WorkoutSessionService.clearSession(widget.workoutId);
              Navigator.pop(context, false);
            },
            child: const Text('Start Fresh'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resume'),
          ),
        ],
      ),
    );

    if (shouldRestore == true && mounted) {
      setState(() {
        _currentSetIndex = session.currentSetIndex;
        _loggedSets.clear();
        _loggedSets.addAll(session.loggedSets);
      });

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Resumed from set ${session.currentSetIndex + 1}'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadWorkoutDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final detail = await apiService.getWorkoutDetail(widget.workoutId);

      // Collect all exercise IDs from accessory sets
      final exerciseIds = <String>{};
      for (final set in detail.accessorySets) {
        if (set.exerciseId != null) {
          exerciseIds.add(set.exerciseId!);
        }
      }

      // Build flat list of sets while tracking lift types
      // Order: ALL main lifts (warmup + working sets) first, then ALL accessories
      final allSets = <WorkoutSet>[];
      final setIndexToLiftType = <int, String>{};
      int index = 0;

      // First pass: Add all warmup and main sets for ALL lifts
      for (final mainLift in detail.mainLifts) {
        final liftType = mainLift.liftType;
        final sets = detail.setsByLift[liftType]!;

        for (final set in [...sets.warmupSets, ...sets.mainSets]) {
          allSets.add(set);
          setIndexToLiftType[index] = liftType;
          index++;
        }
      }

      // Second pass: Add all accessory sets (now at workout level)
      final interleavedAccessories = _interleaveCircuitSets(detail.accessorySets);
      // Use first lift type for accessories (they're workout-level, not lift-specific)
      final accessoryLiftType = detail.mainLifts.isNotEmpty ? detail.mainLifts.first.liftType : '';
      for (final set in interleavedAccessories) {
        allSets.add(set);
        setIndexToLiftType[index] = accessoryLiftType;
        index++;
      }

      if (exerciseIds.isNotEmpty) {
        await ref.read(exerciseProvider.notifier).loadExercises();
        final allExercises = ref.read(exerciseProvider).exercises;

        final exerciseMap = <String, Exercise>{};
        for (final exercise in allExercises) {
          if (exerciseIds.contains(exercise.id)) {
            exerciseMap[exercise.id] = exercise;
          }
        }

        setState(() {
          _workoutDetail = detail;
          _exercises = exerciseMap;
          _allSets = allSets;
          _setIndexToLiftType = setIndexToLiftType;
          _isLoading = false;
        });
      } else {
        setState(() {
          _workoutDetail = detail;
          _allSets = allSets;
          _setIndexToLiftType = setIndexToLiftType;
          _isLoading = false;
        });
      }

      // Check for saved session after workout data is loaded
      await _restoreSession();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restSecondsRemaining = seconds;
      _isResting = true;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_restSecondsRemaining > 0) {
          _restSecondsRemaining--;
          // Play beep when timer reaches 0
          if (_restSecondsRemaining == 0) {
            _audioService.playTimerBeep();
          }
        } else {
          _isResting = false;
          timer.cancel();
        }
      });
    });
  }

  void _skipRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restSecondsRemaining = 0;
    });
  }

  void _logCurrentSet() {
    final currentSet = _allSets[_currentSetIndex];
    final isAccessory = currentSet.setType == 'accessory';

    // Validate reps
    if (_repsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter reps completed')),
      );
      return;
    }

    final reps = int.tryParse(_repsController.text);
    if (reps == null || reps < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number for reps')),
      );
      return;
    }

    // For accessories, validate weight input
    double weight;
    if (isAccessory) {
      if (_weightController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter weight used (0 for bodyweight)')),
        );
        return;
      }

      final parsedWeight = double.tryParse(_weightController.text);
      if (parsedWeight == null || parsedWeight < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid weight (0 or greater)')),
        );
        return;
      }
      weight = parsedWeight;
    } else {
      // For main lifts and warmups, use prescribed weight
      weight = currentSet.prescribedWeight ?? 0.0;
    }

    // Log the set with backend-compatible format
    _loggedSets.add({
      'exercise_id': currentSet.exerciseId ?? 'main_lift',
      'set_type': currentSet.setType,
      'set_number': currentSet.setNumber,
      'lift_type': _setIndexToLiftType[_currentSetIndex], // Include lift type for multi-lift workouts
      'actual_reps': reps,
      'actual_weight': weight,
      'weight_unit': 'lbs',
      'prescribed_reps': currentSet.prescribedReps,
      'prescribed_weight': currentSet.prescribedWeight,
    });

    // Check if target was met (for working sets only, not warmup or accessory)
    final isWorkingSet = currentSet.setType == 'working' || currentSet.setType == 'amrap';
    final prescribedReps = currentSet.prescribedReps ?? 0;
    final targetMet = reps >= prescribedReps;

    // Show feedback for missed target on working sets
    if (isWorkingSet && !targetMet && mounted) {
      final deficit = prescribedReps - reps;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Missed target by $deficit rep${deficit > 1 ? 's' : ''} (${reps}/${prescribedReps})',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Clear inputs
    _repsController.clear();
    _weightController.clear();

    // Move to next set or finish
    if (_currentSetIndex < _allSets.length - 1) {
      setState(() {
        _currentSetIndex++;
        // Pre-fill weight for accessories with prescribed weight
        final nextSet = _allSets[_currentSetIndex];
        if (nextSet.setType == 'accessory' && nextSet.prescribedWeight != null) {
          _weightController.text = nextSet.prescribedWeight!.toInt().toString();
        }
      });

      // Start rest timer based on set type
      final restSeconds = currentSet.setType == 'warmup'
          ? 60
          : currentSet.setType == 'accessory'
              ? 90
              : 180;
      _startRestTimer(restSeconds);

      // Save session after each set for background persistence
      _saveSession();
    } else {
      _completeWorkout();
    }
  }

  Future<void> _completeWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Workout?'),
        content: const Text(
          'Are you sure you want to complete this workout? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.completeWorkout(
        widget.workoutId,
        _loggedSets,
        completedDate: DateTime.now(),
      );

      // Clear saved session on successful completion
      await WorkoutSessionService.clearSession(widget.workoutId);

      if (mounted) {
        // Show the analysis dialog
        await _showWorkoutAnalysisDialog(result.analysis);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing workout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showWorkoutAnalysisDialog(WorkoutAnalysis analysis) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WorkoutAnalysisDialog(analysis: analysis),
    );

    if (mounted) {
      context.go('/workouts');
    }
  }

  Future<void> _endCurrentExercise() async {
    // Cancel rest timer if active
    if (_isResting) {
      _restTimer?.cancel();
      setState(() {
        _isResting = false;
        _restSecondsRemaining = 0;
      });
    }

    // 1. Get current lift/exercise identifier
    final currentLiftType = _setIndexToLiftType[_currentSetIndex];
    if (currentLiftType == null) return;

    // 2. Find all remaining sets for this lift/exercise
    List<int> setsToEnd = [];
    for (int i = _currentSetIndex; i < _allSets.length; i++) {
      if (_setIndexToLiftType[i] == currentLiftType) {
        setsToEnd.add(i);
      }
    }

    // 3. Show confirmation dialog with count
    final confirmed = await _showEndSetConfirmation(
      liftType: currentLiftType,
      setCount: setsToEnd.length,
    );

    if (!confirmed) return;

    // 4. Log all remaining sets of current exercise with 0 reps
    for (final setIndex in setsToEnd) {
      final set = _allSets[setIndex];
      final isAccessory = set.setType == 'accessory';

      _loggedSets.add({
        'exercise_id': set.exerciseId ?? 'main_lift',
        'set_type': set.setType,
        'set_number': set.setNumber,
        'lift_type': currentLiftType,
        'actual_reps': 0,
        'actual_weight': isAccessory ? 0.0 : (set.prescribedWeight ?? 0.0),
        'weight_unit': 'lbs',
        'prescribed_reps': set.prescribedReps,
        'prescribed_weight': isAccessory ? null : set.prescribedWeight,
      });
    }

    // 5. Find next different exercise/lift
    int? nextDifferentIndex;
    for (int i = _currentSetIndex + 1; i < _allSets.length; i++) {
      if (_setIndexToLiftType[i] != currentLiftType) {
        nextDifferentIndex = i;
        break;
      }
    }

    // 6. Jump to next exercise or complete workout
    if (nextDifferentIndex != null) {
      setState(() {
        _currentSetIndex = nextDifferentIndex!;
        _repsController.clear();
        _weightController.clear();
        // Pre-fill weight for accessories with prescribed weight
        final nextSet = _allSets[_currentSetIndex];
        if (nextSet.setType == 'accessory' && nextSet.prescribedWeight != null) {
          _weightController.text = nextSet.prescribedWeight!.toInt().toString();
        }
        // No rest timer - jump directly
      });
      // Save session after ending exercise
      _saveSession();
    } else {
      // No more exercises, complete workout
      _completeWorkout();
    }
  }

  Future<void> _endEntireWorkout() async {
    // Cancel rest timer if active
    if (_isResting) {
      _restTimer?.cancel();
      setState(() {
        _isResting = false;
        _restSecondsRemaining = 0;
      });
    }

    // 1. Count remaining sets
    final remainingSets = _allSets.length - _currentSetIndex;

    // 2. Show confirmation dialog
    final confirmed = await _showEndWorkoutConfirmation(
      setCount: remainingSets,
    );

    if (!confirmed) return;

    // 3. Log all remaining sets with 0 reps
    for (int i = _currentSetIndex; i < _allSets.length; i++) {
      final set = _allSets[i];
      final liftType = _setIndexToLiftType[i];
      final isAccessory = set.setType == 'accessory';

      _loggedSets.add({
        'exercise_id': set.exerciseId ?? 'main_lift',
        'set_type': set.setType,
        'set_number': set.setNumber,
        'lift_type': liftType,
        'actual_reps': 0,
        'actual_weight': isAccessory ? 0.0 : (set.prescribedWeight ?? 0.0),
        'weight_unit': 'lbs',
        'prescribed_reps': set.prescribedReps,
        'prescribed_weight': isAccessory ? null : set.prescribedWeight,
      });
    }

    // 4. Complete the workout
    _completeWorkout();
  }

  Future<bool> _showEndSetConfirmation({
    required String liftType,
    required int setCount,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Exercise?'),
        content: Text(
          'This will record 0 reps for all remaining $setCount set(s) of $liftType. '
          'You will move to the next exercise.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Exercise'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _showEndWorkoutConfirmation({
    required int setCount,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Workout?'),
        content: Text(
          'This will record 0 reps for all remaining $setCount set(s) and complete the workout. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Workout'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Workout'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            final hasProgress = _loggedSets.isNotEmpty;

            if (!hasProgress) {
              // No progress, just exit
              await WorkoutSessionService.clearSession(widget.workoutId);
              if (mounted) Navigator.pop(context);
              return;
            }

            final result = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Exit Workout?'),
                content: const Text(
                  'Your progress is automatically saved. You can resume later or discard it.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'cancel'),
                    child: const Text('Continue Workout'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'save'),
                    child: const Text('Save & Exit'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'discard'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            );

            if (result == 'save' && mounted) {
              await _saveSession();
              Navigator.pop(context);
            } else if (result == 'discard' && mounted) {
              await WorkoutSessionService.clearSession(widget.workoutId);
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _buildBody(),
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
            Text('Error loading workout'),
            const SizedBox(height: 8),
            Text(_error!),
          ],
        ),
      );
    }

    if (_workoutDetail == null || _allSets.isEmpty) {
      return const Center(child: Text('No sets available'));
    }

    return Column(
      children: [
        _buildProgressBar(),
        if (_isResting) _buildRestTimer(),
        Expanded(child: _buildCurrentSet()),
        _buildBottomControls(),
      ],
    );
  }

  Widget _buildProgressBar() {
    // Count missed targets in working sets
    int missedTargets = 0;
    for (final loggedSet in _loggedSets) {
      final setType = loggedSet['set_type'] as String?;
      if (setType == 'working' || setType == 'amrap') {
        final actual = loggedSet['actual_reps'] as int? ?? 0;
        final prescribed = loggedSet['prescribed_reps'] as int? ?? 0;
        if (actual < prescribed) {
          missedTargets++;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Set ${_currentSetIndex + 1} of ${_allSets.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Row(
                children: [
                  if (missedTargets > 0) ...[
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      '$missedTargets missed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    '${_loggedSets.length} completed',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _currentSetIndex / _allSets.length,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
          ),
          // Show set status indicators for working sets
          if (_loggedSets.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSetStatusIndicators(),
          ],
        ],
      ),
    );
  }

  Widget _buildSetStatusIndicators() {
    // Only show indicators for working sets (not warmup or accessory)
    final workingSets = <Map<String, dynamic>>[];
    for (int i = 0; i < _loggedSets.length; i++) {
      final loggedSet = _loggedSets[i];
      final setType = loggedSet['set_type'] as String?;
      if (setType == 'working' || setType == 'amrap') {
        workingSets.add(loggedSet);
      }
    }

    if (workingSets.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Working Sets: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          ...workingSets.asMap().entries.map((entry) {
            final index = entry.key;
            final loggedSet = entry.value;
            final actual = loggedSet['actual_reps'] as int? ?? 0;
            final prescribed = loggedSet['prescribed_reps'] as int? ?? 0;
            final targetMet = actual >= prescribed;

            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'Set ${index + 1}: $actual/$prescribed reps',
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: targetMet ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: targetMet ? Colors.green.shade400 : Colors.orange.shade400,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      targetMet ? Icons.check : Icons.close,
                      size: 14,
                      color: targetMet ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRestTimer() {
    final minutes = _restSecondsRemaining ~/ 60;
    final seconds = _restSecondsRemaining % 60;

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.orange.shade50,
      child: Column(
        children: [
          Text(
            'Rest Timer',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _skipRestTimer,
            child: const Text('Skip Rest'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSet() {
    final currentSet = _allSets[_currentSetIndex];
    final isWarmup = currentSet.setType == 'warmup';
    final isAmrap = currentSet.setType == 'amrap';
    final isAccessory = currentSet.setType == 'accessory';

    // For accessories, build a different UI
    if (isAccessory) {
      return _buildAccessorySet(currentSet);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Set type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isWarmup ? Colors.grey.shade200 : Colors.blue.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isWarmup
                  ? 'WARMUP SET'
                  : isAmrap
                      ? 'AMRAP SET'
                      : 'WORKING SET',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isWarmup ? Colors.grey.shade700 : Colors.blue.shade900,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Set number
          Text(
            'Set ${currentSet.setNumber}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 32),

          // Target reps
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  'Target',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  isAmrap
                      ? '${currentSet.prescribedReps}+ reps'
                      : '${currentSet.prescribedReps} reps',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  '${currentSet.prescribedWeight?.toInt() ?? 0} lbs',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _calculatePlates(currentSet.prescribedWeight ?? 0),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Reps input
          Column(
            children: [
              Text(
                'Reps Completed',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: !_isResting,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  decoration: InputDecoration(
                    hintText: '0',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _logCurrentSet(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccessorySet(WorkoutSet currentSet) {
    final exerciseName = currentSet.exerciseId != null && _exercises.containsKey(currentSet.exerciseId)
        ? _exercises[currentSet.exerciseId]!.name
        : 'Accessory Exercise';

    final isCircuit = currentSet.circuitGroup != null;
    final circuitColor = Colors.orange;
    final standardColor = Colors.green;
    final badgeColor = isCircuit ? circuitColor : standardColor;

    // Find next exercise in circuit (if any)
    String? nextExerciseName;
    if (isCircuit && _currentSetIndex < _allSets.length - 1) {
      final nextSet = _allSets[_currentSetIndex + 1];
      if (nextSet.circuitGroup == currentSet.circuitGroup &&
          nextSet.exerciseId != currentSet.exerciseId) {
        nextExerciseName = nextSet.exerciseId != null && _exercises.containsKey(nextSet.exerciseId)
            ? _exercises[nextSet.exerciseId]!.name
            : 'Next Exercise';
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Accessory/Circuit badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCircuit) ...[
                  Icon(Icons.repeat, size: 16, color: badgeColor.shade800),
                  const SizedBox(width: 6),
                ],
                Text(
                  isCircuit ? 'CIRCUIT ${currentSet.circuitGroup}' : 'ACCESSORY EXERCISE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: badgeColor.shade800,
                  ),
                ),
              ],
            ),
          ),

          // Next exercise indicator for circuits
          if (isCircuit && nextExerciseName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: circuitColor.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: circuitColor.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward, size: 14, color: circuitColor.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Next: $nextExerciseName',
                    style: TextStyle(
                      fontSize: 12,
                      color: circuitColor.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Exercise name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fitness_center, size: 28),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  exerciseName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Set number
          Text(
            'Set ${currentSet.setNumber}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 32),

          // Target reps (no weight prescribed for accessories)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: badgeColor.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: badgeColor.shade200, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  'Target',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${currentSet.prescribedReps ?? 0} reps',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: badgeColor.shade900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentSet.prescribedWeight != null
                      ? 'Weight: ${currentSet.prescribedWeight!.toInt()} lbs'
                      : 'Weight: Your choice (0 for bodyweight)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Weight input
          Column(
            children: [
              Text(
                'Weight Used (lbs)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter 0 for bodyweight exercises',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      autofocus: !_isResting,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      decoration: InputDecoration(
                        hintText: '0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.green.shade300, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick "0" button for bodyweight
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _weightController.text = '0';
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      side: BorderSide(color: Colors.green.shade300),
                    ),
                    child: const Text('BW'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Reps input
          Column(
            children: [
              Text(
                'Reps Completed',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  decoration: InputDecoration(
                    hintText: '0',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green.shade300, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _logCurrentSet(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
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
            // End Set and End Workout buttons
            Row(
              children: [
                // End Set button
                Expanded(
                  child: TextButton.icon(
                    onPressed: _endCurrentExercise,
                    icon: const Icon(Icons.skip_next, size: 18),
                    label: const Text('End Exercise'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // End Workout button
                Expanded(
                  child: TextButton.icon(
                    onPressed: _endEntireWorkout,
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('End Workout'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Primary action button (existing)
            FilledButton(
              onPressed: _isResting ? null : _logCurrentSet,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _currentSetIndex == _allSets.length - 1
                    ? 'Complete Workout'
                    : 'Log Set & Continue',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calculatePlates(double targetWeight) {
    const barWeight = 45.0;
    final weightPerSide = (targetWeight - barWeight) / 2;

    if (weightPerSide <= 0) {
      return 'Bar only';
    }

    final plates = <double>[];
    var remaining = weightPerSide;
    // TODO: Make available plates configurable per user
    final availablePlates = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5, 1.0, 0.75, 0.5, 0.25];

    for (final plate in availablePlates) {
      while (remaining >= plate) {
        plates.add(plate);
        remaining -= plate;
      }
    }

    if (plates.isEmpty) {
      return 'Bar only';
    }

    final plateStr = plates
        .map((p) => p == p.toInt() ? p.toInt().toString() : p.toString())
        .join(' + ');
    return '$plateStr per side';
  }
}

/// Dialog showing workout analysis and recommendations.
class _WorkoutAnalysisDialog extends StatelessWidget {
  final WorkoutAnalysis analysis;

  const _WorkoutAnalysisDialog({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            analysis.overallSuccess
                ? Icons.check_circle
                : Icons.info_outline,
            color: analysis.overallSuccess ? Colors.green : Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Workout Complete'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: analysis.overallSuccess
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: analysis.overallSuccess
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    analysis.overallSuccess
                        ? Icons.thumb_up
                        : Icons.trending_flat,
                    color: analysis.overallSuccess
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      analysis.summary,
                      style: TextStyle(
                        color: analysis.overallSuccess
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Recommendations (if any)
            if (analysis.hasRecommendations) ...[
              const SizedBox(height: 16),
              const Text(
                'Recommendations',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...analysis.liftsWithRecommendations.map(
                (lift) => _buildRecommendationCard(lift),
              ),
            ],

            // Cycle-level analysis (if there are failures across the cycle)
            if (analysis.hasCycleRecommendation) ...[
              const SizedBox(height: 16),
              _buildCycleAnalysisCard(analysis.cycleAnalysis!),
            ],

            // Lift summary
            const SizedBox(height: 16),
            const Text(
              'Performance Summary',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ...analysis.lifts.map((lift) => _buildLiftSummary(lift)),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(LiftAnalysis lift) {
    Color bgColor;
    Color borderColor;
    Color iconColor;
    IconData icon;

    switch (lift.recommendationType) {
      case 'critical':
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        iconColor = Colors.red.shade700;
        icon = Icons.warning;
        break;
      case 'warning':
        bgColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        iconColor = Colors.orange.shade700;
        icon = Icons.info;
        break;
      default:
        bgColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade200;
        iconColor = Colors.blue.shade700;
        icon = Icons.lightbulb;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                lift.displayLiftType,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lift.recommendation ?? '',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiftSummary(LiftAnalysis lift) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            lift.allTargetsMet ? Icons.check_circle : Icons.remove_circle,
            color: lift.allTargetsMet ? Colors.green : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lift.displayLiftType,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (lift.amrapReps != null && lift.amrapMinimum != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (lift.amrapExceededMinimum ?? true)
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${lift.amrapReps}/${lift.amrapMinimum}+ reps',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: (lift.amrapExceededMinimum ?? true)
                      ? Colors.green.shade800
                      : Colors.orange.shade800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCycleAnalysisCard(CycleFailedRepsAnalysis cycleAnalysis) {
    final isDeload = cycleAnalysis.isDeloadRecommended;
    final bgColor = isDeload ? Colors.red.shade50 : Colors.purple.shade50;
    final borderColor = isDeload ? Colors.red.shade300 : Colors.purple.shade300;
    final iconColor = isDeload ? Colors.red.shade700 : Colors.purple.shade700;
    final icon = isDeload ? Icons.refresh : Icons.trending_down;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDeload ? 'Cycle Analysis: Deload Recommended' : 'Cycle Analysis: TM Adjustment',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cycleAnalysis.message,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
