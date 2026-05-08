// test/features/sync/sync_remote_ds_classify_error_test.dart
//
// ════════════════════════════════════════════════════════════════════════
// SyncRemoteDataSource — clasificación de errores HTTP/PostgREST.
// ════════════════════════════════════════════════════════════════════════
//
// PIEZA CRÍTICA: Esta lógica decide si un fallo cuesta un retry, descarta
// el item, o aborta toda la cola por re-auth. Una mala clasificación =
// loop infinito de retries (drena batería) o pérdida silenciosa de datos.
//
// REGLAS A VALIDAR:
//
// | Code           | Resultado            |
// |----------------|----------------------|
// | null           | transientFailure     |
// | "PGRST*"       | permanentFailure     |
// | "401" / "403"  | authFailure          |
// | "400-499"      | permanentFailure     |
// | "500-599"      | transientFailure     |
// | no numérico    | transientFailure     |
//
// REQUISITO PREVIO:
//   En `lib/features/sync/data/datasources/sync_remote_ds.dart`, agregar
//   al final de la clase SyncRemoteDataSource:
//
//     @visibleForTesting
//     SyncExecutionResult classifyHttpErrorForTesting(String? code) =>
//         _classifyHttpError(code);
//
//   También requiere `import 'package:flutter/foundation.dart';` si no
//   está presente.
//
// ════════════════════════════════════════════════════════════════════════

import 'package:beti_app/features/sync/data/datasources/sync_remote_ds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // No necesitamos auth real ni red — solo invocamos el método puro.
  // Inicializamos Supabase con valores dummy para poder construir el cliente.
  late SyncRemoteDataSource ds;

  setUpAll(() {
    // Construimos un SupabaseClient mínimo con URL/key dummy.
    // El cliente nunca hará una request en estos tests; sólo necesita
    // existir para el constructor de SyncRemoteDataSource.
    final client = SupabaseClient(
      'https://dummy.supabase.co',
      'dummy-anon-key',
    );
    ds = SyncRemoteDataSource(client);
  });

  // ══════════════════════════════════════════════════════════════════════
  // NULL → transient
  // ══════════════════════════════════════════════════════════════════════

  group('null code', () {
    test('null → transientFailure', () {
      expect(
        ds.classifyHttpErrorForTesting(null),
        SyncExecutionResult.transientFailure,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // PGRST* → permanent (errores de schema/constraint)
  // ══════════════════════════════════════════════════════════════════════

  group('PostgREST codes', () {
    test('PGRST204 (column missing) → permanentFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('PGRST204'),
        SyncExecutionResult.permanentFailure,
      );
    });

    test('PGRST116 (no rows) → permanentFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('PGRST116'),
        SyncExecutionResult.permanentFailure,
      );
    });

    test('PGRST200 (parse error) → permanentFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('PGRST200'),
        SyncExecutionResult.permanentFailure,
      );
    });

    test('cualquier código PGRST* arbitrario → permanentFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('PGRST999'),
        SyncExecutionResult.permanentFailure,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // 401 / 403 → auth
  // ══════════════════════════════════════════════════════════════════════

  group('Auth codes', () {
    test('401 (unauthorized) → authFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('401'),
        SyncExecutionResult.authFailure,
      );
    });

    test('403 (forbidden) → authFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('403'),
        SyncExecutionResult.authFailure,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // 400-499 (excepto 401/403) → permanent
  // ══════════════════════════════════════════════════════════════════════

  group('4xx client errors', () {
    test('400 (bad request) → permanentFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('400'),
        SyncExecutionResult.permanentFailure,
      );
    });

    test('404 (not found) → permanentFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('404'),
        SyncExecutionResult.permanentFailure,
      );
    });

    test('409 (conflict) → permanentFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('409'),
        SyncExecutionResult.permanentFailure,
      );
    });

    test('422 (unprocessable) → permanentFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('422'),
        SyncExecutionResult.permanentFailure,
      );
    });

    test('499 (límite alto del rango) → permanentFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('499'),
        SyncExecutionResult.permanentFailure,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // 5xx → transient (servidor caído, reintentables)
  // ══════════════════════════════════════════════════════════════════════

  group('5xx server errors', () {
    test('500 (internal server error) → transientFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('500'),
        SyncExecutionResult.transientFailure,
      );
    });

    test('502 (bad gateway) → transientFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('502'),
        SyncExecutionResult.transientFailure,
      );
    });

    test('503 (service unavailable) → transientFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('503'),
        SyncExecutionResult.transientFailure,
      );
    });

    test('504 (gateway timeout) → transientFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('504'),
        SyncExecutionResult.transientFailure,
      );
    });

    test('599 (límite alto del rango) → transientFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('599'),
        SyncExecutionResult.transientFailure,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Códigos no numéricos / inesperados
  // ══════════════════════════════════════════════════════════════════════

  group('Códigos malformados', () {
    test('string vacío → transientFailure (int.tryParse falla)', () {
      expect(
        ds.classifyHttpErrorForTesting(''),
        SyncExecutionResult.transientFailure,
      );
    });

    test('string aleatorio → transientFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('???'),
        SyncExecutionResult.transientFailure,
      );
    });

    test('número fuera de rango (300) → transientFailure', () {
      // No matchea 401/403, no es 4xx, no es 5xx → cae al default.
      expect(
        ds.classifyHttpErrorForTesting('300'),
        SyncExecutionResult.transientFailure,
      );
    });

    test('número negativo → transientFailure', () {
      expect(
        ds.classifyHttpErrorForTesting('-1'),
        SyncExecutionResult.transientFailure,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Boundary tests — límites de los rangos
  // ══════════════════════════════════════════════════════════════════════

  group('Límites de rango', () {
    test('399 → transientFailure (no es 4xx aún)', () {
      expect(
        ds.classifyHttpErrorForTesting('399'),
        SyncExecutionResult.transientFailure,
      );
    });

    test('600 → transientFailure (fuera del rango HTTP)', () {
      expect(
        ds.classifyHttpErrorForTesting('600'),
        SyncExecutionResult.transientFailure,
      );
    });
  });
}