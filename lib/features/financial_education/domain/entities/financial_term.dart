// lib/features/financial_education/domain/entities/financial_term.dart

import 'package:flutter/foundation.dart';

/// Entidad pura de un término financiero educativo.
///
/// Representa un concepto que puede ser confuso para usuarios nuevos en
/// finanzas personales (fecha de corte, CAT, gasto hormiga, etc.) junto
/// con su explicación empática en tres bloques.
///
/// El contenido vive de forma estática en [FinancialTermsCatalog] —
/// esta entidad no se persiste en Isar ni se sincroniza.
@immutable
class FinancialTerm {
  /// Identificador estable en snake_case (ej: "cutoff_date", "cat_rate").
  /// Se usa como clave de búsqueda en el catálogo y como clave para
  /// registrar en SharedPreferences si el usuario ya lo consultó.
  ///
  /// NUNCA cambia aunque se edite el contenido del término.
  final String key;

  /// Título mostrado en el bottom sheet y usado como referencia inline.
  /// Ejemplo: "Fecha de corte".
  final String title;

  /// Bloque 1: definición en una oración, lenguaje cotidiano, sin jerga.
  final String whatIs;

  /// Bloque 2: por qué importa al usuario en términos concretos.
  final String whyItMatters;

  /// Bloque 3: tip accionable de Beti en tono empático.
  /// Si está vacío, el bottom sheet oculta este bloque.
  final String bettyTip;

  /// Agrupamiento temático del término.
  final FinancialTermCategory category;

  const FinancialTerm({
    required this.key,
    required this.title,
    required this.whatIs,
    required this.whyItMatters,
    required this.bettyTip,
    required this.category,
  });

  /// Indica si el término tiene tip de Beti definido.
  bool get hasTip => bettyTip.trim().isNotEmpty;
}

/// Agrupamientos temáticos para organizar y filtrar términos.
///
/// Si más adelante se agrega una pantalla "Glosario completo",
/// estas categorías sirven como secciones.
enum FinancialTermCategory {
  creditCards,
  budgeting,
  savings,
  credits,
  general,
}