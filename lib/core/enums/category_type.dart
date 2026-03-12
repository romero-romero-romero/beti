/// Categorías maestras de gasto/ingreso.
/// El MVP arranca con estas; el modelo TFLite las predice.
enum CategoryType {
  // ── Gastos ──
  food,
  transport,
  housing,
  utilities,
  health,
  education,
  entertainment,
  clothing,
  subscriptions,
  debtPayment,
  groceries,
  personalCare,
  gifts,
  pets,

  // ── Ingresos ──
  salary,
  freelance,
  investment,
  refund,
  otherIncome,

  // ── Comodín ──
  other,
}
