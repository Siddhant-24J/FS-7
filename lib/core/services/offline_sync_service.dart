import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_constants.dart';
import 'local_cache_service.dart';

class OfflineSyncService {
  OfflineSyncService._();

  static bool isOnline = true;

  static Future<void> initialize() async {
    final connectivity = Connectivity();
    try {
      final result = await connectivity.checkConnectivity();
      isOnline = !result.contains(ConnectivityResult.none);
    } catch (_) {
      isOnline = true;
    }

    connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final nowOnline = !results.contains(ConnectivityResult.none);
      if (!isOnline && nowOnline) {
        // Trigger sync when coming back online
        syncPendingData();
      }
      isOnline = nowOnline;
    });

    if (isOnline) {
      syncPendingData();
    }
  }

  static Future<void> syncPendingData() async {
    if (!SupabaseConstants.isConfigured) return;

    try {
      final queue = await LocalCacheService.getOfflineQueue();
      if (queue.isEmpty) return;

      final client = Supabase.instance.client;
      final remainingQueue = <Map<String, dynamic>>[];

      for (final item in queue) {
        final action = item['action'] as String?;
        final payload = item['payload'] as Map<String, dynamic>? ?? {};

        try {
          if (action == 'attendance') {
            await client.from(SupabaseConstants.attendanceTable).upsert(payload);
          } else if (action == 'staff_attendance') {
            await client.from(SupabaseConstants.staffAttendanceTable).upsert(payload);
          } else if (action == 'inquiry') {
            await client.from(SupabaseConstants.inquiriesTable).upsert(payload);
          } else if (action == 'followup') {
            await client.from(SupabaseConstants.inquiryFollowupsTable).insert(payload);
          }
        } catch (e) {
          debugPrint('Error syncing offline item ($action): $e');
          remainingQueue.add(item);
        }
      }

      await LocalCacheService.save('offline_queue', remainingQueue);
    } catch (e) {
      debugPrint('SyncPendingData error: $e');
    }
  }
}
