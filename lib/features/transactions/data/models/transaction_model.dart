import 'package:isar/isar.dart';

part 'transaction_model.g.dart';

/// Colección principal de transacciones financieras.
///
/// Diseño Offline-First:
/// - [uuid] es el identificador lógico (UUID v4 generado localmente).
/// - [syncStatus] controla si el registro ya se respaldó en Supabase.
/// - Toda lectura/escritura de la app opera sobre esta colección en Isar.
@collection
class TransactionModel {
  Id id = Isar.autoIncrement;

  /// UUID v4 generado localmente. Clave primaria lógica offline-safe.
  @Index(unique: true)
  late String uuid;

  /// ID del usuario propietario (referencia a UserModel.supabaseId).
  @Index()
  late String userId;

  @Enumerated(EnumType.name)
  late TxType type;

  /// Monto en la moneda del usuario (siempre positivo).
  late double amount;

  /// Descripción o concepto (ej: "Uber al trabajo").
  @Index(type: IndexType.hash)
  late String description;

  @Enumerated(EnumType.name)
  late TxCategory category;

  /// true = auto-categorizada por motor ML, false = elegida por usuario.
  /// Las manuales alimentan el dataset de entrenamiento del TFLite.
  late bool categoryAutoAssigned;

  @Enumerated(EnumType.name)
  late TxInputMethod inputMethod;

  /// Fecha de la transacción (la que indica el usuario o la del ticket).
  @Index()
  late DateTime transactionDate;

  late DateTime createdAt;

  late DateTime updatedAt;

  /// Ruta local de la imagen del ticket (capturado por OCR).
  String? ticketImagePath;

  /// Texto crudo extraído por OCR o STT antes de procesamiento.
  String? rawInputText;

  /// UUID de la tarjeta de crédito asociada (si aplica).
  String? creditCardUuid;

  String? notes;

  // ── Control de Sincronización ──

  @Enumerated(EnumType.name)
  TxPaymentMethod? paymentMethod;

  @Enumerated(EnumType.name)
  late TxSyncStatus syncStatus;

  DateTime? lastSyncedAt;

  /// Borrado lógico: se marca como deleted, la sync propaga, luego se purga.
  late bool isDeleted;
}

// ── Enums locales (requerido por isar_generator) ──
// La referencia canónica para el resto de la app está en core/enums/

enum TxType {
  income,
  expense,
}

enum TxInputMethod {
  manual,
  voice,
  ocr,
  bankSync,
}

enum TxPaymentMethod {
  cash,
  debitCard,
  creditCard,
  transfer,
  other,
}

enum TxCategory {
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
  salary,
  freelance,
  investment,
  refund,
  otherIncome,
  other,
}

enum TxSyncStatus {
  pending,
  synced,
  conflict,
}
