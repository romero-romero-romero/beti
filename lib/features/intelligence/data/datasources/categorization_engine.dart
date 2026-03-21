import 'package:betty_app/core/enums/category_type.dart';
import 'package:betty_app/core/enums/transaction_type.dart';

/// Motor híbrido de categorización (MVP v2).
///
/// Estrategia de 2 niveles:
///   Nivel 1 — Historial del usuario: si el usuario ya categorizó manualmente
///             una descripción similar, respetar esa decisión.
///   Nivel 2 — Keywords estáticas: fallback al mapa de palabras clave.
///
/// Las correcciones manuales alimentan [userOverrides] que se persisten
/// en CategoryModel (Isar) y se cargan al iniciar la app.
class CategorizationEngine {
  CategorizationEngine._();

  // ═══════════════════════════════════════════════════════════
  // Nivel 1: Historial del usuario (overrides aprendidos)
  // ═══════════════════════════════════════════════════════════

  /// Mapa en memoria: keyword normalizada → categoría.
  /// Se carga desde Isar al inicio y se actualiza con cada corrección.
  static final Map<String, CategoryType> _userOverrides = {};

  /// Carga overrides desde una lista de pares keyword→category.
  /// Llamar al inicio de la app con datos de CategoryModel en Isar.
  static void loadUserOverrides(Map<String, CategoryType> overrides) {
    _userOverrides.clear();
    _userOverrides.addAll(overrides);
  }

  /// Registra una corrección manual del usuario.
  /// Se invoca cuando el usuario cambia la categoría en Vista Previa.
  /// Retorna las keywords aprendidas para persistir en Isar.
  static List<String> learnFromCorrection({
    required String description,
    required CategoryType correctedCategory,
  }) {
    final normalized = _normalize(description);
    final words = normalized.split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .toList();

    // Aprender cada palabra significativa
    final learned = <String>[];
    for (final word in words) {
      // No sobreescribir si ya está en keywords estáticas con otra categoría
      // (el usuario puede equivocarse, pero keywords estáticas son confiables)
      if (!_isStaticKeyword(word)) {
        _userOverrides[word] = correctedCategory;
        learned.add(word);
      }
    }

    // También aprender la frase completa si tiene 2+ palabras
    if (words.length >= 2) {
      _userOverrides[normalized] = correctedCategory;
      learned.add(normalized);
    }

    return learned;
  }

  /// Verifica si una palabra ya está en el mapa estático.
  static bool _isStaticKeyword(String word) {
    for (final keywords in _keywordMap.values) {
      if (keywords.contains(word)) return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════════
  // Predicción principal
  // ═══════════════════════════════════════════════════════════

  /// Predice la categoría basándose en la descripción.
  /// Retorna [CategoryType.other] si no encuentra coincidencia.
  static CategoryType predict(String description) {
    final normalized = _normalize(description);

    // ── Nivel 1: Buscar en historial del usuario ──
    final fromHistory = _predictFromHistory(normalized);
    if (fromHistory != null) return fromHistory;

    // ── Nivel 2: Keywords estáticas ──
    return _predictFromKeywords(normalized);
  }

  /// Busca coincidencia en los overrides del usuario.
  static CategoryType? _predictFromHistory(String normalized) {
    if (_userOverrides.isEmpty) return null;

    // Coincidencia exacta de frase completa (más confiable)
    if (_userOverrides.containsKey(normalized)) {
      return _userOverrides[normalized];
    }

    // Coincidencia por palabras individuales
    final words = normalized.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length < 3) continue;
      if (_userOverrides.containsKey(word)) {
        return _userOverrides[word];
      }
    }

    return null;
  }

  /// Busca coincidencia en el mapa de keywords estáticas.
  static CategoryType _predictFromKeywords(String normalized) {
    // Buscar coincidencia exacta de multi-palabra primero (más específico)
    for (final entry in _keywordMap.entries) {
      for (final keyword in entry.value) {
        if (keyword.contains(' ')) {
          if (normalized.contains(keyword)) {
            return entry.key;
          }
        }
      }
    }

    // Luego buscar palabras individuales
    final words = normalized.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length < 3) continue;

