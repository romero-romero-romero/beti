import 'package:intl/intl.dart';
import 'package:beti_app/core/enums/currency_preference.dart';

/// Formateador de moneda para la app.
class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(double amount, {CurrencyPreference currency = CurrencyPreference.mxn}) {
    final formatter = switch (currency) {
      CurrencyPreference.mxn => NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 2),
      CurrencyPreference.usd => NumberFormat.currency(locale: 'en_US', symbol: r'US$', decimalDigits: 2),
    };
    return formatter.format(amount);
  }

  /// Formato compacto para montos grandes (ej: $12.5K).
  static String formatCompact(double amount, {CurrencyPreference currency = CurrencyPreference.mxn}) {
    final symbol = currency == CurrencyPreference.mxn ? r'$' : r'US$';
    final formatter = NumberFormat.compact(locale: currency == CurrencyPreference.mxn ? 'es_MX' : 'en_US');
    return '$symbol${formatter.format(amount)}';
  }
}
