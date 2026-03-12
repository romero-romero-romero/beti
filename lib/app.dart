import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/core/constants/app_strings.dart';
import 'package:betty_app/core/theme/app_theme.dart';
import 'package:betty_app/router/app_router.dart';

class BettyApp extends ConsumerWidget {
  const BettyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppStrings.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
