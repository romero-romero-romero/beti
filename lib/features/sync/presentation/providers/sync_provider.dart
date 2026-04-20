import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beti_app/core/providers/core_providers.dart';
import 'package:beti_app/core/providers/connectivity_provider.dart';
import 'package:beti_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:beti_app/features/sync/data/datasources/sync_local_ds.dart';
import 'package:beti_app/features/sync/data/datasources/sync_remote_ds.dart';
import 'package:beti_app/features/sync/data/datasources/sync_pull_ds.dart';
import 'package:beti_app/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:beti_app/features/sync/data/services/sync_merge_service.dart';
import 'package:beti_app/features/sync/data/services/realtime_service.dart';
import 'package:beti_app/features/sync/domain/repositories/sync_repository.dart';
import 'package:beti_app/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:beti_app/features/financial_health/presentation/providers/health_provider.dart';
import 'package:beti_app/features/budgets_goals/presentation/providers/budgets_goals_provider.dart';
import 'package:beti_app/features/cards_credits/presentation/providers/cards_credits_provider.dart';

// ── Dependency Injection ──

final syncLocalDsProvider = Provider<SyncLocalDataSource>((ref) {
  return SyncLocalDataSource(ref.watch(isarProvider));
});

final syncRemoteDsProvider = Provider<SyncRemoteDataSource>((ref) {
  return SyncRemoteDataSource(ref.watch(supabaseProvider));
});

final syncPullDsProvider = Provider<SyncPullDataSource>((ref) {
  return SyncPullDataSource(ref.watch(supabaseProvider));
});

final syncMergeServiceProvider = Provider<SyncMergeService>((ref) {
  return SyncMergeService(ref.watch(isarProvider));
});

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService(
    client: ref.watch(supabaseProvider),
    mergeService: ref.watch(syncMergeServiceProvider),
  );
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepositoryImpl(
    localDs: ref.watch(syncLocalDsProvider),
    remoteDs: ref.watch(syncRemoteDsProvider),
  );
});

/// Cantidad de items pendientes en la cola de sync (push).
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(syncRepositoryProvider);
  return await repo.getPendingCount();
});

// ── Sync State ──

enum SyncState {
  idle,
  pulling,
  pushing,
  completed,
  error,
}

// ── Sync Notifier ──

