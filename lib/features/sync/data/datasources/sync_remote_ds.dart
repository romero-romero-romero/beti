import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:betty_app/features/sync/data/models/sync_queue_model.dart';

/// DataSource remoto para sincronización.
/// Ejecuta las operaciones CRUD contra las tablas de Supabase.
class SyncRemoteDataSource {
  final SupabaseClient _client;

  SyncRemoteDataSource(this._client);

  /// Ejecuta una operación de la cola contra Supabase.
  /// Retorna true si fue exitosa, false si falló.
  Future<bool> executeOperation(SyncQueueModel item) async {
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

      // Si hay imagen adjunta, subirla a Storage
      if (item.attachmentPath != null && item.attachmentPath!.isNotEmpty) {
        await _uploadAttachment(
          userId: item.userId,
          targetUuid: item.targetUuid,
          filePath: item.attachmentPath!,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Sync operation failed for ${item.targetCollection}/${item.targetUuid}: $e');
      return false;
    }
  }

  /// Sube una imagen de ticket a Supabase Storage.
  Future<String?> _uploadAttachment({
    required String userId,
    required String targetUuid,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final storagePath = '$userId/$targetUuid.jpg';
      await _client.storage
          .from('ticket-images')
          .upload(storagePath, file);

      return storagePath;
    } catch (e) {
      debugPrint('Attachment upload failed: $e');
      return null;
    }
  }
}
