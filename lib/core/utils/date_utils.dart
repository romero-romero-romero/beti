import 'package:betty_app/core/constants/financial_constants.dart';

/// Utilidades de fecha para cálculos financieros.
class BettyDateUtils {
  BettyDateUtils._();

  /// Calcula la próxima ocurrencia de un día del mes.
  /// Si [dayOfMonth] ya pasó este mes, retorna el del siguiente.
  /// Ajusta automáticamente para meses con menos días (ej: 31 en febrero → 28).
  static DateTime nextOccurrence(int dayOfMonth) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, _clampDay(now.year, now.month, dayOfMonth));

    if (thisMonth.isAfter(now)) {
      return thisMonth;
    }

    // Siguiente mes
    final nextMonth = now.month == 12 ? 1 : now.month + 1;
    final nextYear = now.month == 12 ? now.year + 1 : now.year;
    return DateTime(nextYear, nextMonth, _clampDay(nextYear, nextMonth, dayOfMonth));
  }

  /// Calcula la fecha de alerta (3 días antes de [targetDate]).
  static DateTime alertDate(DateTime targetDate) {
    return targetDate.subtract(
      const Duration(days: FinancialConstants.alertDaysBefore),
    );
  }

  /// Retorna true si [date] es hoy o ya pasó.
  static bool isDueOrOverdue(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return !target.isAfter(today);
  }

  /// Período actual en formato "YYYY-MM" para presupuestos.
  static String currentPeriod() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Primer día del mes actual.
  static DateTime startOfCurrentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Último día del mes actual.
  static DateTime endOfCurrentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  /// Ajusta el día para no exceder los días reales del mes.
  static int _clampDay(int year, int month, int day) {
    final maxDay = DateTime(year, month + 1, 0).day;
    return day > maxDay ? maxDay : day;
  }
}
