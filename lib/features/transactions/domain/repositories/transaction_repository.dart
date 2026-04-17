import 'package:beti_app/features/transactions/domain/entities/transaction_entity.dart';

/// Contrato del repositorio de transacciones.
abstract class TransactionRepository {
  /// Crea o actualiza una transacción en Isar + encola sync.
  Future<void> save(TransactionEntity transaction);

  /// Obtiene una transacción por UUID.
  Future<TransactionEntity?> getByUuid(String uuid);

  /// Obtiene todas las transacciones del usuario actual.
  Future<List<TransactionEntity>> getAll();

  /// Obtiene transacciones de un período (mes).
  Future<List<TransactionEntity>> getByPeriod({
    required DateTime from,
    required DateTime to,
  });

  /// Elimina una transacción (soft delete + encola sync).
  Future<void> delete(String uuid);

  /// Busca transacciones por texto.
  Future<List<TransactionEntity>> search(String query);

  /// Obtiene las últimas N transacciones.
  Future<List<TransactionEntity>> getRecent({int limit = 20});
}
