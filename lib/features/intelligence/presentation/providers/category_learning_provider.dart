import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beti_app/core/enums/category_type.dart';
import 'package:beti_app/core/providers/core_providers.dart';
import 'package:beti_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:beti_app/features/intelligence/data/services/category_learning_service.dart';

/// Provider del servicio de aprendizaje de categorías.
/// Se inicializa automáticamente cuando el usuario se autentica.
final categoryLearningProvider = Provider<CategoryLearningService?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState is! AuthAuthenticated) return null;

  final service = CategoryLearningService(
    isar: ref.watch(isarProvider),
    userId: authState.user.supabaseId,
  );

  // Cargar overrides del usuario al crear el servicio
  service.loadOverridesFromIsar();

  return service;
});

/// Acción que se llama desde PreviewCorrectionScreen cuando
/// el usuario confirma una transacción con categoría corregida.
Future<void> learnCategoryCorrection(
  WidgetRef ref, {
  required String description,
  required CategoryType originalCategory,
  required CategoryType correctedCategory,
}) async {
  final service = ref.read(categoryLearningProvider);
  if (service == null) return;

  await service.onCategoryCorrection(
    description: description,
    originalCategory: originalCategory,
    correctedCategory: correctedCategory,
  );
}