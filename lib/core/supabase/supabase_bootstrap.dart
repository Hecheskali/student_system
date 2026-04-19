import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  static Future<void> initialize({String? url, String? anonKey}) async {
    final String resolvedUrl = (url != null && url.trim().isNotEmpty)
        ? url.trim()
        : const String.fromEnvironment('SUPABASE_URL');
    final String resolvedAnonKey =
        (anonKey != null && anonKey.trim().isNotEmpty)
        ? anonKey.trim()
        : const String.fromEnvironment('SUPABASE_ANON_KEY');

    if (resolvedUrl.isEmpty || resolvedAnonKey.isEmpty) {
      debugPrint(
        'Supabase config not found. Starting in local empty-data mode. '
        'Provide inline values or SUPABASE_URL and SUPABASE_ANON_KEY '
        'with --dart-define.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: resolvedUrl,
        anonKey: resolvedAnonKey,
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
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
