import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fs7_gym_app/core/mock/mock_data.dart';
import 'package:fs7_gym_app/core/services/server_functions_service.dart';
import 'package:fs7_gym_app/data/models/user_model.dart';
import 'package:fs7_gym_app/data/models/client_model.dart';
import 'package:fs7_gym_app/data/models/plan_model.dart';
import 'package:fs7_gym_app/features/auth/providers/auth_provider.dart';
import 'package:fs7_gym_app/features/clients/providers/clients_provider.dart';
import 'package:fs7_gym_app/features/timetable/providers/timetable_provider.dart';
import 'package:fs7_gym_app/features/inquiries/providers/inquiries_provider.dart';
import 'package:fs7_gym_app/features/dashboard/providers/dashboard_provider.dart';

void main() {
  setUp(() {
    // Reset to completely blank state for testing realistic zero-data onboarding
    MockData.clients.clear();
    MockData.subscriptions.clear();
    MockData.slots.clear();
    MockData.attendance.clear();
    MockData.assessments.clear();
    MockData.inquiries.clear();
    MockData.inquiryFollowups.clear();
    MockData.staffAttendance.clear();
    MockData.trainers.clear();
    MockData.allStaff.clear();
    MockData.auditLogs.clear();
    MockData.staffPasswords.clear();

    // Only Admin exists
    MockData.allStaff.add(
      UserModel(
        id: 'admin-01',
        userId: 'fs7admin',
        name: 'Director (Admin)',
        phone: '+91 99999 00001',
        role: 'admin',
        active: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    MockData.staffPasswords['fs7admin'] = 'ceo@fs7';
  });

  group('Blank-Start & Production Onboarding Flow', () {
    test('1. App launches with only Admin; clients, slots and inquiries are completely empty', () {
      expect(MockData.allStaff.length, equals(1));
      expect(MockData.allStaff.first.userId, equals('fs7admin'));
      expect(MockData.trainers.isEmpty, isTrue);
      expect(MockData.clients.isEmpty, isTrue);
      expect(MockData.subscriptions.isEmpty, isTrue);
      expect(MockData.slots.isEmpty, isTrue);
      expect(MockData.inquiries.isEmpty, isTrue);
    });

    test('2. Admin logs in with fs7admin / ceo@fs7', () async {
      final container = ProviderContainer();
      final admin = await container
          .read(authNotifierProvider.notifier)
          .login('fs7admin', 'ceo@fs7');

      expect(admin, isNotNull);
      expect(admin!.isAdmin, isTrue);
      expect(admin.role, equals('admin'));
    });

    test('3. Admin creates Trainer Faraz with custom password and shift hours', () async {
      final service = ServerFunctionsService(Supabase.instance.client);
      final trainer = await service.createStaff(
        name: 'Faraz Khan',
        role: 'trainer',
        phone: '+91 98201 11001',
        email: 'faraz@fs7.in',
        userId: 'trainer_faraz',
        password: 'myFarazSecret123',
        shiftStart: '06:00',
        shiftEnd: '14:00',
        weeklyOff: 7,
        actorId: 'admin-01',
      );

      expect(trainer.userId, equals('trainer_faraz'));
      expect(trainer.isTrainer, isTrue);
      expect(MockData.trainers.length, equals(1));
      expect(MockData.staffPasswords[trainer.id], equals('myFarazSecret123'));
      expect(MockData.staffPasswords['trainer_faraz'], equals('myFarazSecret123'));
    });

    test('4. Trainer Faraz logs in with custom password and updates temporary password', () async {
      final service = ServerFunctionsService(Supabase.instance.client);
      final created = await service.createStaff(
        name: 'Faraz Khan',
        role: 'trainer',
        phone: '+91 98201 11001',
        userId: 'trainer_faraz',
        password: 'myFarazSecret123',
        actorId: 'admin-01',
      );

      final container = ProviderContainer();
      // Faraz logs in with custom password
      final user = await container
          .read(authNotifierProvider.notifier)
          .login('trainer_faraz', 'myFarazSecret123');

      expect(user, isNotNull);
      expect(user!.mustChangePassword, isTrue);

      // Faraz changes his password
      await container
          .read(authNotifierProvider.notifier)
          .changePassword('farazBrandNewPass2026');

      final updatedUser = container.read(currentUserProvider);
      expect(updatedUser!.mustChangePassword, isFalse);
      expect(MockData.staffPasswords[created.id], equals('farazBrandNewPass2026'));

      // Next login with new password succeeds
      final relogUser = await container
          .read(authNotifierProvider.notifier)
          .login('trainer_faraz', 'farazBrandNewPass2026');
      expect(relogUser, isNotNull);
      expect(relogUser!.mustChangePassword, isFalse);
    });

    test('5. Trainer slot isolation: trainer with 0 slots receives empty list, not other trainers slots', () async {
      final service = ServerFunctionsService(Supabase.instance.client);
      final trainerA = await service.createStaff(
        name: 'Trainer A',
        role: 'trainer',
        phone: '+91 90000 00001',
        userId: 'trainer_a',
        password: 'pass123',
        actorId: 'admin-01',
      );
      final trainerB = await service.createStaff(
        name: 'Trainer B',
        role: 'trainer',
        phone: '+91 90000 00002',
        userId: 'trainer_b',
        password: 'pass123',
        actorId: 'admin-01',
      );

      // Book a slot for Trainer A
      MockData.slots.add(
        SlotModel(
          id: 'slot-1',
          subscriptionId: 'sub-1',
          clientId: 'client-1',
          trainerId: trainerA.id,
          hourStart: 7,
          pattern: 'A5',
          validFrom: DateTime.now().subtract(const Duration(days: 10)),
          validTo: DateTime.now().add(const Duration(days: 60)),
          createdAt: DateTime.now(),
        ),
      );

      final container = ProviderContainer();

      // Trainer A has 1 slot
      final slotsA = await container.read(trainerSlotsProvider(trainerA.id).future);
      expect(slotsA.length, equals(1));
      expect(slotsA.first.trainerId, equals(trainerA.id));

      // Trainer B has 0 slots -> MUST return empty list []!
      final slotsB = await container.read(trainerSlotsProvider(trainerB.id).future);
      expect(slotsB.isEmpty, isTrue);
    });

    test('6. Client subscriptions & attendance data isolation per client ID', () async {
      final service = ServerFunctionsService(Supabase.instance.client);
      final trainer = await service.createStaff(
        name: 'Trainer Faraz',
        role: 'trainer',
        phone: '+91 98201 11001',
        userId: 'trainer_faraz',
        password: 'trainer123',
        actorId: 'admin-01',
      );

      // Add Client 1
      final res1 = await service.createClient(
        profileData: {
          'first_name': 'Rohan',
          'last_name': 'Mehta',
          'phone_primary': '+91 98200 00001',
          'gender': 'Male',
          'dob': '1995-01-01',
          'program_type': 'Muscle Gain',
          'emergency_first_name': 'Parent',
          'emergency_phone': '+91 98200 00001',
        },
        planId: 'plan_3m_12',
        startDate: DateTime.now(),
        trainerId: trainer.id,
        hourStart: 7,
        pattern: 'A5',
        paymentMethod: 'UPI',
        memberSignature: Uint8List.fromList([1]),
        trainerSignature: Uint8List.fromList([1]),
        consentText: 'Consent',
        createdBy: 'admin-01',
      );
      final client1 = res1['client'] as ClientModel;
      final sub1 = res1['subscription'] as SubscriptionModel;

      // Add Client 2
      final res2 = await service.createClient(
        profileData: {
          'first_name': 'Pooja',
          'last_name': 'Sharma',
          'phone_primary': '+91 98200 00002',
          'gender': 'Female',
          'dob': '1998-05-15',
          'program_type': 'Weight Loss',
          'emergency_first_name': 'Spouse',
          'emergency_phone': '+91 98200 00002',
        },
        planId: 'plan_1m_12',
        startDate: DateTime.now(),
        trainerId: trainer.id,
        hourStart: 8,
        pattern: 'M1',
        paymentMethod: 'Cash',
        memberSignature: Uint8List.fromList([1]),
        trainerSignature: Uint8List.fromList([1]),
        consentText: 'Consent',
        createdBy: 'admin-01',
      );
      final client2 = res2['client'] as ClientModel;
      final sub2 = res2['subscription'] as SubscriptionModel;

      // Mark attendance for Client 1 only
      await service.markAttendance(
        clientId: client1.id,
        date: DateTime.now(),
        status: 'present',
        callerId: trainer.id,
        callerRole: 'trainer',
      );

      final container = ProviderContainer();

      // Client 1 subscriptions
      final subs1 = await container.read(clientSubscriptionsProvider(client1.id).future);
      expect(subs1.length, equals(1));
      expect(subs1.first.id, equals(sub1.id));

      // Client 2 subscriptions
      final subs2 = await container.read(clientSubscriptionsProvider(client2.id).future);
      expect(subs2.length, equals(1));
      expect(subs2.first.id, equals(sub2.id));

      // Client 1 attendance has 1 record
      final att1 = await container.read(clientAttendanceProvider(sub1.id).future);
      expect(att1.length, equals(1));
      expect(att1.first.isPresent, isTrue);

      // Client 2 attendance has 0 records (NOT Client 1's records!)
      final att2 = await container.read(clientAttendanceProvider(sub2.id).future);
      expect(att2.isEmpty, isTrue);
    });

    test('7. Inquiry followups timeline logs and retrieves successfully', () async {
      final service = ServerFunctionsService(Supabase.instance.client);
      final inq = await service.createInquiry(
        data: {
          'name': 'Deepak Verma',
          'phone': '+91 97777 66666',
          'source_id': 'instagram',
          'interested_in': 'Personal Training',
        },
        createdBy: 'admin-01',
      );

      final container = ProviderContainer();
      final initialFollowups = await container.read(inquiryFollowupsProvider(inq.id).future);
      expect(initialFollowups.isEmpty, isTrue);

      // Log a follow-up call
      await service.logFollowup(
        inquiryId: inq.id,
        outcome: 'Interested',
        remarks: 'Client interested in morning 7 AM slot. Requested trial.',
        nextFollowupDate: DateTime.now().add(const Duration(days: 2)),
        loggedBy: 'admin-01',
      );

      container.invalidate(inquiryFollowupsProvider(inq.id));
      final updatedFollowups = await container.read(inquiryFollowupsProvider(inq.id).future);
      expect(updatedFollowups.length, equals(1));
      expect(updatedFollowups.first.outcome, equals('Interested'));
      expect(updatedFollowups.first.remarks, contains('morning 7 AM slot'));
    });

    test('8. Dashboard metrics accurately reconcile with blank-start state', () async {
      final container = ProviderContainer();
      final dash = await container.read(adminDashboardProvider.future);

      expect(dash.activeClients, equals(0));
      expect(dash.sessionsScheduled, equals(0));
      expect(dash.sessionsPresent, equals(0));
      expect(dash.sessionsAbsent, equals(0));
      expect(dash.pendingFollowups, equals(0));
      expect(dash.freeSeats, equals(0));
      expect(dash.conversionRate, equals(0.0));
    });
  });
}

