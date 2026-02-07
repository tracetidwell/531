/// Analytics-related models for progress charts.

/// Single data point for training max progression
class TrainingMaxDataPoint {
  final DateTime date;
  final double value;
  final int cycle;

  const TrainingMaxDataPoint({
    required this.date,
    required this.value,
    required this.cycle,
  });

  factory TrainingMaxDataPoint.fromJson(Map<String, dynamic> json) =>
      TrainingMaxDataPoint(
        date: DateTime.parse(json['date']),
        value: (json['value'] as num).toDouble(),
        cycle: json['cycle'],
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().split('T')[0],
        'value': value,
        'cycle': cycle,
      };
}

/// Training max progression data for all lifts
class TrainingMaxProgression {
  final List<TrainingMaxDataPoint> squat;
  final List<TrainingMaxDataPoint> deadlift;
  final List<TrainingMaxDataPoint> benchPress;
  final List<TrainingMaxDataPoint> press;

  const TrainingMaxProgression({
    required this.squat,
    required this.deadlift,
    required this.benchPress,
    required this.press,
  });

  factory TrainingMaxProgression.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return TrainingMaxProgression(
      squat: _parseDataPoints(data['squat']),
      deadlift: _parseDataPoints(data['deadlift']),
      benchPress: _parseDataPoints(data['bench_press']),
      press: _parseDataPoints(data['press']),
    );
  }

  static List<TrainingMaxDataPoint> _parseDataPoints(dynamic json) {
    if (json == null) return [];
    return (json as List)
        .map((item) =>
            TrainingMaxDataPoint.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Get data points for a specific lift
  List<TrainingMaxDataPoint> getLiftData(String liftType) {
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
        return [];
    }
  }

  /// Check if any progression data exists
  bool get hasData =>
      squat.isNotEmpty ||
      deadlift.isNotEmpty ||
      benchPress.isNotEmpty ||
      press.isNotEmpty;

  /// Get all lift types that have data
  List<String> get availableLifts {
    final lifts = <String>[];
    if (squat.isNotEmpty) lifts.add('squat');
    if (deadlift.isNotEmpty) lifts.add('deadlift');
    if (benchPress.isNotEmpty) lifts.add('bench_press');
    if (press.isNotEmpty) lifts.add('press');
    return lifts;
  }
}
