// lib/features/budgets_goals/presentation/providers/budgets_goals_provider.dart

import 'dart:convert';
import 'package:beti_app/features/financial_health/presentation/providers/health_provider.dart';
import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beti_app/core/providers/core_providers.dart';
import 'package:beti_app/core/utils/date_utils.dart';
import 'package:beti_app/core/utils/uuid_generator.dart';
import 'package:beti_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:beti_app/features/budgets_goals/data/models/budget_model.dart';
import 'package:beti_app/features/budgets_goals/data/models/goal_model.dart';
import 'package:beti_app/features/budgets_goals/data/services/budget_spending_calculator.dart';
import 'package:beti_app/features/budgets_goals/data/services/budget_alert_engine.dart';
import 'package:beti_app/features/sync/data/models/sync_queue_model.dart';
import 'package:beti_app/features/sync/presentation/providers/sync_provider.dart';
import 'package:beti_app/features/budgets_goals/data/services/inflation_adjustment_service.dart';

// ══════════════════════════════════════════════════════════════
// DataSources
// ══════════════════════════════════════════════════════════════

class BudgetLocalDataSource {
  final Isar _isar;
  BudgetLocalDataSource(this._isar);

  Future<void> save(BudgetModel budget) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.budgetModels
          .filter()
          .uuidEqualTo(budget.uuid)
          .findFirst();
      if (existing != null) budget.id = existing.id;
      await _isar.budgetModels.put(budget);
    });
  }

  Future<BudgetModel?> getByUuid(String uuid) async {
    return await _isar.budgetModels.filter().uuidEqualTo(uuid).findFirst();
  }

  Future<BudgetModel?> getByCategoryAndPeriod(
      String userId, String categoryKey, String period) async {
    return await _isar.budgetModels
        .filter()
        .userIdEqualTo(userId)
        .categoryKeyEqualTo(categoryKey)
        .periodEqualTo(period)
        .findFirst();
  }

  Future<List<BudgetModel>> getByPeriod(String userId, String period) async {
    return await _isar.budgetModels
        .filter()
        .userIdEqualTo(userId)
        .periodEqualTo(period)
        .findAll();
  }

  Future<void> delete(String uuid) async {
    await _isar.writeTxn(() async {
      final b = await _isar.budgetModels.filter().uuidEqualTo(uuid).findFirst();
      if (b != null) await _isar.budgetModels.delete(b.id);
    });
  }
}

class GoalLocalDataSource {
  final Isar _isar;
  GoalLocalDataSource(this._isar);

  Future<void> save(GoalModel goal) async {
    await _isar.writeTxn(() async {
      final existing =
          await _isar.goalModels.filter().uuidEqualTo(goal.uuid).findFirst();
      if (existing != null) goal.id = existing.id;
      await _isar.goalModels.put(goal);
    });
  }

  Future<GoalModel?> getByUuid(String uuid) async {
    return await _isar.goalModels.filter().uuidEqualTo(uuid).findFirst();
  }

  Future<List<GoalModel>> getAllActive(String userId) async {
    return await _isar.goalModels
        .filter()
        .userIdEqualTo(userId)
        .isActiveEqualTo(true)
        .findAll();
  }

  Future<void> addSavings(String uuid, double amount) async {
    await _isar.writeTxn(() async {
      final g = await _isar.goalModels.filter().uuidEqualTo(uuid).findFirst();
      if (g != null) {
        g.savedAmount += amount;
        g.progress = g.targetAmount > 0 ? g.savedAmount / g.targetAmount : 0;
        g.isCompleted = g.progress >= 1.0;
        g.updatedAt = DateTime.now();
        g.syncStatus = GoalSyncStatus.pending;
        await _isar.goalModels.put(g);
      }
    });
  }

  Future<void> delete(String uuid) async {
    await _isar.writeTxn(() async {
      final g = await _isar.goalModels.filter().uuidEqualTo(uuid).findFirst();
      if (g != null) {
        g.isActive = false;
        g.syncStatus = GoalSyncStatus.pending;
        await _isar.goalModels.put(g);
      }
    });
  }
}

// ══════════════════════════════════════════════════════════════
// Providers DI
// ══════════════════════════════════════════════════════════════

final budgetLocalDsProvider = Provider<BudgetLocalDataSource>((ref) {
  return BudgetLocalDataSource(ref.watch(isarProvider));
});

