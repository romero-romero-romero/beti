import 'dart:convert';
import 'package:betty_app/core/enums/sync_status.dart';
import 'package:betty_app/core/mappers/enum_mapper.dart';
import 'package:betty_app/core/utils/uuid_generator.dart';
import 'package:betty_app/features/auth/data/datasources/auth_local_ds.dart';
import 'package:betty_app/features/sync/data/models/sync_queue_model.dart';
import 'package:betty_app/features/sync/domain/repositories/sync_repository.dart';
import 'package:betty_app/features/transactions/data/datasources/transaction_local_ds.dart';
import 'package:betty_app/features/transactions/data/models/transaction_model.dart';
import 'package:betty_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:betty_app/features/transactions/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionLocalDataSource _localDs;
  final SyncRepository _syncRepo;
  final AuthLocalDataSource _authDs;

  TransactionRepositoryImpl({
    required TransactionLocalDataSource localDs,
    required SyncRepository syncRepo,
    required AuthLocalDataSource authDs,
  })  : _localDs = localDs,
        _syncRepo = syncRepo,
        _authDs = authDs;

  Future<String> get _userId async {
    final user = await _authDs.getCachedSession();
    return user?.supabaseId ?? '';
  }

  @override
  Future<void> save(TransactionEntity entity) async {
    final uid = await _userId;
    final isNew = (await _localDs.getByUuid(entity.uuid)) == null;
    final now = DateTime.now();

    final model = _entityToModel(entity, uid, now, isNew);
    await _localDs.save(model);

    await _syncRepo.enqueueChange(
      userId: uid,
      targetCollection: 'transactions',
      targetUuid: entity.uuid,
      operation: isNew ? SyncOperation.create : SyncOperation.update,
      payload: _modelToJson(model),
      attachmentPath: entity.ticketImagePath,
    );
  }

  @override
  Future<TransactionEntity?> getByUuid(String uuid) async {
    final model = await _localDs.getByUuid(uuid);
    return model != null ? _modelToEntity(model) : null;
  }

  @override
  Future<List<TransactionEntity>> getAll() async {
    final uid = await _userId;
    final models = await _localDs.getAllByUser(uid);
    return models.map(_modelToEntity).toList();
  }

  @override
  Future<List<TransactionEntity>> getByPeriod({
    required DateTime from,
    required DateTime to,
  }) async {
    final uid = await _userId;
    final models = await _localDs.getByPeriod(userId: uid, from: from, to: to);
    return models.map(_modelToEntity).toList();
  }

  @override
  Future<void> delete(String uuid) async {
    final uid = await _userId;
    await _localDs.softDelete(uuid);

    await _syncRepo.enqueueChange(
      userId: uid,
      targetCollection: 'transactions',
      targetUuid: uuid,
      operation: SyncOperation.delete,
      payload: jsonEncode({'uuid': uuid}),
    );
  }

  @override
  Future<List<TransactionEntity>> search(String query) async {
    final uid = await _userId;
    final models = await _localDs.search(userId: uid, query: query);
    return models.map(_modelToEntity).toList();
  }

  @override
  Future<List<TransactionEntity>> getRecent({int limit = 20}) async {
    final uid = await _userId;
    final models = await _localDs.getRecent(userId: uid, limit: limit);
    return models.map(_modelToEntity).toList();
  }

  // ── Mappers (usan enum_mapper centralizado) ──

  TransactionModel _entityToModel(
    TransactionEntity e,
    String userId,
    DateTime now,
    bool isNew,
  ) {
    return TransactionModel()
      ..uuid = e.uuid.isEmpty ? UuidGenerator.generate() : e.uuid
      ..userId = userId
      ..type = e.type.toIsar()
      ..amount = e.amount
      ..description = e.description
      ..category = e.category.toIsar()
      ..categoryAutoAssigned = e.categoryAutoAssigned
      ..inputMethod = e.inputMethod.toIsar()
      ..transactionDate = e.transactionDate
      ..createdAt = isNew ? now : e.createdAt
      ..updatedAt = now
      ..ticketImagePath = e.ticketImagePath
      ..rawInputText = e.rawInputText
      ..creditCardUuid = e.creditCardUuid
      ..notes = e.notes
      ..paymentMethod = e.paymentMethod?.toIsar()
      ..syncStatus = SyncStatus.pending.toTxIsar()
      ..isDeleted = e.isDeleted;
  }

  TransactionEntity _modelToEntity(TransactionModel m) {
    return TransactionEntity(
      uuid: m.uuid,
      userId: m.userId,
      type: m.type.toCanonical(),
      amount: m.amount,
      description: m.description,
      category: m.category.toCanonical(),
      categoryAutoAssigned: m.categoryAutoAssigned,
      inputMethod: m.inputMethod.toCanonical(),
      transactionDate: m.transactionDate,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
      ticketImagePath: m.ticketImagePath,
      rawInputText: m.rawInputText,
      creditCardUuid: m.creditCardUuid,
      notes: m.notes,
      paymentMethod: m.paymentMethod?.toCanonical(),
      isDeleted: m.isDeleted,
    );
  }

  String _modelToJson(TransactionModel m) {
    return jsonEncode({
      'uuid': m.uuid,
      'user_id': m.userId,
      'type': m.type.name,
      'amount': m.amount,
      'description': m.description,
      'category': m.category.name,
      'category_auto_assigned': m.categoryAutoAssigned,
      'input_method': m.inputMethod.name,
      'transaction_date': m.transactionDate.toIso8601String(),
      'ticket_image_path': m.ticketImagePath,
      'raw_input_text': m.rawInputText,
      'credit_card_uuid': m.creditCardUuid,
      'notes': m.notes,
      'payment_method': m.paymentMethod?.name,
      'is_deleted': m.isDeleted,
      'created_at': m.createdAt.toIso8601String(),
      'updated_at': m.updatedAt.toIso8601String(),
    });
  }
}
