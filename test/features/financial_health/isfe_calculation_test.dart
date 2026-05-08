// test/features/financial_health/isfe_calculation_test.dart
//
// ════════════════════════════════════════════════════════════════════════
// HealthEngine — ISFE: Indicador de Salud Financiera Emocional.
// ════════════════════════════════════════════════════════════════════════
//
// PIEZA CRÍTICA: Es el corazón de la propuesta de valor de Beti. Si el
// score deriva, la pantalla principal del usuario miente sobre su salud
// financiera.
//
// FÓRMULA:
//   score = R·0.35 + D·0.25 + C·0.20 + V·0.10 + M·0.10
//
// Donde cada componente cae en una escala 0-100:
//   R (Ratio gasto/ingreso) - basado en thresholds peace/stable/warning/danger
//   D (Debt level) - debt vs ingreso anual
//   C (Credit utilization) - balance/limit con thresholds healthy/dangerous
//   V (oVerdue payments) - 0 pagos = 100, 1 = 40, 2+ = 0
//   M (Meta progress) - progress * 100
//
// REQUISITO PREVIO:
//   En `lib/features/financial_health/data/datasources/health_engine.dart`,
//   agregar al final de la clase HealthEngine:
//
//     @visibleForTesting
//     double calculateScoreForTesting({...}) => _calculateScore(...);
//
//     @visibleForTesting
//     HealthLevel scoreToLevelForTesting(double score) => _scoreToLevel(score);
//
// ESTRATEGIA:
//   Tests sobre la matemática pura, sin Isar. El wrapper @visibleForTesting
//   nos da acceso a `_calculateScore` y `_scoreToLevel` sin tener que
//   hidratar 5 colecciones de Isar para cada test.
//
// ════════════════════════════════════════════════════════════════════════

import 'package:beti_app/core/constants/financial_constants.dart';
import 'package:beti_app/core/enums/health_level.dart';
import 'package:beti_app/features/financial_health/data/datasources/health_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../../helpers/isar_test_helper.dart';

