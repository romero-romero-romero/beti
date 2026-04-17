import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beti_app/core/providers/core_providers.dart';
import 'package:beti_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:beti_app/features/alerts/data/services/alert_scheduler.dart';

/// Provider que reprograma alertas cada vez que cambia el estado de auth
/// o se invalida manualmente (después de agregar/editar tarjetas).
final alertProvider = FutureProvider<void>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState is! AuthAuthenticated) return;

  final isar = ref.watch(isarProvider);
  await AlertScheduler.rescheduleAll(isar, authState.user.supabaseId);
});