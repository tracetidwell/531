import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_models.dart';
import '../services/api_service.dart';

// API Service Provider
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// Auth State
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;

  AuthNotifier(this._apiService) : super(AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await _apiService.isLoggedIn();
    if (isLoggedIn) {
      try {
        final user = await _apiService.getCurrentUser();
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
        );
      } catch (e) {
        // Token might be expired
        state = state.copyWith(isAuthenticated: false);
      }
    }
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authResponse = await _apiService.register(RegisterRequest(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      ));

      // Get user from auth response, then fetch full profile
      final user = await _apiService.getCurrentUser();

      state = state.copyWith(
        user: user,
        isLoading: false,
        isAuthenticated: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authResponse = await _apiService.login(LoginRequest(
        email: email,
        password: password,
      ));

      // Fetch full user data after login
      final user = await _apiService.getCurrentUser();

      state = state.copyWith(
        user: user,
        isLoading: false,
        isAuthenticated: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _apiService.logout();
    state = AuthState(); // Reset to initial state
  }

  Future<void> refreshUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      state = state.copyWith(user: user);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AuthNotifier(apiService);
});
