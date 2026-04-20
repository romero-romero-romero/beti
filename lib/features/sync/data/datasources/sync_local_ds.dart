import 'package:isar/isar.dart';
import 'package:beti_app/features/sync/data/models/sync_queue_model.dart';
import 'package:beti_app/core/constants/financial_constants.dart';

/// DataSource local para la cola de sincronización.
/// Lee y escribe SyncQueueModel en Isar.
class SyncLocalDataSource {
  final Isar _isar;

  SyncLocalDataSource(this._isar);

  /// Encola un cambio para sincronización posterior.
  Future<void> enqueue({
    required String uuid,
    required String userId,
    required String targetCollection,
    required String targetUuid,
    required SyncOperation operation,
    required String payload,
    String? attachmentPath,
  }) async {
    final priority = switch (operation) {
      SyncOperation.delete => 0,
      SyncOperation.create => 1,
      SyncOperation.update => 2,
    };

    final item = SyncQueueModel()
      ..uuid = uuid
      ..userId = userId
      ..targetCollection = targetCollection
      ..targetUuid = targetUuid
      ..operation = operation
      ..payload = payload
      ..attachmentPath = attachmentPath
      ..enqueuedAt = DateTime.now()
      ..retryCount = 0
      ..priority = priority;

    await _isar.writeTxn(() async {
      await _isar.syncQueueModels.put(item);
    });
  }

  /// Obtiene items pendientes ordenados por prioridad, filtrando los que
  /// están en ventana de backoff exponencial por fallos recientes.
  ///
  /// Backoff: 2^retryCount segundos desde lastAttemptAt.
  ///   retry 1 → espera 2s
  ///   retry 2 → espera 4s
  ///   retry 3 → espera 8s
  ///   retry 4 → espera 16s
  ///   retry 5 → espera 32s
  ///
  /// Items sin lastAttemptAt (nunca intentados) se incluyen siempre.
  Future<List<SyncQueueModel>> getPendingItems() async {
    final all = await _isar.syncQueueModels
        .where()
        .sortByPriority()
        .thenByEnqueuedAt()
        .findAll();

    final now = DateTime.now();
    return all.where((item) {
      if (item.retryCount == 0 || item.lastAttemptAt == null) return true;
      final backoffSeconds = 1 << item.retryCount; // 2^retryCount
      final readyAt =
          item.lastAttemptAt!.add(Duration(seconds: backoffSeconds));
      return now.isAfter(readyAt);
    }).toList();
  }

  /// Obtiene la cantidad de items pendientes.
  Future<int> getPendingCount() async {
    return await _isar.syncQueueModels.count();
  }

  /// Elimina un item de la cola (sync exitosa).
  Future<void> removeItem(String uuid) async {
    await _isar.writeTxn(() async {
      final item =
          await _isar.syncQueueModels.filter().uuidEqualTo(uuid).findFirst();
      if (item != null) {
        await _isar.syncQueueModels.delete(item.id);
      }
    });
  }

  /// Incrementa el retryCount y guarda el error de un item fallido.
  Future<void> markFailed(String uuid, String error) async {
    await _isar.writeTxn(() async {
      final item =
          await _isar.syncQueueModels.filter().uuidEqualTo(uuid).findFirst();

      if (item != null) {
        item.retryCount += 1;
        item.lastError = error;
        item.lastAttemptAt = DateTime.now();
        await _isar.syncQueueModels.put(item);
      }
    });
  }

  /// Elimina items que alcanzaron o excedieron el máximo de reintentos.
  /// C3: usar >= en lugar de > para purgar EN el 5º intento, no en el 6º.
  Future<int> purgeExhaustedItems() async {
    int purged = 0;
    await _isar.writeTxn(() async {
      final exhausted = await _isar.syncQueueModels
          .filter()
          .retryCountGreaterThan(FinancialConstants.maxSyncRetries - 1)
          .findAll();
      for (final item in exhausted) {
        await _isar.syncQueueModels.delete(item.id);
        purged++;
      }
    });
    return purged;
  }

  /// Limpia toda la cola (para testing o reset).
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.syncQueueModels.clear();
    });
  }
}
