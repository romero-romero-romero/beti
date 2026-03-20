import 'package:flutter/foundation.dart';
import 'package:betty_app/features/auth/data/datasources/auth_local_ds.dart';
import 'package:betty_app/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:betty_app/features/auth/data/models/user_model.dart';
import 'package:betty_app/features/auth/domain/entities/user_entity.dart';
import 'package:betty_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource _localDs;
  final AuthRemoteDataSource _remoteDs;

  AuthRepositoryImpl({
    required AuthLocalDataSource localDs,
    required AuthRemoteDataSource remoteDs,
  })  : _localDs = localDs,
        _remoteDs = remoteDs;

  @override
  Future<UserEntity> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Intentar login remoto
      final response = await _remoteDs.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && response.session != null) {
        // Éxito: cachear sesión en Isar para uso offline permanente
        await _cacheUserSession(response.user!, response.session!);
        return _mapUserToEntity(response.user!, isAuthenticated: true);
      }

      throw Exception('Login failed: no user returned');
    } catch (e) {
      debugPrint('Remote sign in failed: $e');
      // Si falla (sin internet), verificar sesión local
      final cached = await _localDs.getCachedSession();
      if (cached != null && cached.email == email) {
        return _mapCachedToEntity(cached);
      }
      rethrow;
    }
  }

  @override
  Future<UserEntity> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    // Registro SIEMPRE requiere internet
    final response = await _remoteDs.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );

    if (response.user != null) {
      if (response.session != null) {
        await _cacheUserSession(response.user!, response.session!);
      }
      return _mapUserToEntity(
        response.user!,
        isAuthenticated: response.session != null,
      );
    }

    throw Exception('Sign up failed: no user returned');
  }

  @override
  Future<bool> signInWithGoogle() async {
    return await _remoteDs.signInWithGoogle();
  }

  @override
  Future<void> resetPassword(String email) async {
    await _remoteDs.resetPassword(email);
  }

  @override
  Future<void> signOut() async {
    // Limpiar sesión local PRIMERO (prioridad offline)
    await _localDs.clearSession();

    // Luego intentar logout remoto (puede fallar sin internet, no importa)
    try {
      await _remoteDs.signOut();
    } catch (e) {
      debugPrint('Remote sign out failed (offline): $e');
    }
  }

  @override
  Future<UserEntity> getCurrentUser() async {
    // 1. Verificar sesión local en Isar (funciona offline)
    final cached = await _localDs.getCachedSession();
    if (cached != null) {
      // 2. Si hay internet, intentar refrescar tokens silenciosamente
      try {
        final session = _remoteDs.currentSession;
        if (session != null) {
          await _localDs.updateTokens(
            supabaseId: cached.supabaseId,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken ?? '',
          );
        }
      } catch (_) {
        // Sin internet: seguir con la sesión cacheada
      }

      return _mapCachedToEntity(cached);
    }

    // 3. No hay sesión local: verificar Supabase
    final user = _remoteDs.currentUser;
    final session = _remoteDs.currentSession;
    if (user != null && session != null) {
      await _cacheUserSession(user, session);
      return _mapUserToEntity(user, isAuthenticated: true);
    }

    return UserEntity.empty;
  }

  // ── Helpers privados ──

  /// Cachea la sesión de Supabase en Isar para uso offline.
  Future<void> _cacheUserSession(
    dynamic user, // Supabase User
    dynamic session, // Supabase Session
  ) async {
    final now = DateTime.now();
    final userModel = UserModel()
      ..supabaseId = user.id
      ..email = user.email ?? ''
      ..displayName = user.userMetadata?['full_name'] as String?
      ..avatarUrl = user.userMetadata?['avatar_url'] as String?
      ..cachedAccessToken = session.accessToken
      ..cachedRefreshToken = session.refreshToken
      ..lastAuthAt = now
      ..createdAt = now
      ..updatedAt = now
      ..currency = UserCurrency.mxn
      ..onboardingCompleted = false
      ..syncStatus = UserSyncStatus.synced;

    await _localDs.cacheSession(userModel);
  }

  /// Mapea un User de Supabase a UserEntity del dominio.
  UserEntity _mapUserToEntity(dynamic user, {bool isAuthenticated = false}) {
    return UserEntity(
      supabaseId: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['full_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      isAuthenticated: isAuthenticated,
    );
  }

  /// Mapea un UserModel de Isar a UserEntity del dominio.
  UserEntity _mapCachedToEntity(UserModel cached) {
    return UserEntity(
      supabaseId: cached.supabaseId,
      email: cached.email,
      displayName: cached.displayName,
      avatarUrl: cached.avatarUrl,
      currency: cached.currency.name,
      onboardingCompleted: cached.onboardingCompleted,
      isAuthenticated: true,
    );
  }
}
