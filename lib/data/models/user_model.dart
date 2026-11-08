class UserModel {
  final String id;
  final String role; // admin, trainer, nutritionist, staff
  final String name;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final String userId; // login username
  final bool active;
  final String? shiftStart; // e.g. "06:00"
  final String? shiftEnd;   // e.g. "10:00"
  final int? weeklyOffDay; // 1=Mon...7=Sun, null = no fixed off
  final int graceMinutes;
  final bool mustChangePassword;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.role,
    required this.name,
    this.phone,
    this.email,
    this.photoUrl,
    required this.userId,
    required this.active,
    this.shiftStart,
    this.shiftEnd,
    this.weeklyOffDay,
    this.graceMinutes = 10,
    this.mustChangePassword = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isTrainer => role == 'trainer';
  bool get isNutritionist => role == 'nutritionist';
  bool get isStaff => role == 'staff';
  int? get weeklyOff => weeklyOffDay;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      role: json['role'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photo_url'] as String?,
      userId: json['user_id'] as String,
      active: json['active'] as bool? ?? true,
      shiftStart: json['shift_start'] as String?,
      shiftEnd: json['shift_end'] as String?,
      weeklyOffDay: json['weekly_off'] as int?,
      graceMinutes: json['grace_minutes'] as int? ?? 10,
      mustChangePassword: json['must_change_password'] as bool? ?? true,
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
    'role': role,
    'name': name,
    'phone': phone,
    'email': email,
    'photo_url': photoUrl,
    'user_id': userId,
    'active': active,
    'shift_start': shiftStart,
    'shift_end': shiftEnd,
    'weekly_off': weeklyOffDay,
    'grace_minutes': graceMinutes,
    'must_change_password': mustChangePassword,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  UserModel copyWith({
    String? role, String? name, String? phone, String? email,
    String? photoUrl, bool? active, String? shiftStart, String? shiftEnd,
    int? weeklyOffDay, int? graceMinutes, bool? mustChangePassword,
  }) {
    return UserModel(
      id: id, userId: userId, createdAt: createdAt,
      updatedAt: DateTime.now(),
      role: role ?? this.role,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      active: active ?? this.active,
      shiftStart: shiftStart ?? this.shiftStart,
      shiftEnd: shiftEnd ?? this.shiftEnd,
      weeklyOffDay: weeklyOffDay ?? this.weeklyOffDay,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }
}

