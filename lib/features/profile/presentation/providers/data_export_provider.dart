import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beti_app/core/providers/core_providers.dart';
import 'package:beti_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:beti_app/features/profile/data/services/data_export_service.dart';

/// Provider del servicio de exportación de datos.
/// Retorna null si el usuario no está autenticado.
final dataExportServiceProvider = Provider<DataExportService?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState is! AuthAuthenticated) return null;

  return DataExportService(
    isar: ref.read(isarProvider),
    userId: authState.user.supabaseId,
  );
});