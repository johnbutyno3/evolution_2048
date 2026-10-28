import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client bootstrap used during the Firebase-to-Supabase migration.
/// Only the project URL and publishable/anon key may be passed by the client.
/// Never pass a service-role key to this class.
class SupabaseBackend {
  SupabaseBackend._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError('SupabaseBackend.initialize() must run first.');
    }
    return Supabase.instance.client;
  }

  static Future<bool> initialize({
    required String url,
    required String publishableKey,
  }) async {
    if (_initialized) return true;

    final normalizedUrl = url.trim();
    final normalizedKey = publishableKey.trim();
    if (normalizedUrl.isEmpty || normalizedKey.isEmpty) {
      // Keep Firebase startup intact until all Firebase call sites are migrated.
      // This avoids switching authentication alone and breaking dependent services.
      debugPrint('Supabase is not configured; migration bootstrap skipped.');
      return false;
    }

    await Supabase.initialize(
      url: normalizedUrl,
      publishableKey: normalizedKey,
    );
    _initialized = true;
    return true;
  }
}
