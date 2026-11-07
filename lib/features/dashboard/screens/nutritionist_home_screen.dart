import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_cards.dart';
import '../../auth/providers/auth_provider.dart';
import '../../clients/providers/clients_provider.dart';

class NutritionistHomeScreen extends ConsumerWidget {
  const NutritionistHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final clientsAsync = ref.watch(clientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Nutrition Clients'),
      ),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (clients) {
          final assigned = clients
              .where((c) => c.nutritionistId == user?.id || user?.isAdmin == true)
              .toList();

          if (assigned.isEmpty) {
            return const EmptyState(
              message: 'No nutrition clients assigned yet.',
              icon: Icons.restaurant,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: assigned.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final client = assigned[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surfaceRaised,
                    child: Text(
                      client.initials,
                      style: const TextStyle(
                          color: AppColors.brandOrange, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(client.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${client.gender}, ${client.age} yrs • Goal: ${client.programType}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    context.go('/nutritionist/${client.id}');
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