/// Orquesta la sincronización bidireccional:
///
/// 1. PULL: Descarga cambios de Supabase → merge con Isar.
/// 2. PUSH: Procesa la cola local → sube a Supabase.
///
/// Se activa cuando:
/// - La app pasa de paused → resumed (AppLifecycleState)
/// - La conectividad cambia de offline → online
/// - El usuario hace login exitoso (initial pull)
class SyncNotifier extends StateNotifier<SyncState>
    with WidgetsBindingObserver {
  final SyncRepository _pushRepo;
  final SyncPullDataSource _pullDs;
  final SyncMergeService _mergeService;
  final RealtimeService _realtimeService;
  final Ref _ref;
  bool _isSyncing = false;

  /// Key para SharedPreferences donde guardamos la última fecha de pull.
  static const _lastPullKey = 'betty_last_pull_at';

  SyncNotifier(
    this._pushRepo,
    this._pullDs,
    this._mergeService,
    this._realtimeService,
    this._ref,
  ) : super(SyncState.idle) {
    WidgetsBinding.instance.addObserver(this);

    _ref.listen(connectivityProvider, (previous, next) {
      next.whenData((hasInternet) {
        if (hasInternet) _triggerFullSync();
      });
    });

    // C6: Re-disparar sync cuando auth pasa a AuthAuthenticated.
    // Cubre caso de conectividad que emitió "online" antes de que la
    // sesión se restaurara. Solo dispara sync delta (no initial pull) —
    // el initialPull es responsabilidad de app.dart.
    _ref.listen(authProvider, (previous, next) {
      if (next is AuthAuthenticated && previous is! AuthAuthenticated) {
        // Delay pequeño para que initialPull (llamado desde app.dart)
        // se ejecute primero si es un login fresco.
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _userId != null) _triggerFullSync();
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerFullSync();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      pushNow();
    }
  }

  /// Obtiene el userId del usuario autenticado.
  String? get _userId {
    final auth = _ref.read(authProvider);
    if (auth is AuthAuthenticated) return auth.user.supabaseId;
    return null;
  }

  /// Sync completo: push primero, luego pull.
  /// Push primero para que nuestros cambios locales lleguen al servidor
  /// antes de que el otro dispositivo haga su pull.
  Future<void> _triggerFullSync() async {
    if (_isSyncing) return;

    final connectivity = _ref.read(hasInternetProvider);
    final hasInternet = connectivity.valueOrNull ?? false;
    if (!hasInternet) {
      debugPrint('[Sync] fullSync skipped: no internet');
      return;
    }

    final userId = _userId;
    if (userId == null) {
      debugPrint('[Sync] fullSync skipped: no userId');
      return;
    }

    _isSyncing = true;
    final before = await _pushRepo.getPendingCount();
    debugPrint('[Sync] fullSync start — pending: $before');

    try {
      state = SyncState.pushing;
      await _executePush();

      state = SyncState.pulling;
      await _executePull(userId);

      _refreshUI();

      state = SyncState.completed;
      _ref.invalidate(pendingSyncCountProvider);
      final after = await _pushRepo.getPendingCount();
      debugPrint('[Sync] fullSync OK — pending: $before → $after');
    } catch (e) {
      state = SyncState.error;
      debugPrint('[Sync] fullSync ERROR: $e');
    } finally {
      _isSyncing = false;
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) state = SyncState.idle;
    }
  }

  /// Pull inicial: descarga todo del servidor.
  /// Se llama una vez después del primer login en un dispositivo nuevo.
  Future<void> initialPull() async {
    final userId = _userId;
    if (userId == null) {
      debugPrint('[Sync] initialPull skipped: no userId');
      return;
    }

    _isSyncing = true;
    state = SyncState.pulling;
    debugPrint('[Sync] initialPull start for user $userId');

    try {
      final profileData = await _pullDs.pullProfile(userId);
      if (profileData != null) {
        await _mergeService.mergeProfile(profileData);
      }

      final remoteData = await _pullDs.pullAll(userId);
      final totalRows =
          remoteData.values.fold<int>(0, (sum, list) => sum + list.length);
      debugPrint('[Sync] initialPull: $totalRows rows received');

      await _mergeService.mergeAll(remoteData);
      await _saveLastPullAt(DateTime.now().toUtc());
      _realtimeService.subscribe(userId, onDataChanged: _refreshUI);
      _refreshUI();

      state = SyncState.completed;
      debugPrint('[Sync] initialPull OK');
    } catch (e) {
      state = SyncState.error;
      debugPrint('[Sync] initialPull ERROR: $e');
    } finally {
      _isSyncing = false;
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) state = SyncState.idle;
    }
  }

  /// Invalida todos los providers de datos para que la UI recargue desde Isar.
  /// Se llama después de cada pull exitoso (initial o delta).
  void _refreshUI() {
    _ref.invalidate(transactionsProvider);
    _ref.invalidate(healthProvider);
    _ref.invalidate(budgetsProvider);
    _ref.invalidate(goalsProvider);
    _ref.invalidate(creditCardsProvider);
    _ref.invalidate(creditsProvider);
    _ref.invalidate(pendingSyncCountProvider);
  }

  /// Pull incremental (delta): solo cambios desde la última descarga.
  /// Resta 30 segundos al lastPullAt como margen de seguridad para no
  /// perder registros que se crearon justo en el límite del timestamp.
  /// El merge descarta duplicados automáticamente.
  Future<void> _executePull(String userId) async {
    final lastPull = await _getLastPullAt();

    if (lastPull == null) {
      // Nunca hemos hecho pull — hacer pull completo
      final remoteData = await _pullDs.pullAll(userId);
      await _mergeService.mergeAll(remoteData);
    } else {
      // Delta pull con margen de seguridad de 30 segundos
      final safeLastPull = lastPull.subtract(const Duration(seconds: 30));
      final remoteData = await _pullDs.pullDelta(
        userId: userId,
        since: safeLastPull,
      );
      await _mergeService.mergeAll(remoteData);
    }

    await _saveLastPullAt(DateTime.now().toUtc());
  }

  /// Push: procesa la cola. Si falla por auth, refresca sesión y reintenta una vez.
  Future<void> _executePush() async {
    try {
      await _pushRepo.processQueue();
    } on SyncAuthException {
      // A12: token expirado — refresh y reintentar una vez.
      await _ref.read(authProvider.notifier).checkAuthStatus();
      if (_userId == null) return;
      try {
        await _pushRepo.processQueue();
      } on SyncAuthException {
        // Token sigue inválido — el usuario debe re-loguearse.
      }
    }
  }

  /// Fuerza una sincronización manual completa.
  Future<void> forceSync() async {
    await _triggerFullSync();
  }

  /// Push inmediato: procesa la cola sin hacer pull.
  /// Llamar después de cada escritura local (addCard, addTransaction, etc.)
  /// para que los datos lleguen al servidor sin esperar al ciclo de resumed.
  Future<void> pushNow() async {
    final connectivity = _ref.read(hasInternetProvider);
    final hasInternet = connectivity.valueOrNull ?? false;
    if (!hasInternet) {
      debugPrint('[Sync] pushNow skipped: no internet');
      return;
    }

    try {
      final before = await _pushRepo.getPendingCount();
      await _executePush();
      final after = await _pushRepo.getPendingCount();
      debugPrint('[Sync] pushNow: queue $before → $after');
    } catch (e) {
      debugPrint('[Sync] pushNow error: $e');
    }
  }

  /// Desconecta el canal de Realtime. Llamar SIEMPRE antes de hacer
  /// signOut/nuclear wipe para evitar que eventos Postgres en vuelo
  /// escriban datos del usuario anterior en Isar después del wipe.
  ///
  /// A2: Sin esto, un INSERT/UPDATE del servidor que llega en el
  /// milisegundo entre "empezar wipe" y "channel.unsubscribe()" termina
  /// repoblando Isar con registros del usuario que acaba de cerrar sesión.
  Future<void> disposeRealtime() async {
    await _realtimeService.unsubscribe();
  }

  // ── SharedPreferences para lastPullAt ──

  Future<DateTime?> _getLastPullAt() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastPullKey);
    return iso != null ? DateTime.tryParse(iso) : null;
  }

  Future<void> _saveLastPullAt(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPullKey, dt.toIso8601String());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeService.unsubscribe();
    super.dispose();
  }
}

// ── Provider ──

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(
    ref.watch(syncRepositoryProvider),
    ref.watch(syncPullDsProvider),
    ref.watch(syncMergeServiceProvider),
    ref.watch(realtimeServiceProvider),
    ref,
  );
});
