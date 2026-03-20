import 'package:flutter/material.dart';
import 'package:betty_app/core/enums/category_type.dart';

/// Bottom sheet para seleccionar categoría manualmente.
class CategoryPicker extends StatelessWidget {
  final CategoryType currentCategory;
  final bool isIncome;
  final ValueChanged<CategoryType> onSelected;

  const CategoryPicker({
    super.key,
    required this.currentCategory,
    required this.isIncome,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories = isIncome ? _incomeCategories : _expenseCategories;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Selecciona categoría',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final entry = categories[index];
                  final isSelected = entry.type == currentCategory;

                  return ListTile(
                    leading: Text(entry.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(entry.label),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                        : null,
                    selected: isSelected,
                    onTap: () => onSelected(entry.type),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryEntry {
  final CategoryType type;
  final String label;
  final String emoji;

  const _CategoryEntry(this.type, this.label, this.emoji);
}

const _expenseCategories = [
  _CategoryEntry(CategoryType.food, 'Alimentación', '🍽️'),
  _CategoryEntry(CategoryType.groceries, 'Supermercado', '🛒'),
  _CategoryEntry(CategoryType.transport, 'Transporte', '🚗'),
  _CategoryEntry(CategoryType.housing, 'Vivienda', '🏠'),
  _CategoryEntry(CategoryType.utilities, 'Servicios', '💡'),
  _CategoryEntry(CategoryType.health, 'Salud', '🏥'),
  _CategoryEntry(CategoryType.education, 'Educación', '📚'),
  _CategoryEntry(CategoryType.entertainment, 'Entretenimiento', '🎬'),
  _CategoryEntry(CategoryType.clothing, 'Ropa', '👕'),
  _CategoryEntry(CategoryType.subscriptions, 'Suscripciones', '📱'),
  _CategoryEntry(CategoryType.debtPayment, 'Pago de deudas', '💳'),
  _CategoryEntry(CategoryType.personalCare, 'Cuidado personal', '✨'),
  _CategoryEntry(CategoryType.gifts, 'Regalos', '🎁'),
  _CategoryEntry(CategoryType.pets, 'Mascotas', '🐾'),
  _CategoryEntry(CategoryType.other, 'Otro', '📌'),
];

const _incomeCategories = [
  _CategoryEntry(CategoryType.salary, 'Nómina', '💰'),
  _CategoryEntry(CategoryType.freelance, 'Freelance', '💻'),
  _CategoryEntry(CategoryType.investment, 'Inversión', '📈'),
  _CategoryEntry(CategoryType.refund, 'Reembolso', '↩️'),
  _CategoryEntry(CategoryType.otherIncome, 'Otro ingreso', '📌'),
];
