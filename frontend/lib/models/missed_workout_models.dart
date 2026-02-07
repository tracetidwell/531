import 'workout_models.dart';

/// Information about a missed workout.
class MissedWorkoutInfo {
  final Workout workout;
  final int daysOverdue;
  final bool canReschedule;

  const MissedWorkoutInfo({
    required this.workout,
    required this.daysOverdue,
    required this.canReschedule,
  });

  factory MissedWorkoutInfo.fromJson(Map<String, dynamic> json) =>
      MissedWorkoutInfo(
        workout: Workout.fromJson(json['workout'] as Map<String, dynamic>),
        daysOverdue: json['days_overdue'],
        canReschedule: json['can_reschedule'],
      );
}

/// Response containing all missed workouts.
class MissedWorkoutsResponse {
  final List<MissedWorkoutInfo> missedWorkouts;
  final String userPreference;
  final int count;

  const MissedWorkoutsResponse({
    required this.missedWorkouts,
    required this.userPreference,
    required this.count,
  });

  factory MissedWorkoutsResponse.fromJson(Map<String, dynamic> json) =>
      MissedWorkoutsResponse(
        missedWorkouts: (json['missed_workouts'] as List)
            .map((e) => MissedWorkoutInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        userPreference: json['user_preference'],
        count: json['count'],
      );

  bool get hasMissedWorkouts => count > 0;
}

/// Response after handling a missed workout.
class HandleMissedWorkoutResponse {
  final Workout workout;
  final String actionTaken;
  final int rescheduledCount;

  const HandleMissedWorkoutResponse({
    required this.workout,
    required this.actionTaken,
    required this.rescheduledCount,
  });

  factory HandleMissedWorkoutResponse.fromJson(Map<String, dynamic> json) =>
      HandleMissedWorkoutResponse(
        workout: Workout.fromJson(json['workout'] as Map<String, dynamic>),
        actionTaken: json['action_taken'],
        rescheduledCount: json['rescheduled_count'],
      );
}
