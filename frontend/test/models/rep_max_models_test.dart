import 'package:flutter_test/flutter_test.dart';
import 'package:five_three_one/models/rep_max_models.dart';

void main() {
  group('RepMaxRecord', () {
    test('fromJson parses correctly', () {
      final json = {
        'weight': 225.0,
        'calculated_1rm': 262.5,
        'achieved_date': '2024-01-15',
        'weight_unit': 'LBS',
      };

      final record = RepMaxRecord.fromJson(json);

      expect(record.weight, equals(225.0));
      expect(record.calculated1rm, equals(262.5));
      expect(record.achievedDate, equals(DateTime.parse('2024-01-15')));
      expect(record.weightUnit, equals('LBS'));
    });

    test('fromJson handles integer weight values', () {
      final json = {
        'weight': 225,
        'calculated_1rm': 262,
        'achieved_date': '2024-01-15',
        'weight_unit': 'LBS',
      };

      final record = RepMaxRecord.fromJson(json);

      expect(record.weight, equals(225.0));
      expect(record.calculated1rm, equals(262.0));
      expect(record.weight, isA<double>());
      expect(record.calculated1rm, isA<double>());
    });

    test('toJson creates correct map', () {
      final record = RepMaxRecord(
        weight: 225.0,
        calculated1rm: 262.5,
        achievedDate: DateTime(2024, 1, 15),
        weightUnit: 'LBS',
      );

      final json = record.toJson();

      expect(json['weight'], equals(225.0));
      expect(json['calculated_1rm'], equals(262.5));
      expect(json['achieved_date'], contains('2024-01-15'));
      expect(json['weight_unit'], equals('LBS'));
    });
  });

  group('RepMaxByReps', () {
    final sampleJson = {
      'lift_type': 'squat',
      'rep_maxes': {
        '5': {
          'weight': 225.0,
          'calculated_1rm': 262.5,
          'achieved_date': '2024-01-15',
          'weight_unit': 'LBS',
        },
        '3': {
          'weight': 240.0,
          'calculated_1rm': 264.0,
          'achieved_date': '2024-01-20',
          'weight_unit': 'LBS',
        },
      },
    };

    test('fromJson parses correctly', () {
      final repMaxByReps = RepMaxByReps.fromJson(sampleJson);

      expect(repMaxByReps.liftType, equals('squat'));
      expect(repMaxByReps.repMaxes.length, equals(2));
      expect(repMaxByReps.repMaxes['5']?.weight, equals(225.0));
      expect(repMaxByReps.repMaxes['3']?.weight, equals(240.0));
    });

    test('getRepMax returns correct record', () {
      final repMaxByReps = RepMaxByReps.fromJson(sampleJson);

      final fiveRm = repMaxByReps.getRepMax(5);
      final threeRm = repMaxByReps.getRepMax(3);
      final oneRm = repMaxByReps.getRepMax(1);

      expect(fiveRm?.weight, equals(225.0));
      expect(threeRm?.weight, equals(240.0));
      expect(oneRm, isNull);
    });

    test('liftDisplayName returns formatted names', () {
      expect(
        RepMaxByReps(liftType: 'squat', repMaxes: {}).liftDisplayName,
        equals('Squat'),
      );
      expect(
        RepMaxByReps(liftType: 'deadlift', repMaxes: {}).liftDisplayName,
        equals('Deadlift'),
      );
      expect(
        RepMaxByReps(liftType: 'bench_press', repMaxes: {}).liftDisplayName,
        equals('Bench Press'),
      );
      expect(
        RepMaxByReps(liftType: 'press', repMaxes: {}).liftDisplayName,
        equals('Press'),
      );
    });

    test('liftDisplayName returns raw value for unknown types', () {
      final repMax = RepMaxByReps(liftType: 'unknown_lift', repMaxes: {});
      expect(repMax.liftDisplayName, equals('unknown_lift'));
    });

    test('toJson creates correct map', () {
      final repMaxByReps = RepMaxByReps.fromJson(sampleJson);
      final json = repMaxByReps.toJson();

      expect(json['lift_type'], equals('squat'));
      expect(json['rep_maxes'], isA<Map<String, dynamic>>());
      expect((json['rep_maxes'] as Map)['5']['weight'], equals(225.0));
    });
  });

  group('AllRepMaxes', () {
    final sampleJson = {
      'lifts': {
        'SQUAT': {
          '5': {
            'weight': 225.0,
            'calculated_1rm': 262.5,
            'achieved_date': '2024-01-15',
            'weight_unit': 'LBS',
          },
        },
        'DEADLIFT': {
          '3': {
            'weight': 315.0,
            'calculated_1rm': 346.5,
            'achieved_date': '2024-01-20',
            'weight_unit': 'LBS',
          },
        },
        'BENCH_PRESS': null,
        'PRESS': null,
      },
    };

    test('fromJson parses correctly', () {
      final allRepMaxes = AllRepMaxes.fromJson(sampleJson);

      expect(allRepMaxes.squat, isNotNull);
      expect(allRepMaxes.deadlift, isNotNull);
      expect(allRepMaxes.benchPress, isNull);
      expect(allRepMaxes.press, isNull);
    });

    test('fromJson parses squat rep maxes correctly', () {
      final allRepMaxes = AllRepMaxes.fromJson(sampleJson);

      expect(allRepMaxes.squat?['5']?.weight, equals(225.0));
      expect(allRepMaxes.squat?['5']?.calculated1rm, equals(262.5));
    });

    test('fromJson parses deadlift rep maxes correctly', () {
      final allRepMaxes = AllRepMaxes.fromJson(sampleJson);

      expect(allRepMaxes.deadlift?['3']?.weight, equals(315.0));
      expect(allRepMaxes.deadlift?['3']?.calculated1rm, equals(346.5));
    });

    test('getLiftRepMaxes returns correct lift data', () {
      final allRepMaxes = AllRepMaxes.fromJson(sampleJson);

      expect(allRepMaxes.getLiftRepMaxes('squat'), isNotNull);
      expect(allRepMaxes.getLiftRepMaxes('deadlift'), isNotNull);
      expect(allRepMaxes.getLiftRepMaxes('bench_press'), isNull);
      expect(allRepMaxes.getLiftRepMaxes('press'), isNull);
      expect(allRepMaxes.getLiftRepMaxes('unknown'), isNull);
    });

    test('hasAnyRecords returns true when records exist', () {
      final allRepMaxes = AllRepMaxes.fromJson(sampleJson);

      expect(allRepMaxes.hasAnyRecords, isTrue);
    });

    test('hasAnyRecords returns false when no records', () {
      final emptyJson = {
        'lifts': {
          'SQUAT': null,
          'DEADLIFT': null,
          'BENCH_PRESS': null,
          'PRESS': null,
        },
      };

      final allRepMaxes = AllRepMaxes.fromJson(emptyJson);

      expect(allRepMaxes.hasAnyRecords, isFalse);
    });

    test('toJson creates correct map', () {
      final allRepMaxes = AllRepMaxes(
        squat: {
          '5': RepMaxRecord(
            weight: 225.0,
            calculated1rm: 262.5,
            achievedDate: DateTime(2024, 1, 15),
            weightUnit: 'LBS',
          ),
        },
        deadlift: null,
        benchPress: null,
        press: null,
      );

      final json = allRepMaxes.toJson();

      expect(json['squat'], isNotNull);
      expect(json['squat']['5']['weight'], equals(225.0));
      expect(json.containsKey('deadlift'), isFalse);
    });

    test('fromJson handles all lifts having records', () {
      final fullJson = {
        'lifts': {
          'SQUAT': {
            '5': {
              'weight': 225.0,
              'calculated_1rm': 262.5,
              'achieved_date': '2024-01-15',
              'weight_unit': 'LBS',
            },
          },
          'DEADLIFT': {
            '5': {
              'weight': 315.0,
              'calculated_1rm': 367.5,
              'achieved_date': '2024-01-15',
              'weight_unit': 'LBS',
            },
          },
          'BENCH_PRESS': {
            '5': {
              'weight': 185.0,
              'calculated_1rm': 215.8,
              'achieved_date': '2024-01-15',
              'weight_unit': 'LBS',
            },
          },
          'PRESS': {
            '5': {
              'weight': 115.0,
              'calculated_1rm': 134.2,
              'achieved_date': '2024-01-15',
              'weight_unit': 'LBS',
            },
          },
        },
      };

      final allRepMaxes = AllRepMaxes.fromJson(fullJson);

      expect(allRepMaxes.squat, isNotNull);
      expect(allRepMaxes.deadlift, isNotNull);
      expect(allRepMaxes.benchPress, isNotNull);
      expect(allRepMaxes.press, isNotNull);
      expect(allRepMaxes.hasAnyRecords, isTrue);
    });
  });
}
