import 'package:isar/isar.dart';

part 'credit_model.g.dart';

/// Créditos y préstamos personales (hipotecas, automotriz, nómina, etc.).
/// Complementa a CreditCardModel para deudas que no son tarjetas.
@collection
class CreditModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  @Index()
  late String userId;

  late String name;

  String? institution;

  late double originalAmount;

  late double currentBalance;

  /// Tasa de interés anual (ej: 0.18 = 18%).
  double? interestRate;

  late double monthlyPayment;

  /// Día del mes en que se debe pagar (1-31).
  late int paymentDay;

  DateTime? nextPaymentDate;

  DateTime? startDate;

  DateTime? endDate;

  int? totalInstallments;

  int? paidInstallments;

  late bool alertsEnabled;

  String? belvoLinkId;

  String? belvoAccountId;

  DateTime? lastBelvoSyncAt;

  late bool isActive;

  late DateTime createdAt;

  late DateTime updatedAt;

  @Enumerated(EnumType.name)
  late CreditSyncStatus syncStatus;
}

enum CreditSyncStatus {
  pending,
  synced,
  conflict,
}
