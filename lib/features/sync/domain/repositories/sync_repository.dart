import 'package:beti_app/features/sync/data/models/sync_queue_model.dart';

/// Contrato del repositorio de sincronización.
abstract class SyncRepository {
  /// Encola un cambio local para sincronización posterior.
  Future<void> enqueueChange({
    required String userId,
    required String targetCollection,
    required String targetUuid,
    required SyncOperation operation,
    required String payload,
    String? attachmentPath,
  });

  /// Procesa toda la cola de pendientes.
  /// Retorna el número de items sincronizados exitosamente.
  Future<int> processQueue();

  /// Obtiene la cantidad de items pendientes.
  Future<int> getPendingCount();

  /// Limpia items que excedieron el máximo de reintentos.
  Future<int> purgeExhaustedItems();
}
