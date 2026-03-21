import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:betty_app/core/constants/app_colors.dart';
import 'package:betty_app/core/utils/currency_formatter.dart';
import 'package:betty_app/core/utils/platform_helper.dart';
import 'package:betty_app/features/cards_credits/presentation/providers/cards_credits_provider.dart';
import 'package:betty_app/features/cards_credits/domain/entities/credit_card_entity.dart';
import 'package:betty_app/features/cards_credits/domain/entities/credit_entity.dart';

class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(creditCardsProvider);
    final creditsAsync = ref.watch(creditsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await ref.read(creditCardsProvider.notifier).refresh();
            await ref.read(creditsProvider.notifier).refresh();
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
                      'Tarjetas y créditos',
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
                      onPressed: () => context.pushNamed('addCard'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Controla tus deudas y fechas de pago',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Tarjetas de crédito ──
                cardsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, _) => Text('Error: $e'),
                  data: (cards) {
                    if (cards.isEmpty) {
                      return _EmptyState(
                        icon: Icons.credit_card_outlined,
                        title: 'Sin tarjetas',
                        subtitle:
                            'Agrega tu primera tarjeta para\nrecibir alertas de corte y pago',
                        isDark: isDark,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tarjetas de crédito',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...cards.map((card) => _CreditCardTile(
                              card: card,
                              isDark: isDark,
                              onDelete: () => ref
                                  .read(creditCardsProvider.notifier)
                                  .deleteCard(card.uuid),
                            )),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ── Créditos / Préstamos ──
                creditsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => Text('Error: $e'),
                  data: (credits) {
                    if (credits.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Créditos y préstamos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...credits.map((credit) => _CreditTile(
                              credit: credit,
                              isDark: isDark,
                              onDelete: () => ref
                                  .read(creditsProvider.notifier)
                                  .deleteCredit(credit.uuid),
                            )),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // ── Botón agregar ──
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.pushNamed('addCard'),
                    icon: Icon(
                      PlatformHelper.isApple ? CupertinoIcons.add : Icons.add,
                      size: 18,
                    ),
                    label: const Text('Agregar tarjeta o crédito'),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Credit Card Tile
// ─────────────────────────────────────────────────────────

class _CreditCardTile extends StatelessWidget {
  final CreditCardEntity card;
  final bool isDark;
  final VoidCallback onDelete;

  const _CreditCardTile({
    required this.card,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final util = card.utilizationPercent;
    final utilColor = util <= 30
        ? AppColors.primary
        : util <= 60
            ? AppColors.warning
            : AppColors.expense;

    return Dismissible(
      key: ValueKey(card.uuid),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.expense),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar tarjeta'),
            content: Text('¿Eliminar "${card.name}"?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Eliminar',
                      style: TextStyle(color: AppColors.expense))),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: nombre + red ──
            Row(
              children: [
                Icon(_networkIcon(card.network.name), size: 20, color: utilColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    card.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                if (card.lastFourDigits != null)
                  Text(
                    '•••• ${card.lastFourDigits}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Saldo / Límite ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saldo: ${CurrencyFormatter.format(card.currentBalance)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                Text(
                  'Límite: ${CurrencyFormatter.format(card.creditLimit)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Barra de utilización ──
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (util / 100).clamp(0.0, 1.0),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(utilColor),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),

            // ── Utilización + Fechas ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${util.toStringAsFixed(0)}% utilizado',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: utilColor,
                  ),
                ),
                Text(
                  'Corte: ${card.cutOffDay} · Pago: ${card.paymentDueDay}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _networkIcon(String network) {
    return switch (network) {
      'visa' => Icons.credit_card,
      'mastercard' => Icons.credit_card,
      'amex' => Icons.credit_score,
      _ => Icons.credit_card_outlined,
    };
  }
}

// ─────────────────────────────────────────────────────────
// Credit/Loan Tile
// ─────────────────────────────────────────────────────────

class _CreditTile extends StatelessWidget {
  final CreditEntity credit;
  final bool isDark;
  final VoidCallback onDelete;

  const _CreditTile({
    required this.credit,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = credit.progressPercent;

    return Dismissible(
      key: ValueKey(credit.uuid),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.expense),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar crédito'),
            content: Text('¿Eliminar "${credit.name}"?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Eliminar',
                      style: TextStyle(color: AppColors.expense))),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_outlined,
                    size: 18, color: AppColors.stable),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    credit.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                if (credit.institution != null)
                  Text(
                    credit.institution!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Debes: ${CurrencyFormatter.format(credit.currentBalance)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                Text(
                  'Mensualidad: ${CurrencyFormatter.format(credit.monthlyPayment)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (progress / 100).clamp(0.0, 1.0),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.toStringAsFixed(0)}% pagado',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Pago día ${credit.paymentDay}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48,
              color: isDark ? AppColors.grey : AppColors.lightGrey),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}