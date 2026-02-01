import 'package:flutter_test/flutter_test.dart';
import 'package:five_three_one/models/auth_models.dart';

void main() {
  group('LoginRequest', () {
    test('toJson creates correct map', () {
      final request = LoginRequest(
        email: 'test@example.com',
        password: 'password123',
      );

      final json = request.toJson();

      expect(json['email'], equals('test@example.com'));
      expect(json['password'], equals('password123'));
    });
  });

  group('RegisterRequest', () {
    test('toJson creates correct map', () {
      final request = RegisterRequest(
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        password: 'securePass123',
      );

      final json = request.toJson();

      expect(json['first_name'], equals('John'));
      expect(json['last_name'], equals('Doe'));
      expect(json['email'], equals('john@example.com'));
      expect(json['password'], equals('securePass123'));
    });
  });

  group('AuthResponse', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'user_id': 'user-123',
        'first_name': 'John',
        'last_name': 'Doe',
        'email': 'john@example.com',
        'access_token': 'access-token-abc',
        'refresh_token': 'refresh-token-xyz',
        'token_type': 'bearer',
      };

      final response = AuthResponse.fromJson(json);

      expect(response.userId, equals('user-123'));
      expect(response.firstName, equals('John'));
      expect(response.lastName, equals('Doe'));
      expect(response.email, equals('john@example.com'));
      expect(response.accessToken, equals('access-token-abc'));
      expect(response.refreshToken, equals('refresh-token-xyz'));
      expect(response.tokenType, equals('bearer'));
    });

    test('fromJson defaults token_type to bearer when missing', () {
      final json = {
        'user_id': 'user-123',
        'first_name': 'John',
        'last_name': 'Doe',
        'email': 'john@example.com',
        'access_token': 'access-token-abc',
        'refresh_token': 'refresh-token-xyz',
      };

      final response = AuthResponse.fromJson(json);

      expect(response.tokenType, equals('bearer'));
    });

    test('toUser creates User with correct fields', () {
      final authResponse = AuthResponse(
        userId: 'user-123',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        accessToken: 'token',
        refreshToken: 'refresh',
        tokenType: 'bearer',
      );

      final user = authResponse.toUser();

      expect(user.id, equals('user-123'));
      expect(user.firstName, equals('John'));
      expect(user.lastName, equals('Doe'));
      expect(user.email, equals('john@example.com'));
      expect(user.weightUnitPreference, equals('LBS'));
      expect(user.roundingIncrement, equals(2.5));
      expect(user.missedWorkoutPreference, equals('ASK'));
    });
  });

  group('User', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'user-456',
        'first_name': 'Jane',
        'last_name': 'Smith',
        'email': 'jane@example.com',
        'weight_unit_preference': 'KG',
        'rounding_increment': 2.5,
        'missed_workout_preference': 'SKIP',
      };

      final user = User.fromJson(json);

      expect(user.id, equals('user-456'));
      expect(user.firstName, equals('Jane'));
      expect(user.lastName, equals('Smith'));
      expect(user.email, equals('jane@example.com'));
      expect(user.weightUnitPreference, equals('KG'));
      expect(user.roundingIncrement, equals(2.5));
      expect(user.missedWorkoutPreference, equals('SKIP'));
    });

    test('fromJson handles integer rounding_increment', () {
      final json = {
        'id': 'user-456',
        'first_name': 'Jane',
        'last_name': 'Smith',
        'email': 'jane@example.com',
        'weight_unit_preference': 'LBS',
        'rounding_increment': 5,
        'missed_workout_preference': 'ASK',
      };

      final user = User.fromJson(json);

      expect(user.roundingIncrement, equals(5.0));
      expect(user.roundingIncrement, isA<double>());
    });

    test('fullName returns correct combined name', () {
      final user = User(
        id: 'user-123',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        weightUnitPreference: 'LBS',
        roundingIncrement: 5.0,
        missedWorkoutPreference: 'ASK',
      );

      expect(user.fullName, equals('John Doe'));
    });
  });

  group('UpdateUserRequest', () {
    test('toJson includes only non-null fields', () {
      final request = UpdateUserRequest(
        firstName: 'John',
        weightUnitPreference: 'KG',
      );

      final json = request.toJson();

      expect(json['first_name'], equals('John'));
      expect(json['weight_unit_preference'], equals('KG'));
      expect(json.containsKey('last_name'), isFalse);
      expect(json.containsKey('rounding_increment'), isFalse);
      expect(json.containsKey('missed_workout_preference'), isFalse);
    });

    test('toJson includes all fields when provided', () {
      final request = UpdateUserRequest(
        firstName: 'John',
        lastName: 'Doe',
        weightUnitPreference: 'KG',
        roundingIncrement: 2.5,
        missedWorkoutPreference: 'SKIP',
      );

      final json = request.toJson();

      expect(json['first_name'], equals('John'));
      expect(json['last_name'], equals('Doe'));
      expect(json['weight_unit_preference'], equals('KG'));
      expect(json['rounding_increment'], equals(2.5));
      expect(json['missed_workout_preference'], equals('SKIP'));
    });

    test('toJson returns empty map when all fields null', () {
      final request = UpdateUserRequest();

      final json = request.toJson();

      expect(json, isEmpty);
    });
  });
}
