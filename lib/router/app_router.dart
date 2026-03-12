import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:betty_app/features/auth/presentation/screens/login_screen.dart';
import 'package:betty_app/features/auth/presentation/screens/register_screen.dart';

// Placeholder screens — se implementan en Fase 5
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Betty — Home (Fase 5)')),
    );
  }
}

/// Configuración de rutas con GoRouter.
/// El guard de autenticación verifica sesión local (Isar) para funcionar offline.
final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
  // TODO Fase 2: Agregar redirect guard basado en sesión de Isar
);
