import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:beti_app/features/transactions/data/models/transaction_model.dart';

/// Servicio que exporta los datos del usuario a un archivo CSV y dispara
/// el share sheet del sistema.
///
/// Diseño:
/// - Lee TODAS las transacciones del usuario desde Isar (no pagina).
/// - Genera CSV en memoria con StringBuffer (no usa paquete `csv`).
/// - Escribe a directorio temporal y comparte vía share_plus.
/// - El archivo temporal queda en el FS del dispositivo hasta que el OS
///   lo limpie (típicamente al reiniciar). No lo borramos manualmente porque
///   share_plus aún lo necesita después de retornar.
class DataExportService {
  final Isar _isar;
  final String _userId;

  DataExportService({required Isar isar, required String userId})
      : _isar = isar,
        _userId = userId;

  /// Exporta las transacciones del usuario a CSV y abre el share sheet.
  /// Retorna `true` si se generó (independientemente de si el usuario
  /// compartió o canceló el share sheet).
  Future<bool> exportTransactionsAsCsv() async {
    final transactions = await _isar.transactionModels
        .filter()
        .userIdEqualTo(_userId)
        .sortByTransactionDateDesc()
        .findAll();

    final csv = _buildCsv(transactions);

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('${dir.path}/beti_transacciones_$timestamp.csv');
    await file.writeAsString(csv, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Exportación de transacciones — Beti',
    );

    return true;
  }

  String _buildCsv(List<TransactionModel> transactions) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
      'Fecha,Tipo,Monto,Descripción,Categoría,Método de pago,Notas',
    );

    for (final tx in transactions) {
      buffer.writeln(_rowFor(tx));
    }

    return buffer.toString();
  }

  String _rowFor(TransactionModel tx) {
    return [
      _formatDate(tx.transactionDate),
      _formatType(tx.type),
      tx.amount.toStringAsFixed(2),
      _csvEscape(tx.description),
      _formatCategory(tx.category),
      _formatPaymentMethod(tx.paymentMethod),
      _csvEscape(tx.notes ?? ''),
    ].join(',');
  }

  /// Formato YYYY-MM-DD (ISO 8601 date, sin hora).
  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatType(TxType type) {
    return switch (type) {
      TxType.income => 'Ingreso',
      TxType.expense => 'Gasto',
    };
  }

  String _formatCategory(TxCategory cat) {
    return switch (cat) {
      TxCategory.food => 'Alimentación',
      TxCategory.transport => 'Transporte',
      TxCategory.housing => 'Vivienda',
      TxCategory.utilities => 'Servicios',
      TxCategory.health => 'Salud',
      TxCategory.education => 'Educación',
      TxCategory.entertainment => 'Entretenimiento',
      TxCategory.clothing => 'Ropa',
      TxCategory.subscriptions => 'Suscripciones',
      TxCategory.debtPayment => 'Pago de deudas',
      TxCategory.groceries => 'Supermercado',
      TxCategory.personalCare => 'Cuidado personal',
      TxCategory.gifts => 'Regalos',
      TxCategory.pets => 'Mascotas',
      TxCategory.salary => 'Nómina',
      TxCategory.freelance => 'Freelance',
      TxCategory.investment => 'Inversión',
      TxCategory.refund => 'Reembolso',
      TxCategory.otherIncome => 'Otro ingreso',
      TxCategory.other => 'Sin categoría',
    };
  }

  String _formatPaymentMethod(TxPaymentMethod? pm) {
    if (pm == null) return '';
    return switch (pm) {
      TxPaymentMethod.cash => 'Efectivo',
      TxPaymentMethod.debitCard => 'Débito',
      TxPaymentMethod.creditCard => 'Crédito',
      TxPaymentMethod.transfer => 'Transferencia',
      TxPaymentMethod.other => 'Otro',
    };
  }

  /// Escapa un valor para CSV según RFC 4180:
  /// - Si contiene comilla, coma o salto de línea → envuelve en comillas
  ///   y duplica cada comilla interna.
  /// - Si no, retorna sin tocar.
  String _csvEscape(String value) {
    final needsQuoting = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuoting) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}