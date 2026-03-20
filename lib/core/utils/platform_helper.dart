import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Utilidad para decisiones de UI adaptiva.
/// Determina si usar Cupertino (iOS) o Material (Android/otros).
class PlatformHelper {
  PlatformHelper._();

  /// True si la plataforma es iOS (o macOS para desarrollo).
  static bool get isApple {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  /// True si la plataforma es Android.
  static bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  /// True si estamos en web.
  static bool get isWeb => kIsWeb;
}
