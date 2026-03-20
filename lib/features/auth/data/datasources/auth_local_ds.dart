import 'package:isar/isar.dart';
import 'package:betty_app/features/auth/data/models/user_model.dart';

/// DataSource local para autenticación.
/// Lee y escribe UserModel en Isar para persistir la sesión offline.
class AuthLocalDataSource {
  final Isar _isar;

  AuthLocalDataSource(this._isar);

  /// Guarda o actualiza la sesión del usuario en Isar.
  Future<void> cacheSession(UserModel user) async {
    await _isar.writeTxn(() async {
      // Buscar si ya existe un usuario con ese supabaseId
      final existing = await _isar.userModels
          .filter()
          .supabaseIdEqualTo(user.supabaseId)
          .findFirst();

      if (existing != null) {
        user.id = existing.id; // Mantener el mismo ID interno de Isar
      }

      await _isar.userModels.put(user);
    });
  }

  /// Obtiene la sesión cacheada del usuario (si existe).
  /// Retorna null si nunca se ha logueado.
  Future<UserModel?> getCachedSession() async {
    return await _isar.userModels.where().findFirst();
  }

  /// Elimina la sesión cacheada (logout).
  Future<void> clearSession() async {
    await _isar.writeTxn(() async {
      await _isar.userModels.clear();
    });
  }

  /// Actualiza los tokens cacheados.
  Future<void> updateTokens({
    required String supabaseId,
    required String accessToken,
    required String refreshToken,
  }) async {
    await _isar.writeTxn(() async {
      final user = await _isar.userModels
          .filter()
          .supabaseIdEqualTo(supabaseId)
          .findFirst();

      if (user != null) {
        user.cachedAccessToken = accessToken;
        user.cachedRefreshToken = refreshToken;
        user.lastAuthAt = DateTime.now();
        user.updatedAt = DateTime.now();
        await _isar.userModels.put(user);
      }
    });
  }
}
