// test/helpers/isar_test_helper.dart
//
// ════════════════════════════════════════════════════════════════════════
// Helper de testing para abrir/cerrar instancias de Isar in-memory.
// ════════════════════════════════════════════════════════════════════════
//
// CONTEXTO:
//   Isar 3.x necesita binarios nativos (libisar.{so,dylib,dll}) para correr
//   en el host (CI o máquina local). En la app real, `isar_flutter_libs`
//   los provee vía Flutter plugin. En tests Dart-puros (`flutter test`)
//   ese plugin NO está disponible — Flutter ejecuta los tests en el VM
//   de Dart, no en un device.
//
//   La solución oficial documentada por Isar es:
//     `Isar.initializeIsarCore(download: true)`
//   La primera vez descarga el binario adecuado a `~/.dart-isar/` y lo
//   reutiliza en runs subsecuentes. NO requiere internet después de la
//   primera descarga.
//
// USO DESDE UN TEST:
//   ```dart
//   late Isar isar;
//
//   setUpAll(IsarTestHelper.initCore);
//
//   setUp(() async {
//     isar = await IsarTestHelper.openIsar();
//   });
//
//   tearDown(() async {
//     await IsarTestHelper.closeIsar(isar);
//   });
//   ```
//
// GARANTÍAS:
//   1. Cada test recibe una BD vacía y aislada (directorio único en tmp).
//   2. `closeIsar` borra el directorio físico — no contamina el FS entre
//      runs.
//   3. Schemas espejean exactamente los registrados en `isar_instance.dart`
//      de producción. Si agregas una colección a Isar, también agrégala
//      aquí o tus tests fallarán con "Schema not registered".
//
// ════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:beti_app/features/auth/data/models/user_model.dart';
import 'package:beti_app/features/budgets_goals/data/models/budget_model.dart';
import 'package:beti_app/features/budgets_goals/data/models/goal_model.dart';
import 'package:beti_app/features/budgets_goals/data/models/income_budget_model.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_model.dart';
import 'package:beti_app/features/financial_health/data/models/health_snapshot_model.dart';
import 'package:beti_app/features/notifications/data/models/notification_preferences_model.dart';
import 'package:beti_app/features/sync/data/models/sync_queue_model.dart';
import 'package:beti_app/features/transactions/data/models/category_model.dart';
import 'package:beti_app/features/transactions/data/models/transaction_model.dart';

/// Lista canónica de schemas — DEBE coincidir con `IsarInstance.initialize()`.
/// Si modificas uno, actualiza ambos lugares.
const _allSchemas = [
  UserModelSchema,
  TransactionModelSchema,
  CategoryModelSchema,
  HealthSnapshotModelSchema,
  CreditCardModelSchema,
  CreditModelSchema,
  BudgetModelSchema,
  IncomeBudgetModelSchema,
  GoalModelSchema,
  SyncQueueModelSchema,
  NotificationPreferencesModelSchema,
];

class IsarTestHelper {
  IsarTestHelper._();

  static bool _coreInitialized = false;

  /// Inicializa el core nativo de Isar. Llamar UNA vez por suite via
  /// `setUpAll(IsarTestHelper.initCore)`.
  ///
  /// La primera ejecución descarga el binario; las siguientes son no-op.
  /// Si ya hay una app de Flutter corriendo en el mismo proceso (poco
  /// común en `flutter test`) este método es seguro de ignorar.
  static Future<void> initCore() async {
    if (_coreInitialized) return;
    await Isar.initializeIsarCore(download: true);
    _coreInitialized = true;
  }

  /// Abre una instancia limpia de Isar en un directorio temporal único.
  ///
  /// El parámetro [name] permite que dos `openIsar()` en el mismo test
  /// no colisionen (Isar usa el name como discriminador de instancias
  /// dentro del proceso). Por defecto se genera uno único basado en
  /// timestamp + counter.
  static Future<Isar> openIsar({String? name}) async {
    final dir = await Directory.systemTemp.createTemp('beti_isar_test_');
    final instanceName = name ?? _uniqueName();

    return await Isar.open(
      _allSchemas,
      directory: dir.path,
      name: instanceName,
      inspector: false, // jamás en tests
    );
  }

  /// Cierra la instancia y borra su directorio físico.
  ///
  /// `deleteFromDisk: true` en `isar.close` libera el archivo de DB pero
  /// no siempre borra el directorio padre — lo eliminamos explícitamente
  /// para no dejar basura en `/tmp` entre runs largos.
  static Future<void> closeIsar(Isar isar) async {
    final path = isar.directory;
    await isar.close(deleteFromDisk: true);

    if (path != null) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {
          // Algunos OS bloquean directorios brevemente tras close.
          // No es crítico — systemTemp se limpia eventualmente.
        }
      }
    }
  }

  static int _counter = 0;
  static String _uniqueName() {
    _counter++;
    return 'beti_test_${DateTime.now().microsecondsSinceEpoch}_$_counter';
  }
}

/// Mock de `path_provider` para tests que necesiten `getApplicationDocumentsDirectory`.
///
/// Algunos servicios (ej: `IsarInstance.initialize`, ciertos data sources)
/// llaman a `path_provider` directamente. En tests este plugin no responde
/// porque no hay platform channels. Este mock retorna un directorio temp
/// para que esos servicios no exploten.
///
/// Uso:
/// ```dart
/// setUpAll(() {
///   PathProviderPlatform.instance = FakePathProviderPlatform();
/// });
/// ```
class FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final dir = await Directory.systemTemp.createTemp('beti_app_docs_');
    return dir.path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    final dir = await Directory.systemTemp.createTemp('beti_app_support_');
    return dir.path;
  }

  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }
}
