import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/programs/program_list_screen.dart';
import 'screens/programs/program_detail_screen.dart';
import 'screens/programs/create_program_screen.dart';
import 'screens/workouts/workout_calendar_screen.dart';
import 'screens/workouts/workout_detail_screen.dart';
import 'screens/workouts/workout_logging_screen.dart';
import 'screens/workouts/workout_history_screen.dart';
import 'screens/progress/progress_screen.dart';
import 'screens/progress/rep_max_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/network_test_screen.dart';
import 'services/api_service.dart';

void main() {
  ApiService.printBaseUrl();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = _createRouter(ref);

    return MaterialApp.router(
      title: '5/3/1 Training',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }

  GoRouter _createRouter(WidgetRef ref) {
    return GoRouter(
      initialLocation: '/login',  // Temporarily start with network test
      redirect: (context, state) {
        final authState = ref.read(authProvider);
        final isAuthenticated = authState.isAuthenticated;
        final isLoggingIn = state.matchedLocation == '/login';
        final isRegistering = state.matchedLocation == '/register';
        final isNetworkTest = state.matchedLocation == '/network-test';

        // Allow network test screen without authentication
        if (isNetworkTest) {
          return null;
        }

        // If not authenticated and trying to access protected routes, redirect to login
        if (!isAuthenticated && !isLoggingIn && !isRegistering) {
          return '/login';
        }

        // If authenticated and on login/register page, redirect to home
        if (isAuthenticated && (isLoggingIn || isRegistering)) {
          return '/';
        }

        // No redirect needed
        return null;
      },
      refreshListenable: _GoRouterRefreshStream(ref),
      routes: [
        GoRoute(
          path: '/network-test',
          builder: (context, state) => const NetworkTestScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/programs',
          builder: (context, state) => const ProgramListScreen(),
        ),
        GoRoute(
          path: '/programs/create',
          builder: (context, state) => const CreateProgramScreen(),
        ),
        GoRoute(
          path: '/programs/:id',
          builder: (context, state) {
            final programId = state.pathParameters['id']!;
            return ProgramDetailScreen(programId: programId);
          },
        ),
        GoRoute(
          path: '/workouts',
          builder: (context, state) {
            final programId = state.uri.queryParameters['programId'];
            final startDateStr = state.uri.queryParameters['startDate'];
            final startDate = startDateStr != null
                ? DateTime.tryParse(startDateStr)
                : null;

            return WorkoutCalendarScreen(
              programId: programId,
              initialWeekStart: startDate,
            );
          },
        ),
        GoRoute(
          path: '/workouts/:id',
          builder: (context, state) {
            final workoutId = state.pathParameters['id']!;
            return WorkoutDetailScreen(workoutId: workoutId);
          },
        ),
        GoRoute(
          path: '/workouts/:id/log',
          builder: (context, state) {
            final workoutId = state.pathParameters['id']!;
            return WorkoutLoggingScreen(workoutId: workoutId);
          },
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const WorkoutHistoryScreen(),
        ),
        GoRoute(
          path: '/progress',
          builder: (context, state) => const ProgressScreen(),
        ),
        GoRoute(
          path: '/records',
          builder: (context, state) => const RepMaxScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
  }
}

// Helper class to make GoRouter listen to auth state changes
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(WidgetRef ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated) {
        notifyListeners();
      }
    });
  }
}
