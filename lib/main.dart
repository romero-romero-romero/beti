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

  // 2. Inicializar Isar PRIMERO (fuente de verdad local, siempre funciona)
  await IsarInstance.initialize();

  // 3. Inicializar Supabase (puede fallar sin internet — la app sigue offline)
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase init failed (offline mode): $e');
  }

  // 4. Lanzar la app con Riverpod
  runApp(
    const ProviderScope(
      child: BettyApp(),
    ),
  );
}
