import 'package:isar/isar.dart';

part 'category_model.g.dart';

/// Colección de categorías personalizadas del usuario.
///
/// Almacena keywords que el motor híbrido (Regex/Tokenization del MVP)
/// usa para auto-categorizar transacciones. Las correcciones manuales
/// enriquecen las keywords → dataset para TFLite en fases futuras.
@collection
class CategoryModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  @Index()
  late String userId;

  /// Nombre visible (ej: "Comida rápida", "Gasolina").
  late String name;

  /// Key del enum CategoryType padre (ej: "transport").
  @Index()
  late String parentCategoryKey;

  /// Emoji o ícono representativo.
  String? icon;

  /// Keywords para auto-categorización (lowercase).
  late List<String> keywords;

  /// true = categoría del sistema (no eliminable), false = creada por usuario.
  late bool isSystem;

  /// true = categoría de ingreso, false = gasto.
  late bool isIncome;

  late int sortOrder;

  late DateTime createdAt;

  late DateTime updatedAt;

  @Enumerated(EnumType.name)
  late CatSyncStatus syncStatus;
}

enum CatSyncStatus {
  pending,
  synced,
  conflict,
}
