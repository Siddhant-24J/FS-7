import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/services/server_functions_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/client_model.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_cards.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/staff_attendance_provider.dart';

class StaffAttendanceScreen extends ConsumerStatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  ConsumerState<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends ConsumerState<StaffAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(allStaffUsersProvider);
    final attendanceAsync = ref.watch(staffAttendanceForDateProvider(_selectedDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Monthly',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exporting attendance report...')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date horizontal strip (strictly up to Today - no future dates)
          _buildDateStrip(),

          // Status & Action Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isToday
                          ? 'Today: ${DateFormat("EEEE, dd MMM yyyy").format(_selectedDate)}'
                          : DateFormat('EEEE, dd MMM yyyy').format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (!_isToday)
                      const Text(
                        'Read-only archive view',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
                if (_isToday)
                  AppSmallButton(
                    label: 'Mark All Present',
                    icon: Icons.done_all,
                    onPressed: () => _markAllPresent(staffAsync.valueOrNull ?? []),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Text('Past Date (Read Only)',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Staff List
          Expanded(
            child: staffAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (staffList) {
                if (staffList.isEmpty) {
                  return const EmptyState(message: 'No staff members found', icon: Icons.people_outline);
                }

                final attendanceMap = {
                  for (var a in (attendanceAsync.valueOrNull ?? [])) a.userId: a.status
                };

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: staffList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final staff = staffList[i];
                    final currentStatus = attendanceMap[staff.id] ?? 'unmarked';

                    return _StaffAttendanceRow(
                      staff: staff,
                      currentStatus: currentStatus,
                      isToday: _isToday,
                      onMark: (status) => _markStatus(staff, status),
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

  Widget _buildDateStrip() {
    final now = DateTime.now();
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: AppColors.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 14,
        itemBuilder: (ctx, i) {
          // Strictly past 13 days up to today (i == 13 is today)
          final date = now.subtract(Duration(days: 13 - i));
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;
          final isTodayItem = i == 13;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 54,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brandOrange
                    : (isTodayItem ? AppColors.brandOrange.withOpacity(0.12) : AppColors.surfaceRaised),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppColors.brandOrange
                      : (isTodayItem ? AppColors.brandOrange.withOpacity(0.4) : AppColors.border),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isTodayItem ? 'TODAY' : DateFormat('E').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isTodayItem ? AppColors.brandOrange : AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _markStatus(UserModel staff, String status) async {
    if (!_isToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance can only be marked for today. Past dates are read-only.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    await ref.read(staffAttendanceRepositoryProvider).markStaffAttendance(
          userId: staff.id,
          date: _selectedDate,
          status: status,
          markedBy: user?.id ?? 'admin-01',
        );
    ref.invalidate(staffAttendanceForDateProvider(_selectedDate));

    // Workflow I: If trainer is absent or on leave, prompt for affected sessions
    if ((status == 'absent' || status == 'leave') && staff.role == 'trainer') {
      final service = ref.read(serverFunctionsServiceProvider);
      final affected = service.getAffectedSessions(trainerId: staff.id, date: _selectedDate);
      if (affected.isNotEmpty && mounted) {
        _showAffectedSessionsDialog(staff, affected);
      }
    }
  }

  void _showAffectedSessionsDialog(UserModel trainer, List<ClientModel> affectedClients) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 8),
            Text('Affected Sessions (${affectedClients.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${trainer.name} is absent today. The following clients have workouts scheduled:',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: affectedClients.length,
                  itemBuilder: (_, i) {
                    final c = affectedClients[i];
                    final slot = MockData.slots.where((s) => s.clientId == c.id).firstOrNull;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(slot != null ? '${slot.pattern} • ${slot.hourLabel}' : '',
                              style: const TextStyle(color: AppColors.brandOrange, fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Workflow I Rule: Gym cancellations do not consume client sessions.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final user = ref.read(currentUserProvider);
              await ref.read(staffAttendanceRepositoryProvider).cancelSessionsForTrainer(
                    trainerId: trainer.id,
                    date: _selectedDate,
                    markedBy: user?.id ?? 'admin-01',
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All affected sessions marked "Cancelled by gym" (0 sessions consumed).'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Cancel All By Gym', style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandOrange),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('To reassign specific sessions for today, select substitute trainer in Timetable.'),
                ),
              );
            },
            child: const Text('Reassign For Day'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllPresent(List<UserModel> staffList) async {
    final user = ref.read(currentUserProvider);
    await ref.read(staffAttendanceRepositoryProvider).markAllPresent(
          staffList: staffList,
          date: _selectedDate,
          markedBy: user?.id ?? '',
        );
    ref.invalidate(staffAttendanceForDateProvider(_selectedDate));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All staff marked present!')),
      );
    }
  }
}

class _StaffAttendanceRow extends StatelessWidget {
  final UserModel staff;
  final String currentStatus;
  final bool isToday;
  final void Function(String status) onMark;

  const _StaffAttendanceRow({
    required this.staff,
    required this.currentStatus,
    required this.isToday,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = AppColors.textSecondary;
    if (currentStatus == 'present') statusColor = AppColors.success;
    if (currentStatus == 'absent') statusColor = AppColors.error;
    if (currentStatus == 'half_day') statusColor = AppColors.warning;
    if (currentStatus == 'leave') statusColor = AppColors.statusHold;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceRaised,
                  child: Text(staff.name[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${staff.role.toUpperCase()} • Shift: ${staff.shiftStart ?? "06:00"} - ${staff.shiftEnd ?? "14:00"}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    currentStatus.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isToday)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _actionChip('Present', 'present', AppColors.success),
                    const SizedBox(width: 6),
                    _actionChip('Absent', 'absent', AppColors.error),
                    const SizedBox(width: 6),
                    _actionChip('Half Day', 'half_day', AppColors.warning),
                    const SizedBox(width: 6),
                    _actionChip('Leave', 'leave', AppColors.statusHold),
                    const SizedBox(width: 6),
                    _actionChip('Week Off', 'week_off', AppColors.textSecondary),
                  ],
                ),
              )
            else
              Text(
                'Record archived · Past date attendance is locked',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.7), fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip(String label, String status, Color color) {
    final isSelected = currentStatus == status;
    return GestureDetector(
      onTap: () => onMark(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? color : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

