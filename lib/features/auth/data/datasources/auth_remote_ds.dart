import 'package:supabase_flutter/supabase_flutter.dart';

/// DataSource remoto para autenticación via Supabase.
/// Solo funciona con internet. El Repository maneja el fallback offline.
class AuthRemoteDataSource {
  final SupabaseClient _client;

  AuthRemoteDataSource(this._client);

  /// Login con email y contraseña.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Registro con email y contraseña.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
  }

  /// Login con Google OAuth.
  Future<bool> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.bettyapp://auth-callback',
    );
  }

  /// Recuperar contraseña.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Cerrar sesión.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Obtener sesión actual de Supabase (puede ser null).
  Session? get currentSession => _client.auth.currentSession;

  /// Obtener usuario actual de Supabase (puede ser null).
  User? get currentUser => _client.auth.currentUser;
}
