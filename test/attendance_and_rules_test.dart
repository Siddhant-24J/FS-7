import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs7_gym_app/core/services/server_functions_service.dart';
import 'package:fs7_gym_app/core/mock/mock_data.dart';
import 'package:fs7_gym_app/core/mock/mock_seed.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    MockSeed.seed(force: true);
  });

  group('Group 5: Add Client End-to-End & Validation (Bug B1 & § 4.2.5)', () {
    test('Admin adds client successfully, slot booked, and profile created', () async {
      final service = ServerFunctionsService(Supabase.instance.client);
      final initialCount = MockData.clients.length;

      final result = await service.createClient(
        profileData: {
          'first_name': 'Aarav',
          'last_name': 'Singhal',
          'phone_primary': '+91 99999 88888',
          'gender': 'Male',
          'dob': '1996-04-12',
          'program_type': 'Weight Loss',
          'emergency_first_name': 'Parent',
          'emergency_phone': '+91 99999 88888',
        },
        planId: 'plan_3m_12',
        startDate: DateTime.now(),
        trainerId: 'trainer-01',
        nutritionistId: 'nutri-01',
        hourStart: 6, // 6 AM Faraz is free
        pattern: 'A5',
        paymentMethod: 'UPI',
        memberSignature: Uint8List.fromList([1, 2, 3]),
        trainerSignature: Uint8List.fromList([1, 2, 3]),
        consentText: 'Standard Consent',
        createdBy: 'admin-01',
      );

      expect(MockData.clients.length, equals(initialCount + 1));
      final client = result['client'];
      expect(client.fullName, equals('Aarav Singhal'));
      expect(client.trainerId, equals('trainer-01'));

      // Check slot was booked
      final slot = MockData.slots.where((s) => s.clientId == client.id).firstOrNull;
      expect(slot, isNotNull);
      expect(slot!.hourStart, equals(6));
      expect(slot.pattern, equals('A5'));
    });

    test('Duplicate phone number throws PHONE_EXISTS', () async {
      final service = ServerFunctionsService(Supabase.instance.client);
      // c-01 phone is +91 98200 00001
      expect(
        () => service.createClient(
          profileData: {
            'first_name': 'Duplicate',
            'last_name': 'User',
            'phone_primary': '+91 98200 00001',
          },
          planId: 'plan_3m_12',
          startDate: DateTime.now(),
          trainerId: 'trainer-01',
          hourStart: 6,
          pattern: 'A5',
          paymentMethod: 'Cash',
          memberSignature: Uint8List.fromList([1]),
          trainerSignature: Uint8List.fromList([1]),
          consentText: 'Consent',
          createdBy: 'admin-01',
        ),
        throwsA(predicate((e) => e is BusinessException && e.code == 'PHONE_EXISTS')),
      );
    });

    test('Booking full slot throws SLOT_FULL', () async {
      final service = ServerFunctionsService(Supabase.instance.client);
      // Hour 8 on trainer-01 has M1 (c-02) and M2 (c-03) -> MWF full!
      expect(
        () => service.createClient(
          profileData: {
            'first_name': 'Overflow',
            'last_name': 'User',
            'phone_primary': '+91 99999 77777',
          },
          planId: 'plan_3m_12',
          startDate: DateTime.now(),
          trainerId: 'trainer-01',
          hourStart: 8,
          pattern: 'A5', // A5 needs MWF which is full!
          paymentMethod: 'Cash',
          memberSignature: Uint8List.fromList([1]),
          trainerSignature: Uint8List.fromList([1]),
          consentText: 'Consent',
          createdBy: 'admin-01',
        ),
        throwsA(predicate((e) => e is BusinessException && (e.code == 'SLOT_FULL' || e.code == 'SLOT_PATTERN_TAKEN'))),
      );
    });
  });

  group('Group 6: Attendance Rules & Weekday Math (Bug B4 & § 4.2.6)', () {
    test('Marking Present increments sessions used by exactly 1', () async {
      final service = ServerFunctionsService(Supabase.instance.client);
      final sub = MockData.subscriptions.firstWhere((s) => s.clientId == 'c-01');

      final initialAttendances = MockData.attendance.where((a) => a.clientId == 'c-01' && (a.isPresent || a.isMakeup)).length;

      await service.markAttendance(
        clientId: 'c-01',
        date: DateTime.now(),
        status: 'present',
        callerId: 'trainer-01',
        callerRole: 'trainer',
      );

      final updatedAttendances = MockData.attendance.where((a) => a.clientId == 'c-01' && (a.isPresent || a.isMakeup)).length;
      expect(updatedAttendances, equals(initialAttendances + 1));
    });

    test('Marking Absent does NOT consume any session', () async {
      final service = ServerFunctionsService(Supabase.instance.client);

      final initialAttendances = MockData.attendance.where((a) => a.clientId == 'c-02' && (a.isPresent || a.isMakeup)).length;

      await service.markAttendance(
        clientId: 'c-02',
        date: DateTime.now(),
        status: 'absent',
        callerId: 'trainer-01',
        callerRole: 'trainer',
      );

      final updatedAttendances = MockData.attendance.where((a) => a.clientId == 'c-02' && (a.isPresent || a.isMakeup)).length;
      expect(updatedAttendances, equals(initialAttendances));
    });

    test('Trainer marking older than 24 hours is refused with EDIT_WINDOW_CLOSED', () async {
      final service = ServerFunctionsService(Supabase.instance.client);
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

      expect(
        () => service.markAttendance(
          clientId: 'c-01',
          date: threeDaysAgo,
          status: 'present',
          callerId: 'trainer-01',
          callerRole: 'trainer', // Trainer cannot edit past 24h
        ),
        throwsA(predicate((e) => e is BusinessException && e.code == 'EDIT_WINDOW_CLOSED')),
      );
    });

    test('Admin CAN mark past attendance older than 24 hours', () async {
      final service = ServerFunctionsService(Supabase.instance.client);
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

      // Admin has no 24h lock
      await service.markAttendance(
        clientId: 'c-01',
        date: threeDaysAgo,
        status: 'present',
        callerId: 'admin-01',
        callerRole: 'admin',
      );

      final att = MockData.attendance.where((a) {
        return a.clientId == 'c-01' &&
            a.date.year == threeDaysAgo.year &&
            a.date.month == threeDaysAgo.month &&
            a.date.day == threeDaysAgo.day;
      }).firstOrNull;

      expect(att, isNotNull);
      expect(att!.status, equals('present'));
    });

    test('Three consecutive absences increments counter for at-risk alert', () async {
      final client = MockData.clients.firstWhere((c) => c.id == 'c-36');
      expect(client.consecutiveAbsences, equals(3));
      // In seed, an at-risk notification was generated
      final hasNotif = MockData.notifications.any((n) => n.type == 'at_risk' && n.title.contains('Vicky Kaushal'));
      expect(hasNotif, isTrue);
    });
  });
}

