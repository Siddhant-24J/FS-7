import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/clients_provider.dart';
import '../../timetable/providers/timetable_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/plan_model.dart';
import '../../../data/models/assessment_model.dart';
import '../../../data/models/document_model.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/services/server_functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../widgets/common/app_cards.dart';

class ClientProfileScreen extends ConsumerStatefulWidget {
  final String clientId;

  const ClientProfileScreen({super.key, required this.clientId});

  @override
  ConsumerState<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<ClientProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    'Overview',
    'Plan & Attendance',
    'Assessments',
    'Reports & Docs',
    'Notes',
    'Nutrition',
    'History',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientAsync = ref.watch(clientProvider(widget.clientId));

    return clientAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
      ),
      data: (client) {
        if (client == null) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: Text('Client not found', style: TextStyle(color: AppColors.textSecondary))),
          );
        }
        return _ProfileScaffold(
          client: client,
          tabController: _tabController,
          tabs: _tabs,
        );
      },
    );
  }
}

class _ProfileScaffold extends ConsumerWidget {
  final ClientModel client;
  final TabController tabController;
  final List<String> tabs;

  const _ProfileScaffold({
    required this.client,
    required this.tabController,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Expanded(
              child: Text(
                client.fullName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(status: client.status),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (user?.isAdmin == true)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
              color: AppColors.surfaceRaised,
              onSelected: (value) => _handleMenu(context, ref, value),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit Profile', style: TextStyle(color: AppColors.textPrimary))),
                PopupMenuItem(
                  value: client.status == 'hold' ? 'resume' : 'hold',
                  child: Text(client.status == 'hold' ? 'Resume Plan' : 'Hold Plan', style: const TextStyle(color: AppColors.warning)),
                ),
                const PopupMenuItem(value: 'reassign', child: Text('Reassign Trainer', style: TextStyle(color: AppColors.brandOrange))),
                const PopupMenuItem(value: 'deactivate', child: Text('Deactivate Client', style: TextStyle(color: AppColors.error))),
                const PopupMenuItem(value: 'audit', child: Text('View Audit Log', style: TextStyle(color: AppColors.textSecondary))),
              ],
            )
          else if (user?.role == 'trainer' && client.trainerId == user?.id)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
              color: AppColors.surfaceRaised,
              onSelected: (value) => _handleMenu(context, ref, value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit Profile', style: TextStyle(color: AppColors.textPrimary))),
              ],
            ),
        ],
        bottom: TabBar(
          controller: tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.brandOrange,
          labelColor: AppColors.brandOrange,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          _OverviewTab(client: client),
          _PlanAttendanceTab(client: client),
          _AssessmentsTab(client: client),
          _ReportsDocsTab(client: client),
          _NotesTab(client: client),
          _NutritionTab(client: client),
          _HistoryTab(client: client),
        ],
      ),
    );
  }

  void _handleMenu(BuildContext context, WidgetRef ref, String value) {
    switch (value) {
      case 'edit':
        context.push('/clients/${client.id}/edit');
        break;
      case 'deactivate':
        _showDeactivateDialog(context, ref);
        break;
      case 'hold':
        _showHoldDialog(context, ref);
        break;
      case 'resume':
        _showResumeDialog(context, ref);
        break;
      case 'reassign':
        _showReassignTrainerDialog(context, ref);
        break;
      case 'audit':
        context.push('/audit-log?clientId=${client.id}');
        break;
    }
  }

  void _showDeactivateDialog(BuildContext context, WidgetRef ref) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Deactivate Client', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Reason',
            labelStyle: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final repo = ref.read(clientRepositoryProvider);
                final sub = await ref.read(activeSubscriptionProvider(client.id).future);
                final user = ref.read(currentUserProvider);
                await repo.deactivateClient(
                  clientId: client.id,
                  subscriptionId: sub?.id,
                  reason: reasonCtrl.text.trim().isEmpty ? 'Deactivated by admin' : reasonCtrl.text.trim(),
                  actorId: user?.id ?? 'admin-01',
                );
                ref.invalidate(clientProvider(client.id));
                ref.invalidate(clientsProvider);
                ref.invalidate(activeSubscriptionProvider(client.id));
                ref.invalidate(clientSubscriptionsProvider(client.id));
                ref.invalidate(allActiveSlotsProvider);
                ref.invalidate(adminDashboardProvider);
                if (client.trainerId.isNotEmpty) {
                  ref.invalidate(trainerSlotsProvider(client.trainerId));
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Client deactivated and timetable seat freed.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Deactivate', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showHoldDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Hold Plan', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will pause the subscription. Resume it from the subscription details.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final sub = await ref.read(activeSubscriptionProvider(client.id).future);
                if (sub != null) {
                  final user = ref.read(currentUserProvider);
                  final repo = ref.read(clientRepositoryProvider);
                  await repo.holdSubscription(
                    subscriptionId: sub.id,
                    holdFrom: DateTime.now(),
                    releaseSlot: false,
                    actorId: user?.id ?? '',
                  );
                  ref.invalidate(activeSubscriptionProvider(client.id));
                  ref.invalidate(clientProvider(client.id));
                  ref.invalidate(clientsProvider);
                  ref.invalidate(allActiveSlotsProvider);
                  ref.invalidate(adminDashboardProvider);
                  if (client.trainerId.isNotEmpty) {
                    ref.invalidate(trainerSlotsProvider(client.trainerId));
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Plan placed on hold.'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                  }
                }
              } catch (_) {}
            },
            child: const Text('Hold', style: TextStyle(color: AppColors.warning)),
          ),
        ],
      ),
    );
  }

  void _showResumeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Resume Plan', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Resuming will reactivate the plan, shifting the end date by the days held.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final sub = await ref.read(activeSubscriptionProvider(client.id).future);
                if (sub != null) {
                  final user = ref.read(currentUserProvider);
                  final repo = ref.read(clientRepositoryProvider);
                  await repo.resumeSubscription(
                    subscriptionId: sub.id,
                    resumeDate: DateTime.now(),
                    actorId: user?.id ?? 'admin-01',
                  );
                  ref.invalidate(activeSubscriptionProvider(client.id));
                  ref.invalidate(clientProvider(client.id));
                  ref.invalidate(clientsProvider);
                  ref.invalidate(allActiveSlotsProvider);
                  ref.invalidate(adminDashboardProvider);
                  if (client.trainerId.isNotEmpty) {
                    ref.invalidate(trainerSlotsProvider(client.trainerId));
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Plan resumed successfully.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              } catch (_) {}
            },
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  void _showReassignTrainerDialog(BuildContext context, WidgetRef ref) {
    String? selectedTrainerId = MockData.trainers.where((t) => t.id != client.trainerId).firstOrNull?.id;
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          title: const Text('Reassign Trainer (Workflow J)', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select new trainer:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedTrainerId,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(labelText: 'New Trainer'),
                items: MockData.trainers
                    .where((t) => t.id != client.trainerId)
                    .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setState(() => selectedTrainerId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Handover Note (Required)',
                  hintText: 'Client medical history, progress, training notes...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandOrange),
              onPressed: () async {
                if (selectedTrainerId == null || noteCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select trainer and provide handover note.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final service = ref.read(serverFunctionsServiceProvider);
                  final user = ref.read(currentUserProvider);
                  await service.reassignClients(
                    fromTrainerId: client.trainerId,
                    toTrainerId: selectedTrainerId!,
                    clientIds: [client.id],
                    handoverNote: noteCtrl.text.trim(),
                    actorId: user?.id ?? 'admin-01',
                  );
                  ref.invalidate(clientProvider(client.id));
                  ref.invalidate(clientsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Client reassigned successfully with handover note!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } on BusinessException catch (be) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(be.message), backgroundColor: AppColors.error),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              },
              child: const Text('Confirm Reassign'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// OVERVIEW TAB
// ─────────────────────────────────────────────────────────
class _OverviewTab extends ConsumerWidget {
  final ClientModel client;

  const _OverviewTab({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(activeSubscriptionProvider(client.id));
    final assessmentsAsync = ref.watch(clientAssessmentsProvider(client.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Photo + basic info
        Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.surfaceRaised,
              backgroundImage: client.photoUrl != null
                  ? CachedNetworkImageProvider(client.photoUrl!)
                  : null,
              child: client.photoUrl == null
                  ? Text(
                      client.firstName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28, color: AppColors.brandOrange, fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.fullName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('${client.age} yrs · ${client.gender}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(client.phonePrimary,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Info cards
        _InfoCard(
          children: [
            _InfoRow(label: 'Program', value: client.programType),
            _InfoRow(label: 'Payment', value: client.paymentMethod),
            if (client.email != null) _InfoRow(label: 'Email', value: client.email!),
            if (client.address != null) _InfoRow(label: 'Address', value: client.address!),
          ],
        ),
        const SizedBox(height: 12),

        // Subscription info
        subAsync.when(
          loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(color: AppColors.brandOrange, strokeWidth: 2))),
          error: (e, _) => const SizedBox(),
          data: (sub) {
            if (sub == null) {
              return _InfoCard(children: [
                const Text('No active subscription', style: TextStyle(color: AppColors.textSecondary)),
              ]);
            }
            return _InfoCard(
              title: 'Current Subscription',
              children: [
                _InfoRow(label: 'Start', value: DateFormat('dd MMM yyyy').format(sub.startDate)),
                _InfoRow(label: 'End', value: DateFormat('dd MMM yyyy').format(sub.effectiveEndDate)),
                _InfoRow(label: 'Sessions', value: sub.totalSessions.toString()),
              ],
            );
          },
        ),
        const SizedBox(height: 12),

        // Baseline check
        assessmentsAsync.when(
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
          data: (assessments) {
            final hasBaseline = assessments.any((a) => a.type == 'baseline');
            if (!hasBaseline) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton.icon(
                  onPressed: () {
                    final sub = ref.read(activeSubscriptionProvider(client.id)).value;
                    if (sub != null) {
                      context.push('/assessments/new?clientId=${client.id}&subscriptionId=${sub.id}&type=baseline');
                    }
                  },
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  label: const Text('Start Baseline Assessment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// PLAN & ATTENDANCE TAB
// ─────────────────────────────────────────────────────────
class _PlanAttendanceTab extends ConsumerStatefulWidget {
  final ClientModel client;

  const _PlanAttendanceTab({required this.client});

  @override
  ConsumerState<_PlanAttendanceTab> createState() => _PlanAttendanceTabState();
}

class _PlanAttendanceTabState extends ConsumerState<_PlanAttendanceTab> {
  @override
  Widget build(BuildContext context) {
    final subAsync = ref.watch(activeSubscriptionProvider(widget.client.id));
    final allSubsAsync = ref.watch(clientSubscriptionsProvider(widget.client.id));

    return subAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.error))),
      data: (sub) {
        if (sub != null) {
          final attendanceAsync = ref.watch(clientAttendanceProvider(sub.id));
          return attendanceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
            error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.error))),
            data: (attendance) => _buildContent(context, sub, attendance),
          );
        }

        // When client is deactivated/completed, load the most recent subscription
        return allSubsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.error))),
          data: (subs) {
            if (subs.isEmpty) {
              return const EmptyState(message: 'No subscription records found', icon: Icons.event_busy_outlined);
            }
            final lastSub = subs.first;
            final attendanceAsync = ref.watch(clientAttendanceProvider(lastSub.id));
            return attendanceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
              error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.error))),
              data: (attendance) => _buildContent(context, lastSub, attendance),
            );
          },
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, SubscriptionModel sub, List<AttendanceModel> attendance) {
    final present = attendance.where((a) => a.isPresent).length;
    final makeup = attendance.where((a) => a.isMakeup).length;
    final absent = attendance.where((a) => a.isAbsent).length;
    final cancelled = attendance.where((a) => a.isCancelled).length;
    final completed = present + makeup;
    final remaining = sub.totalSessions - completed;
    final attendancePct = sub.totalSessions > 0 ? (completed / sub.totalSessions * 100).toStringAsFixed(1) : '0.0';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Subscription card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Current Plan', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  StatusChip(status: sub.status),
                ],
              ),
              const SizedBox(height: 8),
              Text('Plan ID: ${sub.planId}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('dd MMM yyyy').format(sub.startDate)} – ${DateFormat('dd MMM yyyy').format(sub.effectiveEndDate)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _SessionStat(label: 'Total', value: sub.totalSessions, color: AppColors.textPrimary),
                  _SessionStat(label: 'Done', value: completed, color: AppColors.success),
                  _SessionStat(label: 'Remaining', value: remaining > 0 ? remaining : 0, color: AppColors.brandOrange),
                  _SessionStat(label: 'Absent', value: absent, color: AppColors.error),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: sub.totalSessions > 0 ? completed / sub.totalSessions : 0,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation(AppColors.brandOrange),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$attendancePct%', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              if (cancelled > 0) ...[
                const SizedBox(height: 6),
                Text('$cancelled cancelled sessions', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  context.push('/transformation-report?clientId=${widget.client.id}&subscriptionId=${sub.id}');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.brandOrange),
                  foregroundColor: AppColors.brandOrange,
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('View Transformation Report', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Calendar dots
        const SectionHeader(title: 'Attendance History'),
        _AttendanceCalendar(attendance: attendance),
        const SizedBox(height: 16),

        // Mark attendance (Locked strictly to Today)
        if (widget.client.isDeactivated || widget.client.isCompleted || !sub.isActive)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Membership is ${widget.client.status}. Attendance marking is disabled.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else ...[
          const SectionHeader(title: "Mark Today's Attendance"),
          _MarkAttendanceSection(
            clientId: widget.client.id,
            subscriptionId: sub.id,
            onMarked: () {
              ref.invalidate(clientAttendanceProvider(sub.id));
              ref.invalidate(adminDashboardProvider);
            },
          ),
        ],
      ],
    );
  }
}

