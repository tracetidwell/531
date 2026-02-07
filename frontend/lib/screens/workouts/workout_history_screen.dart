import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/workout_models.dart';
import '../../services/api_service.dart';
import '../../providers/program_provider.dart';

class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  ConsumerState<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends ConsumerState<WorkoutHistoryScreen> {
  List<Workout> _workouts = [];
  bool _isLoading = true;
  String? _error;

  // Filter state
  String? _selectedLift;
  String _selectedStatus = 'COMPLETED';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final now = DateTime.now();

      // For completed and skipped, only show past workouts
      // For scheduled, show all (including future)
      DateTime? effectiveEndDate = _endDate;
      if ((_selectedStatus == 'COMPLETED' || _selectedStatus == 'SKIPPED') &&
          effectiveEndDate == null) {
        effectiveEndDate = now;
      }

      final workouts = await apiService.getWorkouts(
        status: _selectedStatus,
        mainLift: _selectedLift,
        startDate: _startDate,
        endDate: effectiveEndDate,
      );

      setState(() {
        _workouts = workouts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadWorkouts();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
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
      body: Column(
        children: [
          _buildFilters(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Filter
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'COMPLETED',
                      label: Text('Completed'),
                      icon: Icon(Icons.check_circle_outline, size: 16),
                    ),
                    ButtonSegment(
                      value: 'SCHEDULED',
                      label: Text('Scheduled'),
                      icon: Icon(Icons.schedule, size: 16),
                    ),
                    ButtonSegment(
                      value: 'SKIPPED',
                      label: Text('Skipped'),
                      icon: Icon(Icons.cancel_outlined, size: 16),
                    ),
                  ],
                  selected: {_selectedStatus},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _selectedStatus = newSelection.first;
                    });
                    _loadWorkouts();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lift and Date filters
          Row(
            children: [
              // Lift Filter
              Expanded(
                child: DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(
                    labelText: 'Lift',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: _selectedLift,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Lifts')),
                    DropdownMenuItem(value: 'press', child: Text('Press')),
                    DropdownMenuItem(
                        value: 'deadlift', child: Text('Deadlift')),
                    DropdownMenuItem(
                        value: 'bench_press', child: Text('Bench Press')),
                    DropdownMenuItem(value: 'squat', child: Text('Squat')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedLift = value;
                    });
                    _loadWorkouts();
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Date Range Filter
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('M/d').format(_startDate!)} - ${DateFormat('M/d').format(_endDate!)}'
                        : 'Date Range',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              if (_startDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: _clearDateRange,
                  tooltip: 'Clear date filter',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
        ],
      ),
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
              'Error loading workouts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadWorkouts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_workouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Workouts Found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWorkouts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _workouts.length,
        itemBuilder: (context, index) {
          return _buildWorkoutCard(_workouts[index]);
        },
      ),
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/workouts/${workout.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(workout.scheduledDate),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  _buildStatusBadge(workout.status),
                ],
              ),
              const SizedBox(height: 12),

              // Main Lift
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getLiftColor(workout.mainLifts.first.liftType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      color: _getLiftColor(workout.mainLifts.first.liftType),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.displayMainLifts,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          workout.displayWeekType,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Cycle and Week Info
              Row(
                children: [
                  Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Cycle ${workout.cycleNumber}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.calendar_view_week,
                      size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Week ${workout.weekNumber}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),

              // Completed Date/Time (if completed)
              if (workout.completedDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: Colors.green[700]),
                    const SizedBox(width: 6),
                    Text(
                      'Completed ${timeFormat.format(workout.completedDate!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ],

              // Notes preview (if any)
              if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          workout.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case 'COMPLETED':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        icon = Icons.check_circle;
        break;
      case 'SCHEDULED':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        icon = Icons.schedule;
        break;
      case 'SKIPPED':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        icon = Icons.cancel;
        break;
      case 'IN_PROGRESS':
        backgroundColor = Colors.purple.shade100;
        textColor = Colors.purple.shade900;
        icon = Icons.play_circle;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade900;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            status == 'COMPLETED'
                ? 'Completed'
                : status == 'SCHEDULED'
                    ? 'Scheduled'
                    : status == 'IN_PROGRESS'
                        ? 'In Progress'
                        : status == 'SKIPPED'
                            ? 'Skipped'
                            : status,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Color _getLiftColor(String lift) {
    switch (lift) {
      case 'press':
        return Colors.orange;
      case 'deadlift':
        return Colors.red;
      case 'bench_press':
        return Colors.blue;
      case 'squat':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
