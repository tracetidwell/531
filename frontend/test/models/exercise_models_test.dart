import 'package:flutter_test/flutter_test.dart';
import 'package:five_three_one/models/exercise_models.dart';

void main() {
  group('ExerciseCategory', () {
    test('displayName returns correct formatted names', () {
      expect(ExerciseCategory.push.displayName, equals('Push'));
      expect(ExerciseCategory.pull.displayName, equals('Pull'));
      expect(ExerciseCategory.legs.displayName, equals('Legs'));
      expect(ExerciseCategory.core.displayName, equals('Core'));
    });

    test('fromString parses lowercase category names', () {
      expect(ExerciseCategory.fromString('push'), equals(ExerciseCategory.push));
      expect(ExerciseCategory.fromString('pull'), equals(ExerciseCategory.pull));
      expect(ExerciseCategory.fromString('legs'), equals(ExerciseCategory.legs));
      expect(ExerciseCategory.fromString('core'), equals(ExerciseCategory.core));
    });

    test('fromString parses uppercase category names', () {
      expect(ExerciseCategory.fromString('PUSH'), equals(ExerciseCategory.push));
      expect(ExerciseCategory.fromString('PULL'), equals(ExerciseCategory.pull));
      expect(ExerciseCategory.fromString('LEGS'), equals(ExerciseCategory.legs));
      expect(ExerciseCategory.fromString('CORE'), equals(ExerciseCategory.core));
    });

    test('fromString throws for invalid category', () {
      expect(
        () => ExerciseCategory.fromString('invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Exercise', () {
    final sampleJson = {
      'id': 'exercise-123',
      'name': 'Barbell Row',
      'category': 'pull',
      'is_predefined': true,
      'description': 'A compound back exercise',
    };

    test('fromJson parses all fields correctly', () {
      final exercise = Exercise.fromJson(sampleJson);

      expect(exercise.id, equals('exercise-123'));
      expect(exercise.name, equals('Barbell Row'));
      expect(exercise.category, equals(ExerciseCategory.pull));
      expect(exercise.isPredefined, isTrue);
      expect(exercise.description, equals('A compound back exercise'));
    });

    test('fromJson handles null description', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['description'] = null;

      final exercise = Exercise.fromJson(json);

      expect(exercise.description, isNull);
    });

    test('toJson creates correct map', () {
      final exercise = Exercise.fromJson(sampleJson);
      final json = exercise.toJson();

      expect(json['id'], equals('exercise-123'));
      expect(json['name'], equals('Barbell Row'));
      expect(json['category'], equals('PULL'));
      expect(json['is_predefined'], isTrue);
      expect(json['description'], equals('A compound back exercise'));
    });

    test('toJson excludes null description', () {
      final exercise = Exercise(
        id: 'ex-1',
        name: 'Test',
        category: ExerciseCategory.push,
        isPredefined: false,
      );

      final json = exercise.toJson();

      expect(json.containsKey('description'), isFalse);
    });

    test('copyWith creates modified copy', () {
      final original = Exercise.fromJson(sampleJson);
      final copy = original.copyWith(name: 'Modified Row', isPredefined: false);

      expect(copy.id, equals(original.id));
      expect(copy.name, equals('Modified Row'));
      expect(copy.category, equals(original.category));
      expect(copy.isPredefined, isFalse);
    });

    test('equality is based on id', () {
      final exercise1 = Exercise(
        id: 'same-id',
        name: 'Exercise 1',
        category: ExerciseCategory.push,
        isPredefined: true,
      );
      final exercise2 = Exercise(
        id: 'same-id',
        name: 'Different Name',
        category: ExerciseCategory.pull,
        isPredefined: false,
      );
      final exercise3 = Exercise(
        id: 'different-id',
        name: 'Exercise 1',
        category: ExerciseCategory.push,
        isPredefined: true,
      );

      expect(exercise1 == exercise2, isTrue);
      expect(exercise1 == exercise3, isFalse);
    });

    test('hashCode is based on id', () {
      final exercise1 = Exercise(
        id: 'same-id',
        name: 'Exercise 1',
        category: ExerciseCategory.push,
        isPredefined: true,
      );
      final exercise2 = Exercise(
        id: 'same-id',
        name: 'Different Name',
        category: ExerciseCategory.pull,
        isPredefined: false,
      );

      expect(exercise1.hashCode, equals(exercise2.hashCode));
    });

    test('toString returns readable format', () {
      final exercise = Exercise.fromJson(sampleJson);

      expect(exercise.toString(), contains('Barbell Row'));
      expect(exercise.toString(), contains('pull'));
    });
  });

  group('ExerciseCreateRequest', () {
    test('toJson creates correct map', () {
      final request = ExerciseCreateRequest(
        name: 'Custom Exercise',
        category: ExerciseCategory.core,
        description: 'My custom exercise',
      );

      final json = request.toJson();

      expect(json['name'], equals('Custom Exercise'));
      expect(json['category'], equals('CORE'));
      expect(json['description'], equals('My custom exercise'));
    });

    test('toJson excludes null description', () {
      final request = ExerciseCreateRequest(
        name: 'Custom Exercise',
        category: ExerciseCategory.core,
      );

      final json = request.toJson();

      expect(json.containsKey('description'), isFalse);
    });

    test('toJson uses uppercase category', () {
      final request = ExerciseCreateRequest(
        name: 'Test',
        category: ExerciseCategory.push,
      );

      final json = request.toJson();

      expect(json['category'], equals('PUSH'));
    });
  });

  group('AccessoryExerciseDetail', () {
    final sampleExercise = Exercise(
      id: 'ex-123',
      name: 'Dumbbell Press',
      category: ExerciseCategory.push,
      isPredefined: true,
    );

    test('toApiJson creates correct reference', () {
      final detail = AccessoryExerciseDetail(
        exercise: sampleExercise,
        sets: 3,
        reps: 10,
      );

      final json = detail.toApiJson();

      expect(json['exercise_id'], equals('ex-123'));
      expect(json['sets'], equals(3));
      expect(json['reps'], equals(10));
      expect(json.containsKey('circuit_group'), isFalse);
    });

    test('toApiJson includes circuit_group when set', () {
      final detail = AccessoryExerciseDetail(
        exercise: sampleExercise,
        sets: 3,
        reps: 10,
        circuitGroup: 1,
      );

      final json = detail.toApiJson();

      expect(json['circuit_group'], equals(1));
    });

    test('copyWith creates modified copy', () {
      final original = AccessoryExerciseDetail(
        exercise: sampleExercise,
        sets: 3,
        reps: 10,
        circuitGroup: 1,
      );

      final copy = original.copyWith(sets: 4, reps: 12);

      expect(copy.exercise, equals(original.exercise));
      expect(copy.sets, equals(4));
      expect(copy.reps, equals(12));
      expect(copy.circuitGroup, equals(1));
    });

    test('copyWith can clear circuit_group', () {
      final original = AccessoryExerciseDetail(
        exercise: sampleExercise,
        sets: 3,
        reps: 10,
        circuitGroup: 1,
      );

      final copy = original.copyWith(clearCircuitGroup: true);

      expect(copy.circuitGroup, isNull);
    });

    test('toString includes circuit group when present', () {
      final withCircuit = AccessoryExerciseDetail(
        exercise: sampleExercise,
        sets: 3,
        reps: 10,
        circuitGroup: 1,
      );
      final withoutCircuit = AccessoryExerciseDetail(
        exercise: sampleExercise,
        sets: 3,
        reps: 10,
      );

      expect(withCircuit.toString(), contains('circuit 1'));
      expect(withoutCircuit.toString(), isNot(contains('circuit')));
    });
  });
}
