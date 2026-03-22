import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:betty_app/features/transactions/data/models/transaction_model.dart';
import 'package:betty_app/features/transactions/data/models/category_model.dart';
import 'package:betty_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:betty_app/features/cards_credits/data/models/credit_model.dart';
import 'package:betty_app/features/budgets_goals/data/models/budget_model.dart';
import 'package:betty_app/features/budgets_goals/data/models/goal_model.dart';
import 'package:betty_app/features/financial_health/data/models/health_snapshot_model.dart';
import 'package:betty_app/features/auth/data/models/user_model.dart';

/// Resultado de una operación de merge.
class MergeResult {
  final int inserted;
  final int updated;
  final int skipped;

  const MergeResult({
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
  });

  MergeResult operator +(MergeResult other) => MergeResult(
        inserted: inserted + other.inserted,
        updated: updated + other.updated,
        skipped: skipped + other.skipped,
      );

  @override
  String toString() =>
      'MergeResult(inserted: $inserted, updated: $updated, skipped: $skipped)';
}

/// Servicio de merge: integra datos remotos (Supabase) con Isar local.
///
/// Estrategia: Last-Write-Wins basada en [updated_at].
/// - Si el uuid NO existe en Isar → INSERT.
/// - Si el uuid existe y remote.updated_at > local.updated_at → UPDATE.
/// - Si el uuid existe y remote.updated_at <= local.updated_at → SKIP.
///
/// Los registros locales con syncStatus=pending NO se sobreescriben
/// (tienen cambios locales que aún no se han pusheado).
class SyncMergeService {
  final Isar _isar;

  SyncMergeService(this._isar);

  /// Procesa todos los datos descargados del pull.
  Future<MergeResult> mergeAll(
      Map<String, List<Map<String, dynamic>>> remoteData) async {
    var total = const MergeResult();

    for (final entry in remoteData.entries) {
      final table = entry.key;
      final rows = entry.value;

      if (rows.isEmpty) continue;

      final result = await _mergeTable(table, rows);
      total = total + result;
      debugPrint('Merge [$table]: $result');
    }

    debugPrint('Merge total: $total');
    return total;
  }

  Future<MergeResult> _mergeTable(
      String table, List<Map<String, dynamic>> rows) async {
    return switch (table) {
      'transactions' => _mergeTransactions(rows),
      'categories' => _mergeCategories(rows),
      'credit_cards' => _mergeCreditCards(rows),
      'credits' => _mergeCredits(rows),
      'budgets' => _mergeBudgets(rows),
      'goals' => _mergeGoals(rows),
      'health_snapshots' => _mergeHealthSnapshots(rows),
      _ => Future.value(const MergeResult()),
    };
  }

  // ─────────────────────────────────────────────────────────
  // TRANSACTIONS
  // ─────────────────────────────────────────────────────────
  Future<MergeResult> _mergeTransactions(
      List<Map<String, dynamic>> rows) async {
    int inserted = 0, updated = 0, skipped = 0;

    await _isar.writeTxn(() async {
      for (final row in rows) {
        final uuid = row['uuid'] as String;
        final remoteUpdatedAt = DateTime.parse(row['updated_at'] as String);
        final remoteIsDeleted = row['is_deleted'] as bool? ?? false;

        final local = await _isar.transactionModels
            .filter()
            .uuidEqualTo(uuid)
            .findFirst();

        if (local == null) {
          if (!remoteIsDeleted) {
            await _isar.transactionModels.put(_mapTransaction(row));
            inserted++;
          } else {
            skipped++;
          }
        } else if (remoteIsDeleted) {
          // Delete siempre gana
          final merged = _mapTransaction(row)..id = local.id;
          await _isar.transactionModels.put(merged);
          updated++;
        } else if (local.syncStatus == TxSyncStatus.pending) {
          skipped++;
        } else if (remoteUpdatedAt.isAfter(local.updatedAt)) {
          final merged = _mapTransaction(row)..id = local.id;
          await _isar.transactionModels.put(merged);
          updated++;
        } else {
          skipped++;
        }
      }
    });

    return MergeResult(inserted: inserted, updated: updated, skipped: skipped);
  }

