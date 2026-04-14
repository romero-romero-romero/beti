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
    final words =
        normalized.split(RegExp(r'\s+')).where((w) => w.length >= 3).toList();

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
      // Establecimientos
      'restaurante', 'fonda', 'fondita', 'comedor', 'cocina', 'buffet',
      'cafeteria', 'cafebreria', 'cafe', 'coffee', 'starbucks', 'cielito',
      'italian coffee', 'the coffee', 'cappuccino', 'latte', 'espresso',
      // Comidas
      'comida', 'cena', 'almuerzo', 'desayuno', 'brunch', 'merienda',
      'lonche', 'lunch', 'snack', 'botanita', 'botana',
      // Platillos MX regionales
      'tacos', 'torta', 'tortas', 'quesadilla', 'gordita', 'sope',
      'tamales', 'pozole', 'enchiladas', 'chilaquiles', 'birria',
      'carnitas', 'barbacoa', 'menudo', 'elote', 'esquite', 'tlayuda',
      'huarache', 'pambazo', 'flautas', 'tostada', 'burrito', 'ceviche',
      'cochinita', 'cochinita pibil', 'panuchos', 'salbutes', 'papadzules',
      'marquesitas', 'poc chuc', 'relleno negro', 'queso relleno',
      'machaca', 'carne asada', 'cabrito', 'cortadillo', 'discada',
      'burritos', 'chimichangas', 'carne seca', 'sobaquera',
      'mole', 'mole negro', 'mole poblano', 'mole amarillo', 'chapulines',
      'tasajo', 'cecina', 'memela', 'tetela', 'garnachas',
      'chalupas', 'cemita', 'molote', 'taco arabe', 'tacos de canasta',
      'pozole rojo', 'pozole verde', 'pozole blanco',
      'aguachile', 'callo de hacha', 'marlin', 'camarones',
      'pescado zarandeado', 'tostada de ceviche', 'mariscos', 'mariscada',
      'empanada', 'pastes', 'gorditas de horno', 'pachola',
      'enchiladas mineras', 'guacamayas', 'tacos dorados',
      'tacos de guisado', 'tacos al pastor', 'tacos de suadero',
      'tacos de tripa', 'tacos de cabeza', 'tacos de birria',
      'torta ahogada', 'lonches', 'jericalla', 'tejuino',
      'chamorro', 'chicharron', 'chicharron prensado',
      'corunda', 'uchepo', 'carnitas michoacanas',
      'zacahuil', 'bocoles', 'enchiladas potosinas', 'gorditas de migajas',
      // Platillos internacionales
      'pizza', 'sushi', 'hamburguesa', 'burger', 'hot dog', 'alitas',
      'pollo', 'pasta', 'ramen', 'poke', 'wok', 'curry', 'kebab',
      'shawarma', 'falafel', 'gyros', 'pad thai', 'pho',
      // Cadenas y delivery
      'mcdonalds', 'dominos', 'little caesars', 'kfc', 'subway',
      'burger king', 'wendys', 'carls jr', 'chilis', 'applebees',
      'vips', 'sanborns', 'wings', 'wingstop', 'pizza hut',
      'rappi', 'uber eats', 'didi food', 'cornershop',
      'popeyes', 'church', 'toks', 'el portон', 'la casa de tono',
      'el fogoncito', 'el califa', 'tacos el gordo',
      // Antojitos / informal
      'antojitos', 'puesto', 'carreta', 'tianguis comida',
      'changarro', 'cochinita', 'taqueria', 'marisqueria',
      'cenaduría', 'cenaduria', 'merendero', 'loncherias', 'loncheria',
      // Bebidas
      'cerveza', 'chela', 'michelada', 'refresco', 'jugo', 'smoothie',
      'agua fresca', 'horchata', 'jamaica', 'tepache', 'pulque',
      'tejuino', 'tascalate', 'pozol', 'atole', 'champurrado',
      // Panadería
      'panaderia', 'pan', 'pastel', 'dona', 'churro', 'galleta',
      'concha', 'cuerno', 'polvoron', 'garibaldi', 'oreja',
      // Jerga MX comida
      'tragar', 'tragadera', 'jalon', 'echarse un taco',
      'botanear', 'chupar', 'pistear', 'echarse una chela',
      'merendar', 'cenar', 'desayunar', 'almorzar',
      'garnachear', 'antojarse', 'echarse unas',
    ],
    CategoryType.transport: [
      // Apps de ride
      'uber', 'didi', 'cabify', 'bolt', 'indriver', 'beat',
      // Transporte público
      'metro', 'metrobus', 'camion', 'autobus', 'microbus', 'trolebus',
      'tren ligero', 'macrobus', 'mi macro', 'ruta', 'periferico',
      'suburban', 'combi', 'pesero', 'pecera', 'chimecos',
      'colectivo', 'calafias', 'mototaxi', 'bicitaxi',
      'ecovia', 'transmetro', 'mexibus', 'tuzobús', 'sistema rtp',
      // Taxi
      'taxi', 'sitio', 'radio taxi', 'libre', 'ruletero',
      // Vehículo propio
      'gasolina', 'gas', 'pemex', 'bp', 'shell', 'mobil',
      'estacionamiento', 'parking', 'parquimetro',
      'peaje', 'caseta', 'tag', 'televia', 'pase', 'iave',
      'verificacion', 'tenencia', 'refrendo', 'placas',
      'mecanico', 'taller', 'refaccion', 'llanta', 'afinacion',
      'aceite', 'lavado auto', 'autolavado', 'grua',
      'corralon', 'multa', 'infraccion', 'fotomulta',
      // Viajes
      'avion', 'vuelo', 'aeropuerto', 'aerolinea', 'volaris',
      'vivaaerobus', 'aeromexico', 'flixbus', 'etn', 'primera plus',
      'omnibus', 'pullman', 'ado', 'estrella blanca', 'tap',
      'futura', 'herradura de plata', 'estrella roja',
      'elite', 'turimex', 'noreste', 'senda',
      // Jerga MX transporte
      'raite', 'ride', 'aventón', 'aventon', 'jalón', 'jalon',
      'llevar', 'manejar', 'echarse un uber', 'pedir un didi',
      'cacharro', 'nave', 'ranfla', 'troca', 'carrucha',
    ],
    CategoryType.housing: [
      'renta', 'alquiler', 'hipoteca', 'mantenimiento', 'predial',
      'inmobiliaria', 'departamento', 'casa', 'condominio',
      'mudanza', 'cerrajero', 'plomero', 'electricista', 'pintura',
      'impermeabilizante', 'fumigacion', 'jardinero', 'limpieza hogar',
      'mueble', 'muebles', 'colchon', 'refrigerador', 'estufa',
      'lavadora', 'microondas', 'home depot', 'lowes', 'coppel',
      'elektra', 'famsa', 'koncept', 'recamara',
      'terreno', 'escrituras', 'notario', 'avaluo',
      'cuota mantenimiento', 'vigilancia', 'cisterna', 'tinaco',
      'boiler', 'calentador', 'minisplit', 'aire acondicionado',
      'herreria', 'carpinteria', 'tablaroca', 'azulejo',
      // Jerga MX vivienda
      'depa', 'depita', 'cantón', 'canton', 'chante', 'jacal',
      'choza', 'cueva', 'guarida',
    ],
    CategoryType.utilities: [
      // Servicios básicos
      'luz', 'agua', 'gas natural', 'gas lp', 'cfe', 'recibo',
      'siapa', 'interapas', 'sacmex', 'cespt', 'jmas',
      // Telecom
      'internet', 'telefono', 'celular', 'plan celular', 'recarga',
      'telmex', 'izzi', 'totalplay', 'megacable', 'axtel',
      'telcel', 'att', 'movistar', 'altan', 'bait', 'oui',
      'unefon', 'virgin', 'weex',
      // TV/Streaming como servicio
      'fibra optica', 'cable', 'satelital', 'sky', 'dish',
      'star tv', 'vetv',
    ],
    CategoryType.health: [
      // Profesionales
      'doctor', 'medico', 'dentista', 'oculista', 'psicologo',
      'psiquiatra', 'nutriologo', 'terapeuta', 'fisioterapeuta',
      'quiropractico', 'dermatologo', 'ginecologo', 'pediatra',
      'consulta', 'especialista', 'urologo', 'cardiologo',
      'traumatologo', 'endocrinologo', 'oncologo', 'cirujano',
      'otorrino', 'oftalmologo', 'neurologo', 'angiologo',
      'homeopata', 'acupuntura', 'quiromasaje',
      // Establecimientos
      'hospital', 'clinica', 'laboratorio', 'analisis',
      'cruz roja', 'imss', 'issste', 'seguro popular', 'insabi',
      'hospital general', 'hospital civil', 'angeles', 'star medica',
      'christus muguerza', 'medica sur', 'abc',
      // Farmacias MX
      'farmacia', 'guadalajara', 'similares', 'benavides',
      'san pablo', 'del ahorro', 'gi', 'farmacias', 'farmalisto',
      'genericos', 'doctora', 'consultorio farmacia',
      // Productos
      'medicina', 'medicamento', 'receta', 'lentes', 'anteojos',
      'ortopedia', 'protesis', 'vitaminas', 'suplemento',
      'antibiotico', 'pastilla', 'jarabe', 'inyeccion', 'vacuna',
      'curación', 'curacion', 'vendas', 'alcohol', 'aspirina',
      // Seguros
      'seguro medico', 'seguro gastos', 'poliza salud', 'deducible',
      // Jerga MX salud
      'matasanos', 'botica', 'yerbero', 'curandero', 'sobador',
    ],
    CategoryType.education: [
      // Instituciones
      'escuela', 'universidad', 'colegio', 'prepa', 'preparatoria',
      'kinder', 'guarderia', 'primaria', 'secundaria',
      'conalep', 'cetis', 'cbtis', 'tecnologico', 'politecnico',
      'unam', 'ipn', 'uag', 'udg', 'iteso', 'tec', 'ibero',
      'lasalle', 'anahuac', 'unitec', 'uvm', 'up',
      // Pagos
      'colegiatura', 'inscripcion', 'matricula', 'examen', 'titulo',
      'cedula profesional', 'constancia', 'credencial escolar',
      'transporte escolar', 'cooperacion escolar',
      // Cursos online
      'curso', 'taller', 'diplomado', 'maestria', 'doctorado',
      'certificacion', 'bootcamp', 'seminario', 'congreso',
      'udemy', 'platzi', 'coursera', 'domestika', 'crehana',
      'linkedin learning', 'skillshare', 'duolingo', 'edx',
      // Material
      'libro', 'libros', 'libreria', 'cuaderno', 'papeleria',
      'material escolar', 'mochila', 'uniforme escolar',
      'copias', 'impresion', 'tesis', 'gandhi', 'gonvill',
      'porrua', 'fondo cultura', 'sanborns libros',
    ],
    CategoryType.entertainment: [
      // Streaming
      'netflix', 'spotify', 'disney', 'hbo', 'amazon prime',
      'apple tv', 'paramount', 'star plus', 'crunchyroll',
      'youtube premium', 'twitch', 'deezer', 'tidal', 'vix',
      // Cine y espectáculos
      'cine', 'cinemex', 'cinepolis', 'concierto', 'teatro',
      'museo', 'exposicion', 'festival', 'feria', 'circo',
      'boleto', 'entrada', 'ticketmaster', 'boletia', 'superboletos',
      'palenque', 'rodeo', 'charreada', 'jaripeo', 'lucha libre',
      // Social
      'bar', 'antro', 'fiesta', 'club', 'karaoke', 'cantina',
      'pulqueria', 'mezcaleria', 'botanero', 'cerveceria',
      'terraza', 'rooftop', 'after', 'peda', 'caguama',
      'chelada', 'botaneo', 'table', 'table dance',
      // Juegos
      'videojuego', 'juego', 'steam', 'playstation store',
      'xbox store', 'nintendo', 'gaming', 'arcade',
      'billar', 'boliche', 'go karts', 'laser tag', 'escape room',
      'paintball', 'gotcha', 'karting',
      // Recreación
      'parque', 'balneario', 'alberca', 'playa', 'camping',
      'senderismo', 'escalada', 'six flags', 'selvatica',
      'xcaret', 'xel ha', 'xplor', 'xenses', 'ventura park',
      'la feria', 'kidzania', 'acuario', 'zoologico',
      // Jerga MX entretenimiento
      'reventón', 'reventon', 'pachanga', 'desmadre', 'cotorreo',
      'pistear', 'echar relajo', 'relajo', 'parranda', 'farra',
      'juerga', 'chupe', 'pisto', 'chupar', 'carrete',
    ],
    CategoryType.clothing: [
      // Prendas
      'ropa', 'zapatos', 'tenis', 'camisa', 'pantalon', 'vestido',
      'falda', 'chamarra', 'sudadera', 'playera', 'blusa',
      'traje', 'corbata', 'cinturon', 'bolsa', 'cartera',
      'sombrero', 'gorra', 'calcetines', 'ropa interior',
      'pijama', 'uniforme', 'bata', 'huaraches', 'botas',
      'botines', 'sandalias', 'mocasines', 'guaraches',
      // Tiendas MX
      'zara', 'h&m', 'liverpool', 'palacio', 'sears',
      'suburbia', 'c&a', 'bershka', 'pull and bear', 'stradivarius',
      'massimo dutti', 'forever 21', 'old navy', 'gap',
      'innova sport', 'marti', 'cuidado con el perro',
      'julio', 'andrea', 'flexi', 'price shoes',
      // Online
      'shein', 'amazon moda', 'mercado libre ropa', 'privalia',
      // Marcas deportivas
      'nike', 'adidas', 'puma', 'under armour', 'reebok',
      'new balance', 'skechers', 'vans', 'converse', 'fila',
      // Servicios
      'tintoreria', 'lavanderia', 'costura', 'sastre', 'zapatero',
      'modista', 'bordado',
      // Jerga MX ropa
      'trapos', 'garras', 'pilchas', 'fachoso', 'modelito',
    ],
    CategoryType.subscriptions: [
      'suscripcion', 'membresia', 'mensualidad', 'anualidad', 'renovacion',
      // Fitness
      'gym', 'gimnasio', 'smart fit', 'sport city', 'crossfit', 'yoga',
      'anytime fitness', 'planet fitness', 'gold gym',
      // Cloud / Tech
      'icloud', 'google one', 'apple', 'dropbox', 'adobe',
      'microsoft 365', 'office 365', 'chatgpt', 'openai', 'canva',
      'notion', 'figma', 'github', 'copilot',
      // Gaming
      'xbox game pass', 'playstation plus', 'nintendo online',
      'ea play', 'ubisoft', 'geforce now',
      // Otros
      'amazon prime', 'costco membresia', 'sams membresia',
      'revista', 'periodico', 'patron', 'patreon',
      'priority pass', 'club de vinos', 'cava',
    ],
    CategoryType.debtPayment: [
      'pago tarjeta', 'pago credito', 'abono', 'mensualidad credito',
      'pago prestamo', 'deuda', 'intereses', 'capital', 'liquidacion',
      'meses sin intereses', 'msi', 'credito nomina', 'credito personal',
      'hipotecario', 'pago minimo', 'saldo', 'adeudo',
      'financiamiento', 'prestamo', 'apartado',
      'coppel credito', 'elektra credito', 'fonacot',
      'infonavit', 'fovissste', 'credito automotriz',
      'tandas', 'tanda', 'cundina',
      // Jerga MX deudas
      'deber', 'empenado', 'empeno', 'monte de piedad',
      'casa de empeno', 'primera cash', 'presta prenda',
    ],
    CategoryType.groceries: [
      // Cadenas MX
      'super', 'supermercado', 'walmart', 'soriana', 'chedraui',
      'costco', 'sams', 'bodega aurrera', 'la comer', 'heb',
      'city market', 'fresko', 'superama', 'alsuper', 'ley',
      'mega soriana', 'smart', 'city club', 's mart',
      'casa ley', 'merza', 'zorro abarrotero',
      // Conveniencia
      'oxxo', 'tienda', 'abarrotes', 'miscelanea', 'seven eleven',
      'circle k', 'extra', 'kiosko', 'modelorama', 'six',
      'deposito', 'tendajón', 'tendajon', 'changarro',
      // Mercado
      'mercado', 'central de abasto', 'tianguis', 'verduleria',
      'fruteria', 'carniceria', 'polleria', 'tortilleria',
      'cremeria', 'pescaderia', 'recauderia',
      // General
      'despensa', 'mandado', 'compras casa', 'viveres',
      // Jerga MX compras
      'hacerse de la despensa', 'ir al mandado', 'surtir',
      'abastecer', 'proveer', 'la semana',
    ],
    CategoryType.personalCare: [
      // Establecimientos
      'peluqueria', 'barberia', 'salon', 'estetica', 'spa',
      'manicure', 'pedicure', 'facial', 'masaje', 'depilacion',
      'unas', 'pestanas', 'cejas', 'corte', 'tinte',
      'alisado', 'keratina', 'tratamiento capilar',
      // Productos
      'crema', 'shampoo', 'jabon', 'perfume', 'maquillaje',
      'cosmetico', 'protector solar', 'desodorante', 'rastrillo',
      'cepillo', 'pasta dental', 'higiene', 'toalla sanitaria',
      'pañales', 'panales',
      // Tiendas
      'sephora', 'bath and body', 'mac cosmetics', 'clinique',
      // Jerga MX
      'peluqueada', 'rasurada', 'recorte', 'degrafilado',
      'hacerse las unas', 'arreglarse',
    ],
    CategoryType.gifts: [
      'regalo', 'cumpleanos', 'navidad', 'dia de la madre',
      'dia del padre', 'dia del nino', 'san valentin', 'aniversario',
      'obsequio', 'sorpresa', 'boda', 'baby shower', 'bautizo',
      'primera comunion', 'graduacion', 'xv anos', 'quinceanos',
      'posada', 'intercambio', 'aguinaldo regalo',
      'flores', 'floreria', 'peluche', 'tarjeta regalo',
      'dia de reyes', 'rosca de reyes', 'dia de muertos',
      'ofrenda', 'piñata', 'pinata', 'dulces', 'colación',
      'recuerdo', 'detalle', 'presente',
      // Jerga MX
      'cooperacha', 'vaquita', 'bote', 'kitty',
    ],
    CategoryType.pets: [
      'veterinario', 'veterinaria', 'mascota', 'perro', 'gato',
      'croquetas', 'alimento mascota', 'petco', '+kota', 'pet',
      'vacuna mascota', 'estilista canino', 'grooming',
      'pecera', 'acuario', 'jaula', 'correa', 'collar mascota',
      'antipulgas', 'desparasitante', 'juguete mascota',
      'pedigree', 'whiskas', 'royal canin', 'proplan',
      'dog chow', 'cat chow', 'nupec', 'bravecto',
      // Jerga MX mascotas
      'firulais', 'lomito', 'michis', 'michi', 'peludito',
      'animalito', 'chucho', 'minino',
    ],

    // ── Ingresos ──
    CategoryType.salary: [
      'nomina', 'salario', 'sueldo', 'quincena', 'pago quincenal',
      'deposito nomina', 'transferencia nomina', 'pago semanal',
      'aguinaldo', 'prima vacacional', 'bono', 'compensacion',
      'finiquito', 'liquidacion laboral', 'retroactivo',
      'pago mensual', 'sueldo base', 'ingreso fijo',
      'destajo', 'comision ventas', 'propina', 'gratificacion',
      // Jerga MX salario
      'raya', 'la quince', 'la catorcena', 'el sobre',
      'me cayó', 'me cayo', 'deposito', 'paguita',
    ],
    CategoryType.freelance: [
      'freelance',
      'proyecto',
      'cliente',
      'factura',
      'honorarios',
      'consultoria',
      'servicio profesional',
      'contrato',
      'comision',
      'asesoria',
      'coaching',
      'mentoria',
      'diseno',
      'programacion',
      'desarrollo',
      'traduccion',
      'fotografia',
      'videografia',
      'edicion',
      'community manager',
      'marketing digital',
      'jale',
      'chamba extra',
      'trabajito',
      'encargo',
      'pedido',
      'chambita',
      'negocito',
      'hueso',
    ],
    CategoryType.investment: [
      'rendimiento',
      'dividendo',
      'interes ganado',
      'inversion',
      'cetes',
      'gbm',
      'nu invest',
      'fondo',
      'etf',
      'accion',
      'bono gubernamental',
      'fibra',
      'sofipos',
      'hey banco',
      'nu',
      'dinn',
      'finsus',
      'kuspit',
      'bitcoin',
      'cripto',
      'ethereum',
      'staking',
      'yield',
      'ganancia cambiaria',
      'plusvalia',
      'renta fija',
      'cetesdirecto',
      'udibonos',
      'bonddia',
      'pagare',
      'afore',
      'retiro afore',
      'aportacion voluntaria',
    ],
    CategoryType.refund: [
      'reembolso',
      'devolucion',
      'cashback',
      'bonificacion',
      'cancelacion',
      'regreso',
      'nota credito',
      'compensacion cliente',
      'garantia',
      'seguro cobrado',
      'reclamacion',
      'contracargo',
      'chargeback',
      'reintegro',
    ],
  };
}
