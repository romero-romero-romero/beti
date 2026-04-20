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

    // Paso 2.5: "IMPORTE" solo — monto puede estar en la línea siguiente
    for (int i = 0; i < lines.length; i++) {
      final upper = lines[i].toUpperCase().trim();
      if (_isExcludedLine(upper)) continue;
      if (RegExp(r'^[TI1]MPORTE$|^TOTA[L1]$|^[TI]OTAL$').hasMatch(upper)) {
        final sameLine = _parseAmountFromLine(lines[i]);
        if (sameLine != null && sameLine > 0) return sameLine;
        if (i + 1 < lines.length) {
          final nextLine = _parseAmountFromLine(lines[i + 1]);
          if (nextLine != null && nextLine > 0) return nextLine;
        }
      }
    }

    // Paso 3: "COBRO", "VENTA"
    for (final line in lines.reversed) {
      final upper = line.toUpperCase().trim();
      if (_isExcludedLine(upper)) continue;
      if (upper.contains('COBRO') || upper.contains('VENTA TOTAL')) {
        final amount = _parseAmountFromLine(line);
        if (amount != null && amount > 0) return amount;
      }
    }

    // Paso 4: "ENTREGADO" (lo que pagó el cliente)
    for (final line in lines) {
      final upper = line.toUpperCase().trim();
      if (upper.contains('ENTREGADO') || upper.contains('PAGO CON')) {
        final amount = _parseAmountFromLine(line);
        if (amount != null && amount > 0) return amount;
      }
    }

    // Paso 5: "$ XX.XX MXN" en cualquier línea
    for (final line in lines) {
      final upper = line.toUpperCase().trim();
      if (_isExcludedLine(upper)) continue;
      final mxnMatch = RegExp(r'\$\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*MXN')
          .firstMatch(line);
      if (mxnMatch != null) {
        final raw = mxnMatch.group(1)?.replaceAll(',', '');
        if (raw != null) {
          final value = double.tryParse(raw);
          if (value != null && value > 0) return value;
        }
      }
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
    final matches =
        RegExp(r'\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)').allMatches(line).toList();
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
  // ═══════════════════════════════════════════════════════════

  DateTime? _extractDate(String text) {
    // Formato ISO: yyyy-mm-dd (algunos POS modernos)
    final isoMatch =
        RegExp(r'(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})').firstMatch(text);
    if (isoMatch != null) {
      final year = int.tryParse(isoMatch.group(1) ?? '');
      final month = int.tryParse(isoMatch.group(2) ?? '');
      final day = int.tryParse(isoMatch.group(3) ?? '');
      if (year != null &&
          month != null &&
          day != null &&
          year >= 2020 &&
          year <= 2030 &&
          month >= 1 &&
          month <= 12 &&
          day >= 1 &&
          day <= 31) {
        try {
          return DateTime(year, month, day);
        } catch (_) {}
      }
    }

    final patterns = [
      RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})'),
      RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2})'),
    ];

    for (final regex in patterns) {
      final match = regex.firstMatch(text);
      if (match != null) {
        final day = int.tryParse(match.group(1) ?? '');
        final month = int.tryParse(match.group(2) ?? '');
        var year = int.tryParse(match.group(3) ?? '');
        if (day != null && month != null && year != null) {
          if (year < 100) year += 2000;
          if (year >= 2020 &&
              year <= 2030 &&
              month >= 1 &&
              month <= 12 &&
              day >= 1 &&
              day <= 31) {
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
