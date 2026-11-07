import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../constants/supabase_constants.dart';
import '../formulas/slot_engine.dart';
import '../formulas/fitness_formulas.dart';
import '../mock/mock_data.dart';
import '../services/pdf_service.dart';
import '../../data/models/user_model.dart';
import '../../data/models/client_model.dart';
import '../../data/models/plan_model.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/assessment_model.dart';
import '../../data/models/inquiry_model.dart';
import '../../data/models/staff_attendance_model.dart';
import '../../data/models/document_model.dart';

/// Business exception with error codes specified in Section 20.2
class BusinessException implements Exception {
  final String code;
  final String message;

  const BusinessException(this.code, this.message);

  @override
  String toString() => message;

  static const slotFull = BusinessException('SLOT_FULL', 'This hour is full for that pattern');
  static const slotPatternTaken = BusinessException('SLOT_PATTERN_TAKEN', 'That seat is already taken');
  static const slotOutsideHours = BusinessException('SLOT_OUTSIDE_HOURS', 'Trainer does not work at this time');
  static const hasActiveClients = BusinessException('HAS_ACTIVE_CLIENTS', 'Move this trainer\'s clients first');
  static const notYourClient = BusinessException('NOT_YOUR_CLIENT', 'You do not have access to this client');
  static const editWindowClosed = BusinessException('EDIT_WINDOW_CLOSED', 'Only admin can change this now');
  static const noSessionsLeft = BusinessException('NO_SESSIONS_LEFT', 'No sessions left on this plan');
  static const openSubscriptionExists = BusinessException('OPEN_SUBSCRIPTION_EXISTS', 'This client already has an active plan');
  static const phoneExists = BusinessException('PHONE_EXISTS', 'This number already exists');
  static const outOfRange = BusinessException('OUT_OF_RANGE', 'Please check this value');
}

/// Unified Server Functions Service (Section 18 & 20)
/// Executes business logic atomically with exact validation rules, audit logging,
/// and live offline resilience.
class ServerFunctionsService {
  final SupabaseClient _client;

  ServerFunctionsService(this._client);

  static const Map<String, Set<int>> patternDays = {
    'A5': {1, 2, 3, 4, 5},
    'M1': {1, 3, 5},
    'M2': {1, 3, 5},
    'T1': {2, 4, 6},
    'T2': {2, 4, 6},
  };

