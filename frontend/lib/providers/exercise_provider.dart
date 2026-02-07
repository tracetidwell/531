import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise_models.dart';
import '../services/api_service.dart';
import 'program_provider.dart'; // For apiServiceProvider

// Exercise state
class ExerciseState {
  final List<Exercise> exercises;
  final bool isLoading;
  final String? error;
  final ExerciseCategory? filterCategory;
  final bool? filterPredefined;

  ExerciseState({
    this.exercises = const [],
    this.isLoading = false,
    this.error,
    this.filterCategory,
    this.filterPredefined,
  });

  ExerciseState copyWith({
    List<Exercise>? exercises,
    bool? isLoading,
    String? error,
    ExerciseCategory? filterCategory,
    bool? filterPredefined,
    bool clearFilters = false,
  }) {
    return ExerciseState(
      exercises: exercises ?? this.exercises,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filterCategory: clearFilters ? null : (filterCategory ?? this.filterCategory),
      filterPredefined: clearFilters ? null : (filterPredefined ?? this.filterPredefined),
    );
  }

  /// Get exercises by category
  List<Exercise> getByCategory(ExerciseCategory category) {
    return exercises.where((ex) => ex.category == category).toList();
  }

  /// Get predefined exercises only
  List<Exercise> get predefinedExercises {
    return exercises.where((ex) => ex.isPredefined).toList();
  }

  /// Get custom exercises only
  List<Exercise> get customExercises {
    return exercises.where((ex) => !ex.isPredefined).toList();
  }
}

// Exercise notifier
class ExerciseNotifier extends StateNotifier<ExerciseState> {
  final ApiService _apiService;

  ExerciseNotifier(this._apiService) : super(ExerciseState());

  /// Load all exercises or filtered exercises
  Future<void> loadExercises({
    ExerciseCategory? category,
    bool? isPredefined,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      filterCategory: category,
      filterPredefined: isPredefined,
    );

    try {
      final exercises = await _apiService.getExercises(
        category: category,
        isPredefined: isPredefined,
      );
      state = state.copyWith(
        exercises: exercises,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Create a custom exercise
  Future<Exercise> createExercise(ExerciseCreateRequest request) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final newExercise = await _apiService.createExercise(request);
      state = state.copyWith(
        exercises: [...state.exercises, newExercise],
        isLoading: false,
      );
      return newExercise;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Clear filters and reload all exercises
  Future<void> clearFilters() async {
    await loadExercises();
  }

  /// Refresh exercises (reload with current filters)
  Future<void> refresh() async {
    await loadExercises(
      category: state.filterCategory,
      isPredefined: state.filterPredefined,
    );
  }

  /// Get exercise by ID from current state
  Exercise? getExerciseById(String id) {
    try {
      return state.exercises.firstWhere((ex) => ex.id == id);
    } catch (e) {
      return null;
    }
  }
}

// Provider for exercise state
final exerciseProvider =
    StateNotifierProvider<ExerciseNotifier, ExerciseState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ExerciseNotifier(apiService);
});

// Convenience provider for getting exercises by category
final exercisesByCategoryProvider =
    Provider.family<List<Exercise>, ExerciseCategory>((ref, category) {
  final exerciseState = ref.watch(exerciseProvider);
  return exerciseState.getByCategory(category);
});

// Provider for predefined exercises only
final predefinedExercisesProvider = Provider<List<Exercise>>((ref) {
  final exerciseState = ref.watch(exerciseProvider);
  return exerciseState.predefinedExercises;
});

// Provider for custom exercises only
final customExercisesProvider = Provider<List<Exercise>>((ref) {
  final exerciseState = ref.watch(exerciseProvider);
  return exerciseState.customExercises;
});
