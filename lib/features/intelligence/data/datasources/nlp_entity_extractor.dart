import 'package:beti_app/core/enums/transaction_type.dart';
import 'package:beti_app/core/enums/category_type.dart';
import 'package:beti_app/features/intelligence/data/datasources/categorization_engine.dart';
import 'package:beti_app/core/enums/payment_method.dart';

/// Resultado estructurado de la extracción NLP.
class NlpExtractionResult {
  final double? amount;
  final String description;
  final TransactionType type;
  final CategoryType category;
  final bool categoryAutoAssigned;
  final DateTime? date;
  final PaymentMethod? paymentMethod;
  final String rawInput;

  const NlpExtractionResult({
    this.amount,
    required this.description,
    required this.type,
    required this.category,
    required this.categoryAutoAssigned,
    this.date,
    this.paymentMethod,
    required this.rawInput,
  });
}

/// Extractor centralizado de entidades financieras a partir de texto.
///
/// Procesa cualquier input (voz, OCR, manual) y extrae:
/// - Monto (numérico y en palabras español, incluyendo compuestos)
/// - Tipo de transacción (gasto/ingreso por verbo o categoría)
/// - Categoría (delegada a CategorizationEngine)
/// - Fecha (patrones mexicanos + relativos)
/// - Método de pago (efectivo, tarjeta, transferencia)
///
/// 100% on-device, cero dependencias externas, Dart puro.
class NlpEntityExtractor {
  NlpEntityExtractor._();

  /// Punto de entrada principal. Recibe texto crudo, retorna entidades.
  static NlpExtractionResult extract(String rawText) {
    final normalized = _normalize(rawText);

    final amount = _extractAmount(normalized);
    final date = _extractDate(normalized);
    final paymentMethod = _extractPaymentMethod(normalized);
    final description = _extractDescription(normalized, amount, date);
    final type = _inferType(normalized, description);
    final category = CategorizationEngine.predict(description);
    final categoryAuto = category != CategoryType.other;

    // Si la categoría sugiere ingreso, respetar eso sobre el verbo
    final finalType =
        categoryAuto ? CategorizationEngine.inferType(category) : type;

    return NlpExtractionResult(
      amount: amount,
      description: description,
      type: finalType,
      category: category,
      categoryAutoAssigned: categoryAuto,
      date: date,
      paymentMethod: paymentMethod,
      rawInput: rawText,
    );
  }

