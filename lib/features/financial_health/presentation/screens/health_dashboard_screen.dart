import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:betty_app/core/constants/app_colors.dart';
import 'package:betty_app/core/utils/currency_formatter.dart';
import 'package:betty_app/core/utils/platform_helper.dart';
import 'package:betty_app/features/financial_health/presentation/providers/health_provider.dart';
import 'package:betty_app/features/financial_health/presentation/widgets/health_thermometer.dart';
import 'package:betty_app/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:betty_app/features/transactions/presentation/widgets/transaction_tile.dart';

/// Dashboard principal de Betty — Salud Financiera Emocional.
///
/// Diseño minimalista inspirado en el EJEMPLO-APP:
/// 1. Saludo + fecha
/// 2. Balance card con gradiente oscuro
/// 3. Termómetro de salud (barra horizontal)
/// 4. Últimos movimientos
class HealthDashboardScreen extends ConsumerWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(healthProvider);
    final txAsync = ref.watch(transactionsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(healthProvider);
            await ref.read(transactionsProvider.notifier).refresh();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Saludo + Fecha ──
                _buildGreeting(context, isDark),
                const SizedBox(height: 20),

                // ── Balance Card ──
                healthAsync.when(
                  loading: () => _BalanceCardSkeleton(isDark: isDark),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (health) => Column(
                    children: [
                      _BalanceCard(
                        balance: health.totalIncome - health.totalExpenses,
                        income: health.totalIncome,
                        expenses: health.totalExpenses,
                        isDark: isDark,
                        onAddTap: () => context.pushNamed('addTransaction'),
                      ),
                      const SizedBox(height: 16),

                      // ── Termómetro de Salud (barra) ──
                      _HealthSection(
                        score: health.score,
                        level: health.level,
                        message: health.message,
                        isDark: isDark,
                      ),

                      if (health.totalDebt > 0) ...[
                        const SizedBox(height: 12),
                        _DebtBanner(
                          debt: health.totalDebt,
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Últimos movimientos ──
                _buildRecentTransactions(context, ref, txAsync, theme, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context, bool isDark) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMM', 'es_MX').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateStr,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'Hola, Usuario ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const Text('👋', style: TextStyle(fontSize: 20)),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<dynamic> txAsync,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Últimos movimientos',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {}, // Navega a tab de movimientos
              child: Row(
                children: [
                  Text(
                    'Ver todos',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  Icon(
                    PlatformHelper.isApple
                        ? CupertinoIcons.chevron_right
                        : Icons.chevron_right,
                    size: 14,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        txAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (transactions) {
            if (transactions.isEmpty) {
              return _EmptyState(isDark: isDark);
            }

            final recent = transactions.take(4).toList();
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < recent.length; i++) ...[
                    TransactionTile(
                      transaction: recent[i],
                      onDelete: () {
                        ref.read(transactionsProvider.notifier).delete(recent[i].uuid);
                        ref.invalidate(healthProvider);
                      },
                    ),
                    if (i < recent.length - 1)
                      Divider(
                        height: 0.5,
                        indent: 60,
                        color: isDark
                            ? AppColors.grey.withValues(alpha: 0.15)
                            : AppColors.lightGrey.withValues(alpha: 0.3),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// Balance Card — Gradiente oscuro estilo EJEMPLO-APP
// ══════════════════════════════════════════════════════════
class _BalanceCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expenses;
  final bool isDark;
  final VoidCallback onAddTap;

  const _BalanceCard({
    required this.balance,
    required this.income,
    required this.expenses,
    required this.isDark,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? AppColors.balanceGradientDark
              : AppColors.balanceGradientLight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Balance total',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAddTap,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(balance),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),

          // ── Income / Expenses pills ──
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.arrow_downward_rounded,
                              size: 12, color: AppColors.income.withValues(alpha: 0.9)),
                          const SizedBox(width: 4),
                          Text(
                            'Ingresos',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${CurrencyFormatter.format(income)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.arrow_upward_rounded,
                              size: 12, color: AppColors.expense.withValues(alpha: 0.9)),
                          const SizedBox(width: 4),
                          Text(
                            'Gastos',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '-${CurrencyFormatter.format(expenses)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Health Section — Barra horizontal + label (estilo EJEMPLO-APP)
// ══════════════════════════════════════════════════════════
class _HealthSection extends StatelessWidget {
  final double score;
  final dynamic level;
  final String message;
  final bool isDark;

  const _HealthSection({
    required this.score,
    required this.level,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromHealthLevel(level);
    final emoji = AppColors.emojiForLevel(level);
    final bgColor = AppColors.healthBackground(level, isDark: isDark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // ── Header: emoji + label + score ──
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Salud financiera',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  Text(
                    _levelLabel(level),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${score.toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Barra de progreso ──
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (score / 100).clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.6),
                    valueColor: AlwaysStoppedAnimation(color),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Mensaje ──
          Text(
            message,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  String _levelLabel(dynamic level) {
    return switch (level) {
      _ when level.toString().contains('peace') => 'Paz financiera',
      _ when level.toString().contains('stable') => 'Estable',
      _ when level.toString().contains('warning') => 'Precaución',
      _ when level.toString().contains('danger') => 'Peligro',
      _ when level.toString().contains('crisis') => 'Necesitas actuar',
      _ => 'Calculando...',
    };
  }
}

// ══════════════════════════════════════════════════════════
// Debt Banner
// ══════════════════════════════════════════════════════════
class _DebtBanner extends StatelessWidget {
  final double debt;
  final bool isDark;

  const _DebtBanner({required this.debt, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.warning.withValues(alpha: 0.12)
            : AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.credit_card, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Text(
            'Deuda total',
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            CurrencyFormatter.format(debt),
            style: TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Empty State
// ══════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: isDark ? AppColors.grey : AppColors.lightGrey,
            ),
            const SizedBox(height: 8),
            Text(
              'Sin movimientos aún',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Registra tu primer gasto o ingreso',
              style: TextStyle(
                color: isDark ? AppColors.grey : AppColors.lightGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Skeleton loader for balance card
// ══════════════════════════════════════════════════════════
class _BalanceCardSkeleton extends StatelessWidget {
  final bool isDark;

  const _BalanceCardSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? AppColors.balanceGradientDark
              : AppColors.balanceGradientLight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white38,
        ),
      ),
    );
  }
}
