import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:betty_app/core/constants/app_colors.dart';
import 'package:betty_app/core/enums/category_type.dart';
import 'package:betty_app/core/utils/platform_helper.dart';
import 'package:betty_app/features/budgets_goals/presentation/providers/budgets_goals_provider.dart';
import 'package:betty_app/features/financial_education/presentation/widgets/term_info_icon.dart';

/// Pantalla para agregar o editar un presupuesto mensual.
class AddBudgetScreen extends ConsumerStatefulWidget {
  const AddBudgetScreen({super.key});

  @override
  ConsumerState<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends ConsumerState<AddBudgetScreen> {
  final _amountController = TextEditingController();
  CategoryType _selectedCategory = CategoryType.food;

  /// Solo categorías de gasto (no ingresos).
  static const _expenseCategories = [
    CategoryType.food,
    CategoryType.groceries,
    CategoryType.transport,
    CategoryType.housing,
    CategoryType.utilities,
    CategoryType.health,
    CategoryType.education,
    CategoryType.entertainment,
    CategoryType.clothing,
    CategoryType.subscriptions,
    CategoryType.debtPayment,
    CategoryType.personalCare,
    CategoryType.gifts,
    CategoryType.pets,
    CategoryType.other,
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _categoryLabel(CategoryType cat) {
    return switch (cat) {
      CategoryType.food => 'Comida',
      CategoryType.groceries => 'Despensa / Súper',
      CategoryType.transport => 'Transporte',
      CategoryType.housing => 'Vivienda',
      CategoryType.utilities => 'Servicios',
      CategoryType.health => 'Salud',
      CategoryType.education => 'Educación',
      CategoryType.entertainment => 'Entretenimiento',
      CategoryType.clothing => 'Ropa',
      CategoryType.subscriptions => 'Suscripciones',
      CategoryType.debtPayment => 'Pago de deudas',
      CategoryType.personalCare => 'Cuidado personal',
      CategoryType.gifts => 'Regalos',
      CategoryType.pets => 'Mascotas',
      CategoryType.other => 'Otros',
      _ => cat.name,
    };
  }

  IconData _categoryIcon(CategoryType cat) {
    return switch (cat) {
      CategoryType.food => Icons.restaurant,
      CategoryType.groceries => Icons.shopping_cart,
      CategoryType.transport => Icons.directions_car,
      CategoryType.housing => Icons.home,
      CategoryType.utilities => Icons.bolt,
      CategoryType.health => Icons.favorite,
      CategoryType.education => Icons.school,
      CategoryType.entertainment => Icons.movie,
      CategoryType.clothing => Icons.checkroom,
      CategoryType.subscriptions => Icons.subscriptions,
      CategoryType.debtPayment => Icons.credit_card,
      CategoryType.personalCare => Icons.spa,
      CategoryType.gifts => Icons.card_giftcard,
      CategoryType.pets => Icons.pets,
      CategoryType.other => Icons.more_horiz,
      _ => Icons.category,
    };
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    await ref.read(budgetsProvider.notifier).addBudget(
          categoryKey: _selectedCategory.name,
          amount: amount,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Presupuesto guardado'),
          backgroundColor: AppColors.primary,
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo presupuesto'),
        leading: IconButton(
          icon: Icon(
              PlatformHelper.isApple ? CupertinoIcons.back : Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Categoría ──
            Row(
              children: [
                Text(
                  'Categoría',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(width: 4),
                const TermInfoIcon(termKey: 'expense_category'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _expenseCategories.map((cat) {
                final selected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : (isDark
                              ? AppColors.surfaceDark
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(20),
                      border: selected
                          ? Border.all(color: AppColors.primary, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _categoryIcon(cat),
                          size: 16,
                          color: selected
                              ? AppColors.primary
                              : (isDark ? AppColors.grey : Colors.grey),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _categoryLabel(cat),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Monto ──
            Text(
              'Límite mensual',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '0.00',
                filled: true,
                fillColor: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 32),

            // ── Guardar ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Guardar presupuesto',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
