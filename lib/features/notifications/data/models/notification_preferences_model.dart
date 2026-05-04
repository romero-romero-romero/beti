import 'package:isar/isar.dart';

part 'notification_preferences_model.g.dart';

/// Preferencias del reminder diario persistidas en Isar.
///
/// Solo existe UN documento en esta colección (id = 1).
/// Se accede siempre con `isar.notificationPreferencesModels.get(1)`.
@Collection()
class NotificationPreferencesModel {
  Id id = 1; // singleton

  /// Si el reminder diario está activo.
  bool dailyReminderEnabled = true;

  /// Hora del reminder (0-23).
  int reminderHour = 21;

  /// Minuto del reminder (0-59).
  int reminderMinute = 0;

  NotificationPreferencesModel();

  NotificationPreferencesModel copyWith({
    bool? dailyReminderEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return NotificationPreferencesModel()
      ..id = id
      ..dailyReminderEnabled = dailyReminderEnabled ?? this.dailyReminderEnabled
      ..reminderHour = reminderHour ?? this.reminderHour
      ..reminderMinute = reminderMinute ?? this.reminderMinute;
  }
}