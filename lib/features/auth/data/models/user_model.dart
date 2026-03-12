import 'package:isar/isar.dart';

part 'user_model.g.dart';

/// Colección de usuario almacenada en Isar.
///
/// Persistir la sesión localmente para que el usuario
/// pueda abrir la app sin internet después del primer login.
@collection
class UserModel {
  Id id = Isar.autoIncrement;

  /// UUID del usuario en Supabase Auth — identificador real para sync.
  @Index(unique: true)
  late String supabaseId;

  @Index()
  late String email;

  String? displayName;

  String? avatarUrl;

  /// Token de sesión de Supabase cacheado para revalidar cuando vuelva internet.
  String? cachedAccessToken;

  String? cachedRefreshToken;

  /// Fecha del último login exitoso (con internet).
  DateTime? lastAuthAt;

  late DateTime createdAt;

  late DateTime updatedAt;

  @Enumerated(EnumType.name)
  late UserCurrency currency;

  late bool onboardingCompleted;

  @Enumerated(EnumType.name)
  late UserSyncStatus syncStatus;
}

/// Monedas soportadas (local a este schema para compatibilidad con isar_generator).
enum UserCurrency {
  mxn,
  usd,
}

/// Estado de sincronización (local a este schema para compatibilidad con isar_generator).
enum UserSyncStatus {
  pending,
  synced,
  conflict,
}
