// lib/features/budgets_goals/data/services/budget_alert_engine.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:betty_app/features/budgets_goals/data/models/budget_model.dart';

/// Evalúa presupuestos y dispara notificaciones locales instantáneas
/// cuando se superan los umbrales de gasto (80% y 100%).
///
/// A diferencia de AlertScheduler (que programa notificaciones futuras
/// para fechas de corte/pago), este motor dispara alertas INMEDIATAS
/// cuando un gasto recién registrado cruza un umbral.
class BudgetAlertEngine {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Umbral de advertencia (amarillo).
  static const double _warningThreshold = 0.8;

  /// Umbral de exceso (rojo).
  static const double _exceededThreshold = 1.0;

  /// IDs de notificación para presupuestos: 40000 + hash del categoryKey.
  static int _notificationId(String categoryKey, bool isExceeded) {
    final base = categoryKey.hashCode.abs() % 10000;
    return isExceeded ? 50000 + base : 40000 + base;
  }

  /// Evalúa una lista de presupuestos y dispara notificaciones
  /// para los que crucen umbrales.
  ///
  /// Se llama después de recalcular spentAmount.
  static Future<void> evaluate(List<BudgetModel> budgets) async {
    for (final budget in budgets) {
      if (budget.budgetedAmount <= 0) continue;

      final ratio = budget.spentAmount / budget.budgetedAmount;
      final label = _categoryLabel(budget.categoryKey);

      if (ratio >= _exceededThreshold) {
        await _showNotification(
          id: _notificationId(budget.categoryKey, true),
          title: '🔴 Presupuesto excedido',
          body:
              '$label: gastaste \$${budget.spentAmount.toStringAsFixed(0)} '
              'de \$${budget.budgetedAmount.toStringAsFixed(0)}',
        );
      } else if (ratio >= _warningThreshold) {
        await _showNotification(
          id: _notificationId(budget.categoryKey, false),
          title: '🟡 Presupuesto al ${(ratio * 100).toStringAsFixed(0)}%',
          body:
              '$label: llevas \$${budget.spentAmount.toStringAsFixed(0)} '
              'de \$${budget.budgetedAmount.toStringAsFixed(0)}',
        );
      }
    }
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Alertas de presupuesto',
      channelDescription: 'Notificaciones cuando te acercas o excedes tu presupuesto',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details);
  }

  /// Mapeo rápido de categoryKey → label en español.
  static String _categoryLabel(String key) {
    const labels = {
      'food': 'Comida',
      'groceries': 'Despensa',
      'transport': 'Transporte',
      'housing': 'Casa',
      'utilities': 'Servicios',
      'health': 'Salud',
      'education': 'Educación',
      'entertainment': 'Entretenimiento',
      'clothing': 'Ropa',
      'subscriptions': 'Suscripciones',
      'debtPayment': 'Deudas',
      'personalCare': 'Cuidado personal',
      'gifts': 'Regalos',
      'pets': 'Mascotas',
      'other': 'Otros',
    };
    return labels[key] ?? key;
  }
}