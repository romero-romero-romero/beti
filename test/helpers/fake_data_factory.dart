// test/helpers/fake_data_factory.dart
//
// ════════════════════════════════════════════════════════════════════════
// Builders de modelos Isar para tests.
// ════════════════════════════════════════════════════════════════════════
//
// FILOSOFÍA:
//   Todos los métodos retornan modelos con defaults razonables y permiten
//   override granular vía parámetros nombrados opcionales. Evita que cada
//   test tenga que rellenar 15+ campos para construir una transacción.
//
//   PRINCIPIO: si un test dice `factory.transaction(amount: 500)`, eso
//   debe leerse como "dame una transacción cualquiera con monto 500" sin
//   pensar en userId, category, fecha, syncStatus, etc.
//
// ARQUITECTURA DE ENUMS (importante):
//   Cada modelo Isar tiene su propio `*SyncStatus` local con prefijo
//   (TxSyncStatus, CcSyncStatus, etc.) — esto es requisito de
//   isar_generator. La factory expone esos tipos directamente; el caller
//   no debe mezclar con el `SyncStatus` canónico de core/enums.
//
// ════════════════════════════════════════════════════════════════════════

import 'package:beti_app/features/auth/data/models/user_model.dart';
import 'package:beti_app/features/budgets_goals/data/models/budget_model.dart';
import 'package:beti_app/features/budgets_goals/data/models/goal_model.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_model.dart';
import 'package:beti_app/features/sync/data/models/sync_queue_model.dart';
import 'package:beti_app/features/transactions/data/models/category_model.dart';
import 'package:beti_app/features/transactions/data/models/transaction_model.dart';

class FakeDataFactory {
  static const String defaultUserId = 'test-user-uuid-0001';

  static int _uuidCounter = 0;
  static String _nextUuid([String prefix = 'uuid']) {
    _uuidCounter++;
    return '$prefix-$_uuidCounter-${DateTime.now().microsecondsSinceEpoch}';
  }

  /// Resetea el contador de UUIDs. Llamar en `setUp()` si tu suite depende
  /// de UUIDs reproducibles. La mayoría de tests no lo necesita.
  static void resetCounters() => _uuidCounter = 0;

  // ══════════════════════════════════════════════════════════════════════
  // TransactionModel
  // ══════════════════════════════════════════════════════════════════════

