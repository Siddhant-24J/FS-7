import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/formulas/fitness_formulas.dart';
import '../../../core/formulas/slot_engine.dart';
import '../../../core/services/server_functions_service.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/plan_model.dart';
import '../../../data/models/user_model.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_cards.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../../timetable/providers/timetable_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../providers/clients_provider.dart';

enum WizardStepType {
  personal,
  emergency,
  program,
  trainer,
  nutritionist,
  plan,
  slot,
  payment,
  consent,
  review,
}

class AddClientWizardScreen extends ConsumerStatefulWidget {
  final String? sourceInquiryId;
  final String? initialName;
  final String? initialPhone;
  final String? initialProgram;

  const AddClientWizardScreen({
    super.key,
    this.sourceInquiryId,
    this.initialName,
    this.initialPhone,
    this.initialProgram,
  });

  @override
  ConsumerState<AddClientWizardScreen> createState() => _AddClientWizardScreenState();
}

class _AddClientWizardScreenState extends ConsumerState<AddClientWizardScreen> {
  int _currentStep = 0;

  // Step 1: Personal Details
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  DateTime _dob = DateTime.now().subtract(const Duration(days: 365 * 25));
  String _gender = 'Male';
  final _phonePrimaryCtrl = TextEditingController();
  final _phoneSecondaryCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Step 2: Emergency Contact
  final _emFirstNameCtrl = TextEditingController();
  final _emLastNameCtrl = TextEditingController();
  final _emAddressCtrl = TextEditingController();
  final _emPhoneCtrl = TextEditingController();

  // Step 3: Program Type
  String _programType = AppConstants.programTypes.first;

  // Step 4: Trainer
  String? _selectedTrainerId;

  // Step 5: Nutritionist
  String? _selectedNutritionistId;

  // Step 6: Plan & Start Date
  PlanModel? _selectedPlan;
  DateTime _startDate = DateTime.now();

  // Step 7: Slot
  int _selectedHour = 7;
  String _selectedPattern = AppConstants.patternM1;

  // Step 8: Payment Method
  String _paymentMethod = 'Online';

