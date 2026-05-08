// test/features/sync/sync_repository_impl_test.dart
//
// ════════════════════════════════════════════════════════════════════════
// SyncRepositoryImpl.processQueue — el dispatcher de la cola.
// ════════════════════════════════════════════════════════════════════════
//
// PIEZA CRÍTICA: Decide qué hacer con cada item según el resultado del
// remoto. Un bug acá = pérdida de datos (eliminar lo que no debías) o
// loops infinitos (no eliminar lo que sí).
//
// REGLAS A VALIDAR (matriz de decisión):
//
// | Resultado del remoto    | Acción local                      | Cuenta success? |
// |-------------------------|-----------------------------------|-----------------|
// | success                 | removeItem                        | sí              |
// | permanentFailure        | removeItem (purga sin retries)    | no              |
// | transientFailure        | markFailed (incrementa retry)     | no              |
// | authFailure             | markFailed + throw SyncAuthExc.   | no (pre-throw)  |
//
// Adicional:
//   - authFailure ABORTA el loop: items posteriores NO se procesan.
//   - SyncAuthException expone successCountBeforeAuth.
//   - Al final del run exitoso: purgeExhaustedItems se ejecuta.
//
// ARQUITECTURA DEL TEST:
//   - SyncLocalDataSource: REAL (Isar in-memory). Vemos el efecto
//     verdadero sobre la cola.
//   - SyncRemoteDataSource: MOCK (mocktail). Controlamos el outcome de
//     executeOperation por item.
//
//   Este enfoque híbrido nos da tests que verifican comportamiento
//   end-to-end del repo sin depender de Supabase real.
//
// ════════════════════════════════════════════════════════════════════════

import 'package:beti_app/features/sync/data/datasources/sync_local_ds.dart';
import 'package:beti_app/features/sync/data/datasources/sync_remote_ds.dart';
import 'package:beti_app/features/sync/data/models/sync_queue_model.dart';
import 'package:beti_app/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_data_factory.dart';
import '../../helpers/isar_test_helper.dart';

class _MockRemoteDs extends Mock implements SyncRemoteDataSource {}

/// Fallback para `any<SyncQueueModel>()` — mocktail lo requiere para tipos
/// no nullable que no son primitivos.
class _FakeSyncQueueModel extends Fake implements SyncQueueModel {}

