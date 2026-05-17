import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beti_app/core/constants/app_colors.dart';
import 'package:beti_app/core/utils/platform_helper.dart';
import 'package:beti_app/core/providers/theme_provider.dart';
import 'package:beti_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:beti_app/features/profile/presentation/providers/data_export_provider.dart';

/// Pantalla de Perfil con configuraciones.
///
/// Usa CupertinoListSection en iOS, Card en Android.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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
                'Perfil',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // ── Avatar + Nombre ──
              Builder(builder: (_) {
                final authState = ref.watch(authProvider);
                String displayName = 'Usuario';
                String email = '';
                String initials = 'U';

                if (authState is AuthAuthenticated) {
                  final user = authState.user;
                  email = user.email;

                  if (user.displayName != null &&
                      user.displayName!.trim().isNotEmpty) {
                    displayName = user.displayName!.trim();
                    // Iniciales: primera letra de cada palabra (máx 2)
                    final parts = displayName
                        .split(' ')
                        .where((p) => p.isNotEmpty)
                        .toList();
                    initials = parts.length >= 2
                        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
                        : parts[0][0].toUpperCase();
                  } else if (email.contains('@')) {
                    displayName = email.split('@').first;
                    initials = displayName[0].toUpperCase();
                  }
                }

                return Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 32),

              // ── Sección Preferencias ──
              // ── Sección Preferencias ──
              _SectionHeader(title: 'Preferencias', isDark: isDark),
              const SizedBox(height: 8),
              _SettingsCard(
                isDark: isDark,
                children: [
                  Builder(builder: (rowContext) {
                    final themeMode = ref.watch(themeModeProvider);
                    return _SettingsRow(
                      icon: PlatformHelper.isApple
                          ? CupertinoIcons.moon
                          : Icons.dark_mode_outlined,
                      title: 'Tema',
                      subtitle: _themeModeLabel(themeMode),
                      isDark: isDark,
                      trailing: Icon(
                        PlatformHelper.isApple
                            ? CupertinoIcons.chevron_right
                            : Icons.chevron_right,
                        size: 18,
                        color: isDark ? AppColors.grey : AppColors.lightGrey,
                      ),
                      onTap: () => _showThemePicker(rowContext, ref, themeMode),
                    );
                  }),
                  _SettingsDivider(isDark: isDark),
                  _SettingsRow(
                    icon: PlatformHelper.isApple
                        ? CupertinoIcons.bell
                        : Icons.notifications_outlined,
                    title: 'Notificaciones',
                    subtitle: 'Alertas de corte y pago',
                    isDark: isDark,
                    trailing: Icon(
                      PlatformHelper.isApple
                          ? CupertinoIcons.chevron_right
                          : Icons.chevron_right,
                      size: 18,
                      color: isDark ? AppColors.grey : AppColors.lightGrey,
                    ),
                    onTap: () => context.pushNamed('notificationSettings'),
                  ),
                  _SettingsDivider(isDark: isDark),
                  _SettingsRow(
                    icon: PlatformHelper.isApple
                        ? CupertinoIcons.money_dollar_circle
                        : Icons.attach_money,
                    title: 'Moneda',
                    subtitle: 'MXN — Peso mexicano',
                    isDark: isDark,
                    trailing: Icon(
                      PlatformHelper.isApple
                          ? CupertinoIcons.chevron_right
                          : Icons.chevron_right,
                      size: 18,
                      color: isDark ? AppColors.grey : AppColors.lightGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Sección Datos ──
              _SectionHeader(title: 'Datos', isDark: isDark),
              const SizedBox(height: 8),
              _SettingsCard(
                isDark: isDark,
                children: [
                  _SettingsRow(
                    icon: PlatformHelper.isApple
                        ? CupertinoIcons.cloud_download
                        : Icons.cloud_download_outlined,
                    title: 'Exportar datos',
                    subtitle: 'Genera un CSV de tus transacciones',
                    isDark: isDark,
                    trailing: Icon(
                      PlatformHelper.isApple
                          ? CupertinoIcons.chevron_right
                          : Icons.chevron_right,
                      size: 18,
                      color: isDark ? AppColors.grey : AppColors.lightGrey,
                    ),
                    onTap: () => _exportData(context, ref),
                  ),
                  // "Borrar todos los datos" — pendiente diseño de UX
                  // (confirmación doble, manejo de sesión, sync remoto).
                  // Se reintroduce en una iteración futura.
                ],
              ),
              const SizedBox(height: 24),

              // ── Cerrar Sesión ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cerrar sesión'),
                        content: const Text(
                          'Se borrarán todos los datos locales. '
                          'Tus datos respaldados en la nube se mantendrán.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.expense,
                            ),
                            child: const Text('Cerrar sesión'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(authProvider.notifier).signOut();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    side: BorderSide(
                        color: AppColors.expense.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Cerrar sesión'),
                ),
              ),

              const SizedBox(height: 16),

              if (kDebugMode) ...[
                const SizedBox(height: 24),
                _SectionHeader(title: 'Desarrollador', isDark: isDark),
                const SizedBox(height: 8),
                _SettingsCard(
                  isDark: isDark,
                  children: [
                    _SettingsRow(
                      icon: Icons.bug_report_outlined,
                      title: 'OCR Evaluator',
                      subtitle: 'Evaluar tickets en lote [DEV]',
                      isDark: isDark,
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: isDark ? AppColors.grey : AppColors.lightGrey,
                      ),
                      onTap: () => context.goNamed('ocrEvaluator'),
                    ),
                  ],
                ),
              ],

              // ── Versión ──
              Center(
                child: Text(
                  'Beti v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.grey : AppColors.lightGrey,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Widgets auxiliares de settings
// ══════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color:
            isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _SettingsCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final Widget? trailing;
  final VoidCallback? onTap; 
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.trailing,
    this.onTap, // ← y esto
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.grey.withValues(alpha: 0.15)
                    : AppColors.offWhite,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  final bool isDark;

  const _SettingsDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      indent: 64,
      color: isDark
          ? AppColors.grey.withValues(alpha: 0.15)
          : AppColors.lightGrey.withValues(alpha: 0.3),
    );
  }
}

String _themeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.system:
      return 'Sistema';
    case ThemeMode.light:
      return 'Claro';
    case ThemeMode.dark:
      return 'Oscuro';
  }
}

Future<void> _showThemePicker(
  BuildContext context,
  WidgetRef ref,
  ThemeMode current,
) async {
  final selected = await showModalBottomSheet<ThemeMode>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tema',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            for (final mode in ThemeMode.values)
              RadioListTile<ThemeMode>(
                title: Text(_themeModeLabel(mode)),
                value: mode,
                groupValue: current,
                onChanged: (val) => Navigator.of(sheetContext).pop(val),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  // Si el sheet se cerró sin selección (tap fuera, swipe), no hacemos nada.
  if (selected == null || selected == current) return;

  // Aplicar cambio. ref sigue siendo válido aquí porque el sheet bloquea
  // navegación mientras está abierto.
  await ref.read(themeModeProvider.notifier).setThemeMode(selected);
}

Future<void> _exportData(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(dataExportServiceProvider);

  if (service == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Necesitas iniciar sesión para exportar.'),
      ),
    );
    return;
  }

  try {
    await service.exportTransactionsAsCsv();
    // No mostramos SnackBar de éxito: el share sheet del sistema ya es
    // confirmación suficiente. Si el usuario cancela, no hay "fallo".
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('No se pudo exportar: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
