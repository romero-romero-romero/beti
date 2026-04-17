import 'package:beti_app/core/enums/card_network.dart';
import 'package:beti_app/core/enums/sync_status.dart';

/// Entidad de dominio de tarjeta de crédito.
/// Independiente de Isar — los Repositories mapean hacia/desde aquí.
/// La UI y los Providers trabajan exclusivamente con esta clase.
class CreditCardEntity {
  final String uuid;
  final String userId;
  final String name;
  final String? lastFourDigits;
  final CardNetwork network;
  final double creditLimit;
  final double currentBalance;
  final double availableCredit;
  final double? annualRate;
  final int cutOffDay;
  final int paymentDueDay;
  final DateTime? nextCutOffDate;
  final DateTime? nextPaymentDueDate;
  final bool alertsEnabled;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  const CreditCardEntity({
    required this.uuid,
    required this.userId,
    required this.name,
    this.lastFourDigits,
    this.network = CardNetwork.other,
    required this.creditLimit,
    required this.currentBalance,
    required this.availableCredit,
    this.annualRate,
    required this.cutOffDay,
    required this.paymentDueDay,
    this.nextCutOffDate,
    this.nextPaymentDueDate,
    this.alertsEnabled = true,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  /// Porcentaje de utilización del crédito (0-100+).
  double get utilizationPercent =>
      creditLimit > 0 ? (currentBalance / creditLimit * 100) : 0;

  CreditCardEntity copyWith({
    String? uuid,
    String? userId,
    String? name,
    String? lastFourDigits,
    CardNetwork? network,
    double? creditLimit,
    double? currentBalance,
    double? availableCredit,
    double? annualRate,
    int? cutOffDay,
    int? paymentDueDay,
    DateTime? nextCutOffDate,
    DateTime? nextPaymentDueDate,
    bool? alertsEnabled,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return CreditCardEntity(
      uuid: uuid ?? this.uuid,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      lastFourDigits: lastFourDigits ?? this.lastFourDigits,
      network: network ?? this.network,
      creditLimit: creditLimit ?? this.creditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
      availableCredit: availableCredit ?? this.availableCredit,
      annualRate: annualRate ?? this.annualRate,
      cutOffDay: cutOffDay ?? this.cutOffDay,
      paymentDueDay: paymentDueDay ?? this.paymentDueDay,
      nextCutOffDate: nextCutOffDate ?? this.nextCutOffDate,
      nextPaymentDueDate: nextPaymentDueDate ?? this.nextPaymentDueDate,
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