  TransactionModel _mapTransaction(Map<String, dynamic> row) {
    return TransactionModel()
      ..uuid = row['uuid'] as String
      ..userId = row['user_id'] as String
      ..type = TxType.values.byName(row['type'] as String)
      ..amount = (row['amount'] as num).toDouble()
      ..description = (row['description'] as String?) ?? ''
      ..category = TxCategory.values.byName(row['category'] as String)
      ..categoryAutoAssigned = row['category_auto_assigned'] as bool? ?? false
      ..inputMethod = TxInputMethod.values
          .byName(row['input_method'] as String? ?? 'manual')
      ..transactionDate = DateTime.parse(row['transaction_date'] as String)
      ..ticketImagePath = row['ticket_image_path'] as String?
      ..rawInputText = row['raw_input_text'] as String?
      ..creditCardUuid = row['credit_card_uuid'] as String?
      ..notes = row['notes'] as String?
      ..isDeleted = row['is_deleted'] as bool? ?? false
      ..createdAt = DateTime.parse(row['created_at'] as String)
      ..updatedAt = DateTime.parse(row['updated_at'] as String)
      ..syncStatus = TxSyncStatus.synced;
  }

  // ─────────────────────────────────────────────────────────
  // CATEGORIES
  // ─────────────────────────────────────────────────────────
  Future<MergeResult> _mergeCategories(List<Map<String, dynamic>> rows) async {
    int inserted = 0, updated = 0, skipped = 0;

    await _isar.writeTxn(() async {
      for (final row in rows) {
        final uuid = row['uuid'] as String;
        final remoteUpdatedAt = DateTime.parse(row['updated_at'] as String);

        final local =
            await _isar.categoryModels.filter().uuidEqualTo(uuid).findFirst();

        if (local == null) {
          await _isar.categoryModels.put(_mapCategory(row));
          inserted++;
        } else if (local.syncStatus == CatSyncStatus.pending) {
          skipped++;
        } else if (remoteUpdatedAt.isAfter(local.updatedAt)) {
          final merged = _mapCategory(row)..id = local.id;
          await _isar.categoryModels.put(merged);
          updated++;
        } else {
          skipped++;
        }
      }
    });

    return MergeResult(inserted: inserted, updated: updated, skipped: skipped);
  }

  CategoryModel _mapCategory(Map<String, dynamic> row) {
    return CategoryModel()
      ..uuid = row['uuid'] as String
      ..userId = row['user_id'] as String
      ..name = row['name'] as String
      ..parentCategoryKey = row['parent_category_key'] as String
      ..icon = row['icon'] as String?
      ..keywords = List<String>.from(row['keywords'] ?? [])
      ..isSystem = row['is_system'] as bool? ?? false
      ..isIncome = row['is_income'] as bool? ?? false
      ..sortOrder = row['sort_order'] as int? ?? 0
      ..createdAt = DateTime.parse(row['created_at'] as String)
      ..updatedAt = DateTime.parse(row['updated_at'] as String)
      ..syncStatus = CatSyncStatus.synced;
  }

  // ─────────────────────────────────────────────────────────
  // CREDIT CARDS
  // ─────────────────────────────────────────────────────────
  Future<MergeResult> _mergeCreditCards(List<Map<String, dynamic>> rows) async {
    int inserted = 0, updated = 0, skipped = 0;

    await _isar.writeTxn(() async {
      for (final row in rows) {
        final uuid = row['uuid'] as String;
        final remoteUpdatedAt = DateTime.parse(row['updated_at'] as String);
        final remoteIsActive = row['is_active'] as bool? ?? true;

        final local =
            await _isar.creditCardModels.filter().uuidEqualTo(uuid).findFirst();

        if (local == null) {
          // Solo insertar si está activo (no traer tarjetas ya eliminadas)
          if (remoteIsActive) {
            await _isar.creditCardModels.put(_mapCreditCard(row));
            inserted++;
          } else {
            skipped++;
          }
        } else if (!remoteIsActive) {
          // Delete siempre gana — propagar sin importar syncStatus
          final merged = _mapCreditCard(row)..id = local.id;
          await _isar.creditCardModels.put(merged);
          updated++;
        } else if (local.syncStatus == CcSyncStatus.pending) {
          skipped++;
        } else if (remoteUpdatedAt.isAfter(local.updatedAt)) {
          final merged = _mapCreditCard(row)..id = local.id;
          await _isar.creditCardModels.put(merged);
          updated++;
        } else {
          skipped++;
        }
      }
    });

    return MergeResult(inserted: inserted, updated: updated, skipped: skipped);
  }

