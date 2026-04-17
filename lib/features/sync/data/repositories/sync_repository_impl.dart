import 'package:flutter/foundation.dart';
import 'package:beti_app/core/utils/uuid_generator.dart';
import 'package:beti_app/features/sync/data/datasources/sync_local_ds.dart';
import 'package:beti_app/features/sync/data/datasources/sync_remote_ds.dart';
import 'package:beti_app/features/sync/data/models/sync_queue_model.dart';
import 'package:beti_app/features/sync/domain/repositories/sync_repository.dart';

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

    for (final item in pending) {
      final success = await _remoteDs.executeOperation(item);

      if (success) {
        await _localDs.removeItem(item.uuid);
        successCount++;
      } else {
        await _localDs.markFailed(
          item.uuid,
          'Sync failed at ${DateTime.now().toIso8601String()}',
        );
      }
    }

    // Limpiar items que excedieron reintentos
    final purged = await _localDs.purgeExhaustedItems();
    if (purged > 0) {
      debugPrint('SyncRepo: purged $purged exhausted items');
    }

    debugPrint('SyncRepo: processed ${pending.length}, success: $successCount');
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
