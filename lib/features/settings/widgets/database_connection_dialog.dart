import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';

class DatabaseConnectionDialog extends StatefulWidget {
  const DatabaseConnectionDialog({super.key});

  @override
  State<DatabaseConnectionDialog> createState() => _DatabaseConnectionDialogState();
}

class _DatabaseConnectionDialogState extends State<DatabaseConnectionDialog> {
  final _urlCtrl = TextEditingController();
  final _anonKeyCtrl = TextEditingController();
  bool _testing = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = SupabaseConstants.customUrl ??
        (SupabaseConstants.isConfigured ? SupabaseConstants.url : '');
    _anonKeyCtrl.text = SupabaseConstants.customAnonKey ??
        (SupabaseConstants.isConfigured ? SupabaseConstants.anonKey : '');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _anonKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final url = _urlCtrl.text.trim();
    final key = _anonKeyCtrl.text.trim();

    if (url.isEmpty || key.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter both Supabase Project URL and Anon Key.';
        _isSuccess = false;
      });
      return;
    }

    if (!url.startsWith('https://')) {
      setState(() {
        _statusMessage = 'Project URL must start with https:// (e.g. https://xyz.supabase.co)';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _statusMessage = 'Testing connection to Supabase...';
      _isSuccess = false;
    });

    try {
      // Re-initialize Supabase client dynamically
      await Supabase.initialize(
        url: url,
        anonKey: key,
      );

      // Test query to verify tables exist
      final client = Supabase.instance.client;
      await client.from(SupabaseConstants.plansTable).select('id').limit(1);

      // Save permanently to local cache
      await LocalCacheService.saveSupabaseCredentials(url: url, anonKey: key);
      SupabaseConstants.customUrl = url;
      SupabaseConstants.customAnonKey = key;

      setState(() {
        _testing = false;
        _isSuccess = true;
        _statusMessage = 'Connected successfully to Supabase! All devices sharing this project will see live synced data.';
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _isSuccess = false;
        _statusMessage = 'Connection test failed: $e\n\nEnsure you have run supabase_schema.sql in your Supabase SQL Editor.';
      });
    }
  }

  Future<void> _resetToLocal() async {
    await LocalCacheService.saveSupabaseCredentials(url: '', anonKey: '');
    SupabaseConstants.customUrl = null;
    SupabaseConstants.customAnonKey = null;
    setState(() {
      _urlCtrl.clear();
      _anonKeyCtrl.clear();
      _isSuccess = true;
      _statusMessage = 'Reset to local in-memory mode.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = SupabaseConstants.isConfigured;

    return AlertDialog(
      backgroundColor: AppColors.surfaceRaised,
      title: Row(
        children: [
          Icon(
            isConfigured ? Icons.cloud_done : Icons.cloud_off,
            color: isConfigured ? AppColors.success : AppColors.brandOrange,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Database Connection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isConfigured ? AppColors.success : AppColors.brandOrange).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isConfigured ? AppColors.success : AppColors.brandOrange).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isConfigured ? Icons.check_circle : Icons.info_outline,
                      size: 16,
                      color: isConfigured ? AppColors.success : AppColors.brandOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isConfigured
                            ? 'Connected to Live Cloud Database'
                            : 'Currently in Offline / In-Memory Mode',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isConfigured ? AppColors.success : AppColors.brandOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Connect all trainer and admin APKs to a shared Supabase database so everyone sees the exact same clients, slots, and attendance.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _urlCtrl,
                label: 'Supabase Project URL',
                hint: 'https://xyzcompany.supabase.co',
                prefixIcon: Icons.link,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _anonKeyCtrl,
                label: 'Supabase Anon Public API Key',
                hint: 'eyJhbGciOiJIUzI1NiIsInR5cCI6...',
                prefixIcon: Icons.key,
                maxLines: 2,
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_isSuccess ? AppColors.success : AppColors.error).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_isSuccess ? AppColors.success : AppColors.error).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isSuccess ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (isConfigured)
          TextButton(
            onPressed: _resetToLocal,
            child: const Text('Disconnect', style: TextStyle(color: AppColors.error)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandOrange),
          onPressed: _testing ? null : _testAndSave,
          child: _testing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Save & Connect'),
        ),
      ],
    );
  }
}

