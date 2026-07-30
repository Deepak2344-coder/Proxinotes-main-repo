import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _supabase;
  bool _googleInitialized = false;

  AuthRepository(this._supabase);

  Future<void> _ensureGoogle() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '811185103637-s39hje4nqpun4e3gp8q1rp4qu40lak6p.apps.googleusercontent.com',
      );
      _googleInitialized = true;
    }
  }

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;

  Future<void> signInWithGoogle() async {
    await _ensureGoogle();

    final account = await GoogleSignIn.instance.authenticate();
    final auth = account.authentication;
    if (auth.idToken == null) {
      throw Exception('No idToken from Google');
    }

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: auth.idToken!,
      accessToken: null,
    );
  }

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    return _supabase
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> setUsername(String userId, String username) async {
    await _supabase.from('users').upsert({
      'id': userId,
      'username': username,
      'name': username,
    });
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _supabase.auth.signOut();
  }
}
