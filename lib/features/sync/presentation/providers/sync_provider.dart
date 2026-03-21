import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:betty_app/core/providers/core_providers.dart';
import 'package:betty_app/core/providers/connectivity_provider.dart';
import 'package:betty_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:betty_app/features/sync/data/datasources/sync_local_ds.dart';
import 'package:betty_app/features/sync/data/datasources/sync_remote_ds.dart';
import 'package:betty_app/features/sync/data/datasources/sync_pull_ds.dart';
import 'package:betty_app/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:betty_app/features/sync/data/services/sync_merge_service.dart';
import 'package:betty_app/features/sync/data/services/realtime_service.dart';
import 'package:betty_app/features/sync/domain/repositories/sync_repository.dart';
import 'package:betty_app/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:betty_app/features/financial_health/presentation/providers/health_provider.dart';
import 'package:betty_app/features/budgets_goals/presentation/providers/budgets_goals_provider.dart';
import 'package:betty_app/features/cards_credits/presentation/providers/cards_credits_provider.dart';

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
class SyncNotifier extends StateNotifier<SyncState> with WidgetsBindingObserver {
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

    // Escuchar cambios de conectividad
    _ref.listen(connectivityProvider, (previous, next) {
      next.whenData((hasInternet) {
        if (hasInternet) _triggerFullSync();
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerFullSync();
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
    if (!hasInternet) return;

    final userId = _userId;
    if (userId == null) return;

    _isSyncing = true;

    try {
      // 1. PUSH primero (para que otros dispositivos vean nuestros cambios)
      state = SyncState.pushing;
      await _executePush();

      // 2. PULL después (para recibir cambios de otros dispositivos)
      state = SyncState.pulling;
      await _executePull(userId);

      // 3. Refrescar UI con datos nuevos del pull
      _refreshUI();

      state = SyncState.completed;
      _ref.invalidate(pendingSyncCountProvider);
    } catch (e) {
      state = SyncState.error;
      debugPrint('SyncNotifier: error → $e');
    } finally {
      _isSyncing = false;
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) state = SyncState.idle;
    }
  }

  /// Pull inicial: descarga TODO del servidor.
  /// Se llama una vez después del primer login en un dispositivo nuevo.
  Future<void> initialPull() async {
    final userId = _userId;
    if (userId == null) return;

    _isSyncing = true;
    state = SyncState.pulling;

    try {
      // Pull del perfil
      final profileData = await _pullDs.pullProfile(userId);
      if (profileData != null) {
        await _mergeService.mergeProfile(profileData);
      }

      // Pull de todas las tablas
      final remoteData = await _pullDs.pullAll(userId);
      final result = await _mergeService.mergeAll(remoteData);
      debugPrint('Initial pull: $result');

      // Guardar timestamp del pull
      await _saveLastPullAt(DateTime.now().toUtc());

      // Iniciar escucha en tiempo real para multi-dispositivo
      _realtimeService.subscribe(userId, onDataChanged: _refreshUI);

      // Refrescar UI con datos descargados
      _refreshUI();

      state = SyncState.completed;
    } catch (e) {
      state = SyncState.error;
      debugPrint('Initial pull error: $e');
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

  /// Push: procesa la cola existente.
  Future<void> _executePush() async {
    final synced = await _pushRepo.processQueue();
    debugPrint('Push: $synced items sincronizados');
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
    if (!hasInternet) return;

    try {
      await _executePush();
    } catch (e) {
      debugPrint('pushNow error: $e');
    }
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