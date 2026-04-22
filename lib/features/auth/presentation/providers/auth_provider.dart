import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beti_app/core/providers/core_providers.dart';
import 'package:beti_app/features/auth/data/datasources/auth_local_ds.dart';
import 'package:beti_app/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:beti_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:beti_app/features/auth/domain/entities/user_entity.dart';
import 'package:beti_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:beti_app/features/financial_health/presentation/providers/health_provider.dart';
import 'package:beti_app/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:beti_app/features/budgets_goals/presentation/providers/budgets_goals_provider.dart';
import 'package:beti_app/features/cards_credits/presentation/providers/cards_credits_provider.dart';
import 'package:beti_app/features/sync/presentation/providers/sync_provider.dart';
import 'package:beti_app/features/intelligence/presentation/providers/tflite_categorizer_provider.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb show Supabase, AuthChangeEvent, AuthState;

// ── Dependency Injection via Riverpod ──

final authLocalDsProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSource(ref.watch(isarProvider));
});

final authRemoteDsProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(supabaseProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    localDs: ref.watch(authLocalDsProvider),
    remoteDs: ref.watch(authRemoteDsProvider),
    isar: ref.watch(isarProvider),
    syncRepo: ref.watch(syncRepositoryProvider),
  );
});

// ── Auth State ──

/// Estado de autenticación de la app.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

// ── Auth Notifier ──

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;
  late final StreamSubscription<sb.AuthState> _authSub;

  AuthNotifier(this._repository, this._ref) : super(const AuthInitial()) {
    // Escuchar eventos de auth del SDK (OAuth callback, token refresh).
    // Sin esto, tras completar OAuth Google la app no reacciona al regreso
    // del browser y el usuario debe reiniciar la app para ver la sesión.
    _authSub = sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == sb.AuthChangeEvent.signedIn ||
          event == sb.AuthChangeEvent.tokenRefreshed) {
        checkAuthStatus();
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  /// Verifica si hay sesión activa (local o remota).
  Future<void> checkAuthStatus() async {
    state = const AuthLoading();
    try {
      final user = await _repository.getCurrentUser();
      if (user.isNotEmpty) {
        state = AuthAuthenticated(user);
      } else {
        state = const AuthUnauthenticated();
      }
    } catch (e) {
      state = const AuthUnauthenticated();
    }
  }

  /// Login con email/password.
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    try {
      final user = await _repository.signInWithPassword(
        email: email,
        password: password,
      );
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(_parseAuthError(e));
    }
  }

  /// Registro con email/password.
  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = const AuthLoading();
    try {
      final user = await _repository.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
      if (user.isAuthenticated) {
        state = AuthAuthenticated(user);
      } else {
        // Email de verificación enviado
        state = const AuthUnauthenticated();
      }
    } catch (e) {
      state = AuthError(_parseAuthError(e));
    }
  }

  /// Login con Google.
  Future<void> signInWithGoogle() async {
    state = const AuthLoading();
    try {
      await _repository.signInWithGoogle();
      // OAuth redirige al browser, el estado se actualiza en checkAuthStatus
    } catch (e) {
      state = AuthError(_parseAuthError(e));
    }
  }

  /// Recuperar contraseña.
  Future<void> resetPassword(String email) async {
    await _repository.resetPassword(email);
  }

  /// Cerrar sesión.
  ///
  /// A2: Orden obligatorio:
  ///   1. Unsubscribe del Realtime (evita escrituras post-wipe)
  ///   2. Repository.signOut() (nuclear wipe + clear session)
  ///   3. state = AuthUnauthenticated
  ///   4. Invalidación desacoplada de providers
  Future<void> signOut() async {
    // 1. Cortar realtime ANTES del wipe.
    // Si falla (ej. sin red), continuamos igual — el wipe no debe bloquearse.
    try {
      await _ref.read(syncProvider.notifier).disposeRealtime();
    } catch (_) {
      // Silencioso: no queremos que un error de red impida el logout.
    }

    // 1b. Liberar el intérprete TFLite (memoria nativa fuera del GC).
    // Sin esto hay leak de ~2 MB por sesión cuando el usuario hace login
    // → logout → login en la misma sesión del proceso.
    try {
      _ref.read(tfliteCategorizerProvider.notifier).disposeService();
    } catch (_) {
      // Silencioso: si el servicio nunca se inicializó, dispose es no-op.
    }

    // 2. Nuclear wipe + clear session de Supabase.
    await _repository.signOut();

    // 3. Cambiar state para que los listeners reaccionen.
    state = const AuthUnauthenticated();

    // 4. Desacoplar invalidaciones para evitar CircularDependencyError.
    Future.microtask(() {
      _ref.invalidate(healthProvider);
      _ref.invalidate(transactionsProvider);
      _ref.invalidate(budgetsProvider);
      _ref.invalidate(goalsProvider);
      _ref.invalidate(creditCardsProvider);
      _ref.invalidate(creditsProvider);
      _ref.invalidate(pendingSyncCountProvider);
    });
  }

  String _parseAuthError(dynamic error) {
    final msg = error.toString();
    if (msg.contains('Invalid login credentials')) {
      return 'Credenciales inválidas';
    }
    if (msg.contains('Email not confirmed')) return 'Correo no confirmado';
    if (msg.contains('User already registered')) {
      return 'El correo ya está registrado';
    }
    if (msg.contains('SocketException') || msg.contains('Connection')) {
      return 'Sin conexión a internet';
    }
    return 'Error de autenticación';
  }
}

// ── Provider ──

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository, ref); // ← pasar ref
});
