// lib/features/cards_credits/data/credit_card_catalog.dart

/// Catálogo de tarjetas de crédito mexicanas con su CAT promedio.
///
/// Fuente: datos públicos de instituciones financieras mexicanas.
/// Se usa para autocompletar la tasa al registrar una tarjeta.
class CreditCardCatalog {
  CreditCardCatalog._();

  static const List<CatalogCard> _cards = [
    // Afirme
    CatalogCard('Afirme', 'HEB', 87.12),
    CatalogCard('Afirme', 'Clásica', 61.19),
    CatalogCard('Afirme', 'Tigres Afirme', 71.77),
    CatalogCard('Afirme', 'Platinum', 64.88),
    CatalogCard('Afirme', 'Oro', 49.79),
    CatalogCard('Afirme', 'Básica', 70.42),
    // American Express
    CatalogCard('American Express', 'The Platinum Card', 60.59),
    CatalogCard('American Express', 'The Gold Elite', 64.52),
    CatalogCard('American Express', 'The Gold Card', 65.63),
    CatalogCard('American Express', 'Básica', 61.10),
    CatalogCard('American Express', 'The Platinum Aeromexico', 63.84),
    CatalogCard('American Express', 'Gold Card Aeromexico', 64.85),
    CatalogCard('American Express', 'La Tarjeta (Verde)', 62.83),
    CatalogCard('American Express', 'Aeroméxico Azul', 65.50),
    CatalogCard('American Express', 'Interjet Platinum', 60.52),
    CatalogCard('American Express', 'The Platinum Skyplus', 60.45),
    CatalogCard('American Express', 'Interjet Gold', 67.25),
    // Banamex
    CatalogCard('Banamex', 'Joy (Simplicity)', 62.19),
    CatalogCard('Banamex', 'Oro', 59.96),
    CatalogCard('Banamex', 'Costco', 59.60),
    CatalogCard('Banamex', 'Clásica', 61.70),
    CatalogCard('Banamex', 'The Home Depot', 62.25),
    CatalogCard('Banamex', 'Descubre (Rewards)', 59.84),
    CatalogCard('Banamex', 'Affinity Card', 61.98),
    CatalogCard('Banamex', 'Platinum', 41.74),
    CatalogCard('Banamex', 'B•smart', 61.70),
    CatalogCard('Banamex', 'Explora (Premier)', 56.23),
    CatalogCard('Banamex', 'Office Depot', 62.17),
    CatalogCard('Banamex', 'Teletón', 61.49),
    CatalogCard('Banamex', 'Base', 60.73),
    CatalogCard('Banamex', 'Conquista', 49.27),
    CatalogCard('Banamex', 'Beyond', 61.55),
    CatalogCard('Banamex', 'LineUp', 60.38),
    CatalogCard('Banamex', 'La Comer', 62.37),
    CatalogCard('Banamex', 'Best Buy', 61.50),
    // BanBajio
    CatalogCard('BanBajio', 'Clásica', 56.78),
    CatalogCard('BanBajio', 'Oro', 49.98),
    CatalogCard('BanBajio', 'Platinum', 34.90),
    CatalogCard('BanBajio', 'Clásica Garantizada', 60.00),
    CatalogCard('BanBajio', 'Básica', 55.00),
    // Banco Azteca
    CatalogCard('Banco Azteca', 'Oro', 78.58),
    CatalogCard('Banco Azteca', 'Verde', 78.48),
    // BanCoppel
    CatalogCard('BanCoppel', 'Básica VISA', 64.04),
    CatalogCard('BanCoppel', 'Grupo Coppel', 59.10),
    CatalogCard('BanCoppel', 'Oro', 57.05),
    CatalogCard('BanCoppel', 'Platinum', 65.45),
    // Banorte
    CatalogCard('Banorte', 'Clásica', 67.05),
    CatalogCard('Banorte', 'Oro', 64.55),
    CatalogCard('Banorte', 'Platinum', 40.30),
    CatalogCard('Banorte', 'Mujer Banorte', 63.09),
    CatalogCard('Banorte', 'Básica', 67.31),
    CatalogCard('Banorte', 'Por Ti', 59.18),
    CatalogCard('Banorte', 'Selección Nacional', 65.39),
    CatalogCard('Banorte', 'One Up', 64.59),
    CatalogCard('Banorte', 'Marriot Bonvoy', 63.06),
    CatalogCard('Banorte', 'United', 53.55),
    CatalogCard('Banorte', 'Tarjeta 40', 69.00),
    CatalogCard('Banorte', 'AT&T', 68.83),
    CatalogCard('Banorte', 'AT&T Elite', 65.39),
    CatalogCard('Banorte', 'Infinite', 39.96),
    CatalogCard('Banorte', 'W Radio', 64.96),
    CatalogCard('Banorte', 'United Universe', 43.31),
    CatalogCard('Banorte', 'La Comer', 67.78),
    // Banregio
    CatalogCard('Banregio', 'MÁS', 26.94),
    CatalogCard('Banregio', 'Gold', 47.30),
    CatalogCard('Banregio', 'Platinum', 29.92),
    CatalogCard('Banregio', 'Clásica', 43.84),
    // BBVA Bancomer
    CatalogCard('BBVA Bancomer', 'Azul', 56.89),
    CatalogCard('BBVA Bancomer', 'Oro', 54.82),
    CatalogCard('BBVA Bancomer', 'Vive', 61.47),
    CatalogCard('BBVA Bancomer', 'Platinum', 38.81),
    CatalogCard('BBVA Bancomer', 'Crea', 71.98),
    CatalogCard('BBVA Bancomer', 'Afinidad UNAM', 62.85),
    CatalogCard('BBVA Bancomer', 'Rayados', 56.10),
    CatalogCard('BBVA Bancomer', 'Mi Primera Tarjeta', 59.58),
    CatalogCard('BBVA Bancomer', 'IPN', 64.21),
    CatalogCard('BBVA Bancomer', 'Congelada', 59.77),
    CatalogCard('BBVA Bancomer', 'Educación', 60.95),
    CatalogCard('BBVA Bancomer', "Sam's Club Style", 55.04),
    // Bradescard
    CatalogCard('Bradescard', 'C&A Visa', 87.71),
    CatalogCard('Bradescard', 'Bodega Aurrera', 109.75),
    CatalogCard('Bradescard', 'Promoda Visa', 92.94),
    CatalogCard('Bradescard', 'C&A Pay', 94.62),
    CatalogCard('Bradescard', 'Gana+ Visa', 104.87),
    CatalogCard('Bradescard', 'Shasa Visa', 92.90),
    CatalogCard('Bradescard', 'Total', 99.22),
    CatalogCard('Bradescard', 'C&A Trend', 92.54),
    CatalogCard('Bradescard', 'Promoda', 95.07),
    CatalogCard('Bradescard', 'Bradescard Cuidado con el Perro', 99.53),
    CatalogCard('Bradescard', 'CrediBodega', 109.38),
    CatalogCard('Bradescard', 'Shasa', 92.88),
    CatalogCard('Bradescard', 'Gana+', 104.84),
    CatalogCard('Bradescard', 'Suburbia', 92.94),
    CatalogCard('Bradescard', 'Cosmos', 76.62),
    // CiBanco
    CatalogCard('CiBanco', 'CIBanco Oro', 138.00),
    // Citibanamex
    CatalogCard('Citibanamex', 'Simplicity', 62.05),
    CatalogCard('Citibanamex', 'Oro', 59.91),
    CatalogCard('Citibanamex', 'Clásica', 62.53),
    CatalogCard('Citibanamex', 'Costco', 61.23),
    CatalogCard('Citibanamex', 'The Home Depot', 62.58),
    CatalogCard('Citibanamex', 'Citi Rewards', 60.37),
    CatalogCard('Citibanamex', 'Affinity Card', 62.48),
    CatalogCard('Citibanamex', 'Platinum', 41.28),
    CatalogCard('Citibanamex', 'B•smart', 62.61),
    CatalogCard('Citibanamex', 'Citi Premier', 59.57),
    CatalogCard('Citibanamex', 'Office Depot', 61.76),
    CatalogCard('Citibanamex', 'Teletón', 62.50),
    CatalogCard('Citibanamex', 'Premier', 58.84),
    CatalogCard('Citibanamex', 'Base', 62.36),
    CatalogCard('Citibanamex', 'Martí Clásica', 62.32),
    CatalogCard('Citibanamex', 'Citi AAdvantage', 62.03),
    CatalogCard('Citibanamex', 'Best Buy', 62.65),
    CatalogCard('Citibanamex', 'APAC', 62.71),
    // Didi
    CatalogCard('Didi', 'DiDi Card', 92.11),
    // Falabella
    CatalogCard('Falabella', 'Soriana MasterCard', 102.53),
    CatalogCard('Falabella', 'Soriana Pagos Fijos', 101.34),
    CatalogCard('Falabella', 'Soriana Privada', 99.28),
    // Hey Banco
    CatalogCard('Hey Banco', 'Cuenta Hey', 44.98),
    // HSBC
    CatalogCard('HSBC', 'Zero', 69.89),
    CatalogCard('HSBC', 'VIVA', 70.88),
    CatalogCard('HSBC', 'Air', 42.31),
    CatalogCard('HSBC', '2Now', 69.80),
    CatalogCard('HSBC', 'Clásica', 69.87),
    CatalogCard('HSBC', 'Básica', 70.09),
    CatalogCard('HSBC', 'Oro', 64.92),
    CatalogCard('HSBC', 'Premier World Elite', 30.13),
    CatalogCard('HSBC', 'VIVA PLUS', 58.90),
    CatalogCard('HSBC', 'Advance Platinum', 47.50),
    CatalogCard('HSBC', 'Easy Points', 67.00),
    CatalogCard('HSBC', 'Platinum', 47.49),
    CatalogCard('HSBC', 'Acceso', 70.87),
    // Inbursa
    CatalogCard('Inbursa', "Sam's Club", 64.64),
    CatalogCard('Inbursa', 'Oro', 45.74),
    CatalogCard('Inbursa', 'Clásica', 58.45),
    CatalogCard('Inbursa', 'Walmart', 68.96),
    CatalogCard('Inbursa', 'Bodega Aurrera', 80.28),
    CatalogCard('Inbursa', 'Black American Express', 29.72),
    CatalogCard('Inbursa', 'Telcel Inbursa', 47.94),
    CatalogCard('Inbursa', 'Platinum', 34.35),
    CatalogCard('Inbursa', 'Interjet Clásica', 70.50),
    CatalogCard('Inbursa', 'Naturgy', 69.00),
    CatalogCard('Inbursa', 'Interjet Platinum', 52.00),
    CatalogCard('Inbursa', 'Enlace Médico', 47.00),
    CatalogCard('Inbursa', 'Fundación UNAM', 51.00),
    CatalogCard('Inbursa', 'Óbtima', 39.00),
    // Invex
    CatalogCard('Invex', 'Volaris Invex 0', 111.26),
    CatalogCard('Invex', 'Volaris Invex 2.0', 107.07),
    CatalogCard('Invex', 'Volaris Invex Platinum', 107.61),
    CatalogCard('Invex', 'Volaris Invex Clásica', 116.89),
    CatalogCard('Invex', 'Ikea Invex', 69.20),
    CatalogCard('Invex', 'Despegar Gold', 116.66),
    CatalogCard('Invex', 'Despegar Platinum', 105.73),
    CatalogCard('Invex', 'Now', 54.59),
    CatalogCard('Invex', 'Claire', 20.01),
    CatalogCard('Invex', 'Manchester United', 93.19),
    CatalogCard('Invex', 'Sícard Plus', 105.38),
    CatalogCard('Invex', 'Volaris Invex 2.0 Oro', 82.18),
    CatalogCard('Invex', 'BAM', 81.00),
    CatalogCard('Invex', 'CIBanco Oro', 94.25),
    CatalogCard('Invex', 'Volaris Oro', 65.83),
    CatalogCard('Invex', 'Business', 118.23),
    CatalogCard('Invex', 'Sícard Platinum', 139.83),
    CatalogCard('Invex', 'MULTIVA Oro', 120.18),
    CatalogCard('Invex', 'Farmacias Guadalajara', 83.00),
    CatalogCard('Invex', 'Sícard Básica', 48.00),
    CatalogCard('Invex', 'MULTIVA Platinum', 75.00),
    // Klar
    CatalogCard('Klar', 'Klar', 81.77),
    // Liverpool
    CatalogCard('Liverpool', 'Departamental', 63.83),
    CatalogCard('Liverpool', 'Liverpool Visa', 61.72),
    // Mercado Pago
    CatalogCard('Mercado Pago', 'Tarjeta de crédito Mercado Pago', 83.06),
    // Mifel
    CatalogCard('Mifel', 'Oro', 56.49),
    CatalogCard('Mifel', 'Platino', 37.72),
    CatalogCard('Mifel', 'Básica', 56.94),
    CatalogCard('Mifel', 'Miles & More', 57.00),
    // Multiva
    CatalogCard('Multiva', 'MULTIVA Oro', 141.00),
    // Nu México
    CatalogCard('Nu México', 'Nu', 86.06),
    // Openbank
    CatalogCard('Openbank', 'Openbank', 67.91),
    // Palacio de Hierro
    CatalogCard('Palacio de Hierro', 'Palacio', 63.79),
    // Plata
    CatalogCard('Plata', 'Plata Card', 103.78),
    // Rappi
    CatalogCard('Rappi', 'RappiCard', 77.92),
    // Santander
    CatalogCard('Santander', 'LikeU', 66.53),
    CatalogCard('Santander', 'Free', 68.60),
    CatalogCard('Santander', 'American Express', 63.84),
    CatalogCard('Santander', 'Gold (Light)', 51.43),
    CatalogCard('Santander', 'Access Mastercard', 64.71),
    CatalogCard('Santander', 'Aeromexico', 68.18),
    CatalogCard('Santander', 'Fiesta Rewards Oro', 63.03),
    CatalogCard('Santander', 'Fiesta Rewards Platino', 58.96),
    CatalogCard('Santander', 'Uni-Santander K', 67.55),
    CatalogCard('Santander', 'Zero', 69.09),
    CatalogCard('Santander', 'Platinum', 58.29),
    CatalogCard('Santander', 'Access VISA', 67.77),
    CatalogCard('Santander', 'Clásica', 66.96),
    CatalogCard('Santander', 'Aeromexico Platinum', 56.81),
    CatalogCard('Santander', 'Samsung', 52.12),
    CatalogCard('Santander', 'Oro Cash', 59.62),
    CatalogCard('Santander', 'Oro Internacional', 57.66),
    CatalogCard('Santander', 'Black Unlimited Mastercard', 59.03),
    CatalogCard('Santander', 'Fiesta Rewards Clásica', 62.31),
    CatalogCard('Santander', 'Elite Rewards Oro', 55.83),
    CatalogCard('Santander', 'Aeromexico Infinite', 44.41),
    CatalogCard('Santander', 'Delta Oro', 58.86),
    CatalogCard('Santander', 'World Elite', 28.28),
    CatalogCard('Santander', 'FlexCard', 51.32),
    CatalogCard('Santander', 'Elite Rewards Platino', 57.28),
    CatalogCard('Santander', 'Black', 57.35),
    CatalogCard('Santander', 'Universidad Panamericana', 53.48),
    // Scotiabank
    CatalogCard('Scotiabank', 'IDEAL', 79.17),
    CatalogCard('Scotiabank', 'Travel Platinum', 48.40),
    CatalogCard('Scotiabank', 'Travel Clásica', 72.78),
    CatalogCard('Scotiabank', 'Travel Oro', 68.94),
    CatalogCard('Scotiabank', 'Básica', 76.72),
    CatalogCard('Scotiabank', 'Travel World Elite', 46.07),
    CatalogCard('Scotiabank', 'Tradicional Oro', 70.30),
    CatalogCard('Scotiabank', 'Signature', 35.41),
    CatalogCard('Scotiabank', 'Advantage Platinum', 48.40),
    CatalogCard('Scotiabank', 'Advantage World Elite', 42.40),
    CatalogCard('Scotiabank', 'Tradicional Clásica', 76.60),
    CatalogCard('Scotiabank', 'Tasa Baja Oro', 71.29),
    CatalogCard('Scotiabank', 'Tasa Baja Clásica', 75.56),
    // Stori
    CatalogCard('Stori', 'Stori Clásica', 115.34),
    CatalogCard('Stori', 'Stori Black', 101.19),
    // Suburbia
    CatalogCard('Suburbia', 'Departamental', 82.80),
    CatalogCard('Suburbia', 'Visa', 84.45),
    // Ualá ABC
    CatalogCard('Ualá ABC', 'Ualá', 77.76),
    // Vexi
    CatalogCard('Vexi', 'Vexi American Express', 83.38),
    CatalogCard('Vexi', 'Vexi Carnet', 84.80),
  ];

