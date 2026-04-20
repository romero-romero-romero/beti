import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beti_app/core/database/isar_instance.dart';
import 'package:beti_app/app.dart';
import 'package:beti_app/features/alerts/data/services/alert_scheduler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Inicializar datos de locale para DateFormat('es_MX')
  await initializeDateFormatting('es_MX', null);

  // 1. Cargar variables de entorno
  await dotenv.load(fileName: '.env');

  // 2. Inicializar Isar PRIMERO (fuente de verdad local, siempre funciona)
  await IsarInstance.initialize();
  await AlertScheduler.initialize();

  // 3. Inicializar Supabase (puede fallar sin internet — la app sigue offline)
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  // Soporta ambos nombres durante la migración: nuevo preferido, legacy como fallback
  final supabaseKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
      dotenv.env['SUPABASE_ANON_KEY'] ??
      '';

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } catch (e) {
    // Supabase init failed (offline mode)
  }

  // 4. Lanzar la app con Riverpod
  runApp(
    const ProviderScope(
      child: BetiApp(),
    ),
  );
}
