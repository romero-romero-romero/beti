// test/features/budgets_goals/inflation_adjustment_service_test.dart
//
// ════════════════════════════════════════════════════════════════════════
// InflationAdjustmentService — ajuste compuesto diario de metas.
// ════════════════════════════════════════════════════════════════════════
//
// PIEZA CRÍTICA: Si el factor compuesto deriva, las metas del usuario se
// inflan o se contraen sin que él se entere. Bug acá = pérdida de
// confianza ("¿por qué subió mi meta de $100K a $115K en una semana?").
//
// FÓRMULA:
//   dailyFactor   = 1 + (annualRate / 365)
//   compoundFactor = dailyFactor ^ daysMissed
//   newTarget     = round(oldTarget * compoundFactor, 2)
//
// REGLAS A VALIDAR:
//   1. daysMissed cap = 365 (no inflar metas tras 2 años offline).
//   2. Si lastAdjust == today → no-op (idempotencia diaria).
//   3. Si rate <= 0 → no-op (configuración inválida).
//   4. Solo ajusta metas activas y NO completadas.
//   5. progress se recalcula tras ajustar targetAmount.
//   6. syncStatus pasa a pending para propagar a Supabase.
//   7. Sin lastAdjust previo → daysMissed = 1 (primer ajuste de la app).
//
// ESTRATEGIA:
//   - Isar real (in-memory) para validar el efecto persistido.
//   - SharedPreferences mockeado con `setMockInitialValues` (la API
//     oficial de shared_preferences para tests Dart-puros).
//
// ════════════════════════════════════════════════════════════════════════

import 'package:beti_app/features/budgets_goals/data/models/goal_model.dart';
import 'package:beti_app/features/budgets_goals/data/services/inflation_adjustment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_data_factory.dart';
import '../../helpers/isar_test_helper.dart';

const _userId = FakeDataFactory.defaultUserId;

