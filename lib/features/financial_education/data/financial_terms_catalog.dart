// lib/features/financial_education/data/financial_terms_catalog.dart

import 'package:beti_app/features/financial_education/domain/entities/financial_term.dart';

/// Catálogo estático de términos financieros educativos.
///
/// Contenido en español mexicano, tono empático sin juicios.
/// Para agregar un término: añadirlo al mapa [_terms] con su `key` único.
class FinancialTermsCatalog {
  FinancialTermsCatalog._();

  static const Map<String, FinancialTerm> _terms = {
    // ═══════════════════════════════════════════════════
    // Tarjetas de crédito
    // ═══════════════════════════════════════════════════

    'cutoff_date': FinancialTerm(
      key: 'cutoff_date',
      title: 'Fecha de corte',
      whatIs: 'El día del mes en que tu banco suma todo lo que gastaste con la '
          'tarjeta y genera tu estado de cuenta.',
      whyItMatters:
          'Lo que gastes después del corte ya cuenta para el siguiente '
          'mes — tienes más tiempo para pagarlo sin intereses.',
      bettyTip:
          'Si sabes tu fecha de corte, puedes planear las compras grandes '
          'para justo después. No es trampa, es darte oxígeno.',
      category: FinancialTermCategory.creditCards,
    ),

    'payment_due_date': FinancialTerm(
      key: 'payment_due_date',
      title: 'Fecha límite de pago',
      whatIs: 'El último día para pagar tu tarjeta antes de que el banco te '
          'cobre intereses sobre la deuda.',
      whyItMatters:
          'Pagar un día después puede costarte cientos o miles de pesos '
          'en intereses, aunque solo debas poquito.',
      bettyTip: 'Muchas personas programan un recordatorio tres días antes. '
          'Beti puede hacerlo por ti si activas las alertas de la tarjeta.',
      category: FinancialTermCategory.creditCards,
    ),

    'minimum_payment': FinancialTerm(
      key: 'minimum_payment',
      title: 'Pago mínimo',
      whatIs: 'La cantidad más pequeña que el banco te permite pagar para no '
          'reportarte como moroso ese mes.',
      whyItMatters: 'Pagar solo el mínimo te mantiene al corriente pero genera '
          'intereses sobre todo lo que quedó pendiente. La deuda crece.',
      bettyTip: 'Siempre que puedas, paga "el monto para no generar intereses" '
          '— suele aparecer en tu estado de cuenta justo abajo del mínimo.',
      category: FinancialTermCategory.creditCards,
    ),

    'no_interest_payment': FinancialTerm(
      key: 'no_interest_payment',
      title: 'Pago para no generar intereses',
      whatIs: 'El monto total que debes pagar antes de la fecha límite para '
          'que el banco no te cobre ni un peso de intereses ese mes.',
      whyItMatters:
          'Si pagas esta cantidad completa cada mes, usar la tarjeta te '
          'sale gratis. Si pagas menos, pagas intereses sobre la diferencia.',
      bettyTip: 'Esta es la regla de oro de las tarjetas: úsala como medio de '
          'pago, no como préstamo. Si no puedes pagarla completa, '
          'probablemente la compra no era para este mes.',
      category: FinancialTermCategory.creditCards,
    ),

    'cat_rate': FinancialTerm(
      key: 'cat_rate',
      title: 'CAT (Costo Anual Total)',
      whatIs: 'El porcentaje que mide cuánto te cuesta de verdad una tarjeta '
          'o crédito al año, incluyendo intereses y comisiones.',
      whyItMatters:
          'Una tarjeta con CAT de 80% es mucho más cara que una de 40%, '
          'aunque ambas te digan "tasa de interés baja". El CAT no miente.',
      bettyTip:
          'Cuando compares tarjetas o créditos, mira el CAT — no la tasa. '
          'Es el número que te dice el costo real.',
      category: FinancialTermCategory.creditCards,
    ),

    'installments_no_interest': FinancialTerm(
      key: 'installments_no_interest',
      title: 'Meses sin intereses (MSI)',
      whatIs: 'Una promoción para dividir una compra en mensualidades iguales '
          'sin que el banco te cobre intereses adicionales.',
      whyItMatters:
          'Pueden ser útiles para compras grandes planeadas, pero suman '
          'deuda fija a tu presupuesto por muchos meses. Si pierdes un '
          'pago, los intereses aplican retroactivamente.',
      bettyTip: 'Antes de aceptar MSI, pregúntate: ¿podría pagarlo al contado '
          'hoy? Si la respuesta es no, probablemente no es el momento.',
      category: FinancialTermCategory.creditCards,
    ),

    'available_credit': FinancialTerm(
      key: 'available_credit',
      title: 'Crédito disponible',
      whatIs: 'Lo que te falta por gastar antes de topar el límite de tu '
          'tarjeta. No es dinero tuyo — es dinero que el banco te presta.',
      whyItMatters:
          'Muchas personas confunden el crédito disponible con ahorro. '
          'Cada peso que uses de ahí, lo tienes que devolver con o sin '
          'intereses.',
      bettyTip: 'Una buena señal de salud financiera es usar menos del 30% de '
          'tu línea de crédito. Te da margen para emergencias reales.',
      category: FinancialTermCategory.creditCards,
    ),

    'annual_fee': FinancialTerm(
      key: 'annual_fee',
      title: 'Anualidad',
      whatIs: 'Una comisión que algunos bancos cobran una vez al año por '
          'tener la tarjeta, independientemente de si la usaste o no.',
      whyItMatters:
          'Puede ir desde \$500 hasta varios miles al año. Si la tarjeta '
          'no te da beneficios que superen ese costo, estás perdiendo.',
      bettyTip:
          'La anualidad casi siempre se puede negociar o condonar — llama '
          'a tu banco un mes antes del cobro y pide que te la quiten. '
          'Muchas veces funciona.',
      category: FinancialTermCategory.creditCards,
    ),

    'healthy_utilization': FinancialTerm(
      key: 'healthy_utilization',
      title: 'Uso saludable del crédito',
      whatIs: 'La regla del 30%: procura no deber más del 30% del límite '
          'total de tu tarjeta. Si tu límite es \$10,000, intenta que '
          'tu saldo no pase de \$3,000.',
      whyItMatters:
          'Usar más del 30% de tu línea afecta tu historial crediticio '
          'y te deja poco margen para emergencias. Además, entre más '
          'debes, más intereses pagas si no liquidas a tiempo.',
      bettyTip: 'Si ya rebasaste el 30%, no entres en pánico — enfócate en '
          'pagar más del mínimo este mes. Cada peso que bajes cuenta. '
          'Beti te avisará cuando vuelvas a la zona verde.',
      category: FinancialTermCategory.creditCards,
    ),

    // ═══════════════════════════════════════════════════
    // Presupuestos y gastos
    // ═══════════════════════════════════════════════════

    'fixed_vs_variable_expense': FinancialTerm(
      key: 'fixed_vs_variable_expense',
      title: 'Gasto fijo vs variable',
      whatIs: 'Fijo es lo que pagas cada mes con el mismo monto (renta, '
          'internet). Variable es lo que cambia según tu estilo de vida '
          '(comida fuera, ropa).',
      whyItMatters:
          'Los gastos fijos no los puedes reducir fácil a corto plazo. '
          'Los variables sí — son donde está tu margen real para ahorrar.',
      bettyTip:
          'Si quieres recortar gastos este mes, empieza por los variables. '
          'Los fijos requieren decisiones más grandes (mudanza, cambiar '
          'plan) que no siempre son rápidas.',
      category: FinancialTermCategory.budgeting,
    ),

    'expense_category': FinancialTerm(
      key: 'expense_category',
      title: 'Categoría de gasto',
      whatIs: 'Una etiqueta que agrupa gastos similares (comida, transporte, '
          'salud) para que puedas ver cuánto destinas a cada área de tu vida.',
      whyItMatters:
          'Sin categorías, solo sabes "gasté mucho". Con categorías, sabes '
          '"gasté mucho en comida fuera" — y ahí sí puedes hacer algo.',
      bettyTip:
          'No necesitas ser perfecto clasificando. Aunque falles en algunas, '
          'al final del mes tendrás una foto bastante clara de a dónde '
          'se va tu dinero.',
      category: FinancialTermCategory.budgeting,
    ),

    'ant_expense': FinancialTerm(
      key: 'ant_expense',
      title: 'Gasto hormiga',
      whatIs: 'Esos gastos pequeños y frecuentes que individualmente parecen '
          'insignificantes (cafés, snacks, app stores) pero suman mucho '
          'al mes.',
      whyItMatters:
          'Un café de \$60 diario son \$1,800 al mes. Cinco "gastitos" así '
          'a la semana son más que una renta en muchos lados.',
      bettyTip: 'No se trata de eliminarlos — se trata de verlos. Cuando sabes '
          'a cuánto llegan al mes, tú decides si siguen valiendo la pena.',
      category: FinancialTermCategory.budgeting,
    ),

    'prorated_annual_expense': FinancialTerm(
      key: 'prorated_annual_expense',
      title: 'Prorrateo de gastos grandes',
      whatIs: 'Dividir un gasto que pagas una vez al año (o cada tantos meses) '
          'entre los meses que tardan en llegar, para reservar poquito '
          'cada mes.',
      whyItMatters: 'Así no te cae de sorpresa el predial, la tenencia o la '
          'reinscripción escolar. Ya lo tenías guardadito.',
      bettyTip:
          'Ejemplo: si el predial son \$3,000 al año, reserva \$250 al mes. '
          'Cuando llegue enero, el dinero ya está ahí — sin estrés.',
      category: FinancialTermCategory.budgeting,
    ),

    'inflation': FinancialTerm(
      key: 'inflation',
      title: 'Inflación',
      whatIs: 'La subida generalizada de precios que hace que el mismo billete '
          'de \$100 compre menos cosas con el paso del tiempo.',
      whyItMatters:
          'Lo que hoy te cuesta \$100, el próximo año puede costar \$104 o '
          'más. Si tu dinero no crece al menos al ritmo de la inflación, '
          'pierde valor guardadito.',
      bettyTip: 'Beti ajusta tus metas de ahorro considerando una inflación '
          'anual del 4.5% (referencia Banxico). Puedes cambiar este '
          'valor en la configuración.',
      category: FinancialTermCategory.general,
    ),

    // ═══════════════════════════════════════════════════
    // Ahorro e ingresos
    // ═══════════════════════════════════════════════════

    'fixed_vs_variable_income': FinancialTerm(
      key: 'fixed_vs_variable_income',
      title: 'Ingreso fijo vs variable',
      whatIs: 'Fijo es el dinero que te llega cada mes con certeza (nómina '
          'quincenal). Variable es el que depende de tu trabajo '
          'adicional (freelance, comisiones, bonos).',
      whyItMatters:
          'Para planear tus gastos del mes, usa solo tu ingreso fijo. '
          'Lo variable es bienvenido, pero no puedes depender de él '
          'para pagar la renta.',
      bettyTip: 'Una buena estrategia: destina el ingreso variable a metas de '
          'ahorro o gustos extra. Así si un mes no llega, no afecta tus '
          'gastos esenciales.',
      category: FinancialTermCategory.savings,
    ),

    'emergency_fund': FinancialTerm(
      key: 'emergency_fund',
      title: 'Fondo de emergencia',
      whatIs:
          'Dinero ahorrado exclusivamente para imprevistos reales: quedarte '
          'sin trabajo, una reparación urgente, una emergencia de salud.',
      whyItMatters:
          'Sin este fondo, cualquier imprevisto te empuja a pedir prestado '
          'o a usar la tarjeta. Con él, son solo un mal rato — no una '
          'crisis de meses.',
      bettyTip: 'La meta clásica son 3 a 6 meses de tus gastos esenciales. '
          'Empieza con uno — ya es un cambio enorme. No se trata de '
          'llegar rápido, se trata de empezar.',
      category: FinancialTermCategory.savings,
    ),

    'goal_vs_budget': FinancialTerm(
      key: 'goal_vs_budget',
      title: 'Meta vs presupuesto',
      whatIs: 'Una meta es a dónde quieres llegar (un viaje, un auto, el '
          'fondo de emergencia). Un presupuesto es cuánto puedes gastar '
          'este mes en cada categoría.',
      whyItMatters:
          'El presupuesto te cuida el día a día; la meta le da rumbo a '
          'lo que te sobra. Sin uno, el otro no funciona.',
      bettyTip: 'Si respetas tu presupuesto y te sobra dinero, esa es la '
          'semilla de tus metas. Beti calcula cuánto necesitas ahorrar '
          'al mes para llegar a tiempo.',
      category: FinancialTermCategory.savings,
    ),

    // ═══════════════════════════════════════════════════
    // Créditos
    // ═══════════════════════════════════════════════════

    'principal_vs_interest': FinancialTerm(
      key: 'principal_vs_interest',
      title: 'Capital vs intereses',
      whatIs: 'El capital es la deuda real que pediste prestada. Los intereses '
          'son lo extra que pagas al banco por prestarte ese dinero.',
      whyItMatters:
          'Al inicio de un crédito, casi todo lo que pagas son intereses '
          '— no estás bajando la deuda tan rápido como crees. Con el '
          'tiempo eso se invierte.',
      bettyTip: 'Los pagos anticipados a capital reducen los intereses totales '
          'de todo el crédito. Es la forma más barata de terminar antes.',
      category: FinancialTermCategory.credits,
    ),

    'loan_term': FinancialTerm(
      key: 'loan_term',
      title: 'Plazo del crédito',
      whatIs: 'El número de meses o años que tardarás en terminar de pagar '
          'un crédito.',
      whyItMatters:
          'A más plazo, la mensualidad es menor pero pagas muchos más '
          'intereses totales. Un auto a 6 años puede costarte el precio '
          'de dos autos.',
      bettyTip: 'Antes de elegir el plazo más largo para bajar la mensualidad, '
          'pregúntate si puedes aguantar una cuota un poco más alta. '
          'Tu bolsillo del futuro te lo agradecerá.',
      category: FinancialTermCategory.credits,
    ),

    'fixed_vs_variable_rate': FinancialTerm(
      key: 'fixed_vs_variable_rate',
      title: 'Tasa fija vs variable',
      whatIs: 'Fija significa que tu tasa de interés no cambia durante todo '
          'el crédito. Variable significa que puede subir o bajar según '
          'el mercado.',
      whyItMatters: 'La variable suele empezar más barata, pero si las tasas '
          'suben, tu mensualidad también. La fija te da certeza para '
          'planear.',
      bettyTip: 'Para créditos largos (hipoteca, auto), muchas personas '
          'prefieren tasa fija aunque sea un poco más alta. La tranquilidad '
          'vale algo.',
      category: FinancialTermCategory.credits,
    ),
  };

  /// Retorna un término por su `key`. Null si no existe.
  static FinancialTerm? byKey(String key) => _terms[key];

  /// Retorna todos los términos como lista inmutable.
  static List<FinancialTerm> all() => _terms.values.toList(growable: false);

  /// Filtra términos por categoría.
  static List<FinancialTerm> byCategory(FinancialTermCategory category) {
    return _terms.values
        .where((t) => t.category == category)
        .toList(growable: false);
  }

  /// Indica si existe un término con ese `key`.
  static bool exists(String key) => _terms.containsKey(key);

  /// Total de términos en el catálogo.
  static int get count => _terms.length;
}
