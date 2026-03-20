import 'package:isar/isar.dart';

part 'health_snapshot_model.g.dart';

/// Snapshot del estado de Salud Financiera Emocional.
///
/// Se genera al registrar transacciones, cambios en deudas, o inicio de mes.
/// El historial permite mostrar la evolución del termómetro y alimentar TFLite.
@collection
class HealthSnapshotModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  @Index()
  late String userId;

  @Index()
  late DateTime snapshotDate;

  // ── Métricas base ──

  late double totalIncome;

  late double totalExpenses;

  /// Ratio gasto/ingreso (0.0 a N). Ej: 0.75 = gastas 75%.
  late double expenseToIncomeRatio;

  late double totalDebt;

  /// Pagos vencidos o próximos a vencer (< 3 días).
  late int overduePayments;

  /// Utilización de crédito (deuda / límite). Ej: 0.45 = 45%.
  late double creditUtilizationRatio;

  /// Progreso promedio de metas de ahorro (0.0 a 1.0).
  late double goalProgressAvg;

  // ── Resultado del termómetro ──

  /// Índice numérico (0 = crisis, 100 = paz financiera).
  late double healthScore;

  @Enumerated(EnumType.name)
  late SnapshotHealthLevel healthLevel;

  /// Mensaje motivacional/alerta generado localmente.
  late String emotionalMessage;

  late DateTime createdAt;

  @Enumerated(EnumType.name)
  late SnapshotSyncStatus syncStatus;
}

enum SnapshotHealthLevel {
  peace,
  stable,
  warning,
  danger,
  crisis,
}

enum SnapshotSyncStatus {
  pending,
  synced,
  conflict,
}
