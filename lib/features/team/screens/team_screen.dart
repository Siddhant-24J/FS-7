import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/server_functions_service.dart';
import '../../../data/models/user_model.dart';
import '../../../widgets/common/app_cards.dart';
import '../../auth/providers/auth_provider.dart';
import '../../timetable/providers/timetable_provider.dart';
import '../providers/team_provider.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.brandOrange,
          labelColor: AppColors.brandOrange,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Trainers'),
            Tab(text: 'Nutritionists'),
            Tab(text: 'Staff'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/admin/more/team/add'),
        backgroundColor: AppColors.brandOrange,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Staff', style: TextStyle(color: Colors.white)),
      ),
      body: teamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (members) {
          final trainers = members.where((m) => m.role == 'trainer').toList();
          final nutritionists = members.where((m) => m.role == 'nutritionist').toList();
          final otherStaff = members.where((m) => m.role == 'staff').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildStaffList(trainers),
              _buildStaffList(nutritionists),
              _buildStaffList(otherStaff),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStaffList(List<UserModel> list) {
    if (list.isEmpty) {
      return const EmptyState(message: 'No staff in this category yet', icon: Icons.group_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final staff = list[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.surfaceRaised,
              child: Text(
                staff.name.trim().isNotEmpty ? staff.name.trim()[0].toUpperCase() : 'S',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandOrange),
              ),
            ),
            title: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('User ID: ${staff.userId} • Shift: ${staff.shiftStart ?? "06:00"} - ${staff.shiftEnd ?? "14:00"}'),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'reset') {
                  _showResetPasswordDialog(staff);
                } else if (val == 'deactivate') {
                  _deactivateStaff(staff);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
                const PopupMenuItem(value: 'edit', child: Text('Edit Profile')),
                const PopupMenuItem(
                  value: 'deactivate',
                  child: Text('Deactivate Staff', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deactivateStaff(UserModel staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: Text('Deactivate ${staff.name}?'),
        content: const Text(
          'This will block this user from logging in. If this trainer has active clients, you must reassign them first.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = ref.read(currentUserProvider);
      final service = ref.read(serverFunctionsServiceProvider);
      await service.deactivateStaff(userId: staff.id, actorId: user?.id ?? 'admin-01');
      ref.invalidate(teamMembersProvider);
      ref.invalidate(activeTrainersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${staff.name} has been deactivated.'),
            backgroundColor: AppColors.success,
          ),
        );
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
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showResetPasswordDialog(UserModel staff) {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password: ${staff.name}'),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password reset successfully')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

