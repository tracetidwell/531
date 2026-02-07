import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/program_models.dart';
import '../../models/workout_models.dart';
import '../../models/analytics_models.dart';
import '../../services/api_service.dart';
import '../../providers/program_provider.dart';
import '../../widgets/training_max_chart.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  ProgramDetail? _activeProgram;
  List<Workout> _recentWorkouts = [];
  TrainingMaxProgression? _tmProgression;
  bool _isLoading = true;
  String? _error;

  int _totalCompleted = 0;
  int _thisWeekCompleted = 0;
  int _thisMonthCompleted = 0;

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);

      // Get active program
      final programState = ref.read(programProvider);
      final activePrograms = programState.programs
          .where((p) => p.status == 'ACTIVE')
          .toList();

      if (activePrograms.isNotEmpty) {
        final programDetail =
            await apiService.getProgramById(activePrograms.first.id);
        _activeProgram = programDetail;

        // Load training max progression for charts
        try {
          _tmProgression = await apiService
              .getTrainingMaxProgression(activePrograms.first.id);
        } catch (e) {
          // Chart data is optional, don't fail the whole screen
          debugPrint('Failed to load TM progression: $e');
        }
      }

      // Get all completed workouts
      final allCompleted = await apiService.getWorkouts(status: 'completed');
      _totalCompleted = allCompleted.length;

      // Get workouts from this week
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final weekWorkouts = await apiService.getWorkouts(
        status: 'completed',
        startDate: startOfWeek,
        endDate: now,
      );
      _thisWeekCompleted = weekWorkouts.length;

      // Get workouts from this month
      final startOfMonth = DateTime(now.year, now.month, 1);
      final monthWorkouts = await apiService.getWorkouts(
        status: 'completed',
        startDate: startOfMonth,
        endDate: now,
      );
      _thisMonthCompleted = monthWorkouts.length;

      // Get recent workouts (past workouts only, any status)
      final allWorkouts = await apiService.getWorkouts(
        endDate: now,
      );

      // Filter to only past workouts and sort by most recent
      final pastWorkouts = allWorkouts
          .where((w) => w.scheduledDate.isBefore(now) ||
                       w.scheduledDate.year == now.year &&
                       w.scheduledDate.month == now.month &&
                       w.scheduledDate.day == now.day)
          .toList();

      // Sort by completion date if completed, otherwise by scheduled date
      pastWorkouts.sort((a, b) {
        final aDate = a.completedDate ?? a.scheduledDate;
        final bDate = b.completedDate ?? b.scheduledDate;
        return bDate.compareTo(aDate); // Most recent first
      });

      _recentWorkouts = pastWorkouts.take(10).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Progress'),
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
              'Error loading progress data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProgressData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProgressData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsSection(),
            const Divider(),
            if (_activeProgram != null) ...[
              _buildTrainingMaxesSection(),
              const Divider(),
              if (_tmProgression != null && _tmProgression!.hasData) ...[
                _buildChartSection(),
                const Divider(),
              ],
            ],
            _buildRecentWorkoutsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workout Stats',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.fitness_center,
                  label: 'Total Workouts',
                  value: '$_totalCompleted',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.calendar_today,
                  label: 'This Week',
                  value: '$_thisWeekCompleted',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.calendar_month,
                  label: 'This Month',
                  value: '$_thisMonthCompleted',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => context.push('/records'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events, size: 32, color: Colors.amber.shade700),
                        const SizedBox(height: 8),
                        Text(
                          'View PRs',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color.shade900,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingMaxesSection() {
    final program = _activeProgram!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Training Maxes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                onPressed: () {
                  context.push('/programs/${program.id}');
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View Program'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            program.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 16),
          // Build TM cards dynamically based on what lifts exist in the program
          ..._buildTrainingMaxCards(program.trainingMaxes),
        ],
      ),
    );
  }

  List<Widget> _buildTrainingMaxCards(Map<String, TrainingMax> trainingMaxes) {
    final liftConfig = {
      'press': ('Press', Colors.orange),
      'deadlift': ('Deadlift', Colors.red),
      'bench_press': ('Bench', Colors.blue),
      'squat': ('Squat', Colors.green),
    };

    final widgets = <Widget>[];
    final entries = trainingMaxes.entries.toList();

    for (var i = 0; i < entries.length; i += 2) {
      final row = <Widget>[];

      // First card in row
      final entry1 = entries[i];
      final config1 = liftConfig[entry1.key];
      if (config1 != null) {
        row.add(Expanded(
          child: _buildTMCard(config1.$1, entry1.value.value, config1.$2),
        ));
      }

      // Second card in row (if exists)
      if (i + 1 < entries.length) {
        row.add(const SizedBox(width: 12));
        final entry2 = entries[i + 1];
        final config2 = liftConfig[entry2.key];
        if (config2 != null) {
          row.add(Expanded(
            child: _buildTMCard(config2.$1, entry2.value.value, config2.$2),
          ));
        }
      } else {
        // Add empty spacer for odd number of lifts
        row.add(const SizedBox(width: 12));
        row.add(const Expanded(child: SizedBox()));
      }

      widgets.add(Row(children: row));
      if (i + 2 < entries.length) {
        widgets.add(const SizedBox(height: 12));
      }
    }

    return widgets;
  }

  Widget _buildTMCard(String lift, double value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lift,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${value.toInt()}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color.shade900,
                    ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'lbs',
                  style: TextStyle(
                    fontSize: 12,
                    color: color.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: TrainingMaxChart(data: _tmProgression!),
    );
  }

  Widget _buildRecentWorkoutsSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Workouts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                onPressed: () {
                  context.push('/history');
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentWorkouts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No past workouts yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._recentWorkouts.map((workout) => _buildRecentWorkoutItem(workout)).toList(),
        ],
      ),
    );
  }

  Widget _buildRecentWorkoutItem(Workout workout) {
    final dateFormat = DateFormat('MMM d');
    final isCompleted = workout.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          context.push('/workouts/${workout.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? _getLiftColor(workout.mainLifts.first.liftType).withOpacity(0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.fitness_center,
                  color: isCompleted
                      ? _getLiftColor(workout.mainLifts.first.liftType)
                      : Colors.grey.shade500,
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? null : Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${workout.displayWeekType} • Cycle ${workout.cycleNumber}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ),
                        if (!isCompleted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: workout.isSkipped
                                  ? Colors.orange.shade100
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              workout.displayStatus,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: workout.isSkipped
                                    ? Colors.orange.shade900
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateFormat.format(workout.completedDate ?? workout.scheduledDate),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
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
