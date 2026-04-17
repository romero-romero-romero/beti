import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:betty_app/core/constants/app_colors.dart';
import 'package:betty_app/core/utils/currency_formatter.dart';
import 'package:betty_app/features/budgets_goals/presentation/providers/budgets_goals_provider.dart';
import 'package:betty_app/features/budgets_goals/data/services/budget_spending_calculator.dart';
import 'package:intl/intl.dart';

class BudgetsGoalsScreen extends ConsumerStatefulWidget {
  const BudgetsGoalsScreen({super.key});

  @override
  ConsumerState<BudgetsGoalsScreen> createState() => _BudgetsGoalsScreenState();
}

class _BudgetsGoalsScreenState extends ConsumerState<BudgetsGoalsScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'Metas',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _TabButton(
                    label: 'Presupuestos',
                    selected: _tabIndex == 0,
                    isDark: isDark,
                    onTap: () => setState(() => _tabIndex = 0),
                  ),
                  const SizedBox(width: 8),
                  _TabButton(
                    label: 'Metas de ahorro',
                    selected: _tabIndex == 1,
                    isDark: isDark,
                    onTap: () => setState(() => _tabIndex = 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _tabIndex == 0
                  ? _BudgetsContent(isDark: isDark)
                  : _GoalsContent(isDark: isDark),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Tab Button
// ══════════════════════════════════════════════════════════════

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.surfaceDark : AppColors.black)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? (isDark ? AppColors.textPrimaryDark : Colors.white)
                : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Budgets Content — Conectado a datos reales
// ══════════════════════════════════════════════════════════════

class _BudgetsContent extends ConsumerWidget {
  final bool isDark;
  const _BudgetsContent({required this.isDark});

  static const _categoryLabels = {
    'food': 'Comida',
    'groceries': 'Despensa',
    'transport': 'Transporte',
    'housing': 'Vivienda',
    'utilities': 'Servicios',
    'health': 'Salud',
    'education': 'Educación',
    'entertainment': 'Entretenimiento',
    'clothing': 'Ropa',
    'subscriptions': 'Suscripciones',
    'debtPayment': 'Deudas',
    'personalCare': 'Cuidado personal',
    'gifts': 'Regalos',
    'pets': 'Mascotas',
    'other': 'Otros',
  };

  static const _categoryIcons = {
    'food': Icons.restaurant,
    'groceries': Icons.shopping_cart,
    'transport': Icons.directions_car,
    'housing': Icons.home,
    'utilities': Icons.bolt,
    'health': Icons.favorite,
    'education': Icons.school,
    'entertainment': Icons.movie,
    'clothing': Icons.checkroom,
    'subscriptions': Icons.subscriptions,
    'debtPayment': Icons.credit_card,
    'personalCare': Icons.spa,
    'gifts': Icons.card_giftcard,
    'pets': Icons.pets,
    'other': Icons.more_horiz,
  };

  Color _statusColor(BudgetCategoryStatus status) {
    return switch (status) {
      BudgetCategoryStatus.green => AppColors.primary,
      BudgetCategoryStatus.yellow => Colors.amber.shade700,
      BudgetCategoryStatus.red => Colors.red,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final summaryAsync = ref.watch(budgetMonthSummaryProvider);
    final selected = ref.watch(selectedPeriodProvider);
    final now = DateTime.now();
    final isCurrentMonth =
        selected.year == now.year && selected.month == now.month;

    return budgetsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (budgets) {
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async =>
              ref.read(budgetsProvider.notifier).recalculate(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              // ── Selector de mes ──
              _MonthSelector(
                year: selected.year,
                month: selected.month,
                isDark: isDark,
                onPrevious: () {
                  final prev = selected.month == 1
                      ? (year: selected.year - 1, month: 12)
                      : (year: selected.year, month: selected.month - 1);
                  ref.read(selectedPeriodProvider.notifier).state = prev;
                  ref.invalidate(budgetsProvider);
                },
                onNext: isCurrentMonth
                    ? null
                    : () {
                        final next = selected.month == 12
                            ? (year: selected.year + 1, month: 1)
                            : (year: selected.year, month: selected.month + 1);
                        ref.read(selectedPeriodProvider.notifier).state = next;
                        ref.invalidate(budgetsProvider);
                      },
              ),
              const SizedBox(height: 16),

              // ── Resumen mensual de gastos ──
              if (budgets.isNotEmpty)
                summaryAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (summary) {
                    if (summary == null) return const SizedBox.shrink();
                    return _MonthSummaryCard(summary: summary, isDark: isDark);
                  },
                ),
              if (budgets.isNotEmpty) const SizedBox(height: 16),

              // ── Lista de presupuestos o empty state ──
              if (budgets.isEmpty)
                _EmptyBudgets(isDark: isDark)
              else
                ...budgets.map((b) => _BudgetTile(
                      budget: b,
                      label: _categoryLabels[b.categoryKey] ?? b.categoryKey,
                      icon: _categoryIcons[b.categoryKey] ?? Icons.category,
                      statusColor: _statusColor(b.status),
                      isDark: isDark,
                      onDelete: isCurrentMonth
                          ? () => ref
                              .read(budgetsProvider.notifier)
                              .deleteBudget(b.uuid)
                          : null,
                    )),

              // ── Botón agregar (solo mes actual) ──
              if (isCurrentMonth) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.pushNamed('addBudget'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar presupuesto'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyBudgets extends StatelessWidget {
  final bool isDark;
  const _EmptyBudgets({required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.pie_chart_outline,
              size: 48, color: isDark ? AppColors.grey : AppColors.lightGrey),
          const SizedBox(height: 12),
          Text('Configura tus presupuestos',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight)),
          const SizedBox(height: 4),
          Text('Define límites por categoría para\ncontrolar tus gastos',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight)),
        ],
      ),
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  final BudgetMonthSummary summary;
  final bool isDark;
  const _MonthSummaryCard({required this.summary, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = switch (summary.healthLevel) {
      BudgetHealthLevel.green => AppColors.primary,
      BudgetHealthLevel.yellow => Colors.amber.shade700,
      BudgetHealthLevel.red => Colors.red,
    };
    final pct = (summary.overallRatio * 100).clamp(0, 999).toStringAsFixed(0);
    final unassigned = summary.totalIncome - summary.totalBudgeted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ingresos del mes ──
          if (summary.totalIncome > 0) ...[
            Text('Ingresos del mes',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight)),
            const SizedBox(height: 2),
            Text(CurrencyFormatter.format(summary.totalIncome),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight)),
            const SizedBox(height: 12),
          ],

          // ── Gastos vs presupuesto ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gastos vs presupuesto',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight)),
                    const SizedBox(height: 2),
                    Text(
                        '${CurrencyFormatter.format(summary.totalExpenses)} de ${CurrencyFormatter.format(summary.totalBudgeted)}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight)),
                    const SizedBox(height: 2),
                    Text(
                        'Disponible: ${CurrencyFormatter.format(summary.available)}',
                        style: TextStyle(fontSize: 12, color: color)),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15)),
                child: Center(
                  child: Text('$pct%',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
              ),
            ],
          ),

          // ── Sin asignar ──
          if (summary.totalIncome > 0 && summary.totalBudgeted > 0) ...[
            const SizedBox(height: 10),
            Text(
                unassigned >= 0
                    ? 'Sin asignar: ${CurrencyFormatter.format(unassigned)}'
                    : 'Presupuesto excede ingresos por ${CurrencyFormatter.format(-unassigned)}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: unassigned >= 0
                        ? AppColors.primary
                        : Colors.red.shade400)),
          ],
        ],
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  final BudgetEntity budget;
  final String label;
  final IconData icon;
  final Color statusColor;
  final bool isDark;
  final VoidCallback? onDelete;

  const _BudgetTile({
    required this.budget,
    required this.label,
    required this.icon,
    required this.statusColor,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pct =
        (budget.consumptionRatio * 100).clamp(0, 999).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight)),
                      Text(
                          '${CurrencyFormatter.format(budget.spentAmount)} de ${CurrencyFormatter.format(budget.budgetedAmount)}',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
                Text('$pct%',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: statusColor)),
                const SizedBox(width: 8),
                if (onDelete != null)
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(Icons.close,
                        size: 16,
                        color: isDark ? AppColors.grey : Colors.grey.shade400),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: budget.consumptionRatio.clamp(0, 1),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final int year;
  final int month;
  final bool isDark;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  const _MonthSelector({
    required this.year,
    required this.month,
    required this.isDark,
    required this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime(year, month);
    final label = toBeginningOfSentenceCase(
      DateFormat('MMMM yyyy', 'es_MX').format(date),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left, size: 24),
          visualDensity: VisualDensity.compact,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right, size: 24),
          visualDensity: VisualDensity.compact,
          color: onNext != null
              ? (isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight)
              : Colors.transparent,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Goals Content — Conectado a datos reales
// ══════════════════════════════════════════════════════════════

class _GoalsContent extends ConsumerWidget {
  final bool isDark;
  const _GoalsContent({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return goalsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (goals) {
        if (goals.isEmpty) {
          return _EmptyGoals(isDark: isDark);
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(goalsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              ...goals.map((g) => _GoalTile(goal: g, isDark: isDark, ref: ref)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.pushNamed('addGoal'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva meta'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  final bool isDark;
  const _EmptyGoals({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined,
                size: 48, color: isDark ? AppColors.grey : AppColors.lightGrey),
            const SizedBox(height: 12),
            Text('Crea tu primera meta',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight)),
            const SizedBox(height: 4),
            Text('Define un objetivo de ahorro y\nsigue tu progreso',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => context.pushNamed('addGoal'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva meta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final GoalEntity goal;
  final bool isDark;
  final WidgetRef ref;

  const _GoalTile(
      {required this.goal, required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    final pct = (goal.progress * 100).clamp(0, 999).toStringAsFixed(0);
    final color = goal.isCompleted ? AppColors.primary : Colors.blue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                    goal.isCompleted ? Icons.check_circle : Icons.flag_outlined,
                    size: 20,
                    color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight)),
                      Text(
                          '${CurrencyFormatter.format(goal.savedAmount)} de ${CurrencyFormatter.format(goal.targetAmount)}',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
                Text('$pct%',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () =>
                      ref.read(goalsProvider.notifier).deleteGoal(goal.uuid),
                  child: Icon(Icons.close,
                      size: 16,
                      color: isDark ? AppColors.grey : Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: goal.progress.clamp(0, 1),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
              ),
            ),
            if (goal.suggestedMonthlyContribution != null &&
                !goal.isCompleted) ...[
              const SizedBox(height: 6),
              Text(
                'Ahorra ${CurrencyFormatter.format(goal.suggestedMonthlyContribution!)} /mes para cumplir a tiempo',
                style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
            ],
            if (goal.deadline != null) ...[
              const SizedBox(height: 4),
              Text(
                'Fecha límite: ${goal.deadline!.day}/${goal.deadline!.month}/${goal.deadline!.year}',
                style: TextStyle(
                    fontSize: 10, color: isDark ? AppColors.grey : Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