void main() {
  setUpAll(IsarTestHelper.initCore);

  late Isar isar;
  late HealthEngine engine;

  setUp(() async {
    isar = await IsarTestHelper.openIsar();
    engine = HealthEngine(isar);
  });

  tearDown(() async {
    await IsarTestHelper.closeIsar(isar);
  });

  // Helper: invoca el wrapper @visibleForTesting con defaults razonables.
  double score({
    double ratio = 0.5,
    double totalDebt = 0,
    double totalIncome = 30000,
    double totalExpenses = 15000,
    double creditUtil = 0,
    int overduePayments = 0,
    double goalProgress = 0,
  }) =>
      engine.calculateScoreForTesting(
        ratio: ratio,
        totalDebt: totalDebt,
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        creditUtil: creditUtil,
        overduePayments: overduePayments,
        goalProgress: goalProgress,
      );

  // ══════════════════════════════════════════════════════════════════════
  // SANITY CHECK — pesos suman 1.0
  // ══════════════════════════════════════════════════════════════════════

  group('pesos del score', () {
    test('los 5 pesos suman exactamente 1.0', () {
      final sum = FinancialConstants.weightExpenseRatio +
          FinancialConstants.weightDebtLevel +
          FinancialConstants.weightCreditUtilization +
          FinancialConstants.weightOverduePayments +
          FinancialConstants.weightGoalProgress;
      expect(sum, closeTo(1.0, 0.0001));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // GUARDA "SIN ACTIVIDAD"
  // ══════════════════════════════════════════════════════════════════════

  group('guarda sin actividad', () {
    test('todos los inputs en cero → score = 0', () {
      final s = score(
        ratio: 0,
        totalIncome: 0,
        totalExpenses: 0,
        totalDebt: 0,
        creditUtil: 0,
        overduePayments: 0,
        goalProgress: 0,
      );
      expect(s, 0,
          reason: 'sin actividad financiera, no se infla un score artificial');
    });

    test('cualquier actividad mínima → score > 0', () {
      // Solo deuda activa.
      final withDebt = score(
        ratio: 0,
        totalIncome: 0,
        totalDebt: 1000,
        totalExpenses: 0,
      );
      expect(withDebt, greaterThan(0));

      // Solo progreso de meta.
      final withGoal = score(
        ratio: 0,
        totalIncome: 0,
        totalExpenses: 0,
        goalProgress: 0.5,
      );
      expect(withGoal, greaterThan(0));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // COMPONENTE R (Ratio gasto/ingreso) — peso 0.35
  // ══════════════════════════════════════════════════════════════════════

  group('componente R (ratio gasto/ingreso)', () {
    // Thresholds (de FinancialConstants):
    //   ratio <= 0.60 → 100 (peace)
    //   ratio <= 0.80 → 80  (stable)
    //   ratio <= 0.95 → 55  (warning)
    //   ratio <= 1.10 → 30  (danger)
    //   ratio > 1.10  → 10  (crisis)
    //
    // Aislamos R apagando los demás (debt=0, credit=0, overdue=0, goal=0)
    // pero con totalIncome > 0 para que pase la guarda de actividad.

    test('ratio 0.5 → R=100 → contribuye 35 al score base', () {
      final s = score(ratio: 0.5);
      // Componentes apagados:
      //   D = 100 (sin deuda) × 0.25 = 25
      //   C = 100 (sin crédito) × 0.20 = 20
      //   V = 100 (0 vencidos) × 0.10 = 10
      //   M = 0   × 0.10 = 0
      // R = 100 × 0.35 = 35
      // Total = 90
      expect(s, closeTo(90, 0.5));
    });

    test('ratio 0.70 (zona stable) → R=80', () {
      final s = score(ratio: 0.70);
      // R = 80 × 0.35 = 28; resto = 25 + 20 + 10 + 0 = 55
      // Total = 83
      expect(s, closeTo(83, 0.5));
    });

    test('ratio 0.90 (zona warning) → R=55', () {
      final s = score(ratio: 0.90);
      // R = 55 × 0.35 = 19.25; resto = 55
      // Total ≈ 74.25
      expect(s, closeTo(74.25, 0.5));
    });

    test('ratio 1.05 (zona danger) → R=30', () {
      final s = score(ratio: 1.05);
      // R = 30 × 0.35 = 10.5; resto = 55
      // Total ≈ 65.5
      expect(s, closeTo(65.5, 0.5));
    });

    test('ratio 1.5 (crisis) → R=10', () {
      final s = score(ratio: 1.5);
      // R = 10 × 0.35 = 3.5; resto = 55
      // Total ≈ 58.5
      expect(s, closeTo(58.5, 0.5));
    });

    test('boundary ratio = peaceThreshold exacto → R=100', () {
      final s = score(ratio: FinancialConstants.peaceThreshold);
      // <= 0.60 incluye el límite.
      expect(s, closeTo(90, 0.5));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // COMPONENTE D (Debt level) — peso 0.25
  // ══════════════════════════════════════════════════════════════════════

  group('componente D (deuda vs ingreso anual)', () {
    // debtRatio = totalDebt / (totalIncome * 12)
    //   debtRatio > 1.0 → 10
    //   debtRatio > 0.5 → 40
    //   debtRatio > 0.3 → 70
    //   else            → 100

    test('sin deuda → D=100', () {
      final s = score(totalDebt: 0, totalIncome: 30000);
      // R=100 + D=100 × 0.25 = 25 + C=100 × 0.20 + V=100 × 0.10
      // = 35 + 25 + 20 + 10 = 90
      expect(s, closeTo(90, 0.5));
    });

    test('deuda = 30% del ingreso anual → D=100 (zona saludable)', () {
      // ingreso anual = 30000 × 12 = 360000; deuda = 100000 → ratio 0.277
      // 0.277 NO es > 0.3, cae en el else → D=100
      final s = score(totalDebt: 100000, totalIncome: 30000);
      expect(s, closeTo(90, 0.5));
    });

    test('deuda = 40% del ingreso anual → D=70', () {
      // ingreso anual = 360000; deuda = 144000 → ratio 0.4
      // 0.4 > 0.3 → D=70
      final s = score(totalDebt: 144000, totalIncome: 30000);
      // D=70 × 0.25 = 17.5; resto = 35 + 20 + 10 = 65
      // Total ≈ 82.5
      expect(s, closeTo(82.5, 0.5));
    });

    test('deuda = 60% del ingreso anual → D=40', () {
      // ratio 0.6 → 0.6 > 0.5 → D=40
      final s = score(totalDebt: 216000, totalIncome: 30000);
      // D=40 × 0.25 = 10; resto = 65
      // Total ≈ 75
      expect(s, closeTo(75, 0.5));
    });

    test('deuda > 100% del ingreso anual → D=10', () {
      final s = score(totalDebt: 500000, totalIncome: 30000);
      // D=10 × 0.25 = 2.5; resto = 65
      // Total ≈ 67.5
      expect(s, closeTo(67.5, 0.5));
    });

    test('totalIncome=0 + deuda → D queda en 100 (no divide por cero)', () {
      // Edge case: si no hay ingreso, no se calcula debtRatio y D=100.
      // Esto puede ser controversial pero está en el código:
      //   if (totalIncome > 0) { ... debtScore se ajusta ... }
      final s = score(totalIncome: 0, totalDebt: 100000, ratio: 0);
      // Como totalIncome=0, ratio default va por la rama crisis (1.5):
      // pero pasamos ratio=0 explícitamente... y eso se usa.
      // Lo importante: NO crash por división por cero.
      expect(s.isNaN, isFalse);
      expect(s.isFinite, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // COMPONENTE C (Credit utilization) — peso 0.20
  // ══════════════════════════════════════════════════════════════════════

  group('componente C (utilización de crédito)', () {
    // creditUtil <= 0.30 → 100
    // creditUtil <= 0.70 → 60
    // else               → 20

    test('uso 0% → C=100', () {
      final s = score(creditUtil: 0);
      expect(s, closeTo(90, 0.5));
    });

    test('uso 25% → C=100 (zona saludable)', () {
      final s = score(creditUtil: 0.25);
      expect(s, closeTo(90, 0.5));
    });

    test('uso 50% → C=60', () {
      final s = score(creditUtil: 0.50);
      // C=60 × 0.20 = 12; resto = 35 + 25 + 10 = 70
      // Total = 82
      expect(s, closeTo(82, 0.5));
    });

    test('uso 80% → C=20', () {
      final s = score(creditUtil: 0.80);
      // C=20 × 0.20 = 4; resto = 70
      // Total = 74
      expect(s, closeTo(74, 0.5));
    });

    test('boundary 30% exacto → C=100', () {
      final s =
          score(creditUtil: FinancialConstants.healthyCreditUtilization);
      expect(s, closeTo(90, 0.5));
    });

    test('boundary 70% exacto → C=60', () {
      final s = score(
        creditUtil: FinancialConstants.dangerousCreditUtilization,
      );
      expect(s, closeTo(82, 0.5));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // COMPONENTE V (oVerdue payments) — peso 0.10
  // ══════════════════════════════════════════════════════════════════════

  group('componente V (pagos vencidos)', () {
    test('0 vencidos → V=100', () {
      final s = score(overduePayments: 0);
      expect(s, closeTo(90, 0.5));
    });

    test('1 vencido → V=40', () {
      final s = score(overduePayments: 1);
      // V=40 × 0.10 = 4; resto = 35 + 25 + 20 = 80
      // Total = 84 (perdimos 6 puntos)
      expect(s, closeTo(84, 0.5));
    });

    test('2+ vencidos → V=0', () {
      final s = score(overduePayments: 2);
      // V=0; resto = 80
      expect(s, closeTo(80, 0.5));
    });

    test('5 vencidos → mismo que 2 (penaliza igual)', () {
      final s2 = score(overduePayments: 2);
      final s5 = score(overduePayments: 5);
      expect(s2, equals(s5),
          reason: 'el código castiga 2+ con cero, no escala más');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // COMPONENTE M (Meta progress) — peso 0.10
  // ══════════════════════════════════════════════════════════════════════

  group('componente M (progreso de metas)', () {
    test('progress=0 → M=0', () {
      final s = score(goalProgress: 0);
      // M=0; resto = 35 + 25 + 20 + 10 = 90
      expect(s, closeTo(90, 0.5));
    });

    test('progress=0.5 → M=50 → contribuye 5', () {
      final s = score(goalProgress: 0.5);
      // M=50 × 0.10 = 5; resto = 90
      // Total = 95
      expect(s, closeTo(95, 0.5));
    });

    test('progress=1.0 → M=100 → contribuye 10', () {
      final s = score(goalProgress: 1.0);
      // M=100 × 0.10 = 10; resto = 90
      // Total = 100
      expect(s, closeTo(100, 0.5));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // ESCENARIOS COMPUESTOS — usuario real
  // ══════════════════════════════════════════════════════════════════════

  group('escenarios compuestos', () {
    test('usuario ideal: todo perfecto → score = 100', () {
      final s = score(
        ratio: 0.4,
        totalDebt: 0,
        totalIncome: 30000,
        creditUtil: 0,
        overduePayments: 0,
        goalProgress: 1.0,
      );
      // R=100×.35 + D=100×.25 + C=100×.20 + V=100×.10 + M=100×.10 = 100
      expect(s, closeTo(100, 0.5));
    });

    test('usuario en crisis: todo mal → score bajo', () {
      final s = score(
        ratio: 1.5, // crisis (R=10)
        totalDebt: 500000, // > anual (D=10)
        totalIncome: 30000,
        creditUtil: 0.95, // sobre 70% (C=20)
        overduePayments: 3, // 2+ (V=0)
        goalProgress: 0, // (M=0)
      );
      // 10×.35 + 10×.25 + 20×.20 + 0×.10 + 0×.10
      // = 3.5 + 2.5 + 4 + 0 + 0 = 10
      expect(s, closeTo(10, 0.5));
    });

    test('usuario promedio: mix de positivos y negativos', () {
      final s = score(
        ratio: 0.85, // warning (R=55)
        totalDebt: 144000, // 40% anual (D=70)
        totalIncome: 30000,
        creditUtil: 0.50, // medio (C=60)
        overduePayments: 0,
        goalProgress: 0.30,
      );
      // 55×.35 + 70×.25 + 60×.20 + 100×.10 + 30×.10
      // = 19.25 + 17.5 + 12 + 10 + 3 = 61.75
      expect(s, closeTo(61.75, 0.5));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // BOUNDS — score nunca fuera de [0, 100]
  // ══════════════════════════════════════════════════════════════════════

  group('bounds del score', () {
    test('caso extremo perfecto no excede 100', () {
      final s = score(
        ratio: 0,
        totalDebt: 0,
        totalIncome: 100000,
        creditUtil: 0,
        overduePayments: 0,
        goalProgress: 1.0,
      );
      expect(s, lessThanOrEqualTo(100.001));
    });

    test('caso extremo terrible no baja de 0', () {
      final s = score(
        ratio: 999,
        totalDebt: 999999999,
        totalIncome: 1,
        creditUtil: 999,
        overduePayments: 999,
        goalProgress: 0,
      );
      expect(s, greaterThanOrEqualTo(0));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // MAPEO score → HealthLevel
  // ══════════════════════════════════════════════════════════════════════

  group('scoreToLevel', () {
    test('score 0 → peace (estado neutro de "sin datos")', () {
      // Convención: 0 representa "sin actividad", se trata como peace.
      expect(engine.scoreToLevelForTesting(0), HealthLevel.peace);
    });

    test('score >= 80 → peace', () {
      expect(engine.scoreToLevelForTesting(80), HealthLevel.peace);
      expect(engine.scoreToLevelForTesting(95), HealthLevel.peace);
      expect(engine.scoreToLevelForTesting(100), HealthLevel.peace);
    });

    test('score [60, 80) → stable', () {
      expect(engine.scoreToLevelForTesting(60), HealthLevel.stable);
      expect(engine.scoreToLevelForTesting(75), HealthLevel.stable);
      expect(engine.scoreToLevelForTesting(79.99), HealthLevel.stable);
    });

    test('score [40, 60) → warning', () {
      expect(engine.scoreToLevelForTesting(40), HealthLevel.warning);
      expect(engine.scoreToLevelForTesting(50), HealthLevel.warning);
      expect(engine.scoreToLevelForTesting(59.99), HealthLevel.warning);
    });

    test('score [20, 40) → danger', () {
      expect(engine.scoreToLevelForTesting(20), HealthLevel.danger);
      expect(engine.scoreToLevelForTesting(30), HealthLevel.danger);
      expect(engine.scoreToLevelForTesting(39.99), HealthLevel.danger);
    });

    test('score (0, 20) → crisis', () {
      // Cuidado: score=0 cae en peace por la convención de "sin datos".
      // Pero score>0 y <20 sí es crisis.
      expect(engine.scoreToLevelForTesting(0.1), HealthLevel.crisis);
      expect(engine.scoreToLevelForTesting(10), HealthLevel.crisis);
      expect(engine.scoreToLevelForTesting(19.99), HealthLevel.crisis);
    });
  });
}