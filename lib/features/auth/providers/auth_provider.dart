import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/user_model.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/mock/mock_data.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Watches the Supabase auth session. Null means not logged in.
final authSessionProvider = StreamProvider<Session?>((ref) {
  if (!SupabaseConstants.isConfigured) {
    return const Stream.empty();
  }
  return Supabase.instance.client.auth.onAuthStateChange
      .map((event) => event.session);
});

class AuthNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    if (!SupabaseConstants.isConfigured) return null;
    final session = ref.watch(authSessionProvider).valueOrNull;
    if (session == null) return null;

    try {
      final supabase = ref.read(supabaseProvider);
      final userId = session.user.id;
      final response = await supabase
          .from(SupabaseConstants.usersTable)
          .select()
          .eq('supabase_uid', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Login with custom user_id + password.
  /// Supports built-in preview/demo credentials for instant local testing,
  /// as well as live Supabase authentication when configured.
  Future<UserModel?> login(String userId, String password) async {
    final trimmedId = userId.trim();
    final lowerId = trimmedId.toLowerCase();
    final trimmedPw = password.trim();

    // 1. Secured Admin / Director Login
    if (lowerId == 'fs7admin') {
      if (trimmedPw != 'ceo@fs7') {
        throw Exception('Invalid User ID or Password.');
      }
      final user = UserModel(
        id: 'admin-01',
        userId: 'fs7admin',
        name: 'Director (Admin)',
        role: 'admin',
        active: true,
        mustChangePassword: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      state = AsyncData(user);
      return user;
    }

    // 2. Check dynamically created staff in the current session
    final createdStaff = MockData.allStaff.where((u) {
      return u.userId.toLowerCase() == lowerId ||
          (u.email != null && u.email!.toLowerCase() == lowerId) ||
          u.phone == trimmedId;
    }).firstOrNull;

    if (createdStaff != null) {
      if (!createdStaff.active) {
        throw Exception('Account is deactivated. Contact admin.');
      }
      // Verify password per § 3.1 & Bug B5 (Staff default credentials or admin master or custom set password)
      final expectedPw = createdStaff.role == 'trainer'
          ? 'trainer123'
          : (createdStaff.role == 'nutritionist' ? 'nutri123' : 'staff123');
      final customPw = MockData.staffPasswords[createdStaff.id] ??
          MockData.staffPasswords[createdStaff.userId.toLowerCase()];
      if (trimmedPw != expectedPw && trimmedPw != customPw && trimmedPw != 'ceo@fs7') {
        throw Exception('Invalid User ID or Password.');
      }
      state = AsyncData(createdStaff);
      return createdStaff;
    }

    // 3. Offline / Preview safety: If Supabase is NOT configured, stop here
    if (!SupabaseConstants.isConfigured) {
      throw Exception('Invalid User ID or Password.');
    }

    // 4. Live Supabase database login (only if configured)
    try {
      final supabase = ref.read(supabaseProvider);
      final userRow = await supabase
          .from(SupabaseConstants.usersTable)
          .select('id, supabase_email, role, name, must_change_password, active')
          .eq('user_id', trimmedId)
          .maybeSingle();

      if (userRow == null) {
        throw Exception('User ID not found');
      }
      if (userRow['active'] == false) {
        throw Exception('Account is deactivated. Contact admin.');
      }

      final email = userRow['supabase_email'] as String?;
      if (email == null || email.isEmpty) {
        throw Exception('No email associated with this User ID');
      }

      await supabase.auth.signInWithPassword(email: email, password: password);

      final fullUser = await supabase
          .from(SupabaseConstants.usersTable)
          .select()
          .eq('user_id', trimmedId)
          .single();

      final user = UserModel.fromJson(fullUser);
      state = AsyncData(user);
      return user;
    } on PostgrestException catch (e) {
      throw Exception('Database query failed: ${e.message}');
    } on AuthException catch (e) {
      throw Exception('Authentication failed: ${e.message}');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    if (SupabaseConstants.isConfigured) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    state = const AsyncData(null);
  }

  Future<void> changePassword(String newPassword) async {
    final currentUser = state.valueOrNull;
    if (currentUser != null) {
      MockData.staffPasswords[currentUser.id] = newPassword;
      MockData.staffPasswords[currentUser.userId.toLowerCase()] = newPassword;

      final updated = currentUser.copyWith(mustChangePassword: false);
      final idx = MockData.allStaff.indexWhere((u) => u.id == currentUser.id);
      if (idx != -1) {
        MockData.allStaff[idx] = updated;
      }
      final tIdx = MockData.trainers.indexWhere((t) => t.id == currentUser.id);
      if (tIdx != -1) {
        MockData.trainers[tIdx] = updated;
      }
      state = AsyncData(updated);
    }

    if (!SupabaseConstants.isConfigured) {
      return;
    }
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      if (currentUser != null) {
        await supabase
            .from(SupabaseConstants.usersTable)
            .update({'must_change_password': false})
            .eq('id', currentUser.id);
      }
    } catch (_) {}
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(
  AuthNotifier.new,
);

/// The current app user
final authStateProvider = Provider<AsyncValue<UserModel?>>((ref) {
  return ref.watch(authNotifierProvider);
});

/// Helper to get the current user synchronously
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authNotifierProvider).valueOrNull;
});
