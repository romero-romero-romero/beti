import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/core/constants/app_colors.dart';
import 'package:betty_app/core/utils/platform_helper.dart';
import 'package:betty_app/features/auth/presentation/providers/auth_provider.dart';

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

                  if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
                    displayName = user.displayName!.trim();
                    // Iniciales: primera letra de cada palabra (máx 2)
                    final parts = displayName.split(' ').where((p) => p.isNotEmpty).toList();
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
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 32),

              // ── Sección Preferencias ──
              _SectionHeader(title: 'Preferencias', isDark: isDark),
              const SizedBox(height: 8),
              _SettingsCard(
                isDark: isDark,
                children: [
                  _SettingsRow(
                    icon: PlatformHelper.isApple
                        ? CupertinoIcons.moon
                        : Icons.dark_mode_outlined,
                    title: 'Modo oscuro',
                    subtitle: 'Seguir sistema',
                    isDark: isDark,
                    trailing: PlatformHelper.isApple
                        ? CupertinoSwitch(
                            value: isDark,
                            activeTrackColor: AppColors.primary,
                            onChanged: (_) {
                              // TODO: Implementar toggle de tema
                            },
                          )
                        : Switch(
                            value: isDark,
                            activeColor: AppColors.primary,
                            onChanged: (_) {},
                          ),
                  ),
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
                    subtitle: 'JSON o CSV',
                    isDark: isDark,
                    trailing: Icon(
                      PlatformHelper.isApple
                          ? CupertinoIcons.chevron_right
                          : Icons.chevron_right,
                      size: 18,
                      color: isDark ? AppColors.grey : AppColors.lightGrey,
                    ),
                  ),
                  _SettingsDivider(isDark: isDark),
                  _SettingsRow(
                    icon: PlatformHelper.isApple
                        ? CupertinoIcons.trash
                        : Icons.delete_outline,
                    title: 'Borrar todos los datos',
                    subtitle: 'Esta acción no se puede deshacer',
                    isDark: isDark,
                    titleColor: AppColors.expense,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Cerrar Sesión ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).signOut();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    side: BorderSide(color: AppColors.expense.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Cerrar sesión'),
                ),
              ),
              const SizedBox(height: 16),

              // ── Versión ──
              Center(
                child: Text(
                  'Betty v1.0.0',
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
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
  final Color? titleColor;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.trailing,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              color: titleColor ??
                  (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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
                    color: titleColor ??
                        (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
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