final goalLocalDsProvider = Provider<GoalLocalDataSource>((ref) {
  return GoalLocalDataSource(ref.watch(isarProvider));
});

final budgetSpendingCalculatorProvider =
    Provider<BudgetSpendingCalculator>((ref) {
  return BudgetSpendingCalculator(ref.watch(isarProvider));
});

// ══════════════════════════════════════════════════════════════
// Entities
// ══════════════════════════════════════════════════════════════

class BudgetEntity {
  final String uuid;
  final String categoryKey;
  final double budgetedAmount;
  final double spentAmount;
  final double consumptionRatio;
  final String period;
  final bool isSuggested;

  const BudgetEntity({
    required this.uuid,
    required this.categoryKey,
    required this.budgetedAmount,
    required this.spentAmount,
    required this.consumptionRatio,
    required this.period,
    this.isSuggested = false,
  });

  /// Nivel semáforo individual por categoría.
  BudgetCategoryStatus get status {
    if (consumptionRatio <= 1.0) return BudgetCategoryStatus.green;
    if (consumptionRatio <= 1.1) return BudgetCategoryStatus.yellow;
    return BudgetCategoryStatus.red;
  }

  double get remainingAmount =>
      (budgetedAmount - spentAmount).clamp(0, double.infinity);
}

enum BudgetCategoryStatus { green, yellow, red }

class GoalEntity {
  final String uuid;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final double progress;
  final DateTime? deadline;
  final String? icon;
  final bool isCompleted;

  const GoalEntity({
    required this.uuid,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.progress,
    this.deadline,
    this.icon,
    this.isCompleted = false,
  });

  /// Monto restante por ahorrar.
  double get remainingAmount =>
      (targetAmount - savedAmount).clamp(0, double.infinity);

  /// Contribución mensual sugerida para cumplir a tiempo.
  double? get suggestedMonthlyContribution {
    if (deadline == null || isCompleted) return null;
    final now = DateTime.now();
    final monthsLeft =
        (deadline!.year - now.year) * 12 + (deadline!.month - now.month);
    if (monthsLeft <= 0) return remainingAmount;
    return remainingAmount / monthsLeft;
  }
}

/// Período seleccionado para la vista de presupuestos.
/// Formato: [year, month]. Default: mes actual.
final selectedPeriodProvider = StateProvider<({int year, int month})>((ref) {
  final now = DateTime.now();
  return (year: now.year, month: now.month);
});

// ══════════════════════════════════════════════════════════════
// Budgets Notifier
// ══════════════════════════════════════════════════════════════

class BudgetsNotifier extends AsyncNotifier<List<BudgetEntity>> {
  @override
  Future<List<BudgetEntity>> build() async => _load();

  Future<List<BudgetEntity>> _load() async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return [];

    final selected = ref.read(selectedPeriodProvider);
    final now = DateTime.now();
    final isCurrentMonth =
        selected.year == now.year && selected.month == now.month;

    final calculator = ref.read(budgetSpendingCalculatorProvider);
    final List<BudgetModel> models;

    if (isCurrentMonth) {
      models = await calculator.recalculateAndPersist(auth.user.supabaseId);
    } else {
      models = await calculator.recalculateAndPersistForPeriod(
        auth.user.supabaseId,
        selected.year,
        selected.month,
      );
    }

