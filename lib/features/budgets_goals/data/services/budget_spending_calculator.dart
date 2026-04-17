// lib/features/budgets_goals/data/services/budget_spending_calculator.dart

import 'package:isar/isar.dart';
import 'package:betty_app/core/utils/date_utils.dart';
import 'package:betty_app/features/transactions/data/models/transaction_model.dart';
import 'package:betty_app/features/budgets_goals/data/models/budget_model.dart';

/// Recalcula el gasto real (spentAmount) de cada presupuesto
/// consultando las transacciones del período directamente en Isar.
///
/// Se invoca cada vez que se cargan los presupuestos y cada vez
/// que se guarda/elimina una transacción.
class BudgetSpendingCalculator {
  final Isar _isar;

  BudgetSpendingCalculator(this._isar);

  /// Retorna un mapa { categoryKey: totalGastado } del período actual.
  Future<Map<String, double>> calculateSpentByCategory(String userId) async {
    final from = BettyDateUtils.startOfCurrentMonth();
    final to = BettyDateUtils.endOfCurrentMonth();

    final transactions = await _isar.transactionModels
        .filter()
        .userIdEqualTo(userId)
        .isDeletedEqualTo(false)
        .typeEqualTo(TxType.expense)
        .transactionDateBetween(from, to)
        .findAll();

    final Map<String, double> spentMap = {};
    for (final tx in transactions) {
      final key = tx.category.name; // TxCategory.name == CategoryType.name
      spentMap[key] = (spentMap[key] ?? 0) + tx.amount;
    }
    return spentMap;
  }

  /// Actualiza spentAmount y consumptionRatio de todos los presupuestos
  /// del período actual directamente en Isar.
  /// Retorna la lista de BudgetModel ya actualizados.
  Future<List<BudgetModel>> recalculateAndPersist(String userId) async {
    final period = BettyDateUtils.currentPeriod();
    final spentMap = await calculateSpentByCategory(userId);

    final budgets = await _isar.budgetModels
        .filter()
        .userIdEqualTo(userId)
        .periodEqualTo(period)
        .findAll();

    if (budgets.isEmpty) return budgets;

    await _isar.writeTxn(() async {
      for (final budget in budgets) {
        final spent = spentMap[budget.categoryKey] ?? 0;
        budget.spentAmount = spent;
        budget.consumptionRatio =
            budget.budgetedAmount > 0 ? spent / budget.budgetedAmount : 0;
        budget.updatedAt = DateTime.now();
        // No cambiamos syncStatus aquí porque es un recálculo local,
        // el spentAmount no se sincroniza — se recalcula en cada device.
        await _isar.budgetModels.put(budget);
      }
    });

    return budgets;
  }

  /// Calcula métricas globales del mes para el termómetro.
  Future<BudgetMonthSummary> getMonthSummary(String userId) async {
    final from = BettyDateUtils.startOfCurrentMonth();
    final to = BettyDateUtils.endOfCurrentMonth();

    final allTx = await _isar.transactionModels
        .filter()
        .userIdEqualTo(userId)
        .isDeletedEqualTo(false)
        .transactionDateBetween(from, to)
        .findAll();

    double totalIncome = 0;
    double totalExpenses = 0;
    for (final tx in allTx) {
      if (tx.type == TxType.income) {
        totalIncome += tx.amount;
      } else {
        totalExpenses += tx.amount;
      }
    }

    final period = BettyDateUtils.currentPeriod();
    final budgets = await _isar.budgetModels
        .filter()
        .userIdEqualTo(userId)
        .periodEqualTo(period)
        .findAll();

    final totalBudgeted =
        budgets.fold<double>(0, (sum, b) => sum + b.budgetedAmount);

    return BudgetMonthSummary(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      totalBudgeted: totalBudgeted,
      available: totalIncome - totalExpenses,
      overallRatio: totalBudgeted > 0 ? totalExpenses / totalBudgeted : 0,
    );
  }

  /// Retorna { categoryKey: totalGastado } para un mes específico.
  Future<Map<String, double>> calculateSpentByCategoryForPeriod(
    String userId,
    int year,
    int month,
  ) async {
    final from = BettyDateUtils.startOfMonth(year, month);
    final to = BettyDateUtils.endOfMonth(year, month);

    final transactions = await _isar.transactionModels
        .filter()
        .userIdEqualTo(userId)
        .isDeletedEqualTo(false)
        .typeEqualTo(TxType.expense)
        .transactionDateBetween(from, to)
        .findAll();

    final Map<String, double> spentMap = {};
    for (final tx in transactions) {
      final key = tx.category.name;
      spentMap[key] = (spentMap[key] ?? 0) + tx.amount;
    }
    return spentMap;
  }

  /// Recalcula spentAmount de presupuestos de un período específico.
  Future<List<BudgetModel>> recalculateAndPersistForPeriod(
    String userId,
    int year,
    int month,
  ) async {
    final period = BettyDateUtils.periodFrom(year, month);
    final spentMap =
        await calculateSpentByCategoryForPeriod(userId, year, month);

    final budgets = await _isar.budgetModels
        .filter()
        .userIdEqualTo(userId)
        .periodEqualTo(period)
        .findAll();

    if (budgets.isEmpty) return budgets;

    await _isar.writeTxn(() async {
      for (final budget in budgets) {
        final spent = spentMap[budget.categoryKey] ?? 0;
        budget.spentAmount = spent;
        budget.consumptionRatio =
            budget.budgetedAmount > 0 ? spent / budget.budgetedAmount : 0;
        budget.updatedAt = DateTime.now();
        await _isar.budgetModels.put(budget);
      }
    });

    return budgets;
  }

  /// Resumen de un mes específico.
  Future<BudgetMonthSummary> getMonthSummaryForPeriod(
    String userId,
    int year,
    int month,
  ) async {
    final from = BettyDateUtils.startOfMonth(year, month);
    final to = BettyDateUtils.endOfMonth(year, month);

    final allTx = await _isar.transactionModels
        .filter()
        .userIdEqualTo(userId)
        .isDeletedEqualTo(false)
        .transactionDateBetween(from, to)
        .findAll();

    double totalIncome = 0;
    double totalExpenses = 0;
    for (final tx in allTx) {
      if (tx.type == TxType.income) {
        totalIncome += tx.amount;
      } else {
        totalExpenses += tx.amount;
      }
    }

    final period = BettyDateUtils.periodFrom(year, month);
    final budgets = await _isar.budgetModels
        .filter()
        .userIdEqualTo(userId)
        .periodEqualTo(period)
        .findAll();

    final totalBudgeted =
        budgets.fold<double>(0, (sum, b) => sum + b.budgetedAmount);

    return BudgetMonthSummary(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      totalBudgeted: totalBudgeted,
      available: totalIncome - totalExpenses,
      overallRatio: totalBudgeted > 0 ? totalExpenses / totalBudgeted : 0,
    );
  }
}

/// Resumen del mes para el termómetro global.
class BudgetMonthSummary {
  final double totalIncome;
  final double totalExpenses;
  final double totalBudgeted;
  final double available;

  /// totalExpenses / totalBudgeted (0.0 a N).
  final double overallRatio;

  const BudgetMonthSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.totalBudgeted,
    required this.available,
    required this.overallRatio,
  });

  BudgetHealthLevel get healthLevel {
    if (overallRatio <= 1.0) return BudgetHealthLevel.green;
    if (overallRatio <= 1.1) return BudgetHealthLevel.yellow;
    return BudgetHealthLevel.red;
  }
}

enum BudgetHealthLevel { green, yellow, red }
