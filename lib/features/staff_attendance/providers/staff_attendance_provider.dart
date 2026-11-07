import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/mock/mock_data.dart';
import '../../../data/models/staff_attendance_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/services/server_functions_service.dart';

final allStaffUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  if (!SupabaseConstants.isConfigured) {
    return MockData.allStaff.where((u) => u.role != 'admin').toList();
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.usersTable)
        .select()
        .neq('role', 'admin')
        .eq('active', true)
        .order('name');
    final list = (res as List).map((j) => UserModel.fromJson(j)).toList();
    return list.isEmpty
        ? MockData.allStaff.where((u) => u.role != 'admin').toList()
        : list;
  } catch (_) {
    return MockData.allStaff.where((u) => u.role != 'admin').toList();
  }
});

final staffAttendanceForDateProvider =
    FutureProvider.family<List<StaffAttendanceModel>, DateTime>((ref, date) async {
  if (!SupabaseConstants.isConfigured) {
    return MockData.staffAttendance;
  }
  try {
    final dateStr = date.toIso8601String().split('T')[0];
    final res = await Supabase.instance.client
        .from(SupabaseConstants.staffAttendanceTable)
        .select()
        .eq('date', dateStr);
    final list = (res as List).map((j) => StaffAttendanceModel.fromJson(j)).toList();
    return list.isEmpty ? MockData.staffAttendance : list;
  } catch (_) {
    return MockData.staffAttendance;
  }
});

class StaffAttendanceRepository {
  final SupabaseClient _client;
  final ServerFunctionsService _service;

  StaffAttendanceRepository(this._client, this._service);

  Future<void> markStaffAttendance({
    required String userId,
    required DateTime date,
    required String status,
    String? inTime,
    String? outTime,
    bool lateFlag = false,
    String? note,
    required String markedBy,
  }) async {
    await _service.markStaffAttendance(
      userId: userId,
      date: date,
      status: status,
      inTime: inTime,
      outTime: outTime,
      note: note,
      markedBy: markedBy,
    );
  }

  Future<void> markAllPresent({
    required List<UserModel> staffList,
    required DateTime date,
    required String markedBy,
  }) async {
    for (final staff in staffList) {
      await markStaffAttendance(
        userId: staff.id,
        date: date,
        status: 'present',
        inTime: '06:00',
        markedBy: markedBy,
      );
    }
  }

  Future<void> cancelSessionsForTrainer({
    required String trainerId,
    required DateTime date,
    required String markedBy,
  }) async {
    await _service.cancelSessionsForTrainer(
      trainerId: trainerId,
      date: date,
      markedBy: markedBy,
    );
  }

  Future<void> reassignSessionForDay({
    required String clientId,
    required DateTime date,
    required String substituteTrainerId,
    required int hourStart,
    required String createdBy,
  }) async {
    await _service.reassignSessionForDay(
      clientId: clientId,
      date: date,
      substituteTrainerId: substituteTrainerId,
      hourStart: hourStart,
      createdBy: createdBy,
    );
  }
}

final staffAttendanceRepositoryProvider = Provider<StaffAttendanceRepository>((ref) {
  final service = ref.watch(serverFunctionsServiceProvider);
  return StaffAttendanceRepository(Supabase.instance.client, service);
});
