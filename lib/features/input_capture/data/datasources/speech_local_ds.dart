import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// DataSource local para Speech-to-Text.
/// Usa las librerías nativas del dispositivo (Apple Speech / Google On-Device).
/// Funciona 100% offline después de descargar el modelo de idioma.
class SpeechLocalDataSource {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;

  /// Inicializa el motor STT. Retorna true si está disponible.
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) => _lastError = error.errorMsg,
      onStatus: (status) => _lastStatus = status,
    );
    return _isInitialized;
  }

  String _lastError = '';
  String _lastStatus = '';

  String get lastError => _lastError;
  String get lastStatus => _lastStatus;
  bool get isAvailable => _isInitialized;
  bool get isListening => _speech.isListening;

  /// Comienza a escuchar.
  /// [onResult] se llama con texto parcial y final.
  /// [localeId] default 'es_MX' para español México.
  Future<void> startListening({
    required void Function(SpeechRecognitionResult result) onResult,
    String localeId = 'es_MX',
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    await _speech.listen(
      onResult: onResult,
      localeId: localeId,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
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
