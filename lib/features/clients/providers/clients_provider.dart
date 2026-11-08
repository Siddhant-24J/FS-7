import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/mock/mock_data.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/plan_model.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/assessment_model.dart';
import '../../../core/services/server_functions_service.dart';
import '../../../core/services/local_cache_service.dart';

final clientsProvider = FutureProvider<List<ClientModel>>((ref) async {
  if (!SupabaseConstants.isConfigured) {
    final cached = await LocalCacheService.load('clients');
    if (cached is List && cached.isNotEmpty) {
      return cached.map((j) => ClientModel.fromJson(j)).toList();
    }
    return List<ClientModel>.from(MockData.clients);
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.clientsTable)
        .select()
        .eq('archived', false)
        .order('first_name');
    final list = (res as List).map((j) => ClientModel.fromJson(j)).toList();
    await LocalCacheService.save('clients', res);
    return list.isEmpty ? List<ClientModel>.from(MockData.clients) : list;
  } catch (_) {
    final cached = await LocalCacheService.load('clients');
    if (cached is List && cached.isNotEmpty) {
      return cached.map((j) => ClientModel.fromJson(j)).toList();
    }
    return List<ClientModel>.from(MockData.clients);
  }
});

final clientProvider = FutureProvider.family<ClientModel?, String>((ref, clientId) async {
  if (!SupabaseConstants.isConfigured) {
    return MockData.clients.where((c) => c.id == clientId).firstOrNull;
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.clientsTable)
        .select()
        .eq('id', clientId)
        .maybeSingle();
    if (res == null) {
      return MockData.clients.where((c) => c.id == clientId).firstOrNull;
    }
    return ClientModel.fromJson(res);
  } catch (_) {
    return MockData.clients.where((c) => c.id == clientId).firstOrNull;
  }
});

final clientSubscriptionsProvider = FutureProvider.family<List<SubscriptionModel>, String>((ref, clientId) async {
  if (!SupabaseConstants.isConfigured) {
    return MockData.subscriptions.where((s) => s.clientId == clientId).toList();
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.subscriptionsTable)
        .select()
        .eq('client_id', clientId)
        .order('start_date', ascending: false);
    return (res as List).map((j) => SubscriptionModel.fromJson(j)).toList();
  } catch (_) {
    return MockData.subscriptions.where((s) => s.clientId == clientId).toList();
  }
});

final activeSubscriptionProvider = FutureProvider.family<SubscriptionModel?, String>((ref, clientId) async {
  if (!SupabaseConstants.isConfigured) {
    return MockData.subscriptions.where((s) => s.clientId == clientId && (s.isActive || s.isExtended || s.isHold)).firstOrNull;
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.subscriptionsTable)
        .select()
        .eq('client_id', clientId)
        .inFilter('status', ['active', 'extended', 'hold'])
        .order('start_date', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return MockData.subscriptions.where((s) => s.clientId == clientId && (s.isActive || s.isExtended || s.isHold)).firstOrNull;
    return SubscriptionModel.fromJson(res);
  } catch (_) {
    return MockData.subscriptions.where((s) => s.clientId == clientId && (s.isActive || s.isExtended || s.isHold)).firstOrNull;
  }
});

final clientAttendanceProvider = FutureProvider.family<List<AttendanceModel>, String>((ref, subscriptionId) async {
  if (!SupabaseConstants.isConfigured) {
    return MockData.attendance.where((a) => a.subscriptionId == subscriptionId).toList();
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.attendanceTable)
        .select()
        .eq('subscription_id', subscriptionId)
        .order('date', ascending: false);
    return (res as List).map((j) => AttendanceModel.fromJson(j)).toList();
  } catch (_) {
    return MockData.attendance.where((a) => a.subscriptionId == subscriptionId).toList();
  }
});

final clientAssessmentsProvider = FutureProvider.family<List<AssessmentModel>, String>((ref, clientId) async {
  if (!SupabaseConstants.isConfigured) {
    return MockData.assessments.where((a) => a.clientId == clientId).toList();
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.assessmentsTable)
        .select()
        .eq('client_id', clientId)
        .order('test_date', ascending: false);
    return (res as List).map((j) => AssessmentModel.fromJson(j)).toList();
  } catch (_) {
    return MockData.assessments.where((a) => a.clientId == clientId).toList();
  }
});

