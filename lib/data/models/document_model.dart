class DocumentModel {
  final String id;
  final String clientId;
  final String? assessmentId;
  final String kind; // bca, blood, consent, diet, photo, other
  final String fileUrl;
  final DateTime? docDate;
  final String? notes;
  final String uploadedBy;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DocumentModel({
    required this.id,
    required this.clientId,
    this.assessmentId,
    required this.kind,
    required this.fileUrl,
    this.docDate,
    this.notes,
    required this.uploadedBy,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      assessmentId: json['assessment_id'] as String?,
      kind: json['kind'] as String,
      fileUrl: json['file_url'] as String,
      docDate: json['doc_date'] != null
          ? DateTime.parse(json['doc_date'] as String)
          : null,
      notes: json['notes'] as String?,
      uploadedBy: json['uploaded_by'] as String,
      archived: json['archived'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientId,
    'assessment_id': assessmentId,
    'kind': kind,
    'file_url': fileUrl,
    'doc_date': docDate?.toIso8601String().split('T')[0],
    'notes': notes,
    'uploaded_by': uploadedBy,
    'archived': archived,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  String get kindLabel {
    switch (kind) {
      case 'bca': return 'BCA Report';
      case 'blood': return 'Blood Report';
      case 'consent': return 'Consent Form';
      case 'diet': return 'Diet Plan';
      case 'photo': return 'Progress Photo';
      default: return 'Document';
    }
  }
}

class NoteModel {
  final String id;
  final String clientId;
  final String authorId;
  final String kind; // training, nutrition
  final String visibility; // shared, author_only
  final String body;
  final int version;
  final String? previousVersionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteModel({
    required this.id,
    required this.clientId,
    required this.authorId,
    required this.kind,
    required this.visibility,
    required this.body,
    required this.version,
    this.previousVersionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      authorId: json['author_id'] as String,
      kind: json['kind'] as String,
      visibility: json['visibility'] as String,
      body: json['body'] as String,
      version: json['version'] as int? ?? 1,
      previousVersionId: json['previous_version_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientId,
    'author_id': authorId,
    'kind': kind,
    'visibility': visibility,
    'body': body,
    'version': version,
    'previous_version_id': previousVersionId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class NutritionCheckinModel {
  final String id;
  final String clientId;
  final String nutritionistId;
  final DateTime date;
  final double? weightKg;
  final String? compliance; // Poor, Fair, Good
  final String? notes;
  final DateTime createdAt;

  const NutritionCheckinModel({
    required this.id,
    required this.clientId,
    required this.nutritionistId,
    required this.date,
    this.weightKg,
    this.compliance,
    this.notes,
    required this.createdAt,
  });

  factory NutritionCheckinModel.fromJson(Map<String, dynamic> json) {
    return NutritionCheckinModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      nutritionistId: json['nutritionist_id'] as String,
      date: DateTime.parse(json['date'] as String),
      weightKg: (json['weight'] as num?)?.toDouble(),
      compliance: json['compliance'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientId,
    'nutritionist_id': nutritionistId,
    'date': date.toIso8601String().split('T')[0],
    'weight': weightKg,
    'compliance': compliance,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };
}

class AuditLogModel {
  final String id;
  final String actorId;
  final String tableName;
  final String recordId;
  final String field;
  final String? oldValue;
  final String? newValue;
  final DateTime at;

  const AuditLogModel({
    required this.id,
    required this.actorId,
    required this.tableName,
    required this.recordId,
    required this.field,
    this.oldValue,
    this.newValue,
    required this.at,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] as String,
      actorId: json['actor_id'] as String,
      tableName: json['table'] as String,
      recordId: json['record_id'] as String,
      field: json['field'] as String,
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
      at: DateTime.parse(json['at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'actor_id': actorId,
    'table': tableName,
    'record_id': recordId,
    'field': field,
    'old_value': oldValue,
    'new_value': newValue,
    'at': at.toIso8601String(),
  };
}

class ConsentModel {
  final String id;
  final String clientId;
  final String? memberSignatureUrl;
  final String? trainerSignatureUrl;
  final String consentText;
  final DateTime signedAt;
  final DateTime createdAt;

  const ConsentModel({
    required this.id,
    required this.clientId,
    this.memberSignatureUrl,
    this.trainerSignatureUrl,
    required this.consentText,
    required this.signedAt,
    required this.createdAt,
  });

  factory ConsentModel.fromJson(Map<String, dynamic> json) {
    return ConsentModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      memberSignatureUrl: json['member_signature_url'] as String?,
      trainerSignatureUrl: json['trainer_signature_url'] as String?,
      consentText: json['consent_text'] as String? ?? '',
      signedAt: DateTime.parse(json['signed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientId,
    'member_signature_url': memberSignatureUrl,
    'trainer_signature_url': trainerSignatureUrl,
    'consent_text': consentText,
    'signed_at': signedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

class SessionOverrideModel {
  final String id;
  final String clientId;
  final DateTime date;
  final String trainerId;
  final int hourStart;
  final String createdBy;
  final DateTime createdAt;

  const SessionOverrideModel({
    required this.id,
    required this.clientId,
    required this.date,
    required this.trainerId,
    required this.hourStart,
    required this.createdBy,
    required this.createdAt,
  });

  factory SessionOverrideModel.fromJson(Map<String, dynamic> json) {
    return SessionOverrideModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      date: DateTime.parse(json['date'] as String),
      trainerId: json['trainer_id'] as String,
      hourStart: json['hour_start'] as int,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientId,
    'date': date.toIso8601String().split('T')[0],
    'trainer_id': trainerId,
    'hour_start': hourStart,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
  };
}

class TrainerHandoverModel {
  final String id;
  final String clientId;
  final String fromTrainerId;
  final String toTrainerId;
  final String note;
  final DateTime at;

  const TrainerHandoverModel({
    required this.id,
    required this.clientId,
    required this.fromTrainerId,
    required this.toTrainerId,
    required this.note,
    required this.at,
  });

  factory TrainerHandoverModel.fromJson(Map<String, dynamic> json) {
    return TrainerHandoverModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      fromTrainerId: json['from_trainer_id'] as String,
      toTrainerId: json['to_trainer_id'] as String,
      note: json['note'] as String,
      at: DateTime.parse(json['at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientId,
    'from_trainer_id': fromTrainerId,
    'to_trainer_id': toTrainerId,
    'note': note,
    'at': at.toIso8601String(),
  };
}

class AppNotificationModel {
  final String id;
  final String userId;
  final String type; // e.g. client_assigned, plan_completed, final_due, absent_alert, etc.
  final String title;
  final String body;
  final Map<String, dynamic>? payload;
  final DateTime scheduledFor;
  final DateTime? sentAt;
  final DateTime? readAt;
  final bool cancelled;
  final DateTime createdAt;

  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.payload,
    required this.scheduledFor,
    this.sentAt,
    this.readAt,
    this.cancelled = false,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  AppNotificationModel copyWith({DateTime? readAt, bool? cancelled}) {
    return AppNotificationModel(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      payload: payload,
      scheduledFor: scheduledFor,
      sentAt: sentAt,
      readAt: readAt ?? this.readAt,
      cancelled: cancelled ?? this.cancelled,
      createdAt: createdAt,
    );
  }

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      payload: json['payload'] as Map<String, dynamic>?,
      scheduledFor: DateTime.parse(json['scheduled_for'] as String),
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at'] as String) : null,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      cancelled: json['cancelled'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'type': type,
    'title': title,
    'body': body,
    'payload': payload,
    'scheduled_for': scheduledFor.toIso8601String(),
    'sent_at': sentAt?.toIso8601String(),
    'read_at': readAt?.toIso8601String(),
    'cancelled': cancelled,
    'created_at': createdAt.toIso8601String(),
  };
}

