import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/inquiries_provider.dart';

class AddInquiryScreen extends ConsumerStatefulWidget {
  const AddInquiryScreen({super.key});

  @override
  ConsumerState<AddInquiryScreen> createState() => _AddInquiryScreenState();
}

class _AddInquiryScreenState extends ConsumerState<AddInquiryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _source = AppConstants.defaultInquirySources.first;
  final _refNameCtrl = TextEditingController();
  DateTime _inquiryDate = DateTime.now();
  DateTime _nextFollowupDate = DateTime.now().add(const Duration(days: 1));
  String? _interestedIn;
  final _preferredTimeCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _refNameCtrl.dispose();
    _preferredTimeCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Inquiry'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              controller: _nameCtrl,
              label: 'Lead Name *',
              prefixIcon: Icons.person_outline,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _phoneCtrl,
              label: 'Mobile Number *',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppDropdownField<String>(
              label: 'Inquiry Source',
              value: _source,
              items: AppConstants.defaultInquirySources
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _source = v ?? _source),
            ),
            if (_source == 'Referral') ...[
              const SizedBox(height: 12),
              AppTextField(
                controller: _refNameCtrl,
                label: 'Referred By (Client Name)',
                prefixIcon: Icons.badge_outlined,
              ),
            ],
            const SizedBox(height: 12),
            ListTile(
              tileColor: AppColors.surfaceRaised,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: const Text('Inquiry Date', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              subtitle: Text(DateFormat('dd MMMM yyyy').format(_inquiryDate)),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _inquiryDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _inquiryDate = picked);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: AppColors.surfaceRaised,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: const Text('Next Follow-up Date *',
                  style: TextStyle(fontSize: 12, color: AppColors.brandOrange)),
              subtitle: Text(DateFormat('dd MMMM yyyy').format(_nextFollowupDate)),
              trailing: const Icon(Icons.alarm, size: 18, color: AppColors.brandOrange),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextFollowupDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setState(() => _nextFollowupDate = picked);
              },
            ),
            const SizedBox(height: 12),
            AppDropdownField<String>(
              label: 'Interested Program (Optional)',
              value: _interestedIn,
              items: AppConstants.programTypes
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _interestedIn = v),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _preferredTimeCtrl,
              label: 'Preferred Time & Slot (e.g. 7 AM MWF)',
              prefixIcon: Icons.schedule,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _remarksCtrl,
              label: 'Initial Remarks',
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            AppButton(
              label: 'Save Inquiry',
              isLoading: _isSaving,
              onPressed: _saveInquiry,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveInquiry() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final user = ref.read(currentUserProvider);

    try {
      await ref.read(inquiryRepositoryProvider).createInquiry(
        data: {
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'source_id': _source,
          'reference_name': _refNameCtrl.text.trim(),
          'inquiry_date': _inquiryDate.toIso8601String().split('T')[0],
          'last_followup_date': _inquiryDate.toIso8601String().split('T')[0],
          'next_followup_date': _nextFollowupDate.toIso8601String().split('T')[0],
          'interested_in': _interestedIn,
          'preferred_time': _preferredTimeCtrl.text.trim(),
          'status': 'new',
          'remarks': _remarksCtrl.text.trim(),
        },
        createdBy: user?.id ?? '',
      );

      ref.invalidate(inquiriesProvider);
      ref.invalidate(todayInquiriesProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inquiry created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

