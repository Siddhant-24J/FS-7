import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/mock/mock_data.dart';
import '../../../data/models/inquiry_model.dart';
import '../../../core/services/server_functions_service.dart';

final inquiriesProvider = FutureProvider<List<InquiryModel>>((ref) async {
  if (!SupabaseConstants.isConfigured) {
    return List<InquiryModel>.from(MockData.inquiries);
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.inquiriesTable)
        .select()
        .eq('archived', false)
        .order('inquiry_date', ascending: false);
    final list = (res as List).map((j) => InquiryModel.fromJson(j)).toList();
    return list.isEmpty ? List<InquiryModel>.from(MockData.inquiries) : list;
  } catch (_) {
    return List<InquiryModel>.from(MockData.inquiries);
  }
});

final inquiryProvider = FutureProvider.family<InquiryModel?, String>((ref, id) async {
  if (!SupabaseConstants.isConfigured) {
    return MockData.inquiries.where((i) => i.id == id).firstOrNull;
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.inquiriesTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (res == null) return MockData.inquiries.where((i) => i.id == id).firstOrNull;
    return InquiryModel.fromJson(res);
  } catch (_) {
    return MockData.inquiries.where((i) => i.id == id).firstOrNull;
  }
});

final todayInquiriesProvider = FutureProvider<List<InquiryModel>>((ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  bool isToday(InquiryModel i) {
    if (!i.isOpen) return false;
    final fDate = DateTime(i.nextFollowupDate.year, i.nextFollowupDate.month, i.nextFollowupDate.day);
    return fDate.isAtSameMomentAs(today);
  }

  if (!SupabaseConstants.isConfigured) {
    return List<InquiryModel>.from(MockData.inquiries.where(isToday));
  }
  try {
    final todayStr = now.toIso8601String().split('T')[0];
    final res = await Supabase.instance.client
        .from(SupabaseConstants.inquiriesTable)
        .select()
        .eq('next_followup_date', todayStr)
        .inFilter('status', ['new', 'follow_up'])
        .order('inquiry_date', ascending: false);
    final list = (res as List).map((j) => InquiryModel.fromJson(j)).toList();
    return list.isEmpty
        ? List<InquiryModel>.from(MockData.inquiries.where(isToday))
        : list;
  } catch (_) {
    return List<InquiryModel>.from(MockData.inquiries.where(isToday));
  }
});

final overdueInquiriesProvider = FutureProvider<List<InquiryModel>>((ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  bool isOverdue(InquiryModel i) {
    if (!i.isOpen) return false;
    final fDate = DateTime(i.nextFollowupDate.year, i.nextFollowupDate.month, i.nextFollowupDate.day);
    return fDate.isBefore(today);
  }

  if (!SupabaseConstants.isConfigured) {
    return List<InquiryModel>.from(MockData.inquiries.where(isOverdue));
  }
  try {
    final todayStr = now.toIso8601String().split('T')[0];
    final res = await Supabase.instance.client
        .from(SupabaseConstants.inquiriesTable)
        .select()
        .lt('next_followup_date', todayStr)
        .inFilter('status', ['new', 'follow_up'])
        .order('next_followup_date');
    final list = (res as List).map((j) => InquiryModel.fromJson(j)).toList();
    return list.isEmpty ? List<InquiryModel>.from(MockData.inquiries.where(isOverdue)) : list;
  } catch (_) {
    return List<InquiryModel>.from(MockData.inquiries.where(isOverdue));
  }
});

final upcomingInquiriesProvider = FutureProvider<List<InquiryModel>>((ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  bool isUpcoming(InquiryModel i) {
    if (!i.isOpen) return false;
    final fDate = DateTime(i.nextFollowupDate.year, i.nextFollowupDate.month, i.nextFollowupDate.day);
    return fDate.isAfter(today);
  }

  if (!SupabaseConstants.isConfigured) {
    return List<InquiryModel>.from(MockData.inquiries.where(isUpcoming));
  }
  try {
    final todayStr = now.toIso8601String().split('T')[0];
    final res = await Supabase.instance.client
        .from(SupabaseConstants.inquiriesTable)
        .select()
        .gt('next_followup_date', todayStr)
        .inFilter('status', ['new', 'follow_up'])
        .order('next_followup_date');
    final list = (res as List).map((j) => InquiryModel.fromJson(j)).toList();
    return list.isEmpty ? List<InquiryModel>.from(MockData.inquiries.where(isUpcoming)) : list;
  } catch (_) {
    return List<InquiryModel>.from(MockData.inquiries.where(isUpcoming));
  }
});

final inquiryFollowupsProvider =
    FutureProvider.family<List<InquiryFollowupModel>, String>((ref, inquiryId) async {
  if (!SupabaseConstants.isConfigured) {
    return MockData.inquiryFollowups.where((f) => f.inquiryId == inquiryId).toList();
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.inquiryFollowupsTable)
        .select()
        .eq('inquiry_id', inquiryId)
        .order('followup_at', ascending: false);
    return (res as List).map((j) => InquiryFollowupModel.fromJson(j)).toList();
  } catch (_) {
    return MockData.inquiryFollowups.where((f) => f.inquiryId == inquiryId).toList();
  }
});

class InquiryRepository {
  final SupabaseClient _client;
  final ServerFunctionsService _service;

  InquiryRepository(this._client, this._service);

  Future<void> createInquiry({
    required Map<String, dynamic> data,
    required String createdBy,
  }) async {
    await _service.createInquiry(data: data, createdBy: createdBy);
  }

  Future<void> logFollowup({
    required String inquiryId,
    required String outcome,
    required String remarks,
    required String loggedBy,
    DateTime? nextFollowupDate,
    String? nextFollowupTime,
  }) async {
    await _service.logFollowup(
      inquiryId: inquiryId,
      outcome: outcome,
      remarks: remarks,
      loggedBy: loggedBy,
      nextFollowupDate: nextFollowupDate,
      nextFollowupTime: nextFollowupTime,
    );
  }

  Future<void> closeInquiry({
    required String inquiryId,
    required String reason,
    required String status,
    required String actorId,
  }) async {
    await _service.closeInquiry(
      inquiryId: inquiryId,
      reason: reason,
      status: status,
      actorId: actorId,
    );
  }

  Future<void> reopenInquiry({
    required String inquiryId,
    required String actorId,
  }) async {
    await _service.reopenInquiry(
      inquiryId: inquiryId,
      actorId: actorId,
    );
  }
}

final inquiryRepositoryProvider = Provider<InquiryRepository>((ref) {
  final service = ref.watch(serverFunctionsServiceProvider);
  return InquiryRepository(Supabase.instance.client, service);
});
