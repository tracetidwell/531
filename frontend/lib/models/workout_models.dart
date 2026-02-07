class WorkoutMainLift {
  final String liftType;
  final int liftOrder;
  final double currentTrainingMax;

  WorkoutMainLift({
    required this.liftType,
    required this.liftOrder,
    required this.currentTrainingMax,
  });

  factory WorkoutMainLift.fromJson(Map<String, dynamic> json) {
    return WorkoutMainLift(
      liftType: json['lift_type'].toString(),
      liftOrder: json['lift_order'] is int
          ? json['lift_order']
          : int.parse(json['lift_order'].toString()),
      currentTrainingMax: json['current_training_max'] is double
          ? json['current_training_max']
          : double.parse(json['current_training_max'].toString()),
    );
  }

  String get displayLiftType {
    switch (liftType) {
      case 'PRESS':
        return 'Press';
      case 'DEADLIFT':
        return 'Deadlift';
      case 'BENCH_PRESS':
        return 'Bench Press';
      case 'SQUAT':
        return 'Squat';
      default:
        return liftType;
    }
  }
}

class Workout {
  final String id;
  final String programId;
  final DateTime scheduledDate;
  final DateTime? completedDate;
  final int cycleNumber;
  final int weekNumber;
  final String weekType;
  final List<WorkoutMainLift> mainLifts;
  final String status;
  final String? notes;
  final DateTime createdAt;

  Workout({
    required this.id,
    required this.programId,
    required this.scheduledDate,
    this.completedDate,
    required this.cycleNumber,
    required this.weekNumber,
    required this.weekType,
    required this.mainLifts,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'].toString(),
      programId: json['program_id'].toString(),
      scheduledDate: DateTime.parse(json['scheduled_date']),
      completedDate: json['completed_date'] != null
          ? DateTime.parse(json['completed_date'])
          : null,
      cycleNumber: json['cycle_number'] is int
          ? json['cycle_number']
          : int.parse(json['cycle_number'].toString()),
      weekNumber: json['week_number'] is int
          ? json['week_number']
          : int.parse(json['week_number'].toString()),
      weekType: json['week_type'].toString(),
      mainLifts: (json['main_lifts'] as List)
          .map((ml) => WorkoutMainLift.fromJson(ml))
          .toList(),
      status: json['status'].toString(),
      notes: json['notes']?.toString(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get displayMainLifts {
    return mainLifts.map((ml) => ml.displayLiftType).join(' + ');
  }

  String get displayWeekType {
    switch (weekType) {
      case 'WEEK_1_5S':
        return 'Week 1: 5s';
      case 'WEEK_2_3S':
        return 'Week 2: 3s';
      case 'WEEK_3_531':
        return 'Week 3: 5/3/1';
      case 'WEEK_4_DELOAD':
        return 'Week 4: Deload';
      default:
        return weekType;
    }
  }

  String get displayStatus {
    switch (status) {
      case 'SCHEDULED':
        return 'Scheduled';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'COMPLETED':
        return 'Completed';
      case 'SKIPPED':
        return 'Skipped';
      default:
        return status;
    }
  }

  bool get isCompleted => status == 'COMPLETED';
  bool get isScheduled => status == 'SCHEDULED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isSkipped => status == 'SKIPPED';
}

class WorkoutSet {
  final String? id;
  final String setType;
  final int setNumber;
  final int? prescribedReps;
  final double? prescribedWeight;
  final double? percentageOfTm;
  final int? actualReps;
  final double? actualWeight;
  final bool? isTargetMet;
  final String? notes;
  final String? exerciseId; // For accessory exercises
  final int? circuitGroup; // For circuit training (null = standalone)

  WorkoutSet({
    this.id,
    required this.setType,
    required this.setNumber,
    this.prescribedReps,
    this.prescribedWeight,
    this.percentageOfTm,
    this.actualReps,
    this.actualWeight,
    this.isTargetMet,
    this.notes,
    this.exerciseId,
    this.circuitGroup,
  });

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      id: json['id']?.toString(),
      setType: json['set_type'].toString(),
      setNumber: json['set_number'] is int
          ? json['set_number']
          : int.parse(json['set_number'].toString()),
      prescribedReps: json['prescribed_reps'] != null
          ? (json['prescribed_reps'] is int
              ? json['prescribed_reps']
              : int.tryParse(json['prescribed_reps'].toString()))
          : null,
      prescribedWeight: json['prescribed_weight'] != null
          ? (json['prescribed_weight'] is double
              ? json['prescribed_weight']
              : double.tryParse(json['prescribed_weight'].toString()))
          : null,
      percentageOfTm: json['percentage_of_tm'] != null
          ? (json['percentage_of_tm'] is double
              ? json['percentage_of_tm']
              : double.tryParse(json['percentage_of_tm'].toString()))
          : null,
      actualReps: json['actual_reps'] != null
          ? (json['actual_reps'] is int
              ? json['actual_reps']
              : int.tryParse(json['actual_reps'].toString()))
          : null,
      actualWeight: json['actual_weight'] != null
          ? (json['actual_weight'] is double
              ? json['actual_weight']
              : double.tryParse(json['actual_weight'].toString()))
          : null,
      isTargetMet: json['is_target_met'],
      notes: json['notes']?.toString(),
      exerciseId: json['exercise_id']?.toString(),
      circuitGroup: json['circuit_group'] != null
          ? (json['circuit_group'] is int
              ? json['circuit_group']
              : int.tryParse(json['circuit_group'].toString()))
          : null,
    );
  }
}

class WorkoutSetsForLift {
  final List<WorkoutSet> warmupSets;
  final List<WorkoutSet> mainSets;

