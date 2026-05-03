import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:beti_app/core/enums/payment_method.dart';

class OcrTicketResult {
  final String rawText;
  final double? amount;
  final DateTime? date;
  final String? concept;
  final PaymentMethod? paymentMethod;
  final String? cardLastFour;

  const OcrTicketResult({
    required this.rawText,
    this.amount,
    this.date,
    this.concept,
    this.paymentMethod,
    this.cardLastFour,
  });
}

/// DataSource local para OCR de tickets mexicanos.
/// Usa Google ML Kit Text Recognition 100% on-device.
class OcrLocalDataSource {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<OcrTicketResult> processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _recognizer.processImage(inputImage);
    final rawText = recognized.text;
    final lines = rawText.split('\n');

    return OcrTicketResult(
      rawText: rawText,
      amount: _extractAmount(lines),
      date: _extractDate(rawText),
      concept: _extractConcept(recognized.blocks),
      paymentMethod: _extractPaymentMethod(lines),
      cardLastFour: _extractCardLastFour(lines),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Extracción de monto — prioridad mexicana
  // ═══════════════════════════════════════════════════════════

  double? _extractAmount(List<String> lines) {
    // Paso 1: "TOTAL" exacto (no SUBTOTAL)
    for (final line in lines.reversed) {
      final upper = line.toUpperCase().trim();
      if (_isExcludedLine(upper)) continue;
      if (RegExp(r'(?:^|\s)TOTA[L1](?:\s|$|:|\.)').hasMatch(upper) ||
          RegExp(r'^TOTA[L1]$').hasMatch(upper)) {
        final amount = _parseAmountFromLine(line);
        if (amount != null && amount > 0) return amount;
      }
    }

    // Paso 2: "IMPORTE TOTAL", "TOTAL A PAGAR"
    for (final line in lines.reversed) {
      final upper = line.toUpperCase().trim();
      if (_isExcludedLine(upper)) continue;
      if (upper.contains('TOTAL A PAGAR') ||
          RegExp(r'[TI1]MPORTE\s+TOTA[L1]').hasMatch(upper) ||
          upper.contains('MONTO TOTAL')) {
        final amount = _parseAmountFromLine(line);
        if (amount != null && amount > 0) return amount;
      }
    }

    // Paso 2.5: "IMPORTE" o "TOTAL" solos — monto puede estar en línea siguiente
    // FIX 1: Terminales bancarias (BBVA/Getnet/BanBajío/BANSi/Afirme)
    // emiten "IMPORTE" como etiqueta sola y el monto en la siguiente línea
    // o en la misma línea pero con basura OCR entre medio.
    for (int i = 0; i < lines.length; i++) {
      final upper = lines[i].toUpperCase().trim();
      if (_isExcludedLine(upper)) continue;
      if (RegExp(r'^[TI1]MPORTE$|^TOTA[L1]$|^[TI]OTAL$').hasMatch(upper)) {
        final sameLine = _parseAmountFromLine(lines[i]);
        if (sameLine != null && sameLine > 0) return sameLine;
        // Buscar en hasta 3 líneas siguientes (terminales bancarias
        // pueden tener líneas de ruido entre la etiqueta y el número)
        for (int j = i + 1; j <= i + 3 && j < lines.length; j++) {
          final nextLine = _parseAmountFromLine(lines[j]);
          if (nextLine != null && nextLine > 0) return nextLine;
        }
      }
    }

    // Paso 3: "COBRO", "VENTA TOTAL"
    for (final line in lines.reversed) {
      final upper = line.toUpperCase().trim();
      if (_isExcludedLine(upper)) continue;
      if (upper.contains('COBRO') || upper.contains('VENTA TOTAL')) {
        final amount = _parseAmountFromLine(line);
        if (amount != null && amount > 0) return amount;
      }
    }

    // Paso 4: "ENTREGADO" / "PAGO CON" (lo que pagó el cliente)
    for (final line in lines) {
      final upper = line.toUpperCase().trim();
      if (upper.contains('ENTREGADO') || upper.contains('PAGO CON')) {
        final amount = _parseAmountFromLine(line);
        if (amount != null && amount > 0) return amount;
      }
    }

    // Paso 5: "$ XX.XX MXN" / "$ XX.XX M.N." en cualquier línea
    for (final line in lines) {
      final upper = line.toUpperCase().trim();
      if (_isExcludedLine(upper)) continue;
      final mxnMatch =
          RegExp(r'\$\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*(?:MXN|M\.N\.)')
              .firstMatch(line);
      if (mxnMatch != null) {
        final raw = mxnMatch.group(1)?.replaceAll(',', '');
        if (raw != null) {
          final value = double.tryParse(raw);
          if (value != null && value > 0) return value;
        }
      }
    }

    // ── FIX 2: Terminales bancarias con monto fragmentado ──────────────────
    // Patrón: "IMPORTE $ 78 J0 MN", "IIPORTE: $ 125 00", "$ 56 00 XN"
    // El OCR separa el signo $, los dígitos y el símbolo MN/MXN con espacios
    // o inserta basura. Reconstruimos el monto uniendo tokens numéricos
    // adyacentes al símbolo $ en la misma línea.
    for (final line in lines) {
      final upper = line.toUpperCase().trim();
      if (_isExcludedLine(upper)) continue;
      // Solo aplicar en líneas que claramente son de monto de terminal
      if (!upper.contains('IMPORTE') &&
          !upper.contains('IIPORTE') &&
          !upper.contains('IIMPORTE') &&
          !RegExp(r'\$').hasMatch(line)) { continue; }

      final amount = _parseFragmentedAmount(line);
      if (amount != null && amount > 0) return amount;
    }

    // ── FIX 3: Mercado Pago ────────────────────────────────────────────────
    // Patrón: "$ 740.00 ('x$740 00)" o "$ 385.00 (1x $ 335. 00)"
    // El monto real es el primer número tras el $ antes del paréntesis.
    for (final line in lines) {
      if (!line.toUpperCase().contains('MERCADO') &&
          !line.contains('(1x') &&
          !line.contains("('x")) { continue; }
      final mp = RegExp(r'\$\s*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?)(?:\s*\()')
          .firstMatch(line);
      if (mp != null) {
        final raw = mp.group(1)?.replaceAll(',', '').replaceAll(' ', '');
        if (raw != null) {
          final value = double.tryParse(raw);
          if (value != null && value > 0) return value;
        }
      }
      // Fallback: primer $ con número en la línea de Mercado Pago
      final mpFallback =
          RegExp(r'\$\s*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?)').firstMatch(line);
      if (mpFallback != null) {
        final raw = mpFallback.group(1)?.replaceAll(',', '');
        if (raw != null) {
          final value = double.tryParse(raw);
          if (value != null && value > 0) return value;
        }
      }
    }

    return null;
  }

  // ── FIX 2 helper: reconstruye monto fragmentado por OCR ──────────────────
  // Ejemplo: "IMPORTE $ 78 J0 MN" → busca el $ y toma el primer grupo
  // de dígitos (con posible separador decimal roto) ignorando basura.
  double? _parseFragmentedAmount(String line) {
    // Normalizar: reemplazar letras O/o entre dígitos que parecen 0
    final normalized = line
        .replaceAll(RegExp(r'(?<=\d)[oO](?=\d)'), '0')
        .replaceAll(RegExp(r'(?<=\d)[lI](?=\d)'), '1');

    // Buscar secuencia: $ seguido de número(s) con posible espacio decimal
    // "$ 78 00" → 78.00 / "$ 125 00" → 125.00 / "$ 4530" → 4530
    final match = RegExp(
            r'\$\s*(\d{1,3}(?:[,\s]\d{3})*)\s+(\d{2})\b(?!\d)')
        .firstMatch(normalized);
    if (match != null) {
      final intPart = match.group(1)!.replaceAll(RegExp(r'[,\s]'), '');
      final decPart = match.group(2)!;
      final value = double.tryParse('$intPart.$decPart');
      if (value != null && value > 0) return value;
    }

    // Patrón simple: $ seguido de número entero (sin decimales fragmentados)
    final simple = RegExp(r'\$\s*(\d{2,6})(?!\d)').firstMatch(normalized);
    if (simple != null) {
      final value = double.tryParse(simple.group(1)!);
      if (value != null && value > 0) return value;
    }

    return null;
  }

  bool _isExcludedLine(String upper) {
    return upper.contains('SUBTOTAL') ||
        upper.contains('SUB TOTAL') ||
        upper.contains('SUB-TOTAL') ||
        upper.contains('IVA') ||
        upper.contains('I.V.A') ||
        upper.contains('IMPUESTO') ||
        upper.contains('CAMBIO') ||
        upper.contains('PROPINA') ||
        upper.contains('DESCUENTO') ||
        upper.contains('DESC.') ||
        upper.contains('AHORRO') ||
        upper.contains('PUNTOS') ||
        upper.contains('CASHBACK') ||
        upper.contains('BONIFICACION') ||
        upper.contains('COMISION') ||
        (upper.contains('UDS') && upper.contains('DESCRIPCION')) ||
        (upper.contains('CANT') && upper.contains('DESCRIPCION')) ||
        (upper.contains('PVP') && upper.contains('IMPORTE'));
  }

  // Toma el último monto de la línea (en tickets MX el total va al final)
  double? _parseAmountFromLine(String line) {
    // Normalizar OCR: O→0 e I/l→1 entre dígitos
    final normalized = line
        .replaceAll(RegExp(r'(?<=\d)[oO](?=\d)'), '0')
        .replaceAll(RegExp(r'(?<=\d)[lI](?=\d)'), '1');

    final matches = RegExp(r'\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)')
        .allMatches(normalized)
        .toList();
    if (matches.isEmpty) return null;
    for (final match in matches.reversed) {
      final raw = match.group(1)?.replaceAll(',', '');
      if (raw != null) {
        final value = double.tryParse(raw);
        if (value != null && value > 0) return value;
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // Extracción de fecha — formatos mexicanos
  // FIX 4: Soporte para fechas verbales usadas por terminales
  // bancarias y algunos POS: "ABR 27; 26", "19ABR 26",
  // "19FEB26", "25 Jan'26", "9 Apr'26", "23 ABRIL 2026",
  // "20 MARZO 2026"
  // ═══════════════════════════════════════════════════════════

  // Mapa de abreviaciones de mes (ES e EN) → número
  static const _monthMap = {
    // Español completo
    'ENERO': 1, 'FEBRERO': 2, 'MARZO': 3, 'ABRIL': 4,
    'MAYO': 5, 'JUNIO': 6, 'JULIO': 7, 'AGOSTO': 8,
    'SEPTIEMBRE': 9, 'OCTUBRE': 10, 'NOVIEMBRE': 11, 'DICIEMBRE': 12,
    // Español abreviado
    'ENE': 1, 'FEB': 2, 'MAR': 3, 'ABR': 4,
    'MAY': 5, 'JUN': 6, 'JUL': 7, 'AGO': 8,
    'SEP': 9, 'OCT': 10, 'NOV': 11, 'DIC': 12,
    // Inglés abreviado (algunos POS como Starbucks/Helados)
    'JAN': 1, 'APR': 4, 'AUG': 8, 'DEC': 12,
  };

  DateTime? _extractDate(String text) {
    final upper = text.toUpperCase();

    // ── Formato ISO: yyyy-mm-dd ──────────────────────────────
    final isoMatch =
        RegExp(r'(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})').firstMatch(text);
    if (isoMatch != null) {
      final y = int.tryParse(isoMatch.group(1) ?? '');
      final m = int.tryParse(isoMatch.group(2) ?? '');
      final d = int.tryParse(isoMatch.group(3) ?? '');
      if (_isValidDate(y, m, d)) {
        try { return DateTime(y!, m!, d!); } catch (_) {}
      }
    }

    // ── Formatos numéricos dd/mm/yyyy y dd/mm/yy ────────────
    final numPatterns = [
      RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})'),
      RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2})'),
    ];
    for (final regex in numPatterns) {
      final match = regex.firstMatch(text);
      if (match != null) {
        final d = int.tryParse(match.group(1) ?? '');
        final m = int.tryParse(match.group(2) ?? '');
        var y = int.tryParse(match.group(3) ?? '');
        if (y != null && y < 100) y += 2000;
        if (_isValidDate(y, m, d)) {
          try { return DateTime(y!, m!, d!); } catch (_) {}
        }
      }
    }

    // ── FIX 4A: "dd/mm/yy-HH.mm" (Mercado Pago) ────────────
    // Patrón: "04/04/26- 12.59" o "30/03/26- 13 38"
    final mpDate =
        RegExp(r'(\d{2})/(\d{2})/(\d{2})[–\-]').firstMatch(text);
    if (mpDate != null) {
      final d = int.tryParse(mpDate.group(1) ?? '');
      final m = int.tryParse(mpDate.group(2) ?? '');
      var y = int.tryParse(mpDate.group(3) ?? '');
      if (y != null && y < 100) y += 2000;
      if (_isValidDate(y, m, d)) {
        try { return DateTime(y!, m!, d!); } catch (_) {}
      }
    }

    // ── FIX 4B: "ddMES yy" / "ddMESyy" (BBVA terminal) ─────
    // Patrón: "19ABR 26", "19FEB26", "18MAR26", "24ABR26"
    final bbvaDate =
        RegExp(r"(\d{1,2})\s*(ENE|FEB|MAR|ABR|MAY|JUN|JUL|AGO|SEP|OCT|NOV|DIC)\s*['\x60]?(\d{2,4})",
            caseSensitive: false)
            .firstMatch(upper);
    if (bbvaDate != null) {
      final d = int.tryParse(bbvaDate.group(1) ?? '');
      final m = _monthMap[bbvaDate.group(2)?.toUpperCase()];
      var y = int.tryParse(bbvaDate.group(3) ?? '');
      if (y != null && y < 100) y += 2000;
      if (_isValidDate(y, m, d)) {
        try { return DateTime(y!, m!, d!); } catch (_) {}
      }
    }

    // ── FIX 4C: "MES dd; yy" / "MES dd, yy" (BBVA terminal) ─
    // Patrón: "ABR 27; 26" → dia=27, mes=4, año=2026
    final bbvaDate2 =
        RegExp(r'(ENE|FEB|MAR|ABR|MAY|JUN|JUL|AGO|SEP|OCT|NOV|DIC)'
                r'\s+(\d{1,2})[;,\s]+(\d{2,4})',
            caseSensitive: false)
            .firstMatch(upper);
    if (bbvaDate2 != null) {
      final m = _monthMap[bbvaDate2.group(1)?.toUpperCase()];
      final d = int.tryParse(bbvaDate2.group(2) ?? '');
      var y = int.tryParse(bbvaDate2.group(3) ?? '');
      if (y != null && y < 100) y += 2000;
      if (_isValidDate(y, m, d)) {
        try { return DateTime(y!, m!, d!); } catch (_) {}
      }
    }

    // ── FIX 4D: "dd Mon'yy" / "dd Apr'26" (POS inglés) ──────
    // Patrón: "25 Jan'26", "9 Apr'26"
    final engDate =
        RegExp(r"(\d{1,2})\s+(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)"
                r"\s*['\`]?\s*(\d{2,4})",
            caseSensitive: false)
            .firstMatch(upper);
    if (engDate != null) {
      final d = int.tryParse(engDate.group(1) ?? '');
      final m = _monthMap[engDate.group(2)?.toUpperCase()];
      var y = int.tryParse(engDate.group(3) ?? '');
      if (y != null && y < 100) y += 2000;
      if (_isValidDate(y, m, d)) {
        try { return DateTime(y!, m!, d!); } catch (_) {}
      }
    }

    // ── FIX 4E: "dd MESESPAÑOL yyyy" ────────────────────────
    // Patrón: "23 ABRIL 2026", "20 MARZO 2026"
    final esFullDate = RegExp(
            r'(\d{1,2})\s+(ENERO|FEBRERO|MARZO|ABRIL|MAYO|JUNIO|JULIO|AGOSTO'
            r'|SEPTIEMBRE|OCTUBRE|NOVIEMBRE|DICIEMBRE)\s+(\d{4})',
            caseSensitive: false)
        .firstMatch(upper);
    if (esFullDate != null) {
      final d = int.tryParse(esFullDate.group(1) ?? '');
      final m = _monthMap[esFullDate.group(2)?.toUpperCase()];
      final y = int.tryParse(esFullDate.group(3) ?? '');
      if (_isValidDate(y, m, d)) {
        try { return DateTime(y!, m!, d!); } catch (_) {}
      }
    }

    // ── FIX 4F: "FECHA ddMESyy" en terminales BBVA ──────────
    // Patrón: "FECHA 19ABR 26" (la palabra FECHA precede)
    final fechaPrefix = RegExp(
            r'FECHA\s+(\d{1,2})\s*'
            r'(ENE|FEB|MAR|ABR|MAY|JUN|JUL|AGO|SEP|OCT|NOV|DIC)'
            r'\s*(\d{2,4})',
            caseSensitive: false)
        .firstMatch(upper);
    if (fechaPrefix != null) {
      final d = int.tryParse(fechaPrefix.group(1) ?? '');
      final m = _monthMap[fechaPrefix.group(2)?.toUpperCase()];
      var y = int.tryParse(fechaPrefix.group(3) ?? '');
      if (y != null && y < 100) y += 2000;
      if (_isValidDate(y, m, d)) {
        try { return DateTime(y!, m!, d!); } catch (_) {}
      }
    }

    return null;
  }

