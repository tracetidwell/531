/// Models for workout performance analysis.

/// Analysis of failed reps across an entire cycle.
class CycleFailedRepsAnalysis {
  final String recommendation;
  final List<String> lifts;
  final String message;

  const CycleFailedRepsAnalysis({
    required this.recommendation,
    required this.lifts,
    required this.message,
  });

  factory CycleFailedRepsAnalysis.fromJson(Map<String, dynamic> json) =>
      CycleFailedRepsAnalysis(
        recommendation: json['recommendation'],
        lifts: (json['lifts'] as List?)?.map((e) => e as String).toList() ?? [],
        message: json['message'],
      );

  bool get hasRecommendation => recommendation != 'none';
  bool get isDeloadRecommended => recommendation == 'deload_then_adjust';
  bool get isTmAdjustmentRecommended => recommendation == 'adjust_training_max';
}

/// Information about a failed set.
class FailedSetInfo {
  final int setNumber;
  final String setType;
  final int prescribedReps;
  final int actualReps;
  final double prescribedWeight;

  const FailedSetInfo({
    required this.setNumber,
    required this.setType,
    required this.prescribedReps,
    required this.actualReps,
    required this.prescribedWeight,
  });

  factory FailedSetInfo.fromJson(Map<String, dynamic> json) => FailedSetInfo(
        setNumber: json['set_number'],
        setType: json['set_type'],
        prescribedReps: json['prescribed_reps'],
        actualReps: json['actual_reps'],
        prescribedWeight: (json['prescribed_weight'] as num).toDouble(),
      );
}

/// Analysis of performance for a single lift.
class LiftAnalysis {
  final String liftType;
  final bool allTargetsMet;
  final List<FailedSetInfo> failedSets;
  final int? amrapReps;
  final int? amrapMinimum;
  final bool? amrapExceededMinimum;
  final double currentTrainingMax;
  final double? estimated1rm;
  final double? suggestedTrainingMax;
  final String? recommendation;
  final String? recommendationType; // 'info', 'warning', 'critical'

  const LiftAnalysis({
    required this.liftType,
    required this.allTargetsMet,
    required this.failedSets,
    this.amrapReps,
    this.amrapMinimum,
    this.amrapExceededMinimum,
    required this.currentTrainingMax,
    this.estimated1rm,
    this.suggestedTrainingMax,
    this.recommendation,
    this.recommendationType,
  });

  factory LiftAnalysis.fromJson(Map<String, dynamic> json) => LiftAnalysis(
        liftType: json['lift_type'],
        allTargetsMet: json['all_targets_met'],
        failedSets: (json['failed_sets'] as List?)
                ?.map((e) => FailedSetInfo.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        amrapReps: json['amrap_reps'],
        amrapMinimum: json['amrap_minimum'],
        amrapExceededMinimum: json['amrap_exceeded_minimum'],
        currentTrainingMax:
            (json['current_training_max'] as num).toDouble(),
        estimated1rm: json['estimated_1rm'] != null
            ? (json['estimated_1rm'] as num).toDouble()
            : null,
        suggestedTrainingMax: json['suggested_training_max'] != null
            ? (json['suggested_training_max'] as num).toDouble()
            : null,
        recommendation: json['recommendation'],
        recommendationType: json['recommendation_type'],
      );

  /// Get human-readable lift name
  String get displayLiftType {
    switch (liftType) {
      case 'squat':
        return 'Squat';
      case 'deadlift':
        return 'Deadlift';
      case 'bench_press':
        return 'Bench Press';
      case 'press':
        return 'Overhead Press';
      default:
        return liftType;
    }
  }

  /// Check if this lift has any recommendation
  bool get hasRecommendation => recommendation != null;

  /// Check if recommendation is critical
  bool get isCritical => recommendationType == 'critical';

  /// Check if recommendation is warning
  bool get isWarning => recommendationType == 'warning';
}

/// Complete analysis of a workout.
class WorkoutAnalysis {
  final bool overallSuccess;
  final List<LiftAnalysis> lifts;
  final String summary;
  final bool hasRecommendations;
  final CycleFailedRepsAnalysis? cycleAnalysis;

  const WorkoutAnalysis({
    required this.overallSuccess,
    required this.lifts,
    required this.summary,
    required this.hasRecommendations,
    this.cycleAnalysis,
  });

  factory WorkoutAnalysis.fromJson(Map<String, dynamic> json) =>
      WorkoutAnalysis(
        overallSuccess: json['overall_success'],
        lifts: (json['lifts'] as List)
            .map((e) => LiftAnalysis.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: json['summary'],
        hasRecommendations: json['has_recommendations'],
        cycleAnalysis: json['cycle_analysis'] != null
            ? CycleFailedRepsAnalysis.fromJson(
                json['cycle_analysis'] as Map<String, dynamic>)
            : null,
      );

  /// Check if there's a cycle-level recommendation
  bool get hasCycleRecommendation =>
      cycleAnalysis != null && cycleAnalysis!.hasRecommendation;

  /// Get lifts with critical recommendations
  List<LiftAnalysis> get criticalLifts =>
      lifts.where((l) => l.isCritical).toList();

  /// Get lifts with warning recommendations
  List<LiftAnalysis> get warningLifts =>
      lifts.where((l) => l.isWarning).toList();

  /// Get lifts with any recommendations
  List<LiftAnalysis> get liftsWithRecommendations =>
      lifts.where((l) => l.hasRecommendation).toList();
}

/// Response from workout completion including analysis.
class WorkoutCompletionResponse {
  final Map<String, dynamic> workout;
  final WorkoutAnalysis analysis;

  const WorkoutCompletionResponse({
    required this.workout,
    required this.analysis,
  });

  factory WorkoutCompletionResponse.fromJson(Map<String, dynamic> json) =>
      WorkoutCompletionResponse(
        workout: json['workout'] as Map<String, dynamic>,
        analysis:
            WorkoutAnalysis.fromJson(json['analysis'] as Map<String, dynamic>),
      );
}
