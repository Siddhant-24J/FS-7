import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/document_model.dart';
import '../../../widgets/common/app_cards.dart';

final auditLogsProvider = FutureProvider<List<AuditLogModel>>((ref) async {
  if (!SupabaseConstants.isConfigured) {
    return MockData.auditLogs;
  }
  try {
    final res = await Supabase.instance.client
        .from(SupabaseConstants.auditLogTable)
        .select()
        .order('at', ascending: false)
        .limit(100);
    return (res as List).map((j) => AuditLogModel.fromJson(j)).toList();
  } catch (_) {
    return MockData.auditLogs;
  }
});

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Audit Trail'),
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (logs) {
          if (logs.isEmpty) {
            return const EmptyState(
              message: 'No audit records logged yet.',
              icon: Icons.receipt_long,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final log = logs[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.brandOrange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log.tableName.toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.brandOrange, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(log.at),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Field: ${log.field}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (log.oldValue != null) ...[
                            Text('Old: ${log.oldValue}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.error, decoration: TextDecoration.lineThrough)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                          ],
                          Text('New: ${log.newValue ?? "—"}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

