import 'package:betty_app/core/enums/card_network.dart';
import 'package:betty_app/core/enums/category_type.dart';
import 'package:betty_app/core/enums/currency_preference.dart';
import 'package:betty_app/core/enums/health_level.dart';
import 'package:betty_app/core/enums/input_method.dart';
import 'package:betty_app/core/enums/sync_status.dart';
import 'package:betty_app/core/enums/transaction_type.dart';

import 'package:betty_app/features/auth/data/models/user_model.dart';
import 'package:betty_app/features/budgets_goals/data/models/budget_model.dart';
import 'package:betty_app/features/budgets_goals/data/models/goal_model.dart';
import 'package:betty_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:betty_app/features/cards_credits/data/models/credit_model.dart';
import 'package:betty_app/features/financial_health/data/models/health_snapshot_model.dart';
import 'package:betty_app/features/transactions/data/models/category_model.dart';
import 'package:betty_app/features/transactions/data/models/transaction_model.dart';

// ═══════════════════════════════════════════════════════════
// Mapeo centralizado: Enums Canónicos (core/) ↔ Enums Isar
//
// Estrategia: extensiones bidireccionales usando .name matching.
// Cada par tiene .toIsar() y .toCanonical() (o .toCore()).
//
// Uso en Repositories:
//   model.type = entity.type.toIsar();          // Core → Isar
//   entity.type = model.type.toCanonical();     // Isar → Core
// ═══════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────
// TransactionType ↔ TxType
// ─────────────────────────────────────────────────────────

extension TransactionTypeToIsar on TransactionType {
  TxType toIsar() => TxType.values.byName(name);
}

extension TxTypeToCanonical on TxType {
  TransactionType toCanonical() => TransactionType.values.byName(name);
}

// ─────────────────────────────────────────────────────────
// CategoryType ↔ TxCategory
// ─────────────────────────────────────────────────────────

extension CategoryTypeToIsar on CategoryType {
  TxCategory toIsar() => TxCategory.values.byName(name);
}

extension TxCategoryToCanonical on TxCategory {
  CategoryType toCanonical() => CategoryType.values.byName(name);
}

// ─────────────────────────────────────────────────────────
// InputMethod ↔ TxInputMethod
// ─────────────────────────────────────────────────────────

extension InputMethodToIsar on InputMethod {
  TxInputMethod toIsar() => TxInputMethod.values.byName(name);
}

extension TxInputMethodToCanonical on TxInputMethod {
  InputMethod toCanonical() => InputMethod.values.byName(name);
}

// ─────────────────────────────────────────────────────────
// CardNetwork ↔ CcNetwork
// ─────────────────────────────────────────────────────────

extension CardNetworkToIsar on CardNetwork {
  CcNetwork toIsar() => CcNetwork.values.byName(name);
}

extension CcNetworkToCanonical on CcNetwork {
  CardNetwork toCanonical() => CardNetwork.values.byName(name);
}

// ─────────────────────────────────────────────────────────
// HealthLevel ↔ SnapshotHealthLevel
// ─────────────────────────────────────────────────────────

extension HealthLevelToIsar on HealthLevel {
  SnapshotHealthLevel toIsar() => SnapshotHealthLevel.values.byName(name);
}

extension SnapshotHealthLevelToCanonical on SnapshotHealthLevel {
  HealthLevel toCanonical() => HealthLevel.values.byName(name);
}

// ─────────────────────────────────────────────────────────
// CurrencyPreference ↔ UserCurrency
// ─────────────────────────────────────────────────────────

extension CurrencyPreferenceToIsar on CurrencyPreference {
  UserCurrency toIsar() => UserCurrency.values.byName(name);
}

extension UserCurrencyToCanonical on UserCurrency {
  CurrencyPreference toCanonical() => CurrencyPreference.values.byName(name);
}

// ─────────────────────────────────────────────────────────
// SyncStatus ↔ Todos los *SyncStatus de Isar
//
// Cada modelo Isar tiene su propio SyncStatus enum con prefijo.
// Las extensiones son simétricas: mismos valores, distinto tipo.
// ─────────────────────────────────────────────────────────

extension SyncStatusToTx on SyncStatus {
  TxSyncStatus toTxIsar() => TxSyncStatus.values.byName(name);
}

extension TxSyncStatusToCanonical on TxSyncStatus {
  SyncStatus toCanonical() => SyncStatus.values.byName(name);
}

extension SyncStatusToCc on SyncStatus {
  CcSyncStatus toCcIsar() => CcSyncStatus.values.byName(name);
}

extension CcSyncStatusToCanonical on CcSyncStatus {
  SyncStatus toCanonical() => SyncStatus.values.byName(name);
}

extension SyncStatusToCredit on SyncStatus {
  CreditSyncStatus toCreditIsar() => CreditSyncStatus.values.byName(name);
}

extension CreditSyncStatusToCanonical on CreditSyncStatus {
  SyncStatus toCanonical() => SyncStatus.values.byName(name);
}

extension SyncStatusToBudget on SyncStatus {
  BudgetSyncStatus toBudgetIsar() => BudgetSyncStatus.values.byName(name);
}

extension BudgetSyncStatusToCanonical on BudgetSyncStatus {
  SyncStatus toCanonical() => SyncStatus.values.byName(name);
}

extension SyncStatusToGoal on SyncStatus {
  GoalSyncStatus toGoalIsar() => GoalSyncStatus.values.byName(name);
}

extension GoalSyncStatusToCanonical on GoalSyncStatus {
  SyncStatus toCanonical() => SyncStatus.values.byName(name);
}

extension SyncStatusToCat on SyncStatus {
  CatSyncStatus toCatIsar() => CatSyncStatus.values.byName(name);
}

extension CatSyncStatusToCanonical on CatSyncStatus {
  SyncStatus toCanonical() => SyncStatus.values.byName(name);
}

extension SyncStatusToSnapshot on SyncStatus {
  SnapshotSyncStatus toSnapshotIsar() =>
      SnapshotSyncStatus.values.byName(name);
}

extension SnapshotSyncStatusToCanonical on SnapshotSyncStatus {
  SyncStatus toCanonical() => SyncStatus.values.byName(name);
}

extension SyncStatusToUser on SyncStatus {
  UserSyncStatus toUserIsar() => UserSyncStatus.values.byName(name);
}

extension UserSyncStatusToCanonical on UserSyncStatus {
  SyncStatus toCanonical() => SyncStatus.values.byName(name);
}
