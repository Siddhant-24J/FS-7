import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/services/server_functions_service.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../data/models/user_model.dart';

final teamMembersProvider = FutureProvider<List<UserModel>>((ref) async {
  if (!SupabaseConstants.isConfigured) {
    final cached = await LocalCacheService.load('all_staff');
    if (cached is List && cached.isNotEmpty) {
      return cached.map((j) => UserModel.fromJson(j)).where((u) => u.role != 'admin').toList();
    }
    return MockData.allStaff.where((u) => u.role != 'admin').toList();
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.usersTable)
        .select()
        .neq('role', 'admin')
        .order('name');
    final list = (res as List).map((j) => UserModel.fromJson(j)).toList();
    await LocalCacheService.save('all_staff', res);
    return list.isEmpty
        ? MockData.allStaff.where((u) => u.role != 'admin').toList()
        : list;
  } catch (_) {
    final cached = await LocalCacheService.load('all_staff');
    if (cached is List && cached.isNotEmpty) {
      return cached.map((j) => UserModel.fromJson(j)).where((u) => u.role != 'admin').toList();
    }
    return MockData.allStaff.where((u) => u.role != 'admin').toList();
  }
});

class TeamRepository {
  final SupabaseClient _client;
  final ServerFunctionsService _service;

  TeamRepository(this._client, this._service);

  Future<void> createStaffMember({
    required String name,
    required String phone,
    required String role,
    required String userId,
    required String password,
    String? shiftStart,
    String? shiftEnd,
    int? weeklyOff,
    String actorId = 'admin-01',
  }) async {
    await _service.createStaff(
      name: name,
      role: role,
      phone: phone,
      userId: userId,
      password: password,
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
      weeklyOff: weeklyOff,
      actorId: actorId,
    );
  }

  Future<void> updateStaffMember({
    required String id,
    required String name,
    required String phone,
    required String role,
    String? password,
    String? shiftStart,
    String? shiftEnd,
    int? weeklyOff,
    String actorId = 'admin-01',
  }) async {
    await _service.updateStaff(
      id: id,
      name: name,
      phone: phone,
      role: role,
      password: password,
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
      weeklyOff: weeklyOff,
      actorId: actorId,
    );
  }

  Future<void> reactivateStaffMember({
    required String userId,
    String actorId = 'admin-01',
  }) async {
    await _service.reactivateStaff(userId: userId, actorId: actorId);
  }
}

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  final service = ref.watch(serverFunctionsServiceProvider);
  return TeamRepository(Supabase.instance.client, service);
});
