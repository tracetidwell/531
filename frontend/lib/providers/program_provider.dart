import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/program_models.dart';
import '../services/api_service.dart';

// Provider for ApiService
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// Program state
class ProgramState {
  final List<Program> programs;
  final bool isLoading;
  final String? error;

  ProgramState({
    this.programs = const [],
    this.isLoading = false,
    this.error,
  });

  ProgramState copyWith({
    List<Program>? programs,
    bool? isLoading,
    String? error,
  }) {
    return ProgramState(
      programs: programs ?? this.programs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Program notifier
class ProgramNotifier extends StateNotifier<ProgramState> {
  final ApiService _apiService;

  ProgramNotifier(this._apiService) : super(ProgramState());

  Future<void> loadPrograms() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final programs = await _apiService.getPrograms();
      state = state.copyWith(
        programs: programs,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> createProgram(CreateProgramRequest request) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final newProgram = await _apiService.createProgram(request);
      state = state.copyWith(
        programs: [...state.programs, newProgram],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> updateProgram(String id, Map<String, dynamic> updates) async {
    try {
      final updatedProgram = await _apiService.updateProgram(id, updates);
      final updatedPrograms = state.programs.map((program) {
        return program.id == id ? updatedProgram : program;
      }).toList();

      state = state.copyWith(programs: updatedPrograms);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteProgram(String id) async {
    try {
      await _apiService.deleteProgram(id);
      final updatedPrograms = state.programs.where((p) => p.id != id).toList();
      state = state.copyWith(programs: updatedPrograms);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Program? getProgramById(String id) {
    try {
      return state.programs.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Program> get activePrograms {
    return state.programs.where((p) => p.status == 'ACTIVE').toList();
  }

  List<Program> get completedPrograms {
    return state.programs.where((p) => p.status == 'COMPLETED').toList();
  }

  List<Program> get pausedPrograms {
    return state.programs.where((p) => p.status == 'PAUSED').toList();
  }
}

// Program provider
final programProvider = StateNotifierProvider<ProgramNotifier, ProgramState>(
  (ref) {
    final apiService = ref.watch(apiServiceProvider);
    return ProgramNotifier(apiService);
  },
);
