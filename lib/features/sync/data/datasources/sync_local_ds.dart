import 'package:isar/isar.dart';
import 'package:betty_app/features/sync/data/models/sync_queue_model.dart';
import 'package:betty_app/core/constants/financial_constants.dart';

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

  /// Obtiene todos los items pendientes ordenados por prioridad y fecha.
  Future<List<SyncQueueModel>> getPendingItems() async {
    return await _isar.syncQueueModels
        .where()
        .sortByPriority()
        .thenByEnqueuedAt()
        .findAll();
  }

  /// Obtiene la cantidad de items pendientes.
  Future<int> getPendingCount() async {
    return await _isar.syncQueueModels.count();
  }

  /// Elimina un item de la cola (sync exitosa).
  Future<void> removeItem(String uuid) async {
    await _isar.writeTxn(() async {
      final item = await _isar.syncQueueModels
          .filter()
          .uuidEqualTo(uuid)
          .findFirst();
      if (item != null) {
        await _isar.syncQueueModels.delete(item.id);
      }
    });
  }

  /// Incrementa el retryCount y guarda el error de un item fallido.
  Future<void> markFailed(String uuid, String error) async {
    await _isar.writeTxn(() async {
      final item = await _isar.syncQueueModels
          .filter()
          .uuidEqualTo(uuid)
          .findFirst();

      if (item != null) {
        item.retryCount += 1;
        item.lastError = error;
        item.lastAttemptAt = DateTime.now();
        await _isar.syncQueueModels.put(item);
      }
    });
  }

  /// Elimina items que excedieron el máximo de reintentos.
  Future<int> purgeExhaustedItems() async {
    int purged = 0;
    await _isar.writeTxn(() async {
      final exhausted = await _isar.syncQueueModels
          .filter()
          .retryCountGreaterThan(FinancialConstants.maxSyncRetries)
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