// All plans
final plansProvider = FutureProvider<List<PlanModel>>((ref) async {
  final fallbackPlans = PlanModel.defaultPlans;

  if (!SupabaseConstants.isConfigured) {
    return fallbackPlans;
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.plansTable)
        .select()
        .eq('active', true)
        .order('months');
    final list = (res as List).map((j) => PlanModel.fromJson(j)).toList();
    return list.isEmpty ? fallbackPlans : list;
  } catch (_) {
    return fallbackPlans;
  }
});

// Repository methods for mutations
class ClientRepository {
  final SupabaseClient _client;
  final ServerFunctionsService _service;

  ClientRepository(this._client, this._service);

  Future<ClientModel> createClient({
    required Map<String, dynamic> data,
    required String createdBy,
  }) async {
    final newId = 'client-${DateTime.now().millisecondsSinceEpoch}';

    final newClient = ClientModel(
      id: newId,
      firstName: data['first_name'] ?? '',
      lastName: data['last_name'] ?? '',
      phonePrimary: data['phone_primary'] ?? '',
      phoneSecondary: data['phone_secondary'],
      email: data['email'],
      gender: data['gender'] ?? 'male',
      dob: DateTime.tryParse(data['dob'] ?? '') ?? DateTime(1995, 1, 1),
      programType: data['program_type'] ?? 'General Fitness',
      paymentMethod: data['payment_method'] ?? 'UPI',
      trainerId: data['trainer_id'] ?? 'trainer-01',
      nutritionistId: data['nutritionist_id'],
      status: 'active',
      emergencyFirstName: data['emergency_first_name'] ?? 'Contact',
      emergencyLastName: data['emergency_last_name'] ?? 'Person',
      emergencyPhone: data['emergency_phone'] ?? (data['phone_primary'] ?? ''),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );

    MockData.clients.insert(0, newClient);

    try {
      if (SupabaseConstants.isConfigured) {
        final res = await _client.from(SupabaseConstants.clientsTable).insert({
          ...data,
          'created_by': createdBy,
        }).select().single();
        return ClientModel.fromJson(res);
      }
    } catch (_) {}

    return newClient;
  }

  Future<SubscriptionModel> createSubscription({
    required String clientId,
    required String planId,
    required DateTime startDate,
    required DateTime endDate,
    required int totalSessions,
    required String createdBy,
  }) async {
    final newSub = SubscriptionModel(
      id: 'sub-${DateTime.now().millisecondsSinceEpoch}',
      clientId: clientId,
      planId: planId,
      startDate: startDate,
      endDate: endDate,
      totalSessions: totalSessions,
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );
    MockData.subscriptions.insert(0, newSub);

    try {
      if (SupabaseConstants.isConfigured) {
        final res = await _client.from(SupabaseConstants.subscriptionsTable).insert({
          'client_id': clientId,
          'plan_id': planId,
          'start_date': startDate.toIso8601String().split('T')[0],
          'end_date': endDate.toIso8601String().split('T')[0],
          'total_sessions': totalSessions,
          'status': 'active',
          'created_by': createdBy,
        }).select().single();
        return SubscriptionModel.fromJson(res);
      }
    } catch (_) {}

    return newSub;
  }

