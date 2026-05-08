// test/features/intelligence/extract_numeric_amount_test.dart
//
// ════════════════════════════════════════════════════════════════════════
// NlpEntityExtractor — extracción de monto numérico desde STT/OCR.
// ════════════════════════════════════════════════════════════════════════
//
// CONTEXTO:
//   El motor STT del dispositivo entrega texto en formatos heterogéneos
//   según el OEM y el reconocedor (Apple Speech vs Google On-Device).
//   Específicamente para números, vimos en producción:
//
//   | Formato       | Origen                           | Esperado |
//   |---------------|----------------------------------|----------|
//   | "2 000"       | STT Android (es-MX, separador)   | 2000     |
//   | "2.000"       | STT iOS español europeo          | 2000     |
//   | "2,000"       | Reconocedor en inglés            | 2000     |
//   | "2000"        | Ideal sin separador              | 2000     |
//   | "$1,500.50"   | Texto formal                     | 1500.50  |
//   | "2.50"        | Decimal genuino                  | 2.50     |
//
// BUG HISTÓRICO QUE ESTOS TESTS BLINDAN:
//   "2 000" se parseaba como 2 (cogía solo el primer dígito).
//   "2.000" se parseaba como 2.0 (interpretaba como decimal).
//   El fix añadió pre-sanitización con regex disambiguante.
//
// ESTRATEGIA:
//   Testeamos via `NlpEntityExtractor.extract()` (función pública) en vez
//   de la privada `_extractNumericAmount`. Más auténtico — el texto pasa
//   primero por `_normalize()` que también puede afectar el monto.
//
// ════════════════════════════════════════════════════════════════════════

import 'package:beti_app/features/intelligence/data/datasources/nlp_entity_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper: ejecuta el pipeline completo y retorna solo el monto.
double? extractAmount(String input) =>
    NlpEntityExtractor.extract(input).amount;

