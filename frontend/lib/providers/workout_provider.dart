import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout_models.dart';
import '../services/api_service.dart';
import 'program_provider.dart';

// Workout state
class WorkoutState {
  final List<Workout> workouts;
  final bool isLoading;
  final String? error;
  final String? selectedProgramId;

  WorkoutState({
    this.workouts = const [],
    this.isLoading = false,
    this.error,
    this.selectedProgramId,
  });

  WorkoutState copyWith({
    List<Workout>? workouts,
    bool? isLoading,
    String? error,
    String? selectedProgramId,
  }) {
    return WorkoutState(
      workouts: workouts ?? this.workouts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedProgramId: selectedProgramId ?? this.selectedProgramId,
    );
  }
}

// Workout notifier
class WorkoutNotifier extends StateNotifier<WorkoutState> {
  final ApiService _apiService;

  WorkoutNotifier(this._apiService) : super(WorkoutState());

  Future<void> loadWorkouts({
    String? programId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? mainLift,
    int? cycleNumber,
    int? weekNumber,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final workouts = await _apiService.getWorkouts(
        programId: programId,
        status: status,
        startDate: startDate,
        endDate: endDate,
        mainLift: mainLift,
        cycleNumber: cycleNumber,
        weekNumber: weekNumber,
      );

      state = state.copyWith(
        workouts: workouts,
        isLoading: false,
        selectedProgramId: programId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadWeekWorkouts(String programId, DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 7));
    await loadWorkouts(
      programId: programId,
      startDate: weekStart,
      endDate: weekEnd,
    );
  }

  List<Workout> getWorkoutsForDate(DateTime date) {
    return state.workouts.where((w) {
      return w.scheduledDate.year == date.year &&
          w.scheduledDate.month == date.month &&
          w.scheduledDate.day == date.day;
    }).toList();
  }

  List<Workout> get completedWorkouts {
    return state.workouts.where((w) => w.isCompleted).toList();
  }

  List<Workout> get scheduledWorkouts {
    return state.workouts.where((w) => w.isScheduled).toList();
  }

  List<Workout> get upcomingWorkouts {
    final now = DateTime.now();
    return state.workouts
        .where((w) => w.isScheduled && w.scheduledDate.isAfter(now))
        .toList();
  }
}

// Workout provider
final workoutProvider = StateNotifierProvider<WorkoutNotifier, WorkoutState>(
  (ref) {
    final apiService = ref.watch(apiServiceProvider);
    return WorkoutNotifier(apiService);
  },
);
