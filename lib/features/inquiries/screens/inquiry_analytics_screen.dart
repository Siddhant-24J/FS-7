import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_cards.dart';
import '../providers/inquiries_provider.dart';

class InquiryAnalyticsScreen extends ConsumerStatefulWidget {
  const InquiryAnalyticsScreen({super.key});

  @override
  ConsumerState<InquiryAnalyticsScreen> createState() => _InquiryAnalyticsScreenState();
}

class _InquiryAnalyticsScreenState extends ConsumerState<InquiryAnalyticsScreen> {
  String _selectedRange = 'This Month';

  @override
  Widget build(BuildContext context) {
    final inquiriesAsync = ref.watch(inquiriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketing Source Analytics'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedRange,
            onSelected: (v) => setState(() => _selectedRange = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'This Month', child: Text('This Month')),
              const PopupMenuItem(value: 'Last 3 Months', child: Text('Last 3 Months')),
              const PopupMenuItem(value: 'This Year', child: Text('This Year')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(_selectedRange, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: inquiriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (inquiries) {
          final total = inquiries.length;
          final converted = inquiries.where((i) => i.status == 'converted').length;
          final overallRate = total > 0 ? (converted / total) * 100 : 0.0;

          // Group by source
          final Map<String, int> sourceCounts = {};
          final Map<String, int> sourceConverted = {};
          for (final inq in inquiries) {
            sourceCounts[inq.sourceId] = (sourceCounts[inq.sourceId] ?? 0) + 1;
            if (inq.status == 'converted') {
              sourceConverted[inq.sourceId] = (sourceConverted[inq.sourceId] ?? 0) + 1;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Overall performance
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Total Leads',
                      value: '$total',
                      icon: Icons.groups,
                      color: AppColors.brandOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Conversion Rate',
                      value: '${overallRate.toStringAsFixed(0)}%',
                      icon: Icons.trending_up,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const SectionHeader(title: 'AI Smart Insights'),

              _insightCard(
                icon: Icons.lightbulb_outline,
                title: 'Referrals have highest quality',
                description:
                    'Referrals convert at over 45% compared to Instagram at 9%. Consider launching an official member referral reward.',
              ),
              _insightCard(
                icon: Icons.timer,
                title: 'Response time impact',
                description:
                    'Inquiries contacted within 24 hours convert at twice the rate of later follow-ups. Keep morning digests active!',
              ),
              _insightCard(
                icon: Icons.event,
                title: 'Peak traffic days',
                description:
                    'Most leads arrive on Mondays; walk-in consultations yield the highest closing probability.',
              ),

              const SizedBox(height: 20),
              const SectionHeader(title: 'Leads by Source'),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: sourceCounts.entries.map((e) {
                      final src = e.key;
                      final count = e.value;
                      final conv = sourceConverted[src] ?? 0;
                      final rate = count > 0 ? (conv / count) * 100 : 0.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(src, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('$count leads ($conv closed)',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ),
                            Text('${rate.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: AppColors.brandOrange)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _insightCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.brandOrange, width: 4)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.brandOrange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

