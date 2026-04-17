// lib/features/financial_education/presentation/providers/financial_education_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beti_app/features/financial_education/data/datasources/seen_terms_prefs_ds.dart';

// ── Dependency Injection ──

final seenTermsDsProvider = Provider<SeenTermsPrefsDataSource>((ref) {
  return SeenTermsPrefsDataSource();
});

// ── Seen Terms State ──

/// Estado reactivo del conjunto de términos que el usuario ya consultó.
///
/// Expone un `Set<String>` de keys para que los widgets puedan preguntar
/// `state.contains(key)` en O(1) y reconstruirse al agregar uno nuevo.
final seenTermsProvider =
    NotifierProvider<SeenTermsNotifier, Set<String>>(SeenTermsNotifier.new);

class SeenTermsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _hydrate();
    return <String>{};
  }

  Future<void> _hydrate() async {
    final ds = ref.read(seenTermsDsProvider);
    final seen = await ds.getAllSeen();
    state = seen;
  }

  /// Marca un término como visto. Actualiza estado primero y persiste
  /// después para respuesta inmediata en la UI.
  Future<void> markAsSeen(String termKey) async {
    if (state.contains(termKey)) return;

    state = {...state, termKey};
    await ref.read(seenTermsDsProvider).markAsSeen(termKey);
  }

  /// Consulta síncrona para widgets.
  bool hasSeen(String termKey) => state.contains(termKey);

  /// Resetea el historial de términos vistos (para logout o configuración).
  Future<void> clearAll() async {
    state = <String>{};
    await ref.read(seenTermsDsProvider).clearAll();
  }
}