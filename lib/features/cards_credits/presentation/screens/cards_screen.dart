import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/core/constants/app_colors.dart';
import 'package:betty_app/core/utils/platform_helper.dart';

/// Pantalla de Tarjetas de Crédito — rediseñada con estética minimalista.
///
/// Muestra las tarjetas vinculadas con su utilización,
/// fechas de corte/pago y estado de alertas.
class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Text(
                'Tarjetas',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Administra tus tarjetas y créditos',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 20),

              // ── Empty state placeholder ──
              // TODO: Conectar con cards_credits provider cuando esté listo
              _EmptyCardsState(isDark: isDark),

              const SizedBox(height: 20),

              // ── Botón agregar ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Navegar a agregar tarjeta
                  },
                  icon: Icon(
                    PlatformHelper.isApple
                        ? CupertinoIcons.add
                        : Icons.add,
                    size: 18,
                  ),
                  label: const Text('Vincular tarjeta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCardsState extends StatelessWidget {
  final bool isDark;

  const _EmptyCardsState({required this.isDark});

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
          Icon(
            Icons.credit_card_outlined,
            size: 48,
            color: isDark ? AppColors.grey : AppColors.lightGrey,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin tarjetas vinculadas',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Vincula tu primera tarjeta para recibir\nalertas de corte y pago',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
