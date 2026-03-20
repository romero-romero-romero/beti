import 'package:betty_app/features/auth/domain/entities/user_entity.dart';

/// Contrato del repositorio de autenticación.
/// La implementación decide si usa local (Isar) o remoto (Supabase).
abstract class AuthRepository {
  /// Intenta login con email/password.
  /// Con internet: autentica en Supabase y cachea en Isar.
  /// Sin internet: verifica sesión cacheada en Isar.
  Future<UserEntity> signInWithPassword({
    required String email,
    required String password,
  });

  /// Registro con email/password (requiere internet).
  Future<UserEntity> signUp({
    required String email,
    required String password,
    String? fullName,
  });

  /// Login con Google (requiere internet).
  Future<bool> signInWithGoogle();

  /// Recuperar contraseña (requiere internet).
  Future<void> resetPassword(String email);

  /// Cerrar sesión (limpia Isar + Supabase).
  Future<void> signOut();

  /// Obtiene la sesión actual.
  /// Primero verifica Isar (offline), luego Supabase si hay internet.
  Future<UserEntity> getCurrentUser();
}
