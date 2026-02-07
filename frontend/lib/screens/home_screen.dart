import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../models/missed_workout_models.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _checkedMissedWorkouts = false;

  @override
  void initState() {
    super.initState();
    // Check for missed workouts after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForMissedWorkouts();
    });
  }

  Future<void> _checkForMissedWorkouts() async {
    if (_checkedMissedWorkouts) return;
    _checkedMissedWorkouts = true;

    try {
      final apiService = ref.read(apiServiceProvider);
      final missedResponse = await apiService.getMissedWorkouts();

      if (!mounted) return;

      if (missedResponse.hasMissedWorkouts) {
        if (missedResponse.userPreference == 'ask') {
          // Show dialog for user to decide
          await _showMissedWorkoutsDialog(missedResponse);
        }
        // For 'skip' and 'reschedule' preferences, the backend handles it automatically
        // when user accesses workout endpoints
      }
    } catch (e) {
      // Silently fail - don't disrupt the home screen
      debugPrint('Failed to check missed workouts: $e');
    }
  }

  Future<void> _showMissedWorkoutsDialog(MissedWorkoutsResponse missed) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MissedWorkoutsDialog(
        missedWorkouts: missed,
        onHandled: () {
          // Refresh state after handling
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('5/3/1 Training'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              context.push('/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user.fullName,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                user.email,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _QuickActionCard(
                        icon: Icons.fitness_center,
                        title: 'Start Workout',
                        subtitle: 'Begin today\'s session',
                        color: Colors.blue,
                        onTap: () {
                          context.push('/workouts');
                        },
                      ),
                      _QuickActionCard(
                        icon: Icons.calendar_today,
                        title: 'My Programs',
                        subtitle: 'View your programs',
                        color: Colors.green,
                        onTap: () {
                          context.push('/programs');
                        },
                      ),
                      _QuickActionCard(
                        icon: Icons.history,
                        title: 'History',
                        subtitle: 'View past workouts',
                        color: Colors.orange,
                        onTap: () {
                          context.push('/history');
                        },
                      ),
                      _QuickActionCard(
                        icon: Icons.add_circle,
                        title: 'New Program',
                        subtitle: 'Create a program',
                        color: Colors.purple,
                        onTap: () {
                          context.push('/programs/create');
                        },
                      ),
                      _QuickActionCard(
                        icon: Icons.trending_up,
                        title: 'Progress',
                        subtitle: 'Track your gains',
                        color: Colors.teal,
                        onTap: () {
                          context.push('/progress');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // User Preferences
                  Text(
                    'Your Preferences',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _PreferenceRow(
                            icon: Icons.straighten,
                            label: 'Weight Unit',
                            value: user.weightUnitPreference.toUpperCase(),
                          ),
                          const Divider(),
                          _PreferenceRow(
                            icon: Icons.scale,
                            label: 'Rounding Increment',
                            value: '${user.roundingIncrement} ${user.weightUnitPreference}',
                          ),
                          const Divider(),
                          _PreferenceRow(
                            icon: Icons.event_busy,
                            label: 'Missed Workout',
                            value: user.missedWorkoutPreference
                                .split('_')
                                .map((word) =>
                                    word[0].toUpperCase() + word.substring(1))
                                .join(' '),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PreferenceRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for handling missed workouts.
class _MissedWorkoutsDialog extends ConsumerStatefulWidget {
  final MissedWorkoutsResponse missedWorkouts;
  final VoidCallback onHandled;

  const _MissedWorkoutsDialog({
    required this.missedWorkouts,
    required this.onHandled,
  });

  @override
  ConsumerState<_MissedWorkoutsDialog> createState() =>
      _MissedWorkoutsDialogState();
}

class _MissedWorkoutsDialogState extends ConsumerState<_MissedWorkoutsDialog> {
  int _currentIndex = 0;
  bool _isLoading = false;

  MissedWorkoutInfo get currentWorkout =>
      widget.missedWorkouts.missedWorkouts[_currentIndex];

  bool get isLastWorkout =>
      _currentIndex >= widget.missedWorkouts.missedWorkouts.length - 1;

  @override
  Widget build(BuildContext context) {
    final workout = currentWorkout;
    final dateFormat = DateFormat('EEEE, MMM d');

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Missed Workout${widget.missedWorkouts.count > 1 ? 's' : ''}',
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.missedWorkouts.count > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Workout ${_currentIndex + 1} of ${widget.missedWorkouts.count}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // Workout info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormat.format(workout.workout.scheduledDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          workout.workout.mainLifts
                              .map((l) => l.displayLiftType)
                              .join(', '),
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${workout.daysOverdue} day${workout.daysOverdue == 1 ? '' : 's'} overdue',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              'What would you like to do with this workout?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
      actions: [
        // Skip button
        TextButton(
          onPressed: _isLoading ? null : () => _handleWorkout('skip'),
          child: const Text('Skip'),
        ),

        // Reschedule button
        if (workout.canReschedule)
          FilledButton(
            onPressed: _isLoading ? null : () => _handleWorkout('reschedule'),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reschedule to Today'),
          ),
      ],
    );
  }

  Future<void> _handleWorkout(String action) async {
    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.handleMissedWorkout(
        currentWorkout.workout.id,
        action: action,
        rescheduleDate: action == 'reschedule' ? DateTime.now() : null,
      );

      if (!mounted) return;

      final actionText = action == 'skip' ? 'skipped' : 'rescheduled';

      if (isLastWorkout) {
        // All workouts handled
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.missedWorkouts.count == 1
                  ? 'Workout $actionText'
                  : 'All missed workouts handled',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onHandled();
      } else {
        // Move to next workout
        setState(() {
          _currentIndex++;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
