import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// DataSource local para Speech-to-Text.
/// Usa las librerías nativas del dispositivo (Apple Speech / Google On-Device).
/// Funciona 100% offline después de descargar el modelo de idioma.
class SpeechLocalDataSource {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  String _resolvedLocale = 'es_MX';

  /// Inicializa el motor STT. Retorna true si está disponible.
  /// En Android, esto también dispara el diálogo de permiso RECORD_AUDIO
  /// la primera vez.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          _lastError = error.errorMsg;
          debugPrint('STT error: ${error.errorMsg} (permanent: ${error.permanent})');
        },
        onStatus: (status) {
          _lastStatus = status;
          debugPrint('STT status: $status');
        },
        // En Android, esto solicita RECORD_AUDIO si no se ha concedido
        debugLogging: kDebugMode,
      );
    } catch (e) {
      debugPrint('STT initialize exception: $e');
      _isInitialized = false;
      _lastError = e.toString();
      return false;
    }

    if (_isInitialized) {
      // Resolver el mejor locale disponible para español
      await _resolveSpanishLocale();
    }

    return _isInitialized;
  }

  /// Busca el mejor locale español disponible en el dispositivo.
  /// Prioridad: es_MX > es_ES > es_US > es_* > primer idioma disponible.
  Future<void> _resolveSpanishLocale() async {
    try {
      final locales = await _speech.locales();
      final ids = locales.map((l) => l.localeId).toList();

      debugPrint('STT locales disponibles: $ids');

      const preferred = ['es_MX', 'es_ES', 'es_US'];
      for (final pref in preferred) {
        if (ids.contains(pref)) {
          _resolvedLocale = pref;
          debugPrint('STT locale seleccionado: $_resolvedLocale');
          return;
        }
      }

      // Buscar cualquier variante de español
      final anySpanish = ids.firstWhere(
        (id) => id.startsWith('es'),
        orElse: () => '',
      );

      if (anySpanish.isNotEmpty) {
        _resolvedLocale = anySpanish;
        debugPrint('STT locale fallback español: $_resolvedLocale');
        return;
      }

      // Si no hay español, usar el primero disponible
      if (ids.isNotEmpty) {
        _resolvedLocale = ids.first;
        debugPrint('STT locale fallback general: $_resolvedLocale');
      }
    } catch (e) {
      debugPrint('STT resolveLocale error: $e');
    }
  }

  String _lastError = '';
  String _lastStatus = '';

  String get lastError => _lastError;
  String get lastStatus => _lastStatus;
  bool get isAvailable => _isInitialized;
  bool get isListening => _speech.isListening;
  String get resolvedLocale => _resolvedLocale;

  /// Comienza a escuchar.
  /// [onResult] se llama con texto parcial y final.
  /// Usa el locale resuelto automáticamente (español México preferido).
  Future<void> startListening({
    required void Function(SpeechRecognitionResult result) onResult,
    String? localeId,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    final locale = localeId ?? _resolvedLocale;
    debugPrint('STT: escuchando con locale $locale');

    await _speech.listen(
      onResult: onResult,
      localeId: locale,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
        // En Android, permitir que el motor de Google sugiera resultados
        // aunque la confianza sea baja (mejora la experiencia con acentos)
        autoPunctuation: true,
      ),
    );
  }

  /// Detiene la escucha.
  Future<void> stopListening() async {
    await _speech.stop();
  }

  /// Cancela la escucha sin procesar.
  Future<void> cancel() async {
    await _speech.cancel();
  }

  /// Obtiene los idiomas disponibles en el dispositivo.
  Future<List<String>> getAvailableLocales() async {
    if (!_isInitialized) await initialize();
    final locales = await _speech.locales();
    return locales.map((l) => l.localeId).toList();
  }

  void dispose() {
    _speech.cancel();
  }
}