  CreditCardModel _mapCreditCard(Map<String, dynamic> row) {
    return CreditCardModel()
      ..uuid = row['uuid'] as String
      ..userId = row['user_id'] as String
      ..name = row['name'] as String
      ..lastFourDigits = row['last_four_digits'] as String?
      ..network = CcNetwork.values.byName(row['network'] as String? ?? 'other')
      ..creditLimit = (row['credit_limit'] as num?)?.toDouble() ?? 0
      ..currentBalance = (row['current_balance'] as num?)?.toDouble() ?? 0
      ..availableCredit = (row['available_credit'] as num?)?.toDouble() ?? 0
      ..cutOffDay = row['cut_off_day'] as int
      ..paymentDueDay = row['payment_due_day'] as int
      ..nextCutOffDate = _parseNullableDate(row['next_cut_off_date'])
      ..nextPaymentDueDate = _parseNullableDate(row['next_payment_due_date'])
      ..alertsEnabled = row['alerts_enabled'] as bool? ?? true
      ..belvoLinkId = row['belvo_link_id'] as String?
      ..belvoAccountId = row['belvo_account_id'] as String?
      ..lastBelvoSyncAt = _parseNullableDate(row['last_belvo_sync_at'])
      ..isActive = row['is_active'] as bool? ?? true
      ..createdAt = DateTime.parse(row['created_at'] as String)
      ..updatedAt = DateTime.parse(row['updated_at'] as String)
      ..syncStatus = CcSyncStatus.synced;
  }

  // ─────────────────────────────────────────────────────────
  // CREDITS
  // ─────────────────────────────────────────────────────────
  Future<MergeResult> _mergeCredits(List<Map<String, dynamic>> rows) async {
    int inserted = 0, updated = 0, skipped = 0;

    await _isar.writeTxn(() async {
      for (final row in rows) {
        final uuid = row['uuid'] as String;
        final remoteUpdatedAt = DateTime.parse(row['updated_at'] as String);
        final remoteIsActive = row['is_active'] as bool? ?? true;

        final local =
            await _isar.creditModels.filter().uuidEqualTo(uuid).findFirst();

        if (local == null) {
          if (remoteIsActive) {
            await _isar.creditModels.put(_mapCredit(row));
            inserted++;
          } else {
            skipped++;
          }
        } else if (!remoteIsActive) {
          final merged = _mapCredit(row)..id = local.id;
          await _isar.creditModels.put(merged);
          updated++;
        } else if (local.syncStatus == CreditSyncStatus.pending) {
          skipped++;
        } else if (remoteUpdatedAt.isAfter(local.updatedAt)) {
          final merged = _mapCredit(row)..id = local.id;
          await _isar.creditModels.put(merged);
          updated++;
        } else {
          skipped++;
        }
      }
    });

    return MergeResult(inserted: inserted, updated: updated, skipped: skipped);
  }

