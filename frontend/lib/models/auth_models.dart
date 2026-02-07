/// Authentication models for API requests and responses

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class RegisterRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String password;

  RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
      };
}

class AuthResponse {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  AuthResponse({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        userId: json['user_id'],
        firstName: json['first_name'],
        lastName: json['last_name'],
        email: json['email'],
        accessToken: json['access_token'],
        refreshToken: json['refresh_token'],
        tokenType: json['token_type'] ?? 'bearer',
      );

  User toUser() => User(
        id: userId,
        firstName: firstName,
        lastName: lastName,
        email: email,
        weightUnitPreference: 'LBS', // Defaults, will be updated when fetching full user
        roundingIncrement: 2.5,
        missedWorkoutPreference: 'ASK',
      );
}

class UpdateUserRequest {
  final String? firstName;
  final String? lastName;
  final String? weightUnitPreference;
  final double? roundingIncrement;
  final String? missedWorkoutPreference;

  UpdateUserRequest({
    this.firstName,
    this.lastName,
    this.weightUnitPreference,
    this.roundingIncrement,
    this.missedWorkoutPreference,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;
    if (weightUnitPreference != null) {
      data['weight_unit_preference'] = weightUnitPreference;
    }
    if (roundingIncrement != null) {
      data['rounding_increment'] = roundingIncrement;
    }
    if (missedWorkoutPreference != null) {
      data['missed_workout_preference'] = missedWorkoutPreference;
    }
    return data;
  }
}

class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String weightUnitPreference;
  final double roundingIncrement;
  final String missedWorkoutPreference;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.weightUnitPreference,
    required this.roundingIncrement,
    required this.missedWorkoutPreference,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        firstName: json['first_name'],
        lastName: json['last_name'],
        email: json['email'],
        weightUnitPreference: json['weight_unit_preference'],
        roundingIncrement: (json['rounding_increment'] as num).toDouble(),
        missedWorkoutPreference: json['missed_workout_preference'],
      );

  String get fullName => '$firstName $lastName';
}
