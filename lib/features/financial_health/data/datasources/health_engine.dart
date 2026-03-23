import 'package:isar/isar.dart';
import 'package:betty_app/core/constants/financial_constants.dart';
import 'package:betty_app/core/enums/health_level.dart';
import 'package:betty_app/core/utils/date_utils.dart';
import 'package:betty_app/features/transactions/data/models/transaction_model.dart';
import 'package:betty_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:betty_app/features/cards_credits/data/models/credit_model.dart';
import 'package:betty_app/features/budgets_goals/data/models/goal_model.dart';
import 'package:betty_app/features/financial_health/data/models/health_snapshot_model.dart';
import 'package:betty_app/core/utils/uuid_generator.dart';

/// Resultado del cálculo de salud financiera.
class HealthResult {
  final double score;
  final HealthLevel level;
  final String message;
  final double totalIncome;
  final double totalExpenses;
  final double expenseToIncomeRatio;
  final double totalDebt;
  final int overduePayments;
  final double creditUtilizationRatio;
  final double goalProgressAvg;

  const HealthResult({
    required this.score,
    required this.level,
    required this.message,
    required this.totalIncome,
    required this.totalExpenses,
    required this.expenseToIncomeRatio,
    required this.totalDebt,
    required this.overduePayments,
    required this.creditUtilizationRatio,
    required this.goalProgressAvg,
  });
}

/// Motor de cálculo de Salud Financiera Emocional.
/// Opera 100% offline sobre datos de Isar.
class HealthEngine {
  final Isar _isar;

  HealthEngine(this._isar);

  /// Calcula el score actual basándose en datos del mes en curso.
  Future<HealthResult> calculate(String userId) async {
    final from = BettyDateUtils.startOfCurrentMonth();
    final to = BettyDateUtils.endOfCurrentMonth();

    // 1. Ingresos y gastos del mes
    final transactions = await _isar.transactionModels
        .filter()
        .userIdEqualTo(userId)
        .isDeletedEqualTo(false)
        .transactionDateBetween(from, to)
        .findAll();

    double totalIncome = 0;
    double totalExpenses = 0;
    for (final tx in transactions) {
      if (tx.type == TxType.income) {
        totalIncome += tx.amount;
      } else {
        totalExpenses += tx.amount;
      }
    }

    final ratio = totalIncome > 0 ? totalExpenses / totalIncome : 1.5;

    // 2. Deuda total (tarjetas + créditos)
    final cards = await _isar.creditCardModels
        .filter()
        .userIdEqualTo(userId)
        .isActiveEqualTo(true)
        .findAll();

    final credits = await _isar.creditModels
        .filter()
        .userIdEqualTo(userId)
        .isActiveEqualTo(true)
        .findAll();

    double totalDebt = 0;
    double totalCreditLimit = 0;
    int overduePayments = 0;

    for (final c in cards) {
      totalDebt += c.currentBalance;
      totalCreditLimit += c.creditLimit;
      if (c.nextPaymentDueDate != null &&
          BettyDateUtils.isDueOrOverdue(c.nextPaymentDueDate!)) {
        overduePayments++;
      }
    }

    for (final c in credits) {
      totalDebt += c.currentBalance;
      if (c.nextPaymentDate != null &&
          BettyDateUtils.isDueOrOverdue(c.nextPaymentDate!)) {
        overduePayments++;
      }
    }

    final creditUtil =
        totalCreditLimit > 0 ? totalDebt / totalCreditLimit : 0.0;

    // 3. Progreso de metas
    final goals = await _isar.goalModels
        .filter()
        .userIdEqualTo(userId)
        .isActiveEqualTo(true)
        .isCompletedEqualTo(false)
        .findAll();

    double goalProgressAvg = 0;
    if (goals.isNotEmpty) {
      goalProgressAvg =
          goals.map((g) => g.progress).reduce((a, b) => a + b) / goals.length;
    }

    // 4. Calcular score (0-100)
    final score = _calculateScore(
      ratio: ratio,
      totalDebt: totalDebt,
      totalIncome: totalIncome,
      creditUtil: creditUtil,
      overduePayments: overduePayments,
      goalProgress: goalProgressAvg,
    );

    final hasActivity = totalIncome > 0 || totalDebt > 0 || goalProgressAvg > 0;
    final level = _scoreToLevel(score);
    final message = hasActivity
        ? _levelToMessage(level)
        : 'Registra tus ingresos y gastos para ver tu salud financiera. 📝';

    return HealthResult(
      score: score,
      level: level,
      message: message,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      expenseToIncomeRatio: ratio,
      totalDebt: totalDebt,
      overduePayments: overduePayments,
      creditUtilizationRatio: creditUtil,
      goalProgressAvg: goalProgressAvg,
    );
  }

