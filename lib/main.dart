import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/offline_sync_service.dart';
import 'core/services/local_cache_service.dart';
import 'core/constants/supabase_constants.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Cache & load stored DB credentials
  await LocalCacheService.initialize();
  final savedConfig = await LocalCacheService.getSupabaseCredentials();
  if (savedConfig != null) {
    SupabaseConstants.customUrl = savedConfig['url'];
    SupabaseConstants.customAnonKey = savedConfig['anon_key'];
  }

  // Lock to portrait on phone, allow landscape on tablet
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Status bar style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0E0E0E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Firebase (wrapped in try-catch for offline / unconfigured startup)
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  // Supabase (initializes safely without resolving to localhost on web)
  try {
    await Supabase.initialize(
      url: SupabaseConstants.isConfigured
          ? SupabaseConstants.url
          : 'https://placeholder.supabase.co',
      anonKey: SupabaseConstants.isConfigured
          ? SupabaseConstants.anonKey
          : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.placeholder',
    );
  } catch (_) {}

  // Notifications
  await NotificationService.initialize();

  // Offline DB
  await OfflineSyncService.initialize();

  runApp(
    const ProviderScope(
      child: FS7App(),
    ),
  );
}

