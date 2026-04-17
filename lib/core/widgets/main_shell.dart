import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beti_app/core/constants/app_colors.dart';
import 'package:beti_app/core/utils/platform_helper.dart';
import 'package:beti_app/features/financial_health/presentation/screens/health_dashboard_screen.dart';
import 'package:beti_app/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:beti_app/features/cards_credits/presentation/screens/cards_screen.dart';
import 'package:beti_app/features/budgets_goals/presentation/screens/budgets_goals_screen.dart';
import 'package:beti_app/features/profile/presentation/screens/profile_screen.dart';

/// Shell principal adaptivo.
///
/// - **iOS**: Scaffold + CupertinoTabBar (estética nativa sin conflicto
///   con el framework de build targets de MaterialApp.router).
/// - **Android**: Scaffold + NavigationBar (Material 3).
///
/// Ambos usan IndexedStack para preservar el estado de cada pestaña.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  static const _screens = [
    HealthDashboardScreen(),
    TransactionsListScreen(),
    CardsScreen(),
    BudgetsGoalsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isApple) {
      return _buildCupertinoShell(context);
    }
    return _buildMaterialShell(context);
  }

  // ══════════════════════════════════════════════════════════
  // iOS — Scaffold + CupertinoTabBar
  // ══════════════════════════════════════════════════════════
  Widget _buildCupertinoShell(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        activeColor: AppColors.primary,
        inactiveColor: isDark
            ? AppColors.lightGrey.withValues(alpha: 0.6)
            : AppColors.grey,
        backgroundColor: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.95)
            : AppColors.surfaceLight.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.grey.withValues(alpha: 0.15)
                : AppColors.lightGrey.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.heart),
            activeIcon: Icon(CupertinoIcons.heart_fill),
            label: 'Salud',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.doc_text),
            activeIcon: Icon(CupertinoIcons.doc_text_fill),
            label: 'Movimientos',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.creditcard),
            activeIcon: Icon(CupertinoIcons.creditcard_fill),
            label: 'Tarjetas',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.flag),
            activeIcon: Icon(CupertinoIcons.flag_fill),
            label: 'Metas',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            activeIcon: Icon(CupertinoIcons.person_fill),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Android — Material 3 NavigationBar
  // ══════════════════════════════════════════════════════════
  Widget _buildMaterialShell(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Salud',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Movimientos',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_card_outlined),
            selectedIcon: Icon(Icons.credit_card),
            label: 'Tarjetas',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Metas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
