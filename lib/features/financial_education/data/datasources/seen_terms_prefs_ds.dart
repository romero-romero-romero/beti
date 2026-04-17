// lib/features/financial_education/data/datasources/seen_terms_prefs_ds.dart

import 'package:shared_preferences/shared_preferences.dart';

/// Persiste qué términos financieros ya consultó el usuario.
///
/// Usa SharedPreferences (no Isar) porque los términos son estáticos
/// y solo necesitamos un flag booleano por término. Evita la complejidad
/// de una collection Isar para datos efímeros.
class SeenTermsPrefsDataSource {
  static const String _keyPrefix = 'betty_seen_term_';

  /// Marca un término como visto por primera vez.
  /// Si ya estaba marcado, no sobrescribe el timestamp original.
  Future<void> markAsSeen(String termKey) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = _keyPrefix + termKey;

    if (prefs.containsKey(storageKey)) return;

    await prefs.setString(storageKey, DateTime.now().toIso8601String());
  }

  /// Indica si el usuario ya consultó este término al menos una vez.
  Future<bool> hasSeen(String termKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyPrefix + termKey);
  }

  /// Retorna cuándo se vio por primera vez. Null si nunca se ha visto.
  Future<DateTime?> firstSeenAt(String termKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPrefix + termKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Retorna el set de keys de todos los términos ya vistos.
  Future<Set<String>> getAllSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((k) => k.startsWith(_keyPrefix))
        .map((k) => k.substring(_keyPrefix.length))
        .toSet();
  }

  /// Limpia el historial de términos vistos.
  /// Útil para llamar desde logout si se desea resetear el estado educativo.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keysToRemove =
        prefs.getKeys().where((k) => k.startsWith(_keyPrefix)).toList();
    for (final k in keysToRemove) {
      await prefs.remove(k);
    }
  }
}