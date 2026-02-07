import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists in-progress workout state to survive app backgrounding/termination.
///
/// Saves after each set is logged. Restored when returning to the workout.
/// Cleared when workout is completed or explicitly abandoned.
class WorkoutSessionService {
  static const String _keyPrefix = 'workout_session_';

  /// Save current workout session state.
  static Future<void> saveSession({
    required String workoutId,
    required int currentSetIndex,
    required List<Map<String, dynamic>> loggedSets,
    required int restSecondsRemaining,
    required bool isResting,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionData = {
      'workoutId': workoutId,
      'currentSetIndex': currentSetIndex,
      'loggedSets': loggedSets,
      'restSecondsRemaining': restSecondsRemaining,
      'isResting': isResting,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString('$_keyPrefix$workoutId', jsonEncode(sessionData));

    // Also store which workout is active (for quick lookup)
    await prefs.setString('${_keyPrefix}active', workoutId);
  }

  /// Load saved session for a workout.
  /// Returns null if no session exists or session is too old (>24 hours).
  static Future<WorkoutSession?> loadSession(String workoutId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = prefs.getString('$_keyPrefix$workoutId');

    if (sessionJson == null) return null;

    try {
      final data = jsonDecode(sessionJson) as Map<String, dynamic>;

      // Check if session is stale (older than 24 hours)
      final savedAt = DateTime.parse(data['savedAt'] as String);
      if (DateTime.now().difference(savedAt).inHours > 24) {
        await clearSession(workoutId);
        return null;
      }

      return WorkoutSession(
        workoutId: data['workoutId'] as String,
        currentSetIndex: data['currentSetIndex'] as int,
        loggedSets: (data['loggedSets'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        restSecondsRemaining: data['restSecondsRemaining'] as int,
        isResting: data['isResting'] as bool,
        savedAt: savedAt,
      );
    } catch (e) {
      // Corrupted data, clear it
      await clearSession(workoutId);
      return null;
    }
  }

  /// Clear saved session (called on completion or abandon).
  static Future<void> clearSession(String workoutId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$workoutId');

    // Clear active workout if it matches
    final activeId = prefs.getString('${_keyPrefix}active');
    if (activeId == workoutId) {
      await prefs.remove('${_keyPrefix}active');
    }
  }

  /// Check if there's an active workout session.
  static Future<String?> getActiveWorkoutId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_keyPrefix}active');
  }

  /// Check if a specific workout has a saved session.
  static Future<bool> hasSession(String workoutId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_keyPrefix$workoutId');
  }
}

/// Represents a saved workout session.
class WorkoutSession {
  final String workoutId;
  final int currentSetIndex;
  final List<Map<String, dynamic>> loggedSets;
  final int restSecondsRemaining;
  final bool isResting;
  final DateTime savedAt;

  WorkoutSession({
    required this.workoutId,
    required this.currentSetIndex,
    required this.loggedSets,
    required this.restSecondsRemaining,
    required this.isResting,
    required this.savedAt,
  });
}
