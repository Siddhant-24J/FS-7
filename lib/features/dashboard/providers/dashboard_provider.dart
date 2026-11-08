import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/services/server_functions_service.dart';
import '../../../data/models/client_model.dart';

class AdminDashboardData {
  final int sessionsScheduled;
  final int sessionsPresent;
  final int sessionsAbsent;
  final int sessionsNotMarked;
  final int activeClients;
  final int freeSeats;
  final int plansEndingSoon;
  final int clientsInExtension;
  final int deactivatedThisMonth;
  final int pendingFollowups;
  final int overdueCalls;
  final int newInquiriesWeek;
  final double conversionRate;
  final int staffPresent;
  final int staffAbsent;
  final int assessmentsPending;

  const AdminDashboardData({
    this.sessionsScheduled = 0,
    this.sessionsPresent = 0,
    this.sessionsAbsent = 0,
    this.sessionsNotMarked = 0,
    this.activeClients = 0,
    this.freeSeats = 0,
    this.plansEndingSoon = 0,
    this.clientsInExtension = 0,
    this.deactivatedThisMonth = 0,
    this.pendingFollowups = 0,
    this.overdueCalls = 0,
    this.newInquiriesWeek = 0,
    this.conversionRate = 0.0,
    this.staffPresent = 0,
    this.staffAbsent = 0,
    this.assessmentsPending = 0,
  });
}