  WorkoutSetsForLift({
    required this.warmupSets,
    required this.mainSets,
  });

  factory WorkoutSetsForLift.fromJson(Map<String, dynamic> json) {
    return WorkoutSetsForLift(
      warmupSets: (json['warmup_sets'] as List)
          .map((s) => WorkoutSet.fromJson(s))
          .toList(),
      mainSets: (json['main_sets'] as List)
          .map((s) => WorkoutSet.fromJson(s))
          .toList(),
    );
  }
}

class WorkoutDetail {
  final String id;
  final String programId;
  final DateTime scheduledDate;
  final DateTime? completedDate;
  final int cycleNumber;
  final int weekNumber;
  final String weekType;
  final List<WorkoutMainLift> mainLifts;
  final String status;
  final Map<String, WorkoutSetsForLift> setsByLift;
  final List<WorkoutSet> accessorySets;
  final String? notes;
  final DateTime createdAt;

  WorkoutDetail({
    required this.id,
    required this.programId,
    required this.scheduledDate,
    this.completedDate,
    required this.cycleNumber,
    required this.weekNumber,
    required this.weekType,
    required this.mainLifts,
    required this.status,
    required this.setsByLift,
    required this.accessorySets,
    this.notes,
    required this.createdAt,
  });

  factory WorkoutDetail.fromJson(Map<String, dynamic> json) {
    // Parse sets_by_lift map
    final setsByLiftJson = json['sets_by_lift'] as Map<String, dynamic>;
    final setsByLift = <String, WorkoutSetsForLift>{};
    setsByLiftJson.forEach((key, value) {
      setsByLift[key] = WorkoutSetsForLift.fromJson(value as Map<String, dynamic>);
    });

    // Parse accessory_sets at workout level
    final accessorySets = (json['accessory_sets'] as List)
        .map((s) => WorkoutSet.fromJson(s))
        .toList();

    return WorkoutDetail(
      id: json['id'].toString(),
      programId: json['program_id'].toString(),
      scheduledDate: DateTime.parse(json['scheduled_date']),
      completedDate: json['completed_date'] != null
          ? DateTime.parse(json['completed_date'])
          : null,
      cycleNumber: json['cycle_number'] is int
          ? json['cycle_number']
          : int.parse(json['cycle_number'].toString()),
      weekNumber: json['week_number'] is int
          ? json['week_number']
          : int.parse(json['week_number'].toString()),
      weekType: json['week_type'].toString(),
      mainLifts: (json['main_lifts'] as List)
          .map((ml) => WorkoutMainLift.fromJson(ml))
          .toList(),
      status: json['status'].toString(),
      setsByLift: setsByLift,
      accessorySets: accessorySets,
      notes: json['notes']?.toString(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
