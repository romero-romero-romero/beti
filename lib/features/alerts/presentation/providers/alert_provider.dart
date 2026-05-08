import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beti_app/core/providers/core_providers.dart';
import 'package:beti_app/features/auth/presentation/providers/auth_provider.dart';

/// Provider que reprograma alertas de tarjetas y créditos cada vez que
/// cambia el estado de auth o se invalida manualmente (p.ej. después
/// de agregar/editar/desactivar una tarjeta o crédito).
///
/// La lógica concreta vive en [AlertOrchestrator] (que delega a su vez
/// a [NotificationService]).
final alertProvider = FutureProvider<void>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState is! AuthAuthenticated) return;

  final orchestrator = ref.watch(alertOrchestratorProvider);
  await orchestrator.rescheduleAll(authState.user.supabaseId);
});