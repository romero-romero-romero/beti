import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:beti_app/features/auth/data/models/user_model.dart';
import 'package:beti_app/features/transactions/data/models/transaction_model.dart';
import 'package:beti_app/features/transactions/data/models/category_model.dart';
import 'package:beti_app/features/financial_health/data/models/health_snapshot_model.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_model.dart';
import 'package:beti_app/features/budgets_goals/data/models/budget_model.dart';
import 'package:beti_app/features/budgets_goals/data/models/goal_model.dart';
import 'package:beti_app/features/sync/data/models/sync_queue_model.dart';
import 'package:beti_app/features/budgets_goals/data/models/income_budget_model.dart';

/// Singleton que gestiona la instancia única de Isar Database.
///
/// Se inicializa UNA vez en main.dart antes de runApp().
/// Todos los DataSources locales reciben esta instancia vía Riverpod.
class IsarInstance {
  static Isar? _instance;

  IsarInstance._();

  /// Retorna la instancia de Isar. Lanza si no fue inicializada.
  static Isar get instance {
    if (_instance == null) {
      throw StateError(
        'Isar no ha sido inicializado. '
        'Llama a IsarInstance.initialize() en main() antes de runApp().',
      );
    }
    return _instance!;
  }

  /// Inicializa Isar con TODOS los schemas de la app.
  ///
  /// Uso en main.dart:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await IsarInstance.initialize();
  ///   runApp(const ProviderScope(child: BettyApp()));
  /// }
  /// ```
  static Future<Isar> initialize() async {
    if (_instance != null) return _instance!;

    final dir = await getApplicationDocumentsDirectory();

    _instance = await Isar.open(
      [
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
      ],
      directory: dir.path,
      name: 'betty_db',
      inspector: !const bool.fromEnvironment('dart.vm.product'),
    );

    return _instance!;
  }

  /// Cierra la instancia (útil en tests).
  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}
