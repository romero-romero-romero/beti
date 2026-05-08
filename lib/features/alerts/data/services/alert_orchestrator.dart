// lib/features/alerts/data/services/alert_orchestrator.dart
//
// ════════════════════════════════════════════════════════════════════════
// AlertOrchestrator — orquesta alertas a partir del estado de Isar.
// ════════════════════════════════════════════════════════════════════════
//
// REEMPLAZA a `AlertScheduler` con dos diferencias clave:
//
// 1. SEPARACIÓN DE RESPONSABILIDADES
//    - Este servicio: leer Isar y decidir QUÉ programar.
//    - NotificationService: CÓMO programar (canales, IDs, IDs únicos,
//      idempotencia, debug logs).
//    - Resultado: el código aquí es testeable sin tocar el plugin nativo.
//
// 2. CANCELACIÓN QUIRÚRGICA
//    - AlertScheduler hacía `cancelAll()` antes de reprogramar, lo cual
//      mataba también el reminder diario.
//    - Aquí cancelamos por ID específico, dejando intactas alertas de
//      otros tipos.
//
// USO:
//   - Llamado desde `alertProvider` cada vez que cambia el estado de
//     auth o se invalida (después de modificar tarjetas/créditos).
//
// ════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';

import 'package:beti_app/core/services/notification_service.dart';
import 'package:beti_app/core/utils/date_utils.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_model.dart';

class AlertOrchestrator {
  final Isar _isar;
  final NotificationService _notifications;

  AlertOrchestrator({
    required Isar isar,
    NotificationService? notifications,
  })  : _isar = isar,
        _notifications = notifications ?? NotificationService.instance;

  /// Reprograma TODAS las alertas del usuario a partir del estado actual
  /// de Isar.
  ///
  /// Idempotente: cada alerta cancela la previa antes de programar.
  /// Solo procesa items con `isActive=true` y `alertsEnabled=true`.
  ///
  /// Retorna la cantidad de alertas que quedaron programadas.
  Future<int> rescheduleAll(String userId) async {
    final cardCount = await _rescheduleCards(userId);
    final creditCount = await _rescheduleCredits(userId);
    final total = cardCount + creditCount;
    debugPrint('[AlertOrchestrator] $total alertas programadas '
        '($cardCount tarjetas, $creditCount créditos)');
    return total;
  }

  /// Cancela las alertas de una tarjeta específica.
  /// Llamar al desactivar/eliminar una tarjeta.
  Future<void> cancelCard(int cardIsarId) async {
    await _notifications.cancelCardAlerts(cardIsarId);
  }

  /// Cancela la alerta de un crédito específico.
  /// Llamar al desactivar/eliminar un crédito.
  Future<void> cancelCredit(int creditIsarId) async {
    await _notifications.cancelCreditAlert(creditIsarId);
  }

  // ══════════════════════════════════════════════════════════
  // Privados
  // ══════════════════════════════════════════════════════════

  Future<int> _rescheduleCards(String userId) async {
    final cards = await _isar.creditCardModels
        .filter()
        .userIdEqualTo(userId)
        .isActiveEqualTo(true)
        .alertsEnabledEqualTo(true)
        .findAll();

    var scheduled = 0;
    for (final card in cards) {
      final cutOff = BettyDateUtils.nextOccurrence(card.cutOffDay);
      final payment = BettyDateUtils.nextOccurrence(card.paymentDueDay);

      await _notifications.scheduleCardAlerts(
        cardIndex: card.id,
        cardName: card.name,
        nextCutOff: cutOff,
        nextPaymentDue: payment,
      );
      // Cada call programa hasta 2 alertas (corte + pago) si ambas son
      // futuras. NotificationService filtra internamente las pasadas,
      // así que aquí asumimos el caso optimista.
      scheduled += 2;
    }
    return scheduled;
  }

  Future<int> _rescheduleCredits(String userId) async {
    final credits = await _isar.creditModels
        .filter()
        .userIdEqualTo(userId)
        .isActiveEqualTo(true)
        .alertsEnabledEqualTo(true)
        .findAll();

    var scheduled = 0;
    for (final credit in credits) {
      final paymentDate = BettyDateUtils.nextOccurrence(credit.paymentDay);

      await _notifications.scheduleCreditAlert(
        creditIndex: credit.id,
        creditName: credit.name,
        nextPaymentDate: paymentDate,
        monthlyPayment: credit.monthlyPayment,
      );
      scheduled += 1;
    }
    return scheduled;
  }
}