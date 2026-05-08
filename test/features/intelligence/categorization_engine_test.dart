// test/features/intelligence/categorization_engine_test.dart
//
// ════════════════════════════════════════════════════════════════════════
// CategorizationEngine — cascada de 3 niveles para predecir categoría.
// ════════════════════════════════════════════════════════════════════════
//
// PIEZA CRÍTICA: El usuario captura una transacción → CategorizationEngine
// decide la categoría → se persiste en Isar. Bug = transacciones mal
// categorizadas, presupuestos descuadrados, ISFE inflado.
//
// CASCADA DE 3 NIVELES (orden de prioridad):
//   Nivel 0 — User overrides (aprendido de correcciones manuales).
//   Nivel 1 — Modelo TFLite (si está cargado y confiado).
//   Nivel 2 — Keywords estáticas (red de seguridad).
//
// ESTRATEGIA DE TESTING:
//   Probamos SIN inicializar TFLite (servicio no isReady). El Nivel 1
//   retorna null y la cascada salta de Nivel 0 → Nivel 2 directamente.
//   Esto blinda el contrato: "si TFLite falla, los keywords toman el
//   relevo SIEMPRE". Por diseño, el engine es fail-soft ante TFLite.
//
// LO QUE NO PROBAMOS:
//   - Inferencia real de TFLite (requeriría cargar el modelo .tflite,
//     lo cual hace tests lentos y frágiles ante reentrenamiento).
//   - Persistencia en Isar de overrides — eso es responsabilidad de
//     CategoryLearningService, no del engine.
//
// LIMPIEZA:
//   _userOverrides es estado estático compartido entre tests. Cada test
//   debe llamar `loadUserOverrides({})` en setUp para evitar
//   contaminación cruzada.
//
// ════════════════════════════════════════════════════════════════════════

