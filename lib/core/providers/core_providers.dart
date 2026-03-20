import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:betty_app/core/database/isar_instance.dart';

/// Provider global de la instancia de Isar (fuente de verdad local).
/// Se inicializa en main.dart antes de runApp().
final isarProvider = Provider<Isar>((ref) {
  return IsarInstance.instance;
});

/// Provider global del cliente de Supabase (backup + auth).
/// Puede lanzar si Supabase no se inicializó (sin internet al abrir la app).
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
