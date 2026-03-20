import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/core/providers/core_providers.dart';
import 'package:betty_app/core/providers/connectivity_provider.dart';
import 'package:betty_app/features/sync/data/datasources/sync_local_ds.dart';
import 'package:betty_app/features/sync/data/datasources/sync_remote_ds.dart';
import 'package:betty_app/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:betty_app/features/sync/domain/repositories/sync_repository.dart';

// ── Dependency Injection ──

final syncLocalDsProvider = Provider<SyncLocalDataSource>((ref) {
  return SyncLocalDataSource(ref.watch(isarProvider));
});

final syncRemoteDsProvider = Provider<SyncRemoteDataSource>((ref) {
  return SyncRemoteDataSource(ref.watch(supabaseProvider));
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepositoryImpl(
    localDs: ref.watch(syncLocalDsProvider),
    remoteDs: ref.watch(syncRemoteDsProvider),
  );
});

/// Cantidad de items pendientes en la cola de sync.
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(syncRepositoryProvider);
  return await repo.getPendingCount();
});

// ── Sync State ──

enum SyncState {
  idle,
  syncing,
  completed,
  error,
}

// ── Sync Notifier ──

/// Maneja la sincronización en segundo plano.
///
/// Se activa cuando:
/// 1. La app pasa de paused → resumed (AppLifecycleState)
/// 2. La conectividad cambia de offline → online
///
/// Nunca se ejecuta si no hay internet.
class SyncNotifier extends StateNotifier<SyncState> with WidgetsBindingObserver {
  final SyncRepository _repository;
  final Ref _ref;
  bool _isSyncing = false;

  SyncNotifier(this._repository, this._ref) : super(SyncState.idle) {
    // Registrar como observer del lifecycle de la app
    WidgetsBinding.instance.addObserver(this);

    // Escuchar cambios de conectividad
    _ref.listen(connectivityProvider, (previous, next) {
      next.whenData((hasInternet) {
        if (hasInternet) {
          _triggerSync();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerSync();
    }
  }

  /// Dispara la sincronización si hay internet y no está en curso.
  Future<void> _triggerSync() async {
    if (_isSyncing) return;

    // Verificar conectividad
    final connectivity = _ref.read(hasInternetProvider);
    final hasInternet = connectivity.valueOrNull ?? false;
    if (!hasInternet) return;

    _isSyncing = true;
    state = SyncState.syncing;

    try {
      final synced = await _repository.processQueue();
      state = SyncState.completed;
      debugPrint('SyncNotifier: synced $synced items');

      // Refrescar el contador de pendientes
      _ref.invalidate(pendingSyncCountProvider);
    } catch (e) {
      state = SyncState.error;
      debugPrint('SyncNotifier: error during sync: $e');
    } finally {
      _isSyncing = false;
      // Volver a idle después de un momento
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        state = SyncState.idle;
      }
    }
  }

  /// Fuerza una sincronización manual.
  Future<void> forceSync() async {
    await _triggerSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

// ── Provider ──

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final repository = ref.watch(syncRepositoryProvider);
  return SyncNotifier(repository, ref);
});
