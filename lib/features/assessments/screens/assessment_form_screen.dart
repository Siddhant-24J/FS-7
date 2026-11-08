import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/formulas/fitness_formulas.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/assessment_model.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/services/server_functions_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../../clients/providers/clients_provider.dart';

class AssessmentFormScreen extends ConsumerStatefulWidget {
  final String clientId;
  final String subscriptionId;
  final String type; // baseline, final, checkpoint

  const AssessmentFormScreen({
    super.key,
    required this.clientId,
    required this.subscriptionId,
    required this.type,
  });

  @override
  ConsumerState<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends ConsumerState<AssessmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Basics
  DateTime _testDate = DateTime.now();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _selectedGoal = AppConstants.fitnessGoals.first;

  // 2. Blood Pressure
  final _restingHrCtrl = TextEditingController();
  final _systolicCtrl = TextEditingController();
  final _diastolicCtrl = TextEditingController();

  // 3. Body Measurements (cm)
  final _neckCtrl = TextEditingController();
  final _chestCtrl = TextEditingController();
  final _upperAbdomenCtrl = TextEditingController();
  final _waistWidestCtrl = TextEditingController();
  final _waistNarrowestCtrl = TextEditingController();
  final _hipCtrl = TextEditingController();
  final _armLCtrl = TextEditingController();
  final _armRCtrl = TextEditingController();
  final _thighLCtrl = TextEditingController();
  final _thighRCtrl = TextEditingController();
  final _calfLCtrl = TextEditingController();
  final _calfRCtrl = TextEditingController();

  // 4. Cardio (Rockport)
  final _rockportTimeCtrl = TextEditingController(text: '11:34');
  final _rockportPulseCtrl = TextEditingController();

  // 5. Recovery (YMCA)
  final _recoveryHrCtrl = TextEditingController();

  // 6. Muscular Endurance
  final _pushupsCtrl = TextEditingController();
  final _squatsCtrl = TextEditingController();
  final _pullupsCtrl = TextEditingController();
  final _pullupsTimeCtrl = TextEditingController(text: '60');

  // 7. Flexibility
  String _quadsFlex = 'Fair';
  String _hamsFlex = 'Fair';
  String _hipFlex = 'Fair';
  String _shoulderFlex = 'Fair';

  // 8. Overall Remarks
  final _remarksCtrl = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _restingHrCtrl.dispose();
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    _neckCtrl.dispose();
    _chestCtrl.dispose();
    _upperAbdomenCtrl.dispose();
    _waistWidestCtrl.dispose();
    _waistNarrowestCtrl.dispose();
    _hipCtrl.dispose();
    _armLCtrl.dispose();
    _armRCtrl.dispose();
    _thighLCtrl.dispose();
    _thighRCtrl.dispose();
    _calfLCtrl.dispose();
    _calfRCtrl.dispose();
    _rockportTimeCtrl.dispose();
    _rockportPulseCtrl.dispose();
    _recoveryHrCtrl.dispose();
    _pushupsCtrl.dispose();
    _squatsCtrl.dispose();
    _pullupsCtrl.dispose();
    _pullupsTimeCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientAsync = ref.watch(clientProvider(widget.clientId));

