import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:beti_app/core/enums/category_type.dart';
import 'package:beti_app/features/intelligence/data/datasources/text_preprocessor.dart';

/// Resultado de una inferencia del modelo TFLite.
///
/// La `confidence` es el valor softmax de la categoría ganadora (0..1).
/// `isReliable` combina varias heurísticas para decidir si el caller
/// debe usar esta predicción o caer al fallback (keywords).
class MlPrediction {
  final CategoryType category;
  final double confidence;
  final bool isReliable;
  final int knownTokens;

  const MlPrediction({
    required this.category,
    required this.confidence,
    required this.isReliable,
    required this.knownTokens,
  });

  @override
  String toString() => 'MlPrediction('
      'cat=$category, conf=${confidence.toStringAsFixed(3)}, '
      'reliable=$isReliable, knownTokens=$knownTokens)';
}

/// Servicio de inferencia del modelo TFLite de categorización de texto.
///
/// **Responsabilidades:**
///   1. Cargar `beti_categorizer.tflite` + `labels.json` desde assets (una vez).
///   2. Delegar el preprocesamiento a [TextPreprocessor].
///   3. Ejecutar inferencia y retornar [MlPrediction] con la categoría ganadora.
///   4. Aplicar reglas de "confianza" para decidir si la predicción es usable.
///
/// **Ciclo de vida:**
///   - Singleton lazy. `initialize()` se llama UNA vez al iniciar la app
///     (típicamente al hacer login / en un provider Riverpod).
///   - `dispose()` se llama al hacer logout para liberar el intérprete nativo.
///
/// **Decisión arquitectónica:** este servicio NO decide si se usa el modelo
/// o el fallback keyword-matching. Solo reporta su resultado y una flag
/// `isReliable`. El `CategorizationEngine` (capa superior) orquesta la
/// jerarquía TFLite → overrides → keywords.
class TfliteCategorizerService {
  // ══════════════════════════════════════════════════════════
  // Assets
  // ══════════════════════════════════════════════════════════

  static const String _modelAssetPath = 'assets/ml/beti_categorizer.tflite';
  static const String _labelsAssetPath = 'assets/ml/labels.json';

  // ══════════════════════════════════════════════════════════
  // Hiperparámetros del modelo — deben coincidir con Python
  // ══════════════════════════════════════════════════════════

  /// Longitud fija de la entrada (idéntica a MAX_SEQ_LENGTH en Python).
  static const int _inputLength = 8;

  /// Umbral mínimo de softmax para confiar en la predicción.
  /// Por debajo → caer al fallback keyword-matching.
  ///
  /// Elegido con base en el training_report (~99% acc con synthetic data).
  /// En producción con datos reales esperamos ~85-92%; un 0.65 da margen
  /// para cubrir incertidumbre sin dejar pasar basura.
  static const double _confidenceThreshold = 0.65;

  /// Mínimo de tokens conocidos (en vocab) para que la predicción sea
  /// confiable. Si el usuario escribe "xyz abc" y todos los tokens son
  /// UNK, el softmax igual suma 1.0 pero la predicción es ruido puro.
  static const int _minKnownTokens = 1;

  // ══════════════════════════════════════════════════════════
  // Singleton lazy
  // ══════════════════════════════════════════════════════════

  TfliteCategorizerService._();
  static final TfliteCategorizerService _instance =
      TfliteCategorizerService._();
  static TfliteCategorizerService get instance => _instance;

  // ══════════════════════════════════════════════════════════
  // Estado interno
  // ══════════════════════════════════════════════════════════

  Interpreter? _interpreter;

  /// Mapa índice → CategoryType, cargado desde labels.json.
  /// Usamos CategoryType (no String) para detectar en compile-time si el
  /// enum de Dart se desincroniza del labels.json de Python.
  List<CategoryType>? _labels;

  /// true si [initialize] terminó y el modelo está listo para inferir.
  bool get isReady => _interpreter != null && _labels != null;

  /// Número de clases que el modelo conoce (debe ser 20).
  int get numClasses => _labels?.length ?? 0;

  // ══════════════════════════════════════════════════════════
  // Inicialización
  // ══════════════════════════════════════════════════════════

