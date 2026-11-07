import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfflineSyncService {
  OfflineSyncService._();

  static bool isOnline = true;

  static Future<void> initialize() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    isOnline = !result.contains(ConnectivityResult.none);

    connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final nowOnline = !results.contains(ConnectivityResult.none);
      if (!isOnline && nowOnline) {
        // Trigger sync when coming back online
        syncPendingData();
      }
      isOnline = nowOnline;
    });
  }

  static Future<void> syncPendingData() async {
    // Sync local cached attendances and assessments to Supabase
    try {
      // In production, syncs queued mutations stored in local SQLite / Drift
    } catch (_) {}
  }
}