    return clientAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (client) {
        if (client == null) {
          return const Scaffold(body: Center(child: Text('Client not found')));
        }

        // Live Calculations
        final weightKg = double.tryParse(_weightCtrl.text) ?? 0.0;
        final heightCm = double.tryParse(_heightCtrl.text) ?? 0.0;
        final age = client.age;
        final gender = client.gender;

        // BMI
        final bmi = FitnessFormulas.calculateBMI(weightKg, heightCm);
        final bmiCat = bmi > 0 ? FitnessFormulas.bmiCategory(bmi) : '';
        final healthyRange = heightCm > 0 ? FitnessFormulas.healthyWeightRange(heightCm) : [0.0, 0.0];

        // BP
        final systolic = int.tryParse(_systolicCtrl.text) ?? 0;
        final diastolic = int.tryParse(_diastolicCtrl.text) ?? 0;
        final bpCat = (systolic > 0 && diastolic > 0)
            ? FitnessFormulas.bpCategory(systolic, diastolic)
            : '';
        final isCrisis = FitnessFormulas.isBloodPressureCrisis(systolic, diastolic);

        // Body Measurements Auto
        final waist = double.tryParse(_waistNarrowestCtrl.text.isNotEmpty
                ? _waistNarrowestCtrl.text
                : _waistWidestCtrl.text) ??
            0.0;
        final hip = double.tryParse(_hipCtrl.text) ?? 0.0;
        final neck = double.tryParse(_neckCtrl.text) ?? 0.0;

        final whr = (waist > 0 && hip > 0) ? FitnessFormulas.waistToHipRatio(waist, hip) : 0.0;
        final whrRisk = whr > 0 ? FitnessFormulas.waistHipRiskLabel(whr, gender) : '';

        final whtr = (waist > 0 && heightCm > 0) ? FitnessFormulas.waistToHeightRatio(waist, heightCm) : 0.0;

        double bodyFatPct = 0.0;
        if (heightCm > 0 && waist > 0 && neck > 0) {
          if (gender.toLowerCase() == 'male') {
            bodyFatPct = FitnessFormulas.bodyFatPercentMale(
                waistCm: waist, neckCm: neck, heightCm: heightCm);
          } else if (hip > 0) {
            bodyFatPct = FitnessFormulas.bodyFatPercentFemale(
                waistCm: waist, hipCm: hip, neckCm: neck, heightCm: heightCm);
          }
        }
        if (bodyFatPct.isNaN || bodyFatPct.isInfinite || bodyFatPct < 0) bodyFatPct = 0.0;

        final bodyFatCat = bodyFatPct > 0 ? FitnessFormulas.bodyFatCategory(bodyFatPct, gender) : '';
        final fatMassKg = FitnessFormulas.fatMass(weightKg, bodyFatPct);
        final leanMassKg = FitnessFormulas.leanMass(weightKg, fatMassKg);

        // Cardio
        final walkTimeMin = FitnessFormulas.parseTimeToMinutes(_rockportTimeCtrl.text);
        final walkPulse = int.tryParse(_rockportPulseCtrl.text) ?? 0;
        double vo2 = 0.0;
        if (weightKg > 0 && walkTimeMin > 0 && walkPulse > 0) {
          vo2 = FitnessFormulas.vo2max(
            weightKg: weightKg,
            age: age,
            gender: gender,
            timeMinutes: walkTimeMin,
            heartRate: walkPulse,
          );
        }
        if (vo2.isNaN || vo2.isInfinite || vo2 < 0) vo2 = 0.0;
        final vo2Cat = vo2 > 0 ? FitnessFormulas.vo2maxCategory(vo2, age, gender) : '';
        final maxHr = FitnessFormulas.maxHeartRate(age);

        // Recovery
        final recHr = int.tryParse(_recoveryHrCtrl.text) ?? 0;
        final recCat = recHr > 0 ? FitnessFormulas.recoveryCategory(recHr, age, gender) : '';

        // Muscular endurance
        final pushups = int.tryParse(_pushupsCtrl.text) ?? 0;
        final pushupRating = pushups > 0 ? FitnessFormulas.pushupRating(pushups, age, gender) : '';

        // Flexibility
        final flexScore = FitnessFormulas.flexibilityScore(
            [_quadsFlex, _hamsFlex, _hipFlex, _shoulderFlex]);

        // FS-7 Fitness Score
        final fs7ScoreVal = FitnessFormulas.fs7Score(
          vo2maxCategory: vo2Cat.isNotEmpty ? vo2Cat : null,
          bodyFatCategory: bodyFatCat.isNotEmpty ? bodyFatCat : null,
          pushupRating: pushupRating.isNotEmpty ? pushupRating : null,
          flexibilityRatings: [_quadsFlex, _hamsFlex, _hipFlex, _shoulderFlex],
          recoveryCategory: recCat.isNotEmpty ? recCat : null,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.type.toUpperCase()} Assessment - ${client.fullName}'),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FS-7 Fitness Score',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text(
                        '${fs7ScoreVal.toStringAsFixed(1)} / 100',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.brandOrange),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AppButton(
                    label: 'Save Assessment',
                    isLoading: _isSaving,
                    onPressed: () => _saveAssessment(client, fs7ScoreVal, {
                      'bmi': bmi,
                      'bmi_category': bmiCat,
                      'body_fat_pct': bodyFatPct,
                      'body_fat_category': bodyFatCat,
                      'fat_mass_kg': fatMassKg,
                      'lean_mass_kg': leanMassKg,
                      'vo2max': vo2,
                      'vo2max_category': vo2Cat,
                      'max_hr': maxHr,
                      'recovery_category': recCat,
                      'pushup_rating': pushupRating,
                      'flexibility_score': flexScore,
                      'fs7_score': fs7ScoreVal,
                    }),
                  ),
                ),
              ],
            ),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. BASICS
                _sectionHeader('1. Basics'),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _weightCtrl,
                        label: 'Weight (kg)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _heightCtrl,
                        label: 'Height (cm)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppDropdownField<String>(
                  label: 'Primary Goal',
                  value: _selectedGoal,
                  items: AppConstants.fitnessGoals
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedGoal = v ?? _selectedGoal),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AutoCalcField(
                        label: 'BMI',
                        value: bmi > 0 ? '${bmi.toStringAsFixed(1)} ($bmiCat)' : '—',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AutoCalcField(
                        label: 'Healthy Weight Range',
                        value: healthyRange[0] > 0
                            ? '${healthyRange[0].toStringAsFixed(1)} - ${healthyRange[1].toStringAsFixed(1)} kg'
                            : '—',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                // 2. BLOOD PRESSURE
                _sectionHeader('2. Blood Pressure & Resting HR'),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _restingHrCtrl,
                        label: 'Resting HR (bpm)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppTextField(
                        controller: _systolicCtrl,
                        label: 'Systolic (mmHg)',
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppTextField(
                        controller: _diastolicCtrl,
                        label: 'Diastolic (mmHg)',
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AutoCalcField(
                  label: 'Blood Pressure Category',
                  value: bpCat.isNotEmpty ? bpCat : '—',
                  valueColor: isCrisis ? AppColors.error : null,
                ),
                if (isCrisis) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('⚠️ HYPERTENSIVE CRISIS: Refer client to medical doctor immediately.',
                        style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],

                const SizedBox(height: 24),
                // 3. BODY MEASUREMENTS
                _sectionHeader('3. Body Measurements (cm)'),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _neckCtrl,
                        label: 'Neck',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _chestCtrl,
                        label: 'Chest',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _waistNarrowestCtrl,
                        label: 'Waist (Natural/Narrowest)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _waistWidestCtrl,
                        label: 'Waist (Widest)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _hipCtrl,
                        label: 'Hip',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _upperAbdomenCtrl,
                        label: 'Upper Abdomen',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _armLCtrl,
                        label: 'Arm Left',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _armRCtrl,
                        label: 'Arm Right',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _thighLCtrl,
                        label: 'Thigh Left',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _thighRCtrl,
                        label: 'Thigh Right',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _calfLCtrl,
                        label: 'Calf Left',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _calfRCtrl,
                        label: 'Calf Right',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AutoCalcField(
                        label: 'Body Fat % (US Navy)',
                        value: bodyFatPct > 0
                            ? '${bodyFatPct.toStringAsFixed(1)}% ($bodyFatCat)'
                            : '—',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AutoCalcField(
                        label: 'Lean Mass',
                        value: leanMassKg > 0 ? '${leanMassKg.toStringAsFixed(1)} kg' : '—',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AutoCalcField(
                        label: 'Waist-to-Hip Ratio',
                        value: whr > 0 ? '${whr.toStringAsFixed(2)} ($whrRisk)' : '—',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AutoCalcField(
                        label: 'Waist-to-Height',
                        value: whtr > 0 ? whtr.toStringAsFixed(2) : '—',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                // 4. CARDIO FITNESS (Rockport)
                _sectionHeader('4. Cardio Fitness (Rockport 1-mile walk)'),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _rockportTimeCtrl,
                        label: 'Time (MM:SS)',
                        hint: 'e.g. 11:34',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _rockportPulseCtrl,
                        label: 'End Pulse (bpm)',
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AutoCalcField(
                        label: 'VO2max (ml/kg/min)',
                        value: vo2 > 0 ? '${vo2.toStringAsFixed(1)} ($vo2Cat)' : '—',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AutoCalcField(
                        label: 'Max Heart Rate',
                        value: '$maxHr bpm',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                // 5. RECOVERY (YMCA)
                _sectionHeader('5. Recovery (YMCA 3-minute step test)'),
                AppTextField(
                  controller: _recoveryHrCtrl,
                  label: '1-min Recovery Heart Rate (bpm)',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                AutoCalcField(
                  label: 'Recovery Category',
                  value: recCat.isNotEmpty ? recCat : '—',
                ),

                const SizedBox(height: 24),
                // 6. MUSCULAR ENDURANCE
                _sectionHeader('6. Muscular Endurance'),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _pushupsCtrl,
                        label: 'Push-ups in 60s',
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AutoCalcField(
                        label: 'Push-up Rating',
                        value: pushupRating.isNotEmpty ? pushupRating : '—',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _squatsCtrl,
                        label: 'Squats in 60s',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _pullupsCtrl,
                        label: 'Pull-ups Count',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                // 7. FLEXIBILITY
                _sectionHeader('7. Flexibility (Poor, Fair, Good, Excellent)'),
                Row(
                  children: [
                    Expanded(
                      child: AppDropdownField<String>(
                        label: 'Quadriceps',
                        value: _quadsFlex,
                        items: AppConstants.flexibilityRatings
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (v) => setState(() => _quadsFlex = v ?? _quadsFlex),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDropdownField<String>(
                        label: 'Hamstrings',
                        value: _hamsFlex,
                        items: AppConstants.flexibilityRatings
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (v) => setState(() => _hamsFlex = v ?? _hamsFlex),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppDropdownField<String>(
                        label: 'Hip Flexors',
                        value: _hipFlex,
                        items: AppConstants.flexibilityRatings
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (v) => setState(() => _hipFlex = v ?? _hipFlex),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDropdownField<String>(
                        label: 'Shoulder Reach',
                        value: _shoulderFlex,
                        items: AppConstants.flexibilityRatings
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (v) => setState(() => _shoulderFlex = v ?? _shoulderFlex),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AutoCalcField(
                  label: 'Flexibility Score',
                  value: '${flexScore.toStringAsFixed(0)} / 100',
                ),

                const SizedBox(height: 24),
                // 8. TRAINER REMARKS
                _sectionHeader('8. Trainer Remarks & FS-7 Score'),
                AppTextField(
                  controller: _remarksCtrl,
                  label: 'Trainer Remarks',
                  maxLines: 3,
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandOrange),
      ),
    );
  }

  Future<void> _saveAssessment(
    ClientModel client,
    double fs7Score,
    Map<String, dynamic> calculatedJson,
  ) async {
    setState(() => _isSaving = true);
    final user = ref.read(currentUserProvider);

    try {
      final service = ref.read(serverFunctionsServiceProvider);
      await service.saveAssessment(
        clientId: widget.clientId,
        subscriptionId: widget.subscriptionId,
        type: widget.type,
        rawInputs: {
          'weight_kg': double.tryParse(_weightCtrl.text),
          'height_cm': double.tryParse(_heightCtrl.text),
          'goal': _selectedGoal,
          'resting_heart_rate': int.tryParse(_restingHrCtrl.text),
          'systolic': int.tryParse(_systolicCtrl.text),
          'diastolic': int.tryParse(_diastolicCtrl.text),
          'neck': double.tryParse(_neckCtrl.text),
          'waist_widest': double.tryParse(_waistWidestCtrl.text),
          'hip': double.tryParse(_hipCtrl.text),
          'rockport_time': _rockportTimeCtrl.text,
          'rockport_pulse': int.tryParse(_rockportPulseCtrl.text),
          'pushups_count': int.tryParse(_pushupsCtrl.text),
        },
        remarks: _remarksCtrl.text,
        assessedBy: user?.id ?? 'trainer-01',
      );

      // Invalidate queries
      ref.invalidate(clientAssessmentsProvider(widget.clientId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assessment saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } on BusinessException catch (be) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(be.message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save assessment: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

