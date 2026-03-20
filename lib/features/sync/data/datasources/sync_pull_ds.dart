import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// DataSource remoto para PULL (Supabase → dispositivo).
///
/// Complementa a [SyncRemoteDataSource] que solo hace PUSH.
/// Descarga registros del servidor filtrados por user_id y opcionalmente
/// por updated_at > lastPullAt para delta syncs incrementales.
class SyncPullDataSource {
  final SupabaseClient _client;

  SyncPullDataSource(this._client);

  /// Tablas sincronizables y sus columnas de orden.
  static const _tables = [
    'transactions',
    'categories',
    'credit_cards',
    'credits',
    'budgets',
    'goals',
    'health_snapshots',
  ];

  /// Pull completo: descarga TODOS los registros del usuario.
  /// Se usa al primer login en un dispositivo nuevo.
  Future<Map<String, List<Map<String, dynamic>>>> pullAll(String userId) async {
    final result = <String, List<Map<String, dynamic>>>{};

    for (final table in _tables) {
      try {
        final data = await _client
            .from(table)
            .select()
            .eq('user_id', userId)
            .order('updated_at', ascending: false);

        result[table] = List<Map<String, dynamic>>.from(data);
        debugPrint('SyncPull: $table → ${result[table]!.length} registros');
      } catch (e) {
        debugPrint('SyncPull: error en $table → $e');
        result[table] = [];
      }
    }

    return result;
  }

  /// Delta pull: descarga solo registros modificados después de [since].
  /// Se usa en syncs incrementales (app resumed + internet).
  Future<Map<String, List<Map<String, dynamic>>>> pullDelta({
    required String userId,
    required DateTime since,
  }) async {
    final result = <String, List<Map<String, dynamic>>>{};
    final sinceIso = since.toUtc().toIso8601String();

    for (final table in _tables) {
      try {
        // health_snapshots no tienen updated_at, usan created_at
        final timeColumn =
            table == 'health_snapshots' ? 'created_at' : 'updated_at';

        final data = await _client
            .from(table)
            .select()
            .eq('user_id', userId)
            .gt(timeColumn, sinceIso)
            .order(timeColumn, ascending: false);

        result[table] = List<Map<String, dynamic>>.from(data);

        if (result[table]!.isNotEmpty) {
          debugPrint(
              'SyncPull delta: $table → ${result[table]!.length} nuevos');
        }
      } catch (e) {
        debugPrint('SyncPull delta: error en $table → $e');
        result[table] = [];
      }
    }

    return result;
  }

  /// Pull del perfil del usuario (tabla profiles, PK = user_id directo).
  Future<Map<String, dynamic>?> pullProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return data;
    } catch (e) {
      debugPrint('SyncPull: error en profile → $e');
      return null;
    }
  }
}