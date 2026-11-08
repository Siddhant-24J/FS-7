import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/mock/mock_data.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/plan_model.dart';
import '../../../data/models/client_model.dart';
import '../../../core/services/local_cache_service.dart';

final activeTrainersProvider = FutureProvider<List<UserModel>>((ref) async {
  if (!SupabaseConstants.isConfigured) {
    final cached = await LocalCacheService.load('trainers');
    if (cached is List && cached.isNotEmpty) {
      return cached.map((j) => UserModel.fromJson(j)).toList();
    }
    return MockData.trainers;
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.usersTable)
        .select()
        .eq('role', 'trainer')
        .eq('active', true)
        .order('name');
    final list = (res as List).map((j) => UserModel.fromJson(j)).toList();
    await LocalCacheService.save('trainers', res);
    return list.isEmpty ? MockData.trainers : list;
  } catch (_) {
    final cached = await LocalCacheService.load('trainers');
    if (cached is List && cached.isNotEmpty) {
      return cached.map((j) => UserModel.fromJson(j)).toList();
    }
    return MockData.trainers;
  }
});

final activeNutritionistsProvider = FutureProvider<List<UserModel>>((ref) async {
  if (!SupabaseConstants.isConfigured) {
    return MockData.allStaff.where((u) => u.role == 'nutritionist' && u.active).toList();
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.usersTable)
        .select()
        .eq('role', 'nutritionist')
        .eq('active', true)
        .order('name');
    final list = (res as List).map((j) => UserModel.fromJson(j)).toList();
    return list.isEmpty
        ? MockData.allStaff.where((u) => u.role == 'nutritionist' && u.active).toList()
        : list;
  } catch (_) {
    return MockData.allStaff.where((u) => u.role == 'nutritionist' && u.active).toList();
  }
});

final allActiveSlotsProvider = FutureProvider<List<SlotModel>>((ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  bool isSlotActive(SlotModel s) {
    // 1. Slot must be valid today
    final vf = DateTime(s.validFrom.year, s.validFrom.month, s.validFrom.day);
    final vt = DateTime(s.validTo.year, s.validTo.month, s.validTo.day);
    if (today.isBefore(vf) || today.isAfter(vt)) return false;

    // 2. Client must not be deactivated or completed
    final client = MockData.clients.where((c) => c.id == s.clientId).firstOrNull;
    if (client != null && (client.isDeactivated || client.isCompleted)) return false;

    // 3. Subscription must not be deactivated or completed
    if (s.subscriptionId.isNotEmpty) {
      final sub = MockData.subscriptions.where((sub) => sub.id == s.subscriptionId).firstOrNull;
      if (sub != null && (sub.isDeactivated || sub.isCompleted)) return false;
    }
    return true;
  }

  if (!SupabaseConstants.isConfigured) {
    return List<SlotModel>.from(MockData.slots.where(isSlotActive));
  }
  try {
    final todayStr = today.toIso8601String().split('T')[0];
    final res = await Supabase.instance.client
        .from(SupabaseConstants.slotsTable)
        .select()
        .lte('valid_from', todayStr)
        .gte('valid_to', todayStr);
    final list = (res as List).map((j) => SlotModel.fromJson(j)).where(isSlotActive).toList();
    return list;
  } catch (_) {
    return List<SlotModel>.from(MockData.slots.where(isSlotActive));
  }
});

/// Returns all slots for a specific trainer
final trainerSlotsProvider = FutureProvider.family<List<SlotModel>, String>((ref, trainerId) async {
  final allSlots = await ref.watch(allActiveSlotsProvider.future);
  return allSlots.where((s) => s.trainerId == trainerId).toList();
});
