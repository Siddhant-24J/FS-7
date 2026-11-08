class AssessmentModel {
  final String id;
  final String clientId;
  final String subscriptionId;
  final String type; // baseline, final, checkpoint
  final DateTime testDate;

  // Basics (stored)
  final double? weightKg;
  final double? heightCm;
  final String? goal;

  // Blood pressure
  final int? restingHeartRate;
  final int? systolic;
  final int? diastolic;

  // Body measurements (all in cm)
  final double? neck;
  final double? chest;
  final double? upperAbdomen;
  final double? waistWidest;
  final double? waistNarrowest;
  final double? hip;
  final double? armLeft;
  final double? armRight;
  final double? thighLeft;
  final double? thighRight;
  final double? calfLeft;
  final double? calfRight;

  // Cardio (Rockport)
  final String? rockportTime; // "MM:SS"
  final int? rockportPulse;

  // Recovery (YMCA step)
  final int? recoveryHeartRate;

  // Muscular endurance
  final int? pushupsCount;
  final int? squatsCount;
  final int? pullupsCount;
  final int? pullupsTimeSeconds;

  // Flexibility
  final String? quadricepsFlexibility;
  final String? hamstringsFlexibility;
  final String? hipFlexorsFlexibility;
  final String? shoulderReachFlexibility;

  // Remarks and score
  final String? trainerRemarks;
  final double? fs7Score;

  // Calculated snapshot stored as JSON
  final Map<String, dynamic>? calculatedJson;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  const AssessmentModel({
    required this.id,
    required this.clientId,
    required this.subscriptionId,
    required this.type,
    required this.testDate,
    this.weightKg,
    this.heightCm,
    this.goal,
    this.restingHeartRate,
    this.systolic,
    this.diastolic,
    this.neck,
    this.chest,
    this.upperAbdomen,
    this.waistWidest,
    this.waistNarrowest,
    this.hip,
    this.armLeft,
    this.armRight,
    this.thighLeft,
    this.thighRight,
    this.calfLeft,
    this.calfRight,
    this.rockportTime,
    this.rockportPulse,
    this.recoveryHeartRate,
    this.pushupsCount,
    this.squatsCount,
    this.pullupsCount,
    this.pullupsTimeSeconds,
    this.quadricepsFlexibility,
    this.hamstringsFlexibility,
    this.hipFlexorsFlexibility,
    this.shoulderReachFlexibility,
    this.trainerRemarks,
    this.fs7Score,
    this.calculatedJson,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  bool get isBaseline => type == 'baseline';
  bool get isFinal => type == 'final';
  bool get isCheckpoint => type == 'checkpoint';

  factory AssessmentModel.fromJson(Map<String, dynamic> json) {
    return AssessmentModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      subscriptionId: json['subscription_id'] as String,
      type: json['type'] as String,
      testDate: DateTime.parse(json['test_date'] as String),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      goal: json['goal'] as String?,
      restingHeartRate: json['resting_heart_rate'] as int?,
      systolic: json['systolic'] as int?,
      diastolic: json['diastolic'] as int?,
      neck: (json['neck'] as num?)?.toDouble(),
      chest: (json['chest'] as num?)?.toDouble(),
      upperAbdomen: (json['upper_abdomen'] as num?)?.toDouble(),
      waistWidest: (json['waist_widest'] as num?)?.toDouble(),
      waistNarrowest: (json['waist_narrowest'] as num?)?.toDouble(),
      hip: (json['hip'] as num?)?.toDouble(),
      armLeft: (json['arm_left'] as num?)?.toDouble(),
      armRight: (json['arm_right'] as num?)?.toDouble(),
      thighLeft: (json['thigh_left'] as num?)?.toDouble(),
      thighRight: (json['thigh_right'] as num?)?.toDouble(),
      calfLeft: (json['calf_left'] as num?)?.toDouble(),
      calfRight: (json['calf_right'] as num?)?.toDouble(),
      rockportTime: json['rockport_time'] as String?,
      rockportPulse: json['rockport_pulse'] as int?,
      recoveryHeartRate: json['recovery_heart_rate'] as int?,
      pushupsCount: json['pushups_count'] as int?,
      squatsCount: json['squats_count'] as int?,
      pullupsCount: json['pullups_count'] as int?,
      pullupsTimeSeconds: json['pullups_time_seconds'] as int?,
      quadricepsFlexibility: json['quadriceps_flexibility'] as String?,
      hamstringsFlexibility: json['hamstrings_flexibility'] as String?,
      hipFlexorsFlexibility: json['hip_flexors_flexibility'] as String?,
      shoulderReachFlexibility: json['shoulder_reach_flexibility'] as String?,
      trainerRemarks: json['trainer_remarks'] as String?,
      fs7Score: (json['fs7_score'] as num?)?.toDouble(),
      calculatedJson: json['calculated_json'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientId,
    'subscription_id': subscriptionId,
    'type': type,
    'test_date': testDate.toIso8601String().split('T')[0],
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'goal': goal,
    'resting_heart_rate': restingHeartRate,
    'systolic': systolic,
    'diastolic': diastolic,
    'neck': neck,
    'chest': chest,
    'upper_abdomen': upperAbdomen,
    'waist_widest': waistWidest,
    'waist_narrowest': waistNarrowest,
    'hip': hip,
    'arm_left': armLeft,
    'arm_right': armRight,
    'thigh_left': thighLeft,
    'thigh_right': thighRight,
    'calf_left': calfLeft,
    'calf_right': calfRight,
    'rockport_time': rockportTime,
    'rockport_pulse': rockportPulse,
    'recovery_heart_rate': recoveryHeartRate,
    'pushups_count': pushupsCount,
    'squats_count': squatsCount,
    'pullups_count': pullupsCount,
    'pullups_time_seconds': pullupsTimeSeconds,
    'quadriceps_flexibility': quadricepsFlexibility,
    'hamstrings_flexibility': hamstringsFlexibility,
    'hip_flexors_flexibility': hipFlexorsFlexibility,
    'shoulder_reach_flexibility': shoulderReachFlexibility,
    'trainer_remarks': trainerRemarks,
    'fs7_score': fs7Score,
    'calculated_json': calculatedJson,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'created_by': createdBy,
  };

  List<String> get flexibilityRatings {
    final ratings = <String>[];
    if (quadricepsFlexibility != null) ratings.add(quadricepsFlexibility!);
    if (hamstringsFlexibility != null) ratings.add(hamstringsFlexibility!);
    if (hipFlexorsFlexibility != null) ratings.add(hipFlexorsFlexibility!);
    if (shoulderReachFlexibility != null) ratings.add(shoulderReachFlexibility!);
    return ratings;
  }

  String get typeLabel {
    switch (type) {
      case 'baseline': return 'Baseline';
      case 'final': return 'Final';
      case 'checkpoint': return 'Checkpoint';
      default: return type;
    }
  }
}

