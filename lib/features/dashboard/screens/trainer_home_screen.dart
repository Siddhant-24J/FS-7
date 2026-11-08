import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/services/server_functions_service.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/plan_model.dart';
import '../../../data/models/attendance_model.dart';
import '../../../widgets/common/app_cards.dart';
import '../../auth/providers/auth_provider.dart';
import '../../clients/providers/clients_provider.dart';

/// Full Trainer Sessions & Attendance Screen
/// Implements Bug B4 and Section 3.4 of the Specification
class TrainerHomeScreen extends ConsumerStatefulWidget {
  const TrainerHomeScreen({super.key});

  @override
  ConsumerState<TrainerHomeScreen> createState() => _TrainerHomeScreenState();
}

class _TrainerHomeScreenState extends ConsumerState<TrainerHomeScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final clientsAsync = ref.watch(clientsProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final isSunday = targetDate.weekday == DateTime.sunday;
    final isToday = targetDate.isAtSameMomentAs(today);

    // 24-Hour Edit Window Rule (§ 3.4 & B4):
    // Trainers can mark/edit ONLY within 24 hours of session date and NOT in future.
    // Admins can mark any date.
    final hoursDiff = now.difference(targetDate).inHours;
    final isFuture = targetDate.isAfter(today);
    final canMark = user?.isAdmin == true || (!isFuture && hoursDiff <= 24);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isToday ? "Today's Sessions" : "Scheduled Sessions",
                style: Theme.of(context).textTheme.titleLarge),
            Text(
              DateFormat('EEEE, dd MMMM yyyy').format(targetDate),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          if (!isToday)
            TextButton.icon(
              onPressed: () => setState(() => _selectedDate = DateTime.now()),
              icon: const Icon(Icons.today, size: 16, color: AppColors.brandOrange),
              label: const Text('Today', style: TextStyle(color: AppColors.brandOrange)),
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Pick Date',
            onPressed: () => _pickDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Interactive Date Strip (§ 3.4 & B4) ─────────────────────────
          _buildDateStrip(targetDate),

          // ─── 24-Hour Rule Warning Banner ─────────────────────────────────
          if (!canMark && !isSunday)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceRaised,
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFuture
                          ? 'Future date: Preview only. Marking enables on workout day.'
                          : 'Edit window closed (>24h). Only admin can modify past records.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

          // ─── Clients List for Selected Date ──────────────────────────────
          Expanded(
            child: clientsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (clients) {
                if (isSunday) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.weekend_outlined, size: 56, color: AppColors.brandOrange),
                        SizedBox(height: 16),
                        Text('Sunday • Gym Closed',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('No client sessions are scheduled on Sundays.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                // Exact Section 21.2 & Section 3.4 Day Matching:
                final scheduledClients = _getDueClientsForDate(clients, user?.id, targetDate, user?.isAdmin == true);

                if (scheduledClients.isEmpty) {
                  return EmptyState(
                    message: 'No client workouts scheduled for ${DateFormat("EEEE, dd MMM").format(targetDate)}.',
                    icon: Icons.event_available,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: scheduledClients.length,
                  itemBuilder: (ctx, i) {
                    final item = scheduledClients[i];
                    return _ScheduledClientCard(
                      client: item.client,
                      slot: item.slot,
                      selectedDate: targetDate,
                      canMark: canMark,
                      onMarked: () => setState(() {}),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStrip(DateTime targetDate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous Day',
            onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
          ),
          InkWell(
            onTap: () => _pickDate(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.event, size: 18, color: AppColors.brandOrange),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEE, dd MMM yyyy').format(targetDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next Day',
            onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.brandOrange,
            surface: AppColors.surfaceRaised,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  List<_DueClient> _getDueClientsForDate(List<ClientModel> clients, String? trainerId, DateTime date, bool isAdmin) {
    final weekday = date.weekday;
    final List<_DueClient> list = [];

    for (final c in clients) {
      final isMyClient = c.trainerId == trainerId || isAdmin;
      final isStatusValid = c.status == 'active' || c.status == 'extended';

      // 1. Check one-day session override
      final override = MockData.sessionOverrides.where((so) {
        final soDate = DateTime(so.date.year, so.date.month, so.date.day);
        return so.clientId == c.id &&
            (so.trainerId == trainerId || isAdmin) &&
            soDate.isAtSameMomentAs(date);
      }).firstOrNull;

      if (override != null) {
        list.add(_DueClient(client: c, slot: SlotModel(
          id: 'override-${override.id}',
          subscriptionId: '',
          clientId: c.id,
          trainerId: override.trainerId,
          hourStart: override.hourStart,
          pattern: 'OVERRIDE',
          validFrom: date,
          validTo: date,
          createdAt: DateTime.now(),
        )));
        continue;
      }

      if (!isMyClient || !isStatusValid) continue;

      // 2. Check regular slot matching weekday and validity
      final slot = MockData.slots.where((s) {
        if (s.clientId != c.id) return false;
        if (!isAdmin && s.trainerId != trainerId) return false;
        final vf = DateTime(s.validFrom.year, s.validFrom.month, s.validFrom.day);
        final vt = DateTime(s.validTo.year, s.validTo.month, s.validTo.day);
        return !date.isBefore(vf) && !date.isAfter(vt);
      }).firstOrNull ?? MockData.slots.where((s) => s.clientId == c.id && (isAdmin || s.trainerId == trainerId)).firstOrNull;

      if (slot == null) continue;

      final days = ServerFunctionsService.patternDays[slot.pattern] ?? {};
      if (!days.contains(weekday)) continue;

      // Date must be within valid range
      final validFrom = DateTime(slot.validFrom.year, slot.validFrom.month, slot.validFrom.day);
      final validTo = DateTime(slot.validTo.year, slot.validTo.month, slot.validTo.day);
      if (date.isBefore(validFrom) || date.isAfter(validTo)) continue;

      list.add(_DueClient(client: c, slot: slot));
    }

    // Sort by hour
    list.sort((a, b) => a.slot.hourStart.compareTo(b.slot.hourStart));
    return list;
  }
}

class _DueClient {
  final ClientModel client;
  final SlotModel slot;
  const _DueClient({required this.client, required this.slot});
}

class _ScheduledClientCard extends ConsumerWidget {
  final ClientModel client;
  final SlotModel slot;
  final DateTime selectedDate;
  final bool canMark;
  final VoidCallback onMarked;

  const _ScheduledClientCard({
    required this.client,
    required this.slot,
    required this.selectedDate,
    required this.canMark,
    required this.onMarked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = MockData.subscriptions.where((s) => s.clientId == client.id && (s.isActive || s.isExtended)).firstOrNull;
    final totalSessions = sub?.totalSessions ?? 36;

    final attendances = MockData.attendance.where((a) => a.clientId == client.id).toList();
    final usedSessions = attendances.where((a) => a.isPresent || a.isMakeup).length;
    final remainingSessions = (totalSessions - usedSessions).clamp(0, totalSessions);

    final targetDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final existingAttendance = attendances.where((a) {
      final aDate = DateTime(a.date.year, a.date.month, a.date.day);
      return aDate.isAtSameMomentAs(targetDate);
    }).firstOrNull;

    final currentStatus = existingAttendance?.status ?? 'unmarked';
    final hourLabel = '${slot.hourStart.toString().padLeft(2, "0")}:00';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Hour & Pattern badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.brandOrange.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      Text(hourLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brandOrange)),
                      Text(slot.pattern, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        'Sessions: $usedSessions / $totalSessions ($remainingSessions left)',
                        style: TextStyle(
                          fontSize: 12,
                          color: remainingSessions <= 3 ? AppColors.warning : AppColors.textSecondary,
                          fontWeight: remainingSessions <= 3 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(currentStatus),
              ],
            ),
            const Divider(height: 20),
            // Marking Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!canMark) ...[
                  const Text('Marking locked', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                ] else ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: currentStatus == 'absent' ? Colors.white : AppColors.error,
                      backgroundColor: currentStatus == 'absent' ? AppColors.error : null,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(90, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () => _mark(context, ref, sub?.id, 'absent'),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Absent', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentStatus == 'present' ? AppColors.success : AppColors.brandOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () => _mark(context, ref, sub?.id, 'present'),
                    icon: const Icon(Icons.check, size: 14),
                    label: Text(currentStatus == 'present' ? 'Present ✓' : 'Present', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'present':
        color = AppColors.success;
        label = 'Present';
        break;
      case 'absent':
        color = AppColors.error;
        label = 'Absent';
        break;
      case 'makeup':
        color = AppColors.warning;
        label = 'Make-up';
        break;
      case 'cancelled':
        color = AppColors.textSecondary;
        label = 'Cancelled';
        break;
      default:
        color = AppColors.textSecondary.withOpacity(0.5);
        label = 'Not Marked';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _mark(BuildContext context, WidgetRef ref, String? subId, String status) async {
    final user = ref.read(currentUserProvider);
    try {
      await ref.read(clientRepositoryProvider).markAttendance(
            subscriptionId: subId ?? 'sub-${client.id}',
            clientId: client.id,
            date: selectedDate,
            status: status,
            markedBy: user?.id ?? 'trainer-01',
            callerRole: user?.role ?? 'trainer',
          );
      ref.invalidate(clientsProvider);
      onMarked();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked ${client.fullName} as ${status.toUpperCase()}'),
            backgroundColor: status == 'present' ? AppColors.success : AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on BusinessException catch (be) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(be.message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
