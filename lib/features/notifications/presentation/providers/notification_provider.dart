import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beti_app/core/providers/core_providers.dart';
import 'package:beti_app/core/services/notification_service.dart';
import 'package:beti_app/features/notifications/data/models/notification_preferences_model.dart';

// ── Provider de preferencias (AsyncNotifier) ──────────────────────────────

final notificationPreferencesProvider = AsyncNotifierProvider<
    NotificationPreferencesNotifier, NotificationPreferencesModel>(
  NotificationPreferencesNotifier.new,
);

class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferencesModel> {
  @override
  Future<NotificationPreferencesModel> build() async {
    final isar = ref.watch(isarProvider);
    final stored = await isar.notificationPreferencesModels.get(1);
    // Primera vez: retorna defaults (no persiste hasta que el usuario cambie algo)
    return stored ?? NotificationPreferencesModel();
  }

  // ── Toggle reminder diario ───────────────────────────────────────────────

  Future<void> setDailyReminderEnabled(bool enabled) async {
    final current = state.valueOrNull ?? NotificationPreferencesModel();
    final updated = current.copyWith(dailyReminderEnabled: enabled);

    await _persist(updated);

    if (enabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: updated.reminderHour,
        minute: updated.reminderMinute,
      );
    } else {
      await NotificationService.instance.cancelDailyReminder();
    }

    state = AsyncData(updated);
  }

  // ── Cambiar hora del reminder ────────────────────────────────────────────

  Future<void> setReminderTime({required int hour, required int minute}) async {
    final current = state.valueOrNull ?? NotificationPreferencesModel();
    final updated = current.copyWith(
      reminderHour: hour,
      reminderMinute: minute,
    );

    await _persist(updated);

    // Solo re-programar si el reminder está activo
    if (updated.dailyReminderEnabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: hour,
        minute: minute,
      );
    }

    state = AsyncData(updated);
  }

  // ── Persistencia ─────────────────────────────────────────────────────────

  Future<void> _persist(NotificationPreferencesModel prefs) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      await isar.notificationPreferencesModels.put(prefs);
    });
  }
}