  // Step 9: Consent Signatures
  final GlobalKey<SfSignaturePadState> _memberSigKey = GlobalKey();
  final GlobalKey<SfSignaturePadState> _secondSigKey = GlobalKey();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      final parts = widget.initialName!.trim().split(' ');
      _firstNameCtrl.text = parts.first;
      if (parts.length > 1) {
        _lastNameCtrl.text = parts.sublist(1).join(' ');
      }
    }
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      _phonePrimaryCtrl.text = widget.initialPhone!;
    }
    if (widget.initialProgram != null && widget.initialProgram!.isNotEmpty) {
      _programType = widget.initialProgram!;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _addressCtrl.dispose();
    _phonePrimaryCtrl.dispose();
    _phoneSecondaryCtrl.dispose();
    _emailCtrl.dispose();
    _emFirstNameCtrl.dispose();
    _emLastNameCtrl.dispose();
    _emAddressCtrl.dispose();
    _emPhoneCtrl.dispose();
    super.dispose();
  }

  bool get _isNutritionOnly => _programType.trim().toLowerCase() == 'nutrition';
  bool get _isDual => _programType.trim() == 'Personal Training + Nutrition';
  bool get _needsTrainer => !_isNutritionOnly;
  bool get _needsSlot => _needsTrainer;
  bool get _isNutritionistRequired => _isNutritionOnly || _isDual;

  List<WizardStepType> get _activeSteps {
    final list = <WizardStepType>[
      WizardStepType.personal,
      WizardStepType.emergency,
      WizardStepType.program,
    ];
    if (_needsTrainer) {
      list.add(WizardStepType.trainer);
    }
    list.add(WizardStepType.nutritionist);
    list.add(WizardStepType.plan);
    if (_needsSlot) {
      list.add(WizardStepType.slot);
    }
    list.add(WizardStepType.payment);
    list.add(WizardStepType.consent);
    list.add(WizardStepType.review);
    return list;
  }

  int get _totalSteps => _activeSteps.length;
  WizardStepType get _currentStepType {
    final steps = _activeSteps;
    final safeIdx = _currentStep.clamp(0, steps.length - 1);
    return steps[safeIdx];
  }

  int get _calculatedAge => FitnessFormulas.calculateAge(_dob, DateTime.now());
  DateTime get _calculatedEndDate => _selectedPlan != null
      ? FitnessFormulas.planEndDate(_startDate, _selectedPlan!.months)
      : _startDate;

  @override
  Widget build(BuildContext context) {
    // Keep current step in bounds if active steps length changes
    if (_currentStep >= _totalSteps) {
      _currentStep = _totalSteps - 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Client (${_currentStep + 1}/$_totalSteps)'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            color: AppColors.brandOrange,
            backgroundColor: AppColors.border,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep--),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: AppButton(
                label: _currentStep == _totalSteps - 1 ? 'Save & Activate' : 'Next',
                isLoading: _isSaving,
                onPressed: _onNext,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildStepContent(_currentStepType),
      ),
    );
  }

  Widget _buildStepContent(WizardStepType stepType) {
    switch (stepType) {
      case WizardStepType.personal:
        return _step1Personal();
      case WizardStepType.emergency:
        return _step2Emergency();
      case WizardStepType.program:
        return _step3Program();
      case WizardStepType.trainer:
        return _step4Trainer();
      case WizardStepType.nutritionist:
        return _step5Nutritionist();
      case WizardStepType.plan:
        return _step6Plan();
      case WizardStepType.slot:
        return _step7Slot();
      case WizardStepType.payment:
        return _step8Payment();
      case WizardStepType.consent:
        return _step9Consent();
      case WizardStepType.review:
        return _step10Review();
    }
  }

  Widget _step1Personal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Personal Details'),
        Row(
          children: [
            Expanded(child: AppTextField(controller: _firstNameCtrl, label: 'First Name *')),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(controller: _lastNameCtrl, label: 'Last Name *')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ListTile(
                tileColor: AppColors.surfaceRaised,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                title: const Text('Date of Birth', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_dob)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dob,
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _dob = picked);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AutoCalcField(
                label: 'Calculated Age',
                value: '$_calculatedAge yrs',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppDropdownField<String>(
          label: 'Gender',
          value: _gender,
          items: ['Male', 'Female']
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (v) => setState(() => _gender = v ?? _gender),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _phonePrimaryCtrl,
          label: 'Primary Phone *',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _phoneSecondaryCtrl,
          label: 'Secondary Phone (Optional)',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _emailCtrl,
          label: 'Email (Optional)',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _addressCtrl,
          label: 'Address',
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _step2Emergency() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Emergency Contact'),
        Row(
          children: [
            Expanded(child: AppTextField(controller: _emFirstNameCtrl, label: 'First Name *')),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(controller: _emLastNameCtrl, label: 'Last Name *')),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _emPhoneCtrl,
          label: 'Primary Phone *',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _emAddressCtrl,
          label: 'Emergency Contact Address',
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _step3Program() {
    final descriptions = {
      'Personal Training': 'Dedicated trainer on gym floor with timetable slot booking. Nutrition is optional.',
      'Personal Training + Nutrition': 'Dual combo: Dedicated trainer with timetable slot PLUS certified nutritionist consulting.',
      'Nutrition': 'Nutrition & diet consulting only. No trainer or gym workout slot assigned.',
      'Yoga': 'Yoga guidance with scheduled studio slot.',
      'Group Program': 'Group session program with scheduled slot.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Program Selection'),
        const Text(
          'Select client enrollment type. "Personal Training + Nutrition" assigns both a trainer and nutritionist. "Nutrition" skips trainer and slot booking.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        ...AppConstants.programTypes.map((prog) {
          final isSelected = _programType == prog;
          final desc = descriptions[prog] ?? '';
          return Card(
            color: isSelected ? AppColors.brandOrange.withOpacity(0.15) : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected ? AppColors.brandOrange : AppColors.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? AppColors.brandOrange : AppColors.textSecondary,
                size: 24,
              ),
              title: Text(prog, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: desc.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    )
                  : null,
              onTap: () {
                setState(() {
                  _programType = prog;
                  // Auto-adjust selections
                  if (_isNutritionOnly) {
                    _selectedTrainerId = null;
                  }
                });
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _step4Trainer() {
    final trainersAsync = ref.watch(activeTrainersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Assign Trainer'),
        const Text(
          'Select the personal trainer who will coach this client and supervise their booked slot.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        trainersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading trainers: $e'),
          data: (trainers) {
            if (trainers.isEmpty) {
              return Card(
                color: AppColors.surfaceRaised,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.fitness_center, size: 36, color: AppColors.brandOrange),
                      const SizedBox(height: 8),
                      const Text(
                        'No active trainers in team yet.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add a trainer in More > Team to assign floor workouts.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandOrange),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Trainer in Team'),
                        onPressed: () => context.go('/admin/more/team/add'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (_selectedTrainerId == null && trainers.isNotEmpty) {
              _selectedTrainerId = trainers.first.id;
            }
            return Column(
              children: trainers.map((t) {
                final isSelected = _selectedTrainerId == t.id;
                return Card(
                  color: isSelected ? AppColors.brandOrange.withOpacity(0.15) : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? AppColors.brandOrange : AppColors.border,
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected ? AppColors.brandOrange : AppColors.surfaceRaised,
                      foregroundColor: isSelected ? Colors.white : AppColors.textPrimary,
                      child: Text(t.name.isNotEmpty ? t.name[0] : 'T'),
                    ),
                    title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Shift: ${t.shiftStart ?? "06:00"} - ${t.shiftEnd ?? "22:00"}'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.brandOrange)
                        : null,
                    onTap: () => setState(() => _selectedTrainerId = t.id),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _step5Nutritionist() {
    final nutritionistsAsync = ref.watch(activeNutritionistsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: _isNutritionistRequired
              ? 'Assign Nutritionist (Required)'
              : 'Assign Nutritionist (Optional)',
        ),
        Text(
          _isNutritionistRequired
              ? '$_programType includes professional nutrition guidance. Please choose a certified nutritionist.'
              : 'Optional diet planning add-on. Select a nutritionist or keep workout only.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),

        // If optional, show "None (Workout Only)" option
        if (!_isNutritionistRequired) ...[
          Card(
            color: _selectedNutritionistId == null ? AppColors.brandOrange.withOpacity(0.15) : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: _selectedNutritionistId == null ? AppColors.brandOrange : AppColors.border,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _selectedNutritionistId == null ? AppColors.brandOrange : AppColors.surfaceRaised,
                foregroundColor: _selectedNutritionistId == null ? Colors.white : AppColors.textPrimary,
                child: const Icon(Icons.fitness_center, size: 18),
              ),
              title: const Text('None (Workout / Floor Only)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('No dedicated nutritionist consultation', style: TextStyle(fontSize: 12)),
              trailing: _selectedNutritionistId == null
                  ? const Icon(Icons.check_circle, color: AppColors.brandOrange)
                  : null,
              onTap: () => setState(() => _selectedNutritionistId = null),
            ),
          ),
        ],

        // List nutritionists from team
        nutritionistsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading nutritionists: $e'),
          data: (nutritionists) {
            if (nutritionists.isEmpty) {
              return Card(
                color: AppColors.surfaceRaised,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.restaurant_menu, size: 36, color: AppColors.brandOrange),
                      const SizedBox(height: 8),
                      Text(
                        _isNutritionistRequired
                            ? 'No nutritionists found in team yet.'
                            : 'No nutritionists currently listed in team.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'You can create staff with role "Nutritionist" in More > Team.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandOrange),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Nutritionist in Team'),
                        onPressed: () => context.go('/admin/more/team/add'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Auto-select first nutritionist if required and none selected
            if (_isNutritionistRequired && _selectedNutritionistId == null && nutritionists.isNotEmpty) {
              _selectedNutritionistId = nutritionists.first.id;
            }

            return Column(
              children: nutritionists.map((n) {
                final isSelected = _selectedNutritionistId == n.id;
                return Card(
                  color: isSelected ? AppColors.brandOrange.withOpacity(0.15) : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? AppColors.brandOrange : AppColors.border,
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected ? AppColors.brandOrange : AppColors.surfaceRaised,
                      foregroundColor: isSelected ? Colors.white : AppColors.textPrimary,
                      child: Text(n.name.isNotEmpty ? n.name[0] : 'N'),
                    ),
                    title: Text(n.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Nutrition Specialist • ${n.phone ?? n.userId}'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.brandOrange)
                        : null,
                    onTap: () => setState(() => _selectedNutritionistId = n.id),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _step6Plan() {
    final plansAsync = ref.watch(plansProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Select Plan & Start Date'),
        ListTile(
          tileColor: AppColors.surfaceRaised,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: const Text('Start Date', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          subtitle: Text(DateFormat('dd MMMM yyyy').format(_startDate)),
          trailing: const Icon(Icons.calendar_today, size: 18),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 90)),
            );
            if (picked != null) setState(() => _startDate = picked);
          },
        ),
        const SizedBox(height: 16),
        plansAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _defaultPlansList(),
          data: (plans) {
            final list = plans.isNotEmpty ? plans : PlanModel.defaultPlans;
            if (_selectedPlan == null && list.isNotEmpty) _selectedPlan = list.first;
            return Column(
              children: list.map((p) {
                final isSelected = _selectedPlan?.id == p.id;
                return Card(
                  color: isSelected ? AppColors.brandOrange.withOpacity(0.15) : AppColors.surface,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${p.months} Months • ${p.totalSessions} Total Sessions'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.brandOrange)
                        : null,
                    onTap: () => setState(() => _selectedPlan = p),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        AutoCalcField(
          label: 'Calculated Plan End Date',
          value: DateFormat('dd MMMM yyyy').format(_calculatedEndDate),
        ),
      ],
    );
  }

  Widget _defaultPlansList() {
    final list = PlanModel.defaultPlans;
    if (_selectedPlan == null) _selectedPlan = list.first;
    return Column(
      children: list.map((p) {
        final isSelected = _selectedPlan?.id == p.id;
        return Card(
          color: isSelected ? AppColors.brandOrange.withOpacity(0.15) : AppColors.surface,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${p.months} Months • ${p.totalSessions} Total Sessions'),
            trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.brandOrange) : null,
            onTap: () => setState(() => _selectedPlan = p),
          ),
        );
      }).toList(),
    );
  }

  Widget _step7Slot() {
    final trainerId = _selectedTrainerId ?? '';
    final existingPatterns = MockData.slots
        .where((s) => s.trainerId == trainerId && s.hourStart == _selectedHour)
        .map((s) => s.pattern)
        .toList();
    final available = SlotEngine.getAvailablePatterns(existingPatterns);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Timetable Slot & Pattern'),
        const Text('Select Hour:'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [6, 7, 8, 9, 10, 11, 17, 18, 19, 20].map((h) {
            final isSelected = _selectedHour == h;
            final label = h >= 12 ? '${h - 12 == 0 ? 12 : h - 12} PM' : '$h AM';
            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedHour = h),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text('Select Pattern:'),
        const SizedBox(height: 8),
        ...available.map((av) {
          final isSelected = _selectedPattern == av.pattern;
          return Card(
            color: isSelected ? AppColors.brandOrange.withOpacity(0.15) : AppColors.surface,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: SlotPatternChip(pattern: av.pattern),
              title: Text('Pattern ${av.pattern}'),
              subtitle: Text(av.isAvailable ? 'Valid seat' : av.reason ?? 'Unavailable'),
              enabled: av.isAvailable,
              trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.brandOrange) : null,
              onTap: av.isAvailable ? () => setState(() => _selectedPattern = av.pattern) : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _step8Payment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Payment Method (Record Only)'),
        ...AppConstants.paymentMethods.map((pm) {
          final isSelected = _paymentMethod == pm;
          return Card(
            color: isSelected ? AppColors.brandOrange.withOpacity(0.15) : AppColors.surface,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(pm == 'Cash' ? Icons.money : Icons.credit_card),
              title: Text(pm, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.brandOrange) : null,
              onTap: () => setState(() => _paymentMethod = pm),
            ),
          );
        }),
      ],
    );
  }

  Widget _step9Consent() {
    final consentBody = _isNutritionOnly
        ? 'I, ${_firstNameCtrl.text} ${_lastNameCtrl.text}, agree to participate in the Nutrition & Diet Consultation Program at FS-7 Fitness. I acknowledge the importance of dietary compliance and health disclosures.'
        : 'I, ${_firstNameCtrl.text} ${_lastNameCtrl.text}, agree to participate in physical training at FS-7 Fitness. I acknowledge the potential physical risks and agree to the gym’s safety policies and regulations.';

    final secondLabel = _isNutritionOnly
        ? 'Nutritionist / Staff Signature *'
        : 'Trainer Signature *';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Informed Consent & Signatures'),
        Card(
          color: AppColors.surfaceRaised,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              consentBody,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Member Signature *', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: SfSignaturePad(
            key: _memberSigKey,
            backgroundColor: Colors.white,
            strokeColor: Colors.black,
            minimumStrokeWidth: 2.0,
            maximumStrokeWidth: 4.0,
          ),
        ),
        const SizedBox(height: 16),
        Text(secondLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: SfSignaturePad(
            key: _secondSigKey,
            backgroundColor: Colors.white,
            strokeColor: Colors.black,
            minimumStrokeWidth: 2.0,
            maximumStrokeWidth: 4.0,
          ),
        ),
      ],
    );
  }

  Widget _step10Review() {
    final trainer = MockData.allStaff.where((u) => u.id == _selectedTrainerId).firstOrNull;
    final nutritionist = MockData.allStaff.where((u) => u.id == _selectedNutritionistId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Review & Activate'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _summaryRow('Client Name', '${_firstNameCtrl.text} ${_lastNameCtrl.text}'),
                _summaryRow('Phone', _phonePrimaryCtrl.text),
                _summaryRow('Program', _programType),
                if (_needsTrainer) ...[
                  _summaryRow('Trainer', trainer?.name ?? 'Assigned Trainer'),
                ],
                if (_selectedNutritionistId != null && _selectedNutritionistId!.isNotEmpty) ...[
                  _summaryRow('Nutritionist', nutritionist?.name ?? 'Assigned Nutritionist'),
                ],
                _summaryRow('Plan', _selectedPlan?.name ?? '—'),
                _summaryRow('Total Sessions', '${_selectedPlan?.totalSessions ?? 0}'),
                _summaryRow('Start Date', DateFormat('dd MMM yyyy').format(_startDate)),
                _summaryRow('End Date', DateFormat('dd MMM yyyy').format(_calculatedEndDate)),
                if (_needsSlot) ...[
                  _summaryRow('Slot', '$_selectedHour:00 • Pattern $_selectedPattern'),
                ] else ...[
                  _summaryRow('Timetable Slot', 'N/A (Nutrition Only)'),
                ],
                _summaryRow('Payment', _paymentMethod),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _onNext() {
    switch (_currentStepType) {
      case WizardStepType.personal:
        if (_firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty || _phonePrimaryCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill required fields (First Name, Last Name, Primary Phone)')),
          );
          return;
        }
        break;

      case WizardStepType.emergency:
        if (_emFirstNameCtrl.text.trim().isEmpty || _emPhoneCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter emergency contact name and phone')),
          );
          return;
        }
        break;

      case WizardStepType.program:
        break;

      case WizardStepType.trainer:
        if (_needsTrainer && (_selectedTrainerId == null || _selectedTrainerId!.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please assign a trainer. Add trainers in More > Team if none exist.')),
          );
          return;
        }
        break;

      case WizardStepType.nutritionist:
        if (_isNutritionistRequired && (_selectedNutritionistId == null || _selectedNutritionistId!.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please assign a nutritionist for $_programType.')),
          );
          return;
        }
        break;

      case WizardStepType.plan:
        if (_selectedPlan == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a plan')),
          );
          return;
        }
        break;

      case WizardStepType.slot:
        if (_needsSlot) {
          final trainerId = _selectedTrainerId ?? '';
          final existingPatterns = MockData.slots
              .where((s) => s.trainerId == trainerId && s.hourStart == _selectedHour)
              .map((s) => s.pattern)
              .toList();
          final available = SlotEngine.getAvailablePatterns(existingPatterns);
          final patternSlot = available.firstWhere((p) => p.pattern == _selectedPattern, orElse: () => available.first);
          if (!patternSlot.isAvailable) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Pattern $_selectedPattern is not available at $_selectedHour:00. ${patternSlot.reason ?? ""}')),
            );
            return;
          }
        }
        break;

      case WizardStepType.payment:
      case WizardStepType.consent:
      case WizardStepType.review:
        break;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _saveAndActivate();
    }
  }

  Future<void> _saveAndActivate() async {
    setState(() => _isSaving = true);
    final user = ref.read(currentUserProvider);

    try {
      Uint8List memberSig = Uint8List(0);
      Uint8List secondSig = Uint8List(0);
      try {
        final img1 = await _memberSigKey.currentState?.toImage(pixelRatio: 2.0);
        final bytes1 = await img1?.toByteData(format: ui.ImageByteFormat.png);
        if (bytes1 != null) memberSig = bytes1.buffer.asUint8List();
      } catch (_) {}
      try {
        final img2 = await _secondSigKey.currentState?.toImage(pixelRatio: 2.0);
        final bytes2 = await img2?.toByteData(format: ui.ImageByteFormat.png);
        if (bytes2 != null) secondSig = bytes2.buffer.asUint8List();
      } catch (_) {}

      final service = ref.read(serverFunctionsServiceProvider);

      final result = await service.createClient(
        profileData: {
          'first_name': _firstNameCtrl.text.trim(),
          'last_name': _lastNameCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'dob': _dob.toIso8601String().split('T')[0],
          'gender': _gender,
          'phone_primary': _phonePrimaryCtrl.text.trim(),
          'phone_secondary': _phoneSecondaryCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'program_type': _programType,
          'emergency_first_name': _emFirstNameCtrl.text.trim(),
          'emergency_last_name': _emLastNameCtrl.text.trim(),
          'emergency_address': _emAddressCtrl.text.trim(),
          'emergency_phone': _emPhoneCtrl.text.trim(),
          'source_inquiry_id': widget.sourceInquiryId,
        },
        planId: _selectedPlan?.id ?? 'plan_3m_12',
        startDate: _startDate,
        trainerId: _needsTrainer ? (_selectedTrainerId ?? '') : '',
        nutritionistId: _selectedNutritionistId,
        hourStart: _needsSlot ? _selectedHour : 0,
        pattern: _needsSlot ? _selectedPattern : '',
        paymentMethod: _paymentMethod,
        memberSignature: memberSig.isNotEmpty ? memberSig : Uint8List.fromList([0]),
        trainerSignature: secondSig.isNotEmpty ? secondSig : Uint8List.fromList([0]),
        consentText: AppConstants.consentTerms,
        createdBy: user?.id ?? 'admin-01',
      );

      final client = result['client'] as ClientModel;
      final sub = result['subscription'] as SubscriptionModel;

      ref.invalidate(clientsProvider);
      ref.invalidate(allActiveSlotsProvider);
      ref.invalidate(adminDashboardProvider);
      if (_selectedTrainerId != null) {
        ref.invalidate(trainerSlotsProvider(_selectedTrainerId!));
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Client Activated! 🎉'),
            content: Text(
                'Client profile, subscription, dual-signature consent${_needsSlot ? ", and timetable slot" : ""} have been created.\n\nWould you like to start the baseline fitness assessment now?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/admin/clients/${client.id}');
                },
                child: const Text('View Client Profile'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go(
                      '/admin/clients/${client.id}/assessment/new?subscriptionId=${sub.id}&type=baseline');
                },
                child: const Text('Start Baseline Now'),
              ),
            ],
          ),
        );
      }
    } on BusinessException catch (be) {
      if (mounted) {
        if (be.code.startsWith('SLOT_')) {
          final slotIdx = _activeSteps.indexOf(WizardStepType.slot);
          if (slotIdx != -1) {
            setState(() => _currentStep = slotIdx);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(be.message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating client: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
