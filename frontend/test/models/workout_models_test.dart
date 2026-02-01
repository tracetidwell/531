import 'package:flutter_test/flutter_test.dart';
import 'package:five_three_one/models/workout_models.dart';

void main() {
  group('WorkoutMainLift', () {
    test('fromJson parses correctly', () {
      final json = {
        'lift_type': 'SQUAT',
        'lift_order': 1,
        'current_training_max': 250.0,
      };

      final lift = WorkoutMainLift.fromJson(json);

      expect(lift.liftType, equals('SQUAT'));
      expect(lift.liftOrder, equals(1));
      expect(lift.currentTrainingMax, equals(250.0));
    });

    test('fromJson handles string numbers', () {
      final json = {
        'lift_type': 'BENCH_PRESS',
        'lift_order': '2',
        'current_training_max': '200.5',
      };

      final lift = WorkoutMainLift.fromJson(json);

      expect(lift.liftOrder, equals(2));
      expect(lift.currentTrainingMax, equals(200.5));
    });

    test('displayLiftType returns formatted names', () {
      expect(
        WorkoutMainLift(liftType: 'PRESS', liftOrder: 1, currentTrainingMax: 100)
            .displayLiftType,
        equals('Press'),
      );
      expect(
        WorkoutMainLift(liftType: 'DEADLIFT', liftOrder: 1, currentTrainingMax: 100)
            .displayLiftType,
        equals('Deadlift'),
      );
      expect(
        WorkoutMainLift(liftType: 'BENCH_PRESS', liftOrder: 1, currentTrainingMax: 100)
            .displayLiftType,
        equals('Bench Press'),
      );
      expect(
        WorkoutMainLift(liftType: 'SQUAT', liftOrder: 1, currentTrainingMax: 100)
            .displayLiftType,
        equals('Squat'),
      );
    });

    test('displayLiftType returns raw value for unknown types', () {
      final lift = WorkoutMainLift(
        liftType: 'UNKNOWN_LIFT',
        liftOrder: 1,
        currentTrainingMax: 100,
      );

      expect(lift.displayLiftType, equals('UNKNOWN_LIFT'));
    });
  });

  group('Workout', () {
    final sampleJson = {
      'id': 'workout-123',
      'program_id': 'program-456',
      'scheduled_date': '2024-01-15',
      'completed_date': '2024-01-15T14:30:00',
      'cycle_number': 1,
      'week_number': 2,
      'week_type': 'WEEK_2_3S',
      'main_lifts': [
        {'lift_type': 'SQUAT', 'lift_order': 1, 'current_training_max': 250.0}
      ],
      'status': 'COMPLETED',
      'notes': 'Felt strong today',
      'created_at': '2024-01-01T00:00:00',
    };

    test('fromJson parses all fields correctly', () {
      final workout = Workout.fromJson(sampleJson);

      expect(workout.id, equals('workout-123'));
      expect(workout.programId, equals('program-456'));
      expect(workout.scheduledDate, equals(DateTime.parse('2024-01-15')));
      expect(workout.completedDate, equals(DateTime.parse('2024-01-15T14:30:00')));
      expect(workout.cycleNumber, equals(1));
      expect(workout.weekNumber, equals(2));
      expect(workout.weekType, equals('WEEK_2_3S'));
      expect(workout.mainLifts.length, equals(1));
      expect(workout.mainLifts.first.liftType, equals('SQUAT'));
      expect(workout.status, equals('COMPLETED'));
      expect(workout.notes, equals('Felt strong today'));
    });

    test('fromJson handles null completedDate', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['completed_date'] = null;

      final workout = Workout.fromJson(json);

      expect(workout.completedDate, isNull);
    });

    test('fromJson handles null notes', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['notes'] = null;

      final workout = Workout.fromJson(json);

      expect(workout.notes, isNull);
    });

    test('displayMainLifts returns formatted string', () {
      final workout = Workout.fromJson(sampleJson);

      expect(workout.displayMainLifts, equals('Squat'));
    });

    test('displayMainLifts handles multiple lifts', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['main_lifts'] = [
        {'lift_type': 'SQUAT', 'lift_order': 1, 'current_training_max': 250.0},
        {'lift_type': 'BENCH_PRESS', 'lift_order': 2, 'current_training_max': 200.0},
      ];

      final workout = Workout.fromJson(json);

      expect(workout.displayMainLifts, equals('Squat + Bench Press'));
    });

    test('displayWeekType returns formatted week names', () {
      final week1 = Workout.fromJson({...sampleJson, 'week_type': 'WEEK_1_5S'});
      final week2 = Workout.fromJson({...sampleJson, 'week_type': 'WEEK_2_3S'});
      final week3 = Workout.fromJson({...sampleJson, 'week_type': 'WEEK_3_531'});
      final week4 = Workout.fromJson({...sampleJson, 'week_type': 'WEEK_4_DELOAD'});

      expect(week1.displayWeekType, equals('Week 1: 5s'));
      expect(week2.displayWeekType, equals('Week 2: 3s'));
      expect(week3.displayWeekType, equals('Week 3: 5/3/1'));
      expect(week4.displayWeekType, equals('Week 4: Deload'));
    });

    test('displayStatus returns formatted status names', () {
      expect(
        Workout.fromJson({...sampleJson, 'status': 'SCHEDULED'}).displayStatus,
        equals('Scheduled'),
      );
      expect(
        Workout.fromJson({...sampleJson, 'status': 'IN_PROGRESS'}).displayStatus,
        equals('In Progress'),
      );
      expect(
        Workout.fromJson({...sampleJson, 'status': 'COMPLETED'}).displayStatus,
        equals('Completed'),
      );
      expect(
        Workout.fromJson({...sampleJson, 'status': 'SKIPPED'}).displayStatus,
        equals('Skipped'),
      );
    });

    test('status helper getters work correctly', () {
      final completed = Workout.fromJson({...sampleJson, 'status': 'COMPLETED'});
      final scheduled = Workout.fromJson({...sampleJson, 'status': 'SCHEDULED'});
      final inProgress = Workout.fromJson({...sampleJson, 'status': 'IN_PROGRESS'});
      final skipped = Workout.fromJson({...sampleJson, 'status': 'SKIPPED'});

      expect(completed.isCompleted, isTrue);
      expect(completed.isScheduled, isFalse);

      expect(scheduled.isScheduled, isTrue);
      expect(scheduled.isCompleted, isFalse);

      expect(inProgress.isInProgress, isTrue);
      expect(skipped.isSkipped, isTrue);
    });
  });

  group('WorkoutSet', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'set-123',
        'set_type': 'WORKING',
        'set_number': 3,
        'prescribed_reps': 5,
        'prescribed_weight': 215.0,
        'percentage_of_tm': 0.85,
        'actual_reps': 8,
        'actual_weight': 215.0,
        'is_target_met': true,
        'notes': 'AMRAP set',
        'exercise_id': 'exercise-123',
        'circuit_group': 1,
      };

      final set = WorkoutSet.fromJson(json);

      expect(set.id, equals('set-123'));
      expect(set.setType, equals('WORKING'));
      expect(set.setNumber, equals(3));
      expect(set.prescribedReps, equals(5));
      expect(set.prescribedWeight, equals(215.0));
      expect(set.percentageOfTm, equals(0.85));
      expect(set.actualReps, equals(8));
      expect(set.actualWeight, equals(215.0));
      expect(set.isTargetMet, isTrue);
      expect(set.notes, equals('AMRAP set'));
      expect(set.exerciseId, equals('exercise-123'));
      expect(set.circuitGroup, equals(1));
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'set_type': 'WARMUP',
        'set_number': 1,
      };

      final set = WorkoutSet.fromJson(json);

      expect(set.id, isNull);
      expect(set.prescribedReps, isNull);
      expect(set.prescribedWeight, isNull);
      expect(set.percentageOfTm, isNull);
      expect(set.actualReps, isNull);
      expect(set.actualWeight, isNull);
      expect(set.isTargetMet, isNull);
      expect(set.notes, isNull);
      expect(set.exerciseId, isNull);
      expect(set.circuitGroup, isNull);
    });

    test('fromJson handles string numbers', () {
      final json = {
        'set_type': 'WORKING',
        'set_number': '2',
        'prescribed_reps': '5',
        'prescribed_weight': '200.5',
        'percentage_of_tm': '0.75',
      };

      final set = WorkoutSet.fromJson(json);

      expect(set.setNumber, equals(2));
      expect(set.prescribedReps, equals(5));
      expect(set.prescribedWeight, equals(200.5));
      expect(set.percentageOfTm, equals(0.75));
    });
  });

  group('WorkoutSetsForLift', () {
    test('fromJson parses warmup and main sets', () {
      final json = {
        'warmup_sets': [
          {'set_type': 'WARMUP', 'set_number': 1, 'prescribed_weight': 45.0},
          {'set_type': 'WARMUP', 'set_number': 2, 'prescribed_weight': 95.0},
        ],
        'main_sets': [
          {'set_type': 'WORKING', 'set_number': 1, 'prescribed_weight': 165.0},
          {'set_type': 'WORKING', 'set_number': 2, 'prescribed_weight': 190.0},
          {'set_type': 'WORKING', 'set_number': 3, 'prescribed_weight': 215.0},
        ],
      };

      final setsForLift = WorkoutSetsForLift.fromJson(json);

      expect(setsForLift.warmupSets.length, equals(2));
      expect(setsForLift.mainSets.length, equals(3));
      expect(setsForLift.warmupSets.first.prescribedWeight, equals(45.0));
      expect(setsForLift.mainSets.last.prescribedWeight, equals(215.0));
    });
  });

  group('WorkoutDetail', () {
    final sampleDetailJson = {
      'id': 'workout-123',
      'program_id': 'program-456',
      'scheduled_date': '2024-01-15',
      'completed_date': null,
      'cycle_number': 1,
      'week_number': 1,
      'week_type': 'WEEK_1_5S',
      'main_lifts': [
        {'lift_type': 'SQUAT', 'lift_order': 1, 'current_training_max': 250.0}
      ],
      'status': 'SCHEDULED',
      'sets_by_lift': {
        'SQUAT': {
          'warmup_sets': [
            {'set_type': 'WARMUP', 'set_number': 1, 'prescribed_weight': 45.0},
          ],
          'main_sets': [
            {'set_type': 'WORKING', 'set_number': 1, 'prescribed_weight': 165.0},
          ],
        },
      },
      'accessory_sets': [
        {'set_type': 'ACCESSORY', 'set_number': 1, 'exercise_id': 'ex-123'},
      ],
      'notes': null,
      'created_at': '2024-01-01T00:00:00',
    };

    test('fromJson parses all fields correctly', () {
      final detail = WorkoutDetail.fromJson(sampleDetailJson);

      expect(detail.id, equals('workout-123'));
      expect(detail.programId, equals('program-456'));
      expect(detail.cycleNumber, equals(1));
      expect(detail.weekNumber, equals(1));
      expect(detail.weekType, equals('WEEK_1_5S'));
      expect(detail.status, equals('SCHEDULED'));
      expect(detail.mainLifts.length, equals(1));
      expect(detail.setsByLift.containsKey('SQUAT'), isTrue);
      expect(detail.accessorySets.length, equals(1));
    });

    test('fromJson parses setsByLift correctly', () {
      final detail = WorkoutDetail.fromJson(sampleDetailJson);

      final squatSets = detail.setsByLift['SQUAT']!;
      expect(squatSets.warmupSets.length, equals(1));
      expect(squatSets.mainSets.length, equals(1));
      expect(squatSets.warmupSets.first.prescribedWeight, equals(45.0));
    });

    test('fromJson parses accessorySets correctly', () {
      final detail = WorkoutDetail.fromJson(sampleDetailJson);

      expect(detail.accessorySets.first.setType, equals('ACCESSORY'));
      expect(detail.accessorySets.first.exerciseId, equals('ex-123'));
    });

    test('fromJson handles multiple lifts in setsByLift', () {
      final multiLiftJson = {
        ...sampleDetailJson,
        'main_lifts': [
          {'lift_type': 'SQUAT', 'lift_order': 1, 'current_training_max': 250.0},
          {'lift_type': 'BENCH_PRESS', 'lift_order': 2, 'current_training_max': 200.0},
        ],
        'sets_by_lift': {
          'SQUAT': {
            'warmup_sets': [],
            'main_sets': [
              {'set_type': 'WORKING', 'set_number': 1, 'prescribed_weight': 165.0},
            ],
          },
          'BENCH_PRESS': {
            'warmup_sets': [],
            'main_sets': [
              {'set_type': 'WORKING', 'set_number': 1, 'prescribed_weight': 135.0},
            ],
          },
        },
      };

      final detail = WorkoutDetail.fromJson(multiLiftJson);

      expect(detail.setsByLift.length, equals(2));
      expect(detail.setsByLift.containsKey('SQUAT'), isTrue);
      expect(detail.setsByLift.containsKey('BENCH_PRESS'), isTrue);
    });
  });
}
