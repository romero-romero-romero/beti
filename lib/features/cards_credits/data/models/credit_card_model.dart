import 'package:isar/isar.dart';

part 'credit_card_model.g.dart';

/// Colección de tarjetas de crédito del usuario.
///
/// Las fechas de corte y pago son críticas para las alertas locales
/// (3 días antes de cada fecha → Local Notification programada en el OS).
@collection
class CreditCardModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  @Index()
  late String userId;

  /// Nombre personalizado (ej: "BBVA Oro", "Nu").
  late String name;

  /// Últimos 4 dígitos (nunca el número completo).
  String? lastFourDigits;

  @Enumerated(EnumType.name)
  late CcNetwork network;

  // ── Datos financieros ──

  late double creditLimit;

  late double currentBalance;

  /// creditLimit - currentBalance (cacheado para acceso offline rápido).
  late double availableCredit;

  // ── Fechas clave para alertas ──

  /// Día del mes de la fecha de corte (1-31).
  late int cutOffDay;

  /// Día del mes de la fecha límite de pago (1-31).
  late int paymentDueDay;

  DateTime? nextCutOffDate;

  DateTime? nextPaymentDueDate;

  // ── Alertas ──

  late bool alertsEnabled;

  // ── Belvo ──

  String? belvoLinkId;

  String? belvoAccountId;

  DateTime? lastBelvoSyncAt;

  // ── Control ──

  late bool isActive;

  late DateTime createdAt;

  late DateTime updatedAt;

  @Enumerated(EnumType.name)
  late CcSyncStatus syncStatus;
}

enum CcNetwork {
  visa,
  mastercard,
  amex,
  other,
}

enum CcSyncStatus {
  pending,
  synced,
  conflict,
}
