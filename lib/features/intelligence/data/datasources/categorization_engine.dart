import 'package:betty_app/core/enums/category_type.dart';
import 'package:betty_app/core/enums/transaction_type.dart';

/// Motor híbrido de categorización (MVP).
///
/// Fase actual: Regex/Tokenization por keywords en español.
/// Las correcciones manuales del usuario se almacenan en CategoryModel
/// y alimentarán el modelo TFLite en fases futuras.
class CategorizationEngine {
  CategorizationEngine._();

  /// Mapa de keywords → categoría.
  /// Cada keyword está en lowercase y sin acentos para matching flexible.
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

  /// Predice la categoría basándose en la descripción.
  /// Retorna [CategoryType.other] si no encuentra coincidencia.
  static CategoryType predict(String description) {
    final normalized = _normalize(description);

    // Buscar coincidencia exacta de multi-palabra primero (más específico)
    for (final entry in _keywordMap.entries) {
      for (final keyword in entry.value) {
        if (keyword.contains(' ')) {
          // Multi-palabra: buscar como substring
          if (normalized.contains(keyword)) {
            return entry.key;
          }
        }
      }
    }

    // Luego buscar palabras individuales
    final words = normalized.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length < 3) continue; // Ignorar palabras muy cortas

      for (final entry in _keywordMap.entries) {
        for (final keyword in entry.value) {
          if (!keyword.contains(' ') && word == keyword) {
            return entry.key;
          }
          // Coincidencia parcial para palabras largas (>= 5 chars)
          if (!keyword.contains(' ') && keyword.length >= 5 && word.startsWith(keyword.substring(0, 5))) {
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

  /// Normaliza texto: lowercase, sin acentos, sin caracteres especiales.
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
}
