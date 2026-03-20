import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:betty_app/core/constants/app_colors.dart';
import 'package:betty_app/core/utils/currency_formatter.dart';
import 'package:betty_app/features/financial_health/presentation/providers/health_provider.dart';
import 'package:betty_app/features/financial_health/presentation/widgets/health_thermometer.dart';
import 'package:betty_app/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:betty_app/features/transactions/presentation/widgets/transaction_tile.dart';

/// Dashboard principal de Betty — Salud Financiera Emocional.
class HealthDashboardScreen extends ConsumerWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(healthProvider);
    final txAsync = ref.watch(transactionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
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
                // ── Header ──
                Row(
                  children: [
                    Text(
                      'Betty',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 28),
                      onPressed: () => context.pushNamed('addTransaction'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Termómetro ──
                healthAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (health) => Column(
                    children: [
                      Center(
                        child: HealthThermometer(
                          score: health.score,
                          level: health.level,
                          message: health.message,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Resumen rápido ──
                      Row(
                        children: [
                          _StatCard(
                            label: 'Ingresos',
                            value: CurrencyFormatter.format(health.totalIncome),
                            color: AppColors.income,
                            icon: Icons.arrow_upward_rounded,
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            label: 'Gastos',
                            value: CurrencyFormatter.format(health.totalExpenses),
                            color: AppColors.expense,
                            icon: Icons.arrow_downward_rounded,
                          ),
                        ],
                      ),
                      if (health.totalDebt > 0) ...[
                        const SizedBox(height: 12),
                        _WideStatCard(
                          label: 'Deuda total',
                          value: CurrencyFormatter.format(health.totalDebt),
                          color: AppColors.warning,
                          icon: Icons.credit_card,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Últimos movimientos ──
                Row(
                  children: [
                    Text(
                      'Últimos movimientos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.goNamed('transactions'),
                      child: const Text('Ver todos'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                txAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 40, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text(
                                'Sin movimientos aún',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final recent = transactions.take(5).toList();
                    return Card(
                      child: Column(
                        children: recent.map((tx) {
                          return TransactionTile(
                            transaction: tx,
                            onDelete: () {
                              ref.read(transactionsProvider.notifier).delete(tx.uuid);
                              ref.invalidate(healthProvider);
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _WideStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
