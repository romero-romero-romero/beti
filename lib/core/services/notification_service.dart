import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// IDs de canal / notificación — nunca reutilizar entre tipos distintos.
class NotificationIds {
  NotificationIds._();

  // ── Canales Android ──
  static const String channelAlertId = 'beti_alerts';
  static const String channelReminderId = 'beti_daily_reminder';

  // ── IDs de notificación (únicos en toda la app) ──
  // Rango 1000-1999: corte de tarjeta (1000 + índice de tarjeta)
  // Rango 2000-2999: pago de tarjeta  (2000 + índice de tarjeta)
  // 9000: reminder diario
  static const int dailyReminderId = 9000;

  static int cutOffId(int cardIndex) => 1000 + cardIndex;
  static int paymentId(int cardIndex) => 2000 + cardIndex;
}

/// Servicio singleton de notificaciones locales.
///
/// Responsabilidades:
///   1. Inicializar `FlutterLocalNotificationsPlugin` (una vez, en main).
///   2. Programar/cancelar el reminder diario.
///   3. Programar/cancelar alertas de corte y pago de tarjetas.
///
/// Todas las operaciones son idempotentes: programar dos veces el mismo ID
/// simplemente reemplaza la notificación anterior.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ════════════════════════════════════════════════════════════
  // Inicialización — llamar UNA vez en main() antes de runApp
  // ════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);
    await _createChannels();

    _initialized = true;
    debugPrint('[Notifications] Servicio inicializado.');
  }

  // ════════════════════════════════════════════════════════════
  // Permisos
  // ════════════════════════════════════════════════════════════

  /// Solicita permisos de notificación al usuario.
  /// Retorna `true` si fueron concedidos.
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }

    if (Platform.isAndroid) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return result ?? false;
    }

    return false;
  }

  // ════════════════════════════════════════════════════════════
  // Reminder diario
  // ════════════════════════════════════════════════════════════

  /// Programa el reminder diario a la [hour]:[minute] indicada.
  /// Si ya existía uno previo, lo cancela primero (reemplaza).
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await cancelDailyReminder();

    final scheduledTime = _nextInstanceOf(hour, minute);

    await _plugin.zonedSchedule(
      NotificationIds.dailyReminderId,
      '¿Ya registraste todo?',
      'Tómate un momento para anotar tus gastos e ingresos de hoy 💚',
      scheduledTime,
      _notificationDetails(channelId: NotificationIds.channelReminderId),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('[Notifications] Reminder diario programado: $hour:$minute');
  }

  /// Cancela el reminder diario si existe.
  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(NotificationIds.dailyReminderId);
    debugPrint('[Notifications] Reminder diario cancelado.');
  }

  // ════════════════════════════════════════════════════════════
  // Alertas de tarjeta — corte y pago
  // ════════════════════════════════════════════════════════════

  /// Programa las dos alertas de una tarjeta: 3 días antes del corte
  /// y 3 días antes del vencimiento de pago.
  Future<void> scheduleCardAlerts({
    required int cardIndex,
    required String cardName,
    required DateTime nextCutOff,
    required DateTime nextPaymentDue,
  }) async {
    await cancelCardAlerts(cardIndex);

    final cutOffAlert = nextCutOff.subtract(const Duration(days: 3));
    final paymentAlert = nextPaymentDue.subtract(const Duration(days: 3));
    final now = DateTime.now();

    if (cutOffAlert.isAfter(now)) {
      await _plugin.zonedSchedule(
        NotificationIds.cutOffId(cardIndex),
        'Corte próximo — $cardName',
        'Tu fecha de corte es el ${_dayMonth(nextCutOff)}. '
            'Revisa tu saldo antes de que cierre.',
        _toTz(cutOffAlert),
        _notificationDetails(channelId: NotificationIds.channelAlertId),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('[Notifications] Alerta corte $cardName → $cutOffAlert');
    }

    if (paymentAlert.isAfter(now)) {
      await _plugin.zonedSchedule(
        NotificationIds.paymentId(cardIndex),
        'Pago próximo — $cardName',
        'Tu fecha límite de pago es el ${_dayMonth(nextPaymentDue)}. '
            'No te quedes sin pagar.',
        _toTz(paymentAlert),
        _notificationDetails(channelId: NotificationIds.channelAlertId),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('[Notifications] Alerta pago $cardName → $paymentAlert');
    }
  }

  /// Cancela las dos alertas de una tarjeta.
  Future<void> cancelCardAlerts(int cardIndex) async {
    await _plugin.cancel(NotificationIds.cutOffId(cardIndex));
    await _plugin.cancel(NotificationIds.paymentId(cardIndex));
  }

  /// Cancela absolutamente todas las notificaciones programadas.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('[Notifications] Todas las notificaciones canceladas.');
  }

  // ════════════════════════════════════════════════════════════
  // Helpers privados
  // ════════════════════════════════════════════════════════════

  Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationIds.channelAlertId,
        'Alertas de tarjetas',
        description: 'Avisos de corte y pago de tus tarjetas',
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationIds.channelReminderId,
        'Recordatorio diario',
        description: 'Reminder para registrar transacciones del día',
        importance: Importance.defaultImportance,
      ),
    );
  }

  NotificationDetails _notificationDetails({required String channelId}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelId == NotificationIds.channelAlertId
            ? 'Alertas de tarjetas'
            : 'Recordatorio diario',
        importance: channelId == NotificationIds.channelAlertId
            ? Importance.high
            : Importance.defaultImportance,
        priority: channelId == NotificationIds.channelAlertId
            ? Priority.high
            : Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Calcula el próximo `TZDateTime` para la hora dada.
  /// Si ya pasó hoy, lo programa para mañana.
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _toTz(DateTime dt) => tz.TZDateTime.from(dt, tz.local);

  String _dayMonth(DateTime dt) => '${dt.day}/${dt.month}';
}