class SupabaseConstants {
  SupabaseConstants._();

  /// Default compile-time project URL (e.g. https://xyzcompany.supabase.co)
  static const String defaultUrl = 'https://virsakxalcazonfljhao.supabase.co';

  /// Default compile-time anon key
  static const String defaultAnonKey = 'sb_publishable_Bo3HEmCz4ukioeX2IKGVuA_e26CZAHG';

  /// Dynamic runtime override (set via Database Setup screen in app or LocalCacheService)
  static String? customUrl;
  static String? customAnonKey;

  static String get url {
    final raw = (customUrl != null && customUrl!.isNotEmpty) ? customUrl! : defaultUrl;
    return raw
        .replaceAll('/rest/v1/', '')
        .replaceAll('/rest/v1', '')
        .replaceAll(RegExp(r'/+$'), '')
        .trim();
  }

  static String get anonKey => (customAnonKey != null && customAnonKey!.isNotEmpty)
      ? customAnonKey!.trim()
      : defaultAnonKey.trim();

  /// Whether real Supabase credentials have been configured
  static bool get isConfigured =>
      url.startsWith('https://') &&
      !url.contains('YOUR_SUPABASE_URL') &&
      !url.contains('placeholder.supabase.co') &&
      anonKey.isNotEmpty &&
      !anonKey.contains('YOUR_SUPABASE_ANON_KEY') &&
      !anonKey.contains('placeholder');

  // Table names
  static const String usersTable = 'users';
  static const String clientsTable = 'clients';
  static const String plansTable = 'plans';
  static const String subscriptionsTable = 'subscriptions';
  static const String slotsTable = 'slots';
  static const String attendanceTable = 'attendance';
  static const String assessmentsTable = 'assessments';
  static const String documentsTable = 'documents';
  static const String consentsTable = 'consents';
  static const String notesTable = 'notes';
  static const String nutritionCheckinsTable = 'nutrition_checkins';
  static const String dietPlansTable = 'diet_plans';
  static const String inquiriesTable = 'inquiries';
  static const String inquiryFollowupsTable = 'inquiry_followups';
  static const String inquirySourcesTable = 'inquiry_sources';
  static const String marketingSpendTable = 'marketing_spend';
  static const String staffAttendanceTable = 'staff_attendance';
  static const String normTablesTable = 'norm_tables';
  static const String settingsTable = 'settings';
  static const String notificationsTable = 'notifications';
  static const String auditLogTable = 'audit_log';

  // Storage buckets
  static const String documentsBucket = 'documents';
  static const String photosBucket = 'photos';

  // Edge function names
  static const String applyStatusTransitionsFunc = 'apply-status-transitions';
}
