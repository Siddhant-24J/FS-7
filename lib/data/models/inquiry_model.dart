class InquiryModel {
  final String id;
  final String name;
  final String phone;
  final String sourceId;
  final String? referenceName;
  final String? referredByClientId;
  final DateTime inquiryDate;
  final DateTime lastFollowupDate;
  final DateTime nextFollowupDate;
  final String? nextFollowupTime;
  final String? interestedIn;
  final String? preferredTime;
  final String? preferredPattern;
  final String status; // new, follow_up, converted, not_interested, lost
  final String? lostReason;
  final String? convertedClientId;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  const InquiryModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.sourceId,
    this.referenceName,
    this.referredByClientId,
    required this.inquiryDate,
    required this.lastFollowupDate,
    required this.nextFollowupDate,
    this.nextFollowupTime,
    this.interestedIn,
    this.preferredTime,
    this.preferredPattern,
    required this.status,
    this.lostReason,
    this.convertedClientId,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  bool get isOpen => status != 'converted' && status != 'not_interested' && status != 'lost';
  bool get isConverted => status == 'converted';
  bool get isNotInterested => status == 'not_interested';
  bool get isLost => status == 'lost';
  bool get isFollowUp => status == 'follow_up';
  bool get isNew => status == 'new';
  bool get isOverdue => isOpen && nextFollowupDate.isBefore(DateTime.now());
  bool get isDueToday {
    final now = DateTime.now();
    return nextFollowupDate.year == now.year &&
        nextFollowupDate.month == now.month &&
        nextFollowupDate.day == now.day;
  }

  InquiryModel copyWith({
    String? name,
    String? phone,
    String? sourceId,
    String? referenceName,
    String? referredByClientId,
    DateTime? inquiryDate,
    DateTime? lastFollowupDate,
    DateTime? nextFollowupDate,
    String? nextFollowupTime,
    String? interestedIn,
    String? preferredTime,
    String? preferredPattern,
    String? status,
    String? lostReason,
    String? convertedClientId,
    bool? archived,
    DateTime? updatedAt,
  }) {
    return InquiryModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      sourceId: sourceId ?? this.sourceId,
      referenceName: referenceName ?? this.referenceName,
      referredByClientId: referredByClientId ?? this.referredByClientId,
      inquiryDate: inquiryDate ?? this.inquiryDate,
      lastFollowupDate: lastFollowupDate ?? this.lastFollowupDate,
      nextFollowupDate: nextFollowupDate ?? this.nextFollowupDate,
      nextFollowupTime: nextFollowupTime ?? this.nextFollowupTime,
      interestedIn: interestedIn ?? this.interestedIn,
      preferredTime: preferredTime ?? this.preferredTime,
      preferredPattern: preferredPattern ?? this.preferredPattern,
      status: status ?? this.status,
      lostReason: lostReason ?? this.lostReason,
      convertedClientId: convertedClientId ?? this.convertedClientId,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
    );
  }

  factory InquiryModel.fromJson(Map<String, dynamic> json) {
    return InquiryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      sourceId: json['source_id'] as String,
      referenceName: json['reference_name'] as String?,
      referredByClientId: json['referred_by_client_id'] as String?,
      inquiryDate: DateTime.parse(json['inquiry_date'] as String),
      lastFollowupDate: DateTime.parse(json['last_followup_date'] as String),
      nextFollowupDate: DateTime.parse(json['next_followup_date'] as String),
      nextFollowupTime: json['next_followup_time'] as String?,
      interestedIn: json['interested_in'] as String?,
      preferredTime: json['preferred_time'] as String?,
      preferredPattern: json['preferred_pattern'] as String?,
      status: json['status'] as String,
      lostReason: json['lost_reason'] as String?,
      convertedClientId: json['converted_client_id'] as String?,
      archived: json['archived'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'source_id': sourceId,
    'reference_name': referenceName,
    'referred_by_client_id': referredByClientId,
    'inquiry_date': inquiryDate.toIso8601String().split('T')[0],
    'last_followup_date': lastFollowupDate.toIso8601String().split('T')[0],
    'next_followup_date': nextFollowupDate.toIso8601String().split('T')[0],
    'next_followup_time': nextFollowupTime,
    'interested_in': interestedIn,
    'preferred_time': preferredTime,
    'preferred_pattern': preferredPattern,
    'status': status,
    'lost_reason': lostReason,
    'converted_client_id': convertedClientId,
    'archived': archived,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'created_by': createdBy,
  };
}

class InquiryFollowupModel {
  final String id;
  final String inquiryId;
  final DateTime followupAt;
  final String outcome;
  final String? remarks;
  final DateTime? nextFollowupDate;
  final String? nextFollowupTime;
  final String loggedBy;
  final DateTime createdAt;

  const InquiryFollowupModel({
    required this.id,
    required this.inquiryId,
    required this.followupAt,
    required this.outcome,
    this.remarks,
    this.nextFollowupDate,
    this.nextFollowupTime,
    required this.loggedBy,
    required this.createdAt,
  });

  factory InquiryFollowupModel.fromJson(Map<String, dynamic> json) {
    return InquiryFollowupModel(
      id: json['id'] as String,
      inquiryId: json['inquiry_id'] as String,
      followupAt: DateTime.parse(json['followup_at'] as String),
      outcome: json['outcome'] as String,
      remarks: json['remarks'] as String?,
      nextFollowupDate: json['next_followup_date'] != null
          ? DateTime.parse(json['next_followup_date'] as String)
          : null,
      nextFollowupTime: json['next_followup_time'] as String?,
      loggedBy: json['logged_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inquiry_id': inquiryId,
    'followup_at': followupAt.toIso8601String(),
    'outcome': outcome,
    'remarks': remarks,
    'next_followup_date': nextFollowupDate?.toIso8601String().split('T')[0],
    'next_followup_time': nextFollowupTime,
    'logged_by': loggedBy,
    'created_at': createdAt.toIso8601String(),
  };
}

class InquirySourceModel {
  final String id;
  final String name;
  final bool active;

  const InquirySourceModel({
    required this.id,
    required this.name,
    required this.active,
  });

  factory InquirySourceModel.fromJson(Map<String, dynamic> json) {
    return InquirySourceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'active': active,
  };
}

