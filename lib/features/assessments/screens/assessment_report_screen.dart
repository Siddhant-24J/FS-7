import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/assessment_model.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_cards.dart';
import '../../clients/providers/clients_provider.dart';

class AssessmentReportScreen extends ConsumerWidget {
  final String clientId;
  final String assessmentId;

  const AssessmentReportScreen({
    super.key,
    required this.clientId,
    required this.assessmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientProvider(clientId));
    final assessmentsAsync = ref.watch(clientAssessmentsProvider(clientId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share('FS-7 Assessment Report for $clientId');
            },
          ),
        ],
      ),
      body: assessmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (assessments) {
          if (assessments.isEmpty) {
            return const EmptyState(message: 'No assessment data found.', icon: Icons.assignment);
          }
          final current = assessments.firstWhere(
            (a) => a.id == assessmentId,
            orElse: () => assessments.first,
          );
          final baseline = assessments.firstWhere(
            (a) => a.type == 'baseline',
            orElse: () => current,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Headline FS-7 Score card
              Card(
                color: AppColors.surfaceRaised,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('FS-7 FITNESS SCORE',
                          style: TextStyle(
                              letterSpacing: 1.5,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandOrange)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${current.fs7Score?.toStringAsFixed(0) ?? "—"}',
                            style: const TextStyle(
                                fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.brandOrange),
                          ),
                          const Text(' / 100',
                              style: TextStyle(fontSize: 20, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Assessed on ${DateFormat("dd MMMM yyyy").format(current.testDate)} • ${current.typeLabel}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const SectionHeader(title: 'Key Metrics Comparison'),

              _comparisonRow('Weight', '${baseline.weightKg ?? "—"} kg', '${current.weightKg ?? "—"} kg',
                  baseline: baseline.weightKg, final_: current.weightKg, lowerIsBetter: true),
              _comparisonRow('Waist', '${baseline.waistWidest ?? "—"} cm', '${current.waistWidest ?? "—"} cm',
                  baseline: baseline.waistWidest, final_: current.waistWidest, lowerIsBetter: true),
              _comparisonRow('Push-ups', '${baseline.pushupsCount ?? "—"}', '${current.pushupsCount ?? "—"}',
                  baseline: baseline.pushupsCount?.toDouble(),
                  final_: current.pushupsCount?.toDouble(),
                  lowerIsBetter: false),
              _comparisonRow(
                  'Squats', '${baseline.squatsCount ?? "—"}', '${current.squatsCount ?? "—"}',
                  baseline: baseline.squatsCount?.toDouble(),
                  final_: current.squatsCount?.toDouble(),
                  lowerIsBetter: false),

              const SizedBox(height: 24),
              const SectionHeader(title: 'Body Composition & Cardio Details'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _detailTile('Primary Goal', current.goal ?? 'General fitness'),
                      const Divider(),
                      _detailTile('Blood Pressure',
                          '${current.systolic ?? "—"}/${current.diastolic ?? "—"} mmHg'),
                      const Divider(),
                      _detailTile('Resting Heart Rate', '${current.restingHeartRate ?? "—"} bpm'),
                      const Divider(),
                      _detailTile('Rockport 1-mile Time', current.rockportTime ?? '—'),
                      const Divider(),
                      _detailTile('End Test Pulse', '${current.rockportPulse ?? "—"} bpm'),
                      const Divider(),
                      _detailTile('1-min Recovery Heart Rate', '${current.recoveryHeartRate ?? "—"} bpm'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const SectionHeader(title: 'Trainer Remarks'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    current.trainerRemarks ?? 'No specific remarks entered for this assessment.',
                    style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.textPrimary),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              AppButton(
                label: 'Export PDF Report',
                icon: Icons.picture_as_pdf,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generating PDF Report...')),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _comparisonRow(
    String label,
    String baselineVal,
    String currentVal, {
    double? baseline,
    double? final_,
    bool lowerIsBetter = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text('Base: $baselineVal',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(width: 16),
            Text('Now: $currentVal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            ImprovementArrow(
              baseline: baseline,
              final_: final_,
              lowerIsBetter: lowerIsBetter,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailTile(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

