import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar/isar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:beti_app/core/utils/date_utils.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_model.dart';

/// Servicio de alertas locales programadas en el OS.
///
/// Programa notificaciones 3 días antes de:
/// - Fecha de corte de tarjetas de crédito
/// - Fecha límite de pago de tarjetas
/// - Fecha de pago de créditos/préstamos
///
/// Las notificaciones sobreviven reinicios del teléfono y
/// funcionan sin internet (programadas en el scheduler del OS).
class AlertScheduler {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  AlertScheduler._();

  // ═══════════════════════════════════════════════════════════
  // Inicialización
  // ═══════════════════════════════════════════════════════════

  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    _initialized = true;
    debugPrint('[AlertScheduler] Initialized');
  }

  /// Solicita permisos de notificación.
  static Future<bool> requestPermission() async {
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  // Programación de alertas
  // ═══════════════════════════════════════════════════════════

  static Future<void> rescheduleAll(Isar isar, String userId) async {
    if (!_initialized) await initialize();

    await _plugin.cancelAll();
    debugPrint('[AlertScheduler] Cancelled all previous alerts');

    int scheduled = 0;

    // Tarjetas de crédito
    final cards = await isar.creditCardModels
        .filter()
        .userIdEqualTo(userId)
        .isActiveEqualTo(true)
        .alertsEnabledEqualTo(true)
        .findAll();

    for (final card in cards) {
      // Alerta de corte
      final cutOffDate = BettyDateUtils.nextOccurrence(card.cutOffDay);
      final cutOffAlert = BettyDateUtils.alertDate(cutOffDate);

      if (cutOffAlert.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: _cardCutOffId(card.id),
          title: 'Corte próximo: ${card.name}',
          body: 'Tu fecha de corte es en 3 días '
              '(día ${card.cutOffDay}). Revisa tus consumos.',
          scheduledDate: cutOffAlert,
        );
        scheduled++;
      }

      // Alerta de pago
      final paymentDate =
          BettyDateUtils.nextOccurrence(card.paymentDueDay);
      final paymentAlert = BettyDateUtils.alertDate(paymentDate);

      if (paymentAlert.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: _cardPaymentId(card.id),
          title: 'Pago próximo: ${card.name}',
          body: 'Tu fecha límite de pago es en 3 días '
              '(día ${card.paymentDueDay}). Evita recargos.',
          scheduledDate: paymentAlert,
        );
        scheduled++;
      }
    }

    // Créditos / préstamos
    final credits = await isar.creditModels
        .filter()
        .userIdEqualTo(userId)
        .isActiveEqualTo(true)
        .alertsEnabledEqualTo(true)
        .findAll();

    for (final credit in credits) {
      final paymentDate =
          BettyDateUtils.nextOccurrence(credit.paymentDay);
      final paymentAlert = BettyDateUtils.alertDate(paymentDate);

      if (paymentAlert.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: _creditPaymentId(credit.id),
          title: 'Pago próximo: ${credit.name}',
          body: 'Tu pago de crédito vence en 3 días '
              '(día ${credit.paymentDay}). '
              'Monto: \$${credit.monthlyPayment.toStringAsFixed(0)}.',
          scheduledDate: paymentAlert,
        );
        scheduled++;
      }
    }

    debugPrint('[AlertScheduler] Scheduled $scheduled alerts');
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('[AlertScheduler] All alerts cancelled');
  }

  static Future<void> cancelForCard(int isarId) async {
    await _plugin.cancel(_cardCutOffId(isarId));
    await _plugin.cancel(_cardPaymentId(isarId));
  }

  static Future<void> cancelForCredit(int isarId) async {
    await _plugin.cancel(_creditPaymentId(isarId));
  }

  // ═══════════════════════════════════════════════════════════
  // Helpers privados
  // ═══════════════════════════════════════════════════════════

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    // Programar a las 9:00 AM del día de la alerta
    final alertAt = tz.TZDateTime(
      tz.local,
      tzDate.year,
      tzDate.month,
      tzDate.day,
      9,
      0,
    );

    if (alertAt.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      alertAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'betty_payment_alerts',
          'Alertas de pagos',
          channelDescription:
              'Recordatorios de fechas de corte y pago',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('[AlertScheduler] Scheduled #$id: $title at $alertAt');
  }

  static int _cardCutOffId(int isarId) => 10000 + isarId;
  static int _cardPaymentId(int isarId) => 20000 + isarId;
  static int _creditPaymentId(int isarId) => 30000 + isarId;
}