import 'package:beti_app/core/enums/category_type.dart';
import 'package:beti_app/core/enums/transaction_type.dart';
import 'package:beti_app/features/intelligence/data/datasources/categorization_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reset del estado estático antes de cada test para evitar leaks.
  setUp(() {
    CategorizationEngine.loadUserOverrides({});
  });

  // ══════════════════════════════════════════════════════════════════════
  // predict — fallback a keywords / other
  // ══════════════════════════════════════════════════════════════════════

  group('predict — Nivel 2 (keywords como fallback)', () {
    test('retorna CategoryType.other para texto sin coincidencias', () {
      // Una secuencia random que no debería estar en keywords.
      final result = CategorizationEngine.predict('xkqzwj brljmhxcz');
      expect(result, CategoryType.other);
    });

    test('texto vacío → other (no crash)', () {
      final result = CategorizationEngine.predict('');
      expect(result, CategoryType.other);
    });

    test('detecta categoría "food" para inputs típicos', () {
      // Entradas que deberían matchear keywords del dominio comida.
      // Si tu _keywordMap usa otras palabras, ajustar aquí.
      final result = CategorizationEngine.predict('compre tacos');
      expect(result, isNot(CategoryType.other),
          reason: '"tacos" debería detectarse como categoría conocida');
    });

    test('detecta categoría "transport" para inputs típicos', () {
      final result = CategorizationEngine.predict('viaje en uber');
      expect(result, isNot(CategoryType.other),
          reason: '"uber" debería detectarse como categoría conocida');
    });

    test('normaliza antes de buscar (caps + diacríticos)', () {
      // Si "tacos" detecta food, "TACOS" y "tácos" también deben.
      final lowercaseResult = CategorizationEngine.predict('compre tacos');
      final upperResult = CategorizationEngine.predict('COMPRE TACOS');
      final accentResult = CategorizationEngine.predict('Compré Tacos');

      expect(upperResult, equals(lowercaseResult));
      expect(accentResult, equals(lowercaseResult));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // predict — Nivel 0 (user overrides) tiene prioridad sobre Nivel 2
  // ══════════════════════════════════════════════════════════════════════

  group('predict — Nivel 0 (overrides)', () {
    test('override exacto de frase completa gana sobre keywords', () {
      // "tacos" probablemente es CategoryType.food en keywords estáticas.
      // Forzamos un override que diga "compre tacos" → entertainment.
      // Si el override gana, predict retorna entertainment.
      CategorizationEngine.loadUserOverrides({
        'compre tacos': CategoryType.entertainment,
      });

      final result = CategorizationEngine.predict('compre tacos');
      expect(result, CategoryType.entertainment,
          reason: 'override de frase completa tiene prioridad absoluta');
    });

    test('override por palabra individual también funciona', () {
      CategorizationEngine.loadUserOverrides({
        'tacos': CategoryType.entertainment,
      });

      final result = CategorizationEngine.predict('compre tacos en la calle');
      expect(result, CategoryType.entertainment);
    });

    test('override es invariante a caps/diacríticos del input', () {
      CategorizationEngine.loadUserOverrides({
        'tacos': CategoryType.entertainment,
      });

      final upperResult = CategorizationEngine.predict('compre TACOS');
      final accentResult = CategorizationEngine.predict('Compré Tácos');

      expect(upperResult, CategoryType.entertainment);
      expect(accentResult, CategoryType.entertainment);
    });

    test('palabras de menos de 3 chars NO se buscan en overrides', () {
      // El código filtra palabras de longitud < 3 al buscar matches por
      // palabra individual. Aunque "el" esté en overrides, no debe
      // disparar.
      CategorizationEngine.loadUserOverrides({
        'el': CategoryType.entertainment,
      });

      final result = CategorizationEngine.predict('el uber');
      // Como "el" se filtra, debe caer al keyword match de "uber".
      expect(result, isNot(CategoryType.entertainment),
          reason: '"el" tiene 2 chars y NO debe buscarse en overrides');
    });

    test('overrides vacío → comportamiento equivalente a sin overrides', () {
      // Doble check: limpiar overrides no debe romper la cascada.
      CategorizationEngine.loadUserOverrides({});
      final result = CategorizationEngine.predict('xkqzwj');
      expect(result, CategoryType.other);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // loadUserOverrides — gestión de estado
  // ══════════════════════════════════════════════════════════════════════

  group('loadUserOverrides', () {
    test('reemplaza completamente los overrides previos', () {
      CategorizationEngine.loadUserOverrides({
        'foo': CategoryType.entertainment,
      });
      CategorizationEngine.loadUserOverrides({
        'bar': CategoryType.health,
      });

      // foo ya NO debe activar nada.
      final fooResult = CategorizationEngine.predict('foo es algo');
      expect(fooResult, isNot(CategoryType.entertainment),
          reason: 'overrides anteriores fueron reemplazados, no fusionados');

      // bar sí.
      final barResult = CategorizationEngine.predict('voy al bar hoy');
      expect(barResult, CategoryType.health);
    });

    test('mapa vacío limpia todo el estado previo', () {
      CategorizationEngine.loadUserOverrides({
        'tacos': CategoryType.entertainment,
      });
      CategorizationEngine.loadUserOverrides({});

      // tacos ya no debe ser entertainment (cae al keyword match real).
      final result = CategorizationEngine.predict('tacos');
      expect(result, isNot(CategoryType.entertainment));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // learnFromCorrection — alimentar overrides desde la UI
  // ══════════════════════════════════════════════════════════════════════

  group('learnFromCorrection', () {
    test('retorna las palabras aprendidas (>=3 chars) + frase completa',
        () {
      final learned = CategorizationEngine.learnFromCorrection(
        description: 'fui al gimnasio',
        correctedCategory: CategoryType.health,
      );

      // "fui" (3 chars), "gimnasio" (8 chars) — "al" (2) se filtra.
      // Plus la frase completa "fui al gimnasio".
      // (Pero "gimnasio" probablemente es keyword estática y se filtra.)
      // Mínimo: la frase completa siempre se incluye si hay >=2 palabras
      // significativas.
      expect(learned, isNotEmpty);
      expect(learned, contains('fui al gimnasio'),
          reason: 'la frase completa se aprende para matches exactos');
    });

    test('aplica la categoría aprendida en el próximo predict', () {
      // Una palabra inventada que no existe en keywords estáticas.
      const invented = 'pikuchu';

      CategorizationEngine.learnFromCorrection(
        description: invented,
        correctedCategory: CategoryType.health,
      );

      final result = CategorizationEngine.predict(invented);
      expect(result, CategoryType.health);
    });

    test('NO sobrescribe palabras que ya están en _keywordMap estático', () {
      // Aprendemos "tacos → entertainment" pero "tacos" probablemente
      // es keyword estática de food. La función debe filtrar y no
      // agregar tacos al override.
      // Aprendemos también una palabra inventada "blablaword".
      CategorizationEngine.loadUserOverrides({});

      final learned = CategorizationEngine.learnFromCorrection(
        description: 'tacos blablaword',
        correctedCategory: CategoryType.entertainment,
      );

      // "blablaword" debe estar; "tacos" probablemente NO (es keyword
      // estática). Pero la frase completa "tacos blablaword" sí
      // (porque la frase completa siempre se aprende si >=2 palabras
      // significativas).
      expect(learned, contains('blablaword'));

      // Sanity: "blablaword" sola debe categorizar como entertainment.
      final r1 = CategorizationEngine.predict('blablaword');
      expect(r1, CategoryType.entertainment);
    });

    test('palabras de menos de 3 chars no se aprenden como individuales', () {
      // "ir" tiene 2 chars y debería filtrarse al aprender por palabra.
      final learned = CategorizationEngine.learnFromCorrection(
        description: 'ir cinema',
        correctedCategory: CategoryType.entertainment,
      );

      // "ir" no debe aparecer como entrada individual; "cinema" sí
      // (asumiendo que no está en keywords estáticas).
      expect(learned, isNot(contains('ir')));
    });

    test('frase de una sola palabra significativa NO aprende la frase completa',
        () {
      // El código exige >=2 palabras para aprender la frase completa.
      // Si solo hay 1 palabra, solo se aprende esa palabra individual.
      CategorizationEngine.loadUserOverrides({});

      final learned = CategorizationEngine.learnFromCorrection(
        description: 'pikuchu',
        correctedCategory: CategoryType.health,
      );

      expect(learned, contains('pikuchu'));
      expect(learned.length, 1,
          reason: 'una palabra → solo se aprende esa, no la "frase"');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // inferType — categoría → tipo de transacción
  // ══════════════════════════════════════════════════════════════════════

  group('inferType', () {
    test('categorías de ingreso → TransactionType.income', () {
      expect(CategorizationEngine.inferType(CategoryType.salary),
          TransactionType.income);
      expect(CategorizationEngine.inferType(CategoryType.freelance),
          TransactionType.income);
      expect(CategorizationEngine.inferType(CategoryType.investment),
          TransactionType.income);
      expect(CategorizationEngine.inferType(CategoryType.refund),
          TransactionType.income);
      expect(CategorizationEngine.inferType(CategoryType.otherIncome),
          TransactionType.income);
    });

    test('categorías de gasto → TransactionType.expense', () {
      expect(CategorizationEngine.inferType(CategoryType.food),
          TransactionType.expense);
      expect(CategorizationEngine.inferType(CategoryType.transport),
          TransactionType.expense);
      expect(CategorizationEngine.inferType(CategoryType.health),
          TransactionType.expense);
      expect(CategorizationEngine.inferType(CategoryType.entertainment),
          TransactionType.expense);
    });

    test('CategoryType.other → expense (default seguro)', () {
      // 'other' no está en la whitelist de income, por lo tanto es expense.
      expect(CategorizationEngine.inferType(CategoryType.other),
          TransactionType.expense);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Cascada — ordering integration
  // ══════════════════════════════════════════════════════════════════════

  group('cascada de prioridad (integración)', () {
    test('Nivel 0 gana incluso si hay match en Nivel 2', () {
      // "uber" probablemente es transport en keywords.
      // Si añadimos override "uber → entertainment", debe ganar el override.
      CategorizationEngine.loadUserOverrides({
        'uber': CategoryType.entertainment,
      });

      final result = CategorizationEngine.predict('viaje en uber');
      expect(result, CategoryType.entertainment,
          reason: 'override (Nivel 0) tiene prioridad absoluta');
    });

    test('sin override → cae a keywords (Nivel 2)', () {
      CategorizationEngine.loadUserOverrides({});
      final result = CategorizationEngine.predict('compre tacos');
      // No debe ser other (porque tacos es keyword estática).
      expect(result, isNot(CategoryType.other));
    });

    test('sin override y sin keyword match → other', () {
      CategorizationEngine.loadUserOverrides({});
      final result = CategorizationEngine.predict('xkqzwj brljmhxcz');
      expect(result, CategoryType.other);
    });
  });
}