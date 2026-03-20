import 'package:flutter/material.dart';
import 'package:betty_app/core/enums/health_level.dart';

/// Paleta de colores emocional de Betty.
/// Cada nivel de salud financiera mapea a un color específico.
class AppColors {
  AppColors._();

  // ── Marca ──
  static const Color primary = Color(0xFF2ECC71);
  static const Color primaryDark = Color(0xFF27AE60);
  static const Color accent = Color(0xFF3498DB);

  // ── Termómetro emocional ──
  static const Color peace = Color(0xFF2ECC71);
  static const Color stable = Color(0xFF3498DB);
  static const Color warning = Color(0xFFF39C12);
  static const Color danger = Color(0xFFE67E22);
  static const Color crisis = Color(0xFFE74C3C);

  // ── Superficies ──
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF16213E);

  // ── Texto ──
  static const Color textPrimaryLight = Color(0xFF2D3436);
  static const Color textSecondaryLight = Color(0xFF636E72);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB2BEC3);

  // ── Transacciones ──
  static const Color income = Color(0xFF2ECC71);
  static const Color expense = Color(0xFFE74C3C);

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
}
