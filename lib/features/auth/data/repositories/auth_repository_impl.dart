import 'package:betty_app/features/budgets_goals/data/models/income_budget_model.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:betty_app/features/auth/data/datasources/auth_local_ds.dart';
import 'package:betty_app/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:betty_app/features/auth/data/models/user_model.dart';
import 'package:betty_app/features/auth/domain/entities/user_entity.dart';
import 'package:betty_app/features/auth/domain/repositories/auth_repository.dart';

// Imports de TODAS las colecciones para el nuclear wipe
import 'package:betty_app/features/transactions/data/models/transaction_model.dart';
import 'package:betty_app/features/transactions/data/models/category_model.dart';
import 'package:betty_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:betty_app/features/cards_credits/data/models/credit_model.dart';
import 'package:betty_app/features/budgets_goals/data/models/budget_model.dart';
import 'package:betty_app/features/budgets_goals/data/models/goal_model.dart';
import 'package:betty_app/features/financial_health/data/models/health_snapshot_model.dart';
import 'package:betty_app/features/sync/data/models/sync_queue_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource _localDs;
  final AuthRemoteDataSource _remoteDs;
  final Isar _isar;

  AuthRepositoryImpl({
    required AuthLocalDataSource localDs,
    required AuthRemoteDataSource remoteDs,
    required Isar isar,
  })  : _localDs = localDs,
        _remoteDs = remoteDs,
        _isar = isar;

  // ── Sign In ──

  @override
  Future<UserEntity> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _remoteDs.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && response.session != null) {
        await _cacheUserSession(response.user!, response.session!);
        return _mapUserToEntity(response.user!, isAuthenticated: true);
      }

      throw Exception('Login failed: no user returned');
    } catch (e) {
      debugPrint('Remote sign in failed: $e');
      final cached = await _localDs.getCachedSession();
      if (cached != null && cached.email == email) {
        return _mapCachedToEntity(cached);
      }
      rethrow;
    }
  }

  // ── Sign Up ──

  @override
  Future<UserEntity> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
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

  // ── Google / Reset ──

  @override
  Future<bool> signInWithGoogle() async {
    return await _remoteDs.signInWithGoogle();
  }

  @override
  Future<void> resetPassword(String email) async {
    await _remoteDs.resetPassword(email);
  }

  // ── Sign Out (NUCLEAR WIPE) ──

  @override
  Future<void> signOut() async {
    // 1. Limpiar TODAS las colecciones de Isar
    await _isar.writeTxn(() async {
      await _isar.userModels.clear();
      await _isar.transactionModels.clear();
      await _isar.categoryModels.clear();
      await _isar.creditCardModels.clear();
      await _isar.creditModels.clear();
      await _isar.budgetModels.clear();
      await _isar.incomeBudgetModels.clear();
      await _isar.goalModels.clear();
      await _isar.healthSnapshotModels.clear();
      await _isar.syncQueueModels.clear();
    });

    // 2. Limpiar SharedPreferences de sync
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('betty_last_pull_at');
    } catch (e) {
      debugPrint('Failed to clear SharedPreferences: $e');
    }

    // 3. Logout remoto (puede fallar sin internet)
    try {
      await _remoteDs.signOut();
    } catch (e) {
      debugPrint('Remote sign out failed (offline): $e');
    }
  }

  // ── Get Current User (con validación de tokens) ──

  @override
  Future<UserEntity> getCurrentUser() async {
    // 1. Verificar sesión local en Isar
    final cached = await _localDs.getCachedSession();

    if (cached != null) {
      // 2. Si hay internet, validar que la sesión siga viva
      try {
        final session = _remoteDs.currentSession;

        if (session != null) {
          // SDK tiene sesión → refrescar tokens en cache
          await _localDs.updateTokens(
            supabaseId: cached.supabaseId,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken ?? '',
          );
          return _mapCachedToEntity(cached);
        }

        // SDK no tiene sesión → intentar refresh
        if (cached.cachedRefreshToken != null &&
            cached.cachedRefreshToken!.isNotEmpty) {
          try {
            final response = await _remoteDs.refreshSession();
            if (response.session != null) {
              await _localDs.updateTokens(
                supabaseId: cached.supabaseId,
                accessToken: response.session!.accessToken,
                refreshToken: response.session!.refreshToken ?? '',
              );
              return _mapCachedToEntity(cached);
            }
          } catch (_) {
            debugPrint('Refresh session failed — invalidating local cache');
          }
        }

        // Token inválido o usuario eliminado → nuclear wipe
        await signOut();
        return UserEntity.empty;
      } catch (_) {
        // Sin internet: confiar en el cache (correcto para offline-first)
        return _mapCachedToEntity(cached);
      }
    }

    // 3. No hay sesión local: verificar Supabase directamente
    final user = _remoteDs.currentUser;
    final session = _remoteDs.currentSession;
    if (user != null && session != null) {
      await _cacheUserSession(user, session);
      return _mapUserToEntity(user, isAuthenticated: true);
    }

    return UserEntity.empty;
  }

  // ── Helpers privados ──

  Future<void> _cacheUserSession(
    dynamic user,
    dynamic session,
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

  UserEntity _mapUserToEntity(dynamic user, {bool isAuthenticated = false}) {
    return UserEntity(
      supabaseId: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['full_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      isAuthenticated: isAuthenticated,
    );
  }

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