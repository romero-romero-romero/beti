import 'dart:convert';
import 'package:betty_app/features/financial_health/presentation/providers/health_provider.dart';
import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/core/providers/core_providers.dart';
import 'package:betty_app/core/utils/date_utils.dart';
import 'package:betty_app/core/utils/uuid_generator.dart';
import 'package:betty_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:betty_app/features/budgets_goals/data/models/budget_model.dart';
import 'package:betty_app/features/budgets_goals/data/models/goal_model.dart';
import 'package:betty_app/features/sync/data/models/sync_queue_model.dart';
import 'package:betty_app/features/sync/presentation/providers/sync_provider.dart';

// ── Budget DataSource ──

class BudgetLocalDataSource {
  final Isar _isar;
  BudgetLocalDataSource(this._isar);

  Future<void> save(BudgetModel budget) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.budgetModels
          .filter().uuidEqualTo(budget.uuid).findFirst();
      if (existing != null) budget.id = existing.id;
      await _isar.budgetModels.put(budget);
    });
  }

  Future<List<BudgetModel>> getByPeriod(String userId, String period) async {
    return await _isar.budgetModels
        .filter().userIdEqualTo(userId).periodEqualTo(period).findAll();
  }

  Future<void> delete(String uuid) async {
    await _isar.writeTxn(() async {
      final b = await _isar.budgetModels.filter().uuidEqualTo(uuid).findFirst();
      if (b != null) await _isar.budgetModels.delete(b.id);
    });
  }
}

// ── Goal DataSource ──

class GoalLocalDataSource {
  final Isar _isar;
  GoalLocalDataSource(this._isar);

  Future<void> save(GoalModel goal) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.goalModels
          .filter().uuidEqualTo(goal.uuid).findFirst();
      if (existing != null) goal.id = existing.id;
      await _isar.goalModels.put(goal);
    });
  }

  Future<List<GoalModel>> getAllActive(String userId) async {
    return await _isar.goalModels
        .filter().userIdEqualTo(userId).isActiveEqualTo(true).findAll();
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

// ── Providers ──

final budgetLocalDsProvider = Provider<BudgetLocalDataSource>((ref) {
  return BudgetLocalDataSource(ref.watch(isarProvider));
});

final goalLocalDsProvider = Provider<GoalLocalDataSource>((ref) {
  return GoalLocalDataSource(ref.watch(isarProvider));
});

// ── Budget entity ──

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
}

// ── Goal entity ──

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
}

// ── Budgets Notifier ──

class BudgetsNotifier extends AsyncNotifier<List<BudgetEntity>> {
  @override
  Future<List<BudgetEntity>> build() async => _load();

  Future<List<BudgetEntity>> _load() async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return [];
    final period = BettyDateUtils.currentPeriod();
    final models = await ref.read(budgetLocalDsProvider).getByPeriod(auth.user.supabaseId, period);
    return models.map((m) => BudgetEntity(
      uuid: m.uuid, categoryKey: m.categoryKey,
      budgetedAmount: m.budgetedAmount, spentAmount: m.spentAmount,
      consumptionRatio: m.consumptionRatio, period: m.period,
      isSuggested: m.isSuggested,
    )).toList();
  }

  Future<void> addBudget({required String categoryKey, required double amount}) async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return;
    final now = DateTime.now();
    final uuid = UuidGenerator.generate();
    final model = BudgetModel()
      ..uuid = uuid ..userId = auth.user.supabaseId
      ..categoryKey = categoryKey ..budgetedAmount = amount
      ..spentAmount = 0 ..period = BettyDateUtils.currentPeriod()
      ..isSuggested = false ..consumptionRatio = 0
      ..createdAt = now ..updatedAt = now
      ..syncStatus = BudgetSyncStatus.pending;
    await ref.read(budgetLocalDsProvider).save(model);
    await ref.read(syncRepositoryProvider).enqueueChange(
      userId: auth.user.supabaseId, targetCollection: 'budgets',
      targetUuid: uuid, operation: SyncOperation.create,
      payload: jsonEncode({'uuid': uuid, 'user_id': auth.user.supabaseId,
        'category_key': categoryKey, 'budgeted_amount': amount,
        'spent_amount': 0, 'period': BettyDateUtils.currentPeriod(),
        'is_suggested': false, 'consumption_ratio': 0,
        'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String()}),
    );
    state = AsyncData(await _load());
  }

  Future<void> deleteBudget(String uuid) async {
    await ref.read(budgetLocalDsProvider).delete(uuid);
    state = AsyncData(await _load());
  }
}

final budgetsProvider = AsyncNotifierProvider<BudgetsNotifier, List<BudgetEntity>>(BudgetsNotifier.new);

// ── Goals Notifier ──

class GoalsNotifier extends AsyncNotifier<List<GoalEntity>> {
  @override
  Future<List<GoalEntity>> build() async => _load();

  Future<List<GoalEntity>> _load() async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return [];
    final models = await ref.read(goalLocalDsProvider).getAllActive(auth.user.supabaseId);
    return models.map((m) => GoalEntity(
      uuid: m.uuid, name: m.name, targetAmount: m.targetAmount,
      savedAmount: m.savedAmount, progress: m.progress,
      deadline: m.deadline, icon: m.icon, isCompleted: m.isCompleted,
    )).toList();
  }

  Future<void> addGoal({required String name, required double targetAmount, DateTime? deadline, String? icon}) async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return;
    final now = DateTime.now();
    final uuid = UuidGenerator.generate();
    final model = GoalModel()
      ..uuid = uuid ..userId = auth.user.supabaseId
      ..name = name ..targetAmount = targetAmount ..savedAmount = 0
      ..deadline = deadline ..icon = icon ..progress = 0
      ..isCompleted = false ..isActive = true
      ..createdAt = now ..updatedAt = now ..syncStatus = GoalSyncStatus.pending;
    await ref.read(goalLocalDsProvider).save(model);
    await ref.read(syncRepositoryProvider).enqueueChange(
      userId: auth.user.supabaseId, targetCollection: 'goals',
      targetUuid: uuid, operation: SyncOperation.create,
      payload: jsonEncode({'uuid': uuid, 'user_id': auth.user.supabaseId,
        'name': name, 'target_amount': targetAmount, 'saved_amount': 0,
        'deadline': deadline?.toIso8601String(), 'icon': icon,
        'progress': 0, 'is_completed': false, 'is_active': true,
        'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String()}),
    );
    state = AsyncData(await _load());
  }

  Future<void> addSavings(String uuid, double amount) async {
    await ref.read(goalLocalDsProvider).addSavings(uuid, amount);
    ref.invalidate(healthProvider);
    state = AsyncData(await _load());
  }

  Future<void> deleteGoal(String uuid) async {
    await ref.read(goalLocalDsProvider).delete(uuid);
    state = AsyncData(await _load());
  }
}

final goalsProvider = AsyncNotifierProvider<GoalsNotifier, List<GoalEntity>>(GoalsNotifier.new);
