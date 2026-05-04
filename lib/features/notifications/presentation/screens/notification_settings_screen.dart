import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beti_app/core/services/notification_service.dart';
import 'package:beti_app/features/notifications/presentation/providers/notification_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        centerTitle: true,
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (prefs) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ── Sección reminder diario ──────────────────────────────────
            _SectionHeader(label: 'Recordatorio diario'),

            _SettingsTile(
              title: '¿Ya registraste todo?',
              subtitle: 'Beti te preguntará cada día si completaste '
                  'el registro de tus transacciones.',
              trailing: CupertinoSwitch(
                value: prefs.dailyReminderEnabled,
                activeTrackColor: Theme.of(context).colorScheme.primary,
                onChanged: (enabled) async {
                  // Pedir permisos la primera vez que activa
                  if (enabled) {
                    final granted = await NotificationService
                        .instance
                        .requestPermissions();
                    if (!granted) {
                      if (context.mounted) {
                        _showPermissionDeniedDialog(context);
                      }
                      return;
                    }
                  }
                  await ref
                      .read(notificationPreferencesProvider.notifier)
                      .setDailyReminderEnabled(enabled);
                },
              ),
            ),

            // Hora del reminder — solo visible si está activo
            if (prefs.dailyReminderEnabled)
              _SettingsTile(
                title: 'Hora del recordatorio',
                subtitle: _formatTime(prefs.reminderHour, prefs.reminderMinute),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickTime(context, ref, prefs.reminderHour,
                    prefs.reminderMinute),
              ),

            const Divider(height: 32),

            // ── Sección alertas de tarjetas ──────────────────────────────
            _SectionHeader(label: 'Alertas de tarjetas'),

            _SettingsTile(
              title: 'Corte y pago',
              subtitle: 'Beti te avisará 3 días antes de tu fecha de '
                  'corte y de tu fecha límite de pago.',
              trailing: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.green,
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Las alertas de tarjeta se programan automáticamente '
                'cuando agregas o editas una tarjeta.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Time picker ──────────────────────────────────────────────────────────

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    int currentHour,
    int currentMinute,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
      helpText: 'Hora del recordatorio',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );

    if (picked == null) return;

    await ref
        .read(notificationPreferencesProvider.notifier)
        .setReminderTime(hour: picked.hour, minute: picked.minute);
  }

  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permisos requeridos'),
        content: const Text(
          'Para recibir recordatorios, permite las notificaciones '
          'de Beti en los ajustes de tu dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

// ── Widgets internos ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle,
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55))),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}