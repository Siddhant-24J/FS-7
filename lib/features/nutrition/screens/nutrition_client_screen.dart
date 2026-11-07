import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formulas/fitness_formulas.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/client_model.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_cards.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../clients/providers/clients_provider.dart';

class NutritionClientScreen extends ConsumerStatefulWidget {
  final String clientId;

  const NutritionClientScreen({super.key, required this.clientId});

  @override
  ConsumerState<NutritionClientScreen> createState() => _NutritionClientScreenState();
}

class _NutritionClientScreenState extends ConsumerState<NutritionClientScreen> {
  final _noteCtrl = TextEditingController();
  String _activityLevel = 'Moderate (3–5 days/week)';

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientAsync = ref.watch(clientProvider(widget.clientId));
    final assessmentsAsync = ref.watch(clientAssessmentsProvider(widget.clientId));

    return clientAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (client) {
        if (client == null) return const Scaffold(body: Center(child: Text('Client not found')));

        final latestAssessment = assessmentsAsync.valueOrNull?.firstOrNull;
        final weightKg = latestAssessment?.weightKg ?? 70.0;
        final heightCm = latestAssessment?.heightCm ?? 170.0;
        final bmr = FitnessFormulas.bmr(
          weightKg: weightKg,
          heightCm: heightCm,
          age: client.age,
          gender: client.gender,
        );
        final maintenanceCals = FitnessFormulas.maintenanceCalories(bmr, _activityLevel);

        return Scaffold(
          appBar: AppBar(
            title: Text('Nutrition: ${client.fullName}'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Client overview card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.surfaceRaised,
                        child: Text(
                          '${client.firstName[0]}${client.lastName[0]}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandOrange),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(client.fullName, style: Theme.of(context).textTheme.titleLarge),
                            Text('${client.gender}, ${client.age} yrs • ${client.phonePrimary}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const SectionHeader(title: 'Metabolic & Calorie Calculations'),

              Card(
                color: AppColors.surfaceRaised,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('BMR (Mifflin-St Jeor)',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text('${bmr.toStringAsFixed(0)} kcal',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brandOrange)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Daily Maintenance',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text('${maintenanceCals.toStringAsFixed(0)} kcal',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppDropdownField<String>(
                        label: 'Activity Multiplier',
                        value: _activityLevel,
                        items: FitnessFormulas.activityFactors.keys
                            .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                            .toList(),
                        onChanged: (v) => setState(() => _activityLevel = v ?? _activityLevel),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const SectionHeader(title: 'Diet Plan (Placeholder)'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: AppColors.brandOrange),
                  title: const Text('Upload Diet Plan Document'),
                  subtitle: const Text('Select PDF or photo of customized meal plan'),
                  trailing: IconButton(
                    icon: const Icon(Icons.upload_file),
                    onPressed: () {},
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const SectionHeader(title: 'Nutritionist Notes'),
              AppTextField(
                controller: _noteCtrl,
                label: 'Write Consultation Notes',
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Save Note',
                icon: Icons.check,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Note logged successfully!')),
                  );
                  _noteCtrl.clear();
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