  /// Carga el modelo TFLite, el archivo de labels y el vocabulario del
  /// [TextPreprocessor]. Idempotente.
  ///
  /// **Orden de ejecución importa:**
  ///   1. TextPreprocessor.loadVocab() ANTES que Interpreter.fromAsset,
  ///      porque el constructor del Interpreter puede tardar y queremos
  ///      que cualquier fallo en vocab.json reviente primero (fail fast).
  ///   2. Labels se cargan DESPUÉS del modelo, porque es barato y sirve
  ///      de sanity-check (si labels.json está corrupto, no queremos un
  ///      Interpreter colgando en memoria).
  Future<void> initialize() async {
    if (isReady) return;

    // 1) Vocab (delegado al preprocessor)
    await TextPreprocessor.instance.loadVocab();

    // 2) Modelo TFLite
    _interpreter = await Interpreter.fromAsset(_modelAssetPath);

    // 2b) Validación fail-fast de la shape del input.
    // Si el modelo fue regenerado con otro MAX_SEQ_LENGTH en Python y
    // alguien olvidó actualizar la constante aquí, queremos reventar AHORA
    // (al iniciar la app) y no producir predicciones basura silenciosas.
    final inputShape = _interpreter!.getInputTensor(0).shape;
    // Shape esperada: [1, _inputLength] (batch=1, seq_length=8).
    assert(
      inputShape.length == 2 && inputShape[1] == _inputLength,
      'El modelo TFLite tiene input shape $inputShape pero el código '
      'espera [_, $_inputLength]. Regenera el modelo con '
      'MAX_SEQ_LENGTH=$_inputLength en generate_dataset.py o actualiza '
      'la constante _inputLength aquí.',
    );

    // 3) Labels
    final labelsJson = await rootBundle.loadString(_labelsAssetPath);
    final decoded = jsonDecode(labelsJson) as Map<String, dynamic>;

    // labels.json tiene formato {"0": "clothing", "1": "debtPayment", ...}
    // Convertimos a lista ordenada por índice.
    final sortedEntries = decoded.entries.toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

    _labels = sortedEntries
        .map((e) => _stringToCategoryType(e.value as String))
        .toList();

    // Validación fail-fast: el modelo espera exactamente 20 clases.
    // Si alguien edita labels.json a mano, aquí se detecta antes de inferir.
    assert(
      _labels!.length == CategoryType.values.length,
      'labels.json tiene ${_labels!.length} entradas pero el enum '
      'CategoryType tiene ${CategoryType.values.length}. '
      'Regenera el modelo o actualiza el enum.',
    );
  }

  // ══════════════════════════════════════════════════════════
  // Inferencia
  // ══════════════════════════════════════════════════════════

  /// Predice la categoría de una descripción de transacción.
  ///
  /// Devuelve [MlPrediction] con:
  ///   - `category`: mejor predicción (argmax).
  ///   - `confidence`: softmax de la mejor predicción (0..1).
  ///   - `isReliable`: true si supera [_confidenceThreshold] Y tiene
  ///     al menos [_minKnownTokens] tokens conocidos.
  ///   - `knownTokens`: cuántos tokens del input están en el vocab.
  ///
  /// **Thread-safety:** TFLite Interpreter no es thread-safe, pero Flutter
  /// corre Dart en el main isolate por default. Si en el futuro migramos
  /// a `compute()` o isolates, este servicio necesita refactor.
  ///
  /// Lanza [StateError] si [initialize] no se llamó previamente.
  MlPrediction predict(String description) {
    final interpreter = _interpreter;
    final labels = _labels;
    if (interpreter == null || labels == null) {
      throw StateError(
        'TfliteCategorizerService.initialize() no fue llamado. '
        'Llámalo una vez al iniciar la app.',
      );
    }

    // 1) Preprocesar → List<int> de longitud 8
    final preprocessor = TextPreprocessor.instance;
    final sequence = preprocessor.textToSequence(description);
    final knownTokens = preprocessor.countKnownTokens(description);

    // 2) Construir tensor de input con shape [1, 8] (batch=1).
    //    TFLite requiere un buffer multidimensional en Dart, no una flat list.
    final input = [sequence];

    // 3) Buffer de output con shape [1, numClasses].
    //    Inicializamos con ceros; TFLite lo sobreescribe con los softmax.
    final output = List.generate(
      1,
      (_) => List<double>.filled(labels.length, 0.0),
    );

    // 4) Ejecutar inferencia
    interpreter.run(input, output);

    // 5) Argmax y confidence
    final probabilities = output[0];
    var bestIdx = 0;
    var bestProb = probabilities[0];
    for (var i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > bestProb) {
        bestProb = probabilities[i];
        bestIdx = i;
      }
    }

    final category = labels[bestIdx];
    final isReliable =
        bestProb >= _confidenceThreshold && knownTokens >= _minKnownTokens;

    return MlPrediction(
      category: category,
      confidence: bestProb,
      isReliable: isReliable,
      knownTokens: knownTokens,
    );
  }

  // ══════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════

  /// Libera recursos nativos del intérprete.
  /// Llamar en logout (nuclear wipe) o al destruir la app.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _labels = null;
  }

  // ══════════════════════════════════════════════════════════
  // Utilidades internas
  // ══════════════════════════════════════════════════════════

  /// Convierte el nombre de categoría de `labels.json` (string del enum
  /// Python) a [CategoryType] de Dart.
  ///
  /// Si el string no coincide con ningún enum, lanza excepción explícita
  /// en initialize() (fail-fast en lugar de basura silenciosa en producción).
  static CategoryType _stringToCategoryType(String name) {
    for (final type in CategoryType.values) {
      if (type.name == name) return type;
    }
    throw FormatException(
      'Categoría "$name" en labels.json no existe en CategoryType enum. '
      'Verifica que el keyword_map.json de Python tenga las mismas keys '
      'que el enum de Dart.',
    );
  }
}