    return models
        .map((m) => BudgetEntity(
              uuid: m.uuid,
              categoryKey: m.categoryKey,
              budgetedAmount: m.budgetedAmount,
              spentAmount: m.spentAmount,
              consumptionRatio: m.consumptionRatio,
              period: m.period,
              isSuggested: m.isSuggested,
            ))
        .toList();
  }

  /// Refrescar después de que se guarda/elimina una transacción.
  Future<void> recalculate() async {
    state = const AsyncLoading();
    final budgets = await _load();
    state = AsyncData(budgets);

    // Evaluar alertas solo en el mes actual
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return;

    final selected = ref.read(selectedPeriodProvider);
    final now = DateTime.now();
    if (selected.year != now.year || selected.month != now.month) return;

    final period = BettyDateUtils.currentPeriod();
    final models = await ref
        .read(budgetLocalDsProvider)
        .getByPeriod(auth.user.supabaseId, period);
    await BudgetAlertEngine.evaluate(models);
  }

  /// Agrega un presupuesto para una categoría en el período actual.
  /// Si ya existe uno para esa categoría/período, lo actualiza.
  Future<void> addBudget({
    required String categoryKey,
    required double amount,
  }) async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return;

    final uid = auth.user.supabaseId;
    final period = BettyDateUtils.currentPeriod();
    final ds = ref.read(budgetLocalDsProvider);
    final now = DateTime.now();

    final existing = await ds.getByCategoryAndPeriod(uid, categoryKey, period);

    if (existing != null) {
      await updateBudget(uuid: existing.uuid, newAmount: amount);
      return;
    }

    final uuid = UuidGenerator.generate();
    final model = BudgetModel()
      ..uuid = uuid
      ..userId = uid
      ..categoryKey = categoryKey
      ..budgetedAmount = amount
      ..spentAmount = 0
      ..period = period
      ..isSuggested = false
      ..consumptionRatio = 0
      ..createdAt = now
      ..updatedAt = now
      ..syncStatus = BudgetSyncStatus.pending;

    await ds.save(model);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: uid,
          targetCollection: 'budgets',
          targetUuid: uuid,
          operation: SyncOperation.create,
          payload: jsonEncode({
            'uuid': uuid,
            'user_id': uid,
            'category_key': categoryKey,
            'budgeted_amount': amount,
            'spent_amount': 0,
            'period': period,
            'is_suggested': false,
            'consumption_ratio': 0,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          }),
        );

    ref.invalidate(healthProvider);
    await recalculate();
  }

  /// Actualizar el monto de un presupuesto existente.
  Future<void> updateBudget({
    required String uuid,
    required double newAmount,
  }) async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return;

    final ds = ref.read(budgetLocalDsProvider);
    final model = await ds.getByUuid(uuid);
    if (model == null) return;

    final now = DateTime.now();
    model.budgetedAmount = newAmount;
    model.consumptionRatio = newAmount > 0 ? model.spentAmount / newAmount : 0;
    model.updatedAt = now;
    model.syncStatus = BudgetSyncStatus.pending;
    await ds.save(model);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: auth.user.supabaseId,
          targetCollection: 'budgets',
          targetUuid: uuid,
          operation: SyncOperation.update,
          payload: jsonEncode({
            'uuid': uuid,
            'budgeted_amount': newAmount,
            'consumption_ratio': model.consumptionRatio,
            'updated_at': now.toIso8601String(),
          }),
        );

    ref.invalidate(healthProvider);
    await recalculate();
  }

  Future<void> deleteBudget(String uuid) async {
    await ref.read(budgetLocalDsProvider).delete(uuid);
    ref.invalidate(healthProvider);
    state = AsyncData(await _load());
  }
}

final budgetsProvider =
    AsyncNotifierProvider<BudgetsNotifier, List<BudgetEntity>>(
  BudgetsNotifier.new,
);

/// Resumen mensual del termómetro (se usa en la UI del dashboard).
final budgetMonthSummaryProvider =
    FutureProvider<BudgetMonthSummary?>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth is! AuthAuthenticated) return null;

  ref.watch(budgetsProvider);

  final selected = ref.watch(selectedPeriodProvider);
  final calculator = ref.read(budgetSpendingCalculatorProvider);
  return await calculator.getMonthSummaryForPeriod(
    auth.user.supabaseId,
    selected.year,
    selected.month,
  );
});

// ══════════════════════════════════════════════════════════════
// Goals Notifier
// ══════════════════════════════════════════════════════════════

class GoalsNotifier extends AsyncNotifier<List<GoalEntity>> {
  @override
  Future<List<GoalEntity>> build() async => _load();

  Future<List<GoalEntity>> _load() async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return [];

    // Ajuste diario por inflación (se ejecuta máximo 1 vez al día)
    final inflationService = ref.read(inflationServiceProvider);
    await inflationService.adjustIfNeeded(auth.user.supabaseId);

