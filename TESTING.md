# FS-7 Gym Staff App: Automated Testing & QA Guide

This document describes how to execute the automated test suites and verify feature compliance per the FS-7 QA Specification.

---

### 1. Test Suite Structure

The test suite covers all 17 required verification groups across 4 dedicated test files:

| Test File | Verification Scope | Specification Groups |
|---|---|---|
| `test/auth_role_isolation_test.dart` | Authentication per role, wrong password rejection, deactivated account blocks, cross-role data isolation (Trainer Faraz vs Suyog vs Ananya), clean logout state reset. | Groups 1, 2, 3, 4 |
| `test/slot_engine_and_status_test.dart` | The 9 core Slot Engine validation test cases (A5, M1, M2, T1, T2), subscription math invariants (`used + remaining == total`), timetable slot release on completion/deactivation, max 2 seats per trainer-hour. | Groups 7, 8, 14 |
| `test/attendance_and_rules_test.dart` | Add Client end-to-end (Bug B1), duplicate phone rejection, full-slot rejection, weekday attendance math, Sunday closed rule, trainer 24-hour edit window lock, admin past-marking, 3-consecutive-absence at-risk detection. | Groups 5, 6, 9 |
| `test/fitness_calculations_test.dart` | Golden vectors: Rockport VO2max formula, BMI classification, US Navy body fat percent, unit toggle conversions (kg/lb, cm/inch). | Group 10 |

---

### 2. How to Run the Tests

To run all automated test suites at once:
```bash
flutter test
```

To run individual test groups:
```bash
flutter test test/auth_role_isolation_test.dart
flutter test test/slot_engine_and_status_test.dart
flutter test test/attendance_and_rules_test.dart
flutter test test/fitness_calculations_test.dart
```

---

### 3. Static Code Analysis

To verify zero warnings and clean linting:
```bash
flutter analyze
```

---

### 4. Deterministic Seed Data

The test environment uses `lib/core/mock/mock_seed.dart` to deterministically populate:
- **7 Staff Members**: 1 Admin (`fs7admin`), 3 Trainers (Faraz, Suyog, Khalfan), 1 Nutritionist (Ananya), 2 Support Staff (Ramesh, Priya).
- **40 Realistic Clients**: Enrolled across all statuses (`active`, `extended`, `completed`, `deactivated`, `hold`), slot patterns (`A5`, `M1`, `M2`, `T1`, `T2`), with and without assigned nutritionists.
- **Attendance Records**: 3 months of historical data with Present, Absent, Make-up, and Cancelled entries.
- **Fitness Assessments**: Baseline and Final assessments with validated body composition metrics.
- **Inquiries**: Full spectrum from new walk-ins to converted clients and closed leads.
- **Staff Attendance**: 60 days of daily logs including leaves and week-offs.

*Safety Rule: `MockSeed.seed()` automatically halts if a production Supabase database is connected.*

