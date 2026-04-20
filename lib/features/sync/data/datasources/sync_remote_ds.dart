import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beti_app/features/sync/data/models/sync_queue_model.dart';

/// Resultado de ejecutar una operación de sync.
enum SyncExecutionResult {
  /// Operación exitosa.
  success,

  /// Error transitorio (red, 5xx, timeout). Reintentable.
  transientFailure,

  /// Error permanente (4xx excepto 401: constraint, not found, bad payload).
  /// No tiene sentido reintentar — purgar el item.
  permanentFailure,

  /// Token inválido/expirado (401). Abortar la cola completa: los demás
  /// items fallarán igual. A12 se encargará del refresh + retry.
  authFailure,
}

/// DataSource remoto para sincronización.
/// Ejecuta las operaciones CRUD contra las tablas de Supabase.
class SyncRemoteDataSource {
  final SupabaseClient _client;

  SyncRemoteDataSource(this._client);

  /// Ejecuta una operación de la cola contra Supabase.
  /// Retorna un [SyncExecutionResult] clasificando el outcome.
  Future<SyncExecutionResult> executeOperation(SyncQueueModel item) async {
    try {
      final data = jsonDecode(item.payload) as Map<String, dynamic>;

      switch (item.operation) {
        case SyncOperation.create:
          await _client.from(item.targetCollection).upsert(data);
          break;
        case SyncOperation.update:
          await _client
              .from(item.targetCollection)
              .update(data)
              .eq('uuid', item.targetUuid);
          break;
        case SyncOperation.delete:
          await _client
              .from(item.targetCollection)
              .delete()
              .eq('uuid', item.targetUuid);
          break;
      }

      if (item.attachmentPath != null && item.attachmentPath!.isNotEmpty) {
        await _uploadAttachment(
          userId: item.userId,
          targetUuid: item.targetUuid,
          filePath: item.attachmentPath!,
        );
      }

      return SyncExecutionResult.success;
    } on PostgrestException catch (e) {
      // 401 => auth failure; 4xx => permanente; 5xx => transient.
      return _classifyHttpError(e.code);
    } on StorageException catch (e) {
      return _classifyHttpError(e.statusCode);
    } on AuthException {
      return SyncExecutionResult.authFailure;
    } on SocketException {
      return SyncExecutionResult.transientFailure;
    } catch (_) {
      // Desconocido — asumir transient; retryCount limpiará eventualmente.
      return SyncExecutionResult.transientFailure;
    }
  }

  /// Clasifica un status HTTP/error code en [SyncExecutionResult].
  SyncExecutionResult _classifyHttpError(String? code) {
    if (code == null) return SyncExecutionResult.transientFailure;
    final status = int.tryParse(code);
    if (status == null) return SyncExecutionResult.transientFailure;

    if (status == 401 || status == 403) return SyncExecutionResult.authFailure;
    if (status >= 400 && status < 500) {
      return SyncExecutionResult.permanentFailure;
    }
    if (status >= 500) return SyncExecutionResult.transientFailure;
    return SyncExecutionResult.transientFailure;
  }

  /// Sube una imagen de ticket a Supabase Storage.
  Future<String?> _uploadAttachment({
    required String userId,
    required String targetUuid,
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final storagePath = '$userId/$targetUuid.jpg';
    await _client.storage.from('ticket-images').upload(storagePath, file);
    return storagePath;
  }
}
