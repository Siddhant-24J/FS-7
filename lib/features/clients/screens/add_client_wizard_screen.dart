import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/formulas/fitness_formulas.dart';
import '../../../core/formulas/slot_engine.dart';
import '../../../core/services/pdf_service.dart';
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
  final int _totalSteps = 10;

  // Step 1: Personal Details
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  DateTime _dob = DateTime.now().subtract(const Duration(days: 365 * 25));
  String _gender = 'Male';
  final _phonePrimaryCtrl = TextEditingController();
  final _phoneSecondaryCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

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
  final GlobalKey<SfSignaturePadState> _trainerSigKey = GlobalKey();

  bool _isSaving = false;

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

  int get _calculatedAge => FitnessFormulas.calculateAge(_dob, DateTime.now());
  DateTime get _calculatedEndDate => _selectedPlan != null
      ? FitnessFormulas.planEndDate(_startDate, _selectedPlan!.months)
      : _startDate;

  @override
  Widget build(BuildContext context) {
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
        child: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _step1Personal();
      case 1:
        return _step2Emergency();
      case 2:
        return _step3Program();
      case 3:
        return _step4Trainer();
      case 4:
        return _step5Nutritionist();
      case 5:
        return _step6Plan();
      case 6:
        return _step7Slot();
      case 7:
        return _step8Payment();
      case 8:
        return _step9Consent();
      case 9:
        return _step10Review();
      default:
        return const SizedBox();
    }
  }

  Widget _step1Personal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Step 1: Personal Details'),
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
        const SectionHeader(title: 'Step 2: Emergency Contact'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Step 3: Program Type'),
        ...AppConstants.programTypes.map((prog) {
          final isSelected = _programType == prog;
          return Card(
            color: isSelected ? AppColors.brandOrange.withOpacity(0.15) : AppColors.surface,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? AppColors.brandOrange : AppColors.textSecondary,
              ),
              title: Text(prog, style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => setState(() => _programType = prog),
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
        const SectionHeader(title: 'Step 4: Assign Trainer'),
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
                      const Text(
                        'No trainers in team yet. You can enroll clients after adding a trainer in More > Team.',
                        style: TextStyle(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandOrange),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Trainer Now'),
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
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.surfaceRaised,
                      child: Text(t.name[0]),
                    ),
                    title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Hours: ${t.shiftStart ?? "6 AM"} - ${t.shiftEnd ?? "10 PM"}'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Step 5: Assign Nutritionist (Optional)'),
        Card(
          color: _selectedNutritionistId == null ? AppColors.brandOrange.withOpacity(0.15) : null,
          child: ListTile(
            title: const Text('None (Workout Only)'),
            trailing: _selectedNutritionistId == null
                ? const Icon(Icons.check_circle, color: AppColors.brandOrange)
                : null,
            onTap: () => setState(() => _selectedNutritionistId = null),
          ),
        ),
      ],
    );
  }

  Widget _step6Plan() {
    final plansAsync = ref.watch(plansProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Step 6: Select Plan & Start Date'),
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
        const SectionHeader(title: 'Step 7: Timetable Slot & Pattern'),
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
        const SectionHeader(title: 'Step 8: Payment Method (Record Only)'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Step 9: Informed Consent & Signatures'),
        Card(
          color: AppColors.surfaceRaised,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'I, ${_firstNameCtrl.text} ${_lastNameCtrl.text}, agree to participate in physical training at FS-7 Fitness. I acknowledge the potential physical risks and agree to the gym’s safety policies and regulations.',
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
        const Text('Trainer Signature *', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: SfSignaturePad(
            key: _trainerSigKey,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Step 10: Review & Activate'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _summaryRow('Client Name', '${_firstNameCtrl.text} ${_lastNameCtrl.text}'),
                _summaryRow('Phone', _phonePrimaryCtrl.text),
                _summaryRow('Program', _programType),
                _summaryRow('Plan', _selectedPlan?.name ?? '—'),
                _summaryRow('Total Sessions', '${_selectedPlan?.totalSessions ?? 0}'),
                _summaryRow('Start Date', DateFormat('dd MMM yyyy').format(_startDate)),
                _summaryRow('End Date', DateFormat('dd MMM yyyy').format(_calculatedEndDate)),
                _summaryRow('Slot', '$_selectedHour:00 • Pattern $_selectedPattern'),
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
    if (_currentStep == 0) {
      if (_firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty || _phonePrimaryCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill required fields (First Name, Last Name, Primary Phone)')),
        );
        return;
      }
    } else if (_currentStep == 1) {
      if (_emFirstNameCtrl.text.trim().isEmpty || _emPhoneCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter emergency contact name and phone')),
        );
        return;
      }
    } else if (_currentStep == 3) {
      if (_selectedTrainerId == null || _selectedTrainerId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please assign a trainer. Add trainers in More > Team if none exist.')),
        );
        return;
      }
    } else if (_currentStep == 6) {
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
      Uint8List trainerSig = Uint8List(0);
      try {
        final img1 = await _memberSigKey.currentState?.toImage(pixelRatio: 2.0);
        final bytes1 = await img1?.toByteData(format: ui.ImageByteFormat.png);
        if (bytes1 != null) memberSig = bytes1.buffer.asUint8List();
      } catch (_) {}
      try {
        final img2 = await _trainerSigKey.currentState?.toImage(pixelRatio: 2.0);
        final bytes2 = await img2?.toByteData(format: ui.ImageByteFormat.png);
        if (bytes2 != null) trainerSig = bytes2.buffer.asUint8List();
      } catch (_) {}

      final service = ref.read(serverFunctionsServiceProvider);

      // Single atomic Server Function call (Section 20.1 & Workflow B)
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
        trainerId: _selectedTrainerId ?? '',
        nutritionistId: _selectedNutritionistId,
        hourStart: _selectedHour,
        pattern: _selectedPattern,
        paymentMethod: _paymentMethod,
        memberSignature: memberSig.isNotEmpty ? memberSig : Uint8List.fromList([0]),
        trainerSignature: trainerSig.isNotEmpty ? trainerSig : Uint8List.fromList([0]),
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
        // Prompt for Baseline Assessment (Workflow B.8)
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Client Activated! 🎉'),
            content: const Text(
                'Client profile, subscription, dual-signature consent, and timetable slot have been created.\n\nWould you like to start the baseline fitness assessment now?'),
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
        // If slot failed, return to slot step (Step 7 = index 6) per Workflow B.7
        if (be.code.startsWith('SLOT_')) {
          setState(() => _currentStep = 6);
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

