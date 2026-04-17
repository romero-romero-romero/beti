import 'package:flutter/cupertino.dart';
import 'package:beti_app/core/enums/health_level.dart';

/// Paleta de colores emocional de Betty.
/// Colores principales: verde, negro, gris, blanco.
/// Cada nivel de salud financiera mapea a un color específico.
class AppColors {
  AppColors._();

  // ── Marca Betty ──
  static const Color primary = Color(0xFF2ECC71);
  static const Color primaryDark = Color(0xFF27AE60);
  static const Color primaryLight = Color(0xFFD5F5E3);
  static const Color accent = Color(0xFF1ABC9C);

  // ── Neutros (Negro, Gris, Blanco) ──
  static const Color black = Color(0xFF1A1A1A);
  static const Color darkGrey = Color(0xFF2D3436);
  static const Color grey = Color(0xFF636E72);
  static const Color lightGrey = Color(0xFFB2BEC3);
  static const Color offWhite = Color(0xFFF1F2F6);
  static const Color white = Color(0xFFFFFFFF);

  // ── Termómetro emocional ──
  static const Color peace = Color(0xFF2ECC71);
  static const Color stable = Color(0xFF3498DB);
  static const Color warning = Color(0xFFF39C12);
  static const Color danger = Color(0xFFE67E22);
  static const Color crisis = Color(0xFFE74C3C);

  // ── Superficies ──
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF2A2A2A);

  // ── Texto ──
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF636E72);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB2BEC3);

  // ── Transacciones ──
  static const Color income = Color(0xFF2ECC71);
  static const Color expense = Color(0xFFE74C3C);

  // ── Gradientes para Balance Card ──
  static const List<Color> balanceGradientLight = [
    Color(0xFF1A1A1A),
    Color(0xFF2D3436),
  ];
  static const List<Color> balanceGradientDark = [
    Color(0xFF2A2A2A),
    Color(0xFF3D3D3D),
  ];

  /// Color CupertinoColor adaptivo para iOS.
  static const CupertinoDynamicColor cupertinoSystemBackground =
      CupertinoColors.systemGroupedBackground;

  /// Retorna el color correspondiente al nivel de salud financiera.
  static Color fromHealthLevel(HealthLevel level) {
    switch (level) {
      case HealthLevel.peace:
        return peace;
      case HealthLevel.stable:
        return stable;
      case HealthLevel.warning:
        return warning;
      case HealthLevel.danger:
        return danger;
      case HealthLevel.crisis:
        return crisis;
    }
  }

  /// Retorna el emoji del nivel de salud.
  static String emojiForLevel(HealthLevel level) {
    return switch (level) {
      HealthLevel.peace => '😌',
      HealthLevel.stable => '🙂',
      HealthLevel.warning => '😟',
      HealthLevel.danger => '😰',
      HealthLevel.crisis => '🆘',
    };
  }

  /// Color de fondo suave para el termómetro según nivel.
  static Color healthBackground(HealthLevel level, {bool isDark = false}) {
    final color = fromHealthLevel(level);
    return isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.08);
  }
}
