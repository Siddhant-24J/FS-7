class PlanModel {
  final String id;
  final String name;
  final int months;
  final int sessionsPerMonth;
  final bool active;
  final DateTime createdAt;

  const PlanModel({
    required this.id,
    required this.name,
    required this.months,
    required this.sessionsPerMonth,
    required this.active,
    required this.createdAt,
  });

  int get totalSessions => months * sessionsPerMonth;

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] as String,
      name: json['name'] as String,
      months: json['months'] as int,
      sessionsPerMonth: json['sessions_per_month'] as int,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'months': months,
    'sessions_per_month': sessionsPerMonth,
    'active': active,
    'created_at': createdAt.toIso8601String(),
  };

  static List<PlanModel> get defaultPlans => [
    PlanModel(
      id: 'plan_3m_12', name: '3 Months, 12 sessions',
      months: 3, sessionsPerMonth: 12, active: true,
      createdAt: DateTime.now(),
    ),
    PlanModel(
      id: 'plan_3m_20', name: '3 Months, 20 sessions',
      months: 3, sessionsPerMonth: 20, active: true,
      createdAt: DateTime.now(),
    ),
    PlanModel(
      id: 'plan_6m_12', name: '6 Months, 12 sessions',
      months: 6, sessionsPerMonth: 12, active: true,
      createdAt: DateTime.now(),
    ),
    PlanModel(
      id: 'plan_6m_20', name: '6 Months, 20 sessions',
      months: 6, sessionsPerMonth: 20, active: true,
      createdAt: DateTime.now(),
    ),
  ];
}

class SubscriptionModel {
  final String id;
  final String clientId;
  final String planId;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? extensionEndDate;
  final int totalSessions;
  final String status; // active, extended, completed, deactivated, hold
  final DateTime? holdFrom;
  final DateTime? holdTo;
  final String? deactivationReason;
  final String? renewedFromId;
  final DateTime? baselineDueDate;
  final bool finalAssessmentDue;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  const SubscriptionModel({
    required this.id,
    required this.clientId,
    required this.planId,
    required this.startDate,
    required this.endDate,
    this.extensionEndDate,
    required this.totalSessions,
    required this.status,
    this.holdFrom,
    this.holdTo,
    this.deactivationReason,
    this.renewedFromId,
    this.baselineDueDate,
    this.finalAssessmentDue = false,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  DateTime get effectiveEndDate => extensionEndDate ?? endDate;

  bool get isActive => status == 'active';
  bool get isExtended => status == 'extended';
  bool get isCompleted => status == 'completed';
  bool get isDeactivated => status == 'deactivated';
  bool get isOnHold => status == 'hold';
  bool get isHold => status == 'hold';

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      planId: json['plan_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      extensionEndDate: json['extension_end_date'] != null
          ? DateTime.parse(json['extension_end_date'] as String)
          : null,
      totalSessions: json['total_sessions'] as int,
      status: json['status'] as String,
      holdFrom: json['hold_from'] != null
          ? DateTime.parse(json['hold_from'] as String)
          : null,
      holdTo: json['hold_to'] != null
          ? DateTime.parse(json['hold_to'] as String)
          : null,
      deactivationReason: json['deactivation_reason'] as String?,
      renewedFromId: json['renewed_from_id'] as String?,
      baselineDueDate: json['baseline_due_date'] != null
          ? DateTime.parse(json['baseline_due_date'] as String)
          : null,
      finalAssessmentDue: json['final_assessment_due'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientId,
    'plan_id': planId,
    'start_date': startDate.toIso8601String().split('T')[0],
    'end_date': endDate.toIso8601String().split('T')[0],
    'extension_end_date': extensionEndDate?.toIso8601String().split('T')[0],
    'total_sessions': totalSessions,
    'status': status,
    'hold_from': holdFrom?.toIso8601String().split('T')[0],
    'hold_to': holdTo?.toIso8601String().split('T')[0],
    'deactivation_reason': deactivationReason,
    'renewed_from_id': renewedFromId,
    'baseline_due_date': baselineDueDate?.toIso8601String().split('T')[0],
    'final_assessment_due': finalAssessmentDue,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'created_by': createdBy,
  };
}

class SlotModel {
  final String id;
  final String subscriptionId;
  final String clientId;
  final String trainerId;
  final int hourStart; // 6 = 6 AM slot
  final String pattern; // A5, M1, M2, T1, T2
  final DateTime validFrom;
  final DateTime validTo;
  final DateTime createdAt;

  const SlotModel({
    required this.id,
    required this.subscriptionId,
    required this.clientId,
    required this.trainerId,
    required this.hourStart,
    required this.pattern,
    required this.validFrom,
    required this.validTo,
    required this.createdAt,
  });

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      id: json['id'] as String,
      subscriptionId: json['subscription_id'] as String,
      clientId: json['client_id'] as String,
      trainerId: json['trainer_id'] as String,
      hourStart: json['hour_start'] as int,
      pattern: json['pattern'] as String,
      validFrom: DateTime.parse(json['valid_from'] as String),
      validTo: DateTime.parse(json['valid_to'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subscription_id': subscriptionId,
    'client_id': clientId,
    'trainer_id': trainerId,
    'hour_start': hourStart,
    'pattern': pattern,
    'valid_from': validFrom.toIso8601String().split('T')[0],
    'valid_to': validTo.toIso8601String().split('T')[0],
    'created_at': createdAt.toIso8601String(),
  };

  String get hourLabel {
    final hour12 = hourStart > 12 ? hourStart - 12 : hourStart;
    final ampm = hourStart >= 12 ? 'PM' : 'AM';
    final end12 = (hourStart + 1) > 12 ? (hourStart + 1) - 12 : (hourStart + 1);
    final endAmpm = (hourStart + 1) >= 12 ? 'PM' : 'AM';
    return '$hour12 $ampm – $end12 $endAmpm';
  }
}

