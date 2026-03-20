import 'package:flutter/material.dart';
import 'package:betty_app/core/enums/category_type.dart';
import 'package:betty_app/core/enums/transaction_type.dart';
import 'package:betty_app/core/utils/currency_formatter.dart';
import 'package:betty_app/features/transactions/domain/entities/transaction_entity.dart';

/// Widget para mostrar una transacción en una lista.
class TransactionTile extends StatelessWidget {
  final TransactionEntity transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final color = isExpense ? Colors.red : Colors.green;

    return Dismissible(
      key: Key(transaction.uuid),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade100,
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar'),
            content: const Text('¿Estás seguro de eliminar este movimiento?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Text(_categoryEmoji(transaction.category), style: const TextStyle(fontSize: 20)),
        ),
        title: Text(
          transaction.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${transaction.transactionDate.day}/${transaction.transactionDate.month}/${transaction.transactionDate.year}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          '${isExpense ? "-" : "+"}${CurrencyFormatter.format(transaction.amount)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  String _categoryEmoji(CategoryType cat) {
    return switch (cat) {
      CategoryType.food => '🍽️',
      CategoryType.groceries => '🛒',
      CategoryType.transport => '🚗',
      CategoryType.housing => '🏠',
      CategoryType.utilities => '💡',
      CategoryType.health => '🏥',
      CategoryType.education => '📚',
      CategoryType.entertainment => '🎬',
      CategoryType.clothing => '👕',
      CategoryType.subscriptions => '📱',
      CategoryType.debtPayment => '💳',
      CategoryType.personalCare => '✨',
      CategoryType.gifts => '🎁',
      CategoryType.pets => '🐾',
      CategoryType.salary => '💰',
      CategoryType.freelance => '💻',
      CategoryType.investment => '📈',
      CategoryType.refund => '↩️',
      CategoryType.otherIncome => '📌',
      CategoryType.other => '📌',
    };
  }
}
