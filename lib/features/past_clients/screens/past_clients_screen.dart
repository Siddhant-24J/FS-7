import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/services/server_functions_service.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/plan_model.dart';
import '../../../widgets/common/app_cards.dart';
import '../../auth/providers/auth_provider.dart';
import '../../clients/providers/clients_provider.dart';
import '../../timetable/providers/timetable_provider.dart';

class PastClientsScreen extends ConsumerWidget {
  const PastClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Clients'),
      ),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (clients) {
          final pastClients = clients
              .where((c) => c.status == 'completed' || c.status == 'deactivated')
              .toList();

          if (pastClients.isEmpty) {
            return const EmptyState(
              message: 'No completed or deactivated clients yet',
              icon: Icons.history,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pastClients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final client = pastClients[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surfaceRaised,
                    child: Text(
                      client.initials,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(client.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${client.gender}, ${client.age} yrs • Status: ${client.status.toUpperCase()}'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandOrange,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => _showRenewDialog(context, ref, client),
                    child: const Text('Renew / Reactivate', style: TextStyle(fontSize: 12)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showRenewDialog(BuildContext context, WidgetRef ref, ClientModel client) {
    final prevSub = MockData.subscriptions.where((s) => s.clientId == client.id).firstOrNull;
    final prevSlot = MockData.slots.where((s) => s.clientId == client.id).firstOrNull;

    String selectedPlanId = prevSub?.planId ?? PlanModel.defaultPlans.first.id;
    String selectedTrainerId = client.trainerId;
    int selectedHour = prevSlot?.hourStart ?? 7;
    String selectedPattern = prevSlot?.pattern ?? 'A5';
    DateTime startDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          title: Text('Renew Plan: ${client.fullName}', style: const TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedPlanId,
                  dropdownColor: AppColors.surface,
                  decoration: const InputDecoration(labelText: 'Plan'),
                  items: PlanModel.defaultPlans.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.name} (${p.months}M • ${p.totalSessions} Sessions)'),
                  )).toList(),
                  onChanged: (v) => setState(() => selectedPlanId = v ?? selectedPlanId),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: MockData.trainers.any((t) => t.id == selectedTrainerId)
                      ? selectedTrainerId
                      : (MockData.trainers.isNotEmpty ? MockData.trainers.first.id : selectedTrainerId),
                  dropdownColor: AppColors.surface,
                  decoration: const InputDecoration(labelText: 'Trainer'),
                  items: MockData.trainers.isNotEmpty
                      ? MockData.trainers.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList()
                      : [DropdownMenuItem(value: selectedTrainerId, child: const Text('Default Trainer'))],
                  onChanged: (v) => setState(() => selectedTrainerId = v ?? selectedTrainerId),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedHour,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(labelText: 'Hour'),
                        items: List.generate(16, (i) => i + 6).map((h) => DropdownMenuItem(
                          value: h,
                          child: Text('${h.toString().padLeft(2, "0")}:00'),
                        )).toList(),
                        onChanged: (v) => setState(() => selectedHour = v ?? selectedHour),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedPattern,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(labelText: 'Pattern'),
                        items: const [
                          DropdownMenuItem(value: 'A5', child: Text('A5 (M-F)')),
                          DropdownMenuItem(value: 'M1', child: Text('M1 (MWF)')),
                          DropdownMenuItem(value: 'M2', child: Text('M2 (MWF)')),
                          DropdownMenuItem(value: 'T1', child: Text('T1 (TTS)')),
                          DropdownMenuItem(value: 'T2', child: Text('T2 (TTS)')),
                        ],
                        onChanged: (v) => setState(() => selectedPattern = v ?? selectedPattern),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start Date', style: TextStyle(fontSize: 13)),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(startDate)),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) setState(() => startDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandOrange),
              onPressed: () async {
                try {
                  final user = ref.read(currentUserProvider);
                  await ref.read(clientRepositoryProvider).renewSubscription(
                    clientId: client.id,
                    planId: selectedPlanId,
                    startDate: startDate,
                    hourStart: selectedHour,
                    pattern: selectedPattern,
                    trainerId: selectedTrainerId,
                    createdBy: user?.id ?? 'admin-01',
                  );
                  Navigator.pop(ctx);
                  ref.invalidate(clientsProvider);
                  ref.invalidate(clientProvider(client.id));
                  ref.invalidate(activeSubscriptionProvider(client.id));
                  ref.invalidate(clientSubscriptionsProvider(client.id));
                  ref.invalidate(allActiveSlotsProvider);
                  ref.invalidate(trainerSlotsProvider(selectedTrainerId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${client.fullName} renewed successfully! Slot booked at $selectedPattern.'),
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
              child: const Text('Confirm Renewal'),
            ),
          ],
        ),
      ),
    );
  }
}

