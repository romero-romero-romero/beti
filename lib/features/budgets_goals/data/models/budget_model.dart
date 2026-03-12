import 'package:isar/isar.dart';

part 'budget_model.g.dart';

/// Presupuesto mensual por categoría.
/// El motor TFLite puede sugerir "Presupuestos Reales" analizando historial.
@collection
class BudgetModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  @Index()
  late String userId;

  /// Key del enum CategoryType al que aplica.
  @Index()
  late String categoryKey;

  late double budgetedAmount;

  /// Acumulado gastado en el período (recalculado en tiempo real).
  late double spentAmount;

  /// Período: año-mes (ej: "2025-07").
  @Index()
  late String period;

  /// true = sugerido por motor ML, false = creado manualmente.
  late bool isSuggested;

  /// spentAmount / budgetedAmount (precalculado para queries rápidas).
  late double consumptionRatio;

  late DateTime createdAt;

  late DateTime updatedAt;

  @Enumerated(EnumType.name)
  late BudgetSyncStatus syncStatus;
}

enum BudgetSyncStatus {
  pending,
  synced,
  conflict,
}
