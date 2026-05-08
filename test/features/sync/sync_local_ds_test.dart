// test/features/sync/sync_local_ds_test.dart
//
// ════════════════════════════════════════════════════════════════════════
// SyncLocalDataSource — la cola FIFO con prioridad y backoff exponencial.
// ════════════════════════════════════════════════════════════════════════
//
// PIEZA CRÍTICA: Si esta clase falla, el usuario pierde transacciones que
// pensaba estaban respaldadas. CERO TOLERANCIA a bugs.
//
// QUÉ VALIDAMOS:
//
// 1. ENQUEUE
//    - Persiste el item con todos los campos correctos.
//    - Asigna priority según operation: delete=0, create=1, update=2.
//    - retryCount inicial = 0, lastAttemptAt = null, lastError = null.
//
// 2. ORDEN DE PROCESAMIENTO
//    - Sort primario por priority asc (deletes primero, luego creates,
//      luego updates).
//    - Sort secundario por enqueuedAt asc (FIFO dentro de la misma prio).
//
// 3. BACKOFF EXPONENCIAL
//    - retry=0 → siempre listo (sin importar lastAttemptAt).
//    - retry=N>0 → listo solo si han pasado 2^N segundos desde lastAttemptAt.
//    - Items en ventana de backoff NO aparecen en getPendingItems().
//
// 4. MARK FAILED
//    - Incrementa retryCount.
//    - Setea lastError y lastAttemptAt.
//    - Item sigue en la cola (no se elimina).
//
// 5. PURGE EXHAUSTED
//    - Borra items con retryCount > maxSyncRetries-1 (es decir >= 5).
//    - Retorna count purgado.
//    - Items con retryCount=4 (un intento más antes del cap) NO se purgan.
//
// NO USAMOS MOCKS: Isar es nuestra dependencia real. Mockearlo nos haría
// probar que llamamos a Isar, no que el comportamiento es correcto.
//
// ════════════════════════════════════════════════════════════════════════

import 'package:beti_app/core/constants/financial_constants.dart';
import 'package:beti_app/features/sync/data/datasources/sync_local_ds.dart';
import 'package:beti_app/features/sync/data/models/sync_queue_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../../helpers/fake_data_factory.dart';
import '../../helpers/isar_test_helper.dart';

