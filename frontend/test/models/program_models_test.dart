import 'package:flutter_test/flutter_test.dart';
import 'package:five_three_one/models/program_models.dart';

void main() {
  group('Program', () {
    final sampleJson = {
      'id': 'program-123',
      'name': 'My 5/3/1 Program',
      'template_type': '4_day',
      'start_date': '2024-01-01',
      'end_date': '2024-06-01',
      'target_cycles': 6,
      'include_deload': true,
      'training_days': ['monday', 'tuesday', 'thursday', 'friday'],
      'status': 'ACTIVE',
      'current_cycle': 2,
      'created_at': '2024-01-01T00:00:00',
    };

    test('fromJson parses all fields correctly', () {
      final program = Program.fromJson(sampleJson);

      expect(program.id, equals('program-123'));
      expect(program.name, equals('My 5/3/1 Program'));
      expect(program.templateType, equals('4_day'));
      expect(program.startDate, equals(DateTime.parse('2024-01-01')));
      expect(program.endDate, equals(DateTime.parse('2024-06-01')));
      expect(program.targetCycles, equals(6));
      expect(program.includeDeload, isTrue);
      expect(program.trainingDays, equals(['monday', 'tuesday', 'thursday', 'friday']));
      expect(program.status, equals('ACTIVE'));
      expect(program.currentCycle, equals(2));
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'program-123',
        'name': 'Test',
        'template_type': '4_day',
        'start_date': '2024-01-01',
        'end_date': null,
        'target_cycles': null,
        'include_deload': true,
        'training_days': ['monday'],
        'status': 'ACTIVE',
        'current_cycle': null,
        'created_at': '2024-01-01T00:00:00',
      };

      final program = Program.fromJson(json);

      expect(program.endDate, isNull);
      expect(program.targetCycles, isNull);
      expect(program.currentCycle, isNull);
    });

    test('fromJson defaults includeDeload to true', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json.remove('include_deload');

      final program = Program.fromJson(json);

      expect(program.includeDeload, isTrue);
    });

    test('fromJson handles include_deload as integer', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['include_deload'] = 1;

      final program = Program.fromJson(json);

      expect(program.includeDeload, isTrue);
    });

    test('toJson creates correct map', () {
      final program = Program.fromJson(sampleJson);
      final json = program.toJson();

      expect(json['id'], equals('program-123'));
      expect(json['name'], equals('My 5/3/1 Program'));
      expect(json['template_type'], equals('4_day'));
      expect(json['start_date'], equals('2024-01-01'));
      expect(json['status'], equals('ACTIVE'));
    });

    test('displayStatus returns formatted names', () {
      expect(
        Program.fromJson({...sampleJson, 'status': 'ACTIVE'}).displayStatus,
        equals('Active'),
      );
      expect(
        Program.fromJson({...sampleJson, 'status': 'COMPLETED'}).displayStatus,
        equals('Completed'),
      );
      expect(
        Program.fromJson({...sampleJson, 'status': 'PAUSED'}).displayStatus,
        equals('Paused'),
      );
    });

    test('displayTemplateType returns formatted names', () {
      expect(
        Program.fromJson({...sampleJson, 'template_type': '4_day'}).displayTemplateType,
        equals('4-Day Program'),
      );
      expect(
        Program.fromJson({...sampleJson, 'template_type': '3_day'}).displayTemplateType,
        equals('3-Day Program'),
      );
      expect(
        Program.fromJson({...sampleJson, 'template_type': '2_day'}).displayTemplateType,
        equals('2-Day Program'),
      );
    });

    test('trainingDaysDisplay returns abbreviated days', () {
      final program = Program.fromJson(sampleJson);

      expect(program.trainingDaysDisplay, equals('MON, TUE, THU, FRI'));
    });
  });

  group('CreateProgramRequest', () {
    test('toJson creates correct map', () {
      final request = CreateProgramRequest(
        name: 'New Program',
        templateType: '4_day',
        startDate: DateTime(2024, 1, 15),
        includeDeload: true,
        trainingDays: ['monday', 'wednesday', 'friday'],
        trainingMaxes: {
          'squat': 250.0,
          'deadlift': 300.0,
          'bench_press': 200.0,
          'press': 100.0,
        },
      );

      final json = request.toJson();

      expect(json['name'], equals('New Program'));
      expect(json['template_type'], equals('4_day'));
      expect(json['start_date'], equals('2024-01-15'));
      expect(json['include_deload'], isTrue);
      expect(json['training_days'], equals(['monday', 'wednesday', 'friday']));
      expect(json['training_maxes']['squat'], equals(250.0));
    });

    test('toJson includes end_date when provided', () {
      final request = CreateProgramRequest(
        name: 'New Program',
        templateType: '4_day',
        startDate: DateTime(2024, 1, 15),
        endDate: DateTime(2024, 6, 15),
        trainingDays: ['monday'],
        trainingMaxes: {'squat': 250.0},
      );

      final json = request.toJson();

      expect(json['end_date'], equals('2024-06-15'));
    });

    test('toJson handles null end_date', () {
      final request = CreateProgramRequest(
        name: 'New Program',
        templateType: '4_day',
        startDate: DateTime(2024, 1, 15),
        trainingDays: ['monday'],
        trainingMaxes: {'squat': 250.0},
      );

      final json = request.toJson();

      expect(json['end_date'], isNull);
    });

    test('toJson includes accessories when provided', () {
      final request = CreateProgramRequest(
        name: 'New Program',
        templateType: '4_day',
        startDate: DateTime(2024, 1, 15),
        trainingDays: ['monday'],
        trainingMaxes: {'squat': 250.0},
        accessories: {
          'monday': [
            AccessoryExercise(exerciseId: 'ex-1', sets: 3, reps: 10),
            AccessoryExercise(exerciseId: 'ex-2', sets: 3, reps: 12, circuitGroup: 1),
          ],
        },
      );

      final json = request.toJson();

      expect(json['accessories'], isNotNull);
      expect(json['accessories']['monday'].length, equals(2));
      expect(json['accessories']['monday'][0]['exercise_id'], equals('ex-1'));
    });
  });

  group('AccessoryExercise', () {
    test('toJson creates correct map', () {
      final exercise = AccessoryExercise(
        exerciseId: 'exercise-123',
        sets: 3,
        reps: 10,
      );

      final json = exercise.toJson();

      expect(json['exercise_id'], equals('exercise-123'));
      expect(json['sets'], equals(3));
      expect(json['reps'], equals(10));
      expect(json.containsKey('circuit_group'), isFalse);
    });

    test('toJson includes circuit_group when provided', () {
      final exercise = AccessoryExercise(
        exerciseId: 'exercise-123',
        sets: 3,
        reps: 10,
        circuitGroup: 1,
      );

      final json = exercise.toJson();

      expect(json['circuit_group'], equals(1));
    });
  });

  group('TrainingMax', () {
    test('fromJson parses correctly', () {
      final json = {
        'value': 250.0,
        'effective_date': '2024-01-15',
        'cycle': 2,
      };

      final tm = TrainingMax.fromJson(json);

      expect(tm.value, equals(250.0));
      expect(tm.effectiveDate, equals(DateTime.parse('2024-01-15')));
      expect(tm.cycle, equals(2));
    });

    test('fromJson handles integer value', () {
      final json = {
        'value': 250,
        'effective_date': '2024-01-15',
        'cycle': 2,
      };

      final tm = TrainingMax.fromJson(json);

      expect(tm.value, equals(250.0));
      expect(tm.value, isA<double>());
    });
  });

  group('ProgramDetail', () {
    final sampleDetailJson = {
      'id': 'program-123',
      'name': 'My Program',
      'template_type': '4_day',
      'start_date': '2024-01-01',
      'end_date': null,
      'target_cycles': null,
      'include_deload': true,
      'status': 'ACTIVE',
      'training_days': ['monday', 'tuesday', 'thursday', 'friday'],
      'current_cycle': 2,
      'current_week': 3,
      'training_maxes': {
        'squat': {'value': 250.0, 'effective_date': '2024-01-01', 'cycle': 1},
        'deadlift': {'value': 300.0, 'effective_date': '2024-01-01', 'cycle': 1},
        'bench_press': {'value': 200.0, 'effective_date': '2024-01-01', 'cycle': 1},
        'press': {'value': 100.0, 'effective_date': '2024-01-01', 'cycle': 1},
      },
      'workouts_generated': 16,
      'created_at': '2024-01-01T00:00:00',
    };

    test('fromJson parses all fields correctly', () {
      final detail = ProgramDetail.fromJson(sampleDetailJson);

      expect(detail.id, equals('program-123'));
      expect(detail.name, equals('My Program'));
      expect(detail.templateType, equals('4_day'));
      expect(detail.status, equals('ACTIVE'));
      expect(detail.currentCycle, equals(2));
      expect(detail.currentWeek, equals(3));
      expect(detail.workoutsGenerated, equals(16));
    });

    test('fromJson parses training maxes correctly', () {
      final detail = ProgramDetail.fromJson(sampleDetailJson);

      expect(detail.trainingMaxes.length, equals(4));
      expect(detail.trainingMaxes['squat']?.value, equals(250.0));
      expect(detail.trainingMaxes['deadlift']?.value, equals(300.0));
      expect(detail.trainingMaxes['bench_press']?.value, equals(200.0));
      expect(detail.trainingMaxes['press']?.value, equals(100.0));
    });

    test('displayStatus returns formatted names', () {
      expect(
        ProgramDetail.fromJson({...sampleDetailJson, 'status': 'ACTIVE'}).displayStatus,
        equals('Active'),
      );
      expect(
        ProgramDetail.fromJson({...sampleDetailJson, 'status': 'COMPLETED'}).displayStatus,
        equals('Completed'),
      );
      expect(
        ProgramDetail.fromJson({...sampleDetailJson, 'status': 'PAUSED'}).displayStatus,
        equals('Paused'),
      );
    });

    test('getDisplayLiftName returns formatted names', () {
      final detail = ProgramDetail.fromJson(sampleDetailJson);

      expect(detail.getDisplayLiftName('press'), equals('Overhead Press'));
      expect(detail.getDisplayLiftName('deadlift'), equals('Deadlift'));
      expect(detail.getDisplayLiftName('bench_press'), equals('Bench Press'));
      expect(detail.getDisplayLiftName('squat'), equals('Squat'));
    });

    test('trainingDaysDisplay returns abbreviated days', () {
      final detail = ProgramDetail.fromJson(sampleDetailJson);

      expect(detail.trainingDaysDisplay, equals('MON, TUE, THU, FRI'));
    });
  });
}
