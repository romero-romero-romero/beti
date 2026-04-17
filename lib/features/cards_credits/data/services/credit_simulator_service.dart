// lib/features/cards_credits/data/services/credit_simulator_service.dart

/// Servicio de simulación de pago de deuda con intereses.
///
/// Cálculo puro en Dart, sin dependencias externas ni persistencia.
/// Se usa desde la pantalla del simulador para mostrar al usuario
/// el costo real de pagar solo el mínimo.
class CreditSimulatorService {
  CreditSimulatorService._();

  /// Simula el pago de una deuda mes a mes.
  ///
  /// [debt] Deuda actual.
  /// [annualRate] Tasa de interés anual (ej: 0.60 = 60%).
  /// [monthlyPayment] Pago mensual fijo que el usuario haría.
  ///
  /// Retorna null si el pago mensual no cubre ni los intereses
  /// del primer mes (deuda crecería infinitamente).
  static SimulationResult? simulate({
    required double debt,
    required double annualRate,
    required double monthlyPayment,
  }) {
    if (debt <= 0 || monthlyPayment <= 0) return null;

    final monthlyRate = annualRate / 12;
    final firstMonthInterest = debt * monthlyRate;

    // Si el pago no cubre ni los intereses, la deuda nunca baja
    if (monthlyPayment <= firstMonthInterest) return null;

    double balance = debt;
    double totalPaid = 0;
    double totalInterest = 0;
    int months = 0;
    const maxMonths = 600;

    while (balance > 0 && months < maxMonths) {
      final interest = balance * monthlyRate;
      totalInterest += interest;

      // El último mes puede ser menor al pago fijo
      final payment = (balance + interest) < monthlyPayment
          ? (balance + interest)
          : monthlyPayment;

      balance = balance + interest - payment;
      totalPaid += payment;
      months++;

      // Evitar residuos de punto flotante
      if (balance < 0.01) balance = 0;
    }

    return SimulationResult(
      months: months,
      totalPaid: totalPaid,
      totalInterest: totalInterest,
      originalDebt: debt,
      monthlyPayment: monthlyPayment,
    );
  }

  /// Compara dos escenarios: pago actual vs pago incrementado.
  ///
  /// [extraPayment] Monto adicional al pago mensual actual.
  static SimulationComparison? compare({
    required double debt,
    required double annualRate,
    required double monthlyPayment,
    required double extraPayment,
  }) {
    final current = simulate(
      debt: debt,
      annualRate: annualRate,
      monthlyPayment: monthlyPayment,
    );

    final accelerated = simulate(
      debt: debt,
      annualRate: annualRate,
      monthlyPayment: monthlyPayment + extraPayment,
    );

    if (current == null || accelerated == null) return null;

    return SimulationComparison(
      current: current,
      accelerated: accelerated,
    );
  }
}

/// Resultado de una simulación de pago.
class SimulationResult {
  final int months;
  final double totalPaid;
  final double totalInterest;
  final double originalDebt;
  final double monthlyPayment;

  const SimulationResult({
    required this.months,
    required this.totalPaid,
    required this.totalInterest,
    required this.originalDebt,
    required this.monthlyPayment,
  });

  /// Años y meses en formato legible.
  String get timeLabel {
    final years = months ~/ 12;
    final remaining = months % 12;
    if (years == 0) return '$remaining meses';
    if (remaining == 0) return '$years ${years == 1 ? 'año' : 'años'}';
    return '$years ${years == 1 ? 'año' : 'años'} y $remaining meses';
  }

  /// Porcentaje del total pagado que fueron intereses.
  double get interestPercent =>
      totalPaid > 0 ? (totalInterest / totalPaid * 100) : 0;
}

/// Comparación entre pago actual y pago acelerado.
class SimulationComparison {
  final SimulationResult current;
  final SimulationResult accelerated;

  const SimulationComparison({
    required this.current,
    required this.accelerated,
  });

  /// Meses ahorrados con el pago extra.
  int get monthsSaved => current.months - accelerated.months;

  /// Dinero ahorrado en intereses.
  double get interestSaved =>
      current.totalInterest - accelerated.totalInterest;
}