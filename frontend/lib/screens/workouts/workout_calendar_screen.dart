import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/workout_models.dart';
import '../../providers/workout_provider.dart';
import '../../providers/program_provider.dart';

class WorkoutCalendarScreen extends ConsumerStatefulWidget {
  final String? programId;
  final DateTime? initialWeekStart;

  const WorkoutCalendarScreen({
    super.key,
    this.programId,
    this.initialWeekStart,
  });

  @override
  ConsumerState<WorkoutCalendarScreen> createState() =>
      _WorkoutCalendarScreenState();
}

class _WorkoutCalendarScreenState
    extends ConsumerState<WorkoutCalendarScreen> {
  late DateTime _selectedWeekStart;
  String? _selectedProgramId;

  static DateTime _getWeekStart(DateTime date) {
    // Get Monday of the current week
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  @override
  void initState() {
    super.initState();

    // Use provided initial week or default to current week
    _selectedWeekStart = widget.initialWeekStart != null
        ? _getWeekStart(widget.initialWeekStart!)
        : _getWeekStart(DateTime.now());

    Future.microtask(() async {
      // Load programs first
      await ref.read(programProvider.notifier).loadPrograms();

      // Use provided program ID or get active program
      if (widget.programId != null) {
        setState(() => _selectedProgramId = widget.programId);
        _loadWeekWorkouts();
      } else {
        final programs = ref.read(programProvider).programs;
        final activeProgram =
            programs.where((p) => p.status == 'ACTIVE').firstOrNull;

        if (activeProgram != null) {
          setState(() => _selectedProgramId = activeProgram.id);
          _loadWeekWorkouts();
        }
      }
    });
  }

  Future<void> _loadWeekWorkouts() async {
    if (_selectedProgramId != null) {
      await ref
          .read(workoutProvider.notifier)
          .loadWeekWorkouts(_selectedProgramId!, _selectedWeekStart);
    }
  }

  void _previousWeek() {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
    });
    _loadWeekWorkouts();
  }

  void _nextWeek() {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7));
    });
    _loadWeekWorkouts();
  }

  void _goToToday() {
    setState(() {
      _selectedWeekStart = _getWeekStart(DateTime.now());
    });
    _loadWeekWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    final workoutState = ref.watch(workoutProvider);
    final programState = ref.watch(programProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/'),
          tooltip: 'Home',
        ),
        actions: [
          if (_selectedProgramId != null)
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: _goToToday,
              tooltip: 'Today',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'select_program') {
                _showProgramSelector();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'select_program',
                child: Text('Select Program'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(workoutState, programState),
    );
  }

  Widget _buildBody(WorkoutState workoutState, ProgramState programState) {
    if (_selectedProgramId == null && programState.programs.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fitness_center,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Program',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Select a program to view workouts',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _showProgramSelector,
              child: const Text('Select Program'),
            ),
          ],
        ),
      );
    }

    if (_selectedProgramId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fitness_center,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No Programs Yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a program to start tracking workouts',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/programs/create'),
              child: const Text('Create Program'),
            ),
          ],
        ),
      );
    }

    if (workoutState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (workoutState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading workouts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(workoutState.error!),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadWeekWorkouts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildWeekNavigator(),
        const Divider(height: 1),
        Expanded(child: _buildWeekView(workoutState)),
      ],
    );
  }

  Widget _buildWeekNavigator() {
    final weekEnd = _selectedWeekStart.add(const Duration(days: 6));
    final dateFormat = DateFormat('MMM d');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousWeek,
          ),
          Expanded(
            child: Text(
              '${dateFormat.format(_selectedWeekStart)} - ${dateFormat.format(weekEnd)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextWeek,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekView(WorkoutState workoutState) {
    final days = List.generate(
      7,
      (index) => _selectedWeekStart.add(Duration(days: index)),
    );

    if (workoutState.workouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No workouts this week',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final dayWorkouts = ref
            .read(workoutProvider.notifier)
            .getWorkoutsForDate(day);

        return _buildDayCard(day, dayWorkouts);
      },
    );
  }

  Widget _buildDayCard(DateTime date, List<Workout> workouts) {
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    final dateFormat = DateFormat('EEEE, MMM d');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isToday ? 4 : 1,
      color: isToday ? Colors.blue.shade50 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isToday) const SizedBox(width: 12),
                Text(
                  dateFormat.format(date),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          if (workouts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Rest day',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            )
          else if (workouts.length == 1)
            _buildWorkoutTile(workouts.first)
          else
            _buildCombinedWorkoutTile(workouts),
        ],
      ),
    );
  }

  Widget _buildWorkoutTile(Workout workout) {
    return InkWell(
      onTap: () {
        context.push('/workouts/${workout.id}');
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getStatusColor(workout.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getStatusIcon(workout.status),
                color: _getStatusColor(workout.status),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.displayMainLifts,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${workout.displayWeekType} • Cycle ${workout.cycleNumber}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Accessories included',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildStatusChip(workout.status),
          ],
        ),
      ),
    );
  }

  Widget _buildCombinedWorkoutTile(List<Workout> workouts) {
    // Determine overall status (all completed, any in progress, or scheduled)
    final allCompleted = workouts.every((w) => w.status == 'COMPLETED');
    final anyInProgress = workouts.any((w) => w.status == 'IN_PROGRESS');
    final overallStatus = allCompleted
        ? 'completed'
        : anyInProgress
            ? 'in_progress'
            : 'scheduled';

    final firstWorkout = workouts.first;

    return InkWell(
      onTap: () {
        // Navigate to the first workout's detail page
        // The detail screen will load all workouts for that date
        context.push('/workouts/${firstWorkout.id}');
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getStatusColor(overallStatus).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getStatusIcon(overallStatus),
                color: _getStatusColor(overallStatus),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show all main lifts separated by " + "
                  Text(
                    workouts.first.displayMainLifts,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${firstWorkout.displayWeekType} • Cycle ${firstWorkout.cycleNumber}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Accessories included',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildStatusChip(overallStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'COMPLETED':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        break;
      case 'IN_PROGRESS':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        break;
      case 'SKIPPED':
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade900;
        break;
      default:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status == 'COMPLETED'
            ? 'Done'
            : status == 'IN_PROGRESS'
                ? 'In Progress'
                : status == 'SKIPPED'
                    ? 'Skipped'
                    : 'Scheduled',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'COMPLETED':
        return Icons.check_circle;
      case 'IN_PROGRESS':
        return Icons.play_circle;
      case 'SKIPPED':
        return Icons.cancel;
      default:
        return Icons.fitness_center;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return Colors.green;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'SKIPPED':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  void _showProgramSelector() {
    final programs = ref.read(programProvider).programs;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Program'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: programs.length,
            itemBuilder: (context, index) {
              final program = programs[index];
              return ListTile(
                title: Text(program.name),
                subtitle: Text(program.displayStatus),
                selected: program.id == _selectedProgramId,
                onTap: () {
                  setState(() => _selectedProgramId = program.id);
                  Navigator.pop(context);
                  _loadWeekWorkouts();
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
