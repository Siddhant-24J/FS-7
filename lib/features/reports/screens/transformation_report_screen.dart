import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/services/pdf_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/assessment_model.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_cards.dart';
import '../../../widgets/common/fs7_logo.dart';
import '../../clients/providers/clients_provider.dart';

class TransformationReportScreen extends ConsumerWidget {
  final String clientId;
  final String subscriptionId;

  const TransformationReportScreen({
    super.key,
    required this.clientId,
    required this.subscriptionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientProvider(clientId));
    final subAsync = ref.watch(activeSubscriptionProvider(clientId));
    final assessmentsAsync = ref.watch(clientAssessmentsProvider(clientId));
    final attendanceAsync = ref.watch(clientAttendanceProvider(subscriptionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transformation Report'),
      ),
      body: clientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (client) {
          if (client == null) return const Center(child: Text('Client not found'));

          return assessmentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (assessments) {
              if (assessments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.assessment_outlined, size: 56, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        const Text(
                          'No Assessments Completed Yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'A baseline fitness assessment is needed to generate the scientific Transformation Report.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandOrange),
                          icon: const Icon(Icons.add),
                          label: const Text('Start Baseline Assessment'),
                          onPressed: () => context.push(
                            '/assessments/new?clientId=$clientId&subscriptionId=$subscriptionId&type=baseline',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final baseline = assessments.firstWhere(
                (a) => a.type == 'baseline',
                orElse: () => assessments.last,
              );
              final finalAssessment = assessments.firstWhere(
                (a) => a.type == 'final',
                orElse: () => assessments.first,
              );

              final attendances = attendanceAsync.valueOrNull ?? [];
              final presentCount = attendances.where((a) => a.isPresent || a.isMakeup).length;
              final sub = subAsync.valueOrNull;
              final total = sub?.totalSessions ?? 36;
              final attendancePct = total > 0 ? (presentCount / total) * 100 : 0.0;

              final scoreChange = (finalAssessment.fs7Score ?? 0) - (baseline.fs7Score ?? 0);

              // Auto-written summary sentences
              final summarySentences = <String>[];
              if (baseline.weightKg != null && finalAssessment.weightKg != null) {
                final diff = finalAssessment.weightKg! - baseline.weightKg!;
                if (diff.abs() > 0.2) {
                  summarySentences.add(diff < 0
                      ? 'Body weight reduced by ${diff.abs().toStringAsFixed(1)} kg.'
                      : 'Body weight increased by ${diff.toStringAsFixed(1)} kg.');
                }
              }
              if (baseline.waistWidest != null && finalAssessment.waistWidest != null) {
                final diff = finalAssessment.waistWidest! - baseline.waistWidest!;
                if (diff.abs() > 0.5) {
                  summarySentences.add(diff < 0
                      ? 'Waist reduced by ${diff.abs().toStringAsFixed(1)} cm.'
                      : 'Waist circumference changed by ${diff.toStringAsFixed(1)} cm.');
                }
              }
              if (scoreChange != 0) {
                summarySentences.add(
                    'Overall FS-7 Fitness Score ${scoreChange > 0 ? "improved by" : "changed by"} ${scoreChange.abs().toStringAsFixed(0)} points.');
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Cover Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const FS7Logo(size: 64, showText: false),
                          const SizedBox(height: 12),
                          Text(client.fullName, style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text('Personal Training • ${client.gender}, ${client.age} yrs',
                              style: const TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceRaised,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text('Sessions: $presentCount / $total'),
                                Text('Consistency: ${attendancePct.toStringAsFixed(0)}%'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Headline Score
                  Card(
                    color: AppColors.surfaceRaised,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('BASELINE',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text('${baseline.fs7Score?.toStringAsFixed(0) ?? "—"}',
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Icon(
                            scoreChange >= 0 ? Icons.trending_up : Icons.trending_down,
                            size: 36,
                            color: scoreChange >= 0 ? AppColors.success : AppColors.error,
                          ),
                          Column(
                            children: [
                              const Text('FINAL',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brandOrange)),
                              const SizedBox(height: 4),
                              Text('${finalAssessment.fs7Score?.toStringAsFixed(0) ?? "—"}',
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brandOrange)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Auto-written Summary
                  const SectionHeader(title: 'Transformation Summary'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final sentence in summarySentences) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ',
                                    style: TextStyle(
                                        color: AppColors.brandOrange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Expanded(child: Text(sentence, style: const TextStyle(fontSize: 14))),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Print / Save PDF Report',
                    icon: Icons.print,
                    onPressed: () async {
                      if (sub != null) {
                        final pdfBytes = await PdfService.generateTransformationReportPdf(
                          client: client,
                          subscription: sub,
                          baseline: baseline,
                          finalAssessment: finalAssessment,
                          completedSessions: presentCount,
                          attendancePercent: attendancePct,
                        );
                        await Printing.layoutPdf(onLayout: (_) => pdfBytes);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