void main() {
  setUpAll(() async {
    await IsarTestHelper.initCore();
    registerFallbackValue(_FakeSyncQueueModel());
  });

  late Isar isar;
  late SyncLocalDataSource localDs;
  late _MockRemoteDs remoteDs;
  late SyncRepositoryImpl repo;

  setUp(() async {
    isar = await IsarTestHelper.openIsar();
    localDs = SyncLocalDataSource(isar);
    remoteDs = _MockRemoteDs();
    repo = SyncRepositoryImpl(localDs: localDs, remoteDs: remoteDs);
  });

  tearDown(() async {
    await IsarTestHelper.closeIsar(isar);
  });

  // Helper: encola N items vía localDs (no via repo) para evitar el UUID
  // generado en enqueueChange y poder predecir uuids para asserts.
  Future<void> seed(List<SyncQueueModel> items) async {
    await isar.writeTxn(() async {
      await isar.syncQueueModels.putAll(items);
    });
  }

  // Helper: cuenta items en la cola sin filtrar.
  Future<int> queueLength() => isar.syncQueueModels.count();

  // ══════════════════════════════════════════════════════════════════════
  // enqueueChange (delgada — solo verifica que persiste)
  // ══════════════════════════════════════════════════════════════════════

  group('enqueueChange', () {
    test('crea un item con UUID generado', () async {
      await repo.enqueueChange(
        userId: 'user-1',
        targetCollection: 'transactions',
        targetUuid: 'txn-abc',
        operation: SyncOperation.create,
        payload: '{"amount":100}',
      );

      final all = await isar.syncQueueModels.where().findAll();
      expect(all.length, 1);
      expect(all.first.uuid, isNotEmpty,
          reason: 'enqueueChange genera UUID propio para el item de cola');
      expect(all.first.targetUuid, 'txn-abc');
      expect(all.first.payload, '{"amount":100}');
    });

    test('UUIDs distintos en llamadas sucesivas', () async {
      await repo.enqueueChange(
        userId: 'u',
        targetCollection: 'transactions',
        targetUuid: 'txn-1',
        operation: SyncOperation.create,
        payload: '{}',
      );
      await repo.enqueueChange(
        userId: 'u',
        targetCollection: 'transactions',
        targetUuid: 'txn-2',
        operation: SyncOperation.create,
        payload: '{}',
      );

      final all = await isar.syncQueueModels.where().findAll();
      expect(all.length, 2);
      expect(all[0].uuid, isNot(all[1].uuid));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // processQueue — outcome simple: success
  // ══════════════════════════════════════════════════════════════════════

  group('processQueue — success', () {
    test('elimina items de la cola y los cuenta como success', () async {
      await seed([
        FakeDataFactory.syncQueueItem(uuid: 'a'),
        FakeDataFactory.syncQueueItem(uuid: 'b'),
        FakeDataFactory.syncQueueItem(uuid: 'c'),
      ]);

      when(() => remoteDs.executeOperation(any()))
          .thenAnswer((_) async => SyncExecutionResult.success);

      final count = await repo.processQueue();

      expect(count, 3);
      expect(await queueLength(), 0,
          reason: 'todos los items exitosos se eliminan');
    });

    test('cola vacía: success=0, no llama al remoto', () async {
      final count = await repo.processQueue();

      expect(count, 0);
      verifyNever(() => remoteDs.executeOperation(any()));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // processQueue — permanentFailure (purga sin retries)
  // ══════════════════════════════════════════════════════════════════════

  group('processQueue — permanentFailure', () {
    test('elimina el item pero NO lo cuenta como success', () async {
      await seed([FakeDataFactory.syncQueueItem(uuid: 'bad-payload')]);

      when(() => remoteDs.executeOperation(any()))
          .thenAnswer((_) async => SyncExecutionResult.permanentFailure);

      final count = await repo.processQueue();

      expect(count, 0,
          reason: 'permanentFailure no incrementa successCount');
      expect(await queueLength(), 0,
          reason: 'permanentFailure purga el item');
    });

    test('mezcla success + permanent: cuenta solo success, todos fuera',
        () async {
      await seed([
        FakeDataFactory.syncQueueItem(uuid: 'ok-1'),
        FakeDataFactory.syncQueueItem(uuid: 'bad-1'),
        FakeDataFactory.syncQueueItem(uuid: 'ok-2'),
      ]);

      when(() => remoteDs.executeOperation(
              any(that: predicate<SyncQueueModel>((i) => i.uuid == 'bad-1'))))
          .thenAnswer((_) async => SyncExecutionResult.permanentFailure);
      when(() => remoteDs.executeOperation(
              any(that: predicate<SyncQueueModel>((i) => i.uuid != 'bad-1'))))
          .thenAnswer((_) async => SyncExecutionResult.success);

      final count = await repo.processQueue();

      expect(count, 2);
      expect(await queueLength(), 0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // processQueue — transientFailure (retry)
  // ══════════════════════════════════════════════════════════════════════

  group('processQueue — transientFailure', () {
    test('marca como fallido (incrementa retryCount), preserva el item',
        () async {
      await seed([
        FakeDataFactory.syncQueueItem(uuid: 'will-retry', retryCount: 0),
      ]);

      when(() => remoteDs.executeOperation(any()))
          .thenAnswer((_) async => SyncExecutionResult.transientFailure);

      final count = await repo.processQueue();

      expect(count, 0);
      expect(await queueLength(), 1, reason: 'item se preserva para reintento');

      final item = await isar.syncQueueModels
          .filter()
          .uuidEqualTo('will-retry')
          .findFirst();
      expect(item!.retryCount, 1);
      expect(item.lastError, isNotNull);
      expect(item.lastError, contains('Transient failure'));
      expect(item.lastAttemptAt, isNotNull);
    });

    test(
        'item ya con retries acumulados sigue incrementando hasta el cap',
        () async {
      await seed([
        FakeDataFactory.syncQueueItem(uuid: 'high-retry', retryCount: 3),
      ]);

      when(() => remoteDs.executeOperation(any()))
          .thenAnswer((_) async => SyncExecutionResult.transientFailure);

      await repo.processQueue();

      final item = await isar.syncQueueModels
          .filter()
          .uuidEqualTo('high-retry')
          .findFirst();
      expect(item!.retryCount, 4);
      expect(await queueLength(), 1,
          reason: 'retry=4 todavía no es purgable (cap es >=5)');
    });

    test('item que cruza el cap es purgado por purgeExhaustedItems al final',
        () async {
      // Seed con retry=4: tras este intento fallido pasa a 5, el cap.
      await seed([
        FakeDataFactory.syncQueueItem(uuid: 'will-exhaust', retryCount: 4),
      ]);

      when(() => remoteDs.executeOperation(any()))
          .thenAnswer((_) async => SyncExecutionResult.transientFailure);

      final count = await repo.processQueue();

      expect(count, 0);
      expect(await queueLength(), 0,
          reason: 'retry pasó a 5, purgeExhaustedItems lo eliminó');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // processQueue — authFailure (abort + throw)
  // ══════════════════════════════════════════════════════════════════════

  group('processQueue — authFailure', () {
    test('lanza SyncAuthException con successCountBeforeAuth=0', () async {
      await seed([FakeDataFactory.syncQueueItem(uuid: 'token-expired')]);

      when(() => remoteDs.executeOperation(any()))
          .thenAnswer((_) async => SyncExecutionResult.authFailure);

      await expectLater(
        repo.processQueue(),
        throwsA(isA<SyncAuthException>()
            .having((e) => e.successCountBeforeAuth, 'success', 0)),
      );

      // El item se marcó como fallido, no se eliminó.
      final item = await isar.syncQueueModels
          .filter()
          .uuidEqualTo('token-expired')
          .findFirst();
      expect(item, isNotNull);
      expect(item!.retryCount, 1);
      expect(item.lastError, contains('Auth failure'));
    });

    test('aborta items posteriores cuando uno falla con authFailure',
        () async {
      // 3 items: el primero éxito, segundo auth-fail, tercero NO debe llamarse.
      await seed([
        FakeDataFactory.syncQueueItem(
          uuid: 'first-ok',
          operation: SyncOperation.delete, // priority 0 — va primero
        ),
        FakeDataFactory.syncQueueItem(
          uuid: 'second-auth',
          operation: SyncOperation.create, // priority 1
          enqueuedAt: DateTime.now(),
        ),
        FakeDataFactory.syncQueueItem(
          uuid: 'third-never',
          operation: SyncOperation.create, // priority 1
          enqueuedAt: DateTime.now().add(const Duration(seconds: 10)),
        ),
      ]);

      when(() => remoteDs.executeOperation(
              any(that: predicate<SyncQueueModel>((i) => i.uuid == 'first-ok'))))
          .thenAnswer((_) async => SyncExecutionResult.success);
      when(() => remoteDs.executeOperation(any(
              that: predicate<SyncQueueModel>((i) => i.uuid == 'second-auth'))))
          .thenAnswer((_) async => SyncExecutionResult.authFailure);
      // 'third-never' debería NO ser llamado — si lo es, el test falla con
      // un MissingStubError de mocktail.

      await expectLater(
        repo.processQueue(),
        throwsA(isA<SyncAuthException>()
            .having((e) => e.successCountBeforeAuth, 'success', 1)),
      );

      // Verificamos que el remoto NO recibió el tercer item.
      verifyNever(() => remoteDs.executeOperation(
          any(that: predicate<SyncQueueModel>((i) => i.uuid == 'third-never'))));

      // first-ok se eliminó (success). second-auth y third-never quedan.
      final remaining = await isar.syncQueueModels.where().findAll();
      final uuids = remaining.map((i) => i.uuid).toSet();
      expect(uuids, {'second-auth', 'third-never'});
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // getPendingCount + flushBeforeWipe
  // ══════════════════════════════════════════════════════════════════════

  group('getPendingCount', () {
    test('refleja la cantidad real en Isar (sin filtrar backoff)', () async {
      await seed([
        FakeDataFactory.syncQueueItem(uuid: 'a'),
        FakeDataFactory.syncQueueItem(uuid: 'b'),
        FakeDataFactory.syncQueueItem(
          uuid: 'c-in-backoff',
          retryCount: 3,
          lastAttemptAt: DateTime.now(),
        ),
      ]);

      expect(await repo.getPendingCount(), 3);
    });
  });

  group('flushBeforeWipe', () {
    test('cola vacía → retorna true', () async {
      expect(await repo.flushBeforeWipe(), isTrue);
    });

    test(
        'todos los items pushean exitosamente → retorna true (cola limpia)',
        () async {
      await seed([
        FakeDataFactory.syncQueueItem(uuid: 'a'),
        FakeDataFactory.syncQueueItem(uuid: 'b'),
      ]);

      when(() => remoteDs.executeOperation(any()))
          .thenAnswer((_) async => SyncExecutionResult.success);

      expect(await repo.flushBeforeWipe(), isTrue);
      expect(await queueLength(), 0);
    });

    test('algún item falla transitoriamente → retorna false (cola persiste)',
        () async {
      await seed([
        FakeDataFactory.syncQueueItem(uuid: 'will-fail'),
      ]);

      when(() => remoteDs.executeOperation(any()))
          .thenAnswer((_) async => SyncExecutionResult.transientFailure);

      expect(await repo.flushBeforeWipe(), isFalse,
          reason: 'la cola NO debe wipearse si hay pendientes');
      expect(await queueLength(), 1);
    });

    test('authException se traga internamente, retorna false (no relanza)',
        () async {
      await seed([
        FakeDataFactory.syncQueueItem(uuid: 'auth-fails'),
      ]);

      when(() => remoteDs.executeOperation(any()))
          .thenAnswer((_) async => SyncExecutionResult.authFailure);

      // CRÍTICO: flushBeforeWipe NO debe propagar la excepción —
      // el caller (signOut) la trataría como error y abortaría el wipe.
      await expectLater(repo.flushBeforeWipe(), completes);
      expect(await repo.flushBeforeWipe(), isFalse);
    });
  });
}