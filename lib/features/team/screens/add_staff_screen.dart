import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';
import '../providers/team_provider.dart';
import '../../timetable/providers/timetable_provider.dart';
import '../../staff_attendance/providers/staff_attendance_provider.dart';

class AddStaffScreen extends ConsumerStatefulWidget {
  final String? staffId;

  const AddStaffScreen({super.key, this.staffId});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _role = 'trainer';
  final _userIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _shiftStartCtrl = TextEditingController(text: '06:00');
  final _shiftEndCtrl = TextEditingController(text: '14:00');
  int _weeklyOff = 7; // Sunday default

  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadExistingStaff();
  }

  void _loadExistingStaff() {
    if (widget.staffId == null) return;

    final staff = MockData.allStaff.where((u) => u.id == widget.staffId).firstOrNull;
    if (staff != null) {
      _nameCtrl.text = staff.name;
      _phoneCtrl.text = staff.phone ?? '';
      _role = staff.role;
      _userIdCtrl.text = staff.userId;
      _shiftStartCtrl.text = staff.shiftStart ?? '06:00';
      _shiftEndCtrl.text = staff.shiftEnd ?? '14:00';
      _weeklyOff = staff.weeklyOffDay ?? 7;
      _initialized = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.staffId != null && !_initialized) {
      final teamList = ref.watch(teamMembersProvider).valueOrNull ?? [];
      final staff = teamList.where((u) => u.id == widget.staffId).firstOrNull;
      if (staff != null) {
        _nameCtrl.text = staff.name;
        _phoneCtrl.text = staff.phone ?? '';
        _role = staff.role;
        _userIdCtrl.text = staff.userId;
        _shiftStartCtrl.text = staff.shiftStart ?? '06:00';
        _shiftEndCtrl.text = staff.shiftEnd ?? '14:00';
        _weeklyOff = staff.weeklyOffDay ?? 7;
        _initialized = true;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _userIdCtrl.dispose();
    _passwordCtrl.dispose();
    _shiftStartCtrl.dispose();
    _shiftEndCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.staffId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Staff Member' : 'Add Staff Member'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              controller: _nameCtrl,
              label: 'Full Name *',
              prefixIcon: Icons.person_outline,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _phoneCtrl,
              label: 'Phone Number *',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppDropdownField<String>(
              label: 'Staff Role',
              value: _role,
              items: const [
                DropdownMenuItem(value: 'trainer', child: Text('Trainer')),
                DropdownMenuItem(value: 'nutritionist', child: Text('Nutritionist')),
                DropdownMenuItem(value: 'staff', child: Text('Support Staff / Reception')),
              ],
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 16),
            const Text('Account Credentials',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandOrange)),
            const SizedBox(height: 8),
            AppTextField(
              controller: _userIdCtrl,
              label: 'Staff User ID (Login Username) *',
              prefixIcon: Icons.badge_outlined,
              readOnly: isEditing,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _passwordCtrl,
              label: isEditing
                  ? 'New Password (Leave blank to keep existing)'
                  : 'Initial Password *',
              prefixIcon: Icons.lock_outline,
              obscureText: true,
              validator: isEditing
                  ? null
                  : (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            const Text('Shift & Working Hours',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandOrange)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _shiftStartCtrl,
                    label: 'Shift Start (HH:MM)',
                    prefixIcon: Icons.schedule,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _shiftEndCtrl,
                    label: 'Shift End (HH:MM)',
                    prefixIcon: Icons.schedule,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppDropdownField<int>(
              label: 'Weekly Off Day',
              value: _weeklyOff,
              items: const [
                DropdownMenuItem(value: 1, child: Text('Monday')),
                DropdownMenuItem(value: 2, child: Text('Tuesday')),
                DropdownMenuItem(value: 3, child: Text('Wednesday')),
                DropdownMenuItem(value: 4, child: Text('Thursday')),
                DropdownMenuItem(value: 5, child: Text('Friday')),
                DropdownMenuItem(value: 6, child: Text('Saturday')),
                DropdownMenuItem(value: 7, child: Text('Sunday')),
              ],
              onChanged: (v) => setState(() => _weeklyOff = v ?? 7),
            ),
            const SizedBox(height: 32),
            AppButton(
              label: isEditing ? 'Save Changes' : 'Create Profile',
              isLoading: _isSaving,
              onPressed: _saveStaff,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveStaff() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      if (widget.staffId != null) {
        await ref.read(teamRepositoryProvider).updateStaffMember(
              id: widget.staffId!,
              name: _nameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              role: _role,
              password: _passwordCtrl.text.isNotEmpty ? _passwordCtrl.text : null,
              shiftStart: _shiftStartCtrl.text.trim(),
              shiftEnd: _shiftEndCtrl.text.trim(),
              weeklyOff: _weeklyOff,
            );
      } else {
        await ref.read(teamRepositoryProvider).createStaffMember(
              name: _nameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              role: _role,
              userId: _userIdCtrl.text.trim(),
              password: _passwordCtrl.text,
              shiftStart: _shiftStartCtrl.text.trim(),
              shiftEnd: _shiftEndCtrl.text.trim(),
              weeklyOff: _weeklyOff,
            );
      }

      ref.invalidate(teamMembersProvider);
      ref.invalidate(activeTrainersProvider);
      ref.invalidate(allStaffUsersProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.staffId != null
                ? 'Staff member profile updated!'
                : 'Staff member profile created!'),
            backgroundColor: AppColors.success,
          ),
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
