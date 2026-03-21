import 'package:betty_app/core/enums/sync_status.dart';

/// Entidad de dominio de crédito/préstamo.
/// Independiente de Isar — los Repositories mapean hacia/desde aquí.
class CreditEntity {
  final String uuid;
  final String userId;
  final String name;
  final String? institution;
  final double originalAmount;
  final double currentBalance;
  final double? interestRate;
  final double monthlyPayment;
  final int paymentDay;
  final DateTime? nextPaymentDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? totalInstallments;
  final int? paidInstallments;
  final bool alertsEnabled;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  const CreditEntity({
    required this.uuid,
    required this.userId,
    required this.name,
    this.institution,
    required this.originalAmount,
    required this.currentBalance,
    this.interestRate,
    required this.monthlyPayment,
    required this.paymentDay,
    this.nextPaymentDate,
    this.startDate,
    this.endDate,
    this.totalInstallments,
    this.paidInstallments,
    this.alertsEnabled = true,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  /// Progreso de pago (0.0 a 1.0+).
  double get progressPercent =>
      originalAmount > 0
          ? ((originalAmount - currentBalance) / originalAmount).clamp(0, 1)
          : 0;

  CreditEntity copyWith({
    String? uuid,
    String? userId,
    String? name,
    String? institution,
    double? originalAmount,
    double? currentBalance,
    double? interestRate,
    double? monthlyPayment,
    int? paymentDay,
    DateTime? nextPaymentDate,
    DateTime? startDate,
    DateTime? endDate,
    int? totalInstallments,
    int? paidInstallments,
    bool? alertsEnabled,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return CreditEntity(
      uuid: uuid ?? this.uuid,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      institution: institution ?? this.institution,
      originalAmount: originalAmount ?? this.originalAmount,
      currentBalance: currentBalance ?? this.currentBalance,
      interestRate: interestRate ?? this.interestRate,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      paymentDay: paymentDay ?? this.paymentDay,
      nextPaymentDate: nextPaymentDate ?? this.nextPaymentDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      paidInstallments: paidInstallments ?? this.paidInstallments,
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
