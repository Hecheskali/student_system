import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  static Future<void> initialize({String? url, String? anonKey}) async {
    final String resolvedUrl = (url != null && url.trim().isNotEmpty)
        ? url.trim()
        : const String.fromEnvironment('SUPABASE_URL');
    const String anonKeyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
    const String publishableKeyDefine = String.fromEnvironment('SUPABASE_KEY');
    final String resolvedAnonKey =
        (anonKey != null && anonKey.trim().isNotEmpty)
        ? anonKey.trim()
        : anonKeyDefine.isNotEmpty
        ? anonKeyDefine
        : publishableKeyDefine;

    if (resolvedUrl.isEmpty || resolvedAnonKey.isEmpty) {
      debugPrint(
        'Supabase config not found. Live authentication is disabled. '
        'Provide inline values or SUPABASE_URL plus SUPABASE_ANON_KEY '
        'or SUPABASE_KEY '
        'with --dart-define.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: resolvedUrl,
        anonKey: resolvedAnonKey,
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
      );
    } on Exception catch (error, stackTrace) {
      debugPrint('Supabase initialization skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } on Object {
      return null;
    }
  }
}
