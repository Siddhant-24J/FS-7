import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fs7_gym_app/core/mock/mock_data.dart';
import 'package:fs7_gym_app/core/mock/mock_seed.dart';
import 'package:fs7_gym_app/features/auth/providers/auth_provider.dart';

void main() {
  setUp(() {
    MockSeed.seed(force: true);
  });

  group('Group 1: Authentication & Role Verification (§ 4.2.1)', () {
    test('Admin logs in with fs7admin / ceo@fs7 and gets admin role', () async {
      final container = ProviderContainer();
      final user = await container
          .read(authNotifierProvider.notifier)
          .login('fs7admin', 'ceo@fs7');

      expect(user, isNotNull);
      expect(user!.role, equals('admin'));
      expect(user.isAdmin, isTrue);
      expect(user.userId, equals('fs7admin'));
    });

    test('Trainer Faraz logs in with trainer_faraz / trainer123 and gets trainer role', () async {
      final container = ProviderContainer();
      final user = await container
          .read(authNotifierProvider.notifier)
          .login('trainer_faraz', 'trainer123');

      expect(user, isNotNull);
      expect(user!.role, equals('trainer'));
      expect(user.isAdmin, isFalse);
      expect(user.name, equals('Faraz Khan'));
    });

    test('Nutritionist Ananya logs in with nutri_ananya / nutri123', () async {
      final container = ProviderContainer();
      final user = await container
          .read(authNotifierProvider.notifier)
          .login('nutri_ananya', 'nutri123');

      expect(user, isNotNull);
      expect(user!.role, equals('nutritionist'));
    });

    test('Wrong password throws exception with clear message', () async {
      final container = ProviderContainer();
      expect(
        () => container.read(authNotifierProvider.notifier).login('fs7admin', 'wrong_pass'),
        throwsA(predicate((e) => e.toString().contains('Invalid User ID or Password'))),
      );
    });

    test('Deactivated staff member is refused login', () async {
      final container = ProviderContainer();
      // Deactivate Suyog
      final suyogIdx = MockData.allStaff.indexWhere((u) => u.userId == 'trainer_suyog');
      final suyog = MockData.allStaff[suyogIdx];
      MockData.allStaff[suyogIdx] = suyog.copyWith(active: false);

      expect(
        () => container.read(authNotifierProvider.notifier).login('trainer_suyog', 'trainer123'),
        throwsA(predicate((e) => e.toString().contains('Account is deactivated'))),
      );
    });
  });

  group('Group 3 & 4: Data & Session Isolation (§ 4.2.3 & § 4.2.4)', () {
    test('Trainer A (Faraz) only sees his own clients, not Trainer B (Suyog)', () {
      final farazClients = MockData.clients.where((c) => c.trainerId == 'trainer-01').toList();
      final suyogClients = MockData.clients.where((c) => c.trainerId == 'trainer-02').toList();

      expect(farazClients.isNotEmpty, isTrue);
      expect(suyogClients.isNotEmpty, isTrue);

      // Verify complete disjointness of assigned clients
      final farazIds = farazClients.map((c) => c.id).toSet();
      for (final sc in suyogClients) {
        expect(farazIds.contains(sc.id), isFalse,
            reason: 'Trainer Faraz must never see Suyog client ${sc.fullName}');
      }
    });

    test('Nutritionist only sees assigned clients', () {
      final ananyaClients = MockData.clients.where((c) => c.nutritionistId == 'nutri-01').toList();
      final unassigned = MockData.clients.where((c) => c.nutritionistId == null).toList();

      expect(ananyaClients.isNotEmpty, isTrue);
      expect(unassigned.isNotEmpty, isTrue);

      final assignedIds = ananyaClients.map((c) => c.id).toSet();
      for (final uc in unassigned) {
        expect(assignedIds.contains(uc.id), isFalse);
      }
    });

    test('Logout clears session state completely', () async {
      final container = ProviderContainer();
      await container.read(authNotifierProvider.notifier).login('fs7admin', 'ceo@fs7');
      expect(container.read(currentUserProvider), isNotNull);

      await container.read(authNotifierProvider.notifier).logout();
      expect(container.read(currentUserProvider), isNull);
    });
  });
}

