import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/core/providers/core_providers.dart';
import 'package:betty_app/features/auth/data/datasources/auth_local_ds.dart';
import 'package:betty_app/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:betty_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:betty_app/features/auth/domain/entities/user_entity.dart';
import 'package:betty_app/features/auth/domain/repositories/auth_repository.dart';

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

  AuthNotifier(this._repository) : super(const AuthInitial());

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
  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthUnauthenticated();
  }

  String _parseAuthError(dynamic error) {
    final msg = error.toString();
    if (msg.contains('Invalid login credentials')) return 'Credenciales inválidas';
    if (msg.contains('Email not confirmed')) return 'Correo no confirmado';
    if (msg.contains('User already registered')) return 'El correo ya está registrado';
    if (msg.contains('SocketException') || msg.contains('Connection')) {
      return 'Sin conexión a internet';
    }
    return 'Error de autenticación';
  }
}

// ── Provider ──

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
