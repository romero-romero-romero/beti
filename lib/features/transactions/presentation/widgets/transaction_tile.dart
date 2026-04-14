import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:betty_app/core/constants/app_colors.dart';
import 'package:betty_app/core/enums/category_type.dart';
import 'package:betty_app/core/enums/transaction_type.dart';
import 'package:betty_app/core/utils/currency_formatter.dart';
import 'package:betty_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:betty_app/core/enums/payment_method.dart';

/// Tile de transacción minimalista inspirado en el EJEMPLO-APP.
///
/// - Círculo con ícono de flecha (verde ingreso / rojo gasto)
/// - Descripción + categoría + fecha
/// - Monto con color
class TransactionTile extends StatelessWidget {
  final TransactionEntity transaction;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final color = isExpense ? AppColors.expense : AppColors.income;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ── Ícono circular ──
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? color.withValues(alpha: 0.15)
                    : color.withValues(alpha: 0.1),
              ),
              child: Icon(
                isExpense
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),

            // ── Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description.isNotEmpty
                        ? transaction.description
                        : _categoryLabel(transaction.category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        _categoryLabel(transaction.category),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '·',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.grey.withValues(alpha: 0.5)
                                : AppColors.lightGrey,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('d MMM', 'es_MX').format(transaction.transactionDate),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      if (transaction.paymentMethod != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '·',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.grey.withValues(alpha: 0.5)
                                  : AppColors.lightGrey,
                            ),
                          ),
                        ),
                        Icon(
                          _paymentIcon(transaction.paymentMethod!),
                          size: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Monto ──
            Text(
              '${isExpense ? "-" : "+"}${CurrencyFormatter.format(transaction.amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(CategoryType cat) {
    return switch (cat) {
      CategoryType.food => 'Comida',
      CategoryType.groceries => 'Despensa',
      CategoryType.transport => 'Transporte',
      CategoryType.housing => 'Casa',
      CategoryType.utilities => 'Servicios',
      CategoryType.health => 'Salud',
      CategoryType.education => 'Educación',
      CategoryType.entertainment => 'Entretenimiento',
      CategoryType.clothing => 'Ropa',
      CategoryType.subscriptions => 'Suscripciones',
      CategoryType.debtPayment => 'Deudas',
      CategoryType.personalCare => 'Cuidado personal',
      CategoryType.gifts => 'Regalos',
      CategoryType.pets => 'Mascotas',
      CategoryType.salary => 'Salario',
      CategoryType.freelance => 'Freelance',
      CategoryType.investment => 'Inversión',
      CategoryType.refund => 'Reembolso',
      CategoryType.otherIncome => 'Otro ingreso',
      CategoryType.other => 'Otro',
    };
  }

  IconData _paymentIcon(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => Icons.money_rounded,
        PaymentMethod.debitCard => Icons.credit_card_outlined,
        PaymentMethod.creditCard => Icons.credit_card,
        PaymentMethod.transfer => Icons.swap_horiz_rounded,
        PaymentMethod.other => Icons.more_horiz,
      };
}
