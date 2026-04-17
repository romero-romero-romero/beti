// lib/features/budgets_goals/data/models/income_budget_model.dart

import 'package:isar/isar.dart';

part 'income_budget_model.g.dart';

/// Ingreso esperado del mes por fuente.
///
/// Cada usuario puede tener varios por período (ej: "Nómina", "Bono",
/// "Freelance"). El total esperado del mes es la suma de todos sus
/// [IncomeBudgetModel] activos del período.
///
/// El monto REAL no se almacena aquí — se calcula on-the-fly desde
/// transacciones TxType.income del período vía [IncomeActualCalculator].
@collection
class IncomeBudgetModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  @Index()
  late String userId;

  /// Nombre descriptivo de la fuente (ej: "Nómina Ella", "Freelance").
  late String sourceName;

  /// Fijo = llega con certeza cada mes. Variable = depende del trabajo.
  @Enumerated(EnumType.name)
  late IncomeType incomeType;

  /// Monto esperado mensual.
  late double expectedAmount;

  /// Período: año-mes (ej: "2026-04").
  @Index()
  late String period;

  late DateTime createdAt;

  late DateTime updatedAt;

  @Enumerated(EnumType.name)
  late IncomeBudgetSyncStatus syncStatus;
}

enum IncomeType {
  fixed,
  variable,
}

enum IncomeBudgetSyncStatus {
  pending,
  synced,
  conflict,
}