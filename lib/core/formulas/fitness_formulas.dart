import 'dart:math' as math;
import '../constants/app_constants.dart';

/// Central calculations module.
/// ALL formulas live here and run instantly while typing.
/// Results are stored as a snapshot so old assessments never change.
class FitnessFormulas {
  FitnessFormulas._();

  // ─────────────────────────────────────────────
  // 1. AGE
  // ─────────────────────────────────────────────
  static int calculateAge(DateTime dob, DateTime testDate) {
    int age = testDate.year - dob.year;
    if (testDate.month < dob.month ||
        (testDate.month == dob.month && testDate.day < dob.day)) {
      age--;
    }
    return age;
  }

  // ─────────────────────────────────────────────
  // 2. BMI
  // ─────────────────────────────────────────────
  static double calculateBMI(double weightKg, double heightCm) {
    if (heightCm <= 0) return 0;
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  static String bmiCategory(double bmi, {String standard = AppConstants.bmiWho}) {
    if (standard == AppConstants.bmiAsiaPacific) {
      if (bmi < 18.5) return 'Underweight';
      if (bmi < 23.0) return 'Normal';
      if (bmi < 27.5) return 'Overweight';
      return 'Obese';
    }
    // WHO standard
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  /// Returns [min, max] of healthy weight range in kg
  static List<double> healthyWeightRange(double heightCm) {
    final hm = heightCm / 100;
    return [18.5 * hm * hm, 24.9 * hm * hm];
  }

  // ─────────────────────────────────────────────
  // 3. BLOOD PRESSURE
  // ─────────────────────────────────────────────
  static String bpCategory(int systolic, int diastolic) {
    if (systolic > 180 || diastolic > 120) return 'Crisis';
    if (systolic >= 140 || diastolic >= 90) return 'Stage 2 Hypertension';
    if (systolic >= 130 || diastolic >= 80) return 'Stage 1 Hypertension';
    if (systolic >= 120 && diastolic < 80) return 'Elevated';
    return 'Normal';
  }

  static bool isBloodPressureCrisis(int systolic, int diastolic) {
    return systolic > 180 || diastolic > 120;
  }

  // ─────────────────────────────────────────────
  // 4. WAIST-TO-HIP RATIO
  // ─────────────────────────────────────────────
  static double waistToHipRatio(double waistCm, double hipCm) {
    if (hipCm <= 0) return 0;
    return waistCm / hipCm;
  }

  static bool isWaistHipRatioRisk(double ratio, String gender) {
    if (gender.toLowerCase() == 'male') return ratio >= 0.90;
    return ratio >= 0.85;
  }

  static String waistHipRiskLabel(double ratio, String gender) {
    return isWaistHipRatioRisk(ratio, gender) ? 'Raised Risk' : 'Normal';
  }

  // ─────────────────────────────────────────────
  // 5. WAIST-TO-HEIGHT RATIO
  // ─────────────────────────────────────────────
  static double waistToHeightRatio(double waistCm, double heightCm) {
    if (heightCm <= 0) return 0;
    return waistCm / heightCm;
  }

  static bool isWaistHeightRatioRisk(double ratio) => ratio >= 0.5;

  // ─────────────────────────────────────────────
  // 6. BODY FAT % — US Navy method
  // ─────────────────────────────────────────────
  static double bodyFatPercentMale({
    required double waistCm,
    required double neckCm,
    required double heightCm,
  }) {
    if (waistCm <= neckCm) return 0;
    final logDiff = math.log(waistCm - neckCm) / math.ln10;
    final logHeight = math.log(heightCm) / math.ln10;
    return 495 / (1.0324 - 0.19077 * logDiff + 0.15456 * logHeight) - 450;
  }

  static double bodyFatPercentFemale({
    required double waistCm,
    required double hipCm,
    required double neckCm,
    required double heightCm,
  }) {
    final sum = waistCm + hipCm;
    if (sum <= neckCm) return 0;
    final logDiff = math.log(sum - neckCm) / math.ln10;
    final logHeight = math.log(heightCm) / math.ln10;
    return 495 / (1.29579 - 0.35004 * logDiff + 0.22100 * logHeight) - 450;
  }

  static String bodyFatCategory(double percent, String gender) {
    if (gender.toLowerCase() == 'male') {
      if (percent < 6) return 'Essential';
      if (percent < 14) return 'Athletes';
      if (percent < 18) return 'Fitness';
      if (percent < 25) return 'Average';
      return 'Obese';
    } else {
      if (percent < 14) return 'Essential';
      if (percent < 21) return 'Athletes';
      if (percent < 25) return 'Fitness';
      if (percent < 32) return 'Average';
      return 'Obese';
    }
  }

  // ─────────────────────────────────────────────
  // 7. FAT MASS & LEAN MASS
  // ─────────────────────────────────────────────
  static double fatMass(double weightKg, double bodyFatPercent) {
    return weightKg * (bodyFatPercent / 100);
  }

  static double leanMass(double weightKg, double fatMassKg) {
    return weightKg - fatMassKg;
  }

  // ─────────────────────────────────────────────
  // 8. LEFT-RIGHT ASYMMETRY
  // ─────────────────────────────────────────────
  static double asymmetryAbsolute(double left, double right) {
    return (left - right).abs();
  }

  static double asymmetryPercent(double left, double right) {
    final larger = math.max(left, right);
    if (larger == 0) return 0;
    return (left - right).abs() / larger * 100;
  }

  static bool isAsymmetryFlagged(double percent,
      {double threshold = AppConstants.defaultAsymmetryThresholdPercent}) {
    return percent >= threshold;
  }

  // ─────────────────────────────────────────────
  // 9. HEART RATE
  // ─────────────────────────────────────────────
  static int maxHeartRate(int age) {
    return (208 - 0.7 * age).round();
  }

  /// Karvonen heart rate zone
  /// intensity: 0.0 to 1.0 (e.g. 0.5 for 50%)
  static int karvonen(int maxHR, int restingHR, double intensity) {
    return ((maxHR - restingHR) * intensity + restingHR).round();
  }

  /// Returns all 5 HR zones as [min, max] pairs
  static List<Map<String, dynamic>> heartRateZones(int maxHR, int restingHR) {
    return [
      {'zone': 'Zone 1 (50–60%)', 'min': karvonen(maxHR, restingHR, 0.50), 'max': karvonen(maxHR, restingHR, 0.60)},
      {'zone': 'Zone 2 (60–70%)', 'min': karvonen(maxHR, restingHR, 0.60), 'max': karvonen(maxHR, restingHR, 0.70)},
      {'zone': 'Zone 3 (70–80%)', 'min': karvonen(maxHR, restingHR, 0.70), 'max': karvonen(maxHR, restingHR, 0.80)},
      {'zone': 'Zone 4 (80–90%)', 'min': karvonen(maxHR, restingHR, 0.80), 'max': karvonen(maxHR, restingHR, 0.90)},
      {'zone': 'Zone 5 (90–100%)', 'min': karvonen(maxHR, restingHR, 0.90), 'max': karvonen(maxHR, restingHR, 1.00)},
    ];
  }

  // ─────────────────────────────────────────────
  // 10. VO2MAX — Rockport 1-mile walk test
  //     Kline et al. (1987)
  // ─────────────────────────────────────────────
  /// [weightKg] stored kg, [age] years, [gender] 'male'/'female',
  /// [timeMinutes] walk time in decimal minutes (e.g. 11:34 → 11.5667),
  /// [heartRate] BPM at end of walk
  static double vo2max({
    required double weightKg,
    required int age,
    required String gender,
    required double timeMinutes,
    required int heartRate,
  }) {
    final weightLb = weightKg * AppConstants.kgToLb;
    final g = gender.toLowerCase() == 'male' ? 1.0 : 0.0;
    return 132.853
        - 0.0769 * weightLb
        - 0.3877 * age
        + 6.315 * g
        - 3.2649 * timeMinutes
        - 0.1565 * heartRate;
  }

  /// Parse "MM:SS" string to decimal minutes
  static double parseTimeToMinutes(String mmss) {
    final parts = mmss.split(':');
    if (parts.length != 2) return 0;
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    return minutes + seconds / 60.0;
  }

  static bool isOutsideRockportRange(int age) {
    return age < AppConstants.rockportMinAge || age > AppConstants.rockportMaxAge;
  }

  // ─────────────────────────────────────────────
  // 11. VO2MAX CATEGORY (ACSM/Cooper norms)
  // Uses norm_tables in DB; this is the in-code fallback
  // ─────────────────────────────────────────────
  static String vo2maxCategory(double vo2max, int age, String gender) {
    // ACSM norms simplified — full table loaded from DB at runtime
    // These are fallback values only
    final isMale = gender.toLowerCase() == 'male';
    if (isMale) {
      if (age < 30) {
        if (vo2max < 25) return 'Very poor';
        if (vo2max < 34) return 'Poor';
        if (vo2max < 42) return 'Fair';
        if (vo2max < 52) return 'Good';
        if (vo2max < 60) return 'Excellent';
        return 'Superior';
      } else if (age < 40) {
        if (vo2max < 23) return 'Very poor';
        if (vo2max < 30) return 'Poor';
        if (vo2max < 38) return 'Fair';
        if (vo2max < 48) return 'Good';
        if (vo2max < 56) return 'Excellent';
        return 'Superior';
      } else if (age < 50) {
        if (vo2max < 20) return 'Very poor';
        if (vo2max < 27) return 'Poor';
        if (vo2max < 35) return 'Fair';
        if (vo2max < 45) return 'Good';
        if (vo2max < 53) return 'Excellent';
        return 'Superior';
      } else {
        if (vo2max < 18) return 'Very poor';
        if (vo2max < 24) return 'Poor';
        if (vo2max < 30) return 'Fair';
        if (vo2max < 40) return 'Good';
        if (vo2max < 48) return 'Excellent';
        return 'Superior';
      }
    } else {
      if (age < 30) {
        if (vo2max < 20) return 'Very poor';
        if (vo2max < 28) return 'Poor';
        if (vo2max < 36) return 'Fair';
        if (vo2max < 45) return 'Good';
        if (vo2max < 53) return 'Excellent';
        return 'Superior';
      } else if (age < 40) {
        if (vo2max < 19) return 'Very poor';
        if (vo2max < 26) return 'Poor';
        if (vo2max < 34) return 'Fair';
        if (vo2max < 42) return 'Good';
        if (vo2max < 50) return 'Excellent';
        return 'Superior';
      } else if (age < 50) {
        if (vo2max < 17) return 'Very poor';
        if (vo2max < 24) return 'Poor';
        if (vo2max < 30) return 'Fair';
        if (vo2max < 38) return 'Good';
        if (vo2max < 46) return 'Excellent';
        return 'Superior';
      } else {
        if (vo2max < 15) return 'Very poor';
        if (vo2max < 21) return 'Poor';
        if (vo2max < 27) return 'Fair';
        if (vo2max < 35) return 'Good';
        if (vo2max < 43) return 'Excellent';
        return 'Superior';
      }
    }
  }

  // ─────────────────────────────────────────────
  // 12. YMCA 3-MIN STEP TEST RECOVERY CATEGORY
  // ─────────────────────────────────────────────
  static String recoveryCategory(int recoveryHR, int age, String gender) {
    // YMCA norms — fallback; full table from DB
    final isMale = gender.toLowerCase() == 'male';
    if (isMale) {
      if (recoveryHR < 76) return 'Excellent';
      if (recoveryHR < 84) return 'Good';
      if (recoveryHR < 92) return 'Above average';
      if (recoveryHR < 100) return 'Average';
      if (recoveryHR < 112) return 'Below average';
      if (recoveryHR < 124) return 'Poor';
      return 'Very poor';
    } else {
      if (recoveryHR < 84) return 'Excellent';
      if (recoveryHR < 92) return 'Good';
      if (recoveryHR < 100) return 'Above average';
      if (recoveryHR < 108) return 'Average';
      if (recoveryHR < 120) return 'Below average';
      if (recoveryHR < 132) return 'Poor';
      return 'Very poor';
    }
  }

  // ─────────────────────────────────────────────
  // 13. PUSH-UP RATING (ACSM norms — fallback)
  // ─────────────────────────────────────────────
  static String pushupRating(int count, int age, String gender) {
    final isMale = gender.toLowerCase() == 'male';
    if (isMale) {
      if (age < 30) {
        if (count < 17) return 'Poor';
        if (count < 22) return 'Fair';
        if (count < 29) return 'Good';
        return 'Excellent';
      } else if (age < 40) {
        if (count < 13) return 'Poor';
        if (count < 18) return 'Fair';
        if (count < 23) return 'Good';
        return 'Excellent';
      } else if (age < 50) {
        if (count < 10) return 'Poor';
        if (count < 14) return 'Fair';
        if (count < 19) return 'Good';
        return 'Excellent';
      } else {
        if (count < 7) return 'Poor';
        if (count < 11) return 'Fair';
        if (count < 15) return 'Good';
        return 'Excellent';
      }
    } else {
      if (age < 30) {
        if (count < 12) return 'Poor';
        if (count < 18) return 'Fair';
        if (count < 23) return 'Good';
        return 'Excellent';
      } else if (age < 40) {
        if (count < 10) return 'Poor';
        if (count < 15) return 'Fair';
        if (count < 20) return 'Good';
        return 'Excellent';
      } else if (age < 50) {
        if (count < 7) return 'Poor';
        if (count < 12) return 'Fair';
        if (count < 16) return 'Good';
        return 'Excellent';
      } else {
        if (count < 5) return 'Poor';
        if (count < 10) return 'Fair';
        if (count < 13) return 'Good';
        return 'Excellent';
      }
    }
  }

  // ─────────────────────────────────────────────
  // 14. FLEXIBILITY SCORE
  // ─────────────────────────────────────────────
  static const Map<String, int> flexPoints = {
    'Poor': 25, 'Fair': 50, 'Good': 75, 'Excellent': 100,
  };

  static double flexibilityScore(List<String> ratings) {
    if (ratings.isEmpty) return 0;
    final sum = ratings
        .map((r) => flexPoints[r] ?? 0)
        .reduce((a, b) => a + b);
    return sum / ratings.length;
  }

  // ─────────────────────────────────────────────
  // 15. BMR — Mifflin-St Jeor
  // ─────────────────────────────────────────────
  static double bmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return gender.toLowerCase() == 'male' ? base + 5 : base - 161;
  }

  /// Activity factors
  static const Map<String, double> activityFactors = {
    'Sedentary': 1.2,
    'Light (1–3 days/week)': 1.375,
    'Moderate (3–5 days/week)': 1.55,
    'Very active (6–7 days/week)': 1.725,
  };

  static double maintenanceCalories(double bmr, String activityLevel) {
    return bmr * (activityFactors[activityLevel] ?? 1.2);
  }

  // ─────────────────────────────────────────────
  // 16. FS-7 FITNESS SCORE
  // ─────────────────────────────────────────────
  static const Map<String, int> _categoryPts = AppConstants.categoryPoints;

  static double fs7Score({
    String? vo2maxCategory,
    String? bodyFatCategory,
    String? pushupRating,
    String? squatRating,
    String? pullupRating,
    List<String>? flexibilityRatings,
    String? recoveryCategory,
  }) {
    final Map<String, double?> components = {};

    if (vo2maxCategory != null) {
      components['cardio'] = _categoryPts[vo2maxCategory]?.toDouble();
    }
    if (bodyFatCategory != null) {
      components['body_composition'] = _categoryPts[bodyFatCategory]?.toDouble();
    }

    // Muscular endurance: average of available ratings
    final List<double> muscleRatings = [];
    if (pushupRating != null && _categoryPts.containsKey(pushupRating)) {
      muscleRatings.add(_categoryPts[pushupRating]!.toDouble());
    }
    if (squatRating != null && _categoryPts.containsKey(squatRating)) {
      muscleRatings.add(_categoryPts[squatRating]!.toDouble());
    }
    if (pullupRating != null && _categoryPts.containsKey(pullupRating)) {
      muscleRatings.add(_categoryPts[pullupRating]!.toDouble());
    }
    if (muscleRatings.isNotEmpty) {
      components['muscular_endurance'] =
          muscleRatings.reduce((a, b) => a + b) / muscleRatings.length;
    }

    if (flexibilityRatings != null && flexibilityRatings.isNotEmpty) {
      components['flexibility'] = flexibilityScore(flexibilityRatings);
    }

    if (recoveryCategory != null) {
      components['recovery'] = _categoryPts[recoveryCategory]?.toDouble();
    }

    // Weights for tested components only; share proportionally
    final Map<String, double> weights = {
      'cardio': 0.25,
      'body_composition': 0.25,
      'muscular_endurance': 0.25,
      'flexibility': 0.15,
      'recovery': 0.10,
    };

    double totalWeight = 0;
    double weightedSum = 0;

    for (final key in weights.keys) {
      final val = components[key];
      if (val != null) {
        totalWeight += weights[key]!;
        weightedSum += val * weights[key]!;
      }
    }

    if (totalWeight == 0) return 0;
    return weightedSum / totalWeight;
  }

  // ─────────────────────────────────────────────
  // 17. PLAN DATES
  // ─────────────────────────────────────────────
  static DateTime planEndDate(DateTime startDate, int months) {
    final end = DateTime(startDate.year, startDate.month + months, startDate.day);
    return end.subtract(const Duration(days: 1));
  }

  static DateTime extensionEndDate(DateTime endDate) {
    return endDate.add(Duration(days: AppConstants.extensionDays));
  }

  // ─────────────────────────────────────────────
  // 18. SESSIONS REMAINING
  // ─────────────────────────────────────────────
  static int sessionsRemaining(int total, int present, int makeup) {
    return total - present - makeup;
  }

  // ─────────────────────────────────────────────
  // 19. UNIT CONVERSIONS
  // ─────────────────────────────────────────────
  static double kgToLb(double kg) => kg * AppConstants.kgToLb;
  static double lbToKg(double lb) => lb * AppConstants.lbToKg;
  static double lbsToKg(double lb) => lbToKg(lb);
  static double cmToInch(double cm) => cm * AppConstants.cmToInch;
  static double inchToCm(double inch) => inch * AppConstants.inchToCm;
  static double inchesToCm(double inch) => inchToCm(inch);

  // ─────────────────────────────────────────────
  // 20. ATTENDANCE PERCENTAGE
  // ─────────────────────────────────────────────
  static double attendancePercentage(int present, int total) {
    if (total == 0) return 0;
    return (present / total) * 100;
  }
}

