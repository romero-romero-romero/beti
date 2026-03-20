import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/core/constants/app_strings.dart';
import 'package:betty_app/core/theme/app_theme.dart';
import 'package:betty_app/router/app_router.dart';
import 'package:betty_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:betty_app/features/sync/presentation/providers/sync_provider.dart';

class BettyApp extends ConsumerStatefulWidget {
  const BettyApp({super.key});

  @override
  ConsumerState<BettyApp> createState() => _BettyAppState();
}

class _BettyAppState extends ConsumerState<BettyApp> {
  @override
  void initState() {
    super.initState();
    // Verificar sesión al iniciar (primero Isar offline, luego Supabase)
    Future.microtask(() {
      ref.read(authProvider.notifier).checkAuthStatus();
    });
    // Inicializar el SyncProvider para que escuche lifecycle + connectivity
    Future.microtask(() {
      ref.read(syncProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppStrings.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
