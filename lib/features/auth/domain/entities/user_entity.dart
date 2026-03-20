/// Entidad de usuario del dominio.
/// Independiente de Isar y Supabase — los Repositories mapean hacia/desde aquí.
class UserEntity {
  final String supabaseId;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String currency;
  final bool onboardingCompleted;
  final bool isAuthenticated;

  const UserEntity({
    required this.supabaseId,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.currency = 'mxn',
    this.onboardingCompleted = false,
    this.isAuthenticated = false,
  });

  /// Usuario vacío (no autenticado).
  static const empty = UserEntity(
    supabaseId: '',
    email: '',
    isAuthenticated: false,
  );

  bool get isEmpty => supabaseId.isEmpty;
  bool get isNotEmpty => !isEmpty;
}
