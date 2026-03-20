import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/core/enums/category_type.dart';
import 'package:betty_app/core/enums/input_method.dart';
import 'package:betty_app/core/enums/transaction_type.dart';
import 'package:betty_app/core/providers/core_providers.dart';
import 'package:betty_app/core/utils/uuid_generator.dart';
import 'package:betty_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:betty_app/features/intelligence/data/datasources/categorization_engine.dart';
import 'package:betty_app/features/sync/presentation/providers/sync_provider.dart';
import 'package:betty_app/features/transactions/data/datasources/transaction_local_ds.dart';
import 'package:betty_app/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:betty_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:betty_app/features/transactions/domain/repositories/transaction_repository.dart';

// ── Dependency Injection ──

final transactionLocalDsProvider = Provider<TransactionLocalDataSource>((ref) {
  return TransactionLocalDataSource(ref.watch(isarProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(
    localDs: ref.watch(transactionLocalDsProvider),
    syncRepo: ref.watch(syncRepositoryProvider),
    authDs: ref.watch(authLocalDsProvider),
  );
});

// ── Transaction List State ──

/// Lista de transacciones recientes del usuario.
final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<TransactionEntity>>(
  TransactionsNotifier.new,
);

class TransactionsNotifier extends AsyncNotifier<List<TransactionEntity>> {
  @override
  Future<List<TransactionEntity>> build() async {
    return await ref.watch(transactionRepositoryProvider).getRecent();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(
      await ref.read(transactionRepositoryProvider).getRecent(),
    );
  }

  Future<void> save(TransactionEntity transaction) async {
    await ref.read(transactionRepositoryProvider).save(transaction);
    await refresh();
  }

  Future<void> delete(String uuid) async {
    await ref.read(transactionRepositoryProvider).delete(uuid);
    await refresh();
  }
}

// ── Search ──

final transactionSearchProvider =
    FutureProvider.family<List<TransactionEntity>, String>((ref, query) async {
  if (query.length < 2) return [];
  return await ref.watch(transactionRepositoryProvider).search(query);
});

// ── Transaction Form State (para crear/editar) ──

/// Estado del formulario de nueva transacción.
/// Mantiene el borrador mientras el usuario completa o corrige los datos.
class TransactionDraft {
  final String uuid;
  final TransactionType type;
  final double amount;
  final String description;
  final CategoryType category;
  final bool categoryAutoAssigned;
  final InputMethod inputMethod;
  final DateTime transactionDate;
  final String? rawInputText;
  final String? creditCardUuid;
  final String? notes;

  const TransactionDraft({
    this.uuid = '',
    this.type = TransactionType.expense,
    this.amount = 0,
    this.description = '',
    this.category = CategoryType.other,
    this.categoryAutoAssigned = false,
    this.inputMethod = InputMethod.manual,
    DateTime? transactionDate,
    this.rawInputText,
    this.creditCardUuid,
    this.notes,
  }) : transactionDate = transactionDate ?? const _DefaultNow();

  TransactionDraft copyWith({
    String? uuid,
    TransactionType? type,
    double? amount,
    String? description,
    CategoryType? category,
    bool? categoryAutoAssigned,
    InputMethod? inputMethod,
    DateTime? transactionDate,
    String? rawInputText,
    String? creditCardUuid,
    String? notes,
  }) {
    return TransactionDraft(
      uuid: uuid ?? this.uuid,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      categoryAutoAssigned: categoryAutoAssigned ?? this.categoryAutoAssigned,
      inputMethod: inputMethod ?? this.inputMethod,
      transactionDate: transactionDate ?? this.transactionDate,
      rawInputText: rawInputText ?? this.rawInputText,
      creditCardUuid: creditCardUuid ?? this.creditCardUuid,
      notes: notes ?? this.notes,
    );
  }
}

// Helper para default DateTime en const constructor
class _DefaultNow implements DateTime {
  const _DefaultNow();

  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.now().noSuchMethod(invocation);
}

/// Notifier para el formulario de transacción.
/// Incluye la lógica de auto-categorización.
class TransactionFormNotifier extends StateNotifier<TransactionDraft> {
  TransactionFormNotifier() : super(TransactionDraft(transactionDate: DateTime.now()));

  /// Resetea el formulario a valores por defecto.
  void reset() {
    state = TransactionDraft(transactionDate: DateTime.now());
  }

  /// Carga una transacción existente para editar.
  void loadForEdit(TransactionEntity entity) {
    state = TransactionDraft(
      uuid: entity.uuid,
      type: entity.type,
      amount: entity.amount,
      description: entity.description,
      category: entity.category,
      categoryAutoAssigned: entity.categoryAutoAssigned,
      inputMethod: entity.inputMethod,
      transactionDate: entity.transactionDate,
      rawInputText: entity.rawInputText,
      creditCardUuid: entity.creditCardUuid,
      notes: entity.notes,
    );
  }

  void updateType(TransactionType type) => state = state.copyWith(type: type);
  void updateAmount(double amount) => state = state.copyWith(amount: amount);
  void updateDate(DateTime date) => state = state.copyWith(transactionDate: date);
  void updateNotes(String notes) => state = state.copyWith(notes: notes);
  void updateCreditCard(String? uuid) => state = state.copyWith(creditCardUuid: uuid);

  /// Actualiza la descripción Y auto-categoriza.
  void updateDescription(String description) {
    final predicted = CategorizationEngine.predict(description);
    final inferredType = CategorizationEngine.inferType(predicted);

    state = state.copyWith(
      description: description,
      category: predicted,
      categoryAutoAssigned: predicted != CategoryType.other,
      type: predicted != CategoryType.other ? inferredType : state.type,
    );
  }

  /// El usuario elige manualmente una categoría (sobreescribe auto).
  void updateCategory(CategoryType category) {
    state = state.copyWith(
      category: category,
      categoryAutoAssigned: false,
    );
  }

  /// Convierte el draft a entity para guardar.
  TransactionEntity toEntity(String userId) {
    final now = DateTime.now();
    return TransactionEntity(
      uuid: state.uuid.isEmpty ? UuidGenerator.generate() : state.uuid,
      userId: userId,
      type: state.type,
      amount: state.amount,
      description: state.description,
      category: state.category,
      categoryAutoAssigned: state.categoryAutoAssigned,
      inputMethod: state.inputMethod,
      transactionDate: state.transactionDate,
      createdAt: now,
      updatedAt: now,
      rawInputText: state.rawInputText,
      creditCardUuid: state.creditCardUuid,
      notes: state.notes,
    );
  }
}

final transactionFormProvider =
    StateNotifierProvider<TransactionFormNotifier, TransactionDraft>((ref) {
  return TransactionFormNotifier();
});