  /// Busca tarjetas por texto libre (banco o nombre).
  /// Retorna máximo [limit] resultados.
  static List<CatalogCard> search(String query, {int limit = 10}) {
    if (query.trim().length < 2) return [];
    final q = query.toLowerCase();

    // Primero: matches donde banco o nombre empieza con la query
    final startsWith = _cards.where((c) =>
        c.bank.toLowerCase().startsWith(q) ||
        c.name.toLowerCase().startsWith(q));

    // Segundo: matches que contienen la query (sin duplicar)
    final contains = _cards.where((c) =>
        !c.bank.toLowerCase().startsWith(q) &&
        !c.name.toLowerCase().startsWith(q) &&
        (c.bank.toLowerCase().contains(q) || c.name.toLowerCase().contains(q)));

    return [...startsWith, ...contains].take(limit).toList();
  }

  /// Todos los bancos únicos.
  static List<String> get banks {
    final seen = <String>{};
    return _cards.map((c) => c.bank).where((b) => seen.add(b)).toList();
  }

  /// Tarjetas de un banco específico.
  static List<CatalogCard> byBank(String bank) {
    return _cards.where((c) => c.bank == bank).toList();
  }

  /// Total de tarjetas en el catálogo.
  static int get count => _cards.length;
}

/// Entrada del catálogo: banco + nombre + CAT promedio.
class CatalogCard {
  final String bank;
  final String name;

  /// CAT promedio en porcentaje (ej: 57.0 = 57%).
  final double catPercent;

  const CatalogCard(this.bank, this.name, this.catPercent);

  /// Label para mostrar en UI.
  String get displayLabel => '$bank · $name';

  /// Tasa como decimal (ej: 0.57).
  double get rateDecimal => catPercent / 100;
}
