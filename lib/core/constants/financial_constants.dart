/// Constantes del motor financiero.
class FinancialConstants {
  FinancialConstants._();

  // ── Umbrales del termómetro de salud (expenseToIncomeRatio) ──
  static const double peaceThreshold = 0.60;
  static const double stableThreshold = 0.80;
  static const double warningThreshold = 0.95;
  static const double dangerThreshold = 1.10;
  // > dangerThreshold = crisis

  // ── Alertas de tarjetas ──
  /// Días antes de la fecha de corte/pago para enviar alerta.
  static const int alertDaysBefore = 3;

  // ── Utilización de crédito ──
  /// Umbral de utilización saludable (< 30%).
  static const double healthyCreditUtilization = 0.30;
  /// Umbral de utilización peligrosa (> 70%).
  static const double dangerousCreditUtilization = 0.70;

  // ── Sync ──
  /// Máximo de reintentos de sincronización antes de descartar.
  static const int maxSyncRetries = 5;

  // ── Pesos del health score (suman 1.0) ──
  static const double weightExpenseRatio = 0.35;
  static const double weightDebtLevel = 0.25;
  static const double weightCreditUtilization = 0.20;
  static const double weightOverduePayments = 0.10;
  static const double weightGoalProgress = 0.10;
}