  Future<void> deactivateClient({
    required String clientId,
    String? subscriptionId,
    required String reason,
    required String actorId,
  }) async {
    // 1. Process server function
    await _service.deactivateClient(clientId: clientId, reason: reason, actorId: actorId);

    // 2. Direct MockData update to guarantee instant UI reflection
    final cIdx = MockData.clients.indexWhere((c) => c.id == clientId);
    if (cIdx != -1) {
      MockData.clients[cIdx] = MockData.clients[cIdx].copyWith(status: 'deactivated');
    }
    MockData.slots.removeWhere((s) => s.clientId == clientId || (subscriptionId != null && s.subscriptionId == subscriptionId));

    // 3. Supabase persistence if connected
    if (SupabaseConstants.isConfigured) {
      try {
        await _client.from(SupabaseConstants.clientsTable).update({
          'status': 'deactivated',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', clientId);

        if (subscriptionId != null && subscriptionId.isNotEmpty) {
          await _client.from(SupabaseConstants.subscriptionsTable).update({
            'status': 'deactivated',
            'deactivation_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', subscriptionId);
        }

        final yesterdayStr = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T')[0];
        await _client.from(SupabaseConstants.slotsTable).update({
          'valid_to': yesterdayStr,
        }).eq('client_id', clientId);
      } catch (_) {}
    }
  }

  Future<void> holdSubscription({
    required String subscriptionId,
    required DateTime holdFrom,
    required bool releaseSlot,
    required String actorId,
  }) async {
    await _service.holdSubscription(
      subscriptionId: subscriptionId,
      holdFrom: holdFrom,
      releaseSlot: releaseSlot,
      actorId: actorId,
    );
  }

  Future<void> resumeSubscription({
    required String subscriptionId,
    required DateTime resumeDate,
    required String actorId,
  }) async {
    await _service.resumeSubscription(
      subscriptionId: subscriptionId,
      resumeDate: resumeDate,
      actorId: actorId,
    );
  }

  Future<void> changeSlot({
    required String subscriptionId,
    required String newTrainerId,
    required int newHourStart,
    required String newPattern,
    required DateTime effectiveDate,
    required String actorId,
  }) async {
    await _service.changeSlot(
      subscriptionId: subscriptionId,
      newTrainerId: newTrainerId,
      newHourStart: newHourStart,
      newPattern: newPattern,
      effectiveDate: effectiveDate,
      actorId: actorId,
    );
  }

  Future<SubscriptionModel> renewSubscription({
    required String clientId,
    required String planId,
    required DateTime startDate,
    required int hourStart,
    required String pattern,
    required String trainerId,
    required String createdBy,
  }) async {
    return await _service.renewSubscription(
      clientId: clientId,
      planId: planId,
      startDate: startDate,
      hourStart: hourStart,
      pattern: pattern,
      trainerId: trainerId,
      createdBy: createdBy,
    );
  }

  Future<void> createSlot({
    required String subscriptionId,
    required String clientId,
    required String trainerId,
    required int hourStart,
    required String pattern,
    required DateTime validFrom,
    required DateTime validTo,
  }) async {
    final slot = SlotModel(
      id: 'slot-${DateTime.now().millisecondsSinceEpoch}',
      subscriptionId: subscriptionId,
      clientId: clientId,
      trainerId: trainerId,
      hourStart: hourStart,
      pattern: pattern,
      validFrom: validFrom,
      validTo: validTo,
      createdAt: DateTime.now(),
    );
    MockData.slots.insert(0, slot);
  }

  Future<void> markAttendance({
    required String subscriptionId,
    required String clientId,
    required DateTime date,
    required String status,
    required String markedBy,
    String callerRole = 'admin',
    String? note,
  }) async {
    await _service.markAttendance(
      clientId: clientId,
      date: date,
      status: status,
      note: note,
      callerId: markedBy,
      callerRole: callerRole,
    );
  }

  Future<void> applyLeave({
    required String clientId,
    required String subscriptionId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required String appliedBy,
  }) async {
    try {
      await _client.from(SupabaseConstants.notesTable).insert({
        'client_id': clientId,
        'type': 'leave',
        'content': 'Leave applied from $startDate to $endDate. Reason: $reason',
        'created_by': appliedBy,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> updateExtension({
    required String subscriptionId,
    required int additionalDays,
    required String reason,
  }) async {
    try {
      await _client.rpc('apply_subscription_extension', params: {
        'p_subscription_id': subscriptionId,
        'p_days': additionalDays,
        'p_reason': reason,
      });
    } catch (_) {}
  }
}

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final service = ref.watch(serverFunctionsServiceProvider);
  return ClientRepository(Supabase.instance.client, service);
});