void main() {
  setUpAll(IsarTestHelper.initCore);

  late Isar isar;
  late InflationAdjustmentService service;

  setUp(() async {
    isar = await IsarTestHelper.openIsar();
    service = InflationAdjustmentService(isar);
    // Cada test arranca con prefs limpios.
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await IsarTestHelper.closeIsar(isar);
  });

  // Helper: clave usada por el servicio para guardar última fecha de ajuste.
  // Replica `_todayKey()` privado en formato 'yyyy-MM-dd'.
  String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ══════════════════════════════════════════════════════════════════════
  // IDEMPOTENCIA
  // ══════════════════════════════════════════════════════════════════════

  group('idempotencia diaria', () {
    test('si lastAdjust == today, retorna 0 y NO modifica metas', () async {
      // Setup: pref con today + meta activa.
      final today = dateKey(DateTime.now());
      SharedPreferences.setMockInitialValues({
        'betty_inflation_last_adjust': today,
      });

      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(targetAmount: 10000, savedAmount: 1000),
        );
      });

      final adjusted = await service.adjustIfNeeded(_userId);
      expect(adjusted, 0);

      // El targetAmount debe seguir intacto.
      final goal = await isar.goalModels.where().findFirst();
      expect(goal!.targetAmount, 10000);
    });

    test(
        'segunda llamada en el mismo día retorna 0 (escribe la fecha tras la 1ra)',
        () async {
      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(targetAmount: 10000),
        );
      });

      final first = await service.adjustIfNeeded(_userId);
      final second = await service.adjustIfNeeded(_userId);

      expect(first, 1);
      expect(second, 0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // RATE=0 NO-OP
  // ══════════════════════════════════════════════════════════════════════

  group('rate inválida', () {
    test('rate=0 → retorna 0 y NO modifica metas', () async {
      await InflationAdjustmentService.setRate(0);

      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(targetAmount: 10000),
        );
      });

      final adjusted = await service.adjustIfNeeded(_userId);
      expect(adjusted, 0);

      final goal = await isar.goalModels.where().findFirst();
      expect(goal!.targetAmount, 10000);
    });

    test('rate negativa → no-op (la guarda usa rate <= 0)', () async {
      await InflationAdjustmentService.setRate(-0.05);
      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(targetAmount: 10000),
        );
      });

      final adjusted = await service.adjustIfNeeded(_userId);
      expect(adjusted, 0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // SIN METAS
  // ══════════════════════════════════════════════════════════════════════

  group('sin metas elegibles', () {
    test('cero metas → retorna 0', () async {
      final adjusted = await service.adjustIfNeeded(_userId);
      expect(adjusted, 0);
    });

    test('meta inactiva NO se ajusta', () async {
      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(targetAmount: 10000, isActive: false),
        );
      });

      final adjusted = await service.adjustIfNeeded(_userId);
      expect(adjusted, 0);

      final goal = await isar.goalModels.where().findFirst();
      expect(goal!.targetAmount, 10000);
    });

    test('meta completada NO se ajusta', () async {
      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(targetAmount: 10000, isCompleted: true),
        );
      });

      final adjusted = await service.adjustIfNeeded(_userId);
      expect(adjusted, 0);

      final goal = await isar.goalModels.where().findFirst();
      expect(goal!.targetAmount, 10000);
    });

    test('meta de OTRO usuario NO se ajusta', () async {
      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(
            userId: 'other-user',
            targetAmount: 10000,
          ),
        );
      });

      final adjusted = await service.adjustIfNeeded(_userId);
      expect(adjusted, 0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CÁLCULO MATEMÁTICO
  // ══════════════════════════════════════════════════════════════════════

  group('cálculo del factor compuesto', () {
    test('1 día con tasa default (4.5%) eleva el target ~0.0123%', () async {
      // dailyFactor = 1 + 0.045/365 ≈ 1.0001233
      // sobre 10000 → ~10001.23 (con redondeo a centavos).
      await InflationAdjustmentService.setRate(
        InflationAdjustmentService.defaultAnnualRate,
      );

      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(uuid: 'g-1', targetAmount: 10000),
        );
      });

      final adjusted = await service.adjustIfNeeded(_userId);
      expect(adjusted, 1);

      final goal = await isar.goalModels.where().findFirst();
      // Esperado: 10000 * (1 + 0.045/365)^1 ≈ 10001.23
      // El servicio redondea a centavos.
      expect(goal!.targetAmount, closeTo(10001.23, 0.02));
    });

    test('tasa 36.5% × 1 día = factor exacto 1.001 (10000 → 10010.00)',
        () async {
      // 0.365 / 365 = exactamente 0.001
      // dailyFactor = 1.001
      // Sobre 10000 → 10010.00
      await InflationAdjustmentService.setRate(0.365);

      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(targetAmount: 10000),
        );
      });

      await service.adjustIfNeeded(_userId);

      final goal = await isar.goalModels.where().findFirst();
      expect(goal!.targetAmount, 10010.00);
    });

    test('targetAmount se redondea a centavos (2 decimales)', () async {
      // 1234.56 * 1.001 = 1235.79456 → redondeado a 1235.79
      await InflationAdjustmentService.setRate(0.365);

      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(targetAmount: 1234.56),
        );
      });

      await service.adjustIfNeeded(_userId);

      final goal = await isar.goalModels.where().findFirst();
      // Verifica que el resultado tiene a lo sumo 2 decimales.
      final cents = (goal!.targetAmount * 100).round();
      expect((goal.targetAmount * 100), closeTo(cents.toDouble(), 0.001));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // PROGRESS RECALCULADO
  // ══════════════════════════════════════════════════════════════════════

  group('recálculo de progress tras ajustar', () {
    test('progress se recalcula con el nuevo target', () async {
      // Ahorrado fijo, target sube → progress baja.
      await InflationAdjustmentService.setRate(0.365);

      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(
            targetAmount: 10000,
            savedAmount: 5000,
            // progress inicial 0.5 lo asigna la factory por defecto.
          ),
        );
      });

      await service.adjustIfNeeded(_userId);

      final goal = await isar.goalModels.where().findFirst();
      // Nuevo target = 10010, savedAmount = 5000 → progress = 0.4995...
      expect(goal!.progress,
          closeTo(5000 / goal.targetAmount, 0.0001));
      expect(goal.progress, lessThan(0.5));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // SYNC STATUS
  // ══════════════════════════════════════════════════════════════════════

  group('marca syncStatus = pending tras ajustar', () {
    test('meta synced pasa a pending para propagar el cambio', () async {
      await InflationAdjustmentService.setRate(0.365);

      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(
            targetAmount: 10000,
            syncStatus: GoalSyncStatus.synced,
          ),
        );
      });

      await service.adjustIfNeeded(_userId);

      final goal = await isar.goalModels.where().findFirst();
      expect(goal!.syncStatus, GoalSyncStatus.pending);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CAP DE 365 DÍAS
  // ══════════════════════════════════════════════════════════════════════

  group('cap daysMissed = 365', () {
    test('lastAdjust hace 2 años → solo ajusta como si fuera 1 año', () async {
      // Si daysMissed no se capeara, el factor sería astronómico.
      // Validamos que el resultado coincide con 365 días, no con 730.
      final twoYearsAgo = DateTime.now().subtract(const Duration(days: 730));
      SharedPreferences.setMockInitialValues({
        'betty_inflation_last_adjust': dateKey(twoYearsAgo),
      });

      await InflationAdjustmentService.setRate(0.10); // 10% anual
      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(targetAmount: 10000),
        );
      });

      await service.adjustIfNeeded(_userId);

      final goal = await isar.goalModels.where().findFirst();

      // Cálculo esperado con cap de 365:
      // factor = (1 + 0.10/365)^365 ≈ 1.10516 → ~11051.55
      // Sin cap (730 días) sería ~12213.
      // Esperamos algo cercano a 11051, definitivamente NO 12000+.
      expect(goal!.targetAmount, lessThan(12000),
          reason: 'cap de 365 días previene inflación descontrolada');
      expect(goal.targetAmount, greaterThan(10500));
    });

    test('lastAdjust hace 365 días = lastAdjust hace 730 días (cap activo)',
        () async {
      // Test de invariancia: el resultado debe ser el mismo.
      final goal1 = FakeDataFactory.goal(targetAmount: 10000);
      await InflationAdjustmentService.setRate(0.10);

      // Caso A: 365 días.
      SharedPreferences.setMockInitialValues({
        'betty_inflation_last_adjust':
            dateKey(DateTime.now().subtract(const Duration(days: 365))),
      });
      await isar.writeTxn(() async {
        await isar.goalModels.put(goal1);
      });
      await service.adjustIfNeeded(_userId);
      final after365 =
          (await isar.goalModels.where().findFirst())!.targetAmount;

      // Reset y caso B: 730 días.
      await isar.writeTxn(() async {
        await isar.goalModels.clear();
        await isar.goalModels
            .put(FakeDataFactory.goal(targetAmount: 10000));
      });
      SharedPreferences.setMockInitialValues({
        'betty_inflation_last_adjust':
            dateKey(DateTime.now().subtract(const Duration(days: 730))),
      });
      await service.adjustIfNeeded(_userId);
      final after730 =
          (await isar.goalModels.where().findFirst())!.targetAmount;

      // Ambos deben ser idénticos porque ambos hacen 365 días de ajuste.
      expect(after365, after730,
          reason: '365d y 730d producen el mismo resultado por el cap');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // PRIMER AJUSTE
  // ══════════════════════════════════════════════════════════════════════

  group('primer ajuste sin lastAdjust', () {
    test('sin lastAdjust → daysMissed = 1', () async {
      // Pref vacío, simulamos primera vez que la app corre.
      await InflationAdjustmentService.setRate(0.365);

      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(targetAmount: 10000),
        );
      });

      await service.adjustIfNeeded(_userId);

      final goal = await isar.goalModels.where().findFirst();
      // 1 día con factor 1.001 → 10010.
      expect(goal!.targetAmount, 10010.00);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CONFIGURACIÓN DE TASA
  // ══════════════════════════════════════════════════════════════════════

  group('getRate / setRate', () {
    test('default es 4.5% si no se configuró', () async {
      final r = await InflationAdjustmentService.getRate();
      expect(r, InflationAdjustmentService.defaultAnnualRate);
      expect(r, 0.045);
    });

    test('setRate persiste el valor', () async {
      await InflationAdjustmentService.setRate(0.07);
      final r = await InflationAdjustmentService.getRate();
      expect(r, 0.07);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // RESET DE FECHA
  // ══════════════════════════════════════════════════════════════════════

  group('resetLastAdjust', () {
    test('limpia la fecha guardada para forzar un nuevo ajuste', () async {
      // Simulamos ajuste previo y reset.
      SharedPreferences.setMockInitialValues({
        'betty_inflation_last_adjust': dateKey(DateTime.now()),
      });

      await InflationAdjustmentService.resetLastAdjust();

      // Tras reset, una llamada debe ajustar normalmente.
      await InflationAdjustmentService.setRate(0.365);
      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(targetAmount: 10000),
        );
      });

      final adjusted = await service.adjustIfNeeded(_userId);
      expect(adjusted, 1);
    });
  });
}