import '../constants/app_constants.dart';

/// Slot pattern engine — enforces the owner's timetable rules.
///
/// Rule: every trainer-hour has exactly 2 seats per day.
/// Each pattern occupies a seat on its active days.
/// The only valid full combinations are:
///   • A5 + M1 + T1  (Mon-Fri: 2, Sat: 1)
///   • A5 + A5       (Mon-Fri: 2)
///   • M1 + M2 + T1 + T2 (MWF: 2, TTS: 2)
class SlotEngine {
  SlotEngine._();

  /// How many seats does each pattern consume on a given weekday (1=Mon…7=Sun)?
  static int seatsOnDay(String pattern, int weekday) {
    final days = AppConstants.patternDays[pattern] ?? [];
    return days.contains(weekday) ? 1 : 0;
  }

  /// Maximum seats used on any day for a list of patterns.
  /// Must never exceed [AppConstants.maxSeatsPerSlot] = 2.
  static Map<int, int> dailySeatCount(List<String> patterns) {
    final Map<int, int> seats = {};
    for (int day = 1; day <= 7; day++) {
      seats[day] = patterns.fold(0, (sum, p) => sum + seatsOnDay(p, day));
    }
    return seats;
  }

  static bool isValidCombination(List<String> patterns) {
    final seats = dailySeatCount(patterns);
    return seats.values.every((s) => s <= AppConstants.maxSeatsPerSlot);
  }

  /// Given the patterns already booked in this trainer-hour slot,
  /// returns the patterns that are still allowed to be added.
  static List<SlotAvailability> getAvailablePatterns(List<String> existing) {
    final result = <SlotAvailability>[];

    for (final candidate in AppConstants.allPatterns) {
      // M1 and M2 may each be used only once; same for T1/T2
      // A5 may be used up to twice
      final count = existing.where((p) => p == candidate).length;
      if (candidate == AppConstants.patternA5 && count >= 2) {
        result.add(SlotAvailability(
          pattern: candidate,
          isAvailable: false,
          reason: 'A5 is already used twice in this slot',
        ));
        continue;
      }
      if (candidate != AppConstants.patternA5 && count >= 1) {
        result.add(SlotAvailability(
          pattern: candidate,
          isAvailable: false,
          reason: '$candidate is already in this slot',
        ));
        continue;
      }

      final trial = [...existing, candidate];
      if (isValidCombination(trial)) {
        result.add(SlotAvailability(
          pattern: candidate,
          isAvailable: true,
        ));
      } else {
        // Find the conflicting days
        final seats = dailySeatCount(trial);
        final overloadedDays = seats.entries
            .where((e) => e.value > AppConstants.maxSeatsPerSlot)
            .map((e) => _dayName(e.key))
            .join(', ');
        result.add(SlotAvailability(
          pattern: candidate,
          isAvailable: false,
          reason: 'Would exceed 2 clients on $overloadedDays',
        ));
      }
    }
    return result;
  }

  /// Validates whether adding [newPattern] to [existing] is allowed.
  static SlotValidationResult validateAdd(List<String> existing, String newPattern) {
    final trial = [...existing, newPattern];
    if (!isValidCombination(trial)) {
      final seats = dailySeatCount(trial);
      final overloadedDays = seats.entries
          .where((e) => e.value > AppConstants.maxSeatsPerSlot)
          .map((e) => _dayName(e.key))
          .join(', ');
      return SlotValidationResult(
        isValid: false,
        reason: 'Adding $newPattern would exceed 2 clients on $overloadedDays',
      );
    }
    // Extra uniqueness check
    if (newPattern != AppConstants.patternA5) {
      final count = existing.where((p) => p == newPattern).length;
      if (count >= 1) {
        return SlotValidationResult(
          isValid: false,
          reason: '$newPattern is already booked in this hour',
        );
      }
    }
    return SlotValidationResult(isValid: true);
  }

  /// All weekdays (1–7) on which a given pattern has a session.
  static List<int> sessionDays(String pattern) {
    return AppConstants.patternDays[pattern] ?? [];
  }

  /// Whether a pattern has a session on a specific [weekday] (1=Mon…7=Sun).
  static bool hasSessionOn(String pattern, int weekday) {
    return (AppConstants.patternDays[pattern] ?? []).contains(weekday);
  }

  /// Given a [date], returns whether a pattern has a session on that date.
  static bool hasSessionOnDate(String pattern, DateTime date) {
    // DateTime weekday: 1=Mon … 7=Sun
    return hasSessionOn(pattern, date.weekday);
  }

  /// Generate all dates in [startDate..endDate] where the pattern has a session.
  static List<DateTime> sessionDatesInRange(
    String pattern,
    DateTime startDate,
    DateTime endDate,
  ) {
    final List<DateTime> dates = [];
    var current = startDate;
    while (!current.isAfter(endDate)) {
      if (hasSessionOnDate(pattern, current)) {
        dates.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  /// Expected total sessions for a pattern in a date range.
  static int expectedSessions(String pattern, DateTime start, DateTime end) {
    return sessionDatesInRange(pattern, start, end).length;
  }

  static String _dayName(int weekday) {
    const names = {
      1: 'Monday', 2: 'Tuesday', 3: 'Wednesday',
      4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday',
    };
    return names[weekday] ?? 'Day $weekday';
  }

  /// Describes what is currently booked and what seats remain.
  static String describeSlot(List<String> patterns) {
    if (patterns.isEmpty) return 'Empty — 2 seats available';
    final seats = dailySeatCount(patterns);
    final maxSeats = seats.values.reduce((a, b) => a > b ? a : b);
    if (maxSeats >= AppConstants.maxSeatsPerSlot) {
      return 'Full — ${patterns.join(', ')}';
    }
    final available = getAvailablePatterns(patterns)
        .where((a) => a.isAvailable)
        .map((a) => a.pattern)
        .join(', ');
    return '${patterns.join(', ')} taken — $available still free';
  }
}

class SlotAvailability {
  final String pattern;
  final bool isAvailable;
  final String? reason;

  const SlotAvailability({
    required this.pattern,
    required this.isAvailable,
    this.reason,
  });
}

class SlotValidationResult {
  final bool isValid;
  final String? reason;

  const SlotValidationResult({required this.isValid, this.reason});
}

