import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beti_app/features/intelligence/data/datasources/tflite_categorizer_service.dart';

/// Estado de inicialización del modelo TFLite.
///
/// La inicialización del modelo es asíncrona (carga assets desde disk),
/// pero la app NO debe bloquear su UI esperando: si falla o tarda, las
/// transacciones se categorizan con el fallback de keywords (Nivel 2 del
/// CategorizationEngine).
enum TfliteInitStatus {
  /// Aún no se ha intentado cargar el modelo.
  notStarted,

  /// Cargando assets en background.
  loading,

  /// Modelo cargado, listo para predecir.
  ready,

  /// Falló la carga (asset corrupto, OOM, archivo faltante).
  /// El CategorizationEngine sigue funcionando con keywords.
  failed,
}

/// Notifier que orquesta el ciclo de vida del modelo TFLite.
///
/// **Responsabilidades:**
///   1. Disparar [TfliteCategorizerService.initialize] en background al
///      hacer login (cuando el usuario ya tiene sesión válida).
///   2. Exponer un estado observable para UI/debugging.
///   3. Liberar el intérprete con [TfliteCategorizerService.dispose] al
///      hacer logout (parte del nuclear wipe).
///
/// **Decisión arquitectónica (no bloqueante):**
/// `initialize()` se llama con `unawaited()` desde el provider de auth
/// listener en `app.dart`. Si tarda 200ms o falla, el usuario no se
/// entera; la primera transacción que se cree antes de que termine la
/// carga simplemente usa keywords. Esto preserva el principio offline-first
/// de Beti: ninguna feature secundaria bloquea el flujo principal.
class TfliteCategorizerNotifier extends StateNotifier<TfliteInitStatus> {
  TfliteCategorizerNotifier() : super(TfliteInitStatus.notStarted);

  /// Inicializa el modelo en background. Idempotente.
  ///
  /// Llamar UNA vez después del login exitoso. Si se llama varias veces
  /// (ej. re-login), solo la primera vez ejecuta carga real; las demás
  /// son no-ops gracias al check de [TfliteCategorizerService.isReady].
  ///
  /// **No lanza excepciones.** Cualquier fallo se traga y se refleja en
  /// `state = TfliteInitStatus.failed`. La capa superior decide qué hacer
  /// (típicamente nada — el fallback de keywords toma el relevo).
  Future<void> initialize() async {
    if (state == TfliteInitStatus.ready) return;
    if (state == TfliteInitStatus.loading) return;

    state = TfliteInitStatus.loading;

    try {
      await TfliteCategorizerService.instance.initialize();
      state = TfliteInitStatus.ready;
      debugPrint('[TFLite] Modelo cargado correctamente. '
          'Vocab: ${TfliteCategorizerService.instance.numClasses} clases');
    } catch (e, stack) {
      state = TfliteInitStatus.failed;
      // Loguear con stack en debug para diagnosticar; en release el
      // CategorizationEngine cae al fallback automáticamente.
      debugPrint('[TFLite] Init FAILED: $e');
      debugPrint('[TFLite] Stack: $stack');
    }
  }

  /// Libera el intérprete nativo. Llamar en logout.
  ///
  /// El nuclear wipe del repositorio de auth invocará este método a
  /// través del provider para asegurar que la memoria nativa del
  /// intérprete se libere antes de que el usuario haga otro login.
  ///
  /// Tras llamarlo, el state vuelve a `notStarted` para que un siguiente
  /// login pueda re-inicializar el modelo limpiamente.
  void disposeService() {
    TfliteCategorizerService.instance.dispose();
    state = TfliteInitStatus.notStarted;
  }

  /// `true` si el modelo está cargado y listo para inferir.
  /// Útil para UI condicional (ej: badge de "IA activa").
  bool get isReady => state == TfliteInitStatus.ready;
}

// ══════════════════════════════════════════════════════════
// Provider público
// ══════════════════════════════════════════════════════════

/// Provider del notifier que controla el ciclo de vida del modelo TFLite.
///
/// **Uso:**
/// ```dart
/// // En app.dart, dentro del listener de auth:
/// ref.read(tfliteCategorizerProvider.notifier).initialize();
///
/// // Para liberar (en signOut):
/// ref.read(tfliteCategorizerProvider.notifier).disposeService();
///
/// // Para UI reactiva (ej. mostrar un indicador de carga):
/// final status = ref.watch(tfliteCategorizerProvider);
/// if (status == TfliteInitStatus.ready) { ... }
/// ```
final tfliteCategorizerProvider =
    StateNotifierProvider<TfliteCategorizerNotifier, TfliteInitStatus>((ref) {
  return TfliteCategorizerNotifier();
});

// ══════════════════════════════════════════════════════════
// Helper top-level — para uso desde lugares sin Ref
// ══════════════════════════════════════════════════════════

/// Inicializa el modelo TFLite en background sin esperar.
///
/// Wrapper de conveniencia para cuando se necesita disparar la
/// inicialización desde un contexto donde no tiene sentido esperar
/// (ej: post-login, donde el usuario ya está navegando).
///
/// Equivalente a `unawaited(notifier.initialize())` pero más legible.
void scheduleTfliteInit(WidgetRef ref) {
  unawaited(ref.read(tfliteCategorizerProvider.notifier).initialize());
}