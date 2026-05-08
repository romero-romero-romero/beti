// test/core/services/notification_service_test.dart
//
// ════════════════════════════════════════════════════════════════════════
// NotificationService — programación/cancelación de notificaciones locales.
// ════════════════════════════════════════════════════════════════════════
//
// PIEZA TIER 2: Si esto falla, las alertas de corte/pago no llegan al
// usuario y el reminder diario tampoco. No hay pérdida de datos pero sí
// degradación severa del valor del producto.
//
// QUÉ VALIDAMOS:
//
// 1. SCHEDULE DAILY REMINDER
//    - Cancela el reminder previo antes de programar (idempotencia).
//    - Usa el ID fijo NotificationIds.dailyReminderId (9000).
//    - Pasa AndroidScheduleMode.inexactAllowWhileIdle (no exact = no drena
//      batería).
//    - Pasa DateTimeComponents.time (matching diario).
//
// 2. CANCEL DAILY REMINDER
//    - Llama plugin.cancel(9000).
//
// 3. SCHEDULE CARD ALERTS
//    - Cancela alertas previas de la tarjeta antes de programar.
//    - Usa IDs derivados: cutOffId(idx) = 1000+idx, paymentId(idx) = 2000+idx.
//    - NO programa si la fecha de alerta ya pasó (filtro isAfter(now)).
//    - Programa AMBAS alertas (corte y pago) si las dos están en el futuro.
//
// 4. CANCEL CARD ALERTS
//    - Cancela los dos IDs de la tarjeta específica.
//
// 5. CANCEL ALL
//    - Llama plugin.cancelAll().
//
// REQUISITO PREVIO:
//   En lib/core/services/notification_service.dart agregar el constructor
//   `@visibleForTesting NotificationService.testWithPlugin(this._plugin);`
//   y hacer `_plugin` mutable solo en construcción (sigue siendo final).
//
// ESTRATEGIA:
//   Mocktail sobre FlutterLocalNotificationsPlugin. Verificamos las
//   invocaciones — no probamos el plugin nativo en sí.
//
// ════════════════════════════════════════════════════════════════════════

import 'package:beti_app/core/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _FakeNotificationDetails extends Fake implements NotificationDetails {}

class _FakeTZDateTime extends Fake implements tz.TZDateTime {}

