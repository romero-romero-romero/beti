import 'package:uuid/uuid.dart';

/// Generador de UUID v4 para IDs offline-safe.
/// Garantiza cero colisiones al sincronizar con Supabase.
class UuidGenerator {
  static const _uuid = Uuid();

  UuidGenerator._();

  /// Genera un UUID v4 único.
  static String generate() => _uuid.v4();
}
