import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_models.dart';
import '../models/program_models.dart';
import '../models/workout_models.dart';
import '../models/exercise_models.dart';
import '../models/rep_max_models.dart';
import '../models/analytics_models.dart';
import '../models/workout_analysis_models.dart';
import '../models/missed_workout_models.dart';

class ApiService {
  // For Android emulator: 10.0.2.2 is the host machine's localhost
  // For iOS simulator: use 'localhost'
  // For physical device: use your computer's IP (e.g., 'http://192.168.1.XXX:8000/api/v1')
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  static void printBaseUrl() {
    print('API_BASE_URL: $baseUrl');
  }

  final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
          },
        )),
        _storage = const FlutterSecureStorage() {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token to requests
          final token = await _storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 errors (token expired)
          if (error.response?.statusCode == 401) {
            // Try to refresh token
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Retry the request
              final opts = error.requestOptions;
              final token = await _storage.read(key: 'access_token');
              opts.headers['Authorization'] = 'Bearer $token';

              try {
                final response = await _dio.request(
                  opts.path,
                  options: Options(
                    method: opts.method,
                    headers: opts.headers,
                  ),
                  data: opts.data,
                  queryParameters: opts.queryParameters,
                );
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  // Authentication

  Future<AuthResponse> register(RegisterRequest request) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(response.data);
      await _saveTokens(authResponse);
      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(response.data);
      await _saveTokens(authResponse);
      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      // Refresh endpoint only returns access_token, not the full auth response
      final newAccessToken = response.data['access_token'] as String;
      await _storage.write(key: 'access_token', value: newAccessToken);
      // Keep existing refresh_token (it doesn't change)
      return true;
    } catch (e) {
      await logout();
      return false;
    }
  }

  Future<void> _saveTokens(AuthResponse response) async {
    await _storage.write(key: 'access_token', value: response.accessToken);
    await _storage.write(key: 'refresh_token', value: response.refreshToken);
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  Future<User> getCurrentUser() async {
    try {
      final response = await _dio.get('/users/me');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<User> updateUser(UpdateUserRequest request) async {
    try {
      final response = await _dio.put(
        '/users/me',
        data: request.toJson(),
      );
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Programs

  Future<List<Program>> getPrograms() async {
    try {
      final response = await _dio.get('/programs');
      final List<dynamic> programsJson = response.data as List;
      return programsJson.map((json) => Program.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<ProgramDetail> getProgramById(String id) async {
    try {
      final response = await _dio.get('/programs/$id');
      return ProgramDetail.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getProgramTemplates(String programId) async {
    try {
      final response = await _dio.get('/programs/$programId/templates');
      return (response.data as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Program> createProgram(CreateProgramRequest request) async {
    try {
      final response = await _dio.post(
        '/programs',
        data: request.toJson(),
      );
      return Program.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Program> updateProgram(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _dio.put(
        '/programs/$id',
        data: updates,
      );
      return Program.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateAccessories(
    String programId,
    int dayNumber,
    List<Map<String, dynamic>> accessories,
  ) async {
    try {
      final response = await _dio.put(
        '/programs/$programId/days/$dayNumber/accessories',
        data: {'accessories': accessories},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteProgram(String id) async {
    try {
      await _dio.delete('/programs/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Workouts

  Future<List<Workout>> getWorkouts({
    String? programId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? mainLift,
    int? cycleNumber,
    int? weekNumber,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (programId != null) queryParams['program_id'] = programId;
      if (status != null) queryParams['workout_status'] = status.toUpperCase();
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      if (mainLift != null) queryParams['main_lifts'] = [mainLift.toUpperCase()];
      if (cycleNumber != null) queryParams['cycle_number'] = cycleNumber;
      if (weekNumber != null) queryParams['week_number'] = weekNumber;

      final response = await _dio.get(
        '/workouts',
        queryParameters: queryParams,
      );
      final List<dynamic> workoutsJson = response.data as List;
      return workoutsJson.map((json) => Workout.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<WorkoutDetail> getWorkoutDetail(String id) async {
    try {
      final response = await _dio.get('/workouts/$id');
      return WorkoutDetail.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<WorkoutCompletionResponse> completeWorkout(
    String workoutId,
    List<Map<String, dynamic>> loggedSets, {
    DateTime? completedDate,
    String? workoutNotes,
  }) async {
    try {
      final response = await _dio.post(
        '/workouts/$workoutId/complete',
        data: {
          'sets': loggedSets,
          if (completedDate != null)
            'completed_date': completedDate.toIso8601String(),
          if (workoutNotes != null && workoutNotes.isNotEmpty)
            'workout_notes': workoutNotes,
        },
      );
      return WorkoutCompletionResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Workout> skipWorkout(String workoutId) async {
    try {
      final response = await _dio.post('/workouts/$workoutId/skip');
      return Workout.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get all missed workouts
  Future<MissedWorkoutsResponse> getMissedWorkouts() async {
    try {
      final response = await _dio.get('/workouts/missed');
      return MissedWorkoutsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle a missed workout (skip or reschedule)
  Future<HandleMissedWorkoutResponse> handleMissedWorkout(
    String workoutId, {
    required String action,
    DateTime? rescheduleDate,
  }) async {
    try {
      final response = await _dio.post(
        '/workouts/$workoutId/handle-missed',
        data: {
          'action': action,
          if (rescheduleDate != null)
            'reschedule_date': rescheduleDate.toIso8601String().split('T')[0],
        },
      );
      return HandleMissedWorkoutResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Exercise endpoints

  /// Get all exercises (predefined + user's custom)
  Future<List<Exercise>> getExercises({
    ExerciseCategory? category,
    bool? isPredefined,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null) {
        queryParams['category'] = category.name;
      }
      if (isPredefined != null) {
        queryParams['is_predefined'] = isPredefined;
      }

      final response = await _dio.get(
        '/exercises',
        queryParameters: queryParams,
      );

      return (response.data as List)
          .map((json) => Exercise.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a custom exercise
  Future<Exercise> createExercise(ExerciseCreateRequest request) async {
    try {
      final response = await _dio.post(
        '/exercises',
        data: request.toJson(),
      );
      return Exercise.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Rep Max endpoints

  /// Get all rep maxes for all lifts
  Future<AllRepMaxes> getAllRepMaxes() async {
    try {
      final response = await _dio.get('/rep-maxes');
      return AllRepMaxes.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get rep maxes for a specific lift
  Future<RepMaxByReps> getRepMaxesByLift(String liftType) async {
    try {
      final response = await _dio.get('/rep-maxes/$liftType');
      return RepMaxByReps.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Analytics endpoints

  /// Get training max progression for a program
  Future<TrainingMaxProgression> getTrainingMaxProgression(
      String programId) async {
    try {
      final response =
          await _dio.get('/analytics/programs/$programId/training-max-progression');
      return TrainingMaxProgression.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException error) {
    if (error.response?.data != null && error.response?.data is Map) {
      final data = error.response!.data as Map<String, dynamic>;
      if (data.containsKey('detail')) {
        return data['detail'].toString();
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        return error.response?.data?['detail'] ?? 'Server error occurred.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      default:
        return 'Network error. Please try again.';
    }
  }
}