      for (final entry in _keywordMap.entries) {
        for (final keyword in entry.value) {
          if (!keyword.contains(' ') && word == keyword) {
            return entry.key;
          }
          // Coincidencia parcial para palabras largas (>= 5 chars)
          if (!keyword.contains(' ') &&
              keyword.length >= 5 &&
              word.startsWith(keyword.substring(0, 5))) {
            return entry.key;
          }
        }
      }
    }

    return CategoryType.other;
  }

  /// Infiere el tipo de transacción basándose en la categoría.
  static TransactionType inferType(CategoryType category) {
    const incomeCategories = {
      CategoryType.salary,
      CategoryType.freelance,
      CategoryType.investment,
      CategoryType.refund,
      CategoryType.otherIncome,
    };
    return incomeCategories.contains(category)
        ? TransactionType.income
        : TransactionType.expense;
  }

  // ═══════════════════════════════════════════════════════════
  // Normalización
  // ═══════════════════════════════════════════════════════════

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ═══════════════════════════════════════════════════════════
  // Keywords estáticas (Nivel 2)
  // ═══════════════════════════════════════════════════════════

  static const Map<CategoryType, List<String>> _keywordMap = {
    // ── Gastos ──
    CategoryType.food: [
      'restaurante', 'comida', 'cena', 'almuerzo', 'desayuno', 'tacos',
      'pizza', 'sushi', 'hamburguesa', 'cafe', 'cafeteria', 'starbucks',
      'mcdonalds', 'burger', 'dominos', 'pollo', 'torta', 'antojitos',
      'fondita', 'rappi', 'uber eats', 'didi food',
    ],
    CategoryType.transport: [
      'uber', 'didi', 'taxi', 'gasolina', 'gas', 'estacionamiento',
      'metro', 'metrobus', 'camion', 'autobus', 'peaje', 'caseta',
      'bolt', 'cabify', 'indriver', 'verificacion', 'tenencia',
    ],
    CategoryType.housing: [
      'renta', 'alquiler', 'hipoteca', 'mantenimiento', 'predial',
      'inmobiliaria', 'departamento', 'casa', 'condominio',
    ],
    CategoryType.utilities: [
      'luz', 'agua', 'gas natural', 'internet', 'telefono', 'celular',
      'cfe', 'telmex', 'izzi', 'totalplay', 'megacable', 'telcel',
      'att', 'movistar', 'recibo',
    ],
    CategoryType.health: [
      'doctor', 'medicina', 'farmacia', 'hospital', 'clinica', 'dentista',
      'oculista', 'lentes', 'consulta', 'receta', 'guadalajara', 'similares',
      'benavides', 'san pablo', 'analisis', 'laboratorio', 'seguro medico',
    ],
    CategoryType.education: [
      'escuela', 'universidad', 'colegiatura', 'curso', 'libro', 'libros',
      'udemy', 'platzi', 'coursera', 'maestria', 'diplomado', 'inscripcion',
      'material escolar', 'cuaderno', 'papeleria',
    ],
    CategoryType.entertainment: [
      'cine', 'netflix', 'spotify', 'disney', 'hbo', 'amazon prime',
      'videojuego', 'juego', 'concierto', 'teatro', 'museo', 'bar',
      'fiesta', 'antro', 'billar', 'boliche', 'parque',
    ],
    CategoryType.clothing: [
      'ropa', 'zapatos', 'tenis', 'camisa', 'pantalon', 'vestido',
      'zara', 'h&m', 'liverpool', 'palacio', 'shein', 'nike', 'adidas',
    ],
    CategoryType.subscriptions: [
      'suscripcion', 'membresia', 'mensualidad', 'gym', 'gimnasio',
      'icloud', 'google one', 'apple', 'xbox', 'playstation', 'crunchyroll',
    ],
    CategoryType.debtPayment: [
      'pago tarjeta', 'pago credito', 'abono', 'mensualidad credito',
      'pago prestamo', 'deuda', 'intereses',
    ],
    CategoryType.groceries: [
      'super', 'supermercado', 'walmart', 'soriana', 'chedraui', 'costco',
      'sams', 'oxxo', 'tienda', 'abarrotes', 'mercado', 'bodega aurrera',
      'la comer', 'heb', 'despensa', 'mandado',
    ],
    CategoryType.personalCare: [
      'peluqueria', 'barberia', 'salon', 'estetica', 'spa', 'manicure',
      'crema', 'shampoo', 'jabon', 'perfume', 'maquillaje',
    ],
    CategoryType.gifts: [
      'regalo', 'cumpleanos', 'navidad', 'dia de la madre', 'aniversario',
      'obsequio', 'sorpresa',
    ],
    CategoryType.pets: [
      'veterinario', 'mascota', 'perro', 'gato', 'croquetas', 'petco',
      'pet', 'vacuna mascota', '+kota',
    ],

    // ── Ingresos ──
    CategoryType.salary: [
      'nomina', 'salario', 'sueldo', 'quincena', 'pago quincenal',
      'deposito nomina', 'transferencia nomina',
    ],
    CategoryType.freelance: [
      'freelance', 'proyecto', 'cliente', 'factura', 'honorarios',
      'consultoria', 'servicio profesional',
    ],
    CategoryType.investment: [
      'rendimiento', 'dividendo', 'interes ganado', 'inversion',
      'cetes', 'gbm', 'nu invest', 'fondo',
    ],
    CategoryType.refund: [
      'reembolso', 'devolucion', 'cashback', 'bonificacion',
    ],
  };
}