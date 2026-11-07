class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'FS-7';
  static const String gymName = 'FS-7 Fitness';

  // Timezone
  static const String timeZone = 'Asia/Kolkata';

  // Slot patterns
  static const String patternA5 = 'A5';
  static const String patternM1 = 'M1';
  static const String patternM2 = 'M2';
  static const String patternT1 = 'T1';
  static const String patternT2 = 'T2';

  static const List<String> allPatterns = [patternA5, patternM1, patternM2, patternT1, patternT2];

  /// Days (1=Mon, 7=Sun) active for each pattern
  static const Map<String, List<int>> patternDays = {
    patternA5: [1, 2, 3, 4, 5], // Mon-Fri
    patternM1: [1, 3, 5],       // Mon, Wed, Fri
    patternM2: [1, 3, 5],       // Mon, Wed, Fri
    patternT1: [2, 4, 6],       // Tue, Thu, Sat
    patternT2: [2, 4, 6],       // Tue, Thu, Sat
  };

  // Timetable
  static const int timetableStartHourAM = 6;   // 6 AM
  static const int timetableEndHourAM = 11;    // 11 AM (last slot 11-12)
  static const int timetableStartHourPM = 17;  // 5 PM
  static const int timetableEndHourPM = 21;    // 9 PM (last slot 9-10)

  // Session rules
  static const int maxSeatsPerSlot = 2;
  static const int extensionDays = 14;

  // Defaults
  static const int defaultGraceMinutes = 10;
  static const double defaultAsymmetryThresholdPercent = 5.0;
  static const int coldLeadDays = 7;
  static const int renewalReminderDays = 14;

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleTrainer = 'trainer';
  static const String roleNutritionist = 'nutritionist';
  static const String roleStaff = 'staff';

  // Client statuses
  static const String statusActive = 'active';
  static const String statusExtended = 'extended';
  static const String statusCompleted = 'completed';
  static const String statusDeactivated = 'deactivated';
  static const String statusHold = 'hold';

  // Attendance statuses
  static const String attendancePresent = 'present';
  static const String attendanceAbsent = 'absent';
  static const String attendanceMakeup = 'makeup';
  static const String attendanceCancelled = 'cancelled';

  // Assessment types
  static const String assessmentBaseline = 'baseline';
  static const String assessmentFinal = 'final';
  static const String assessmentCheckpoint = 'checkpoint';

  // Notification channels
  static const String channelGeneral = 'general';
  static const String channelReminders = 'reminders';
  static const String channelAttendance = 'attendance';
  static const String channelAlerts = 'alerts';

  // Unit preferences
  static const String unitMetric = 'metric';     // cm, kg
  static const String unitImperial = 'imperial'; // inch, lb

  static const double kgToLb = 2.20462;
  static const double cmToInch = 0.393701;
  static const double lbToKg = 0.453592;
  static const double inchToCm = 2.54;

  // BMI standards
  static const String bmiWho = 'who';
  static const String bmiAsiaPacific = 'asia_pacific';

  // Program types
  static const List<String> programTypes = [
    'Personal Training',
    'Nutrition',
    'Yoga',
    'Group Program',
  ];

  // Payment methods
  static const List<String> paymentMethods = ['Cash', 'Online'];

  // Goals
  static const List<String> fitnessGoals = [
    'Fat loss',
    'Muscle gain',
    'Strength',
    'Endurance',
    'General fitness',
    'Other',
  ];

  // Flexibility ratings
  static const List<String> flexibilityRatings = ['Poor', 'Fair', 'Good', 'Excellent'];

  // Compliance ratings
  static const List<String> complianceRatings = ['Poor', 'Fair', 'Good'];

  // FS-7 Score category points mapping
  static const Map<String, int> categoryPoints = {
    'Very poor': 10,
    'Poor': 30,
    'Fair': 50,
    'Good': 70,
    'Excellent': 90,
    'Superior': 100,
    // Body fat categories
    'Athletes': 100,
    'Fitness': 90,
    'Average': 60,
    'Essential': 70,
    'Obese': 25,
  };

  // FS-7 Score weights
  static const Map<String, double> fs7ScoreWeights = {
    'cardio': 0.25,
    'body_composition': 0.25,
    'muscular_endurance': 0.25,
    'flexibility': 0.15,
    'recovery': 0.10,
  };

  // Inquiry statuses
  static const String inquiryNew = 'new';
  static const String inquiryFollowup = 'follow_up';
  static const String inquiryConverted = 'converted';
  static const String inquiryNotInterested = 'not_interested';
  static const String inquiryLost = 'lost';

  // Follow-up outcomes
  static const List<String> followupOutcomes = [
    'Spoke',
    'No answer',
    'Call back later',
    'Visit scheduled',
    'Converted',
    'Not interested',
  ];

  // Default inquiry sources
  static const List<String> defaultInquirySources = [
    'Walk-in',
    'Instagram',
    'Facebook',
    'Google',
    'Website',
    'Justdial',
    'Hoarding or board',
    'Poster or flyer',
    'Referral',
    'Other',
  ];

  // Staff attendance statuses
  static const String staffPresent = 'present';
  static const String staffAbsent = 'absent';
  static const String staffHalfDay = 'half_day';
  static const String staffLeave = 'leave';
  static const String staffWeekOff = 'week_off';
  static const String staffHoliday = 'holiday';

  // Rockport VO2max validation range
  static const int rockportMinAge = 30;
  static const int rockportMaxAge = 69;

  // Consent terms text
  static const String consentTerms =
      'I hereby voluntarily agree to participate in the physical fitness training program provided by FS-7 Fitness. '
      'I confirm that I am in good physical condition and have disclosed all relevant medical history. '
      'I understand that physical training involves potential risk of injury, and I release FS-7 Fitness, its trainers, '
      'and staff from all liability associated with this program.';
}

