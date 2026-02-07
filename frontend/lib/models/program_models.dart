class Program {
  final String id;
  final String name;
  final String templateType;
  final DateTime startDate;
  final DateTime? endDate;
  final int? targetCycles;
  final bool includeDeload;
  final List<String> trainingDays;
  final String status;
  final int? currentCycle;
  final DateTime createdAt;

  Program({
    required this.id,
    required this.name,
    required this.templateType,
    required this.startDate,
    this.endDate,
    this.targetCycles,
    this.includeDeload = true,
    required this.trainingDays,
    required this.status,
    this.currentCycle,
    required this.createdAt,
  });

  factory Program.fromJson(Map<String, dynamic> json) {
    return Program(
      id: json['id'].toString(),
      name: json['name'].toString(),
      templateType: json['template_type'].toString(),
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      targetCycles: json.containsKey('target_cycles') && json['target_cycles'] != null
          ? (json['target_cycles'] is int
              ? json['target_cycles']
              : int.tryParse(json['target_cycles'].toString()))
          : null,
      includeDeload: json.containsKey('include_deload') && json['include_deload'] != null
          ? (json['include_deload'] is bool
              ? json['include_deload']
              : json['include_deload'] == 1 || json['include_deload'] == '1' || json['include_deload'] == true)
          : true,
      trainingDays: List<String>.from(json['training_days']),
      status: json['status'].toString(),
      currentCycle: json.containsKey('current_cycle') && json['current_cycle'] != null
          ? (json['current_cycle'] is int
              ? json['current_cycle']
              : int.tryParse(json['current_cycle'].toString()))
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'template_type': templateType,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'target_cycles': targetCycles,
      'include_deload': includeDeload,
      'training_days': trainingDays,
      'status': status.toUpperCase(),
      'current_cycle': currentCycle,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get displayStatus {
    switch (status) {
      case 'ACTIVE':
        return 'Active';
      case 'COMPLETED':
        return 'Completed';
      case 'PAUSED':
        return 'Paused';
      default:
        return status;
    }
  }

  String get displayTemplateType {
    switch (templateType) {
      case '4_day':
        return '4-Day Program';
      case '3_day':
        return '3-Day Program';
      case '2_day':
        return '2-Day Program';
      default:
        return templateType;
    }
  }

  String get trainingDaysDisplay {
    return trainingDays.map((day) => day.substring(0, 3).toUpperCase()).join(', ');
  }
}

class CreateProgramRequest {
  final String name;
  final String templateType;
  final DateTime startDate;
  final DateTime? endDate;
  final int? targetCycles;
  final bool includeDeload;
  final List<String> trainingDays;
  final Map<String, double> trainingMaxes;
  final Map<String, List<AccessoryExercise>>? accessories;

  CreateProgramRequest({
    required this.name,
    required this.templateType,
    required this.startDate,
    this.endDate,
    this.targetCycles,
    this.includeDeload = true,
    required this.trainingDays,
    required this.trainingMaxes,
    this.accessories,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'template_type': templateType,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'target_cycles': targetCycles,
      'include_deload': includeDeload,
      'training_days': trainingDays,
      'training_maxes': trainingMaxes,
      'accessories': accessories?.map(
        (key, value) => MapEntry(
          key,
          value.map((e) => e.toJson()).toList(),
        ),
      ),
    };
  }
}

class AccessoryExercise {
  final String exerciseId;
  final int sets;
  final int reps;
  final int? circuitGroup; // null = standalone, 1+ = circuit group number

  AccessoryExercise({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    this.circuitGroup,
  });

  Map<String, dynamic> toJson() {
    return {
      'exercise_id': exerciseId,
      'sets': sets,
      'reps': reps,
      if (circuitGroup != null) 'circuit_group': circuitGroup,
    };
  }
}

class TrainingMax {
  final double value;
  final DateTime effectiveDate;
  final int cycle;

  TrainingMax({
    required this.value,
    required this.effectiveDate,
    required this.cycle,
  });

  factory TrainingMax.fromJson(Map<String, dynamic> json) {
    return TrainingMax(
      value: (json['value'] as num).toDouble(),
      effectiveDate: DateTime.parse(json['effective_date']),
      cycle: json['cycle'] as int,
    );
  }
}

class ProgramDetail {
  final String id;
  final String name;
  final String templateType;
  final DateTime startDate;
  final DateTime? endDate;
  final int? targetCycles;
  final bool includeDeload;
  final String status;
  final List<String> trainingDays;
  final int currentCycle;
  final int currentWeek;
  final Map<String, TrainingMax> trainingMaxes;
  final int workoutsGenerated;
  final DateTime createdAt;

  ProgramDetail({
    required this.id,
    required this.name,
    required this.templateType,
    required this.startDate,
    this.endDate,
    this.targetCycles,
    this.includeDeload = true,
    required this.status,
    required this.trainingDays,
    required this.currentCycle,
    required this.currentWeek,
    required this.trainingMaxes,
    required this.workoutsGenerated,
    required this.createdAt,
  });

  factory ProgramDetail.fromJson(Map<String, dynamic> json) {
    final trainingMaxesJson = json['training_maxes'] as Map<String, dynamic>;
    final trainingMaxes = <String, TrainingMax>{};

    trainingMaxesJson.forEach((key, value) {
      trainingMaxes[key] = TrainingMax.fromJson(value);
    });

    return ProgramDetail(
      id: json['id'].toString(),
      name: json['name'].toString(),
      templateType: json['template_type'].toString(),
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      targetCycles: json['target_cycles'] != null
          ? (json['target_cycles'] is int
              ? json['target_cycles']
              : int.tryParse(json['target_cycles'].toString()))
          : null,
      includeDeload: json.containsKey('include_deload') && json['include_deload'] != null
          ? (json['include_deload'] is bool
              ? json['include_deload']
              : json['include_deload'] == 1 || json['include_deload'] == '1' || json['include_deload'] == true)
          : true,
      status: json['status'].toString(),
      trainingDays: List<String>.from(json['training_days']),
      currentCycle: json['current_cycle'] as int,
      currentWeek: json['current_week'] as int,
      trainingMaxes: trainingMaxes,
      workoutsGenerated: json['workouts_generated'] as int,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get displayStatus {
    switch (status) {
      case 'ACTIVE':
        return 'Active';
      case 'COMPLETED':
        return 'Completed';
      case 'PAUSED':
        return 'Paused';
      default:
        return status;
    }
  }

  String get displayTemplateType {
    switch (templateType) {
      case '4_day':
        return '4-Day Program';
      case '3_day':
        return '3-Day Program';
      case '2_day':
        return '2-Day Program';
      default:
        return templateType;
    }
  }

  String get trainingDaysDisplay {
    return trainingDays.map((day) => day.substring(0, 3).toUpperCase()).join(', ');
  }

  String getDisplayLiftName(String lift) {
    switch (lift) {
      case 'press':
        return 'Overhead Press';
      case 'deadlift':
        return 'Deadlift';
      case 'bench_press':
        return 'Bench Press';
      case 'squat':
        return 'Squat';
      default:
        return lift;
    }
  }
}
