import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Resultado estructurado del OCR sobre un ticket.
class OcrTicketResult {
  final String rawText;
  final double? amount;
  final DateTime? date;
  final String? concept;
  final String? paymentMethod;

  const OcrTicketResult({
    required this.rawText,
    this.amount,
    this.date,
    this.concept,
    this.paymentMethod,
  });
}

/// DataSource local para OCR de tickets mexicanos.
/// Usa Google ML Kit Text Recognition 100% on-device.
///
/// Estrategia de extracción optimizada para tickets MX:
///   1. TOTAL tiene máxima prioridad (ignorando SUBTOTAL).
///   2. Fechas en formato dd/mm/yyyy (estándar MX).
///   3. Concepto = nombre del establecimiento (primeras líneas).
///   4. Método de pago detectado (efectivo, tarjeta, etc.).
class OcrLocalDataSource {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Procesa una imagen y extrae texto + datos estructurados.
  Future<OcrTicketResult> processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _recognizer.processImage(inputImage);
    final rawText = recognized.text;

    debugPrint('[OCR] Raw text:\n$rawText');

    final lines = rawText.split('\n');

    final amount = _extractAmount(lines);
    final date = _extractDate(rawText);
    final concept = _extractConcept(recognized.blocks);
    final paymentMethod = _extractPaymentMethod(lines);

    debugPrint(
        '[OCR] Amount: $amount | Date: $date | Concept: $concept | Payment: $paymentMethod');

    return OcrTicketResult(
      rawText: rawText,
      amount: amount,
      date: date,
      concept: concept,
      paymentMethod: paymentMethod,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Extracción de monto — prioridad mexicana
  // ═══════════════════════════════════════════════════════════

  /// Extrae el monto TOTAL del ticket.
  ///
  /// Prioridad estricta:
  ///   1. Línea que diga exactamente "TOTAL" (no SUBTOTAL).
  ///   2. Línea con "IMPORTE TOTAL" o "TOTAL A PAGAR".
  ///   3. Línea con "COBRO" o "VENTA".
  ///   4. Fallback: monto de la línea "ENTREGADO" (lo que pagó el cliente).
  ///
  /// NUNCA toma SUBTOTAL, IVA, CAMBIO, PROPINA ni montos de artículos.
  double? _extractAmount(List<String> lines) {
    // Paso 1: Buscar "TOTAL" exacto (no SUBTOTAL)
    for (final line in lines.reversed) {
      final upper = line.toUpperCase().trim();

      // Saltar líneas que son SUBTOTAL, IVA, CAMBIO, PROPINA, DESCUENTO
      if (_isExcludedLine(upper)) continue;

      // Buscar "TOTAL" como palabra completa (no parte de SUBTOTAL)
      // El regex requiere que TOTAL esté al inicio o precedido por espacio/símbolo
      if (RegExp(r'(?:^|\s)TOTAL(?:\s|$|:|\.)').hasMatch(upper) ||
          upper == 'TOTAL') {
        final amount = _parseAmountFromLine(line);
        if (amount != null && amount > 0) {
          debugPrint('[OCR] Match TOTAL: $amount from "$line"');
          return amount;
        }
      }
    }

    // Paso 2: Buscar "IMPORTE TOTAL", "TOTAL A PAGAR"
    for (final line in lines.reversed) {
      final upper = line.toUpperCase().trim();
      if (_isExcludedLine(upper)) continue;

      if (upper.contains('TOTAL A PAGAR') ||
          upper.contains('IMPORTE TOTAL') ||
          upper.contains('MONTO TOTAL')) {
        final amount = _parseAmountFromLine(line);
        if (amount != null && amount > 0) {
          debugPrint('[OCR] Match TOTAL A PAGAR: $amount from "$line"');
          return amount;
        }
      }
    }

    // Paso 3: Buscar "COBRO", "VENTA"
    for (final line in lines.reversed) {
      final upper = line.toUpperCase().trim();
      if (_isExcludedLine(upper)) continue;

      if (upper.contains('COBRO') || upper.contains('VENTA TOTAL')) {
        final amount = _parseAmountFromLine(line);
        if (amount != null && amount > 0) {
          debugPrint('[OCR] Match COBRO/VENTA: $amount from "$line"');
          return amount;
        }
      }
    }

    // Paso 4: Fallback — "ENTREGADO" (lo que pagó el cliente)
    for (final line in lines) {
      final upper = line.toUpperCase().trim();
      if (upper.contains('ENTREGADO') || upper.contains('PAGO CON')) {
        final amount = _parseAmountFromLine(line);
        if (amount != null && amount > 0) {
          debugPrint('[OCR] Match ENTREGADO: $amount from "$line"');
          return amount;
        }
      }
    }

    debugPrint('[OCR] No total found');
    return null;
  }

  /// Líneas que NUNCA deben tomarse como monto total.
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
        // Headers de tabla (no contienen montos reales)
        (upper.contains('UDS') && upper.contains('DESCRIPCION')) ||
        (upper.contains('CANT') && upper.contains('DESCRIPCION')) ||
        (upper.contains('PVP') && upper.contains('IMPORTE'));
  }