  /// Punto de entrada para OCR: recibe datos pre-extraídos del ticket
  /// y enriquece con categorización y tipo.
  static NlpExtractionResult extractFromOcr({
    required String rawText,
    double? amount,
    DateTime? date,
    String? concept,
    PaymentMethod? paymentMethod,
  }) {
    final description = concept ??
        _extractDescription(
          _normalize(rawText),
          amount,
          date,
        );
    final category = CategorizationEngine.predict(description);
    final categoryAuto = category != CategoryType.other;
    final type = categoryAuto
        ? CategorizationEngine.inferType(category)
        : TransactionType.expense;

    return NlpExtractionResult(
      amount: amount,
      description: description,
      type: type,
      category: category,
      categoryAutoAssigned: categoryAuto,
      date: date,
      paymentMethod: paymentMethod,
      rawInput: rawText,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Extracción de monto
  // ═══════════════════════════════════════════════════════════

  static double? _extractAmount(String text) {
    // Prioridad 1: monto numérico explícito ($500, 1,234.56, 500 pesos)
    final numeric = _extractNumericAmount(text);
    if (numeric != null) return numeric;

    // Prioridad 2: monto en palabras ("quinientos", "mil doscientos")
    return _extractWordAmount(text);
  }

  static double? _extractNumericAmount(String text) {
    // Buscar patrones: $1,234.56 | 500 pesos | 1234.50
    final patterns = [
      // "$500" o "$ 500" con decimales opcionales
      RegExp(r'\$\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)'),
      // "500 pesos" / "500 varos" / "500 bolas"
      RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*(?:pesos|varos|bolas|mxn)'),
      // Número suelto (>= 2 dígitos para evitar falsos positivos)
      RegExp(r'(?<!\d)(\d{2,3}(?:,\d{3})*(?:\.\d{1,2})?)(?!\d)'),
    ];

    for (final regex in patterns) {
      final match = regex.firstMatch(text);
      if (match != null) {
        final raw = match.group(1)?.replaceAll(',', '');
        if (raw != null) {
          final value = double.tryParse(raw);
          if (value != null && value > 0) return value;
        }
      }
    }
    return null;
  }

  /// Extrae montos en español hablado con soporte de composición.
  /// "mil quinientos" → 1500, "doscientos cincuenta" → 250
  static double? _extractWordAmount(String text) {
    final words = text.split(RegExp(r'\s+'));

    // Mapas de valores
    const units = {
      'un': 1,
      'uno': 1,
      'una': 1,
      'dos': 2,
      'tres': 3,
      'cuatro': 4,
      'cinco': 5,
      'seis': 6,
      'siete': 7,
      'ocho': 8,
      'nueve': 9,
    };
    const teens = {
      'diez': 10,
      'once': 11,
      'doce': 12,
      'trece': 13,
      'catorce': 14,
      'quince': 15,
      'dieciseis': 16,
      'diecisiete': 17,
      'dieciocho': 18,
      'diecinueve': 19,
    };
    const tens = {
      'veinte': 20,
      'veintiuno': 21,
      'veintidos': 22,
      'veintitres': 23,
      'veinticuatro': 24,
      'veinticinco': 25,
      'veintiseis': 26,
      'veintisiete': 27,
      'veintiocho': 28,
      'veintinueve': 29,
      'treinta': 30,
      'cuarenta': 40,
      'cincuenta': 50,
      'sesenta': 60,
      'setenta': 70,
      'ochenta': 80,
      'noventa': 90,
    };
    const hundreds = {
      'cien': 100,
      'ciento': 100,
      'doscientos': 200,
      'doscientas': 200,
      'trescientos': 300,
      'trescientas': 300,
      'cuatrocientos': 400,
      'cuatrocientas': 400,
      'quinientos': 500,
      'quinientas': 500,
      'seiscientos': 600,
      'seiscientas': 600,
      'setecientos': 700,
      'setecientas': 700,
      'ochocientos': 800,
      'ochocientas': 800,
      'novecientos': 900,
      'novecientas': 900,
    };

    // Buscar secuencia de palabras numéricas contiguas
    int? startIdx;
    int? endIdx;

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final isNumWord = units.containsKey(w) ||
          teens.containsKey(w) ||
          tens.containsKey(w) ||
          hundreds.containsKey(w) ||
          w == 'mil' ||
          w == 'y'; // "treinta y cinco"

      if (isNumWord) {
        startIdx ??= i;
        endIdx = i;
      } else if (startIdx != null) {
        // Si encontramos "pesos"/"varos" justo después, incluirlo como fin
        if (w == 'pesos' || w == 'varos' || w == 'bolas') {
          endIdx = i;
        }
        break;
      }
    }

    if (startIdx == null) return null;

    // Componer el valor numérico
    final numWords = words
        .sublist(startIdx, (endIdx ?? startIdx) + 1)
        .where((w) => w != 'y' && w != 'pesos' && w != 'varos' && w != 'bolas')
        .toList();

    if (numWords.isEmpty) return null;

    double total = 0;
    double current = 0;

    for (final w in numWords) {
      if (w == 'mil') {
        // "mil" multiplica lo acumulado o vale 1000 si es el primer token
        if (current == 0) current = 1;
        total += current * 1000;
        current = 0;
      } else {
        final val = units[w] ?? teens[w] ?? tens[w] ?? hundreds[w];
        if (val != null) {
          current += val;
        }
      }
    }

    total += current;
    return total > 0 ? total : null;
  }

  // ═══════════════════════════════════════════════════════════
  // Extracción de fecha
  // ═══════════════════════════════════════════════════════════

  static DateTime? _extractDate(String text) {
    final now = DateTime.now();

    // Relativos
    if (text.contains('hoy')) return now;
    if (text.contains('ayer')) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    if (text.contains('antier') || text.contains('antes de ayer')) {
      return DateTime(now.year, now.month, now.day - 2);
    }

    // Patrón: "15 de marzo", "3 de enero del 2026"
    final monthNames = {
      'enero': 1,
      'febrero': 2,
      'marzo': 3,
      'abril': 4,
      'mayo': 5,
      'junio': 6,
      'julio': 7,
      'agosto': 8,
      'septiembre': 9,
      'octubre': 10,
      'noviembre': 11,
      'diciembre': 12,
    };

    final namedDateRegex = RegExp(
      r'(\d{1,2})\s+de\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)(?:\s+(?:del?\s+)?(\d{4}))?',
    );
    final namedMatch = namedDateRegex.firstMatch(text);
    if (namedMatch != null) {
      final day = int.tryParse(namedMatch.group(1) ?? '');
      final month = monthNames[namedMatch.group(2)];
      final year = int.tryParse(namedMatch.group(3) ?? '') ?? now.year;
      if (day != null && month != null && day >= 1 && day <= 31) {
        try {
          return DateTime(year, month, day);
        } catch (_) {}
      }
    }

    // Patrón numérico: dd/mm/yyyy, dd-mm-yyyy, dd/mm/yy
    final numericPatterns = [
      RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})'),
      RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2})'),
    ];
    for (final regex in numericPatterns) {
      final match = regex.firstMatch(text);
      if (match != null) {
        final day = int.tryParse(match.group(1) ?? '');
        final month = int.tryParse(match.group(2) ?? '');
        var year = int.tryParse(match.group(3) ?? '');
        if (day != null && month != null && year != null) {
          if (year < 100) year += 2000;
          if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            try {
              return DateTime(year, month, day);
            } catch (_) {}
          }
        }
      }
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // Extracción de método de pago
  // ═══════════════════════════════════════════════════════════

  static PaymentMethod? _extractPaymentMethod(String text) {
    if (RegExp(r'tarjeta\s*(de\s*)?debito|tdd|con\s+debito').hasMatch(text)) {
      return PaymentMethod.debitCard;
    }

    if (RegExp(
            r'tarjeta\s*(de\s*)?credito|tdc|con\s+credito|a\s+credito|meses\s+sin\s+intereses')
        .hasMatch(text)) {
      return PaymentMethod.creditCard;
    }

    if (RegExp(r'con\s+tarjeta|tarjeta\b|pase\s+la\s+tarjeta').hasMatch(text)) {
      return PaymentMethod.creditCard;
    }

    if (RegExp(r'transferencia|spei|clabe|deposito|transferi').hasMatch(text)) {
      return PaymentMethod.transfer;
    }

    if (RegExp(
            r'efectivo|cash|billete|cambio|feria|en\s+efectivo|pague\s+con\s+billete')
        .hasMatch(text)) {
      return PaymentMethod.cash;
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // Inferencia de tipo por verbos/contexto
  // ═══════════════════════════════════════════════════════════

  static TransactionType _inferType(String text, String description) {
    // Verbos de ingreso (más específicos primero)
    if (RegExp(
            r'me pagaron|me depositaron|recibi|cobre\s+mi|me dieron|gane|me transfirieron')
        .hasMatch(text)) {
      return TransactionType.income;
    }

    // Verbos de gasto
    if (RegExp(
            r'compre|gaste|pague|me cobraron|pedi|rente|pago de|pago\s+el|pago\s+la|pago\s+los')
        .hasMatch(text)) {
      return TransactionType.expense;
    }

    final cat = CategorizationEngine.predict(description);
    if (cat != CategoryType.other) {
      return CategorizationEngine.inferType(cat);
    }

    return TransactionType.expense;
  }

  // ═══════════════════════════════════════════════════════════
  // Extracción de descripción limpia
  // ═══════════════════════════════════════════════════════════

  /// Remueve del texto las partes ya extraídas (monto, fecha, verbos)
  /// para obtener la descripción pura del concepto.
  static String _extractDescription(
    String text,
    double? amount,
    DateTime? date,
  ) {
    var desc = text;

    // Remover monto numérico y su contexto
    desc = desc.replaceAll(
      RegExp(r'\$\s*\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?\s*(?:pesos|varos|bolas|mxn)?'),
      '',
    );
    desc = desc.replaceAll(
      RegExp(r'\b\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?\s*(?:pesos|varos|bolas|mxn)\b'),
      '',
    );
    desc = desc.replaceAll(
      RegExp(r'\b\d{4,}(?:\.\d{1,2})?\b'),
      '',
    );

    // Remover palabras numéricas de monto (solo si detectamos un monto en palabras)
    if (amount != null && _extractNumericAmount(text) == null) {
      const numWords = [
        'un',
        'uno',
        'una',
        'dos',
        'tres',
        'cuatro',
        'cinco',
        'seis',
        'siete',
        'ocho',
        'nueve',
        'diez',
        'once',
        'doce',
        'trece',
        'catorce',
        'quince',
        'dieciseis',
        'diecisiete',
        'dieciocho',
        'diecinueve',
        'veinte',
        'veintiuno',
        'veintidos',
        'veintitres',
        'veinticuatro',
        'veinticinco',
        'veintiseis',
        'veintisiete',
        'veintiocho',
        'veintinueve',
        'treinta',
        'cuarenta',
        'cincuenta',
        'sesenta',
        'setenta',
        'ochenta',
        'noventa',
        'cien',
        'ciento',
        'doscientos',
        'doscientas',
        'trescientos',
        'trescientas',
        'cuatrocientos',
        'cuatrocientas',
        'quinientos',
        'quinientas',
        'seiscientos',
        'seiscientas',
        'setecientos',
        'setecientas',
        'ochocientos',
        'ochocientas',
        'novecientos',
        'novecientas',
        'mil',
        'pesos',
        'varos',
        'bolas',
      ];
      final words = desc.split(RegExp(r'\s+'));
      desc = words.where((w) => !numWords.contains(w)).join(' ');
    }

    // Remover verbos de contexto
    desc = desc.replaceAll(
      RegExp(
          r'\b(compre|gaste|pague|pedi|rente|me pagaron|me depositaron|recibi|gane|fui)\b'),
      '',
    );

    // Remover fechas relativas
    desc = desc.replaceAll(RegExp(r'\b(hoy|ayer|antier)\b'), '');

    // Remover fechas numéricas
    desc = desc.replaceAll(RegExp(r'\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}'), '');

    // Remover referencias a método de pago
    desc = desc.replaceAll(
      RegExp(
          r'\b(con\s+)?(tarjeta|efectivo|transferencia|debito|credito|spei)\b'),
      '',
    );

    // Limpiar espacios y trim antes de la pasada final
    desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Pasada final: remover preposiciones/artículos sueltos que quedaron
    // al inicio y entre palabras significativas
    // Ejemplo: "de tacos" → "tacos", "en el uber" → "uber"
    final stopWords = {
      'en',
      'de',
      'por',
      'para',
      'a',
      'al',
      'el',
      'la',
      'los',
      'las',
      'un',
      'una',
      'unos',
      'unas',
      'del',
      'con',
      'que',
      'y',
      'o',
      'mi',
      'mis',
      'su',
      'sus',
      'lo',
      'le',
      'se',
      'me',
    };
    final cleanWords = desc
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1 && !stopWords.contains(w))
        .toList();
    desc = cleanWords.join(' ');

    // Si quedó vacío, usar el texto original
    if (desc.isEmpty) desc = text.trim();

    // Capitalizar primera letra
    if (desc.isNotEmpty) {
      desc = desc[0].toUpperCase() + desc.substring(1);
    }

    return desc;
  }

  // ═══════════════════════════════════════════════════════════
  // Normalización
  // ═══════════════════════════════════════════════════════════

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^\w\s/\-\$.,]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
