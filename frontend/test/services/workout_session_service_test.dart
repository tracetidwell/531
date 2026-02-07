import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:five_three_one/services/workout_session_service.dart';

void main() {
  group('WorkoutSessionService', () {
    setUp(() {
      // Set up mock shared preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('saveSession stores workout progress', () async {
      await WorkoutSessionService.saveSession(
        workoutId: 'workout-123',
        currentSetIndex: 5,
        loggedSets: [
          {'set_number': 1, 'actual_reps': 5},
          {'set_number': 2, 'actual_reps': 5},
        ],
        restSecondsRemaining: 120,
        isResting: true,
      );

      final session = await WorkoutSessionService.loadSession('workout-123');

      expect(session, isNotNull);
      expect(session!.workoutId, equals('workout-123'));
      expect(session.currentSetIndex, equals(5));
      expect(session.loggedSets.length, equals(2));
      expect(session.restSecondsRemaining, equals(120));
      expect(session.isResting, isTrue);
    });

    test('loadSession returns null for non-existent session', () async {
      final session = await WorkoutSessionService.loadSession('non-existent');

      expect(session, isNull);
    });

    test('clearSession removes stored data', () async {
      await WorkoutSessionService.saveSession(
        workoutId: 'workout-123',
        currentSetIndex: 5,
        loggedSets: [{'set_number': 1, 'actual_reps': 5}],
        restSecondsRemaining: 0,
        isResting: false,
      );

      await WorkoutSessionService.clearSession('workout-123');

      final session = await WorkoutSessionService.loadSession('workout-123');
      expect(session, isNull);
    });

    test('hasSession returns true when session exists', () async {
      await WorkoutSessionService.saveSession(
        workoutId: 'workout-123',
        currentSetIndex: 0,
        loggedSets: [{'set_number': 1, 'actual_reps': 5}],
        restSecondsRemaining: 0,
        isResting: false,
      );

      expect(await WorkoutSessionService.hasSession('workout-123'), isTrue);
      expect(await WorkoutSessionService.hasSession('other'), isFalse);
    });

    test('getActiveWorkoutId returns active workout', () async {
      await WorkoutSessionService.saveSession(
        workoutId: 'workout-456',
        currentSetIndex: 0,
        loggedSets: [],
        restSecondsRemaining: 0,
        isResting: false,
      );

      final activeId = await WorkoutSessionService.getActiveWorkoutId();
      expect(activeId, equals('workout-456'));
    });

    test('clearSession removes active workout marker', () async {
      await WorkoutSessionService.saveSession(
        workoutId: 'workout-789',
        currentSetIndex: 0,
        loggedSets: [],
        restSecondsRemaining: 0,
        isResting: false,
      );

      await WorkoutSessionService.clearSession('workout-789');

      final activeId = await WorkoutSessionService.getActiveWorkoutId();
      expect(activeId, isNull);
    });

    test('session preserves complex logged sets data', () async {
      final loggedSets = [
        {
          'exercise_id': 'main_lift',
          'set_type': 'working',
          'set_number': 1,
          'lift_type': 'squat',
          'actual_reps': 5,
          'actual_weight': 225.0,
          'weight_unit': 'lbs',
          'prescribed_reps': 5,
          'prescribed_weight': 225.0,
        },
        {
          'exercise_id': 'ex-123',
          'set_type': 'accessory',
          'set_number': 1,
          'lift_type': 'squat',
          'actual_reps': 10,
          'actual_weight': 50.0,
          'weight_unit': 'lbs',
          'prescribed_reps': 10,
          'prescribed_weight': null,
        },
      ];

      await WorkoutSessionService.saveSession(
        workoutId: 'workout-complex',
        currentSetIndex: 2,
        loggedSets: loggedSets,
        restSecondsRemaining: 180,
        isResting: true,
      );

      final session = await WorkoutSessionService.loadSession('workout-complex');

      expect(session, isNotNull);
      expect(session!.loggedSets.length, equals(2));

      final firstSet = session.loggedSets[0];
      expect(firstSet['exercise_id'], equals('main_lift'));
      expect(firstSet['actual_weight'], equals(225.0));
      expect(firstSet['lift_type'], equals('squat'));

      final secondSet = session.loggedSets[1];
      expect(secondSet['exercise_id'], equals('ex-123'));
      expect(secondSet['set_type'], equals('accessory'));
      expect(secondSet['prescribed_weight'], isNull);
    });

    test('savedAt timestamp is recorded', () async {
      final beforeSave = DateTime.now();

      await WorkoutSessionService.saveSession(
        workoutId: 'workout-time',
        currentSetIndex: 0,
        loggedSets: [],
        restSecondsRemaining: 0,
        isResting: false,
      );

      final afterSave = DateTime.now();
      final session = await WorkoutSessionService.loadSession('workout-time');

      expect(session, isNotNull);
      expect(session!.savedAt.isAfter(beforeSave.subtract(const Duration(seconds: 1))), isTrue);
      expect(session.savedAt.isBefore(afterSave.add(const Duration(seconds: 1))), isTrue);
    });
  });
}
