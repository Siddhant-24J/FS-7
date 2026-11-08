import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_cards.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _unit = AppConstants.unitMetric; // metric vs imperial
  String _bmiStandard = AppConstants.bmiWho; // who vs asia_pacific
  int _graceMinutes = 10;
  double _asymmetryThreshold = 5.0;

  bool _morningDigestEnabled = true;
  bool _eveningNudgeEnabled = true;
  bool _atRiskAlertEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings & Norms'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Measurement Units & Standards'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Units (Metric / Imperial)'),
                  subtitle: Text(_unit == AppConstants.unitMetric
                      ? 'Currently Metric (cm, kg) - Stored internally in cm/kg'
                      : 'Currently Imperial (inch, lb)'),
                  value: _unit == AppConstants.unitMetric,
                  onChanged: (val) {
                    setState(() => _unit = val ? AppConstants.unitMetric : AppConstants.unitImperial);
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Text('BMI Standard Cut-offs'),
                  subtitle: Text(_bmiStandard == AppConstants.bmiWho
                      ? 'WHO Standard (Overweight at 25, Obese at 30)'
                      : 'WHO Asia-Pacific (Overweight at 23, Obese at 27.5)'),
                  trailing: DropdownButton<String>(
                    value: _bmiStandard,
                    dropdownColor: AppColors.surface,
                    items: const [
                      DropdownMenuItem(value: AppConstants.bmiWho, child: Text('WHO Standard')),
                      DropdownMenuItem(value: AppConstants.bmiAsiaPacific, child: Text('Asia-Pacific')),
                    ],
                    onChanged: (v) => setState(() => _bmiStandard = v ?? _bmiStandard),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const SectionHeader(title: 'Automated Reminders & Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Owner Morning Follow-up Digest'),
                  subtitle: const Text('Daily at 9:00 AM IST ("You have X calls today")'),
                  value: _morningDigestEnabled,
                  onChanged: (v) => setState(() => _morningDigestEnabled = v),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Evening Nudge for Pending Follow-ups'),
                  subtitle: const Text('Daily at 5:00 PM IST'),
                  value: _eveningNudgeEnabled,
                  onChanged: (v) => setState(() => _eveningNudgeEnabled = v),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('At-Risk Client Alerts'),
                  subtitle: const Text('Notify when a client misses 3 consecutive sessions'),
                  value: _atRiskAlertEnabled,
                  onChanged: (v) => setState(() => _atRiskAlertEnabled = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const SectionHeader(title: 'Gym & Attendance Policies'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Staff Late Arrival Grace Period'),
                  subtitle: Text('$_graceMinutes minutes after shift start before flagging late'),
                  trailing: Text('$_graceMinutes min', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Body Asymmetry Alert Threshold'),
                  subtitle: Text('Flag left-right limb differences at $_asymmetryThreshold% or more'),
                  trailing: Text('$_asymmetryThreshold%', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const SectionHeader(title: 'Scientific Fitness Norms & Citations'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Active Norm Tables:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• VO2max: Kline et al. (1987) Rockport 1-mile walk test & ACSM / Cooper Institute tables',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  SizedBox(height: 4),
                  Text('• Recovery HR: YMCA 3-minute step test standards',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  SizedBox(height: 4),
                  Text('• Push-up Muscular Endurance: ACSM published age/gender norms',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  SizedBox(height: 4),
                  Text('• Body Fat: U.S. Navy circumference method & ACE categories',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Log Out of FS-7'),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

