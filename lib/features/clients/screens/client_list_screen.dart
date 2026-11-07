import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/user_model.dart';
import '../../../widgets/common/app_cards.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/clients_provider.dart';

class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({super.key});

  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends ConsumerState<ClientListScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter;
  String? _trainerFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final clientsAsync = ref.watch(clientsProvider);
    final isStaff = user?.role == 'trainer' || user?.role == 'nutritionist';

    return Scaffold(
      appBar: AppBar(
        title: Text(isStaff ? 'My Clients' : 'Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilters(context),
          ),
          if (user?.isAdmin == true)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export',
              onPressed: () {},
            ),
        ],
      ),
      floatingActionButton: user?.isAdmin == true
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/admin/clients/add'),
              backgroundColor: AppColors.brandOrange,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Add Client', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Active filters chips
          if (_statusFilter != null || _trainerFilter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_statusFilter != null)
                    Chip(
                      label: Text(_statusFilter!),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => setState(() => _statusFilter = null),
                    ),
                ],
              ),
            ),

          // Client list
          Expanded(
            child: clientsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (clients) {
                final filtered = _filterClients(clients, user);
                if (filtered.isEmpty) {
                  return EmptyState(
                    message: isStaff
                        ? 'No clients assigned to you yet.'
                        : 'No clients enrolled yet.\nTap "+ Add Client" below to enroll your first client!',
                    icon: Icons.person_outline,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final client = filtered[i];
                    return _ClientListTile(
                      client: client,
                      onTap: () {
                        if (user?.role == 'trainer') {
                          context.go('/trainer/clients/${client.id}');
                        } else if (user?.role == 'nutritionist') {
                          context.go('/nutritionist/${client.id}');
                        } else {
                          context.go('/admin/clients/${client.id}');
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<ClientModel> _filterClients(List<ClientModel> clients, UserModel? user) {
    var result = clients;

    // Role-based visibility (§ 3.2 & Bug B3)
    if (user?.role == 'trainer') {
      result = result.where((c) => c.trainerId == user?.id).toList();
    } else if (user?.role == 'nutritionist') {
      result = result.where((c) => c.nutritionistId == user?.id).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((c) =>
        c.fullName.toLowerCase().contains(q) ||
        c.phonePrimary.contains(q) ||
        (c.phoneSecondary?.contains(q) ?? false)
      ).toList();
    }
    if (_statusFilter != null) {
      result = result.where((c) => c.status == _statusFilter).toList();
    }
    return result;
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _FilterSheet(
        currentStatus: _statusFilter,
        onStatusChanged: (s) {
          setState(() => _statusFilter = s);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _ClientListTile extends StatelessWidget {
  final ClientModel client;
  final VoidCallback onTap;

  const _ClientListTile({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.surfaceRaised,
        backgroundImage: client.photoUrl != null
            ? NetworkImage(client.photoUrl!)
            : null,
        child: client.photoUrl == null
            ? Text(
                '${client.firstName[0]}${client.lastName[0]}',
                style: const TextStyle(color: AppColors.brandOrange, fontWeight: FontWeight.w700),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(child: Text(client.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600))),
          StatusChip(status: client.status),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            const Icon(Icons.phone, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(client.phonePrimary,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 12),
            const Icon(Icons.person, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('Trainer assigned',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  final String? currentStatus;
  final void Function(String?) onStatusChanged;

  const _FilterSheet({this.currentStatus, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter by Status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['active', 'extended', 'completed', 'deactivated', 'hold'].map((s) {
              final selected = currentStatus == s;
              return FilterChip(
                label: StatusChip(status: s),
                selected: selected,
                onSelected: (_) => onStatusChanged(selected ? null : s),
                backgroundColor: AppColors.surfaceRaised,
                selectedColor: AppColors.brandOrange.withOpacity(0.1),
                checkmarkColor: AppColors.brandOrange,
                side: BorderSide(
                  color: selected ? AppColors.brandOrange : AppColors.border,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () { onStatusChanged(null); },
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

