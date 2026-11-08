class StaffAttendanceModel {
  final String id;
  final String userId;
  final DateTime date;
  final String status; // present, absent, half_day, leave, week_off, holiday
  final String? inTime;
  final String? outTime;
  final bool lateFlag;
  final String? note;
  final String markedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StaffAttendanceModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.status,
    this.inTime,
    this.outTime,
    this.lateFlag = false,
    this.note,
    required this.markedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPresent => status == 'present';
  bool get isAbsent => status == 'absent';
  bool get isHalfDay => status == 'half_day';
  bool get isLeave => status == 'leave';
  bool get isWeekOff => status == 'week_off';
  bool get isHoliday => status == 'holiday';

  factory StaffAttendanceModel.fromJson(Map<String, dynamic> json) {
    return StaffAttendanceModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      date: json['date'] != null
          ? (DateTime.tryParse(json['date'].toString()) ?? DateTime.now())
          : DateTime.now(),
      status: json['status'] as String? ?? 'present',
      inTime: json['in_time'] as String?,
      outTime: json['out_time'] as String?,
      lateFlag: json['late_flag'] as bool? ?? false,
      note: json['note'] as String?,
      markedBy: json['marked_by'] as String? ?? 'admin-01',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'date': date.toIso8601String().split('T')[0],
    'status': status,
    'in_time': inTime,
    'out_time': outTime,
    'late_flag': lateFlag,
    'note': note,
    'marked_by': markedBy,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

