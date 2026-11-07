import '../../data/models/user_model.dart';
import '../../data/models/client_model.dart';
import '../../data/models/plan_model.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/assessment_model.dart';
import '../../data/models/inquiry_model.dart';
import '../../data/models/staff_attendance_model.dart';
import '../../data/models/document_model.dart';

class MockData {
  MockData._();

  static final DateTime _now = DateTime.now();

  // ─── Staff / Users (Only Admin) ───────────────────────────────────────────
  static final List<UserModel> trainers = [];
  static final Map<String, String> staffPasswords = {
    'fs7admin': 'ceo@fs7',
  };

  static final List<UserModel> allStaff = [
    UserModel(
      id: 'admin-01',
      userId: 'fs7admin',
      name: 'Director (Admin)',
      phone: '+91 99999 00001',
      role: 'admin',
      active: true,
      createdAt: _now,
      updatedAt: _now,
    ),
  ];

  // ─── Clients (Empty for Fresh Entry) ──────────────────────────────────────
  static final List<ClientModel> clients = [];

  // ─── Subscriptions (Empty) ────────────────────────────────────────────────
  static final List<SubscriptionModel> subscriptions = [];

  // ─── Timetable Slots (Empty) ──────────────────────────────────────────────
  static final List<SlotModel> slots = [];

  // ─── Attendance (Empty) ───────────────────────────────────────────────────
  static final List<AttendanceModel> attendance = [];

  // ─── Assessments (Empty) ──────────────────────────────────────────────────
  static final List<AssessmentModel> assessments = [];

  // ─── Inquiries (Empty) ────────────────────────────────────────────────────
  static final List<InquiryModel> inquiries = [];
  static final List<InquiryFollowupModel> inquiryFollowups = [];

  // ─── Staff Attendance (Empty) ─────────────────────────────────────────────
  static final List<StaffAttendanceModel> staffAttendance = [];

  // ─── Workflows A to L Tables ──────────────────────────────────────────────
  static final List<ConsentModel> consents = [];
  static final List<SessionOverrideModel> sessionOverrides = [];
  static final List<TrainerHandoverModel> trainerHandovers = [];
  static final List<AppNotificationModel> notifications = [];
  static final List<NoteModel> notes = [];
  static final List<AuditLogModel> auditLogs = [];
}