  CreditModel _mapCredit(Map<String, dynamic> row) {
    return CreditModel()
      ..uuid = row['uuid'] as String
      ..userId = row['user_id'] as String
      ..name = row['name'] as String
      ..institution = row['institution'] as String?
      ..originalAmount = (row['original_amount'] as num?)?.toDouble() ?? 0
      ..currentBalance = (row['current_balance'] as num?)?.toDouble() ?? 0
      ..interestRate = (row['interest_rate'] as num?)?.toDouble()
      ..monthlyPayment = (row['monthly_payment'] as num?)?.toDouble() ?? 0
      ..paymentDay = row['payment_day'] as int
      ..nextPaymentDate = _parseNullableDate(row['next_payment_date'])
      ..startDate = _parseNullableDate(row['start_date'])
      ..endDate = _parseNullableDate(row['end_date'])
      ..totalInstallments = row['total_installments'] as int?
      ..paidInstallments = row['paid_installments'] as int?
      ..alertsEnabled = row['alerts_enabled'] as bool? ?? true
      ..belvoLinkId = row['belvo_link_id'] as String?
      ..belvoAccountId = row['belvo_account_id'] as String?
      ..lastBelvoSyncAt = _parseNullableDate(row['last_belvo_sync_at'])
      ..isActive = row['is_active'] as bool? ?? true
      ..createdAt = DateTime.parse(row['created_at'] as String)
      ..updatedAt = DateTime.parse(row['updated_at'] as String)
      ..syncStatus = CreditSyncStatus.synced;
  }

  // ─────────────────────────────────────────────────────────
  // BUDGETS
  // ─────────────────────────────────────────────────────────
  Future<MergeResult> _mergeBudgets(List<Map<String, dynamic>> rows) async {
    int inserted = 0, updated = 0, skipped = 0;

    await _isar.writeTxn(() async {
      for (final row in rows) {
        final uuid = row['uuid'] as String;
        final remoteUpdatedAt = DateTime.parse(row['updated_at'] as String);

        final local =
            await _isar.budgetModels.filter().uuidEqualTo(uuid).findFirst();

        if (local == null) {
          await _isar.budgetModels.put(_mapBudget(row));
          inserted++;
        } else if (local.syncStatus == BudgetSyncStatus.pending) {
          skipped++;
        } else if (remoteUpdatedAt.isAfter(local.updatedAt)) {
          final merged = _mapBudget(row)..id = local.id;
          await _isar.budgetModels.put(merged);
          updated++;
        } else {
          skipped++;
        }
      }
    });

    return MergeResult(inserted: inserted, updated: updated, skipped: skipped);
  }

  BudgetModel _mapBudget(Map<String, dynamic> row) {
    return BudgetModel()
      ..uuid = row['uuid'] as String
      ..userId = row['user_id'] as String
      ..categoryKey = row['category_key'] as String
      ..budgetedAmount = (row['budgeted_amount'] as num?)?.toDouble() ?? 0
      ..spentAmount = (row['spent_amount'] as num?)?.toDouble() ?? 0
      ..consumptionRatio = (row['consumption_ratio'] as num?)?.toDouble() ?? 0
      ..period = row['period'] as String
      ..isSuggested = row['is_suggested'] as bool? ?? false
      ..createdAt = DateTime.parse(row['created_at'] as String)
      ..updatedAt = DateTime.parse(row['updated_at'] as String)
      ..syncStatus = BudgetSyncStatus.synced;
  }

  // ─────────────────────────────────────────────────────────
  // GOALS
  // ─────────────────────────────────────────────────────────
  Future<MergeResult> _mergeGoals(List<Map<String, dynamic>> rows) async {
    int inserted = 0, updated = 0, skipped = 0;

    await _isar.writeTxn(() async {
      for (final row in rows) {
        final uuid = row['uuid'] as String;
        final remoteUpdatedAt = DateTime.parse(row['updated_at'] as String);

        final local =
            await _isar.goalModels.filter().uuidEqualTo(uuid).findFirst();

        if (local == null) {
          await _isar.goalModels.put(_mapGoal(row));
          inserted++;
        } else if (local.syncStatus == GoalSyncStatus.pending) {
          skipped++;
        } else if (remoteUpdatedAt.isAfter(local.updatedAt)) {
          final merged = _mapGoal(row)..id = local.id;
          await _isar.goalModels.put(merged);
          updated++;
        } else {
          skipped++;
        }
      }
    });

    return MergeResult(inserted: inserted, updated: updated, skipped: skipped);
  }

