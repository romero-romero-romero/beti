import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:betty_app/core/widgets/main_shell.dart';
import 'package:betty_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:betty_app/features/auth/presentation/screens/login_screen.dart';
import 'package:betty_app/features/auth/presentation/screens/register_screen.dart';
import 'package:betty_app/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:betty_app/features/transactions/presentation/screens/preview_correction_screen.dart';
import 'package:betty_app/features/input_capture/presentation/screens/voice_capture_screen.dart';
import 'package:betty_app/features/input_capture/presentation/screens/ocr_capture_screen.dart';
import 'package:betty_app/features/cards_credits/presentation/screens/add_card_screen.dart';

/// Provider de GoRouter que reacciona al estado de autenticación.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthenticated = authState is AuthAuthenticated;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (isAuthenticated && isAuthRoute) return '/home';
      if (!isAuthenticated && !isAuthRoute) return '/login';
      return null;
    },
    routes: [
      // ── Auth ──
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

      // ── App principal (con bottom nav) ──
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const MainShell(),
      ),

      // ── Rutas hijas (se abren sobre el shell) ──
      GoRoute(
        path: '/add-transaction',
        name: 'addTransaction',
        builder: (context, state) => const AddTransactionScreen(),
      ),
      GoRoute(
        path: '/preview',
        name: 'preview',
        builder: (context, state) => const PreviewCorrectionScreen(),
      ),
      GoRoute(
        path: '/voice-capture',
        name: 'voiceCapture',
        builder: (context, state) => const VoiceCaptureScreen(),
      ),
      GoRoute(
        path: '/ocr-capture',
        name: 'ocrCapture',
        builder: (context, state) => const OcrCaptureScreen(),
      ),
      GoRoute(
        path: '/add-card',
        name: 'addCard',
        builder: (context, state) => const AddCardScreen(),
      ),
    ],
  );
});