void main() {
  // ══════════════════════════════════════════════════════════════════════
  // FORMATO IDEAL — número limpio
  // ══════════════════════════════════════════════════════════════════════

  group('número simple sin separadores', () {
    test('número de 4 dígitos suelto', () {
      expect(extractAmount('compre algo de 2000 pesos'), 2000);
    });

    test('número con signo de pesos pegado', () {
      expect(extractAmount('me cobraron \$2000'), 2000);
    });

    test('número con signo de pesos y espacio', () {
      expect(extractAmount('pague \$ 500 en el uber'), 500);
    });

    test('número grande sin formato', () {
      expect(extractAmount('compre carro de 250000'), 250000);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // BUG HISTÓRICO 1: espacio como separador de miles ("2 000")
  // ══════════════════════════════════════════════════════════════════════

  group('separador de miles con espacio (regresión STT Android)', () {
    test('"2 000" se interpreta como 2000, NO como 2', () {
      expect(extractAmount('compre algo de 2 000 pesos'), 2000);
    });

    test('"15 000" se interpreta como 15000', () {
      expect(extractAmount('renta de 15 000'), 15000);
    });

    test('"100 000" se interpreta como 100000', () {
      expect(extractAmount('moto de 100 000 pesos'), 100000);
    });

    test('NO colapsa "2 cosas" como número (2 sin 3 dígitos detrás)', () {
      // Este caso NO debe disparar el reemplazo de espacio→miles.
      // "2 cosas" no tiene 3 dígitos detrás del espacio.
      // El número resultante debería venir del fallback "número suelto >=2 dígitos".
      // Como no hay número de >=2 dígitos en "compre 2 cosas", retorna null.
      expect(extractAmount('compre 2 cosas'), isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // BUG HISTÓRICO 2: punto europeo como separador de miles ("2.000")
  // ══════════════════════════════════════════════════════════════════════

  group('separador de miles con punto (regresión STT iOS europeo)', () {
    test('"2.000" se interpreta como 2000, NO como 2.0', () {
      expect(extractAmount('me cobraron 2.000 pesos'), 2000);
    });

    test('"15.000" se interpreta como 15000', () {
      expect(extractAmount('pague \$15.000 de renta'), 15000);
    });

    test('"1.500" se interpreta como 1500', () {
      expect(extractAmount('compre tenis de 1.500'), 1500);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CASO DELICADO: el punto NO debe colapsar decimales genuinos
  // ══════════════════════════════════════════════════════════════════════

  group('decimales genuinos NO se confunden con miles', () {
    test('"2.50" sigue siendo 2.50 (1-2 dígitos tras el punto)', () {
      // El regex de sanitización exige EXACTAMENTE 3 dígitos tras el punto
      // para colapsar; 2.50 tiene 2 dígitos → se preserva.
      // Pero el regex final del fallback exige >=2 dígitos antes del punto,
      // así que "2.50" cae en la coma anglosajona del primer regex.
      expect(extractAmount('compre por \$2.50'), 2.50);
    });

    test('"15.99" sigue siendo 15.99', () {
      expect(extractAmount('me cobraron \$15.99'), 15.99);
    });

    test('"1500.75" mantiene el decimal', () {
      expect(extractAmount('total \$1500.75'), 1500.75);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // FORMATO ANGLOSAJÓN — coma como separador de miles
  // ══════════════════════════════════════════════════════════════════════

  group('separador de miles con coma (formato anglosajón)', () {
    test('"\$2,000" se interpreta como 2000', () {
      expect(extractAmount('me cobraron \$2,000'), 2000);
    });

    test('"\$1,500.50" se interpreta como 1500.50', () {
      expect(extractAmount('renta de \$1,500.50'), 1500.50);
    });

    test('"15,000 pesos"', () {
      expect(extractAmount('compre laptop de 15,000 pesos'), 15000);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // SUFIJOS DE MONEDA: pesos / varos / bolas / mxn
  // ══════════════════════════════════════════════════════════════════════

  group('sufijos de moneda mexicanos', () {
    test('"pesos"', () {
      expect(extractAmount('pague 500 pesos en tacos'), 500);
    });

    test('"varos" (slang mexicano)', () {
      expect(extractAmount('me costo 1500 varos'), 1500);
    });

    test('"bolas" (slang mexicano)', () {
      expect(extractAmount('gaste 200 bolas'), 200);
    });

    test('"mxn"', () {
      expect(extractAmount('cuesta 3500 mxn'), 3500);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // EDGE CASES
  // ══════════════════════════════════════════════════════════════════════

  group('edge cases', () {
    test('texto sin números retorna null', () {
      expect(extractAmount('hoy compre tacos'), isNull);
    });

    test('cero o negativo NO se interpreta como monto válido', () {
      // El regex acepta "0" pero la función exige value > 0.
      expect(extractAmount('me debían 0 pesos'), isNull);
    });

    test('número de un solo dígito sin sufijo de moneda → null', () {
      // El fallback exige >=2 dígitos para evitar falsos positivos
      // ("compre 1 cosa" no debería extraer 1 como monto).
      expect(extractAmount('compre 1 cosa'), isNull);
    });

    test('número de un solo dígito CON sufijo de moneda sí aplica', () {
      // "5 pesos" sí matchea el regex de sufijo (acepta \d+).
      expect(extractAmount('le di 5 pesos al niño'), 5);
    });

    test('texto vacío retorna null', () {
      expect(extractAmount(''), isNull);
    });

    test('solo signo de pesos sin número retorna null', () {
      expect(extractAmount('me cobraron \$'), isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CASOS REALES DE STT — frases tal como el reconocedor las entrega
  // ══════════════════════════════════════════════════════════════════════

  group('frases reales de STT', () {
    test('"compré tacos de 150 pesos"', () {
      expect(extractAmount('compré tacos de 150 pesos'), 150);
    });

    test('"pagué la luz 2 350 pesos" (espacio en miles)', () {
      expect(extractAmount('pagué la luz 2 350 pesos'), 2350);
    });

    test('"me depositaron 8.500 de mi quincena" (punto europeo)', () {
      expect(extractAmount('me depositaron 8.500 de mi quincena'), 8500);
    });

    test('"compre uber de 89.50" (decimal genuino)', () {
      expect(extractAmount('compre uber de 89.50'), 89.50);
    });

    test('"renta 12,500 pesos" (coma anglosajona)', () {
      expect(extractAmount('renta 12,500 pesos'), 12500);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // PRIORIDAD DE PATTERNS — primer patrón gana
  // ══════════════════════════════════════════════════════════════════════

  group('orden de prioridad de patterns', () {
    test('signo de pesos gana sobre número suelto posterior', () {
      // Si hay $X y luego Y suelto, X gana.
      expect(extractAmount('me cobraron \$500 ese día 25'), 500);
    });

    test('"pesos" gana sobre número suelto sin sufijo', () {
      // El regex de sufijo se evalúa antes que el de número suelto.
      // En "compre 2 cosas de 1500 pesos" el primero (1500) gana.
      expect(extractAmount('compre 2 cosas de 1500 pesos'), 1500);
    });
  });
}