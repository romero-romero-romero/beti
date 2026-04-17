import 'package:isar/isar.dart';
import 'package:beti_app/features/transactions/data/models/transaction_model.dart';

/// DataSource local para transacciones.
/// CRUD directo sobre Isar — fuente de verdad.
class TransactionLocalDataSource {
  final Isar _isar;

  TransactionLocalDataSource(this._isar);

  /// Guarda una transacción (create o update).
  Future<void> save(TransactionModel transaction) async {
    await _isar.writeTxn(() async {
      // Si ya existe con ese uuid, actualizar
      final existing = await _isar.transactionModels
          .filter()
          .uuidEqualTo(transaction.uuid)
          .findFirst();

      if (existing != null) {
        transaction.id = existing.id;
      }

      await _isar.transactionModels.put(transaction);
    });
  }

  /// Obtiene una transacción por UUID.
  Future<TransactionModel?> getByUuid(String uuid) async {
    return await _isar.transactionModels
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
  }

  /// Obtiene todas las transacciones de un usuario (no eliminadas).
  Future<List<TransactionModel>> getAllByUser(String userId) async {
    return await _isar.transactionModels
        .filter()
        .userIdEqualTo(userId)
        .isDeletedEqualTo(false)
        .sortByTransactionDateDesc()
        .findAll();
  }

  /// Obtiene transacciones de un período (mes).
  Future<List<TransactionModel>> getByPeriod({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    return await _isar.transactionModels
        .filter()
        .userIdEqualTo(userId)
        .isDeletedEqualTo(false)
        .transactionDateBetween(from, to)
        .sortByTransactionDateDesc()
        .findAll();
  }

  /// Marca una transacción como eliminada (soft delete).
  Future<void> softDelete(String uuid) async {
    await _isar.writeTxn(() async {
      final item = await _isar.transactionModels
          .filter()
          .uuidEqualTo(uuid)
          .findFirst();

      if (item != null) {
        item.isDeleted = true;
        item.syncStatus = TxSyncStatus.pending;
        item.updatedAt = DateTime.now();
        await _isar.transactionModels.put(item);
      }
    });
  }

  /// Busca transacciones por descripción (para autocompletado).
  Future<List<TransactionModel>> search({
    required String userId,
    required String query,
    int limit = 10,
  }) async {
    return await _isar.transactionModels
        .filter()
        .userIdEqualTo(userId)
        .isDeletedEqualTo(false)
        .descriptionContains(query, caseSensitive: false)
        .sortByTransactionDateDesc()
        .limit(limit)
        .findAll();
  }

  /// Obtiene las últimas N transacciones (para el dashboard).
  Future<List<TransactionModel>> getRecent({
    required String userId,
    int limit = 20,
  }) async {
    return await _isar.transactionModels
        .filter()
        .userIdEqualTo(userId)
        .isDeletedEqualTo(false)
        .sortByTransactionDateDesc()
        .limit(limit)
        .findAll();
  }
}
