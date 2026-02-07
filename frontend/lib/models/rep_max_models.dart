/// Rep max (personal records) models.

/// Individual rep max record
class RepMaxRecord {
  final double weight;
  final double calculated1rm;
  final DateTime achievedDate;
  final String weightUnit;

  const RepMaxRecord({
    required this.weight,
    required this.calculated1rm,
    required this.achievedDate,
    required this.weightUnit,
  });

  factory RepMaxRecord.fromJson(Map<String, dynamic> json) => RepMaxRecord(
        weight: (json['weight'] as num).toDouble(),
        calculated1rm: (json['calculated_1rm'] as num).toDouble(),
        achievedDate: DateTime.parse(json['achieved_date']),
        weightUnit: json['weight_unit'],
      );

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'calculated_1rm': calculated1rm,
        'achieved_date': achievedDate.toIso8601String(),
        'weight_unit': weightUnit,
      };
}

/// Rep maxes for a single lift organized by rep count
class RepMaxByReps {
  final String liftType;
  final Map<String, RepMaxRecord> repMaxes;

  const RepMaxByReps({
    required this.liftType,
    required this.repMaxes,
  });

  factory RepMaxByReps.fromJson(Map<String, dynamic> json) {
    final repMaxesJson = json['rep_maxes'] as Map<String, dynamic>;
    final repMaxesMap = <String, RepMaxRecord>{};

    repMaxesJson.forEach((key, value) {
      repMaxesMap[key] = RepMaxRecord.fromJson(value as Map<String, dynamic>);
    });

    return RepMaxByReps(
      liftType: json['lift_type'],
      repMaxes: repMaxesMap,
    );
  }

  Map<String, dynamic> toJson() {
    final repMaxesJson = <String, dynamic>{};
    repMaxes.forEach((key, value) {
      repMaxesJson[key] = value.toJson();
    });

    return {
      'lift_type': liftType,
      'rep_maxes': repMaxesJson,
    };
  }

  /// Get rep max for specific rep count (1-12)
  RepMaxRecord? getRepMax(int reps) {
    return repMaxes[reps.toString()];
  }

  /// Get display name for lift type
  String get liftDisplayName {
    switch (liftType) {
      case 'squat':
        return 'Squat';
      case 'deadlift':
        return 'Deadlift';
      case 'bench_press':
        return 'Bench Press';
      case 'press':
        return 'Press';
      default:
        return liftType;
    }
  }
}

/// All rep maxes for all lifts
class AllRepMaxes {
  final Map<String, RepMaxRecord>? squat;
  final Map<String, RepMaxRecord>? deadlift;
  final Map<String, RepMaxRecord>? benchPress;
  final Map<String, RepMaxRecord>? press;

  const AllRepMaxes({
    this.squat,
    this.deadlift,
    this.benchPress,
    this.press,
  });

  factory AllRepMaxes.fromJson(Map<String, dynamic> json) {
    final lifts = json['lifts'] as Map<String, dynamic>;
    return AllRepMaxes(
      squat: _parseRepMaxMap(lifts['SQUAT']),
      deadlift: _parseRepMaxMap(lifts['DEADLIFT']),
      benchPress: _parseRepMaxMap(lifts['BENCH_PRESS']),
      press: _parseRepMaxMap(lifts['PRESS']),
    );
  }

  static Map<String, RepMaxRecord>? _parseRepMaxMap(dynamic json) {
    if (json == null) return null;

    final map = json as Map<String, dynamic>;
    final result = <String, RepMaxRecord>{};

    map.forEach((key, value) {
      result[key] = RepMaxRecord.fromJson(value as Map<String, dynamic>);
    });

    return result;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    if (squat != null) {
      final squatJson = <String, dynamic>{};
      squat!.forEach((key, value) {
        squatJson[key] = value.toJson();
      });
      data['squat'] = squatJson;
    }

    if (deadlift != null) {
      final deadliftJson = <String, dynamic>{};
      deadlift!.forEach((key, value) {
        deadliftJson[key] = value.toJson();
      });
      data['deadlift'] = deadliftJson;
    }

    if (benchPress != null) {
      final benchPressJson = <String, dynamic>{};
      benchPress!.forEach((key, value) {
        benchPressJson[key] = value.toJson();
      });
      data['bench_press'] = benchPressJson;
    }

    if (press != null) {
      final pressJson = <String, dynamic>{};
      press!.forEach((key, value) {
        pressJson[key] = value.toJson();
      });
      data['press'] = pressJson;
    }

    return data;
  }

  /// Get rep maxes for specific lift
  Map<String, RepMaxRecord>? getLiftRepMaxes(String liftType) {
    switch (liftType) {
      case 'squat':
        return squat;
      case 'deadlift':
        return deadlift;
      case 'bench_press':
        return benchPress;
      case 'press':
        return press;
      default:
        return null;
    }
  }

  /// Check if any records exist
  bool get hasAnyRecords {
    return squat != null ||
        deadlift != null ||
        benchPress != null ||
        press != null;
  }
}
