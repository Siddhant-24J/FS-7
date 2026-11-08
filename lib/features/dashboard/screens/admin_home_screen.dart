import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/mock/mock_data.dart';
import '../../../widgets/common/app_cards.dart';
import '../../../widgets/common/fs7_logo.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final dashAsync = ref.watch(adminDashboardProvider);
    final today = DateFormat('EEEE, d MMMM y').format(DateTime.now());

    final unreadNotifs = MockData.notifications.where((n) =>
        !n.cancelled && !n.isRead && (n.userId == user?.id || n.userId == 'admin-01' || user?.isAdmin == true)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(10),
          child: FS7Logo(size: 32, showText: false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good ${_greeting()}, ${user?.name.split(' ').first ?? 'Admin'}',
              style: Theme.of(context).textTheme.titleMedium),
            Text(today, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unreadNotifs.isNotEmpty,
              label: Text('${unreadNotifs.length}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => _showNotifications(context, user?.id, user?.isAdmin == true),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showGlobalSearch(context),
          ),
        ],
      ),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (dash) => RefreshIndicator(
          onRefresh: () => ref.refresh(adminDashboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Today's summary banner ──────────────────────
              if (dash.pendingFollowups > 0)
                _AlertBanner(
                  icon: Icons.phone_missed,
                  color: AppColors.brandOrange,
                  message: '${dash.pendingFollowups} follow-up call${dash.pendingFollowups == 1 ? '' : 's'} due today',
                  onTap: () => context.go('/admin/inquiries'),
                ),
              const SizedBox(height: 8),
              if (dash.overdueCalls > 0)
                _AlertBanner(
                  icon: Icons.warning_amber,
                  color: AppColors.error,
                  message: '${dash.overdueCalls} overdue follow-up${dash.overdueCalls == 1 ? '' : 's'}',
                  onTap: () => context.go('/admin/inquiries'),
                ),

              const SizedBox(height: 16),
              // ── Today's sessions ────────────────────────────
              const SectionHeader(title: "Today's Sessions"),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.25,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  StatCard(
                    label: 'Scheduled', value: '${dash.sessionsScheduled}',
                    icon: Icons.event_note, color: AppColors.textSecondary,
                  ),
                  StatCard(
                    label: 'Present', value: '${dash.sessionsPresent}',
                    icon: Icons.check_circle_outline, color: AppColors.success,
                  ),
                  StatCard(
                    label: 'Absent', value: '${dash.sessionsAbsent}',
                    icon: Icons.cancel_outlined, color: AppColors.error,
                  ),
                  StatCard(
                    label: 'Not Marked', value: '${dash.sessionsNotMarked}',
                    icon: Icons.pending_outlined, color: AppColors.warning,
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // ── Clients overview ─────────────────────────────
              const SectionHeader(title: 'Clients'),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.25,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  StatCard(
                    label: 'Active Clients', value: '${dash.activeClients}',
                    icon: Icons.people, color: AppColors.brandOrange,
                    onTap: () => context.go('/admin/clients'),
                  ),
                  StatCard(
                    label: 'Free Seats', value: '${dash.freeSeats}',
                    icon: Icons.event_seat_outlined, color: AppColors.success,
                    onTap: () => context.go('/admin/timetable'),
                  ),
                  StatCard(
                    label: 'Ending in 14 Days', value: '${dash.plansEndingSoon}',
                    icon: Icons.timer_outlined, color: AppColors.warning,
                    onTap: () => context.go('/admin/clients'),
                  ),
                  StatCard(
                    label: 'In Extension', value: '${dash.clientsInExtension}',
                    icon: Icons.update, color: AppColors.warning,
                    onTap: () => context.go('/admin/clients'),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // ── Inquiries ────────────────────────────────────
              SectionHeader(
                title: 'Inquiries',
                action: 'View all',
                onAction: () => context.go('/admin/inquiries'),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.25,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  StatCard(
                    label: 'New This Week', value: '${dash.newInquiriesWeek}',
                    icon: Icons.person_add_outlined, color: AppColors.brandOrange,
                  ),
                  StatCard(
                    label: 'Conversion Rate', value: '${dash.conversionRate.toStringAsFixed(0)}%',
                    icon: Icons.trending_up, color: AppColors.success,
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // ── Staff ────────────────────────────────────────
              const SectionHeader(title: 'Staff Today'),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Present', value: '${dash.staffPresent}',
                      icon: Icons.how_to_reg, color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: 'Absent', value: '${dash.staffAbsent}',
                      icon: Icons.person_off_outlined, color: AppColors.error,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              if (dash.assessmentsPending > 0)
                _AlertBanner(
                  icon: Icons.assignment_late,
                  color: AppColors.warning,
                  message: '${dash.assessmentsPending} assessment${dash.assessmentsPending == 1 ? '' : 's'} pending',
                  onTap: () => context.go('/admin/clients'),
                ),

              const SizedBox(height: 24),
              // ── Quick actions ────────────────────────────────
              const SectionHeader(title: 'Quick Actions'),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _QuickAction(
                    icon: Icons.person_add,
                    label: 'Add Client',
                    onTap: () => context.go('/admin/clients/add'),
                  ),
                  _QuickAction(
                    icon: Icons.phone_in_talk,
                    label: 'Add Inquiry',
                    onTap: () => context.go('/admin/inquiries/add'),
                  ),
                  _QuickAction(
                    icon: Icons.how_to_reg,
                    label: 'Staff Attendance',
                    onTap: () => context.go('/admin/more/staff-attendance'),
                  ),
                  _QuickAction(
                    icon: Icons.calendar_today,
                    label: 'Timetable',
                    onTap: () => context.go('/admin/timetable'),
                  ),
                  _QuickAction(
                    icon: Icons.people,
                    label: 'Team Members',
                    onTap: () => context.go('/admin/more/team'),
                  ),
                  _QuickAction(
                    icon: Icons.analytics_outlined,
                    label: 'Inquiry Analytics',
                    onTap: () => context.go('/admin/inquiries/analytics'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  void _showGlobalSearch(BuildContext context) {
    showSearch(context: context, delegate: _GlobalSearchDelegate());
  }

  void _showNotifications(BuildContext context, String? currentUserId, bool isAdmin) {
    final notifications = MockData.notifications.where((n) =>
        !n.cancelled && (n.userId == currentUserId || n.userId == 'admin-01' || isAdmin)).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications, color: AppColors.brandOrange),
                        const SizedBox(width: 8),
                        Text(
                          'Notifications (${notifications.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (notifications.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            for (int i = 0; i < MockData.notifications.length; i++) {
                              MockData.notifications[i] = MockData.notifications[i].copyWith(readAt: DateTime.now());
                            }
                          });
                        },
                        child: const Text('Mark all as read'),
                      ),
                  ],
                ),
                const Divider(),
                if (notifications.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No notifications yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final notif = notifications[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: notif.isRead
                                ? AppColors.surfaceRaised
                                : AppColors.brandOrange.withOpacity(0.2),
                            child: Icon(
                              _notifIcon(notif.type),
                              color: notif.isRead ? AppColors.textSecondary : AppColors.brandOrange,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            notif.title,
                            style: TextStyle(
                              fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(notif.body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMM, hh:mm a').format(notif.createdAt),
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          onTap: () {
                            setSheetState(() {
                              MockData.notifications[i] = notif.copyWith(readAt: DateTime.now());
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _notifIcon(String type) {
    switch (type) {
      case 'client_assigned': return Icons.person_add;
      case 'final_due': return Icons.assessment;
      case 'absent_alert': return Icons.warning_amber;
      case 'plan_completed': return Icons.emoji_events;
      case 'trainer_absent_impact': return Icons.event_busy;
      default: return Icons.notifications;
    }
  }
}

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final VoidCallback? onTap;

  const _AlertBanner({
    required this.icon, required this.color,
    required this.message, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500))),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios, color: color, size: 12),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.brandOrange, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}

class _GlobalSearchDelegate extends SearchDelegate<String> {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: AppColors.surface),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) => _buildSearchBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchBody(context);

  Widget _buildSearchBody(BuildContext context) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return const Center(
        child: Text('Search clients, inquiries, staff by name or phone...',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final matchingClients = MockData.clients.where((c) =>
        c.fullName.toLowerCase().contains(q) ||
        c.phonePrimary.contains(q)).toList();

    final matchingInquiries = MockData.inquiries.where((i) =>
        i.name.toLowerCase().contains(q) ||
        i.phone.contains(q)).toList();

    final matchingStaff = MockData.allStaff.where((s) =>
        s.name.toLowerCase().contains(q) ||
        s.role.toLowerCase().contains(q) ||
        (s.phone?.contains(q) ?? false)).toList();

    if (matchingClients.isEmpty && matchingInquiries.isEmpty && matchingStaff.isEmpty) {
      return Center(
        child: Text('No results for "$query"',
            style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (matchingClients.isNotEmpty) ...[
          const SectionHeader(title: 'Clients'),
          ...matchingClients.map((c) => ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.surfaceRaised,
              child: Icon(Icons.person, color: AppColors.brandOrange),
            ),
            title: Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${c.phonePrimary} • ${c.programType}'),
            trailing: StatusChip(status: c.status),
            onTap: () {
              close(context, '');
              context.go('/admin/clients/${c.id}');
            },
          )),
          const SizedBox(height: 16),
        ],
        if (matchingInquiries.isNotEmpty) ...[
          const SectionHeader(title: 'Inquiries'),
          ...matchingInquiries.map((inq) => ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.surfaceRaised,
              child: Icon(Icons.phone_in_talk, color: AppColors.brandOrange),
            ),
            title: Text(inq.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${inq.phone} • Status: ${inq.status}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              close(context, '');
              context.go('/admin/inquiries/${inq.id}');
            },
          )),
          const SizedBox(height: 16),
        ],
        if (matchingStaff.isNotEmpty) ...[
          const SectionHeader(title: 'Staff & Team'),
          ...matchingStaff.map((s) => ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.surfaceRaised,
              child: Icon(Icons.badge, color: AppColors.brandOrange),
            ),
            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${s.role.toUpperCase()} • ${s.phone ?? s.userId}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              close(context, '');
              context.go('/admin/more/team');
            },
          )),
        ],
      ],
    );
  }
}

