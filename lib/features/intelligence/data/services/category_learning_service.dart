import 'package:isar/isar.dart';
import 'package:betty_app/core/enums/category_type.dart';
import 'package:betty_app/core/utils/uuid_generator.dart';
import 'package:betty_app/features/intelligence/data/datasources/categorization_engine.dart';
import 'package:betty_app/features/transactions/data/models/category_model.dart';

/// Servicio que conecta las correcciones manuales del usuario con el
/// CategorizationEngine y las persiste en CategoryModel (Isar).
///
/// Flujo:
/// 1. App inicia → [loadOverridesFromIsar] carga keywords → CategorizationEngine
/// 2. Usuario corrige categoría en Vista Previa → [onCategoryCorrection]
/// 3. Se actualiza CategorizationEngine en memoria + se persiste en Isar
/// 4. Próxima vez que el usuario escriba lo mismo → categoría correcta
class CategoryLearningService {
  final Isar _isar;
  final String _userId;

  CategoryLearningService({
    required Isar isar,
    required String userId,
  })  : _isar = isar,
        _userId = userId;

  /// Carga todas las keywords del usuario desde Isar al CategorizationEngine.
  /// Llamar una vez al inicio de la app (después de auth).
  Future<void> loadOverridesFromIsar() async {
    final categories = await _isar.categoryModels
        .filter()
        .userIdEqualTo(_userId)
        .findAll();

    final overrides = <String, CategoryType>{};

    for (final cat in categories) {
      final categoryType = _parseCategoryType(cat.parentCategoryKey);
      if (categoryType == null) continue;

      for (final keyword in cat.keywords) {
        overrides[keyword.toLowerCase()] = categoryType;
      }
    }

    CategorizationEngine.loadUserOverrides(overrides);
  }

  /// Procesa una corrección manual del usuario.
  /// Se llama cuando el usuario confirma una transacción donde
  /// [categoryAutoAssigned] era true pero cambió la categoría.
  Future<void> onCategoryCorrection({
    required String description,
    required CategoryType originalCategory,
    required CategoryType correctedCategory,
  }) async {
    // Si no hubo corrección real, ignorar
    if (originalCategory == correctedCategory) return;

    // 1. Actualizar CategorizationEngine en memoria
    final learnedKeywords = CategorizationEngine.learnFromCorrection(
      description: description,
      correctedCategory: correctedCategory,
    );

    if (learnedKeywords.isEmpty) return;

    // 2. Persistir en Isar
    await _persistLearnedKeywords(
      keywords: learnedKeywords,
      category: correctedCategory,
    );
  }

  /// Persiste keywords aprendidas en CategoryModel.
  /// Si ya existe un CategoryModel para esta categoría del usuario,
  /// agrega las keywords nuevas. Si no, crea uno nuevo.
  Future<void> _persistLearnedKeywords({
    required List<String> keywords,
    required CategoryType category,
  }) async {
    await _isar.writeTxn(() async {
      // Buscar si ya existe un CategoryModel para esta categoría
      var existing = await _isar.categoryModels
          .filter()
          .userIdEqualTo(_userId)
          .parentCategoryKeyEqualTo(category.name)
          .isSystemEqualTo(false)
          .findFirst();

      if (existing != null) {
        // Agregar keywords nuevas (sin duplicados)
        final currentKeywords = Set<String>.from(existing.keywords);
        currentKeywords.addAll(keywords);
        existing.keywords = currentKeywords.toList();
        existing.updatedAt = DateTime.now();
        existing.syncStatus = CatSyncStatus.pending;
        await _isar.categoryModels.put(existing);
      } else {
        // Crear nuevo CategoryModel para las keywords del usuario
        final now = DateTime.now();
        final model = CategoryModel()
          ..uuid = UuidGenerator.generate()
          ..userId = _userId
          ..name = _categoryDisplayName(category)
          ..parentCategoryKey = category.name
          ..icon = null
          ..keywords = keywords
          ..isSystem = false
          ..isIncome = _isIncomeCategory(category)
          ..sortOrder = 0
          ..createdAt = now
          ..updatedAt = now
          ..syncStatus = CatSyncStatus.pending;
        await _isar.categoryModels.put(model);
      }
    });
  }

  /// Parsea un string a CategoryType. Retorna null si no existe.
  static CategoryType? _parseCategoryType(String key) {
    try {
      return CategoryType.values.byName(key);
    } catch (_) {
      return null;
    }
  }

  static bool _isIncomeCategory(CategoryType cat) {
    const income = {
      CategoryType.salary,
      CategoryType.freelance,
      CategoryType.investment,
      CategoryType.refund,
      CategoryType.otherIncome,
    };
    return income.contains(cat);
  }

  static String _categoryDisplayName(CategoryType cat) {
    return switch (cat) {
      CategoryType.food => 'Alimentación',
      CategoryType.transport => 'Transporte',
      CategoryType.housing => 'Vivienda',
      CategoryType.utilities => 'Servicios',
      CategoryType.health => 'Salud',
      CategoryType.education => 'Educación',
      CategoryType.entertainment => 'Entretenimiento',
      CategoryType.clothing => 'Ropa',
      CategoryType.subscriptions => 'Suscripciones',
      CategoryType.debtPayment => 'Pago de deudas',
      CategoryType.groceries => 'Supermercado',
      CategoryType.personalCare => 'Cuidado personal',
      CategoryType.gifts => 'Regalos',
      CategoryType.pets => 'Mascotas',
      CategoryType.salary => 'Nómina',
      CategoryType.freelance => 'Freelance',
      CategoryType.investment => 'Inversión',
      CategoryType.refund => 'Reembolso',
      CategoryType.otherIncome => 'Otro ingreso',
      CategoryType.other => 'Sin categoría',
    };
  }
}