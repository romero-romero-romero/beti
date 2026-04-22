import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Preprocesador de texto para el modelo TFLite de categorización.
///
/// **Paridad Python ↔ Dart:**
/// Este archivo DEBE producir exactamente los mismos token-ids que el
/// `text_to_sequence()` de `tools/ml_training/train_model.py`. Cualquier
/// divergencia (orden de normalización, regex, padding) rompe la inferencia
/// silenciosamente: el modelo ejecuta OK pero predice basura.
///
/// **Contrato del output:**
///   Lista de `int` de longitud fija [_maxSeqLength] = 8
///   Padding con [_padIdx] = 0 a la derecha
///   Tokens desconocidos → [_unkIdx] = 1
///
/// **Ciclo de vida:**
///   1. [loadVocab] (una vez al iniciar la app, idealmente en un provider)
///   2. [textToSequence] (cada vez que se categoriza una transacción)
class TextPreprocessor {
  // ══════════════════════════════════════════════════════════
  // Constantes — DEBEN coincidir con Python
  // ══════════════════════════════════════════════════════════

  /// Longitud fija de la secuencia de entrada al modelo.
  /// Debe ser idéntica a `MAX_SEQ_LENGTH` en `generate_dataset.py`.
  static const int _maxSeqLength = 8;

  /// Índice reservado para padding. Idéntico a `PAD_IDX` en Python.
  static const int _padIdx = 0;

  /// Índice reservado para tokens fuera de vocabulario.
  /// Idéntico a `UNK_IDX` en Python.
  static const int _unkIdx = 1;

  /// Longitud mínima de un token válido (idéntica al filtro de Python).
  static const int _minTokenLength = 2;

  /// Ruta al vocab.json en assets/.
  static const String _vocabAssetPath = 'assets/ml/vocab.json';

  // ══════════════════════════════════════════════════════════
  // Estado (singleton lazy)
  // ══════════════════════════════════════════════════════════

  TextPreprocessor._();
  static final TextPreprocessor _instance = TextPreprocessor._();
  static TextPreprocessor get instance => _instance;

  /// Mapa cargado: token normalizado → índice en el vocab.
  Map<String, int>? _vocab;

  /// Indica si el preprocessor está listo para inferir.
  bool get isReady => _vocab != null;

  /// Tamaño del vocabulario cargado. Útil para logs y debugging.
  int get vocabSize => _vocab?.length ?? 0;

  // ══════════════════════════════════════════════════════════
  // Carga del vocabulario
  // ══════════════════════════════════════════════════════════

  /// Carga el vocabulario desde assets/ml/vocab.json.
  ///
  /// Llamar UNA sola vez al iniciar la app (desde un provider inicializado
  /// en main.dart o al hacer auth). Idempotente: si ya está cargado, no
  /// vuelve a leer el archivo.
  ///
  /// Lanza [FormatException] si el JSON está corrupto.
  /// Lanza [Exception] si el asset no existe (bug de pubspec.yaml).
  Future<void> loadVocab() async {
    if (_vocab != null) return;

    final jsonString = await rootBundle.loadString(_vocabAssetPath);
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

    _vocab = decoded.map((key, value) => MapEntry(key, value as int));
  }

  // ══════════════════════════════════════════════════════════
  // Normalización — ESPEJO de normalize() en Python
  // ══════════════════════════════════════════════════════════

  /// Normaliza el texto aplicando exactamente las mismas transformaciones
  /// que el pipeline de entrenamiento.
  ///
  /// Pasos (ORDEN CRÍTICO):
  ///   1. lowercase
  ///   2. Remover diacríticos: á→a, é→e, í→i, ó→o, ú→u, ü→u
  ///   3. ñ → n (caso especial: no es diacrítico, es letra base)
  ///   4. No-alfanum → espacio (equivalente a `[^\w\s]` de Python)
  ///   5. Colapsar espacios múltiples
  ///   6. Trim
  static String _normalize(String text) {
    var result = text.toLowerCase();

    // Paso 2-3: remover diacríticos y ñ.
    // Python usa unicodedata.NFD; Dart no lo tiene built-in, así que hacemos
    // reemplazos explícitos. El orden no importa porque son chars distintos.
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
      // Mayúsculas ya fueron procesadas por toLowerCase(), pero las dejamos
      // como safety-net contra bugs de Unicode case folding en algunos chars.
      'Á': 'a',
      'É': 'e',
      'Í': 'i',
      'Ó': 'o',
      'Ú': 'u',
      'Ü': 'u',
      'Ñ': 'n',
    };
    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    // Paso 4: no-alfanum → espacio.
    // `\w` en Dart es [a-zA-Z0-9_] y `\s` es whitespace; igual que Python.
    result = result.replaceAll(RegExp(r'[^\w\s]'), ' ');

