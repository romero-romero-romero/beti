import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:betty_app/core/database/isar_instance.dart';
import 'package:betty_app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cargar variables de entorno
  await dotenv.load(fileName: '.env');

  // 2. Inicializar Isar (fuente de verdad local)
  await IsarInstance.initialize();

  // 3. Inicializar Supabase (solo para Auth + Backup sync)
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true,
    );
  } catch (e) {
    // Si Supabase falla (sin internet), la app sigue funcionando offline.
    debugPrint('Supabase init failed (offline mode): $e');
  }

  // 4. Lanzar la app con Riverpod como contenedor de estado
  runApp(
    const ProviderScope(
      child: BettyApp(),
    ),
  );
}
