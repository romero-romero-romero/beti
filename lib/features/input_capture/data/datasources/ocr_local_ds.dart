import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Resultado estructurado del OCR sobre un ticket.
class OcrTicketResult {
  final String rawText;
  final double? amount;
  final DateTime? date;
  final String? concept;

  const OcrTicketResult({
    required this.rawText,
    this.amount,
    this.date,
    this.concept,
  });
}

/// DataSource local para OCR de tickets.
/// Usa Google ML Kit Text Recognition que corre 100% en el dispositivo.
class OcrLocalDataSource {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Procesa una imagen y extrae texto + datos estructurados.
  Future<OcrTicketResult> processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _recognizer.processImage(inputImage);
    final rawText = recognized.text;

    // Extraer datos del texto crudo del ticket
    final amount = _extractAmount(rawText);
    final date = _extractDate(rawText);
    final concept = _extractConcept(recognized.blocks);

    return OcrTicketResult(
      rawText: rawText,
      amount: amount,
      date: date,
      concept: concept,
    );
  }

  /// Extrae el monto más probable del ticket.
  /// Busca patrones como: $123.45, TOTAL: 123.45, etc.
  double? _extractAmount(String text) {
    final lines = text.split('\n');

    // Prioridad 1: buscar líneas con TOTAL
    for (final line in lines.reversed) {
      final lower = line.toLowerCase();
      if (lower.contains('total') ||
          lower.contains('importe') ||
          lower.contains('cobro')) {
        final amount = _parseAmountFromLine(line);
        if (amount != null && amount > 0) return amount;
      }
    }

    // Prioridad 2: buscar el monto más grande (probablemente el total)
    double? largest;
    for (final line in lines) {
      final amount = _parseAmountFromLine(line);
      if (amount != null && amount > 0) {
        if (largest == null || amount > largest) {
          largest = amount;
        }
      }
    }

    return largest;
  }

  /// Parsea un monto de una línea de texto.
  double? _parseAmountFromLine(String line) {
    // Patrones: $1,234.56 | $1234.56 | 1,234.56 | 1234.56
    final regex = RegExp(r'\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)');
    final matches = regex.allMatches(line);

    for (final match in matches) {
      final raw = match.group(1)?.replaceAll(',', '');
      if (raw != null) {
        final value = double.tryParse(raw);
        if (value != null && value > 0) return value;
      }
    }
    return null;
  }

  /// Extrae la fecha del ticket.
  DateTime? _extractDate(String text) {
    // Patrón: dd/mm/yyyy, dd-mm-yyyy, dd/mm/yy
    final patterns = [
      RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})'),
      RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2})'),
    ];

    for (final regex in patterns) {
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

  /// Extrae el concepto/nombre del establecimiento.
  /// Generalmente es una de las primeras líneas del ticket.
  String? _extractConcept(List<TextBlock> blocks) {
    if (blocks.isEmpty) return null;

    // Buscar el primer bloque con texto significativo (>3 chars, no es fecha/número)
    for (final block in blocks.take(5)) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.length > 3 && !RegExp(r'^\d+[/\-.\s]').hasMatch(text)) {
          // Filtrar líneas que son solo números, fechas o RFC
          if (!RegExp(r'^[\d\s\$.,\-/]+$').hasMatch(text) &&
              !text.toLowerCase().contains('rfc') &&
              !text.toLowerCase().contains('ticket')) {
            return text;
          }
        }
      }
    }
    return null;
  }

  void dispose() {
    _recognizer.close();
  }
}
