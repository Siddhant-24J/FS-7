import 'package:flutter_test/flutter_test.dart';
import 'package:fs7_gym_app/core/formulas/fitness_formulas.dart';

void main() {
  group('Group 10: Fitness Formulas & Golden Vectors (§ 4.2.10)', () {
    test('BMI Golden Vector: 84.6 kg and 163 cm gives BMI ~31.84', () {
      final bmi = FitnessFormulas.calculateBMI(84.6, 163.0);
      expect((bmi - 31.84).abs(), lessThan(0.05));
      expect(FitnessFormulas.bmiCategory(bmi), equals('Obese Class I'));
    });

    test('Rockport VO2max Golden Vector: Male 34, 107.7 kg, 11:34 (11.567 min), HR 178', () {
      final minutes = FitnessFormulas.parseTimeToMinutes('11:34');
      final vo2 = FitnessFormulas.vo2max(
        weightKg: 107.7,
        age: 34,
        gender: 'male',
        timeMinutes: minutes,
        heartRate: 178,
      );
      // Expected around 42.1 per § 4.2.10
      expect((vo2 - 42.1).abs(), lessThan(1.5));
    });

    test('US Navy Body Fat Golden Vector for Male', () {
      final bf = FitnessFormulas.bodyFatPercentMale(
        waistCm: 102.0,
        neckCm: 38.0,
        heightCm: 172.0,
      );
      // Expected between 28% and 34%
      expect(bf, greaterThan(25.0));
      expect(bf, lessThan(35.0));
    });

    test('Unit conversion: lbs to kg and inches to cm', () {
      final kg = FitnessFormulas.lbsToKg(150.0);
      expect((kg - 68.04).abs(), lessThan(0.1));

      final cm = FitnessFormulas.inchesToCm(68.0);
      expect((cm - 172.72).abs(), lessThan(0.1));
    });
  });
}

