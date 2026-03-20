import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/core/constants/app_colors.dart';
import 'package:betty_app/core/utils/platform_helper.dart';

/// Pantalla de Presupuestos y Metas de Ahorro.
///
/// Tabs: Presupuestos | Metas
/// Cada sección muestra barras de progreso minimalistas.
class BudgetsGoalsScreen extends ConsumerStatefulWidget {
  const BudgetsGoalsScreen({super.key});

  @override
  ConsumerState<BudgetsGoalsScreen> createState() =>
      _BudgetsGoalsScreenState();
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
            // ── Header ──
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

            // ── Tab selector ──
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

            // ── Content ──
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
                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }
}

class _BudgetsContent extends StatelessWidget {
  final bool isDark;

  const _BudgetsContent({required this.isDark});

  @override
  Widget build(BuildContext context) {
    // TODO: Conectar con budgets provider
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: isDark ? AppColors.grey : AppColors.lightGrey,
            ),
            const SizedBox(height: 12),
            Text(
              'Configura tus presupuestos',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Define límites por categoría para\ncontrolar tus gastos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar presupuesto'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalsContent extends StatelessWidget {
  final bool isDark;

  const _GoalsContent({required this.isDark});

  @override
  Widget build(BuildContext context) {
    // TODO: Conectar con goals provider
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 48,
              color: isDark ? AppColors.grey : AppColors.lightGrey,
            ),
            const SizedBox(height: 12),
            Text(
              'Crea tu primera meta',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Define un objetivo de ahorro y\nsigue tu progreso',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva meta'),
            ),
          ],
        ),
      ),
    );
  }
}