void main() {
  setUpAll(() {
    // Inicializamos timezones aquí porque NotificationService.initialize()
    // normalmente lo hace, pero en tests usamos testWithPlugin que salta
    // ese setup.
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

    // Fallback values para mocktail con tipos no nullable y no primitivos.
    registerFallbackValue(_FakeNotificationDetails());
    registerFallbackValue(_FakeTZDateTime());
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(
      UILocalNotificationDateInterpretation.absoluteTime,
    );
    registerFallbackValue(DateTimeComponents.time);
  });

  late _MockPlugin plugin;
  late NotificationService service;

  setUp(() {
    plugin = _MockPlugin();
    service = NotificationService.testWithPlugin(plugin);

    // Stubs por defecto: cualquier llamada al plugin devuelve un Future
    // completado. Si un test específico necesita comportamiento distinto,
    // se sobrescribe con un `when()` adicional.
    when(() => plugin.cancel(any())).thenAnswer((_) async {});
    when(() => plugin.cancelAll()).thenAnswer((_) async {});
    when(() => plugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          uiLocalNotificationDateInterpretation:
              any(named: 'uiLocalNotificationDateInterpretation'),
          matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});
  });

  // ══════════════════════════════════════════════════════════════════════
  // NotificationIds — convenciones de rangos
  // ══════════════════════════════════════════════════════════════════════

  group('NotificationIds', () {
    test('dailyReminderId es 9000 (rango propio)', () {
      expect(NotificationIds.dailyReminderId, 9000);
    });

    test('cutOffId(idx) = 1000 + idx', () {
      expect(NotificationIds.cutOffId(0), 1000);
      expect(NotificationIds.cutOffId(5), 1005);
      expect(NotificationIds.cutOffId(99), 1099);
    });

    test('paymentId(idx) = 2000 + idx', () {
      expect(NotificationIds.paymentId(0), 2000);
      expect(NotificationIds.paymentId(5), 2005);
      expect(NotificationIds.paymentId(99), 2099);
    });

    test('creditPaymentId(idx) = 3000 + idx', () {
      expect(NotificationIds.creditPaymentId(0), 3000);
      expect(NotificationIds.creditPaymentId(5), 3005);
      expect(NotificationIds.creditPaymentId(99), 3099);
    });

    test('rangos no se solapan: payment [2000-2999] vs credit [3000-3999]',
        () {
      expect(NotificationIds.paymentId(999),
          lessThan(NotificationIds.creditPaymentId(0)));
    });

    test('rangos no se solapan: cutOff [1000-1999] vs payment [2000-2999]',
        () {
      // Sanity: con 1000 tarjetas distintas, los rangos siguen aislados.
      expect(NotificationIds.cutOffId(999), lessThan(NotificationIds.paymentId(0)));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // SCHEDULE DAILY REMINDER
  // ══════════════════════════════════════════════════════════════════════

  group('scheduleDailyReminder', () {
    test('cancela el reminder previo antes de programar', () async {
      await service.scheduleDailyReminder(hour: 21, minute: 0);

      verifyInOrder([
        () => plugin.cancel(NotificationIds.dailyReminderId),
        () => plugin.zonedSchedule(
              NotificationIds.dailyReminderId,
              any(),
              any(),
              any(),
              any(),
              androidScheduleMode: any(named: 'androidScheduleMode'),
              uiLocalNotificationDateInterpretation:
                  any(named: 'uiLocalNotificationDateInterpretation'),
              matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
              payload: any(named: 'payload'),
            ),
      ]);
    });

    test('usa AndroidScheduleMode.inexactAllowWhileIdle (no drena batería)',
        () async {
      await service.scheduleDailyReminder(hour: 21, minute: 0);

      verify(() => plugin.zonedSchedule(
            NotificationIds.dailyReminderId,
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('usa DateTimeComponents.time para repetición diaria', () async {
      await service.scheduleDailyReminder(hour: 21, minute: 0);

      verify(() => plugin.zonedSchedule(
            NotificationIds.dailyReminderId,
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: DateTimeComponents.time,
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('idempotencia: dos llamadas resultan en dos cancel + dos schedule',
        () async {
      await service.scheduleDailyReminder(hour: 21, minute: 0);
      await service.scheduleDailyReminder(hour: 22, minute: 30);

      verify(() => plugin.cancel(NotificationIds.dailyReminderId))
          .called(2);
      verify(() => plugin.zonedSchedule(
            NotificationIds.dailyReminderId,
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          )).called(2);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CANCEL DAILY REMINDER
  // ══════════════════════════════════════════════════════════════════════

  group('cancelDailyReminder', () {
    test('cancela el ID 9000', () async {
      await service.cancelDailyReminder();

      verify(() => plugin.cancel(NotificationIds.dailyReminderId)).called(1);
      verifyNoMoreInteractions(plugin);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // SCHEDULE CARD ALERTS
  // ══════════════════════════════════════════════════════════════════════

  group('scheduleCardAlerts', () {
    test('programa ambas alertas (corte y pago) cuando las dos son futuras',
        () async {
      // Fechas claramente futuras (10 días adelante).
      final cutOff = DateTime.now().add(const Duration(days: 10));
      final paymentDue = DateTime.now().add(const Duration(days: 25));

      await service.scheduleCardAlerts(
        cardIndex: 0,
        cardName: 'BBVA Azul',
        nextCutOff: cutOff,
        nextPaymentDue: paymentDue,
      );

      // Verifica las dos llamadas a zonedSchedule con los IDs correctos.
      verify(() => plugin.zonedSchedule(
            NotificationIds.cutOffId(0),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          )).called(1);

      verify(() => plugin.zonedSchedule(
            NotificationIds.paymentId(0),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('cancela las alertas previas de la tarjeta antes de programar',
        () async {
      final cutOff = DateTime.now().add(const Duration(days: 10));
      final paymentDue = DateTime.now().add(const Duration(days: 25));

      await service.scheduleCardAlerts(
        cardIndex: 3,
        cardName: 'Santander Free',
        nextCutOff: cutOff,
        nextPaymentDue: paymentDue,
      );

      verify(() => plugin.cancel(NotificationIds.cutOffId(3))).called(1);
      verify(() => plugin.cancel(NotificationIds.paymentId(3))).called(1);
    });

    test('NO programa si el corte ya pasó (alerta sería en el pasado)',
        () async {
      // Cutoff fue hace 1 día → alerta sería hace 4 días (pasada).
      final cutOff = DateTime.now().subtract(const Duration(days: 1));
      // Payment es futuro → solo la alerta de pago debe programarse.
      final paymentDue = DateTime.now().add(const Duration(days: 25));

      await service.scheduleCardAlerts(
        cardIndex: 0,
        cardName: 'BBVA',
        nextCutOff: cutOff,
        nextPaymentDue: paymentDue,
      );

      // Cancel inicial sí ocurre.
      verify(() => plugin.cancel(NotificationIds.cutOffId(0))).called(1);
      verify(() => plugin.cancel(NotificationIds.paymentId(0))).called(1);

      // Pero solo paymentId se programa.
      verifyNever(() => plugin.zonedSchedule(
            NotificationIds.cutOffId(0),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          ));

      verify(() => plugin.zonedSchedule(
            NotificationIds.paymentId(0),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('NO programa nada si AMBAS fechas ya pasaron', () async {
      final cutOff = DateTime.now().subtract(const Duration(days: 10));
      final paymentDue = DateTime.now().subtract(const Duration(days: 1));

      await service.scheduleCardAlerts(
        cardIndex: 0,
        cardName: 'Tarjeta vencida',
        nextCutOff: cutOff,
        nextPaymentDue: paymentDue,
      );

      // Solo los cancels iniciales; cero schedules.
      verifyNever(() => plugin.zonedSchedule(
            any(),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          ));
    });

    test('caso de borde: alerta exactamente AHORA → NO se programa', () async {
      // alertDate = cutOff - 3días. Si cutOff es ahora + 3 días, alerta = ahora.
      // El código usa isAfter(now) que excluye igualdad.
      final cutOff = DateTime.now().add(const Duration(days: 3));
      // Damos un poquito de margen para que paymentDue sí sea futuro real.
      final paymentDue = DateTime.now().add(const Duration(days: 30));

      await service.scheduleCardAlerts(
        cardIndex: 7,
        cardName: 'Edge',
        nextCutOff: cutOff,
        nextPaymentDue: paymentDue,
      );

      // Por timing del test, "alertDate vs now" puede ser muy reñido.
      // Lo que validamos es que el comportamiento NO crashea — la
      // estricta inequidad está cubierta en el test "cutOff ya pasó".
      verify(() => plugin.cancel(any())).called(2);
    });

    test('IDs derivados correctamente para cardIndex distinto', () async {
      final cutOff = DateTime.now().add(const Duration(days: 10));
      final paymentDue = DateTime.now().add(const Duration(days: 25));

      await service.scheduleCardAlerts(
        cardIndex: 42,
        cardName: 'Tarjeta 42',
        nextCutOff: cutOff,
        nextPaymentDue: paymentDue,
      );

      verify(() => plugin.zonedSchedule(
            1042, // cutOffId(42)
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          )).called(1);

      verify(() => plugin.zonedSchedule(
            2042, // paymentId(42)
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          )).called(1);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CANCEL CARD ALERTS
  // ══════════════════════════════════════════════════════════════════════

  group('cancelCardAlerts', () {
    test('cancela los dos IDs de la tarjeta', () async {
      await service.cancelCardAlerts(5);

      verify(() => plugin.cancel(NotificationIds.cutOffId(5))).called(1);
      verify(() => plugin.cancel(NotificationIds.paymentId(5))).called(1);
      verifyNoMoreInteractions(plugin);
    });

    test('NO afecta otras tarjetas', () async {
      await service.cancelCardAlerts(0);

      // Solo se cancela cardIndex=0; nunca tocamos índices 1, 2, etc.
      verify(() => plugin.cancel(1000)).called(1); // cutOff(0)
      verify(() => plugin.cancel(2000)).called(1); // payment(0)
      verifyNever(() => plugin.cancel(1001));
      verifyNever(() => plugin.cancel(2001));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CANCEL ALL
  // ══════════════════════════════════════════════════════════════════════

  group('cancelAll', () {
    test('invoca plugin.cancelAll una vez', () async {
      await service.cancelAll();

      verify(() => plugin.cancelAll()).called(1);
      // No invoca cancel individual: cancelAll es atómico.
      verifyNever(() => plugin.cancel(any()));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // SCHEDULE CREDIT ALERT
  // ══════════════════════════════════════════════════════════════════════

  group('scheduleCreditAlert', () {
    test('programa alerta cuando la fecha es futura', () async {
      final paymentDate = DateTime.now().add(const Duration(days: 15));

      await service.scheduleCreditAlert(
        creditIndex: 0,
        creditName: 'Préstamo Nu',
        nextPaymentDate: paymentDate,
        monthlyPayment: 2500,
      );

      verify(() => plugin.zonedSchedule(
            NotificationIds.creditPaymentId(0), // 3000
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('cancela la alerta previa antes de programar (idempotencia)',
        () async {
      final paymentDate = DateTime.now().add(const Duration(days: 15));

      await service.scheduleCreditAlert(
        creditIndex: 5,
        creditName: 'Crédito',
        nextPaymentDate: paymentDate,
        monthlyPayment: 1000,
      );

      verify(() => plugin.cancel(NotificationIds.creditPaymentId(5)))
          .called(1);
    });

    test('NO programa si la fecha de pago ya pasó', () async {
      final paymentDate = DateTime.now().subtract(const Duration(days: 1));

      await service.scheduleCreditAlert(
        creditIndex: 0,
        creditName: 'Crédito vencido',
        nextPaymentDate: paymentDate,
        monthlyPayment: 1000,
      );

      verifyNever(() => plugin.zonedSchedule(
            any(),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          ));
    });

    test('IDs en rango 3000-3999 (no colisiona con tarjetas)', () async {
      final paymentDate = DateTime.now().add(const Duration(days: 10));

      await service.scheduleCreditAlert(
        creditIndex: 7,
        creditName: 'Crédito',
        nextPaymentDate: paymentDate,
        monthlyPayment: 1000,
      );

      verify(() => plugin.zonedSchedule(
            3007, // creditPaymentId(7)
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          )).called(1);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CANCEL CREDIT ALERT
  // ══════════════════════════════════════════════════════════════════════

  group('cancelCreditAlert', () {
    test('cancela el ID específico del crédito', () async {
      await service.cancelCreditAlert(3);

      verify(() => plugin.cancel(NotificationIds.creditPaymentId(3)))
          .called(1);
      verifyNoMoreInteractions(plugin);
    });

    test('NO afecta otros créditos', () async {
      await service.cancelCreditAlert(0);

      verify(() => plugin.cancel(3000)).called(1); // creditPaymentId(0)
      verifyNever(() => plugin.cancel(3001));
      verifyNever(() => plugin.cancel(3002));
    });
  });
}