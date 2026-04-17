import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beti_app/features/budgets_goals/data/models/goal_model.dart';

/// Servicio de ajuste por inflación diario para metas de ahorro.
///
/// Recalcula el targetAmount de cada meta activa aplicando la tasa
/// de inflación anual prorrateada al día. Se ejecuta una vez por día
/// al abrir la app (controlado por SharedPreferences).
///
/// Fórmula diaria: targetAmount *= (1 + tasaAnual / 365)
///
/// Ejemplo: meta de $100,000 con inflación 5% anual
///   → ajuste diario: $100,000 × 1.000137 = $100,013.70
///   → tras 1 año: ~$105,127 (compuesto diario)
class InflationAdjustmentService {
  static const _lastAdjustKey = 'betty_inflation_last_adjust';
  static const _rateKey = 'betty_inflation_rate';

  /// Tasa de inflación anual por defecto (Banco de México ~4.5% 2026).
  static const double defaultAnnualRate = 0.045;

  final Isar _isar;

  InflationAdjustmentService(this._isar);

  /// Obtiene la tasa anual configurada por el usuario.
  static Future<double> getRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_rateKey) ?? defaultAnnualRate;
  }

  /// Permite al usuario configurar su tasa de inflación.
  static Future<void> setRate(double annualRate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rateKey, annualRate);
  }

  /// Ejecuta el ajuste diario si no se ha hecho hoy.
  /// Retorna la cantidad de metas ajustadas.
  Future<int> adjustIfNeeded(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastAdjust = prefs.getString(_lastAdjustKey);
    final today = _todayKey();

    if (lastAdjust == today) {
      debugPrint('[Inflation] Ya se ajustó hoy, skip.');
      return 0;
    }

    final rate = await getRate();
    if (rate <= 0) {
      debugPrint('[Inflation] Tasa en 0, skip.');
      return 0;
    }

    // Calcular días desde último ajuste (para compensar días sin abrir la app)
    int daysMissed = 1;
    if (lastAdjust != null) {
      try {
        final lastDate = DateTime.parse(lastAdjust);
        final now = DateTime.now();
        daysMissed = now.difference(lastDate).inDays;
        if (daysMissed < 1) daysMissed = 1;
        if (daysMissed > 365) daysMissed = 365; // Cap de seguridad
      } catch (_) {
        daysMissed = 1;
      }
    }

    final dailyFactor = 1 + (rate / 365);
    // Factor compuesto por los días perdidos
    final compoundFactor = _pow(dailyFactor, daysMissed);

    final goals = await _isar.goalModels
        .filter()
        .userIdEqualTo(userId)
        .isActiveEqualTo(true)
        .isCompletedEqualTo(false)
        .findAll();

    if (goals.isEmpty) {
      await prefs.setString(_lastAdjustKey, today);
      return 0;
    }

    int adjusted = 0;
    await _isar.writeTxn(() async {
      for (final goal in goals) {
        final oldTarget = goal.targetAmount;
        goal.targetAmount = (oldTarget * compoundFactor * 100).roundToDouble() / 100;
        goal.progress = goal.targetAmount > 0
            ? goal.savedAmount / goal.targetAmount
            : 0;
        goal.updatedAt = DateTime.now();
        goal.syncStatus = GoalSyncStatus.pending;
        await _isar.goalModels.put(goal);
        adjusted++;

        debugPrint(
          '[Inflation] ${goal.name}: '
          '\$${oldTarget.toStringAsFixed(2)} → \$${goal.targetAmount.toStringAsFixed(2)} '
          '(${daysMissed}d × ${(rate * 100).toStringAsFixed(1)}%)',
        );
      }
    });

    await prefs.setString(_lastAdjustKey, today);
    debugPrint('[Inflation] Ajustadas $adjusted metas ($daysMissed días)');
    return adjusted;
  }

  /// Resetea la fecha de último ajuste (para testing).
  static Future<void> resetLastAdjust() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastAdjustKey);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Potencia sin importar dart:math para mantener puro.
  double _pow(double base, int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }
}