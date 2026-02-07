/// Exercise-related models for the 5/3/1 app.
///
/// Represents exercises (both predefined from book and user-created custom).

enum ExerciseCategory {
  push,
  pull,
  legs,
  core;

  String get displayName {
    switch (this) {
      case ExerciseCategory.push:
        return 'Push';
      case ExerciseCategory.pull:
        return 'Pull';
      case ExerciseCategory.legs:
        return 'Legs';
      case ExerciseCategory.core:
        return 'Core';
    }
  }

  static ExerciseCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'push':
        return ExerciseCategory.push;
      case 'pull':
        return ExerciseCategory.pull;
      case 'legs':
        return ExerciseCategory.legs;
      case 'core':
        return ExerciseCategory.core;
      default:
        throw ArgumentError('Invalid exercise category: $value');
    }
  }
}

/// Represents a single exercise (predefined or custom).
class Exercise {
  final String id;
  final String name;
  final ExerciseCategory category;
  final bool isPredefined;
  final String? description;

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.isPredefined,
    this.description,
  });

  /// Create from JSON response
  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      category: ExerciseCategory.fromString(json['category'] as String),
      isPredefined: json['is_predefined'] as bool,
      description: json['description'] as String?,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name.toUpperCase(),
      'is_predefined': isPredefined,
      if (description != null) 'description': description,
    };
  }

  Exercise copyWith({
    String? id,
    String? name,
    ExerciseCategory? category,
    bool? isPredefined,
    String? description,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      isPredefined: isPredefined ?? this.isPredefined,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Exercise &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Exercise($name, $category)';
}

/// Request model for creating a custom exercise
class ExerciseCreateRequest {
  final String name;
  final ExerciseCategory category;
  final String? description;

  ExerciseCreateRequest({
    required this.name,
    required this.category,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category.name.toUpperCase(),
      if (description != null) 'description': description,
    };
  }
}

/// Represents an accessory exercise with sets/reps in a program template
class AccessoryExerciseDetail {
  final Exercise exercise;
  final int sets;
  final int reps;
  final int? circuitGroup; // null = standalone, 1+ = circuit group number

  AccessoryExerciseDetail({
    required this.exercise,
    required this.sets,
    required this.reps,
    this.circuitGroup,
  });

  /// Create simple reference for API (just ID, sets, reps, circuit_group)
  Map<String, dynamic> toApiJson() {
    return {
      'exercise_id': exercise.id,
      'sets': sets,
      'reps': reps,
      if (circuitGroup != null) 'circuit_group': circuitGroup,
    };
  }

  AccessoryExerciseDetail copyWith({
    Exercise? exercise,
    int? sets,
    int? reps,
    int? circuitGroup,
    bool clearCircuitGroup = false,
  }) {
    return AccessoryExerciseDetail(
      exercise: exercise ?? this.exercise,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      circuitGroup: clearCircuitGroup ? null : (circuitGroup ?? this.circuitGroup),
    );
  }

  @override
  String toString() =>
      'AccessoryExerciseDetail(${exercise.name}, $sets×$reps${circuitGroup != null ? ', circuit $circuitGroup' : ''})';
}
