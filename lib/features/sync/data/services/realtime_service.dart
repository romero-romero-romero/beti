import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:betty_app/features/sync/data/services/sync_merge_service.dart';

/// Servicio de Realtime: escucha cambios en PostgreSQL via Supabase Realtime
/// y los mergea en Isar instantáneamente.
///
/// Esto permite que si el usuario crea una transacción en el Dispositivo A,
/// el Dispositivo B la reciba en segundos sin esperar al próximo ciclo de pull.
///
/// Se conecta al hacer login exitoso y se desconecta al hacer logout.
/// Solo escucha cambios del propio user_id (filtrado por RLS en el servidor).
class RealtimeService {
  final SupabaseClient _client;
  final SyncMergeService _mergeService;

  RealtimeChannel? _channel;
  bool _isSubscribed = false;

  /// Tablas a escuchar (las mismas que habilitamos en supabase_realtime).
  static const _tables = [
    'transactions',
    'categories',
    'credit_cards',
    'credits',
    'budgets',
    'goals',
    'health_snapshots',
  ];

  RealtimeService({
    required SupabaseClient client,
    required SyncMergeService mergeService,
  })  : _client = client,
        _mergeService = mergeService;

  /// Inicia la suscripción a cambios en tiempo real.
  /// Llamar después del login exitoso.
  void subscribe(String userId) {
    if (_isSubscribed) return;

    _channel = _client.channel('betty-sync-$userId');

    for (final table in _tables) {
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) => _handleChange(table, payload),
      );
    }

    _channel!.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isSubscribed = true;
        debugPrint('Realtime: suscrito a cambios del usuario');
      } else if (status == RealtimeSubscribeStatus.closed) {
        _isSubscribed = false;
        debugPrint('Realtime: canal cerrado');
      } else if (error != null) {
        debugPrint('Realtime: error → $error');
      }
    });
  }

  /// Maneja un cambio individual recibido del servidor.
  Future<void> _handleChange(
    String table,
    PostgresChangePayload payload,
  ) async {
    try {
      final eventType = payload.eventType;

      if (eventType == PostgresChangeEvent.delete) {
        await _handleDelete(table, payload.oldRecord);
        return;
      }

      // INSERT o UPDATE → merge el registro nuevo/actualizado
      final newRecord = payload.newRecord;
      if (newRecord.isEmpty) return;

      debugPrint('Realtime [$table]: ${eventType.name} → ${newRecord['uuid']}');

      await _mergeService.mergeAll({
        table: [newRecord],
      });
    } catch (e) {
      debugPrint('Realtime: error procesando cambio en $table → $e');
    }
  }

  /// Maneja un DELETE propagado desde otro dispositivo.
  Future<void> _handleDelete(
    String table,
    Map<String, dynamic> oldRecord,
  ) async {
    if (oldRecord.isEmpty) return;

    final uuid = oldRecord['uuid'] as String?;
    if (uuid == null) return;

    debugPrint('Realtime [$table]: delete → $uuid');

    // Para transactions usamos soft-delete (is_deleted = true).
    // Para otras tablas, el merge ya maneja la lógica de actualización.
    if (table == 'transactions') {
      await _mergeService.mergeAll({
        'transactions': [
          {
            ...oldRecord,
            'is_deleted': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      });
    }
    // Otras tablas: el registro se eliminó del servidor.
    // En Isar lo marcamos como no activo si tiene ese campo.
    // Por ahora no eliminamos físicamente — el delta pull lo resolverá.
  }

  /// Detiene la suscripción. Llamar al hacer logout.
  Future<void> unsubscribe() async {
    if (_channel != null) {
      await _client.removeChannel(_channel!);
      _channel = null;
      _isSubscribed = false;
      debugPrint('Realtime: desuscrito');
    }
  }

  /// Indica si hay una suscripción activa.
  bool get isSubscribed => _isSubscribed;
}