  GoalModel _mapGoal(Map<String, dynamic> row) {
    return GoalModel()
      ..uuid = row['uuid'] as String
      ..userId = row['user_id'] as String
      ..name = row['name'] as String
      ..targetAmount = (row['target_amount'] as num?)?.toDouble() ?? 0
      ..savedAmount = (row['saved_amount'] as num?)?.toDouble() ?? 0
      ..progress = (row['progress'] as num?)?.toDouble() ?? 0
      ..deadline = _parseNullableDate(row['deadline'])
      ..icon = row['icon'] as String?
      ..isCompleted = row['is_completed'] as bool? ?? false
      ..isActive = row['is_active'] as bool? ?? true
      ..createdAt = DateTime.parse(row['created_at'] as String)
      ..updatedAt = DateTime.parse(row['updated_at'] as String)
      ..syncStatus = GoalSyncStatus.synced;
  }

  // ─────────────────────────────────────────────────────────
  // HEALTH SNAPSHOTS (insert-only, nunca se actualizan)
  // ─────────────────────────────────────────────────────────
  Future<MergeResult> _mergeHealthSnapshots(
      List<Map<String, dynamic>> rows) async {
    int inserted = 0, skipped = 0;

    await _isar.writeTxn(() async {
      for (final row in rows) {
        final uuid = row['uuid'] as String;

        final exists = await _isar.healthSnapshotModels
            .filter()
            .uuidEqualTo(uuid)
            .findFirst();

        if (exists == null) {
          await _isar.healthSnapshotModels.put(_mapHealthSnapshot(row));
          inserted++;
        } else {
          skipped++;
        }
      }
    });

    return MergeResult(inserted: inserted, skipped: skipped);
  }

  HealthSnapshotModel _mapHealthSnapshot(Map<String, dynamic> row) {
    return HealthSnapshotModel()
      ..uuid = row['uuid'] as String
      ..userId = row['user_id'] as String
      ..snapshotDate = DateTime.parse(row['snapshot_date'] as String)
      ..totalIncome = (row['total_income'] as num?)?.toDouble() ?? 0
      ..totalExpenses = (row['total_expenses'] as num?)?.toDouble() ?? 0
      ..expenseToIncomeRatio =
          (row['expense_to_income_ratio'] as num?)?.toDouble() ?? 0
      ..totalDebt = (row['total_debt'] as num?)?.toDouble() ?? 0
      ..overduePayments = row['overdue_payments'] as int? ?? 0
      ..creditUtilizationRatio =
          (row['credit_utilization_ratio'] as num?)?.toDouble() ?? 0
      ..goalProgressAvg = (row['goal_progress_avg'] as num?)?.toDouble() ?? 0
      ..healthScore = (row['health_score'] as num?)?.toDouble() ?? 50
      ..healthLevel = SnapshotHealthLevel.values
          .byName(row['health_level'] as String? ?? 'stable')
      ..emotionalMessage = (row['emotional_message'] as String?) ?? ''
      ..createdAt = DateTime.parse(row['created_at'] as String)
      ..syncStatus = SnapshotSyncStatus.synced;
  }

  // ─────────────────────────────────────────────────────────
  // PROFILE MERGE
  // ─────────────────────────────────────────────────────────
  Future<void> mergeProfile(Map<String, dynamic> row) async {
    await _isar.writeTxn(() async {
      final local = await _isar.userModels
          .filter()
          .supabaseIdEqualTo(row['id'] as String)
          .findFirst();

      if (local != null) {
        // Solo actualizar campos de perfil, no tokens de sesión
        local.email = row['email'] as String? ?? local.email;
        local.displayName = row['display_name'] as String?;
        local.avatarUrl = row['avatar_url'] as String?;
        local.currency =
            UserCurrency.values.byName(row['currency'] as String? ?? 'mxn');
        local.onboardingCompleted =
            row['onboarding_completed'] as bool? ?? local.onboardingCompleted;
        local.updatedAt = DateTime.now();
        await _isar.userModels.put(local);
      }
    });
  }

  // ─────────────────────────────────────────────────────────
  // UTILS
  // ─────────────────────────────────────────────────────────
  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
