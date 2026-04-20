import 'package:isar/isar.dart';
import 'package:beti_app/features/auth/data/models/user_model.dart';

class AuthLocalDataSource {
  final Isar _isar;

  AuthLocalDataSource(this._isar);

  Future<void> cacheSession(UserModel user) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.userModels
          .filter()
          .supabaseIdEqualTo(user.supabaseId)
          .findFirst();

      if (existing != null) {
        user.id = existing.id;
      }

      await _isar.userModels.put(user);
    });
  }

  Future<void> updateMetadata({
    required String supabaseId,
    String? displayName,
    String? avatarUrl,
  }) async {
    await _isar.writeTxn(() async {
      final user = await _isar.userModels
          .filter()
          .supabaseIdEqualTo(supabaseId)
          .findFirst();
      if (user != null) {
        if (displayName != null) user.displayName = displayName;
        if (avatarUrl != null) user.avatarUrl = avatarUrl;
        user.updatedAt = DateTime.now();
        await _isar.userModels.put(user);
      }
    });
  }

  Future<UserModel?> getCachedSession() async {
    return await _isar.userModels.where().findFirst();
  }

  Future<void> clearSession() async {
    await _isar.writeTxn(() async {
      await _isar.userModels.clear();
    });
  }

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