  static TransactionModel transaction({
    String? uuid,
    String? userId,
    TxType type = TxType.expense,
    double amount = 100.0,
    String description = 'Compra de prueba',
    TxCategory category = TxCategory.food,
    bool categoryAutoAssigned = false,
    TxInputMethod inputMethod = TxInputMethod.manual,
    DateTime? transactionDate,
    String? ticketImagePath,
    String? rawInputText,
    String? creditCardUuid,
    String? notes,
    TxPaymentMethod? paymentMethod,
    TxSyncStatus syncStatus = TxSyncStatus.pending,
    DateTime? lastSyncedAt,
    bool isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return TransactionModel()
      ..uuid = uuid ?? _nextUuid('txn')
      ..userId = userId ?? defaultUserId
      ..type = type
      ..amount = amount
      ..description = description
      ..category = category
      ..categoryAutoAssigned = categoryAutoAssigned
      ..inputMethod = inputMethod
      ..transactionDate = transactionDate ?? now
      ..ticketImagePath = ticketImagePath
      ..rawInputText = rawInputText
      ..creditCardUuid = creditCardUuid
      ..notes = notes
      ..paymentMethod = paymentMethod
      ..syncStatus = syncStatus
      ..lastSyncedAt = lastSyncedAt
      ..isDeleted = isDeleted
      ..createdAt = createdAt ?? now
      ..updatedAt = updatedAt ?? now;
  }

  // ══════════════════════════════════════════════════════════════════════
  // CategoryModel
  // ══════════════════════════════════════════════════════════════════════

  static CategoryModel category({
    String? uuid,
    String? userId,
    String name = 'Comida',
    String parentCategoryKey = 'food',
    String? icon,
    List<String>? keywords,
    bool isSystem = false,
    bool isIncome = false,
    int sortOrder = 0,
    CatSyncStatus syncStatus = CatSyncStatus.pending,
  }) {
    final now = DateTime.now();
    return CategoryModel()
      ..uuid = uuid ?? _nextUuid('cat')
      ..userId = userId ?? defaultUserId
      ..name = name
      ..parentCategoryKey = parentCategoryKey
      ..icon = icon ?? '🍔'
      ..keywords = keywords ?? const ['comida', 'restaurante']
      ..isSystem = isSystem
      ..isIncome = isIncome
      ..sortOrder = sortOrder
      ..syncStatus = syncStatus
      ..createdAt = now
      ..updatedAt = now;
  }

  // ══════════════════════════════════════════════════════════════════════
  // SyncQueueModel
  // ══════════════════════════════════════════════════════════════════════

  static SyncQueueModel syncQueueItem({
    String? uuid,
    String? userId,
    String targetCollection = 'transactions',
    String? targetUuid,
    SyncOperation operation = SyncOperation.create,
    String payload = '{}',
    String? attachmentPath,
    DateTime? enqueuedAt,
    int retryCount = 0,
    String? lastError,
    DateTime? lastAttemptAt,
    int? priority,
  }) {
    return SyncQueueModel()
      ..uuid = uuid ?? _nextUuid('queue')
      ..userId = userId ?? defaultUserId
      ..targetCollection = targetCollection
      ..targetUuid = targetUuid ?? _nextUuid('target')
      ..operation = operation
      ..payload = payload
      ..attachmentPath = attachmentPath
      ..enqueuedAt = enqueuedAt ?? DateTime.now()
      ..retryCount = retryCount
      ..lastError = lastError
      ..lastAttemptAt = lastAttemptAt
      ..priority = priority ?? _priorityFor(operation);
  }

  /// Mapeo de prioridad espejo del que usa SyncLocalDataSource.
  /// Deletes primero (0), creates (1), updates (2).
  static int _priorityFor(SyncOperation op) => switch (op) {
        SyncOperation.delete => 0,
        SyncOperation.create => 1,
        SyncOperation.update => 2,
      };

  // ══════════════════════════════════════════════════════════════════════
  // UserModel
  // ══════════════════════════════════════════════════════════════════════

  static UserModel user({
    String? supabaseId,
    String email = '[email protected]',
    String? displayName,
    String? avatarUrl,
    String? cachedAccessToken,
    String? cachedRefreshToken,
    DateTime? lastAuthAt,
    UserCurrency currency = UserCurrency.mxn,
    bool onboardingCompleted = true,
    UserSyncStatus syncStatus = UserSyncStatus.synced,
    DateTime? createdAt,
  }) {
    final now = DateTime.now();
    return UserModel()
      ..supabaseId = supabaseId ?? defaultUserId
      ..email = email
      ..displayName = displayName ?? 'Usuario de Prueba'
      ..avatarUrl = avatarUrl
      ..cachedAccessToken = cachedAccessToken
      ..cachedRefreshToken = cachedRefreshToken
      ..lastAuthAt = lastAuthAt
      ..currency = currency
      ..onboardingCompleted = onboardingCompleted
      ..syncStatus = syncStatus
      ..createdAt = createdAt ?? now
      ..updatedAt = now;
  }

  // ══════════════════════════════════════════════════════════════════════
  // CreditCardModel
  // ══════════════════════════════════════════════════════════════════════

  static CreditCardModel creditCard({
    String? uuid,
    String? userId,
    String name = 'BBVA Azul',
    String? lastFourDigits,
    CcNetwork network = CcNetwork.visa,
    double creditLimit = 30000.0,
    double currentBalance = 5000.0,
    double? availableCredit,
    double? annualRate,
    int cutOffDay = 15,
    int paymentDueDay = 5,
    DateTime? nextCutOffDate,
    DateTime? nextPaymentDueDate,
    bool alertsEnabled = true,
    bool isActive = true,
    CcSyncStatus syncStatus = CcSyncStatus.pending,
  }) {
    final now = DateTime.now();
    return CreditCardModel()
      ..uuid = uuid ?? _nextUuid('card')
      ..userId = userId ?? defaultUserId
      ..name = name
      ..lastFourDigits = lastFourDigits ?? '1234'
      ..network = network
      ..creditLimit = creditLimit
      ..currentBalance = currentBalance
      ..availableCredit = availableCredit ?? (creditLimit - currentBalance)
      ..annualRate = annualRate ?? 0.45
      ..cutOffDay = cutOffDay
      ..paymentDueDay = paymentDueDay
      ..nextCutOffDate = nextCutOffDate
      ..nextPaymentDueDate = nextPaymentDueDate
      ..alertsEnabled = alertsEnabled
      ..isActive = isActive
      ..syncStatus = syncStatus
      ..createdAt = now
      ..updatedAt = now;
  }

  // ══════════════════════════════════════════════════════════════════════
  // CreditModel
  // ══════════════════════════════════════════════════════════════════════

  static CreditModel credit({
    String? uuid,
    String? userId,
    String name = 'Préstamo personal',
    String? institution,
    double originalAmount = 50000.0,
    double currentBalance = 30000.0,
    double? interestRate,
    double monthlyPayment = 2500.0,
    int paymentDay = 10,
    DateTime? nextPaymentDate,
    DateTime? startDate,
    DateTime? endDate,
    int? totalInstallments,
    int? paidInstallments,
    bool alertsEnabled = true,
    bool isActive = true,
    CreditSyncStatus syncStatus = CreditSyncStatus.pending,
  }) {
    final now = DateTime.now();
    return CreditModel()
      ..uuid = uuid ?? _nextUuid('credit')
      ..userId = userId ?? defaultUserId
      ..name = name
      ..institution = institution
      ..originalAmount = originalAmount
      ..currentBalance = currentBalance
      ..interestRate = interestRate ?? 0.18
      ..monthlyPayment = monthlyPayment
      ..paymentDay = paymentDay
      ..nextPaymentDate = nextPaymentDate
      ..startDate = startDate
      ..endDate = endDate
      ..totalInstallments = totalInstallments
      ..paidInstallments = paidInstallments
      ..alertsEnabled = alertsEnabled
      ..isActive = isActive
      ..syncStatus = syncStatus
      ..createdAt = now
      ..updatedAt = now;
  }

  // ══════════════════════════════════════════════════════════════════════
  // BudgetModel
  // ══════════════════════════════════════════════════════════════════════

  static BudgetModel budget({
    String? uuid,
    String? userId,
    String categoryKey = 'food',
    double budgetedAmount = 5000.0,
    double spentAmount = 0.0,
    String? period,
    bool isSuggested = false,
    double? consumptionRatio,
    BudgetSyncStatus syncStatus = BudgetSyncStatus.pending,
  }) {
    final now = DateTime.now();
    final p = period ??
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    final ratio = consumptionRatio ??
        (budgetedAmount > 0 ? spentAmount / budgetedAmount : 0.0);
    return BudgetModel()
      ..uuid = uuid ?? _nextUuid('budget')
      ..userId = userId ?? defaultUserId
      ..categoryKey = categoryKey
      ..budgetedAmount = budgetedAmount
      ..spentAmount = spentAmount
      ..period = p
      ..isSuggested = isSuggested
      ..consumptionRatio = ratio
      ..syncStatus = syncStatus
      ..createdAt = now
      ..updatedAt = now;
  }

  // ══════════════════════════════════════════════════════════════════════
  // GoalModel
  // ══════════════════════════════════════════════════════════════════════

  static GoalModel goal({
    String? uuid,
    String? userId,
    String name = 'Vacaciones',
    double targetAmount = 20000.0,
    double savedAmount = 5000.0,
    DateTime? deadline,
    String? icon,
    double? progress,
    bool isCompleted = false,
    bool isActive = true,
    GoalSyncStatus syncStatus = GoalSyncStatus.pending,
  }) {
    final now = DateTime.now();
    return GoalModel()
      ..uuid = uuid ?? _nextUuid('goal')
      ..userId = userId ?? defaultUserId
      ..name = name
      ..targetAmount = targetAmount
      ..savedAmount = savedAmount
      ..deadline = deadline
      ..icon = icon
      ..progress = progress ??
          (targetAmount > 0 ? savedAmount / targetAmount : 0.0)
      ..isCompleted = isCompleted
      ..isActive = isActive
      ..syncStatus = syncStatus
      ..createdAt = now
      ..updatedAt = now;
  }
}