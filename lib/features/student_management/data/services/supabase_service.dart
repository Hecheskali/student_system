import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  static const String _usersTable = 'users';

  GoTrueClient get auth => _client.auth;

  User? get currentUser => auth.currentUser;

  Session? get currentSession => auth.currentSession;

  Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmailAndPassword(
    String email,
    String password,
  ) {
    return auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) {
    return _client.from(_usersTable).select().eq('id', uid).maybeSingle();
  }
}
