import 'package:isar/isar.dart';

part 'sync_queue_model.g.dart';

/// Cola de sincronización con Supabase.
///
/// PIEZA CRÍTICA DE LA ARQUITECTURA OFFLINE-FIRST.
///
/// Flujo:
/// 1. Usuario crea/edita/elimina algo → se guarda en Isar.
/// 2. Simultáneamente se encola un SyncQueueModel con el payload.
/// 3. Al detectar internet (AppLifecycleState.resumed + connectivity),
///    SyncProvider procesa la cola en orden FIFO.
/// 4. Éxito → marca syncStatus = synced en el modelo original, elimina de cola.
/// 5. Fallo → incrementa retryCount, reintenta en próximo ciclo.
@collection
class SyncQueueModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  @Index()
  late String userId;

  /// Nombre de la colección afectada (ej: "transactions", "credit_cards").
  @Index()
  late String targetCollection;

  /// UUID del registro afectado en Isar.
  late String targetUuid;

  @Enumerated(EnumType.name)
  late SyncOperation operation;

  /// Payload JSON serializado del registro completo.
  late String payload;

  /// Ruta local de archivo adjunto a subir a Supabase Storage.
  String? attachmentPath;

  @Index()
  late DateTime enqueuedAt;

  late int retryCount;

  String? lastError;

  DateTime? lastAttemptAt;

  /// Prioridad (menor = más urgente). Deletes: 0, Creates: 1, Updates: 2.
  @Index()
  late int priority;
}

/// Tipo de operación en la cola de sync.
enum SyncOperation {
  create,
  update,
  delete,
}
