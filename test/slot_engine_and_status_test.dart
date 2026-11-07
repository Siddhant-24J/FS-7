import 'package:flutter_test/flutter_test.dart';
import 'package:fs7_gym_app/core/formulas/slot_engine.dart';
import 'package:fs7_gym_app/core/services/server_functions_service.dart';
import 'package:fs7_gym_app/core/mock/mock_data.dart';
import 'package:fs7_gym_app/core/mock/mock_seed.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    MockSeed.seed(force: true);
  });

  group('Group 8: 9 Slot Engine Test Cases (§ 4.2.8 & § 21.1)', () {
    test('Case 1: Empty hour allows A5, M1, M2, T1, T2', () {
      final available = SlotEngine.getAvailablePatterns([]);
      for (final p in ['A5', 'M1', 'M2', 'T1', 'T2']) {
        expect(available.any((a) => a.pattern == p && a.isAvailable), isTrue);
      }
    });

    test('Case 2: A5 alone has exactly 1 seat left for A5, M1, M2, T1, T2', () {
      final available = SlotEngine.getAvailablePatterns(['A5']);
      for (final p in ['A5', 'M1', 'M2', 'T1', 'T2']) {
        expect(available.any((a) => a.pattern == p && a.isAvailable), isTrue);
      }
    });

    test('Case 3: A5 + M1 allows only T1, T2 (MWF are full at 2 seats)', () {
      final available = SlotEngine.getAvailablePatterns(['A5', 'M1']);
      expect(available.firstWhere((a) => a.pattern == 'T1').isAvailable, isTrue);
      expect(available.firstWhere((a) => a.pattern == 'T2').isAvailable, isTrue);
      expect(available.firstWhere((a) => a.pattern == 'A5').isAvailable, isFalse);
      expect(available.firstWhere((a) => a.pattern == 'M1').isAvailable, isFalse);
      expect(available.firstWhere((a) => a.pattern == 'M2').isAvailable, isFalse);
    });

    test('Case 4: A5 + M1 + T1 is completely full', () {
      final available = SlotEngine.getAvailablePatterns(['A5', 'M1', 'T1']);
      expect(available.every((a) => !a.isAvailable), isTrue);
    });

    test('Case 5: A5 + A5 is completely full (Mon-Fri 2 seats taken)', () {
      final available = SlotEngine.getAvailablePatterns(['A5', 'A5']);
      expect(available.every((a) => !a.isAvailable), isTrue);
    });

    test('Case 6: M1 + M2 + T1 + T2 is valid and full', () {
      final available = SlotEngine.getAvailablePatterns(['M1', 'M2', 'T1', 'T2']);
      expect(available.every((a) => !a.isAvailable), isTrue);
    });

    test('Case 7: Duplicate pattern M1 + M1 is refused', () {
      final available = SlotEngine.getAvailablePatterns(['M1']);
      final m1 = available.firstWhere((a) => a.pattern == 'M1');
      expect(m1.isAvailable, isFalse);
      expect(m1.reason, contains('already taken'));
    });
  });

  group('Group 7 & 14: Data Consistency & Status Transitions (§ 4.2.7 & § 4.2.14)', () {
    test('Every subscription maintains used + remaining == totalSessions', () {
      for (final sub in MockData.subscriptions) {
        final clientAttendances = MockData.attendance.where((a) => a.clientId == sub.clientId).toList();
        final used = clientAttendances.where((a) => a.isPresent || a.isMakeup).length;
        final remaining = sub.totalSessions - used;

        expect(used + remaining, equals(sub.totalSessions),
            reason: 'Math invariant violated for subscription ${sub.id}');
      }
    });

    test('No timetable slot exists for completed or deactivated subscriptions', () {
      for (final sub in MockData.subscriptions) {
        if (sub.isCompleted || sub.isDeactivated) {
          final slot = MockData.slots.where((s) => s.subscriptionId == sub.id).firstOrNull;
          expect(slot, isNull,
              reason: 'Completed/Deactivated sub ${sub.id} must not hold any timetable slot');
        }
      }
    });

    test('No trainer hour has more than 2 clients on any weekday', () {
      for (final trainer in MockData.trainers) {
        for (int h = 6; h <= 21; h++) {
          final hourSlots = MockData.slots.where((s) => s.trainerId == trainer.id && s.hourStart == h).toList();
          final patterns = hourSlots.map((s) => s.pattern).toList();
          final seatCounts = SlotEngine.dailySeatCount(patterns);

          for (final entry in seatCounts.entries) {
            expect(entry.value, lessThanOrEqualTo(2),
                reason: 'Day ${entry.key} at hour $h exceeds 2 seats for trainer ${trainer.name}');
          }
        }
      }
    });
  });
}