void main() {
  setUpAll(IsarTestHelper.initCore);

  late Isar isar;
  late SyncLocalDataSource ds;

  setUp(() async {
    isar = await IsarTestHelper.openIsar();
    ds = SyncLocalDataSource(isar);
  });

  tearDown(() async {
    await IsarTestHelper.closeIsar(isar);
  });

  // ══════════════════════════════════════════════════════════════════════
  // ENQUEUE
  // ══════════════════════════════════════════════════════════════════════

  group('enqueue', () {
    test('persiste el item con todos los campos', () async {
      await ds.enqueue(
        uuid: 'queue-1',
        userId: 'user-A',
        targetCollection: 'transactions',
        targetUuid: 'txn-abc',
        operation: SyncOperation.create,
        payload: '{"amount":100}',
        attachmentPath: '/tmp/ticket.jpg',
      );

      final items = await isar.syncQueueModels.where().findAll();
      expect(items.length, 1);

      final i = items.first;
      expect(i.uuid, 'queue-1');
      expect(i.userId, 'user-A');
      expect(i.targetCollection, 'transactions');
      expect(i.targetUuid, 'txn-abc');
      expect(i.operation, SyncOperation.create);
      expect(i.payload, '{"amount":100}');
      expect(i.attachmentPath, '/tmp/ticket.jpg');
      expect(i.retryCount, 0);
      expect(i.lastError, isNull);
      expect(i.lastAttemptAt, isNull);
    });

    test('asigna priority=0 a deletes', () async {
      await ds.enqueue(
        uuid: 'q-del',
        userId: 'u',
        targetCollection: 'transactions',
        targetUuid: 't',
        operation: SyncOperation.delete,
        payload: '{}',
      );
      final i = await isar.syncQueueModels.where().findFirst();
      expect(i!.priority, 0);
    });

    test('asigna priority=1 a creates', () async {
      await ds.enqueue(
        uuid: 'q-cr',
        userId: 'u',
        targetCollection: 'transactions',
        targetUuid: 't',
        operation: SyncOperation.create,
        payload: '{}',
      );
      final i = await isar.syncQueueModels.where().findFirst();
      expect(i!.priority, 1);
    });

    test('asigna priority=2 a updates', () async {
      await ds.enqueue(
        uuid: 'q-up',
        userId: 'u',
        targetCollection: 'transactions',
        targetUuid: 't',
        operation: SyncOperation.update,
        payload: '{}',
      );
      final i = await isar.syncQueueModels.where().findFirst();
      expect(i!.priority, 2);
    });

    test('attachmentPath es opcional', () async {
      await ds.enqueue(
        uuid: 'q-noattach',
        userId: 'u',
        targetCollection: 'transactions',
        targetUuid: 't',
        operation: SyncOperation.create,
        payload: '{}',
      );
      final i = await isar.syncQueueModels.where().findFirst();
      expect(i!.attachmentPath, isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // ORDEN DE PROCESAMIENTO (priority + FIFO)
  // ══════════════════════════════════════════════════════════════════════

  group('getPendingItems — orden', () {
    test('ordena por priority asc: deletes primero, updates al final',
        () async {
      // Insertamos en orden inverso al esperado para validar el sort.
      await isar.writeTxn(() async {
        await isar.syncQueueModels.put(
          FakeDataFactory.syncQueueItem(
            uuid: 'u1',
            operation: SyncOperation.update,
          ),
        );
        await isar.syncQueueModels.put(
          FakeDataFactory.syncQueueItem(
            uuid: 'c1',
            operation: SyncOperation.create,
          ),
        );
        await isar.syncQueueModels.put(
          FakeDataFactory.syncQueueItem(
            uuid: 'd1',
            operation: SyncOperation.delete,
          ),
        );
      });

      final pending = await ds.getPendingItems();

      expect(pending.map((i) => i.uuid).toList(), ['d1', 'c1', 'u1']);
    });

    test('FIFO dentro de la misma prioridad (sort secundario por enqueuedAt)',
        () async {
      final t0 = DateTime(2026, 1, 1, 10, 0, 0);

      await isar.writeTxn(() async {
        // c2 enqueued después que c1, ambos creates (priority=1)
        await isar.syncQueueModels.put(
          FakeDataFactory.syncQueueItem(
            uuid: 'c2',
            operation: SyncOperation.create,
            enqueuedAt: t0.add(const Duration(seconds: 30)),
          ),
        );
        await isar.syncQueueModels.put(
          FakeDataFactory.syncQueueItem(
            uuid: 'c1',
            operation: SyncOperation.create,
            enqueuedAt: t0,
          ),
        );
        await isar.syncQueueModels.put(
          FakeDataFactory.syncQueueItem(
            uuid: 'c3',
            operation: SyncOperation.create,
            enqueuedAt: t0.add(const Duration(seconds: 60)),
          ),
        );
      });

      final pending = await ds.getPendingItems();

      expect(pending.map((i) => i.uuid).toList(), ['c1', 'c2', 'c3']);
    });

    test('mezcla prioridades + FIFO secundario', () async {
      final t0 = DateTime(2026, 1, 1, 10, 0, 0);

      await isar.writeTxn(() async {
        await isar.syncQueueModels.putAll([
          FakeDataFactory.syncQueueItem(
            uuid: 'c-late',
            operation: SyncOperation.create,
            enqueuedAt: t0.add(const Duration(seconds: 60)),
          ),
          FakeDataFactory.syncQueueItem(
            uuid: 'd-early',
            operation: SyncOperation.delete,
            enqueuedAt: t0,
          ),
          FakeDataFactory.syncQueueItem(
            uuid: 'u-middle',
            operation: SyncOperation.update,
            enqueuedAt: t0.add(const Duration(seconds: 30)),
          ),
          FakeDataFactory.syncQueueItem(
            uuid: 'c-early',
            operation: SyncOperation.create,
            enqueuedAt: t0,
          ),
        ]);
      });

      final pending = await ds.getPendingItems();
      // Orden esperado:
      //   d-early (prio 0)
      //   c-early, c-late (prio 1, FIFO)
      //   u-middle (prio 2)
      expect(pending.map((i) => i.uuid).toList(),
          ['d-early', 'c-early', 'c-late', 'u-middle']);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // BACKOFF EXPONENCIAL
  // ══════════════════════════════════════════════════════════════════════

  group('getPendingItems — backoff exponencial', () {
    test('retry=0 → siempre listo, ignora lastAttemptAt', () async {
      final ancientAttempt = DateTime.now().subtract(const Duration(days: 1));
      await isar.writeTxn(() async {
        await isar.syncQueueModels.put(
          FakeDataFactory.syncQueueItem(
            retryCount: 0,
            lastAttemptAt: ancientAttempt, // contradictorio pero válido
          ),
        );
      });

      final pending = await ds.getPendingItems();
      expect(pending.length, 1);
    });

    test('retry=1 + lastAttemptAt hace 1s → en backoff (2s mínimo)', () async {
      await isar.writeTxn(() async {
        await isar.syncQueueModels.put(
          FakeDataFactory.syncQueueItem(
            retryCount: 1,
            lastAttemptAt: DateTime.now()
                .subtract(const Duration(milliseconds: 500)),
          ),
        );
      });

      final pending = await ds.getPendingItems();
      expect(pending, isEmpty,
          reason: '500ms < 2s de backoff esperado para retry=1');
    });

    test('retry=1 + lastAttemptAt hace 3s → listo', () async {
      await isar.writeTxn(() async {
        await isar.syncQueueModels.put(
          FakeDataFactory.syncQueueItem(
            retryCount: 1,
            lastAttemptAt: DateTime.now().subtract(const Duration(seconds: 3)),
          ),
        );
      });

      final pending = await ds.getPendingItems();
      expect(pending.length, 1);
    });

    test('retry=3 + lastAttemptAt hace 5s → en backoff (espera 8s)', () async {
      await isar.writeTxn(() async {
        await isar.syncQueueModels.put(
          FakeDataFactory.syncQueueItem(
            retryCount: 3,
            lastAttemptAt: DateTime.now().subtract(const Duration(seconds: 5)),
          ),
        );
      });

      final pending = await ds.getPendingItems();
      expect(pending, isEmpty);
    });

    test('retry=3 + lastAttemptAt hace 9s → listo (>8s)', () async {
      await isar.writeTxn(() async {
        await isar.syncQueueModels.put(
          FakeDataFactory.syncQueueItem(
            retryCount: 3,
            lastAttemptAt: DateTime.now().subtract(const Duration(seconds: 9)),
          ),
        );
      });

      final pending = await ds.getPendingItems();
      expect(pending.length, 1);
    });

    test('mezcla: items frescos pasan, items en backoff se filtran', () async {
      await isar.writeTxn(() async {
        await isar.syncQueueModels.putAll([
          FakeDataFactory.syncQueueItem(uuid: 'fresh', retryCount: 0),
          FakeDataFactory.syncQueueItem(
            uuid: 'in-backoff',
            retryCount: 5,
            lastAttemptAt:
                DateTime.now().subtract(const Duration(seconds: 1)),
          ),
          FakeDataFactory.syncQueueItem(
            uuid: 'ready-after-backoff',
            retryCount: 2,
            lastAttemptAt:
                DateTime.now().subtract(const Duration(seconds: 10)),
          ),
        ]);
      });

      final pending = await ds.getPendingItems();
      final uuids = pending.map((i) => i.uuid).toSet();

      expect(uuids, contains('fresh'));
      expect(uuids, contains('ready-after-backoff'));
      expect(uuids, isNot(contains('in-backoff')));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // GET PENDING COUNT
  // ══════════════════════════════════════════════════════════════════════

  group('getPendingCount', () {
    test('cuenta TODOS los items, ignorando backoff', () async {
      // Diferencia clave con getPendingItems: count NO filtra backoff.
      await isar.writeTxn(() async {
        await isar.syncQueueModels.putAll([
          FakeDataFactory.syncQueueItem(uuid: 'a', retryCount: 0),
          FakeDataFactory.syncQueueItem(
            uuid: 'b',
            retryCount: 3,
            lastAttemptAt:
                DateTime.now().subtract(const Duration(seconds: 1)),
          ),
        ]);
      });

      final count = await ds.getPendingCount();
      expect(count, 2);
    });

    test('cero cuando la cola está vacía', () async {
      expect(await ds.getPendingCount(), 0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // REMOVE ITEM
  // ══════════════════════════════════════════════════════════════════════

  group('removeItem', () {
    test('elimina el item con el uuid dado', () async {
      await isar.writeTxn(() async {
        await isar.syncQueueModels.putAll([
          FakeDataFactory.syncQueueItem(uuid: 'keep'),
          FakeDataFactory.syncQueueItem(uuid: 'remove-me'),
        ]);
      });

      await ds.removeItem('remove-me');

      final remaining = await isar.syncQueueModels.where().findAll();
      expect(remaining.length, 1);
      expect(remaining.first.uuid, 'keep');
    });

    test('no-op cuando el uuid no existe (no lanza)', () async {
      await isar.writeTxn(() async {
        await isar.syncQueueModels
            .put(FakeDataFactory.syncQueueItem(uuid: 'exists'));
      });

      await expectLater(ds.removeItem('does-not-exist'), completes);

      final count = await isar.syncQueueModels.count();
      expect(count, 1);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // MARK FAILED
  // ══════════════════════════════════════════════════════════════════════

  group('markFailed', () {
    test('incrementa retryCount, guarda lastError y lastAttemptAt', () async {
      await isar.writeTxn(() async {
        await isar.syncQueueModels.put(
          FakeDataFactory.syncQueueItem(uuid: 'item-1', retryCount: 0),
        );
      });

      final beforeMark = DateTime.now();
      await ds.markFailed('item-1', 'PGRST204: column missing');
      final afterMark = DateTime.now();

      final item = await isar.syncQueueModels
          .filter()
          .uuidEqualTo('item-1')
          .findFirst();

      expect(item, isNotNull);
      expect(item!.retryCount, 1);
      expect(item.lastError, 'PGRST204: column missing');
      expect(item.lastAttemptAt, isNotNull);
      // lastAttemptAt cae dentro de la ventana del test
      expect(
        item.lastAttemptAt!.isAfter(
              beforeMark.subtract(const Duration(seconds: 1)),
            ) &&
            item.lastAttemptAt!.isBefore(
              afterMark.add(const Duration(seconds: 1)),
            ),
        isTrue,
      );
    });

    test('llamadas sucesivas siguen incrementando retryCount', () async {
      await isar.writeTxn(() async {
        await isar.syncQueueModels.put(
          FakeDataFactory.syncQueueItem(uuid: 'item-1', retryCount: 2),
        );
      });

      await ds.markFailed('item-1', 'fail 1');
      await ds.markFailed('item-1', 'fail 2');

      final item = await isar.syncQueueModels
          .filter()
          .uuidEqualTo('item-1')
          .findFirst();

      expect(item!.retryCount, 4);
      expect(item.lastError, 'fail 2'); // último gana
    });

    test('item NO se elimina al marcarlo fallido', () async {
      await isar.writeTxn(() async {
        await isar.syncQueueModels
            .put(FakeDataFactory.syncQueueItem(uuid: 'item-1'));
      });

      await ds.markFailed('item-1', 'transient 5xx');

      final count = await isar.syncQueueModels.count();
      expect(count, 1);
    });

    test('no-op cuando el uuid no existe', () async {
      await expectLater(
        ds.markFailed('does-not-exist', 'whatever'),
        completes,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // PURGE EXHAUSTED
  // ══════════════════════════════════════════════════════════════════════

  group('purgeExhaustedItems', () {
    test('respeta el cap maxSyncRetries (5): purga retryCount >= 5', () async {
      // Sanity check: si alguien cambia maxSyncRetries, este test grita.
      expect(FinancialConstants.maxSyncRetries, 5,
          reason: 'Si cambias el cap, actualiza este test y los de backoff');

      await isar.writeTxn(() async {
        await isar.syncQueueModels.putAll([
          FakeDataFactory.syncQueueItem(uuid: 'r0', retryCount: 0),
          FakeDataFactory.syncQueueItem(uuid: 'r4', retryCount: 4),
          FakeDataFactory.syncQueueItem(uuid: 'r5', retryCount: 5),
          FakeDataFactory.syncQueueItem(uuid: 'r10', retryCount: 10),
        ]);
      });

      final purged = await ds.purgeExhaustedItems();

      expect(purged, 2, reason: 'r5 y r10 se purgan');

      final remaining = await isar.syncQueueModels.where().findAll();
      final remainingUuids = remaining.map((i) => i.uuid).toSet();
      expect(remainingUuids, {'r0', 'r4'});
    });

    test('retorna 0 cuando no hay items para purgar', () async {
      await isar.writeTxn(() async {
        await isar.syncQueueModels.putAll([
          FakeDataFactory.syncQueueItem(uuid: 'r0', retryCount: 0),
          FakeDataFactory.syncQueueItem(uuid: 'r3', retryCount: 3),
        ]);
      });

      final purged = await ds.purgeExhaustedItems();
      expect(purged, 0);

      final count = await isar.syncQueueModels.count();
      expect(count, 2);
    });

    test('retorna 0 sobre cola vacía', () async {
      final purged = await ds.purgeExhaustedItems();
      expect(purged, 0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CLEAR ALL
  // ══════════════════════════════════════════════════════════════════════

  group('clearAll', () {
    test('borra todo, sin importar retryCount o estado', () async {
      await isar.writeTxn(() async {
        await isar.syncQueueModels.putAll([
          FakeDataFactory.syncQueueItem(uuid: 'a', retryCount: 0),
          FakeDataFactory.syncQueueItem(uuid: 'b', retryCount: 3),
          FakeDataFactory.syncQueueItem(uuid: 'c', retryCount: 99),
        ]);
      });

      await ds.clearAll();

      expect(await isar.syncQueueModels.count(), 0);
    });
  });
}