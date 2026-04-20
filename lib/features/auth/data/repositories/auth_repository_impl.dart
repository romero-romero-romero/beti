import 'package:beti_app/features/budgets_goals/data/models/income_budget_model.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beti_app/features/auth/data/datasources/auth_local_ds.dart';
import 'package:beti_app/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:beti_app/features/auth/data/models/user_model.dart';
import 'package:beti_app/features/auth/domain/entities/user_entity.dart';
import 'package:beti_app/features/auth/domain/repositories/auth_repository.dart';

import 'package:beti_app/features/transactions/data/models/transaction_model.dart';
import 'package:beti_app/features/transactions/data/models/category_model.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_model.dart';
import 'package:beti_app/features/budgets_goals/data/models/budget_model.dart';
import 'package:beti_app/features/budgets_goals/data/models/goal_model.dart';
import 'package:beti_app/features/financial_health/data/models/health_snapshot_model.dart';
import 'package:beti_app/features/sync/data/models/sync_queue_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beti_app/features/sync/domain/repositories/sync_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource _localDs;
  final AuthRemoteDataSource _remoteDs;
  final Isar _isar;
  final SyncRepository _syncRepo;

  AuthRepositoryImpl({
    required AuthLocalDataSource localDs,
    required AuthRemoteDataSource remoteDs,
    required Isar isar,
    required SyncRepository syncRepo,
  })  : _localDs = localDs,
        _remoteDs = remoteDs,
        _isar = isar,
        _syncRepo = syncRepo;

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
    // Fix 3: último intento de flush ANTES del wipe.
    // Si hay items pendientes que no se pueden pushear (sin red, auth failure),
    // la cola se preserva y NO se wipea — esperará al próximo login.
    final queueEmpty = await _syncRepo.flushBeforeWipe();

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
      // Solo wipear la cola si quedó vacía tras el flush.
      if (queueEmpty) {
        await _isar.syncQueueModels.clear();
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('betty_last_pull_at');
    } catch (_) {}

    try {
      await _remoteDs.signOut();
    } catch (_) {}
  }

  @override
  Future<UserEntity> getCurrentUser() async {
    final cached = await _localDs.getCachedSession();

    if (cached != null) {
      try {
        final session = _remoteDs.currentSession;

        if (session != null) {
          await _localDs.updateTokens(
            supabaseId: cached.supabaseId,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken ?? '',
          );

          // Re-hydrate display name/avatar from fresh SDK metadata to cover
          // cases where the first OAuth callback cached stale or empty metadata.
          final freshUser = _remoteDs.currentUser;
          if (freshUser != null) {
            final meta = freshUser.userMetadata;
            final fullName =
                meta?['full_name'] as String? ?? meta?['name'] as String?;
            final avatar =
                meta?['avatar_url'] as String? ?? meta?['picture'] as String?;

            if ((fullName != null && fullName != cached.displayName) ||
                (avatar != null && avatar != cached.avatarUrl)) {
              await _localDs.updateMetadata(
                supabaseId: cached.supabaseId,
                displayName: fullName,
                avatarUrl: avatar,
              );
              final refreshed = await _localDs.getCachedSession();
              if (refreshed != null) return _mapCachedToEntity(refreshed);
            }
          }
          return _mapCachedToEntity(cached);
        }

        if (cached.cachedRefreshToken != null &&
            cached.cachedRefreshToken!.isNotEmpty) {
          try {
            final response = await _remoteDs.refreshSession();

            if (response.session == null) {
              // Fix 4: si hay items pendientes, NO hacer logout silencioso.
              // Confiar en el caché local y dejar que el usuario re-autentique
              // manualmente sin perder datos.
              final pending = await _syncRepo.getPendingCount();
              if (pending > 0) {
                return _mapCachedToEntity(cached);
              }
              await signOut();
              return UserEntity.empty;
            }

            await _localDs.updateTokens(
              supabaseId: cached.supabaseId,
              accessToken: response.session!.accessToken,
              refreshToken: response.session!.refreshToken ?? '',
            );
            return _mapCachedToEntity(cached);
          } on AuthException catch (_) {
            // Fix 4: mismo criterio con AuthException.
            final pending = await _syncRepo.getPendingCount();
            if (pending > 0) {
              return _mapCachedToEntity(cached);
            }
            await signOut();
            return UserEntity.empty;
          } catch (_) {
            return _mapCachedToEntity(cached);
          }
        }

        await signOut();
        return UserEntity.empty;
      } catch (_) {
        // No internet — trust the cache (offline-first).
        return _mapCachedToEntity(cached);
      }
    }

    final user = _remoteDs.currentUser;
    final session = _remoteDs.currentSession;
    if (user != null && session != null) {
      await _cacheUserSession(user, session);
      return _mapUserToEntity(user, isAuthenticated: true);
    }

    return UserEntity.empty;
  }

  Future<void> _cacheUserSession(User user, Session session) async {
    final now = DateTime.now();
    final userModel = UserModel()
      ..supabaseId = user.id
      ..email = user.email ?? ''
      ..displayName = (user.userMetadata?['full_name'] ??
          user.userMetadata?['name']) as String?
      ..avatarUrl = (user.userMetadata?['avatar_url'] ??
          user.userMetadata?['picture']) as String?
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

  UserEntity _mapUserToEntity(User user, {bool isAuthenticated = false}) {
    final meta = user.userMetadata;
    return UserEntity(
      supabaseId: user.id,
      email: user.email ?? '',
      displayName: meta?['full_name'] as String? ?? meta?['name'] as String?,
      avatarUrl: meta?['avatar_url'] as String? ?? meta?['picture'] as String?,
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