    // Paso 5: colapsar whitespace múltiple.
    result = result.replaceAll(RegExp(r'\s+'), ' ');

    // Paso 6: trim.
    return result.trim();
  }

  // ══════════════════════════════════════════════════════════
  // Tokenización — ESPEJO de tokenize() en Python
  // ══════════════════════════════════════════════════════════

  /// Convierte texto ya normalizado en lista de tokens válidos.
  /// Filtra tokens de longitud < [_minTokenLength].
  static List<String> _tokenize(String normalized) {
    return normalized
        .split(' ')
        .where((t) => t.length >= _minTokenLength)
        .toList();
  }

  // ══════════════════════════════════════════════════════════
  // Pipeline completo: texto → secuencia de int para TFLite
  // ══════════════════════════════════════════════════════════

  /// Convierte texto libre a secuencia de int de longitud [_maxSeqLength].
  ///
  /// Pipeline:
  ///   1. Normalizar (mismo algoritmo que Python)
  ///   2. Tokenizar (split + filter por longitud)
  ///   3. Mapear tokens → ids usando el vocab cargado
  ///   4. Truncar a [_maxSeqLength] si hay más tokens
  ///   5. Pad con [_padIdx] si hay menos
  ///
  /// Tokens desconocidos → [_unkIdx].
  ///
  /// Lanza [StateError] si el vocab no ha sido cargado todavía.
  List<int> textToSequence(String text) {
    final vocab = _vocab;
    if (vocab == null) {
      throw StateError(
        'TextPreprocessor.loadVocab() no ha sido llamado. '
        'Invócalo una vez al iniciar la app.',
      );
    }

    final normalized = _normalize(text);
    final tokens = _tokenize(normalized);

    // Mapear tokens a ids
    final ids = tokens.map((tok) => vocab[tok] ?? _unkIdx).toList();

    // Truncation
    if (ids.length > _maxSeqLength) {
      return ids.sublist(0, _maxSeqLength);
    }

    // Padding a la derecha con PAD_IDX=0
    while (ids.length < _maxSeqLength) {
      ids.add(_padIdx);
    }

    return ids;
  }

  // ══════════════════════════════════════════════════════════
  // Utilidades públicas (útiles para debugging y telemetría)
  // ══════════════════════════════════════════════════════════

  /// Expone el pipeline de normalización para testing y debugging.
  /// No pensado para uso en hot paths de categorización.
  @visibleForTestingOrDebugging
  static String debugNormalize(String text) => _normalize(text);

  /// Expone el pipeline de tokenización para testing y debugging.
  @visibleForTestingOrDebugging
  static List<String> debugTokenize(String text) => _tokenize(_normalize(text));

  /// Cantidad de tokens "reales" (no PAD, no UNK) que se mapearon de una
  /// entrada. Útil para confianza secundaria: si una entrada tiene todos
  /// los tokens en UNK, probablemente el modelo no debería opinar.
  int countKnownTokens(String text) {
    final vocab = _vocab;
    if (vocab == null) return 0;
    final tokens = _tokenize(_normalize(text));
    return tokens.where((t) => vocab.containsKey(t)).length;
  }
}

/// Marker meta-anotación sin runtime effect. Claramente indica que una API
/// es solo para tests/debug aunque sea pública.
const visibleForTestingOrDebugging = _VisibleForTestingOrDebugging();

class _VisibleForTestingOrDebugging {
  const _VisibleForTestingOrDebugging();
}