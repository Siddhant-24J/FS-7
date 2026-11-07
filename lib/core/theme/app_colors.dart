import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core backgrounds
  static const Color background = Color(0xFF0E0E0E);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceRaised = Color(0xFF262626);
  static const Color border = Color(0xFF2A2A2A);

  // Text
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9A9A9A);

  // Brand
  static const Color brandOrange = Color(0xFFF58000);
  static const Color brandOrangePressed = Color(0xFFD96F00);

  // Semantic
  static const Color success = Color(0xFF3FB950);
  static const Color warning = Color(0xFFF2A93B);
  static const Color error = Color(0xFFE5484D);

  // Slot pattern colours (timetable grid)
  static const Color slotA5 = Color(0xFFE53935);    // Red (muted)
  static const Color slotM1 = Color(0xFFFFB300);    // Amber/Yellow
  static const Color slotM2 = Color(0xFFAB47BC);    // Magenta/Purple
  static const Color slotT1 = Color(0xFF00ACC1);    // Cyan
  static const Color slotT2 = Color(0xFF90A4AE);    // Light gray/blue

  // Status chip colours
  static const Color statusActive = Color(0xFF3FB950);
  static const Color statusExtended = Color(0xFFF2A93B);
  static const Color statusCompleted = Color(0xFF9A9A9A);
  static const Color statusDeactivated = Color(0xFFE5484D);
  static const Color statusHold = Color(0xFF5C85D6);

  // Attendance dot colours
  static const Color attendancePresent = Color(0xFF3FB950);
  static const Color attendanceAbsent = Color(0xFFE5484D);
  static const Color attendanceCancelled = Color(0xFF9A9A9A);
  static const Color attendanceMakeup = Color(0xFFF58000);

  // Helper methods
  static Color slotColor(String pattern) {
    switch (pattern) {
      case 'A5': return slotA5;
      case 'M1': return slotM1;
      case 'M2': return slotM2;
      case 'T1': return slotT1;
      case 'T2': return slotT2;
      default: return textSecondary;
    }
  }

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return statusActive;
      case 'extended': return statusExtended;
      case 'completed': return statusCompleted;
      case 'deactivated': return statusDeactivated;
      case 'hold': return statusHold;
      default: return textSecondary;
    }
  }
}