  /// Parsea un monto numérico de una línea de texto.
  /// Soporta: $1,234.56 | $1234.56 | 1,234.56 | 1234.56
  double? _parseAmountFromLine(String line) {
    // Buscar todos los números con formato de moneda en la línea
    final regex = RegExp(r'\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)');
    final matches = regex.allMatches(line).toList();

    if (matches.isEmpty) return null;

    // Si hay múltiples montos en la línea, tomar el ÚLTIMO
    // (en tickets MX el total suele estar al final de la línea)
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

  /// Extrae la fecha del ticket.
  /// Formatos soportados:
  ///   - dd/mm/yyyy, dd-mm-yyyy, dd.mm.yyyy
  ///   - dd/mm/yy
  ///   - "FECHA dd/mm/yyyy" o "FECHA: dd/mm/yyyy"
  ///   - yyyy-mm-dd (formato ISO, usado por algunos POS)
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

    // Formato MX estándar: dd/mm/yyyy o dd-mm-yyyy o dd.mm.yyyy
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

  /// Extrae el nombre del establecimiento.
  /// En tickets MX, el nombre suele estar en las primeras 1-3 líneas,
  /// antes de la dirección (que contiene "COL.", "AVE.", "#", "C.P.").
  String? _extractConcept(List<TextBlock> blocks) {
    if (blocks.isEmpty) return null;

    // Patrones que indican que la línea NO es el nombre del negocio
    final skipPatterns = RegExp(
      r'(RFC[:\s]|FOLIO|SERIE|TICKET|FACTURA|^[\d\s\$.,\-/]+$|'
      r'AVE\.|CALLE|COL\.|C\.P\.|CP\s|BLVD|#\s*\d|TEL[:\s.]|'
      r'SUC\.|SUCURSAL|FECHA|HORA|\d{2}[/\-]\d{2}[/\-]\d{2,4})',
      caseSensitive: false,
    );

    for (final block in blocks.take(5)) {
      for (final line in block.lines) {
        final text = line.text.trim();

        // Debe tener al menos 3 caracteres significativos
        if (text.length < 3) continue;

        // Saltar líneas que son direcciones, RFC, fechas, etc.
        if (skipPatterns.hasMatch(text)) continue;

        // El nombre del negocio suele tener letras
        if (RegExp(r'[a-zA-ZáéíóúñÁÉÍÓÚÑ]').hasMatch(text)) {
          debugPrint('[OCR] Concept: "$text"');
          return text;
        }
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // Extracción de método de pago
  // ═══════════════════════════════════════════════════════════

  /// Detecta el método de pago del ticket.
  /// Retorna: "efectivo", "tarjeta_debito", "tarjeta_credito", "transferencia", o null.
  String? _extractPaymentMethod(List<String> lines) {
    for (final line in lines) {
      final upper = line.toUpperCase();

      if (upper.contains('TARJETA DEBITO') ||
          upper.contains('TARJETA DE DEBITO') ||
          upper.contains('T. DEBITO') ||
          upper.contains('DÉBITO')) {
        return 'tarjeta_debito';
      }

      if (upper.contains('TARJETA CREDITO') ||
          upper.contains('TARJETA DE CREDITO') ||
          upper.contains('T. CREDITO') ||
          upper.contains('CRÉDITO')) {
        return 'tarjeta_credito';
      }

      if (upper.contains('TARJETA') &&
          !upper.contains('DEBITO') &&
          !upper.contains('CREDITO')) {
        return 'tarjeta';
      }

      if (upper.contains('EFECTIVO') || upper.contains('CASH')) {
        return 'efectivo';
      }

      if (upper.contains('TRANSFERENCIA') || upper.contains('SPEI')) {
        return 'transferencia';
      }
    }
    return null;
  }

  void dispose() {
    _recognizer.close();
  }
}