class _SessionStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SessionStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _AttendanceCalendar extends StatelessWidget {
  final List<AttendanceModel> attendance;

  const _AttendanceCalendar({required this.attendance});

  Color _dotColor(String status) {
    switch (status) {
      case 'present': return AppColors.attendancePresent;
      case 'absent': return AppColors.attendanceAbsent;
      case 'cancelled': return AppColors.attendanceCancelled;
      case 'makeup': return AppColors.attendanceMakeup;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (attendance.isEmpty) {
      return const Text('No attendance records yet.', style: TextStyle(color: AppColors.textSecondary));
    }

    final sorted = [...attendance]..sort((a, b) => a.date.compareTo(b.date));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sorted.map((a) {
        return Tooltip(
          message: '${DateFormat('dd MMM').format(a.date)} · ${a.status}',
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _dotColor(a.status).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _dotColor(a.status).withOpacity(0.5)),
            ),
            child: Center(
              child: Text(
                '${a.date.day}',
                style: TextStyle(color: _dotColor(a.status), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MarkAttendanceSection extends ConsumerStatefulWidget {
  final String clientId;
  final String subscriptionId;
  final VoidCallback onMarked;

  const _MarkAttendanceSection({
    required this.clientId,
    required this.subscriptionId,
    required this.onMarked,
  });

  @override
  ConsumerState<_MarkAttendanceSection> createState() => _MarkAttendanceSectionState();
}

class _MarkAttendanceSectionState extends ConsumerState<_MarkAttendanceSection> {
  bool _loading = false;

  Future<void> _mark(String status) async {
    setState(() => _loading = true);
    final today = DateTime.now();
    try {
      final user = ref.read(currentUserProvider);
      final repo = ref.read(clientRepositoryProvider);
      await repo.markAttendance(
        subscriptionId: widget.subscriptionId,
        clientId: widget.clientId,
        date: today,
        status: status,
        markedBy: user?.id ?? 'admin-01',
        callerRole: user?.role ?? 'admin',
      );
      widget.onMarked();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked as ${status[0].toUpperCase()}${status.substring(1)} for today'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final attendanceList = ref.watch(clientAttendanceProvider(widget.subscriptionId)).valueOrNull ?? [];
    final todayRecord = attendanceList.where((a) => DateFormat('yyyy-MM-dd').format(a.date) == todayStr).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Locked strictly to Today - no changing to past or future dates
          Row(
            children: [
              const Icon(Icons.today, size: 16, color: AppColors.brandOrange),
              const SizedBox(width: 8),
              Text(
                'Today: ${DateFormat("EEEE, dd MMM yyyy").format(today)}',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              if (todayRecord != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.success.withOpacity(0.4)),
                  ),
                  child: Text(
                    todayRecord.status.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
                )
              else
                const Text('Unmarked', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          // Buttons
          _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.brandOrange, strokeWidth: 2))
              : Row(
                  children: [
                    _AttendanceBtn(
                      label: 'Present',
                      color: AppColors.success,
                      isSelected: todayRecord?.status == 'present',
                      onTap: () => _mark('present'),
                    ),
                    const SizedBox(width: 8),
                    _AttendanceBtn(
                      label: 'Absent',
                      color: AppColors.error,
                      isSelected: todayRecord?.status == 'absent',
                      onTap: () => _mark('absent'),
                    ),
                    const SizedBox(width: 8),
                    _AttendanceBtn(
                      label: 'Makeup',
                      color: AppColors.brandOrange,
                      isSelected: todayRecord?.status == 'makeup',
                      onTap: () => _mark('makeup'),
                    ),
                    const SizedBox(width: 8),
                    _AttendanceBtn(
                      label: 'Cancel',
                      color: AppColors.textSecondary,
                      isSelected: todayRecord?.status == 'cancelled',
                      onTap: () => _mark('cancelled'),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _AttendanceBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _AttendanceBtn({
    required this.label,
    required this.color,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.28) : color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.35),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                Icon(Icons.check, size: 13, color: color),
                const SizedBox(width: 3),
              ],
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// ASSESSMENTS TAB
// ─────────────────────────────────────────────────────────
class _AssessmentsTab extends ConsumerWidget {
  final ClientModel client;

  const _AssessmentsTab({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessmentsAsync = ref.watch(clientAssessmentsProvider(client.id));
    final subAsync = ref.watch(activeSubscriptionProvider(client.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: subAsync.maybeWhen(
        data: (sub) => sub != null
            ? FloatingActionButton.extended(
                onPressed: () {
                  _showAddAssessmentSheet(context, ref, sub.id);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Assessment'),
                backgroundColor: AppColors.brandOrange,
                foregroundColor: Colors.white,
              )
            : null,
        orElse: () => null,
      ),
      body: assessmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.error))),
        data: (assessments) {
          if (assessments.isEmpty) {
            return const EmptyState(
              message: 'No assessments yet.\nTap + to add one.',
              icon: Icons.assignment_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: assessments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _AssessmentTile(
              assessment: assessments[i],
              onTap: () => context.push('/assessments/${assessments[i].id}'),
            ),
          );
        },
      ),
    );
  }

  void _showAddAssessmentSheet(BuildContext context, WidgetRef ref, String subscriptionId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Assessment', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            for (final type in ['baseline', 'checkpoint', 'final'])
              ListTile(
                leading: const Icon(Icons.assignment_turned_in_outlined, color: AppColors.brandOrange),
                title: Text('${type[0].toUpperCase()}${type.substring(1)} Assessment',
                    style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/assessments/new?clientId=${client.id}&subscriptionId=$subscriptionId&type=$type');
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentTile extends StatelessWidget {
  final AssessmentModel assessment;
  final VoidCallback onTap;

  const _AssessmentTile({required this.assessment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final score = assessment.fs7Score;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assignment_outlined, color: AppColors.brandOrange, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(assessment.typeLabel,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(DateFormat('dd MMM yyyy').format(assessment.testDate),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            if (score != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(score.toStringAsFixed(1),
                      style: const TextStyle(color: AppColors.brandOrange, fontSize: 20, fontWeight: FontWeight.w700)),
                  const Text('FS-7 Score', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                ],
              ),
            ],
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// REPORTS & DOCS TAB
// ─────────────────────────────────────────────────────────
class _ReportsDocsTab extends ConsumerWidget {
  final ClientModel client;

  const _ReportsDocsTab({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(_clientDocsProvider(client.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadSheet(context, ref),
        icon: const Icon(Icons.upload_outlined),
        label: const Text('Upload'),
        backgroundColor: AppColors.brandOrange,
        foregroundColor: Colors.white,
      ),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.error))),
        data: (docs) {
          if (docs.isEmpty) {
            return const EmptyState(
              message: 'No documents uploaded yet.',
              icon: Icons.folder_outlined,
            );
          }
          final bcaDocs = docs.where((d) => d['type'] == 'bca').toList();
          final bloodDocs = docs.where((d) => d['type'] == 'blood').toList();
          final otherDocs = docs.where((d) => d['type'] == 'other').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (bcaDocs.isNotEmpty) ...[
                const SectionHeader(title: 'BCA Reports'),
                ...bcaDocs.map((d) => _DocTile(doc: d)),
                const SizedBox(height: 8),
              ],
              if (bloodDocs.isNotEmpty) ...[
                const SectionHeader(title: 'Blood Reports'),
                ...bloodDocs.map((d) => _DocTile(doc: d)),
                const SizedBox(height: 8),
              ],
              if (otherDocs.isNotEmpty) ...[
                const SectionHeader(title: 'Other Documents'),
                ...otherDocs.map((d) => _DocTile(doc: d)),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showUploadSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Upload Document', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.fitness_center, color: AppColors.brandOrange),
              title: const Text('BCA Report', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => _uploadDoc(context, ref, 'bca'),
            ),
            ListTile(
              leading: const Icon(Icons.bloodtype_outlined, color: AppColors.error),
              title: const Text('Blood Report', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => _uploadDoc(context, ref, 'blood'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: AppColors.brandOrange),
              title: const Text('Other Document', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => _uploadDoc(context, ref, 'other'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDoc(BuildContext context, WidgetRef ref, String type) async {
    Navigator.pop(context);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (res != null && res.files.isNotEmpty) {
        final f = res.files.first;
        final doc = {
          'id': 'doc-${DateTime.now().millisecondsSinceEpoch}',
          'client_id': client.id,
          'name': f.name,
          'type': type,
          'file_url': f.path ?? '',
          'created_at': DateTime.now().toIso8601String(),
        };
        _inMemoryDocs.add(doc);
        ref.invalidate(_clientDocsProvider(client.id));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${f.name} uploaded successfully!'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (_) {
      // If native file picker dialog was cancelled or unavailable
      final fallbackName = '${type.toUpperCase()}_Report_${DateFormat("ddMMyy").format(DateTime.now())}.pdf';
      final doc = {
        'id': 'doc-${DateTime.now().millisecondsSinceEpoch}',
        'client_id': client.id,
        'name': fallbackName,
        'type': type,
        'file_url': '',
        'created_at': DateTime.now().toIso8601String(),
      };
      _inMemoryDocs.add(doc);
      ref.invalidate(_clientDocsProvider(client.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fallbackName added.'), backgroundColor: AppColors.success),
        );
      }
    }
  }
}

final List<Map<String, dynamic>> _inMemoryDocs = [];

final _clientDocsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, clientId) async {
  final memory = _inMemoryDocs.where((d) => d['client_id'] == clientId).toList();
  if (!SupabaseConstants.isConfigured) return memory;
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.documentsTable)
        .select()
        .eq('client_id', clientId)
        .order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.isEmpty ? memory : list;
  } catch (_) {
    return memory;
  }
});

class _DocTile extends StatelessWidget {
  final Map<String, dynamic> doc;

  const _DocTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final name = doc['name'] as String? ?? 'Document';
    final createdAt = doc['created_at'] != null ? DateTime.tryParse(doc['created_at']) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, color: AppColors.brandOrange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                if (createdAt != null)
                  Text(DateFormat('dd MMM yyyy').format(createdAt),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.download_outlined, color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// NOTES TAB
// ─────────────────────────────────────────────────────────
class _NotesTab extends ConsumerWidget {
  final ClientModel client;

  const _NotesTab({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(_clientNotesProvider(client.id));

    return notesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.error))),
      data: (notes) {
        final trainingNotes = notes.where((n) => n['type'] == 'training').toList();
        final nutritionNotes = notes.where((n) => n['type'] == 'nutrition').toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Training Notes', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.brandOrange),
                  onPressed: () => _showAddNoteDialog(context, ref, 'training'),
                ),
              ],
            ),
            if (trainingNotes.isEmpty)
              const Text('No training notes yet.', style: TextStyle(color: AppColors.textSecondary))
            else
              ...trainingNotes.map((n) => _NoteCard(note: n)),
            if (client.nutritionistId != null) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nutrition Notes', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.brandOrange),
                    onPressed: () => _showAddNoteDialog(context, ref, 'nutrition'),
                  ),
                ],
              ),
              if (nutritionNotes.isEmpty)
                const Text('No nutrition notes yet.', style: TextStyle(color: AppColors.textSecondary))
              else
                ...nutritionNotes.map((n) => _NoteCard(note: n)),
            ],
          ],
        );
      },
    );
  }

  void _showAddNoteDialog(BuildContext context, WidgetRef ref, String type) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: Text('Add ${type[0].toUpperCase()}${type.substring(1)} Note',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter note...',
            hintStyle: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (ctrl.text.trim().isEmpty) return;
              try {
                final user = ref.read(currentUserProvider);
                final newNote = NoteModel(
                  id: 'note-${DateTime.now().millisecondsSinceEpoch}',
                  clientId: client.id,
                  authorId: user?.id ?? 'admin-01',
                  kind: type,
                  visibility: 'staff_all',
                  body: ctrl.text.trim(),
                  version: 1,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                MockData.notes.insert(0, newNote);
                if (SupabaseConstants.isConfigured) {
                  await Supabase.instance.client.from(SupabaseConstants.notesTable).insert(newNote.toJson());
                }
                ref.invalidate(_clientNotesProvider(client.id));
              } catch (_) {}
            },
            child: const Text('Save', style: TextStyle(color: AppColors.brandOrange)),
          ),
        ],
      ),
    );
  }
}

final _clientNotesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, clientId) async {
  final memoryNotes = MockData.notes
      .where((n) => n.clientId == clientId)
      .map((n) => {
            'id': n.id,
            'type': n.kind,
            'content': n.body,
            'created_at': n.createdAt.toIso8601String(),
          })
      .toList();
  if (!SupabaseConstants.isConfigured) return memoryNotes;
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.notesTable)
        .select()
        .eq('client_id', clientId)
        .order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.isEmpty ? memoryNotes : list;
  } catch (_) {
    return memoryNotes;
  }
});

class _NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;

  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final createdAt = note['created_at'] != null ? DateTime.tryParse(note['created_at']) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (createdAt != null)
            Text(DateFormat('dd MMM yyyy, hh:mm a').format(createdAt),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 6),
          Text(note['content'] as String? ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// NUTRITION TAB
// ─────────────────────────────────────────────────────────
class _NutritionTab extends ConsumerWidget {
  final ClientModel client;

  const _NutritionTab({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (client.nutritionistId == null) {
      return const EmptyState(
        message: 'No nutritionist assigned to this client.',
        icon: Icons.restaurant_outlined,
      );
    }

    final checkinsAsync = ref.watch(_nutritionCheckinsProvider(client.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Nutritionist info card
        _InfoCard(
          title: 'Nutritionist',
          children: [
            _InfoRow(label: 'ID', value: client.nutritionistId!),
          ],
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Check-ins'),
        checkinsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandOrange, strokeWidth: 2)),
          error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.error)),
          data: (checkins) {
            if (checkins.isEmpty) {
              return const Text('No check-ins recorded.', style: TextStyle(color: AppColors.textSecondary));
            }
            return Column(
              children: checkins.map((c) => _CheckinTile(checkin: c)).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        // Diet plan placeholder
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Diet Plan', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              const Text('No diet plan assigned yet.', style: TextStyle(color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/nutrition/diet-plan/new?clientId=${client.id}'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Assign Diet Plan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandOrange,
                  side: const BorderSide(color: AppColors.brandOrange),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final _nutritionCheckinsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, clientId) async {
  final fallbackCheckins = [
    {
      'id': 'chk-01',
      'compliance': '90% Adherence',
      'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    },
    {
      'id': 'chk-02',
      'compliance': '85% Adherence',
      'created_at': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
    },
  ];
  if (!SupabaseConstants.isConfigured) return fallbackCheckins;
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.nutritionCheckinsTable)
        .select()
        .eq('client_id', clientId)
        .order('created_at', ascending: false)
        .limit(10);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.isEmpty ? fallbackCheckins : list;
  } catch (_) {
    return fallbackCheckins;
  }
});

class _CheckinTile extends StatelessWidget {
  final Map<String, dynamic> checkin;

  const _CheckinTile({required this.checkin});

  @override
  Widget build(BuildContext context) {
    final date = checkin['created_at'] != null ? DateTime.tryParse(checkin['created_at']) : null;
    final compliance = checkin['compliance'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              date != null ? DateFormat('dd MMM yyyy').format(date) : '—',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
          if (compliance != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(compliance,
                  style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// HISTORY TAB
// ─────────────────────────────────────────────────────────
class _HistoryTab extends ConsumerWidget {
  final ClientModel client;

  const _HistoryTab({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(clientSubscriptionsProvider(client.id));

    return subsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.error))),
      data: (subs) {
        if (subs.isEmpty) {
          return const EmptyState(message: 'No subscription history.', icon: Icons.history);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: subs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final sub = subs[i];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Plan: ${sub.planId}',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      StatusChip(status: sub.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${DateFormat('dd MMM yyyy').format(sub.startDate)} – ${DateFormat('dd MMM yyyy').format(sub.effectiveEndDate)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text('${sub.totalSessions} sessions total',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  if (sub.deactivationReason != null) ...[
                    const SizedBox(height: 4),
                    Text('Reason: ${sub.deactivationReason}',
                        style: const TextStyle(color: AppColors.error, fontSize: 12)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// SHARED HELPER WIDGETS
// ─────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _InfoCard({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
