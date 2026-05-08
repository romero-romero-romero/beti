// test/helpers/isar_test_helper_smoke_test.dart
//
// ════════════════════════════════════════════════════════════════════════
// SMOKE TEST de la infraestructura de testing.
// ════════════════════════════════════════════════════════════════════════
//
// PROPÓSITO:
//   Validar que el setup de testing funciona ANTES de escribir 50+ tests
//   que dependan de él. Si este archivo no pasa, no tiene sentido seguir.
//
// QUÉ PRUEBA:
//   1. `IsarTestHelper.initCore()` descarga el binario sin errores.
//   2. `IsarTestHelper.openIsar()` abre una instancia funcional.
//   3. Una operación básica de write/read sobre Isar funciona.
//   4. Dos tests consecutivos reciben BDs aisladas (no comparten estado).
//   5. `FakeDataFactory` produce modelos válidos.
//   6. `closeIsar` deja el sistema limpio.
//
// SI ESTO FALLA:
//   - "Failed to download Isar Core": problema de red en CI o firewall
//     bloqueando GitHub releases (Isar baja binarios desde ahí).
//   - "Schema not registered": olvidaste agregar un schema en
//     `_allSchemas` del helper.
//   - "Instance with name X already exists": dos tests intentaron usar
//     el mismo `name`. Verificar `_uniqueName()`.
//
// ════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:beti_app/features/sync/data/models/sync_queue_model.dart';
import 'package:beti_app/features/transactions/data/models/transaction_model.dart';

import 'fake_data_factory.dart';
import 'isar_test_helper.dart';

void main() {
  setUpAll(IsarTestHelper.initCore);

  group('IsarTestHelper smoke', () {
    late Isar isar;

    setUp(() async {
      isar = await IsarTestHelper.openIsar();
    });

    tearDown(() async {
      await IsarTestHelper.closeIsar(isar);
    });

    test('abre una instancia limpia (BD vacía)', () async {
      final count = await isar.syncQueueModels.count();
      expect(count, 0, reason: 'Cada test debe arrancar con BD vacía');
    });

    test('permite escribir y leer un SyncQueueModel', () async {
      final item = FakeDataFactory.syncQueueItem();

      await isar.writeTxn(() async {
        await isar.syncQueueModels.put(item);
      });

      final retrieved = await isar.syncQueueModels
          .filter()
          .uuidEqualTo(item.uuid)
          .findFirst();

      expect(retrieved, isNotNull);
      expect(retrieved!.uuid, item.uuid);
      expect(retrieved.targetCollection, 'transactions');
    });

    test('permite escribir y leer un TransactionModel', () async {
      final txn = FakeDataFactory.transaction(
        amount: 250.50,
        description: 'Café de prueba',
      );

      await isar.writeTxn(() async {
        await isar.transactionModels.put(txn);
      });

      final retrieved = await isar.transactionModels
          .filter()
          .uuidEqualTo(txn.uuid)
          .findFirst();

      expect(retrieved, isNotNull);
      expect(retrieved!.amount, 250.50);
      expect(retrieved.description, 'Café de prueba');
      expect(retrieved.type, TxType.expense);
      expect(retrieved.syncStatus, TxSyncStatus.pending);
    });

    test('aislamiento entre tests: nada del test anterior persiste',
        () async {
      // Si este test ve datos del anterior, el helper está roto.
      final syncCount = await isar.syncQueueModels.count();
      final txnCount = await isar.transactionModels.count();
      expect(syncCount, 0);
      expect(txnCount, 0);
    });

    test('queries con filtros funcionan', () async {
      final a = FakeDataFactory.syncQueueItem(targetCollection: 'transactions');
      final b = FakeDataFactory.syncQueueItem(targetCollection: 'credit_cards');
      final c = FakeDataFactory.syncQueueItem(targetCollection: 'transactions');

      await isar.writeTxn(() async {
        await isar.syncQueueModels.putAll([a, b, c]);
      });

      final txnsOnly = await isar.syncQueueModels
          .filter()
          .targetCollectionEqualTo('transactions')
          .findAll();

      expect(txnsOnly.length, 2);
    });
  });

  group('FakeDataFactory smoke', () {
    test('genera UUIDs únicos en sucesión', () {
      final t1 = FakeDataFactory.transaction();
      final t2 = FakeDataFactory.transaction();
      final t3 = FakeDataFactory.transaction();

      expect(t1.uuid, isNot(t2.uuid));
      expect(t2.uuid, isNot(t3.uuid));
      expect(t1.uuid, isNot(t3.uuid));
    });

    test('respeta overrides en TransactionModel', () {
      final txn = FakeDataFactory.transaction(
        amount: 999.99,
        description: 'XYZ',
        category: TxCategory.transport,
      );
      expect(txn.amount, 999.99);
      expect(txn.description, 'XYZ');
      expect(txn.category, TxCategory.transport);
    });

    test('asigna prioridad correcta a SyncQueueModel según operación', () {
      final create = FakeDataFactory.syncQueueItem();
      final update = FakeDataFactory.syncQueueItem(
        operation: SyncOperation.update,
      );
      final del = FakeDataFactory.syncQueueItem(
        operation: SyncOperation.delete,
      );

      expect(create.priority, 1);
      expect(update.priority, 2);
      expect(del.priority, 0);
    });

    test('BudgetModel calcula consumptionRatio automáticamente', () {
      final b = FakeDataFactory.budget(
        budgetedAmount: 1000,
        spentAmount: 250,
      );
      expect(b.consumptionRatio, 0.25);
    });

    test('BudgetModel formatea period como YYYY-MM por defecto', () {
      final b = FakeDataFactory.budget();
      expect(b.period, matches(RegExp(r'^\d{4}-\d{2}$')));
    });
  });
}