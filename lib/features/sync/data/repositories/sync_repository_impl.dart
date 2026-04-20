import 'package:flutter/foundation.dart';
import 'package:beti_app/core/utils/uuid_generator.dart';
import 'package:beti_app/features/sync/data/datasources/sync_local_ds.dart';
import 'package:beti_app/features/sync/data/datasources/sync_remote_ds.dart';
import 'package:beti_app/features/sync/data/models/sync_queue_model.dart';
import 'package:beti_app/features/sync/domain/repositories/sync_repository.dart';

/// Señal de que la cola se abortó por token inválido/expirado.
/// El caller debe refrescar auth y reintentar.
class SyncAuthException implements Exception {
  final int successCountBeforeAuth;
  SyncAuthException(this.successCountBeforeAuth);

  @override
  String toString() =>
      'SyncAuthException(successBeforeAuth: $successCountBeforeAuth)';
}

class SyncRepositoryImpl implements SyncRepository {
  final SyncLocalDataSource _localDs;
  final SyncRemoteDataSource _remoteDs;

  SyncRepositoryImpl({
    required SyncLocalDataSource localDs,
    required SyncRemoteDataSource remoteDs,
  })  : _localDs = localDs,
        _remoteDs = remoteDs;

  @override
  Future<void> enqueueChange({
    required String userId,
    required String targetCollection,
    required String targetUuid,
    required SyncOperation operation,
    required String payload,
    String? attachmentPath,
  }) async {
    await _localDs.enqueue(
      uuid: UuidGenerator.generate(),
      userId: userId,
      targetCollection: targetCollection,
      targetUuid: targetUuid,
      operation: operation,
      payload: payload,
      attachmentPath: attachmentPath,
    );
  }

  @override
  Future<int> processQueue() async {
    final pending = await _localDs.getPendingItems();
    int successCount = 0;
    int purgedByPermanent = 0;

    for (final item in pending) {
      final result = await _remoteDs.executeOperation(item);

      switch (result) {
        case SyncExecutionResult.success:
          await _localDs.removeItem(item.uuid);
          successCount++;
          break;

        case SyncExecutionResult.permanentFailure:
          // Error 4xx no recuperable: el payload/estado del servidor
          // nunca lo aceptará. Purgar sin gastar retries.
          await _localDs.removeItem(item.uuid);
          purgedByPermanent++;
          debugPrint(
              'SyncRepo: purged permanent failure for ${item.targetCollection}/${item.targetUuid}');
          break;

        case SyncExecutionResult.authFailure:
          // A12: token inválido — marcar este item y abortar con excepción
          // para que el notifier refresque auth y reintente.
          await _localDs.markFailed(
            item.uuid,
            'Auth failure at ${DateTime.now().toIso8601String()}',
          );
          debugPrint('SyncRepo: auth failure, aborting queue');
          throw SyncAuthException(successCount);

        case SyncExecutionResult.transientFailure:
          await _localDs.markFailed(
            item.uuid,
            'Transient failure at ${DateTime.now().toIso8601String()}',
          );
          break;
      }
    }

    // Limpiar items que excedieron reintentos
    final purged = await _localDs.purgeExhaustedItems();
    if (purged > 0) {
      debugPrint('SyncRepo: purged $purged exhausted items');
    }

    debugPrint(
      'SyncRepo: processed ${pending.length}, success: $successCount, '
      'permanent: $purgedByPermanent',
    );
    return successCount;
  }

  @override
  Future<int> getPendingCount() async {
    return await _localDs.getPendingCount();
  }

  @override
  Future<int> purgeExhaustedItems() async {
    return await _localDs.purgeExhaustedItems();
  }
}
