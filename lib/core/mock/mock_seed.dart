import 'dart:math';
import '../constants/supabase_constants.dart';
import '../../data/models/user_model.dart';
import '../../data/models/client_model.dart';
import '../../data/models/plan_model.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/assessment_model.dart';
import '../../data/models/inquiry_model.dart';
import '../../data/models/staff_attendance_model.dart';
import '../../data/models/document_model.dart';
import 'mock_data.dart';

/// Deterministic Seed Data Generator for FS-7 QA & Testing
/// Implements Section 4.1 of FS7 Functional Fix & QA Specification.
/// Refuses to run if real Supabase backend is configured.
class MockSeed {
  MockSeed._();

  static bool _seeded = false;

  static void seed({bool force = false}) {
    if (SupabaseConstants.isConfigured) {
      // Rule 2 & 4.1: Must refuse to run in production
      return;
    }
    if (_seeded && !force) return;
    _seeded = true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ─── 1. Staff & Users ──────────────────────────────────────────────────
    final adminUser = UserModel(
      id: 'admin-01',
      userId: 'fs7admin',
      name: 'Director (Admin)',
      phone: '+91 99999 00001',
      role: 'admin',
      active: true,
      createdAt: now.subtract(const Duration(days: 180)),
      updatedAt: now,
    );

    final farazTrainer = UserModel(
      id: 'trainer-01',
      userId: 'trainer_faraz',
      name: 'Faraz Khan',
      phone: '+91 98201 11001',
      email: 'faraz@fs7.in',
      role: 'trainer',
      shiftStart: '06:00',
      shiftEnd: '14:00',
      weeklyOffDay: 7, // Sunday
      active: true,
      createdAt: now.subtract(const Duration(days: 180)),
      updatedAt: now,
    );

    final suyogTrainer = UserModel(
      id: 'trainer-02',
      userId: 'trainer_suyog',
      name: 'Suyog Shinde',
      phone: '+91 98201 11002',
      email: 'suyog@fs7.in',
      role: 'trainer',
      shiftStart: '07:00',
      shiftEnd: '15:00',
      weeklyOffDay: 7, // Sunday
      active: true,
      createdAt: now.subtract(const Duration(days: 180)),
      updatedAt: now,
    );

    final khalfanTrainer = UserModel(
      id: 'trainer-03',
      userId: 'trainer_khalfan',
      name: 'Khalfan Ansari',
      phone: '+91 98201 11003',
      email: 'khalfan@fs7.in',
      role: 'trainer',
      shiftStart: '14:00',
      shiftEnd: '22:00',
      weeklyOffDay: 7, // Sunday
      active: true,
      createdAt: now.subtract(const Duration(days: 180)),
      updatedAt: now,
    );

    final ananyaNutritionist = UserModel(
      id: 'nutri-01',
      userId: 'nutri_ananya',
      name: 'Ananya Deshmukh',
      phone: '+91 98201 22001',
      email: 'ananya@fs7.in',
      role: 'nutritionist',
      shiftStart: '09:00',
      shiftEnd: '17:00',
      weeklyOffDay: 7,
      active: true,
      createdAt: now.subtract(const Duration(days: 180)),
      updatedAt: now,
    );

    final rameshStaff = UserModel(
      id: 'staff-01',
      userId: 'staff_ramesh',
      name: 'Ramesh Patel',
      phone: '+91 98201 33001',
      email: 'ramesh@fs7.in',
      role: 'support',
      shiftStart: '06:00',
      shiftEnd: '14:00',
      weeklyOffDay: 7,
      active: true,
      createdAt: now.subtract(const Duration(days: 180)),
      updatedAt: now,
    );

    final priyaStaff = UserModel(
      id: 'staff-02',
      userId: 'staff_priya',
      name: 'Priya Verma',
      phone: '+91 98201 33002',
      email: 'priya@fs7.in',
      role: 'support',
      shiftStart: '14:00',
      shiftEnd: '22:00',
      weeklyOffDay: 7,
      active: true,
      createdAt: now.subtract(const Duration(days: 180)),
      updatedAt: now,
    );

    MockData.trainers.clear();
    MockData.trainers.addAll([farazTrainer, suyogTrainer, khalfanTrainer]);

    MockData.allStaff.clear();
    MockData.allStaff.addAll([
      adminUser,
      farazTrainer,
      suyogTrainer,
      khalfanTrainer,
      ananyaNutritionist,
      rameshStaff,
      priyaStaff,
    ]);

    // ─── 2. ~40 Seed Clients Across All Statuses ──────────────────────────
    MockData.clients.clear();
    MockData.subscriptions.clear();
    MockData.slots.clear();
    MockData.attendance.clear();
    MockData.assessments.clear();
    MockData.inquiries.clear();
    MockData.inquiryFollowups.clear();
    MockData.staffAttendance.clear();
    MockData.consents.clear();
    MockData.notifications.clear();
    MockData.auditLogs.clear();

    final trainers = [farazTrainer, suyogTrainer, khalfanTrainer];
    final plans = PlanModel.defaultPlans;

    // Specific Client Definitions matching § 4.1
    final clientConfigs = [
      // Active clients - Faraz
      _ClientSeedSpec(id: 'c-01', firstName: 'Rahul', lastName: 'Sharma', gender: 'male', age: 29, phone: '+91 98200 00001', trainerId: 'trainer-01', nutriId: 'nutri-01', planId: 'plan_3m_12', startDelta: -30, hour: 7, pattern: 'A5', status: 'active'),
      _ClientSeedSpec(id: 'c-02', firstName: 'Pooja', lastName: 'Mehta', gender: 'female', age: 26, phone: '+91 98200 00002', trainerId: 'trainer-01', nutriId: null, planId: 'plan_3m_20', startDelta: -45, hour: 8, pattern: 'M1', status: 'active'),
      _ClientSeedSpec(id: 'c-03', firstName: 'Amit', lastName: 'Verma', gender: 'male', age: 34, phone: '+91 98200 00003', trainerId: 'trainer-01', nutriId: 'nutri-01', planId: 'plan_3m_20', startDelta: -10, hour: 8, pattern: 'M2', status: 'active'),
      _ClientSeedSpec(id: 'c-04', firstName: 'Sneha', lastName: 'Kapoor', gender: 'female', age: 31, phone: '+91 98200 00004', trainerId: 'trainer-01', nutriId: null, planId: 'plan_6m_12', startDelta: -60, hour: 9, pattern: 'T1', status: 'active'),
      _ClientSeedSpec(id: 'c-05', firstName: 'Karan', lastName: 'Malhotra', gender: 'male', age: 24, phone: '+91 98200 00005', trainerId: 'trainer-01', nutriId: null, planId: 'plan_6m_20', startDelta: -5, hour: 9, pattern: 'T2', status: 'active'),
      _ClientSeedSpec(id: 'c-06', firstName: 'Rohan', lastName: 'Gupta', gender: 'male', age: 38, phone: '+91 98200 00006', trainerId: 'trainer-01', nutriId: 'nutri-01', planId: 'plan_3m_12', startDelta: -75, hour: 10, pattern: 'A5', status: 'active', endingInDays: 12),
      _ClientSeedSpec(id: 'c-07', firstName: 'Neha', lastName: 'Joshi', gender: 'female', age: 28, phone: '+91 98200 00007', trainerId: 'trainer-01', nutriId: null, planId: 'plan_3m_12', startDelta: -80, hour: 11, pattern: 'A5', status: 'active', endingInDays: 7),
      _ClientSeedSpec(id: 'c-08', firstName: 'Vikram', lastName: 'Nair', gender: 'male', age: 42, phone: '+91 98200 00008', trainerId: 'trainer-01', nutriId: 'nutri-01', planId: 'plan_12m_20', startDelta: -100, hour: 12, pattern: 'A5', status: 'active'),

      // Active clients - Suyog
      _ClientSeedSpec(id: 'c-09', firstName: 'Anand', lastName: 'Iyer', gender: 'male', age: 33, phone: '+91 98200 00009', trainerId: 'trainer-02', nutriId: 'nutri-01', planId: 'plan_3m_12', startDelta: -20, hour: 7, pattern: 'A5', status: 'active'),
      _ClientSeedSpec(id: 'c-10', firstName: 'Divya', lastName: 'Nambiar', gender: 'female', age: 27, phone: '+91 98200 00010', trainerId: 'trainer-02', nutriId: null, planId: 'plan_3m_20', startDelta: -40, hour: 8, pattern: 'M1', status: 'active'),
      _ClientSeedSpec(id: 'c-11', firstName: 'Siddharth', lastName: 'Bansal', gender: 'male', age: 36, phone: '+91 98200 00011', trainerId: 'trainer-02', nutriId: 'nutri-01', planId: 'plan_3m_20', startDelta: -50, hour: 8, pattern: 'M2', status: 'active'),
      _ClientSeedSpec(id: 'c-12', firstName: 'Kavita', lastName: 'Rao', gender: 'female', age: 40, phone: '+91 98200 00012', trainerId: 'trainer-02', nutriId: null, planId: 'plan_6m_12', startDelta: -70, hour: 9, pattern: 'T1', status: 'active'),
      _ClientSeedSpec(id: 'c-13', firstName: 'Gaurav', lastName: 'Chawla', gender: 'male', age: 25, phone: '+91 98200 00013', trainerId: 'trainer-02', nutriId: null, planId: 'plan_3m_12', startDelta: -78, hour: 10, pattern: 'A5', status: 'active', endingInDays: 9),
      _ClientSeedSpec(id: 'c-14', firstName: 'Ritu', lastName: 'Singhania', gender: 'female', age: 30, phone: '+91 98200 00014', trainerId: 'trainer-02', nutriId: 'nutri-01', planId: 'plan_12m_12', startDelta: -120, hour: 11, pattern: 'A5', status: 'active'),
      _ClientSeedSpec(id: 'c-15', firstName: 'Arjun', lastName: 'Reddy', gender: 'male', age: 29, phone: '+91 98200 00015', trainerId: 'trainer-02', nutriId: null, planId: 'plan_3m_20', startDelta: -15, hour: 12, pattern: 'M1', status: 'active'),
      _ClientSeedSpec(id: 'c-16', firstName: 'Meera', lastName: 'Desai', gender: 'female', age: 35, phone: '+91 98200 00016', trainerId: 'trainer-02', nutriId: 'nutri-01', planId: 'plan_3m_20', startDelta: -15, hour: 12, pattern: 'M2', status: 'active'),

      // Active clients - Khalfan (Evening shift 14:00 - 22:00)
      _ClientSeedSpec(id: 'c-17', firstName: 'Tariq', lastName: 'Shaikh', gender: 'male', age: 32, phone: '+91 98200 00017', trainerId: 'trainer-03', nutriId: 'nutri-01', planId: 'plan_3m_12', startDelta: -30, hour: 15, pattern: 'A5', status: 'active'),
      _ClientSeedSpec(id: 'c-18', firstName: 'Zoya', lastName: 'Akhtar', gender: 'female', age: 26, phone: '+91 98200 00018', trainerId: 'trainer-03', nutriId: null, planId: 'plan_3m_20', startDelta: -25, hour: 16, pattern: 'M1', status: 'active'),
      _ClientSeedSpec(id: 'c-19', firstName: 'Farhan', lastName: 'Qureshi', gender: 'male', age: 28, phone: '+91 98200 00019', trainerId: 'trainer-03', nutriId: null, planId: 'plan_3m_20', startDelta: -25, hour: 16, pattern: 'M2', status: 'active'),
      _ClientSeedSpec(id: 'c-20', firstName: 'Shabnam', lastName: 'Khan', gender: 'female', age: 37, phone: '+91 98200 00020', trainerId: 'trainer-03', nutriId: 'nutri-01', planId: 'plan_6m_12', startDelta: -90, hour: 17, pattern: 'T1', status: 'active'),
      _ClientSeedSpec(id: 'c-21', firstName: 'Sameer', lastName: 'Pathan', gender: 'male', age: 31, phone: '+91 98200 00021', trainerId: 'trainer-03', nutriId: null, planId: 'plan_6m_20', startDelta: -45, hour: 18, pattern: 'A5', status: 'active'),
      _ClientSeedSpec(id: 'c-22', firstName: 'Ayesha', lastName: 'Siddiqui', gender: 'female', age: 29, phone: '+91 98200 00022', trainerId: 'trainer-03', nutriId: 'nutri-01', planId: 'plan_3m_12', startDelta: -79, hour: 19, pattern: 'A5', status: 'active', endingInDays: 8),
      _ClientSeedSpec(id: 'c-23', firstName: 'Bilal', lastName: 'Mirza', gender: 'male', age: 35, phone: '+91 98200 00023', trainerId: 'trainer-03', nutriId: null, planId: 'plan_12m_20', startDelta: -150, hour: 20, pattern: 'A5', status: 'active'),
      _ClientSeedSpec(id: 'c-24', firstName: 'Sana', lastName: 'Fatima', gender: 'female', age: 24, phone: '+91 98200 00024', trainerId: 'trainer-03', nutriId: null, planId: 'plan_3m_12', startDelta: -10, hour: 21, pattern: 'A5', status: 'active'),

      // Extended status clients (Automatic 14-day extension with remaining sessions)
      _ClientSeedSpec(id: 'c-25', firstName: 'Aditya', lastName: 'Roy', gender: 'male', age: 30, phone: '+91 98200 00025', trainerId: 'trainer-01', nutriId: 'nutri-01', planId: 'plan_3m_12', startDelta: -95, hour: 7, pattern: 'A5', status: 'extended', sessionsUsed: 30),
      _ClientSeedSpec(id: 'c-26', firstName: 'Simran', lastName: 'Kaur', gender: 'female', age: 28, phone: '+91 98200 00026', trainerId: 'trainer-02', nutriId: null, planId: 'plan_3m_20', startDelta: -98, hour: 8, pattern: 'T1', status: 'extended', sessionsUsed: 54),
      _ClientSeedSpec(id: 'c-27', firstName: 'Varun', lastName: 'Dhawan', gender: 'male', age: 33, phone: '+91 98200 00027', trainerId: 'trainer-03', nutriId: null, planId: 'plan_3m_12', startDelta: -93, hour: 15, pattern: 'T2', status: 'extended', sessionsUsed: 32),

      // Completed status clients (Used all sessions)
      _ClientSeedSpec(id: 'c-28', firstName: 'Deepak', lastName: 'Chopra', gender: 'male', age: 45, phone: '+91 98200 00028', trainerId: 'trainer-01', nutriId: 'nutri-01', planId: 'plan_3m_12', startDelta: -90, hour: 10, pattern: 'A5', status: 'completed', sessionsUsed: 36),
      _ClientSeedSpec(id: 'c-29', firstName: 'Sunita', lastName: 'Williams', gender: 'female', age: 41, phone: '+91 98200 00029', trainerId: 'trainer-02', nutriId: null, planId: 'plan_3m_20', startDelta: -95, hour: 9, pattern: 'M1', status: 'completed', sessionsUsed: 60),
      _ClientSeedSpec(id: 'c-30', firstName: 'Manish', lastName: 'Paul', gender: 'male', age: 39, phone: '+91 98200 00030', trainerId: 'trainer-03', nutriId: null, planId: 'plan_3m_12', startDelta: -88, hour: 18, pattern: 'A5', status: 'completed', sessionsUsed: 36),

      // Deactivated status clients (Past extension window with sessions left)
      _ClientSeedSpec(id: 'c-31', firstName: 'Rajesh', lastName: 'Khanna', gender: 'male', age: 50, phone: '+91 98200 00031', trainerId: 'trainer-01', nutriId: null, planId: 'plan_3m_12', startDelta: -120, hour: 11, pattern: 'A5', status: 'deactivated', sessionsUsed: 22),
      _ClientSeedSpec(id: 'c-32', firstName: 'Geeta', lastName: 'Phogat', gender: 'female', age: 32, phone: '+91 98200 00032', trainerId: 'trainer-02', nutriId: 'nutri-01', planId: 'plan_3m_20', startDelta: -130, hour: 10, pattern: 'T2', status: 'deactivated', sessionsUsed: 40),
      _ClientSeedSpec(id: 'c-33', firstName: 'Sanjay', lastName: 'Dutt', gender: 'male', age: 55, phone: '+91 98200 00033', trainerId: 'trainer-03', nutriId: null, planId: 'plan_6m_12', startDelta: -220, hour: 19, pattern: 'A5', status: 'deactivated', sessionsUsed: 50),

      // Hold status clients (Paused subscription)
      _ClientSeedSpec(id: 'c-34', firstName: 'Abhishek', lastName: 'Bachchan', gender: 'male', age: 44, phone: '+91 98200 00034', trainerId: 'trainer-01', nutriId: 'nutri-01', planId: 'plan_3m_12', startDelta: -45, hour: 12, pattern: 'M1', status: 'hold', sessionsUsed: 14),
      _ClientSeedSpec(id: 'c-35', firstName: 'Kareena', lastName: 'Kapoor', gender: 'female', age: 41, phone: '+91 98200 00035', trainerId: 'trainer-02', nutriId: null, planId: 'plan_6m_20', startDelta: -60, hour: 11, pattern: 'T1', status: 'hold', sessionsUsed: 30),

      // Client with 3 consecutive absences (§ 4.1 at-risk test)
      _ClientSeedSpec(id: 'c-36', firstName: 'Vicky', lastName: 'Kaushal', gender: 'male', age: 34, phone: '+91 98200 00036', trainerId: 'trainer-01', nutriId: null, planId: 'plan_3m_12', startDelta: -40, hour: 7, pattern: 'A5', status: 'active', consecutiveAbsences: 3),

      // Fresh clients starting today / this week
      _ClientSeedSpec(id: 'c-37', firstName: 'Ranbir', lastName: 'Kapoor', gender: 'male', age: 38, phone: '+91 98200 00037', trainerId: 'trainer-01', nutriId: 'nutri-01', planId: 'plan_3m_12', startDelta: 0, hour: 6, pattern: 'A5', status: 'active'),
      _ClientSeedSpec(id: 'c-38', firstName: 'Alia', lastName: 'Bhatt', gender: 'female', age: 29, phone: '+91 98200 00038', trainerId: 'trainer-02', nutriId: 'nutri-01', planId: 'plan_3m_20', startDelta: 0, hour: 7, pattern: 'M1', status: 'active'),
      _ClientSeedSpec(id: 'c-39', firstName: 'Kartik', lastName: 'Aaryan', gender: 'male', age: 31, phone: '+91 98200 00039', trainerId: 'trainer-03', nutriId: null, planId: 'plan_3m_12', startDelta: 0, hour: 14, pattern: 'A5', status: 'active'),
      _ClientSeedSpec(id: 'c-40', firstName: 'Sara', lastName: 'Ali Khan', gender: 'female', age: 27, phone: '+91 98200 00040', trainerId: 'trainer-03', nutriId: 'nutri-01', planId: 'plan_6m_12', startDelta: 0, hour: 15, pattern: 'A5', status: 'active'),
    ];

    for (final spec in clientConfigs) {
      final startDate = today.add(Duration(days: spec.startDelta));
      final plan = plans.firstWhere((p) => p.id == spec.planId);
      final rawEndDate = DateTime(startDate.year, startDate.month + plan.months, startDate.day).subtract(const Duration(days: 1));
      final endDate = spec.endingInDays != null ? today.add(Duration(days: spec.endingInDays!)) : rawEndDate;
      final extEndDate = spec.status == 'extended' ? endDate.add(const Duration(days: 14)) : null;

      final client = ClientModel(
        id: spec.id,
        firstName: spec.firstName,
        lastName: spec.lastName,
        gender: spec.gender,
        dob: DateTime(now.year - spec.age, 5, 15),
        phonePrimary: spec.phone,
        email: '${spec.firstName.toLowerCase()}@example.com',
        programType: 'General Fitness',
        paymentMethod: 'UPI',
        trainerId: spec.trainerId,
        nutritionistId: spec.nutriId,
        status: spec.status,
        emergencyFirstName: 'Emergency',
        emergencyLastName: 'Contact',
        emergencyPhone: spec.phone,
        consecutiveAbsences: spec.consecutiveAbsences,
        createdAt: startDate,
        updatedAt: now,
        createdBy: 'admin-01',
      );
      MockData.clients.add(client);

      final sub = SubscriptionModel(
        id: 'sub-${spec.id}',
        clientId: spec.id,
        planId: spec.planId,
        startDate: startDate,
        endDate: endDate,
        extensionEndDate: extEndDate,
        totalSessions: plan.totalSessions,
        status: spec.status,
        baselineDueDate: startDate.add(const Duration(days: 7)),
        finalAssessmentDue: spec.status == 'extended' || (spec.endingInDays != null && spec.endingInDays! <= 14),
        createdAt: startDate,
        updatedAt: now,
        createdBy: 'admin-01',
      );
      MockData.subscriptions.add(sub);

      // Slots only exist for active, extended, and hold subscriptions
      if (spec.status == 'active' || spec.status == 'extended' || spec.status == 'hold') {
        final slot = SlotModel(
          id: 'slot-${spec.id}',
          subscriptionId: sub.id,
          clientId: spec.id,
          trainerId: spec.trainerId,
          hourStart: spec.hour,
          pattern: spec.pattern,
          validFrom: startDate,
          validTo: extEndDate ?? endDate,
          createdAt: startDate,
        );
        MockData.slots.add(slot);
      }

      // Consents
      MockData.consents.add(ConsentModel(
        id: 'consent-${spec.id}',
        clientId: spec.id,
        consentText: 'Standard FS-7 Liability Waiver & Fitness Consent',
        signedAt: startDate,
        createdAt: startDate,
      ));

      // ─── Attendance History (§ 4.1 over 3 months) ────────────────────────
      final sessionsUsed = spec.sessionsUsed ?? (spec.status == 'completed' ? plan.totalSessions : (plan.totalSessions * 0.4).round());
      for (int i = 0; i < min(sessionsUsed, 40); i++) {
        final attDate = startDate.add(Duration(days: (i * 2) + 1));
        if (attDate.isAfter(today)) break;
        MockData.attendance.add(AttendanceModel(
          id: 'att-${spec.id}-$i',
          subscriptionId: sub.id,
          clientId: spec.id,
          date: attDate,
          status: (spec.id == 'c-36' && i >= sessionsUsed - 3) ? 'absent' : (i % 8 == 0 ? 'absent' : (i % 12 == 0 ? 'makeup' : 'present')),
          markedBy: spec.trainerId,
          createdAt: attDate,
          updatedAt: attDate,
        ));
      }

      // ─── Baseline & Final Assessments (§ 4.1) ───────────────────────────
      if (spec.id == 'c-01' || spec.id == 'c-06' || spec.id == 'c-10' || spec.id == 'c-25' || spec.id == 'c-28') {
        MockData.assessments.add(AssessmentModel(
          id: 'asm-base-${spec.id}',
          clientId: spec.id,
          subscriptionId: sub.id,
          type: 'baseline',
          testDate: startDate,
          weightKg: 84.6,
          heightCm: 163.0,
          neck: 38.0,
          waistWidest: 92.0,
          hip: 102.0,
          systolic: 124,
          diastolic: 82,
          pushupsCount: 18,
          fs7Score: 68,
          createdAt: startDate,
          updatedAt: startDate,
          createdBy: spec.trainerId,
        ));

        if (spec.status == 'completed' || spec.status == 'extended' || (spec.endingInDays != null && spec.endingInDays! <= 14)) {
          MockData.assessments.add(AssessmentModel(
            id: 'asm-final-${spec.id}',
            clientId: spec.id,
            subscriptionId: sub.id,
            type: 'final',
            testDate: today.subtract(const Duration(days: 2)),
            weightKg: 78.2,
            heightCm: 163.0,
            neck: 37.0,
            waistWidest: 84.0,
            hip: 96.0,
            systolic: 118,
            diastolic: 78,
            pushupsCount: 28,
            fs7Score: 82,
            createdAt: today.subtract(const Duration(days: 2)),
            updatedAt: today.subtract(const Duration(days: 2)),
            createdBy: spec.trainerId,
          ));
        }
      }
    }

    // ─── 3. Inquiries in every status (§ 4.1) ─────────────────────────────
    final inquirySpecs = [
      _InqSeedSpec(id: 'inq-01', name: 'Kabir Oberoi', phone: '+91 99100 00001', status: 'new', daysDelta: 0, nextCallDelta: 0, source: 'Instagram'),
      _InqSeedSpec(id: 'inq-02', name: 'Tanvi Shah', phone: '+91 99100 00002', status: 'follow_up', daysDelta: -2, nextCallDelta: 0, source: 'Walk-in'),
      _InqSeedSpec(id: 'inq-03', name: 'Nikhil Kamath', phone: '+91 99100 00003', status: 'follow_up', daysDelta: -5, nextCallDelta: -2, source: 'Google Maps'),
      _InqSeedSpec(id: 'inq-04', name: 'Disha Patani', phone: '+91 99100 00004', status: 'follow_up', daysDelta: -1, nextCallDelta: 1, source: 'Referral'),
      _InqSeedSpec(id: 'inq-05', name: 'Harsh Goenka', phone: '+91 99100 00005', status: 'converted', daysDelta: -30, nextCallDelta: -25, source: 'Pamphlet'),
      _InqSeedSpec(id: 'inq-06', name: 'Kriti Sanon', phone: '+91 99100 00006', status: 'closed', daysDelta: -20, nextCallDelta: -15, source: 'Instagram', closeReason: 'Joined another gym'),
      _InqSeedSpec(id: 'inq-07', name: 'Varun Grover', phone: '+91 99100 00007', status: 'new', daysDelta: -1, nextCallDelta: 0, source: 'Website'),
      _InqSeedSpec(id: 'inq-08', name: 'Pankaj Tripathi', phone: '+91 99100 00008', status: 'follow_up', daysDelta: -7, nextCallDelta: -3, source: 'Walk-in'),
    ];

    for (final inq in inquirySpecs) {
      final inqDate = today.add(Duration(days: inq.daysDelta));
      final nextCall = today.add(Duration(days: inq.nextCallDelta));
      MockData.inquiries.add(InquiryModel(
        id: inq.id,
        name: inq.name,
        phone: inq.phone,
        sourceId: inq.source,
        status: inq.status,
        inquiryDate: inqDate,
        lastFollowupDate: inqDate,
        nextFollowupDate: nextCall,
        interestedIn: 'Personalized weight loss and strength program.',
        lostReason: inq.closeReason,
        createdAt: inqDate,
        updatedAt: now,
        createdBy: 'admin-01',
      ));

      MockData.inquiryFollowups.add(InquiryFollowupModel(
        id: 'fu-${inq.id}-1',
        inquiryId: inq.id,
        outcome: inq.status == 'new' ? 'Left voicemail' : 'Followed up via call. Discussed 3-month plan.',
        remarks: 'Client asked about morning slots with Faraz.',
        nextFollowupDate: nextCall,
        followupAt: inqDate,
        loggedBy: 'admin-01',
        createdAt: inqDate,
      ));
    }

    // ─── 4. Staff Attendance for 60 Days (§ 4.1) ──────────────────────────
    for (int dayOffset = -60; dayOffset <= 0; dayOffset++) {
      final staffDate = today.add(Duration(days: dayOffset));
      final isSun = staffDate.weekday == DateTime.sunday;
      for (final staff in MockData.allStaff) {
        if (staff.role == 'admin') continue;
        // Faraz had an absence 3 days ago for testing Workflow I
        final isFarazAbsentDay = staff.id == 'trainer-01' && dayOffset == -3;
        final status = isSun ? 'week_off' : (isFarazAbsentDay ? 'absent' : 'present');
        MockData.staffAttendance.add(StaffAttendanceModel(
          id: 'staff-att-${staff.id}-$dayOffset',
          userId: staff.id,
          date: staffDate,
          status: status,
          inTime: isSun || status == 'absent' ? null : staff.shiftStart,
          outTime: isSun || status == 'absent' ? null : staff.shiftEnd,
          note: isFarazAbsentDay ? 'Medical leave' : null,
          markedBy: 'admin-01',
          createdAt: staffDate,
          updatedAt: staffDate,
        ));
      }
    }

    // ─── 5. Initial Notifications (§ 4.1) ─────────────────────────────────
    MockData.notifications.addAll([
      AppNotificationModel(
        id: 'notif-01',
        userId: 'admin-01',
        type: 'at_risk',
        title: 'Client At Risk: Vicky Kaushal',
        body: 'Vicky Kaushal has missed 3 consecutive sessions.',
        scheduledFor: now,
        createdAt: now,
      ),
      AppNotificationModel(
        id: 'notif-02',
        userId: 'admin-01',
        type: 'followup_due',
        title: '2 Follow-up Calls Due Today',
        body: 'Kabir Oberoi and Tanvi Shah are scheduled for calls today.',
        scheduledFor: now,
        createdAt: now,
      ),
      AppNotificationModel(
        id: 'notif-03',
        userId: 'trainer-01',
        type: 'session_alert',
        title: 'Morning Workouts Today',
        body: 'You have 4 client workouts scheduled starting at 07:00 AM.',
        scheduledFor: now,
        createdAt: now,
      ),
    ]);
  }
}

class _ClientSeedSpec {
  final String id;
  final String firstName;
  final String lastName;
  final String gender;
  final int age;
  final String phone;
  final String trainerId;
  final String? nutriId;
  final String planId;
  final int startDelta;
  final int hour;
  final String pattern;
  final String status;
  final int? endingInDays;
  final int? sessionsUsed;
  final int consecutiveAbsences;

  const _ClientSeedSpec({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.age,
    required this.phone,
    required this.trainerId,
    this.nutriId,
    required this.planId,
    required this.startDelta,
    required this.hour,
    required this.pattern,
    required this.status,
    this.endingInDays,
    this.sessionsUsed,
    this.consecutiveAbsences = 0,
  });
}

class _InqSeedSpec {
  final String id;
  final String name;
  final String phone;
  final String status;
  final int daysDelta;
  final int nextCallDelta;
  final String source;
  final String? closeReason;

  const _InqSeedSpec({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    required this.daysDelta,
    required this.nextCallDelta,
    required this.source,
    this.closeReason,
  });
}