  // ──────────────────────────────────────────────────────────────────────────
  // 1. check_slot (Section 21.1)
  // ──────────────────────────────────────────────────────────────────────────
  SlotValidationResult checkSlot({
    required String trainerId,
    required int hourStart,
    required String newPattern,
    String? excludeSubscriptionId,
  }) {
    // 1. Check working hours
    final trainer = MockData.trainers.where((t) => t.id == trainerId).firstOrNull ??
        MockData.allStaff.where((u) => u.id == trainerId).firstOrNull;
    if (trainer != null) {
      final startH = int.tryParse((trainer.shiftStart ?? '06:00').split(':')[0]) ?? 6;
      final endH = int.tryParse((trainer.shiftEnd ?? '22:00').split(':')[0]) ?? 22;
      if (hourStart < startH || hourStart >= endH) {
        throw BusinessException.slotOutsideHours;
      }
    }

    // 2. Open slot rows for (trainer, hour) where validTo is in the future
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final existing = MockData.slots.where((s) {
      if (s.trainerId != trainerId || s.hourStart != hourStart) return false;
      if (excludeSubscriptionId != null && s.subscriptionId == excludeSubscriptionId) return false;
      return s.validTo.isAfter(today) || s.validTo.isAtSameMomentAs(today);
    }).toList();

    // 3. Pattern uniqueness for M1, M2, T1, T2
    if (newPattern != 'A5' && existing.any((s) => s.pattern == newPattern)) {
      throw BusinessException.slotPatternTaken;
    }

    // 4. Daily count must not exceed 2
    final days = patternDays[newPattern] ?? {};
    for (final d in days) {
      final count = existing.where((s) => (patternDays[s.pattern] ?? {}).contains(d)).length;
      if (count + 1 > 2) {
        throw BusinessException.slotFull;
      }
    }

    return const SlotValidationResult(isValid: true);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. create_client (Workflow B)
  // ──────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createClient({
    required Map<String, dynamic> profileData,
    required String planId,
    required DateTime startDate,
    required String trainerId,
    String? nutritionistId,
    required int hourStart,
    required String pattern,
    required String paymentMethod,
    required Uint8List memberSignature,
    required Uint8List trainerSignature,
    required String consentText,
    required String createdBy,
  }) async {
    // Phone uniqueness check
    final phone = profileData['phone_primary'] as String? ?? '';
    if (MockData.clients.any((c) => c.phonePrimary == phone)) {
      throw BusinessException.phoneExists;
    }

    // Verify slot availability
    checkSlot(trainerId: trainerId, hourStart: hourStart, newPattern: pattern);

    // Plan & end date calculation
    final plan = PlanModel.defaultPlans.firstWhere(
      (p) => p.id == planId,
      orElse: () => PlanModel.defaultPlans.first,
    );
    // End date = start + months - 1 day
    final calculatedEndDate = DateTime(
      startDate.year,
      startDate.month + plan.months,
      startDate.day,
    ).subtract(const Duration(days: 1));

    final newClientId = 'client-${DateTime.now().millisecondsSinceEpoch}';
    final newSubId = 'sub-${DateTime.now().millisecondsSinceEpoch}';
    final newSlotId = 'slot-${DateTime.now().millisecondsSinceEpoch}';
    final newConsentId = 'consent-${DateTime.now().millisecondsSinceEpoch}';

    final client = ClientModel(
      id: newClientId,
      firstName: profileData['first_name'] ?? '',
      lastName: profileData['last_name'] ?? '',
      address: profileData['address'],
      dob: DateTime.tryParse(profileData['dob'] ?? '') ?? DateTime(1995, 1, 1),
      gender: profileData['gender'] ?? 'Male',
      phonePrimary: phone,
      phoneSecondary: profileData['phone_secondary'],
      email: profileData['email'],
      programType: profileData['program_type'] ?? 'General Fitness',
      paymentMethod: paymentMethod,
      trainerId: trainerId,
      nutritionistId: nutritionistId,
      status: 'active',
      sourceInquiryId: profileData['source_inquiry_id'],
      emergencyFirstName: profileData['emergency_first_name'] ?? 'Contact',
      emergencyLastName: profileData['emergency_last_name'] ?? 'Person',
      emergencyAddress: profileData['emergency_address'],
      emergencyPhone: profileData['emergency_phone'] ?? phone,
      consecutiveAbsences: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );

    final sub = SubscriptionModel(
      id: newSubId,
      clientId: newClientId,
      planId: planId,
      startDate: startDate,
      endDate: calculatedEndDate,
      totalSessions: plan.totalSessions,
      status: 'active',
      baselineDueDate: startDate.add(const Duration(days: 7)),
      finalAssessmentDue: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );

    final slot = SlotModel(
      id: newSlotId,
      subscriptionId: newSubId,
      clientId: newClientId,
      trainerId: trainerId,
      hourStart: hourStart,
      pattern: pattern,
      validFrom: startDate,
      validTo: calculatedEndDate,
      createdAt: DateTime.now(),
    );

    final consent = ConsentModel(
      id: newConsentId,
      clientId: newClientId,
      consentText: consentText,
      signedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    // Save in memory
    MockData.clients.insert(0, client);
    MockData.subscriptions.insert(0, sub);
    MockData.slots.insert(0, slot);
    MockData.consents.insert(0, consent);

    // Workflow G Step 6: If converted from an inquiry, mark inquiry converted and cancel reminders
    final sourceInquiryId = profileData['source_inquiry_id'] as String?;
    if (sourceInquiryId != null && sourceInquiryId.isNotEmpty) {
      final inqIdx = MockData.inquiries.indexWhere((i) => i.id == sourceInquiryId);
      if (inqIdx != -1) {
        final inq = MockData.inquiries[inqIdx];
        MockData.inquiries[inqIdx] = inq.copyWith(
          status: 'converted',
          convertedClientId: newClientId,
          updatedAt: DateTime.now(),
        );
        // Cancel pending notifications/reminders for this inquiry
        for (int i = 0; i < MockData.notifications.length; i++) {
          final n = MockData.notifications[i];
          if (n.payload?['inquiry_id'] == sourceInquiryId) {
            MockData.notifications[i] = n.copyWith(cancelled: true);
          }
        }
      }
    }

    // Audit log
    _writeAuditLog(
      actorId: createdBy,
      tableName: 'clients',
      recordId: newClientId,
      field: 'status',
      newValue: 'active',
    );

    // Notify trainer
    _createNotification(
      userId: trainerId,
      type: 'client_assigned',
      title: 'New Client Assigned',
      body: '${client.fullName} has been assigned to you for slot $pattern at ${slot.hourLabel}.',
      payload: {'client_id': newClientId, 'subscription_id': newSubId},
    );

    return {'client': client, 'subscription': sub, 'slot': slot};
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. mark_attendance (Section 21.3)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> markAttendance({
    required String clientId,
    required DateTime date,
    required String status,
    String? note,
    required String callerId,
    required String callerRole,
  }) async {
    final client = MockData.clients.where((c) => c.id == clientId).firstOrNull;
    if (client == null) throw Exception('Client not found');

    // 1. Role verification
    if (callerRole != 'admin' && client.trainerId != callerId) {
      throw BusinessException.notYourClient;
    }

    // 2. 24-hour edit limit for trainers
    final now = DateTime.now();
    if (callerRole != 'admin') {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final today = DateTime(now.year, now.month, now.day);
      if (today.difference(dateOnly).inHours > 24) {
        throw BusinessException.editWindowClosed;
      }
    }

    final sub = MockData.subscriptions
        .where((s) => s.clientId == clientId && (s.isActive || s.isExtended))
        .firstOrNull;
    if (sub == null) throw Exception('No active subscription found');

    final dateStr = date.toIso8601String().split('T')[0];

    // 3. Upsert ONE attendance row
    final existingIdx = MockData.attendance.indexWhere(
      (a) => a.subscriptionId == sub.id && a.date.toIso8601String().split('T')[0] == dateStr,
    );

    final record = AttendanceModel(
      id: existingIdx != -1 ? MockData.attendance[existingIdx].id : 'att-${DateTime.now().millisecondsSinceEpoch}',
      subscriptionId: sub.id,
      clientId: clientId,
      date: date,
      status: status,
      markedBy: callerId,
      note: note,
      createdAt: existingIdx != -1 ? MockData.attendance[existingIdx].createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (existingIdx != -1) {
      MockData.attendance[existingIdx] = record;
    } else {
      MockData.attendance.insert(0, record);
    }

    // 4. Session counter calculation
    final subAttendance = MockData.attendance.where((a) => a.subscriptionId == sub.id).toList();
    final used = subAttendance.where((a) => a.isPresent || a.isMakeup).length;
    final remaining = sub.totalSessions - used;

    if ((status == 'present' || status == 'makeup') && remaining < 0) {
      throw BusinessException.noSessionsLeft;
    }

    // 5. Auto-complete if remaining == 0
    if (remaining == 0) {
      final completedSub = SubscriptionModel(
        id: sub.id,
        clientId: sub.clientId,
        planId: sub.planId,
        startDate: sub.startDate,
        endDate: sub.endDate,
        totalSessions: sub.totalSessions,
        status: 'completed',
        createdAt: sub.createdAt,
        updatedAt: DateTime.now(),
        createdBy: sub.createdBy,
      );
      final subIdx = MockData.subscriptions.indexWhere((s) => s.id == sub.id);
      if (subIdx != -1) MockData.subscriptions[subIdx] = completedSub;

      // Close slot
      final slotIdx = MockData.slots.indexWhere((s) => s.subscriptionId == sub.id);
      if (slotIdx != -1) {
        final oldSlot = MockData.slots[slotIdx];
        MockData.slots[slotIdx] = SlotModel(
          id: oldSlot.id,
          subscriptionId: oldSlot.subscriptionId,
          clientId: oldSlot.clientId,
          trainerId: oldSlot.trainerId,
          hourStart: oldSlot.hourStart,
          pattern: oldSlot.pattern,
          validFrom: oldSlot.validFrom,
          validTo: date,
          createdAt: oldSlot.createdAt,
        );
      }

      // Update client status
      _updateClientStatus(clientId, 'completed');

      // Notify admin
      _createNotification(
        userId: 'admin-01',
        type: 'plan_completed',
        title: 'Plan Completed',
        body: '${client.fullName} has completed all ${sub.totalSessions} sessions.',
        payload: {'client_id': clientId, 'subscription_id': sub.id},
      );
    }

    // 6. Final assessment due flag if remaining <= 3 or days_left <= 7
    final daysLeft = sub.endDate.difference(now).inDays;
    final hasFinal = MockData.assessments.any((a) => a.subscriptionId == sub.id && a.type == 'final');
    if ((remaining <= 3 || daysLeft <= 7) && !hasFinal && !sub.finalAssessmentDue) {
      final updatedSub = SubscriptionModel(
        id: sub.id,
        clientId: sub.clientId,
        planId: sub.planId,
        startDate: sub.startDate,
        endDate: sub.endDate,
        totalSessions: sub.totalSessions,
        status: sub.status,
        baselineDueDate: sub.baselineDueDate,
        finalAssessmentDue: true,
        createdAt: sub.createdAt,
        updatedAt: DateTime.now(),
        createdBy: sub.createdBy,
      );
      final subIdx = MockData.subscriptions.indexWhere((s) => s.id == sub.id);
      if (subIdx != -1) MockData.subscriptions[subIdx] = updatedSub;

      _createNotification(
        userId: client.trainerId,
        type: 'final_due',
        title: 'Final Assessment Due',
        body: 'Final fitness assessment is due for ${client.fullName} (sessions remaining: $remaining).',
        payload: {'client_id': clientId, 'subscription_id': sub.id},
      );
    }

    // 7. Consecutive absences check
    final sortedAtt = subAttendance..sort((a, b) => b.date.compareTo(a.date));
    int consecutive = 0;
    for (final a in sortedAtt) {
      if (a.isAbsent) consecutive++;
      else break;
    }
    _updateClientConsecutiveAbsences(clientId, consecutive);

    if (consecutive >= 3) {
      _createNotification(
        userId: client.trainerId,
        type: 'absent_alert',
        title: 'At-Risk Alert: 3 Consecutive Absences',
        body: '${client.fullName} has missed 3 consecutive workouts. Please follow up.',
        payload: {'client_id': clientId},
      );
      _createNotification(
        userId: 'admin-01',
        type: 'absent_alert',
        title: 'At-Risk Client: ${client.fullName}',
        body: 'Client has 3 consecutive absences with trainer.',
        payload: {'client_id': clientId},
      );
    }

    // 8. Audit log
    _writeAuditLog(
      actorId: callerId,
      tableName: 'attendance',
      recordId: record.id,
      field: 'status',
      newValue: status,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. run_status_job (Section 21.4 - Nightly 00:30 IST)
  // ──────────────────────────────────────────────────────────────────────────
  void runStatusJob() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int i = 0; i < MockData.subscriptions.length; i++) {
      final sub = MockData.subscriptions[i];

      // A. Active subscriptions past end_date
      if (sub.isActive && sub.endDate.isBefore(today)) {
        final used = MockData.attendance.where((a) => a.subscriptionId == sub.id && (a.isPresent || a.isMakeup)).length;
        final remaining = sub.totalSessions - used;

        if (remaining > 0) {
          final extEnd = sub.extensionEndDate ?? sub.endDate.add(const Duration(days: 14));
          MockData.subscriptions[i] = SubscriptionModel(
            id: sub.id, clientId: sub.clientId, planId: sub.planId,
            startDate: sub.startDate, endDate: sub.endDate,
            extensionEndDate: extEnd, totalSessions: sub.totalSessions,
            status: 'extended', baselineDueDate: sub.baselineDueDate,
            finalAssessmentDue: sub.finalAssessmentDue,
            createdAt: sub.createdAt, updatedAt: DateTime.now(), createdBy: sub.createdBy,
          );
          _updateClientStatus(sub.clientId, 'extended');
          _createNotification(
            userId: 'admin-01',
            type: 'extension_started',
            title: 'Client in 14-Day Extension',
            body: 'Client ${sub.clientId} moved to Extended with $remaining sessions remaining.',
          );
        } else {
          _closeSubscriptionAndSlot(sub, today, 'completed');
        }
      }

      // B. Extended subscriptions past extension_end_date
      else if (sub.isExtended && sub.extensionEndDate != null && sub.extensionEndDate!.isBefore(today)) {
        final used = MockData.attendance.where((a) => a.subscriptionId == sub.id && (a.isPresent || a.isMakeup)).length;
        final remaining = sub.totalSessions - used;

        if (remaining > 0) {
          _closeSubscriptionAndSlot(sub, sub.extensionEndDate!, 'deactivated', reason: 'plan expired');
          _createNotification(
            userId: 'admin-01',
            type: 'client_deactivated',
            title: 'Client Deactivated (Extension Expired)',
            body: 'Client ${sub.clientId} had $remaining sessions unused. Seat has been freed.',
          );
        } else {
          _closeSubscriptionAndSlot(sub, sub.extensionEndDate!, 'completed');
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5. renew_subscription (Workflow E)
  // ──────────────────────────────────────────────────────────────────────────
  Future<SubscriptionModel> renewSubscription({
    required String clientId,
    required String planId,
    required DateTime startDate,
    required int hourStart,
    required String pattern,
    required String trainerId,
    required String createdBy,
  }) async {
    // 1. Close open subscription if any
    final existingSub = MockData.subscriptions.where((s) => s.clientId == clientId && (s.isActive || s.isExtended)).firstOrNull;
    if (existingSub != null) {
      _closeSubscriptionAndSlot(existingSub, startDate, 'completed');
    }

    // 2. Validate slot
    checkSlot(trainerId: trainerId, hourStart: hourStart, newPattern: pattern);

    // 3. Plan details
    final plan = PlanModel.defaultPlans.firstWhere((p) => p.id == planId, orElse: () => PlanModel.defaultPlans.first);
    final endDate = DateTime(startDate.year, startDate.month + plan.months, startDate.day).subtract(const Duration(days: 1));

    final newSubId = 'sub-${DateTime.now().millisecondsSinceEpoch}';
    final newSlotId = 'slot-${DateTime.now().millisecondsSinceEpoch}';

    final newSub = SubscriptionModel(
      id: newSubId,
      clientId: clientId,
      planId: planId,
      startDate: startDate,
      endDate: endDate,
      totalSessions: plan.totalSessions,
      status: 'active',
      baselineDueDate: startDate.add(const Duration(days: 7)),
      finalAssessmentDue: false,
      renewedFromId: existingSub?.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );

    final newSlot = SlotModel(
      id: newSlotId,
      subscriptionId: newSubId,
      clientId: clientId,
      trainerId: trainerId,
      hourStart: hourStart,
      pattern: pattern,
      validFrom: startDate,
      validTo: endDate,
      createdAt: DateTime.now(),
    );

    MockData.subscriptions.insert(0, newSub);
    MockData.slots.insert(0, newSlot);
    _updateClientStatus(clientId, 'active');

    _writeAuditLog(actorId: createdBy, tableName: 'subscriptions', recordId: newSubId, field: 'status', newValue: 'active');

    _createNotification(
      userId: trainerId,
      type: 'client_renewed',
      title: 'Client Renewed',
      body: 'Client has renewed membership for slot $pattern at ${newSlot.hourLabel}.',
      payload: {'client_id': clientId, 'subscription_id': newSubId},
    );

    return newSub;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5b. deactivate_client (Workflow C & Section 20.1)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> deactivateClient({
    required String clientId,
    required String reason,
    required String actorId,
  }) async {
    final client = MockData.clients.where((c) => c.id == clientId).firstOrNull;

    // Close any active/extended/hold subscription
    final sub = MockData.subscriptions.where((s) => s.clientId == clientId && (s.isActive || s.isExtended || s.isHold)).firstOrNull;
    if (sub != null) {
      _closeSubscriptionAndSlot(sub, DateTime.now(), 'deactivated', reason: reason);
    } else {
      _updateClientStatus(clientId, 'deactivated');
    }

    // Completely remove the slot so the timetable slot immediately looks empty
    MockData.slots.removeWhere((s) => s.clientId == clientId || (sub != null && s.subscriptionId == sub.id));

    _writeAuditLog(
      actorId: actorId,
      tableName: 'clients',
      recordId: clientId,
      field: 'status',
      oldValue: client?.status ?? 'active',
      newValue: 'deactivated',
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5c. hold_subscription & resume_subscription (Section 20.1)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> holdSubscription({
    required String subscriptionId,
    required DateTime holdFrom,
    required bool releaseSlot,
    required String actorId,
  }) async {
    final subIdx = MockData.subscriptions.indexWhere((s) => s.id == subscriptionId);
    if (subIdx == -1) throw Exception('Subscription not found');
    final sub = MockData.subscriptions[subIdx];

    MockData.subscriptions[subIdx] = SubscriptionModel(
      id: sub.id,
      clientId: sub.clientId,
      planId: sub.planId,
      startDate: sub.startDate,
      endDate: sub.endDate,
      totalSessions: sub.totalSessions,
      status: 'hold',
      holdFrom: holdFrom,
      baselineDueDate: sub.baselineDueDate,
      finalAssessmentDue: sub.finalAssessmentDue,
      createdAt: sub.createdAt,
      updatedAt: DateTime.now(),
      createdBy: sub.createdBy,
    );

    if (releaseSlot) {
      final slotIdx = MockData.slots.indexWhere((s) => s.subscriptionId == subscriptionId);
      if (slotIdx != -1) {
        final oldSlot = MockData.slots[slotIdx];
        MockData.slots[slotIdx] = SlotModel(
          id: oldSlot.id,
          subscriptionId: oldSlot.subscriptionId,
          clientId: oldSlot.clientId,
          trainerId: oldSlot.trainerId,
          hourStart: oldSlot.hourStart,
          pattern: oldSlot.pattern,
          validFrom: oldSlot.validFrom,
          validTo: holdFrom,
          createdAt: oldSlot.createdAt,
        );
      }
    }

    _updateClientStatus(sub.clientId, 'hold');
    _writeAuditLog(actorId: actorId, tableName: 'subscriptions', recordId: subscriptionId, field: 'status', newValue: 'hold');
  }

  Future<void> resumeSubscription({
    required String subscriptionId,
    required DateTime resumeDate,
    required String actorId,
  }) async {
    final subIdx = MockData.subscriptions.indexWhere((s) => s.id == subscriptionId);
    if (subIdx == -1) throw Exception('Subscription not found');
    final sub = MockData.subscriptions[subIdx];

    final holdStart = sub.holdFrom ?? resumeDate;
    final heldDays = resumeDate.difference(holdStart).inDays;
    final shiftedEndDate = sub.endDate.add(Duration(days: heldDays > 0 ? heldDays : 0));

    MockData.subscriptions[subIdx] = SubscriptionModel(
      id: sub.id,
      clientId: sub.clientId,
      planId: sub.planId,
      startDate: sub.startDate,
      endDate: shiftedEndDate,
      totalSessions: sub.totalSessions,
      status: 'active',
      holdFrom: null,
      baselineDueDate: sub.baselineDueDate,
      finalAssessmentDue: sub.finalAssessmentDue,
      createdAt: sub.createdAt,
      updatedAt: DateTime.now(),
      createdBy: sub.createdBy,
    );

    final slotIdx = MockData.slots.indexWhere((s) => s.subscriptionId == subscriptionId);
    if (slotIdx != -1) {
      final oldSlot = MockData.slots[slotIdx];
      MockData.slots[slotIdx] = SlotModel(
        id: oldSlot.id,
        subscriptionId: oldSlot.subscriptionId,
        clientId: oldSlot.clientId,
        trainerId: oldSlot.trainerId,
        hourStart: oldSlot.hourStart,
        pattern: oldSlot.pattern,
        validFrom: resumeDate,
        validTo: shiftedEndDate,
        createdAt: oldSlot.createdAt,
      );
    }

    _updateClientStatus(sub.clientId, 'active');
    _writeAuditLog(actorId: actorId, tableName: 'subscriptions', recordId: subscriptionId, field: 'status', newValue: 'active');
  }

  Future<void> changeSlot({
    required String subscriptionId,
    required String newTrainerId,
    required int newHourStart,
    required String newPattern,
    required DateTime effectiveDate,
    required String actorId,
  }) async {
    final sub = MockData.subscriptions.where((s) => s.id == subscriptionId).firstOrNull;
    if (sub == null) throw Exception('Subscription not found');

    checkSlot(
      trainerId: newTrainerId,
      hourStart: newHourStart,
      newPattern: newPattern,
      excludeSubscriptionId: subscriptionId,
    );

    final slotIdx = MockData.slots.indexWhere((s) => s.subscriptionId == subscriptionId);
    if (slotIdx != -1) {
      final oldSlot = MockData.slots[slotIdx];
      MockData.slots[slotIdx] = SlotModel(
        id: oldSlot.id,
        subscriptionId: oldSlot.subscriptionId,
        clientId: oldSlot.clientId,
        trainerId: oldSlot.trainerId,
        hourStart: oldSlot.hourStart,
        pattern: oldSlot.pattern,
        validFrom: oldSlot.validFrom,
        validTo: effectiveDate.subtract(const Duration(days: 1)),
        createdAt: oldSlot.createdAt,
      );
    }

    MockData.slots.insert(0, SlotModel(
      id: 'slot-${DateTime.now().millisecondsSinceEpoch}',
      subscriptionId: subscriptionId,
      clientId: sub.clientId,
      trainerId: newTrainerId,
      hourStart: newHourStart,
      pattern: newPattern,
      validFrom: effectiveDate,
      validTo: sub.endDate,
      createdAt: DateTime.now(),
    ));

    final clientIdx = MockData.clients.indexWhere((c) => c.id == sub.clientId);
    if (clientIdx != -1) {
      MockData.clients[clientIdx] = MockData.clients[clientIdx].copyWith(trainerId: newTrainerId);
    }

    _writeAuditLog(actorId: actorId, tableName: 'slots', recordId: subscriptionId, field: 'slot_change', newValue: '$newPattern @ $newHourStart:00');
  }

  Future<void> assignNutritionist({
    required String clientId,
    String? nutritionistId,
    required String actorId,
  }) async {
    final clientIdx = MockData.clients.indexWhere((c) => c.id == clientId);
    if (clientIdx != -1) {
      final oldNut = MockData.clients[clientIdx].nutritionistId;
      MockData.clients[clientIdx] = MockData.clients[clientIdx].copyWith(nutritionistId: nutritionistId);
      _writeAuditLog(actorId: actorId, tableName: 'clients', recordId: clientId, field: 'nutritionist_id', oldValue: oldNut, newValue: nutritionistId);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 6. reassign_clients & trainer handover (Workflow J)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> reassignClients({
    required String fromTrainerId,
    required String toTrainerId,
    required List<String> clientIds,
    required String handoverNote,
    required String actorId,
  }) async {
    // Verify slot for every client before executing
    for (final cid in clientIds) {
      final slot = MockData.slots.where((s) => s.clientId == cid && s.trainerId == fromTrainerId).firstOrNull;
      if (slot != null) {
        checkSlot(
          trainerId: toTrainerId,
          hourStart: slot.hourStart,
          newPattern: slot.pattern,
          excludeSubscriptionId: slot.subscriptionId,
        );
      }
    }

    // Execute reassignment
    for (final cid in clientIds) {
      // 1. Update client.trainerId
      final cIdx = MockData.clients.indexWhere((c) => c.id == cid);
      if (cIdx != -1) {
        MockData.clients[cIdx] = MockData.clients[cIdx].copyWith(trainerId: toTrainerId);
      }

      // 2. Move slot row
      final sIdx = MockData.slots.indexWhere((s) => s.clientId == cid && s.trainerId == fromTrainerId);
      if (sIdx != -1) {
        final oldSlot = MockData.slots[sIdx];
        MockData.slots[sIdx] = SlotModel(
          id: 'slot-${DateTime.now().millisecondsSinceEpoch}',
          subscriptionId: oldSlot.subscriptionId,
          clientId: cid,
          trainerId: toTrainerId,
          hourStart: oldSlot.hourStart,
          pattern: oldSlot.pattern,
          validFrom: DateTime.now(),
          validTo: oldSlot.validTo,
          createdAt: DateTime.now(),
        );
      }

      // 3. Record handover
      MockData.trainerHandovers.insert(0, TrainerHandoverModel(
        id: 'ho-${DateTime.now().millisecondsSinceEpoch}',
        clientId: cid,
        fromTrainerId: fromTrainerId,
        toTrainerId: toTrainerId,
        note: handoverNote,
        at: DateTime.now(),
      ));

      _writeAuditLog(actorId: actorId, tableName: 'clients', recordId: cid, field: 'trainer_id', oldValue: fromTrainerId, newValue: toTrainerId);
    }

    _createNotification(
      userId: toTrainerId,
      type: 'client_reassigned',
      title: 'Clients Reassigned to You',
      body: '${clientIds.length} client(s) moved to your roster. Note: $handoverNote',
    );
    _createNotification(
      userId: fromTrainerId,
      type: 'client_reassigned',
      title: 'Clients Handed Over',
      body: '${clientIds.length} client(s) transferred to another trainer.',
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 7. create_staff, reset_staff_password, deactivate_staff (Section 20.1)
  // ──────────────────────────────────────────────────────────────────────────
  Future<UserModel> createStaff({
    required String name,
    required String role,
    required String phone,
    String? email,
    required String userId,
    required String password,
    String? shiftStart,
    String? shiftEnd,
    int? weeklyOff,
    required String actorId,
  }) async {
    final newUser = UserModel(
      id: 'staff-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      name: name,
      phone: phone,
      email: email,
      role: role,
      active: true,
      shiftStart: shiftStart ?? '06:00',
      shiftEnd: shiftEnd ?? '14:00',
      weeklyOffDay: weeklyOff,
      mustChangePassword: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    MockData.allStaff.add(newUser);
    MockData.staffPasswords[newUser.id] = password;
    MockData.staffPasswords[newUser.userId.toLowerCase()] = password;
    if (role == 'trainer') {
      MockData.trainers.add(newUser);
    }

    _writeAuditLog(actorId: actorId, tableName: 'users', recordId: newUser.id, field: 'status', newValue: 'created');
    return newUser;
  }

  Future<void> resetStaffPassword({
    required String userId,
    required String newPassword,
    required String actorId,
  }) async {
    final uIdx = MockData.allStaff.indexWhere((u) => u.id == userId);
    if (uIdx != -1) {
      final user = MockData.allStaff[uIdx];
      MockData.allStaff[uIdx] = user.copyWith(mustChangePassword: true);
      MockData.staffPasswords[user.id] = newPassword;
      MockData.staffPasswords[user.userId.toLowerCase()] = newPassword;
    }
    _writeAuditLog(actorId: actorId, tableName: 'users', recordId: userId, field: 'password', newValue: 'reset');
  }

  Future<void> deactivateStaff({required String userId, required String actorId}) async {
    final activeClientsCount = MockData.clients.where((c) => c.trainerId == userId && c.status == 'active').length;
    if (activeClientsCount > 0) {
      throw BusinessException.hasActiveClients;
    }

    final uIdx = MockData.allStaff.indexWhere((u) => u.id == userId);
    if (uIdx != -1) {
      MockData.allStaff[uIdx] = MockData.allStaff[uIdx].copyWith(active: false);
    }
    MockData.trainers.removeWhere((t) => t.id == userId);

    _writeAuditLog(actorId: actorId, tableName: 'users', recordId: userId, field: 'active', newValue: 'false');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 8. Staff Attendance & Affected Sessions (Workflow H & I)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> markStaffAttendance({
    required String userId,
    required DateTime date,
    required String status,
    String? inTime,
    String? outTime,
    String? note,
    required String markedBy,
  }) async {
    final user = MockData.allStaff.where((u) => u.id == userId).firstOrNull;
    bool lateFlag = false;

    if (inTime != null && user != null && user.shiftStart != null) {
      final shiftParts = user.shiftStart!.split(':');
      final inParts = inTime.split(':');
      final shiftMin = int.parse(shiftParts[0]) * 60 + int.parse(shiftParts[1]);
      final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
      if (inMin > (shiftMin + user.graceMinutes)) {
        lateFlag = true;
      }
    }

    final dateStr = date.toIso8601String().split('T')[0];
    final existingIdx = MockData.staffAttendance.indexWhere(
      (s) => s.userId == userId && s.date.toIso8601String().split('T')[0] == dateStr,
    );

    final record = StaffAttendanceModel(
      id: existingIdx != -1 ? MockData.staffAttendance[existingIdx].id : 'sa-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      date: date,
      status: status,
      inTime: inTime,
      outTime: outTime,
      lateFlag: lateFlag,
      note: note,
      markedBy: markedBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (existingIdx != -1) {
      MockData.staffAttendance[existingIdx] = record;
    } else {
      MockData.staffAttendance.insert(0, record);
    }

    // Workflow I: If trainer is absent, build affected sessions
    if ((status == 'absent' || status == 'leave') && (user?.role == 'trainer')) {
      final affected = getAffectedSessions(trainerId: userId, date: date);
      if (affected.isNotEmpty) {
        _createNotification(
          userId: 'admin-01',
          type: 'trainer_absent_impact',
          title: 'Trainer Absent: Action Required',
          body: '${user?.name} is marked $status. ${affected.length} client session(s) affected today.',
          payload: {'trainer_id': userId, 'date': dateStr, 'affected_count': affected.length},
        );
      }
    }
  }

  /// Affected sessions on date D for an absent trainer (Section 21.2)
  List<ClientModel> getAffectedSessions({required String trainerId, required DateTime date}) {
    final weekday = date.weekday;
    final dateOnly = DateTime(date.year, date.month, date.day);

    final affectedClients = <ClientModel>[];
    for (final client in MockData.clients.where((c) => c.trainerId == trainerId && c.status == 'active')) {
      final slot = MockData.slots.where((s) => s.clientId == client.id && s.trainerId == trainerId).firstOrNull;
      if (slot != null) {
        final days = patternDays[slot.pattern] ?? {};
        if (days.contains(weekday) && !slot.validFrom.isAfter(dateOnly) && !slot.validTo.isBefore(dateOnly)) {
          affectedClients.add(client);
        }
      }
    }
    return affectedClients;
  }

  /// Reassign a session for the day only (Workflow I)
  Future<void> reassignSessionForDay({
    required String clientId,
    required DateTime date,
    required String substituteTrainerId,
    required int hourStart,
    required String createdBy,
  }) async {
    MockData.sessionOverrides.insert(0, SessionOverrideModel(
      id: 'so-${DateTime.now().millisecondsSinceEpoch}',
      clientId: clientId,
      date: date,
      trainerId: substituteTrainerId,
      hourStart: hourStart,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    ));

    final client = MockData.clients.where((c) => c.id == clientId).firstOrNull;
    _createNotification(
      userId: substituteTrainerId,
      type: 'substitute_session',
      title: 'Session Override Today',
      body: 'You have been assigned ${client?.fullName ?? "Client"} for workout today at $hourStart:00.',
    );
  }

  /// Cancel sessions for absent trainer (Workflow I - Cancel by gym uses 0 sessions)
  Future<void> cancelSessionsForTrainer({required String trainerId, required DateTime date, required String markedBy}) async {
    final affected = getAffectedSessions(trainerId: trainerId, date: date);
    for (final client in affected) {
      await markAttendance(
        clientId: client.id,
        date: date,
        status: 'cancelled',
        note: 'Cancelled by gym: trainer absent',
        callerId: markedBy,
        callerRole: 'admin',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 9. save_assessment (Workflow F)
  // ──────────────────────────────────────────────────────────────────────────
  Future<AssessmentModel> saveAssessment({
    required String clientId,
    required String subscriptionId,
    required String type, // baseline, final, checkpoint
    required Map<String, dynamic> rawInputs,
    String? remarks,
    required String assessedBy,
  }) async {
    // Only one baseline and one final per subscription
    if (type == 'baseline' && MockData.assessments.any((a) => a.subscriptionId == subscriptionId && a.type == 'baseline')) {
      throw const BusinessException('BASELINE_EXISTS', 'A baseline assessment already exists for this subscription');
    }
    if (type == 'final' && MockData.assessments.any((a) => a.subscriptionId == subscriptionId && a.type == 'final')) {
      throw const BusinessException('FINAL_EXISTS', 'A final assessment already exists for this subscription');
    }

    final client = MockData.clients.where((c) => c.id == clientId).firstOrNull;
    if (client == null) throw Exception('Client not found');

    final now = DateTime.now();
    final weightKg = (rawInputs['weight_kg'] as num?)?.toDouble() ?? 70.0;
    final heightCm = (rawInputs['height_cm'] as num?)?.toDouble() ?? 170.0;
    final age = client.age;
    final gender = client.gender;

    // Rockport decimal minutes conversion
    final rockportTimeStr = rawInputs['rockport_time'] as String? ?? '14:00';
    final rockportMinutes = FitnessFormulas.parseTimeToMinutes(rockportTimeStr);
    final rockportPulse = (rawInputs['rockport_pulse'] as num?)?.toInt() ?? 140;

    final vo2 = FitnessFormulas.vo2max(
      weightKg: weightKg,
      age: age,
      gender: gender,
      timeMinutes: rockportMinutes,
      heartRate: rockportPulse,
    );

    // Body fat US Navy
    final waist = (rawInputs['waist_widest'] as num?)?.toDouble() ?? 80.0;
    final neck = (rawInputs['neck'] as num?)?.toDouble() ?? 38.0;
    final hip = (rawInputs['hip'] as num?)?.toDouble() ?? 95.0;

    final bfPercent = gender.toLowerCase() == 'male'
        ? FitnessFormulas.bodyFatPercentMale(waistCm: waist, neckCm: neck, heightCm: heightCm)
        : FitnessFormulas.bodyFatPercentFemale(waistCm: waist, hipCm: hip, neckCm: neck, heightCm: heightCm);

    // Proprietary FS-7 Fitness Score (0 - 100)
    final fs7Score = _calculateFS7Score(
      bmi: FitnessFormulas.calculateBMI(weightKg, heightCm),
      bodyFatPercent: bfPercent,
      vo2max: vo2,
      pushups: (rawInputs['pushups_count'] as num?)?.toInt() ?? 15,
      systolic: (rawInputs['systolic'] as num?)?.toInt() ?? 120,
    );

    // Freeze snapshot
    final calculatedSnapshot = {
      'bmi': FitnessFormulas.calculateBMI(weightKg, heightCm),
      'bmi_category': FitnessFormulas.bmiCategory(FitnessFormulas.calculateBMI(weightKg, heightCm)),
      'body_fat_percent': bfPercent,
      'body_fat_category': FitnessFormulas.bodyFatCategory(bfPercent, gender),
      'vo2max': vo2,
      'vo2max_category': FitnessFormulas.vo2maxCategory(vo2, age, gender),
      'fs7_score': fs7Score,
      'fat_mass_kg': FitnessFormulas.fatMass(weightKg, bfPercent),
      'lean_mass_kg': FitnessFormulas.leanMass(weightKg, FitnessFormulas.fatMass(weightKg, bfPercent)),
      'waist_to_hip_ratio': FitnessFormulas.waistToHipRatio(waist, hip),
      'calculated_at': now.toIso8601String(),
    };

    final assessment = AssessmentModel(
      id: 'ass-${DateTime.now().millisecondsSinceEpoch}',
      clientId: clientId,
      subscriptionId: subscriptionId,
      type: type,
      testDate: now,
      weightKg: weightKg,
      heightCm: heightCm,
      goal: rawInputs['goal'] as String?,
      restingHeartRate: (rawInputs['resting_heart_rate'] as num?)?.toInt(),
      systolic: (rawInputs['systolic'] as num?)?.toInt(),
      diastolic: (rawInputs['diastolic'] as num?)?.toInt(),
      neck: neck,
      waistWidest: waist,
      hip: hip,
      rockportTime: rockportTimeStr,
      rockportPulse: rockportPulse,
      pushupsCount: (rawInputs['pushups_count'] as num?)?.toInt(),
      trainerRemarks: remarks,
      fs7Score: fs7Score,
      calculatedJson: calculatedSnapshot,
      createdAt: now,
      updatedAt: now,
      createdBy: assessedBy,
    );

    MockData.assessments.insert(0, assessment);

    // Clear due flag
    if (type == 'final') {
      final sIdx = MockData.subscriptions.indexWhere((s) => s.id == subscriptionId);
      if (sIdx != -1) {
        final sub = MockData.subscriptions[sIdx];
        MockData.subscriptions[sIdx] = SubscriptionModel(
          id: sub.id, clientId: sub.clientId, planId: sub.planId,
          startDate: sub.startDate, endDate: sub.endDate,
          totalSessions: sub.totalSessions, status: sub.status,
          baselineDueDate: sub.baselineDueDate, finalAssessmentDue: false,
          createdAt: sub.createdAt, updatedAt: DateTime.now(), createdBy: sub.createdBy,
        );
      }
    }

    _writeAuditLog(actorId: assessedBy, tableName: 'assessments', recordId: assessment.id, field: 'type', newValue: type);

    return assessment;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 10. Inquiries CRM Pipeline (Workflow G)
  // ──────────────────────────────────────────────────────────────────────────
  Future<InquiryModel> createInquiry({required Map<String, dynamic> data, required String createdBy}) async {
    final phone = data['phone'] as String? ?? '';
    if (MockData.inquiries.any((i) => i.phone == phone && i.isOpen)) {
      throw BusinessException.phoneExists;
    }

    final inqDate = DateTime.tryParse(data['inquiry_date'] ?? '') ?? DateTime.now();
    final nextDate = DateTime.tryParse(data['next_followup_date'] ?? '') ?? inqDate.add(const Duration(days: 1));

    final inquiry = InquiryModel(
      id: 'inq-${DateTime.now().millisecondsSinceEpoch}',
      name: data['name'] ?? '',
      phone: phone,
      sourceId: data['source_id'] ?? 'Walk-in',
      referenceName: data['reference_name'],
      inquiryDate: inqDate,
      lastFollowupDate: inqDate,
      nextFollowupDate: nextDate,
      nextFollowupTime: data['next_followup_time'],
      interestedIn: data['interested_in'],
      preferredTime: data['preferred_time'],
      preferredPattern: data['preferred_pattern'],
      status: 'new',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );

    MockData.inquiries.insert(0, inquiry);
    _writeAuditLog(actorId: createdBy, tableName: 'inquiries', recordId: inquiry.id, field: 'status', newValue: 'new');

    return inquiry;
  }

  Future<void> logFollowup({
    required String inquiryId,
    required String outcome,
    required String remarks,
    required String loggedBy,
    DateTime? nextFollowupDate,
    String? nextFollowupTime,
  }) async {
    final inqIdx = MockData.inquiries.indexWhere((i) => i.id == inquiryId);
    if (inqIdx == -1) return;

    final inq = MockData.inquiries[inqIdx];
    final now = DateTime.now();

    MockData.inquiryFollowups.insert(0, InquiryFollowupModel(
      id: 'fup-${DateTime.now().millisecondsSinceEpoch}',
      inquiryId: inquiryId,
      followupAt: now,
      outcome: outcome,
      remarks: remarks,
      nextFollowupDate: nextFollowupDate,
      nextFollowupTime: nextFollowupTime,
      loggedBy: loggedBy,
      createdAt: now,
    ));

    String nextStatus = inq.status;
    if (outcome == 'Converted') {
      nextStatus = 'converted';
    } else if (outcome == 'Not interested') {
      nextStatus = 'not_interested';
    } else {
      nextStatus = 'follow_up';
    }

    MockData.inquiries[inqIdx] = InquiryModel(
      id: inq.id,
      name: inq.name,
      phone: inq.phone,
      sourceId: inq.sourceId,
      referenceName: inq.referenceName,
      inquiryDate: inq.inquiryDate,
      lastFollowupDate: now,
      nextFollowupDate: nextFollowupDate ?? inq.nextFollowupDate,
      nextFollowupTime: nextFollowupTime,
      interestedIn: inq.interestedIn,
      preferredTime: inq.preferredTime,
      preferredPattern: inq.preferredPattern,
      status: nextStatus,
      lostReason: outcome == 'Not interested' ? remarks : inq.lostReason,
      createdAt: inq.createdAt,
      updatedAt: now,
      createdBy: inq.createdBy,
    );

    if (nextStatus == 'converted' || nextStatus == 'not_interested') {
      for (int i = 0; i < MockData.notifications.length; i++) {
        final n = MockData.notifications[i];
        if (n.payload?['inquiry_id'] == inquiryId) {
          MockData.notifications[i] = n.copyWith(cancelled: true);
        }
      }
    }

    _writeAuditLog(actorId: loggedBy, tableName: 'inquiry_followups', recordId: inquiryId, field: 'outcome', newValue: outcome);
  }

  Future<void> closeInquiry({required String inquiryId, required String reason, required String status, required String actorId}) async {
    final inqIdx = MockData.inquiries.indexWhere((i) => i.id == inquiryId);
    if (inqIdx == -1) return;
    final inq = MockData.inquiries[inqIdx];

    MockData.inquiries[inqIdx] = inq.copyWith(
      status: status,
      lostReason: reason,
      updatedAt: DateTime.now(),
    );

    // Cancel pending notification reminders
    for (int i = 0; i < MockData.notifications.length; i++) {
      final n = MockData.notifications[i];
      if (n.payload?['inquiry_id'] == inquiryId) {
        MockData.notifications[i] = n.copyWith(cancelled: true);
      }
    }

    _writeAuditLog(actorId: actorId, tableName: 'inquiries', recordId: inquiryId, field: 'status', newValue: status);
  }

  Future<void> reopenInquiry({required String inquiryId, required String actorId}) async {
    final inqIdx = MockData.inquiries.indexWhere((i) => i.id == inquiryId);
    if (inqIdx == -1) return;
    final inq = MockData.inquiries[inqIdx];

    MockData.inquiries[inqIdx] = inq.copyWith(
      status: 'follow_up',
      lostReason: null,
      nextFollowupDate: DateTime.now().add(const Duration(days: 1)),
      updatedAt: DateTime.now(),
    );

    _writeAuditLog(actorId: actorId, tableName: 'inquiries', recordId: inquiryId, field: 'status', newValue: 'follow_up');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private helper utilities
  // ──────────────────────────────────────────────────────────────────────────
  void _updateClientStatus(String clientId, String status) {
    final idx = MockData.clients.indexWhere((c) => c.id == clientId);
    if (idx != -1) {
      MockData.clients[idx] = MockData.clients[idx].copyWith(status: status);
    }
  }

  void _updateClientConsecutiveAbsences(String clientId, int count) {
    final idx = MockData.clients.indexWhere((c) => c.id == clientId);
    if (idx != -1) {
      final c = MockData.clients[idx];
      MockData.clients[idx] = ClientModel(
        id: c.id, firstName: c.firstName, lastName: c.lastName, address: c.address,
        dob: c.dob, gender: c.gender, phonePrimary: c.phonePrimary, phoneSecondary: c.phoneSecondary,
        email: c.email, photoUrl: c.photoUrl, programType: c.programType, paymentMethod: c.paymentMethod,
        trainerId: c.trainerId, nutritionistId: c.nutritionistId, status: c.status,
        sourceInquiryId: c.sourceInquiryId, emergencyFirstName: c.emergencyFirstName,
        emergencyLastName: c.emergencyLastName, emergencyAddress: c.emergencyAddress,
        emergencyPhone: c.emergencyPhone, consecutiveAbsences: count, archived: c.archived,
        createdAt: c.createdAt, updatedAt: DateTime.now(), createdBy: c.createdBy,
      );
    }
  }

  void _closeSubscriptionAndSlot(SubscriptionModel sub, DateTime closeDate, String finalStatus, {String? reason}) {
    final subIdx = MockData.subscriptions.indexWhere((s) => s.id == sub.id);
    if (subIdx != -1) {
      MockData.subscriptions[subIdx] = SubscriptionModel(
        id: sub.id, clientId: sub.clientId, planId: sub.planId,
        startDate: sub.startDate, endDate: sub.endDate,
        extensionEndDate: sub.extensionEndDate, totalSessions: sub.totalSessions,
        status: finalStatus, deactivationReason: reason,
        createdAt: sub.createdAt, updatedAt: DateTime.now(), createdBy: sub.createdBy,
      );
    }
    // Remove slots associated with this subscription or client so seats are released
    MockData.slots.removeWhere((slot) => slot.subscriptionId == sub.id || slot.clientId == sub.clientId);
    _updateClientStatus(sub.clientId, finalStatus);
  }

  void _writeAuditLog({required String actorId, required String tableName, required String recordId, required String field, String? oldValue, String? newValue}) {
    MockData.auditLogs.insert(0, AuditLogModel(
      id: 'log-${DateTime.now().millisecondsSinceEpoch}',
      actorId: actorId,
      tableName: tableName,
      recordId: recordId,
      field: field,
      oldValue: oldValue,
      newValue: newValue,
      at: DateTime.now(),
    ));
  }

  void _createNotification({required String userId, required String type, required String title, required String body, Map<String, dynamic>? payload}) {
    MockData.notifications.insert(0, AppNotificationModel(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      type: type,
      title: title,
      body: body,
      payload: payload,
      scheduledFor: DateTime.now(),
      createdAt: DateTime.now(),
    ));
  }

  double _calculateFS7Score({required double bmi, required double bodyFatPercent, required double vo2max, required int pushups, required int systolic}) {
    // 100-point balanced composite: Cardio 30%, Strength 25%, Composition 25%, Vitals 20%
    double cardio = (vo2max / 50.0).clamp(0.0, 1.0) * 30.0;
    double strength = (pushups / 35.0).clamp(0.0, 1.0) * 25.0;
    double comp = bodyFatPercent > 0 ? ((28.0 - bodyFatPercent) / 15.0).clamp(0.0, 1.0) * 25.0 : 15.0;
    double vitals = systolic <= 120 ? 20.0 : ((160 - systolic) / 40.0).clamp(0.0, 1.0) * 20.0;
    return (cardio + strength + comp + vitals).clamp(10.0, 99.0);
  }
}

final serverFunctionsServiceProvider = Provider<ServerFunctionsService>((ref) {
  return ServerFunctionsService(Supabase.instance.client);
});
