import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beti_app/core/constants/app_colors.dart';
import 'package:beti_app/core/enums/transaction_type.dart';
import 'package:beti_app/core/utils/platform_helper.dart';
import 'package:beti_app/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:beti_app/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:beti_app/features/financial_health/presentation/providers/health_provider.dart';

/// Pantalla de listado de transacciones con filtro por tipo.
class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() =>
      _TransactionsListScreenState();
}

class _TransactionsListScreenState
    extends ConsumerState<TransactionsListScreen> {
  TransactionType? _filter;

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Movimientos',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      PlatformHelper.isApple
                          ? CupertinoIcons.add_circled
                          : Icons.add_circle_outline,
                      size: 26,
                      color: AppColors.primary,
                    ),
                    onPressed: () => context.pushNamed('addTransaction'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Filtros ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Todos',
                    selected: _filter == null,
                    isDark: isDark,
                    onTap: () => setState(() => _filter = null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Gastos',
                    selected: _filter == TransactionType.expense,
                    isDark: isDark,
                    onTap: () => setState(() => _filter = TransactionType.expense),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Ingresos',
                    selected: _filter == TransactionType.income,
                    isDark: isDark,
                    onTap: () => setState(() => _filter = TransactionType.income),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Lista ──
            Expanded(
              child: txAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (transactions) {
                  final filtered = _filter != null
                      ? transactions.where((tx) => tx.type == _filter).toList()
                      : transactions;

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: isDark ? AppColors.grey : AppColors.lightGrey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filter != null
                                ? 'Sin ${_filter == TransactionType.expense ? "gastos" : "ingresos"} registrados'
                                : 'Sin movimientos aún',
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 0.5,
                      indent: 60,
                      color: isDark
                          ? AppColors.grey.withValues(alpha: 0.15)
                          : AppColors.lightGrey.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      final tx = filtered[index];
                      return Dismissible(
                        key: ValueKey(tx.uuid),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_outline, color: AppColors.expense),
                        ),
                        onDismissed: (_) {
                          ref.read(transactionsProvider.notifier).delete(tx.uuid);
                          ref.invalidate(healthProvider);
                        },
                        child: TransactionTile(transaction: tx),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : isDark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.3)
                : isDark
                    ? AppColors.grey.withValues(alpha: 0.2)
                    : AppColors.lightGrey.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppColors.primary
                : isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}