  /// Valida que año/mes/día sean valores coherentes para un ticket mexicano.
  bool _isValidDate(int? y, int? m, int? d) {
    if (y == null || m == null || d == null) return false;
    return y >= 2020 && y <= 2030 && m >= 1 && m <= 12 && d >= 1 && d <= 31;
  }

  // ═══════════════════════════════════════════════════════════
  // Extracción de concepto (nombre del establecimiento)
  // ═══════════════════════════════════════════════════════════

  String? _extractConcept(List<TextBlock> blocks) {
    if (blocks.isEmpty) return null;

    final skipPatterns = RegExp(
      r'(RFC[:\s]|FOLIO|SERIE|TICKET|FACTURA|^[\d\s\$.,\-/]+$|'
      r'AVE\.|CALLE|COL\.|C\.P\.|CP\s|BLVD|#\s*\d|TEL[:\s.]|'
      r'SUC\.|SUCURSAL|FECHA|HORA|\d{2}[/\-]\d{2}[/\-]\d{2,4}|'
      r'REGIMEN\s+FISCAL|USO\s+DE\s+CFDI|METODO\s+DE\s+PAGO|'
      r'FORMA\s+DE\s+PAGO|CLAVE\s+SAT|NO\.\s+DE\s+CUENTA|'
      r'APROBAD[AO]|DECLINAD[AO]|RECHAZAD[AO]|CANCELAD[AO]|'
      r'VENTA|COMPRA|[TI1]MPORTE|CLIENTE|CONTACTLESS|NFC|'
      r'PAYWAVE|GETNET|TERMINAL|OPERACION|OPER\.|'
      r'NO\.?\s*TARJETA|TARJETA[:\s]|AUT[\.\s:]|ARQC|AID[\s:]|'
      r'REF[\.\s:]|ME\s+OBLIGO)',
      caseSensitive: false,
    );

    final genericPatterns = RegExp(
      r'(UNIVERSIDAD|GOBIERNO|SECRETARIA|INSTITUTO|S\.A\.\s*DE\s*C\.V|'
      r'GETNET|BBVA|BANORTE|BANAMEX|SANTANDER|HSBC|SCOTIABANK)',
      caseSensitive: false,
    );

    final letterPattern = RegExp(r'[a-zA-ZáéíóúñÁÉÍÓÚÑ]');

    for (final block in blocks.take(5)) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.length < 3) continue;
        if (skipPatterns.hasMatch(text)) continue;
        if (genericPatterns.hasMatch(text)) continue;
        if (letterPattern.hasMatch(text)) return _cleanConcept(text);
      }
    }

    for (final block in blocks.take(5)) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.length < 3) continue;
        if (skipPatterns.hasMatch(text)) continue;
        if (letterPattern.hasMatch(text)) return _cleanConcept(text);
      }
    }
    return null;
  }

  String _cleanConcept(String text) {
    var clean = text
        .replaceAll(RegExp(r'^\d+\s*'), '')
        .replaceAll(RegExp(r'\(\d+\)\s*'), '')
        .replaceAll(RegExp(r'\bLIB\b\s*'), '')
        .replaceAll(RegExp(r'\bSUC\b\.?\s*\d*'), '')
        .trim();
    if (clean.isEmpty) clean = text.trim();
    return clean;
  }

  // ═══════════════════════════════════════════════════════════
  // Extracción de método de pago
  // ═══════════════════════════════════════════════════════════

  PaymentMethod? _extractPaymentMethod(List<String> lines) {
    for (final line in lines) {
      final upper = line.toUpperCase();

      if (upper.contains('TARJETA DEBITO') ||
          upper.contains('TARJETA DE DEBITO') ||
          upper.contains('T. DEBITO') ||
          upper.contains('DÉBITO') ||
          upper.contains('DEBIT')) {
        return PaymentMethod.debitCard;
      }

      if (upper.contains('TARJETA CREDITO') ||
          upper.contains('TARJETA DE CREDITO') ||
          upper.contains('T. CREDITO') ||
          upper.contains('CRÉDITO') ||
          upper.contains('CREDIT')) {
        return PaymentMethod.creditCard;
      }

      if (RegExp(r'CREDITO\s*/').hasMatch(upper)) return PaymentMethod.creditCard;
      if (RegExp(r'DEBITO\s*/').hasMatch(upper)) return PaymentMethod.debitCard;

      if (RegExp(r'VISA|MASTERCARD|AMEX|AMERICAN EXPRESS|CARNET').hasMatch(upper)) {
        return PaymentMethod.creditCard;
      }

      if (upper.contains('TARJETA') &&
          !upper.contains('DEBITO') &&
          !upper.contains('CREDITO')) {
        return PaymentMethod.creditCard;
      }

      if (upper.contains('EFECTIVO') || upper.contains('CASH')) {
        return PaymentMethod.cash;
      }

      if (upper.contains('TRANSFERENCIA') || upper.contains('SPEI')) {
        return PaymentMethod.transfer;
      }
    }

    for (final line in lines) {
      if (RegExp(r'[\*xX]{2,4}\s*\d{4}').hasMatch(line)) {
        return PaymentMethod.creditCard;
      }
    }

    return null;
  }

  String? _extractCardLastFour(List<String> lines) {
    for (final line in lines) {
      final match = RegExp(r'[\*xX]{1,16}\s*(\d{4})').firstMatch(line);
      if (match != null) return match.group(1);
    }
    return null;
  }

  void dispose() {
    _recognizer.close();
  }
}