    final models =
        await ref.read(goalLocalDsProvider).getAllActive(auth.user.supabaseId);
    return models
        .map((m) => GoalEntity(
              uuid: m.uuid,
              name: m.name,
              targetAmount: m.targetAmount,
              savedAmount: m.savedAmount,
              progress: m.progress,
              deadline: m.deadline,
              icon: m.icon,
              isCompleted: m.isCompleted,
            ))
        .toList();
  }

  Future<void> addGoal({
    required String name,
    required double targetAmount,
    DateTime? deadline,
    String? icon,
  }) async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return;

    final now = DateTime.now();
    final uuid = UuidGenerator.generate();
    final model = GoalModel()
      ..uuid = uuid
      ..userId = auth.user.supabaseId
      ..name = name
      ..targetAmount = targetAmount
      ..savedAmount = 0
      ..deadline = deadline
      ..icon = icon
      ..progress = 0
      ..isCompleted = false
      ..isActive = true
      ..createdAt = now
      ..updatedAt = now
      ..syncStatus = GoalSyncStatus.pending;

    await ref.read(goalLocalDsProvider).save(model);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: auth.user.supabaseId,
          targetCollection: 'goals',
          targetUuid: uuid,
          operation: SyncOperation.create,
          payload: jsonEncode({
            'uuid': uuid,
            'user_id': auth.user.supabaseId,
            'name': name,
            'target_amount': targetAmount,
            'saved_amount': 0,
            'deadline': deadline?.toIso8601String(),
            'icon': icon,
            'progress': 0,
            'is_completed': false,
            'is_active': true,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          }),
        );

    ref.invalidate(healthProvider);
    state = AsyncData(await _load());
  }

  Future<void> addSavings(String uuid, double amount) async {
    await ref.read(goalLocalDsProvider).addSavings(uuid, amount);
    ref.invalidate(healthProvider);
    state = AsyncData(await _load());
  }

  /// Retirar ahorro de una meta (sin eliminarla).
  Future<void> withdrawSavings(String uuid, double amount) async {
    final ds = ref.read(goalLocalDsProvider);
    final model = await ds.getByUuid(uuid);
    if (model == null) return;

    await ref.read(isarProvider).writeTxn(() async {
      model.savedAmount =
          (model.savedAmount - amount).clamp(0, double.infinity);
      model.progress =
          model.targetAmount > 0 ? model.savedAmount / model.targetAmount : 0;
      model.isCompleted = model.progress >= 1.0;
      model.updatedAt = DateTime.now();
      model.syncStatus = GoalSyncStatus.pending;
      await ref.read(isarProvider).goalModels.put(model);
    });

    ref.invalidate(healthProvider);
    state = AsyncData(await _load());
  }

  /// Actualizar nombre, monto meta o deadline de una meta existente.
  Future<void> updateGoal({
    required String uuid,
    String? name,
    double? targetAmount,
    DateTime? deadline,
    String? icon,
  }) async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return;

    final ds = ref.read(goalLocalDsProvider);
    final model = await ds.getByUuid(uuid);
    if (model == null) return;

    final now = DateTime.now();
    if (name != null) model.name = name;
    if (targetAmount != null) {
      model.targetAmount = targetAmount;
      model.progress = targetAmount > 0 ? model.savedAmount / targetAmount : 0;
      model.isCompleted = model.progress >= 1.0;
    }
    if (deadline != null) model.deadline = deadline;
    if (icon != null) model.icon = icon;
    model.updatedAt = now;
    model.syncStatus = GoalSyncStatus.pending;

    await ds.save(model);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: auth.user.supabaseId,
          targetCollection: 'goals',
          targetUuid: uuid,
          operation: SyncOperation.update,
          payload: jsonEncode({
            'uuid': uuid,
            'name': model.name,
            'target_amount': model.targetAmount,
            'saved_amount': model.savedAmount,
            'deadline': model.deadline?.toIso8601String(),
            'icon': model.icon,
            'progress': model.progress,
            'is_completed': model.isCompleted,
            'updated_at': now.toIso8601String(),
          }),
        );

    ref.invalidate(healthProvider);
    state = AsyncData(await _load());
  }

  Future<void> deleteGoal(String uuid) async {
    await ref.read(goalLocalDsProvider).delete(uuid);
    ref.invalidate(healthProvider);
    state = AsyncData(await _load());
  }
}

final goalsProvider = AsyncNotifierProvider<GoalsNotifier, List<GoalEntity>>(
  GoalsNotifier.new,
);

final inflationServiceProvider = Provider<InflationAdjustmentService>((ref) {
  return InflationAdjustmentService(ref.watch(isarProvider));
});
