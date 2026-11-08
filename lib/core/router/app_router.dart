import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/user_model.dart';
import '../theme/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/change_password_screen.dart';
import '../../features/dashboard/screens/admin_home_screen.dart';
import '../../features/dashboard/screens/trainer_home_screen.dart';
import '../../features/dashboard/screens/nutritionist_home_screen.dart';
import '../../features/timetable/screens/timetable_screen.dart';
import '../../features/clients/screens/client_list_screen.dart';
import '../../features/clients/screens/client_profile_screen.dart';
import '../../features/clients/screens/add_client_wizard_screen.dart';
import '../../features/assessments/screens/assessment_form_screen.dart';
import '../../features/assessments/screens/assessment_report_screen.dart';
import '../../features/inquiries/screens/inquiry_list_screen.dart';
import '../../features/inquiries/screens/add_inquiry_screen.dart';
import '../../features/inquiries/screens/inquiry_detail_screen.dart';
import '../../features/inquiries/screens/inquiry_analytics_screen.dart';
import '../../features/staff_attendance/screens/staff_attendance_screen.dart';
import '../../features/team/screens/team_screen.dart';
import '../../features/team/screens/add_staff_screen.dart';
import '../../features/past_clients/screens/past_clients_screen.dart';
import '../../features/nutrition/screens/nutrition_client_screen.dart';
import '../../features/reports/screens/transformation_report_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/widgets/database_connection_dialog.dart';
import '../constants/supabase_constants.dart';
import '../../features/auth/screens/audit_log_screen.dart';
import '../../features/auth/screens/staff_profile_screen.dart';
import '../../widgets/scaffold/admin_scaffold.dart';
import '../../widgets/scaffold/trainer_scaffold.dart';
import '../../widgets/scaffold/nutritionist_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final isLoginRoute = state.matchedLocation == '/login';
      final isChangePasswordRoute = state.matchedLocation == '/change-password';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn) {
        if (!user.active) return '/login';
        if (user.mustChangePassword && !isChangePasswordRoute) return '/change-password';

        if (isLoginRoute) {
          switch (user.role) {
            case 'admin': return '/admin';
            case 'trainer': return '/trainer';
            case 'nutritionist': return '/nutritionist';
            case 'support': return '/admin';
            default: return '/admin';
          }
        }

        // Strict role guards (§ 3.1 & Bug B3/B5)
        final loc = state.matchedLocation;
        if (user.role == 'trainer' && (loc.startsWith('/admin') || loc.startsWith('/nutritionist'))) {
          return '/trainer';
        }
        if (user.role == 'nutritionist' && (loc.startsWith('/admin') || loc.startsWith('/trainer'))) {
          return '/nutritionist';
        }
        if (user.role == 'admin' && (loc.startsWith('/trainer') || loc.startsWith('/nutritionist'))) {
          return '/admin';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),

      // ─── Admin shell ───────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdminScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin', builder: (_, __) => const AdminHomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin/timetable', builder: (_, __) => const TimetableScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/clients',
              builder: (_, __) => const ClientListScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (_, state) => AddClientWizardScreen(
                    sourceInquiryId: state.uri.queryParameters['sourceInquiryId'],
                    initialName: state.uri.queryParameters['name'],
                    initialPhone: state.uri.queryParameters['phone'],
                    initialProgram: state.uri.queryParameters['program'],
                  ),
                ),
                GoRoute(
                  path: ':id',
                  builder: (ctx, state) =>
                      ClientProfileScreen(clientId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'assessment/new',
                      builder: (ctx, state) => AssessmentFormScreen(
                        clientId: state.pathParameters['id']!,
                        subscriptionId: state.uri.queryParameters['subscriptionId'] ?? '',
                        type: state.uri.queryParameters['type'] ?? 'baseline',
                      ),
                    ),
                    GoRoute(
                      path: 'assessment/:assessmentId/report',
                      builder: (ctx, state) => AssessmentReportScreen(
                        clientId: state.pathParameters['id']!,
                        assessmentId: state.pathParameters['assessmentId']!,
                      ),
                    ),
                    GoRoute(
                      path: 'transformation-report',
                      builder: (ctx, state) => TransformationReportScreen(
                        clientId: state.pathParameters['id']!,
                        subscriptionId: state.uri.queryParameters['subscriptionId'] ?? '',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/inquiries',
              builder: (_, __) => const InquiryListScreen(),
              routes: [
                GoRoute(path: 'add', builder: (_, __) => const AddInquiryScreen()),
                GoRoute(path: 'analytics', builder: (_, __) => const InquiryAnalyticsScreen()),
                GoRoute(
                  path: ':id',
                  builder: (ctx, state) =>
                      InquiryDetailScreen(inquiryId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/more',
              builder: (_, __) => const AdminMoreScreen(),
              routes: [
                GoRoute(path: 'team', builder: (_, __) => const TeamScreen(),
                  routes: [
                    GoRoute(path: 'add', builder: (_, __) => const AddStaffScreen()),
                    GoRoute(
                      path: ':id',
                      builder: (ctx, state) =>
                          AddStaffScreen(staffId: state.pathParameters['id']),
                    ),
                  ],
                ),
                GoRoute(path: 'staff-attendance', builder: (_, __) => const StaffAttendanceScreen()),
                GoRoute(path: 'past-clients', builder: (_, __) => const PastClientsScreen()),
                GoRoute(path: 'settings', builder: (_, __) => const SettingsScreen()),
                GoRoute(path: 'audit-log', builder: (_, __) => const AuditLogScreen()),
              ],
            ),
          ]),
        ],
      ),

      // ─── Trainer shell ─────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => TrainerScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/trainer', builder: (_, __) => const TrainerHomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/trainer/timetable', builder: (_, __) => const TimetableScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/trainer/clients',
              builder: (_, __) => const ClientListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (ctx, state) =>
                      ClientProfileScreen(clientId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/trainer/profile', builder: (_, __) => const StaffProfileScreen()),
          ]),
        ],
      ),

      // ─── Nutritionist shell ────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => NutritionistScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/nutritionist',
              builder: (_, __) => const NutritionistHomeScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (ctx, state) =>
                      NutritionClientScreen(clientId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/nutritionist/profile', builder: (_, __) => const StaffProfileScreen()),
          ]),
        ],
      ),
      // ─── Direct Routes (Accessible across Admin & Staff) ─────
      GoRoute(
        path: '/assessments/new',
        builder: (ctx, state) => AssessmentFormScreen(
          clientId: state.uri.queryParameters['clientId'] ?? '',
          subscriptionId: state.uri.queryParameters['subscriptionId'] ?? '',
          type: state.uri.queryParameters['type'] ?? 'baseline',
        ),
      ),
      GoRoute(
        path: '/assessments/:assessmentId',
        builder: (ctx, state) => AssessmentReportScreen(
          clientId: state.uri.queryParameters['clientId'] ?? '',
          assessmentId: state.pathParameters['assessmentId']!,
        ),
      ),
      GoRoute(
        path: '/transformation-report',
        builder: (ctx, state) => TransformationReportScreen(
          clientId: state.uri.queryParameters['clientId'] ?? '',
          subscriptionId: state.uri.queryParameters['subscriptionId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/inquiries/:inquiryId',
        builder: (ctx, state) => InquiryDetailScreen(
          inquiryId: state.pathParameters['inquiryId']!,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

// Admin More Screen with full navigation and Logout (§ 3.1)
class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.people, color: AppColors.brandOrange),
            title: const Text('Team Management'),
            subtitle: const Text('Trainers, nutritionists, and staff'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => context.go('/admin/more/team'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.how_to_reg, color: AppColors.brandOrange),
            title: const Text('Staff Attendance'),
            subtitle: const Text('Daily staff marking and leave logs'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => context.go('/admin/more/staff-attendance'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.history, color: AppColors.brandOrange),
            title: const Text('Past Clients'),
            subtitle: const Text('Completed and deactivated memberships'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => context.go('/admin/more/past-clients'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings, color: AppColors.brandOrange),
            title: const Text('App Settings & Norms'),
            subtitle: const Text('Measurement units, policies, and cut-offs'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => context.go('/admin/more/settings'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.cloud_sync, color: AppColors.brandOrange),
            title: const Text('Database Connection'),
            subtitle: Text(
              SupabaseConstants.isConfigured
                  ? 'Connected to Supabase Cloud'
                  : 'Offline Mode (Local In-Memory)',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => showDialog(
              context: context,
              builder: (_) => const DatabaseConnectionDialog(),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.receipt_long, color: AppColors.brandOrange),
            title: const Text('System Audit Log'),
            subtitle: const Text('Full system change history'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => context.go('/admin/more/audit-log'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: AppColors.brandOrange),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => context.push('/change-password'),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error.withOpacity(0.15),
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

