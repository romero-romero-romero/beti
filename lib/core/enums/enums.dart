/// Enums canónicos de Betty.
///
/// NOTA: Los modelos Isar (@collection) declaran sus propios enums locales
/// porque isar_generator requiere que los enums estén en el mismo archivo
/// o en su part file. Estos enums en core/ son la referencia canónica
/// que usan los Use Cases, Providers y la UI.
///
/// Mapeo Isar ↔ Core:
///   UserCurrency       ↔ CurrencyPreference
///   UserSyncStatus     ↔ SyncStatus
///   TxType             ↔ TransactionType
///   TxCategory         ↔ CategoryType
///   TxInputMethod      ↔ InputMethod
///   TxSyncStatus       ↔ SyncStatus
///   CatSyncStatus      ↔ SyncStatus
///   SnapshotHealthLevel↔ HealthLevel
///   SnapshotSyncStatus ↔ SyncStatus
///   CcNetwork          ↔ CardNetwork
///   CcSyncStatus       ↔ SyncStatus
///   CreditSyncStatus   ↔ SyncStatus
///   BudgetSyncStatus   ↔ SyncStatus
///   GoalSyncStatus     ↔ SyncStatus
library;

export 'card_network.dart';
export 'category_type.dart';
export 'currency_preference.dart';
export 'health_level.dart';
export 'input_method.dart';
export 'sync_status.dart';
export 'transaction_type.dart';
