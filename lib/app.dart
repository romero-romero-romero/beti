import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beti_app/core/constants/app_strings.dart';
import 'package:beti_app/core/theme/app_theme.dart';
import 'package:beti_app/core/utils/platform_helper.dart';
import 'package:beti_app/router/app_router.dart';
import 'package:beti_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:beti_app/features/sync/presentation/providers/sync_provider.dart';
import 'package:beti_app/features/intelligence/presentation/providers/category_learning_provider.dart';
import 'package:beti_app/features/alerts/presentation/providers/alert_provider.dart';

/// Root widget de Betty.
///
/// En iOS los widgets Cupertino (CupertinoTabBar, CupertinoSwitch)
/// toman su color del CupertinoTheme más cercano en el árbol.
/// Lo inyectamos DENTRO del MaterialApp.router via `builder`,
/// lo cual garantiza que el Theme de Material ya existe en context.
class BetiApp extends ConsumerStatefulWidget {
  const BetiApp({super.key});

  @override
  ConsumerState<BetiApp> createState() => _BetiAppState();
}

class _BetiAppState extends ConsumerState<BetiApp> {
  bool _syncInitialized = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(authProvider.notifier).checkAuthStatus();
    });
    Future.microtask(() {
      ref.read(syncProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    // Escuchar cambios de auth para disparar sync en cualquier transición
    // a AuthAuthenticated (login fresco O restauración de sesión desde Isar).
    //
    // C5: El flag _syncInitialized DEBE resetearse en cualquier transición
    // fuera de AuthAuthenticated (logout, unauthenticated, error). Sin esto,
    // un segundo login en la misma sesión del proceso no re-dispara
    // initialPull() ni re-inicializa categoryLearning/alertProvider,
    // dejando al usuario con Isar vacío (tras nuclear wipe) y sin pull
    // desde Supabase.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthAuthenticated && !_syncInitialized) {
        _syncInitialized = true;
        ref.read(syncProvider.notifier).initialPull();
        ref.read(categoryLearningProvider);
        ref.read(alertProvider);
      } else if (next is! AuthAuthenticated && _syncInitialized) {
        // Cualquier transición fuera de AuthAuthenticated resetea el flag
        // para que el próximo login vuelva a inicializar la sync.
        _syncInitialized = false;
      }
    });

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppStrings.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        if (!PlatformHelper.isApple) return child!;

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return CupertinoTheme(
          data: isDark ? AppTheme.cupertinoDark : AppTheme.cupertinoLight,
          child: child!,
        );
      },
    );
  }
}