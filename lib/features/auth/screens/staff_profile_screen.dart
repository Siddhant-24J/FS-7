import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/mock/mock_data.dart';
import '../../../widgets/common/app_cards.dart';
import '../../../widgets/common/fs7_logo.dart';
import '../providers/auth_provider.dart';

/// Full Profile Screen for Trainers, Nutritionists, and Staff
/// Implements Bug B2 & Specification Section 3.1, 3.2, and 3.5
class StaffProfileScreen extends ConsumerStatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  ConsumerState<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends ConsumerState<StaffProfileScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final roleLabel = user.role.toUpperCase();
    final now = DateTime.now();
    final currentMonthName = DateFormat('MMMM yyyy').format(now);

    // Compute own monthly attendance (§ 3.4 & B2)
    final thisMonthRecords = MockData.staffAttendance.where((s) {
      return s.userId == user.id &&
          s.date.year == now.year &&
          s.date.month == now.month;
    }).toList();

    final daysPresent = thisMonthRecords.where((s) => s.status == 'present').length;
    final daysAbsent = thisMonthRecords.where((s) => s.status == 'absent').length;
    final daysLeave = thisMonthRecords.where((s) => s.status == 'leave' || s.status == 'half_day').length;
    final daysWeekOff = thisMonthRecords.where((s) => s.status == 'week_off').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Profile Header Card ─────────────────────────────────────────
          Card(
            color: AppColors.surfaceRaised,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.surface,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandOrange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.brandOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.brandOrange.withOpacity(0.4)),
                          ),
                          child: Text(
                            roleLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandOrange,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ID: ${user.userId}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const SectionHeader(title: 'Contact & Work Details'),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_outlined, color: AppColors.brandOrange),
                  title: const Text('Phone Number'),
                  subtitle: Text(user.phone ?? 'Not provided'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: AppColors.brandOrange),
                  title: const Text('Email Address'),
                  subtitle: Text(user.email ?? 'Not provided'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.schedule, color: AppColors.brandOrange),
                  title: const Text('Assigned Shift'),
                  subtitle: Text(
                    '${user.shiftStart ?? "06:00"} – ${user.shiftEnd ?? "14:00"} IST',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined, color: AppColors.brandOrange),
                  title: const Text('Weekly Off'),
                  subtitle: Text(
                    user.weeklyOff == 7 ? 'Sunday' : (user.weeklyOff != null ? 'Day ${user.weeklyOff}' : 'Sunday'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          SectionHeader(title: 'My Monthly Attendance ($currentMonthName)'),

          // ─── Monthly Attendance Summary (§ 3.4 & B2) ─────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatTile(label: 'Present', count: daysPresent, color: AppColors.success),
                      _StatTile(label: 'Absent', count: daysAbsent, color: AppColors.error),
                      _StatTile(label: 'Leave', count: daysLeave, color: AppColors.warning),
                      _StatTile(label: 'Week Off', count: daysWeekOff, color: AppColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Attendance is marked daily by Gym Administration (read-only view).',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const SectionHeader(title: 'Security & Preferences'),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: AppColors.brandOrange),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => context.push('/change-password'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined, color: AppColors.brandOrange),
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive session alerts and schedule reminders'),
                  value: _notificationsEnabled,
                  onChanged: (val) => setState(() => _notificationsEnabled = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── Logout Button (§ 3.1 & B2) ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error.withOpacity(0.15),
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text(
                'Log Out',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Center(
            child: Text(
              'FS-7 Gym Staff App • Version 1.0.0 (Production Release)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out of FS-7?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatTile({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

