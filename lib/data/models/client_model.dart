class ClientModel {
  final String id;
  final String firstName;
  final String lastName;
  final String? address;
  final DateTime dob;
  final String gender; // Male, Female
  final String phonePrimary;
  final String? phoneSecondary;
  final String? email;
  final String? photoUrl;
  final String programType;
  final String paymentMethod;
  final String trainerId;
  final String? nutritionistId;
  final String status; // active, extended, completed, deactivated, hold
  final String? sourceInquiryId;
  // Emergency contact
  final String emergencyFirstName;
  final String emergencyLastName;
  final String? emergencyAddress;
  final String emergencyPhone;
  final int consecutiveAbsences;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  const ClientModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.address,
    required this.dob,
    required this.gender,
    required this.phonePrimary,
    this.phoneSecondary,
    this.email,
    this.photoUrl,
    required this.programType,
    required this.paymentMethod,
    required this.trainerId,
    this.nutritionistId,
    required this.status,
    this.sourceInquiryId,
    required this.emergencyFirstName,
    required this.emergencyLastName,
    this.emergencyAddress,
    required this.emergencyPhone,
    this.consecutiveAbsences = 0,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  String get fullName => '$firstName $lastName';

  bool get isActive => status == 'active';
  bool get isExtended => status == 'extended';
  bool get isCompleted => status == 'completed';
  bool get isDeactivated => status == 'deactivated';
  bool get isHold => status == 'hold';

  String get initials {
    final f = firstName.trim().isNotEmpty ? firstName.trim()[0].toUpperCase() : 'C';
    final l = lastName.trim().isNotEmpty ? lastName.trim()[0].toUpperCase() : '';
    return '$f$l';
  }

  int get age {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      address: json['address'] as String?,
      dob: json['dob'] != null
          ? (DateTime.tryParse(json['dob'].toString()) ?? DateTime(1995, 1, 1))
          : DateTime(1995, 1, 1),
      gender: json['gender'] as String? ?? 'Male',
      phonePrimary: json['phone_primary'] as String? ?? '',
      phoneSecondary: json['phone_secondary'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photo_url'] as String?,
      programType: json['program_type'] as String? ?? 'Personal Training',
      paymentMethod: json['payment_method'] as String? ?? 'Online',
      trainerId: json['trainer_id'] as String? ?? '',
      nutritionistId: json['nutritionist_id'] as String?,
      status: json['status'] as String? ?? 'active',
      sourceInquiryId: json['source_inquiry_id'] as String?,
      emergencyFirstName: json['emergency_first_name'] as String? ?? 'Emergency',
      emergencyLastName: json['emergency_last_name'] as String? ?? 'Contact',
      emergencyAddress: json['emergency_address'] as String?,
      emergencyPhone: json['emergency_phone'] as String? ?? '',
      consecutiveAbsences: json['consecutive_absences'] as int? ?? 0,
      archived: json['archived'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      createdBy: json['created_by'] as String? ?? 'admin-01',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'address': address,
    'dob': dob.toIso8601String().split('T')[0],
    'gender': gender,
    'phone_primary': phonePrimary,
    'phone_secondary': phoneSecondary,
    'email': email,
    'photo_url': photoUrl,
    'program_type': programType,
    'payment_method': paymentMethod,
    'trainer_id': trainerId,
    'nutritionist_id': nutritionistId,
    'status': status,
    'source_inquiry_id': sourceInquiryId,
    'emergency_first_name': emergencyFirstName,
    'emergency_last_name': emergencyLastName,
    'emergency_address': emergencyAddress,
    'emergency_phone': emergencyPhone,
    'consecutive_absences': consecutiveAbsences,
    'archived': archived,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'created_by': createdBy,
  };

  ClientModel copyWith({
    String? firstName, String? lastName, String? address,
    DateTime? dob, String? gender, String? phonePrimary,
    String? phoneSecondary, String? email, String? photoUrl,
    String? programType, String? paymentMethod, String? trainerId,
    String? nutritionistId, String? status, bool? archived,
  }) {
    return ClientModel(
      id: id, dob: dob ?? this.dob, createdAt: createdAt,
      updatedAt: DateTime.now(), createdBy: createdBy,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      phonePrimary: phonePrimary ?? this.phonePrimary,
      phoneSecondary: phoneSecondary ?? this.phoneSecondary,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      programType: programType ?? this.programType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      trainerId: trainerId ?? this.trainerId,
      nutritionistId: nutritionistId ?? this.nutritionistId,
      status: status ?? this.status,
      sourceInquiryId: sourceInquiryId,
      emergencyFirstName: emergencyFirstName,
      emergencyLastName: emergencyLastName,
      emergencyAddress: emergencyAddress,
      emergencyPhone: emergencyPhone,
      archived: archived ?? this.archived,
    );
  }
}

