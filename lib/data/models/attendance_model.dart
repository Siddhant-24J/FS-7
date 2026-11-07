class AttendanceModel {
  final String id;
  final String subscriptionId;
  final String clientId;
  final DateTime date;
  final String status; // present, absent, makeup, cancelled
  final String markedBy;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AttendanceModel({
    required this.id,
    required this.subscriptionId,
    required this.clientId,
    required this.date,
    required this.status,
    required this.markedBy,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPresent => status == 'present';
  bool get isAbsent => status == 'absent';
  bool get isMakeup => status == 'makeup';
  bool get isCancelled => status == 'cancelled';
  bool get countsAsSession => isPresent || isMakeup;

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as String,
      subscriptionId: json['subscription_id'] as String,
      clientId: json['client_id'] as String,
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      markedBy: json['marked_by'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subscription_id': subscriptionId,
    'client_id': clientId,
    'date': date.toIso8601String().split('T')[0],
    'status': status,
    'marked_by': markedBy,
    'note': note,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

