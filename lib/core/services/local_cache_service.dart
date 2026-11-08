import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LocalCacheService {
  LocalCacheService._();

  static Directory? _cacheDir;

  static Future<void> initialize() async {
    try {
      _cacheDir = await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint('LocalCacheService init error: $e');
    }
  }

  static Future<File?> _getFile(String filename) async {
    try {
      _cacheDir ??= await getApplicationDocumentsDirectory();
      return File('${_cacheDir!.path}/$filename');
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String key, dynamic data) async {
    try {
      final file = await _getFile('cache_$key.json');
      if (file != null) {
        final jsonStr = jsonEncode(data);
        await file.writeAsString(jsonStr, flush: true);
      }
    } catch (e) {
      debugPrint('LocalCache save error for $key: $e');
    }
  }

  static Future<dynamic> load(String key) async {
    try {
      final file = await _getFile('cache_$key.json');
      if (file != null && await file.exists()) {
        final jsonStr = await file.readAsString();
        return jsonDecode(jsonStr);
      }
    } catch (e) {
      debugPrint('LocalCache load error for $key: $e');
    }
    return null;
  }

  // ── Database Credentials Override ──────────────────────────────────────────
  static Future<void> saveSupabaseCredentials({
    required String url,
    required String anonKey,
  }) async {
    await save('supabase_config', {'url': url, 'anon_key': anonKey});
  }

  static Future<Map<String, String>?> getSupabaseCredentials() async {
    final data = await load('supabase_config');
    if (data is Map && data['url'] != null && data['anon_key'] != null) {
      return {
        'url': data['url'] as String,
        'anon_key': data['anon_key'] as String,
      };
    }
    return null;
  }

  // ── Offline Mutations Queue ────────────────────────────────────────────────
  static Future<void> queueOfflineAction({
    required String actionType,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final raw = await load('offline_queue');
      final list = raw is List ? List<Map<String, dynamic>>.from(raw) : <Map<String, dynamic>>[];
      list.add({
        'action': actionType,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await save('offline_queue', list);
    } catch (e) {
      debugPrint('Queue offline action error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getOfflineQueue() async {
    final raw = await load('offline_queue');
    if (raw is List) {
      return List<Map<String, dynamic>>.from(raw);
    }
    return [];
  }

  static Future<void> clearOfflineQueue() async {
    await save('offline_queue', []);
  }
}