  /// Calcula y persiste un snapshot en Isar.
  Future<HealthSnapshotModel> calculateAndSave(String userId) async {
    final result = await calculate(userId);
    final now = DateTime.now();

    final snapshot = HealthSnapshotModel()
      ..uuid = UuidGenerator.generate()
      ..userId = userId
      ..snapshotDate = now
      ..totalIncome = result.totalIncome
      ..totalExpenses = result.totalExpenses
      ..expenseToIncomeRatio = result.expenseToIncomeRatio
      ..totalDebt = result.totalDebt
      ..overduePayments = result.overduePayments
      ..creditUtilizationRatio = result.creditUtilizationRatio
      ..goalProgressAvg = result.goalProgressAvg
      ..healthScore = result.score
      ..healthLevel = SnapshotHealthLevel.values.byName(result.level.name)
      ..emotionalMessage = result.message
      ..createdAt = now
      ..syncStatus = SnapshotSyncStatus.pending;

    await _isar.writeTxn(() async {
      await _isar.healthSnapshotModels.put(snapshot);
    });

    return snapshot;
  }

  double _calculateScore({
    required double ratio,
    required double totalDebt,
    required double totalIncome,
    required double creditUtil,
    required int overduePayments,
    required double goalProgress,
  }) {
    // ── Guarda: sin datos financieros, no hay score válido ──
    // Si no hay ingresos, gastos, deuda ni metas, el usuario aún no
    // tiene actividad. Retornar 0 en vez de un score inflado.
    final hasActivity = totalIncome > 0 || totalDebt > 0 || goalProgress > 0;
    if (!hasActivity) return 0;

    // Componente 1: Ratio gasto/ingreso (35%)
    double ratioScore;
    if (ratio <= FinancialConstants.peaceThreshold) {
      ratioScore = 100;
    } else if (ratio <= FinancialConstants.stableThreshold) {
      ratioScore = 80;
    } else if (ratio <= FinancialConstants.warningThreshold) {
      ratioScore = 55;
    } else if (ratio <= FinancialConstants.dangerThreshold) {
      ratioScore = 30;
    } else {
      ratioScore = 10;
    }

    // Componente 2: Nivel de deuda vs ingreso (25%)
    double debtScore = 100;
    if (totalIncome > 0) {
      final debtRatio =
          totalDebt / (totalIncome * 12); // Deuda vs ingreso anual
      if (debtRatio > 1.0) {
        debtScore = 10;
      } else if (debtRatio > 0.5) {
        debtScore = 40;
      } else if (debtRatio > 0.3) {
        debtScore = 70;
      }
    }

    // Componente 3: Utilización de crédito (20%)
    double creditScore;
    if (creditUtil <= FinancialConstants.healthyCreditUtilization) {
      creditScore = 100;
    } else if (creditUtil <= FinancialConstants.dangerousCreditUtilization) {
      creditScore = 60;
    } else {
      creditScore = 20;
    }

    // Componente 4: Pagos vencidos (10%)
    double overdueScore =
        overduePayments == 0 ? 100 : (overduePayments == 1 ? 40 : 0);

    // Componente 5: Progreso de metas (10%)
    double goalScore = goalProgress * 100;

    return (ratioScore * FinancialConstants.weightExpenseRatio) +
        (debtScore * FinancialConstants.weightDebtLevel) +
        (creditScore * FinancialConstants.weightCreditUtilization) +
        (overdueScore * FinancialConstants.weightOverduePayments) +
        (goalScore * FinancialConstants.weightGoalProgress);
  }

 HealthLevel _scoreToLevel(double score) {
    if (score == 0) return HealthLevel.peace; // Sin datos = estado neutro
    if (score >= 80) return HealthLevel.peace;
    if (score >= 60) return HealthLevel.stable;
    if (score >= 40) return HealthLevel.warning;
    if (score >= 20) return HealthLevel.danger;
    return HealthLevel.crisis;
  }

  String _levelToMessage(HealthLevel level) {
    return switch (level) {
      HealthLevel.peace => 'Excelente. Estás en paz financiera. ✨',
      HealthLevel.stable => 'Vas bien. Mantén el ritmo. 👍',
      HealthLevel.warning => 'Cuidado. Tus gastos están creciendo. ⚠️',
      HealthLevel.danger => 'Alerta. Estás cerca del límite. 🔔',
      HealthLevel.crisis =>
        'Necesitas actuar. Tus gastos superan tus ingresos. 🚨',
    };
  }
}