final adminDashboardProvider = FutureProvider<AdminDashboardData>((ref) async {
  if (!SupabaseConstants.isConfigured) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final in14 = todayDate.add(const Duration(days: 14));
    final weekAgo = todayDate.subtract(const Duration(days: 7));
    final monthStart = DateTime(today.year, today.month, 1);

    // Today's attendance
    final todayAtt = MockData.attendance.where((a) {
      final aDate = DateTime(a.date.year, a.date.month, a.date.day);
      return aDate.isAtSameMomentAs(todayDate);
    }).toList();
    final presentToday = todayAtt.where((a) => a.isPresent).length;
    final absentToday = todayAtt.where((a) => a.isAbsent).length;

    // Real scheduled sessions for today based on patternDays & active clients
    final todayWeekday = todayDate.weekday;
    final scheduled = todayWeekday == DateTime.sunday
        ? 0
        : MockData.slots.where((s) {
            final vf = DateTime(s.validFrom.year, s.validFrom.month, s.validFrom.day);
            final vt = DateTime(s.validTo.year, s.validTo.month, s.validTo.day);
            if (todayDate.isBefore(vf) || todayDate.isAfter(vt)) return false;
            final days = ServerFunctionsService.patternDays[s.pattern] ?? {};
            if (!days.contains(todayWeekday)) return false;
            final client = MockData.clients.where((c) => c.id == s.clientId).firstOrNull;
            if (client != null && (client.isDeactivated || client.isCompleted)) return false;
            return true;
          }).length;

    final notMarked = (scheduled - (presentToday + absentToday)) > 0
        ? (scheduled - (presentToday + absentToday))
        : 0;

    // Plans ending soon (within 14 days)
    final endingSoon = MockData.subscriptions.where((s) {
      if (s.status != 'active') return false;
      final effEnd = DateTime(s.effectiveEndDate.year, s.effectiveEndDate.month, s.effectiveEndDate.day);
      return !effEnd.isBefore(todayDate) && !effEnd.isAfter(in14);
    }).length;

    // Inquiries conversion & exact date follow-ups
    final totalInquiries = MockData.inquiries.length;
    final converted = MockData.inquiries.where((i) => i.status == 'converted').length;
    final convRate = totalInquiries > 0 ? (converted / totalInquiries) * 100 : 0.0;

    final todayFollowups = MockData.inquiries.where((i) {
      if (!i.isOpen) return false;
      final d = DateTime(i.nextFollowupDate.year, i.nextFollowupDate.month, i.nextFollowupDate.day);
      return d.isAtSameMomentAs(todayDate);
    }).length;

    final overdueCalls = MockData.inquiries.where((i) {
      if (!i.isOpen) return false;
      final d = DateTime(i.nextFollowupDate.year, i.nextFollowupDate.month, i.nextFollowupDate.day);
      return d.isBefore(todayDate);
    }).length;

    // Free seats calculation across active trainers
    int totalCapacity = 0;
    for (final t in MockData.trainers) {
      final startH = int.tryParse((t.shiftStart ?? '06:00').split(':')[0]) ?? 6;
      final endH = int.tryParse((t.shiftEnd ?? '14:00').split(':')[0]) ?? 14;
      final hours = (endH > startH) ? (endH - startH) : 8;
      totalCapacity += hours * 2; // max 2 capacity per hour
    }
    final activeSlotsCount = MockData.slots.where((s) {
      final vf = DateTime(s.validFrom.year, s.validFrom.month, s.validFrom.day);
      final vt = DateTime(s.validTo.year, s.validTo.month, s.validTo.day);
      final client = MockData.clients.where((c) => c.id == s.clientId).firstOrNull;
      if (client != null && (client.isDeactivated || client.isCompleted)) return false;
      return !todayDate.isBefore(vf) && !todayDate.isAfter(vt);
    }).length;
    final freeSeats = (totalCapacity - activeSlotsCount) > 0 ? (totalCapacity - activeSlotsCount) : 0;

    // Today's staff attendance only
    final staffToday = MockData.staffAttendance.where((s) {
      final sDate = DateTime(s.date.year, s.date.month, s.date.day);
      return sDate.isAtSameMomentAs(todayDate);
    }).toList();

    return AdminDashboardData(
      sessionsScheduled: scheduled,
      sessionsPresent: presentToday,
      sessionsAbsent: absentToday,
      sessionsNotMarked: notMarked,
      activeClients: MockData.clients.where((c) => c.status == 'active').length,
      freeSeats: freeSeats,
      plansEndingSoon: endingSoon,
      clientsInExtension: MockData.clients.where((c) => c.status == 'extended').length,
      deactivatedThisMonth: MockData.clients.where((c) => c.status == 'deactivated' && !c.updatedAt.isBefore(monthStart)).length,
      pendingFollowups: todayFollowups,
      overdueCalls: overdueCalls,
      newInquiriesWeek: MockData.inquiries.where((i) => i.createdAt.isAfter(weekAgo)).length,
      conversionRate: convRate,
      staffPresent: staffToday.where((s) => s.status == 'present').length,
      staffAbsent: staffToday.where((s) => s.status == 'absent').length,
      assessmentsPending: MockData.clients.where((c) => c.status == 'active' && !MockData.assessments.any((a) => a.clientId == c.id)).length,
    );
  }

  final supabase = Supabase.instance.client;
  final today = DateTime.now();
  final todayStr = today.toIso8601String().split('T')[0];
  final weekAgo = today.subtract(const Duration(days: 7)).toIso8601String().split('T')[0];
  final in14 = today.add(const Duration(days: 14)).toIso8601String().split('T')[0];
  final monthStart = DateTime(today.year, today.month, 1).toIso8601String().split('T')[0];

  try {
    final activeClientsRes = await supabase
        .from(SupabaseConstants.clientsTable)
        .select('id')
        .eq('status', 'active')
        .eq('archived', false);
    final activeClients = (activeClientsRes as List).length;

    final attendanceRes = await supabase
        .from(SupabaseConstants.attendanceTable)
        .select('status')
        .eq('date', todayStr);
    final attendance = attendanceRes as List;
    final presentToday = attendance.where((a) => a['status'] == 'present').length;
    final absentToday = attendance.where((a) => a['status'] == 'absent').length;

    final pendingInquiriesRes = await supabase
        .from(SupabaseConstants.inquiriesTable)
        .select('id')
        .eq('next_followup_date', todayStr)
        .inFilter('status', ['new', 'follow_up']);
    final pendingFollowups = (pendingInquiriesRes as List).length;

    final overdueInquiriesRes = await supabase
        .from(SupabaseConstants.inquiriesTable)
        .select('id')
        .lt('next_followup_date', todayStr)
        .inFilter('status', ['new', 'follow_up']);
    final overdueCalls = (overdueInquiriesRes as List).length;

    final newInqRes = await supabase
        .from(SupabaseConstants.inquiriesTable)
        .select('id')
        .gte('inquiry_date', weekAgo);
    final newInquiriesWeek = (newInqRes as List).length;

    final endingSoonRes = await supabase
        .from(SupabaseConstants.subscriptionsTable)
        .select('id')
        .eq('status', 'active')
        .lte('end_date', in14)
        .gte('end_date', todayStr);
    final plansEndingSoon = (endingSoonRes as List).length;

    final inExtRes = await supabase
        .from(SupabaseConstants.subscriptionsTable)
        .select('id')
        .eq('status', 'extended');
    final clientsInExtension = (inExtRes as List).length;

    final staffAttRes = await supabase
        .from(SupabaseConstants.staffAttendanceTable)
        .select('status')
        .eq('date', todayStr);
    final staffAtt = staffAttRes as List;
    final staffPresent = staffAtt.where((s) => s['status'] == 'present').length;
    final staffAbsent = staffAtt.where((s) => s['status'] == 'absent').length;

    final monthInquiriesRes = await supabase
        .from(SupabaseConstants.inquiriesTable)
        .select('status')
        .gte('inquiry_date', monthStart);
    final monthInquiries = monthInquiriesRes as List;
    final converted = monthInquiries.where((i) => i['status'] == 'converted').length;
    final conversionRate = monthInquiries.isEmpty
        ? 0.0
        : (converted / monthInquiries.length) * 100;

    return AdminDashboardData(
      activeClients: activeClients,
      sessionsPresent: presentToday,
      sessionsAbsent: absentToday,
      sessionsScheduled: presentToday + absentToday,
      sessionsNotMarked: 0,
      pendingFollowups: pendingFollowups,
      overdueCalls: overdueCalls,
      newInquiriesWeek: newInquiriesWeek,
      plansEndingSoon: plansEndingSoon,
      clientsInExtension: clientsInExtension,
      staffPresent: staffPresent,
      staffAbsent: staffAbsent,
      conversionRate: conversionRate,
    );
  } catch (_) {
    return const AdminDashboardData();
  }
});
