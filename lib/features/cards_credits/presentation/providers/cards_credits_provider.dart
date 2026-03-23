import 'dart:convert';
import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/core/enums/sync_status.dart';
import 'package:betty_app/core/mappers/enum_mapper.dart';
import 'package:betty_app/core/providers/core_providers.dart';
import 'package:betty_app/core/utils/uuid_generator.dart';
import 'package:betty_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:betty_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:betty_app/features/cards_credits/data/models/credit_model.dart';
import 'package:betty_app/features/cards_credits/domain/entities/credit_card_entity.dart';
import 'package:betty_app/features/cards_credits/domain/entities/credit_entity.dart';
import 'package:betty_app/features/sync/data/models/sync_queue_model.dart';
import 'package:betty_app/features/sync/presentation/providers/sync_provider.dart';
import 'package:betty_app/features/financial_health/presentation/providers/health_provider.dart';
import 'package:betty_app/features/alerts/presentation/providers/alert_provider.dart';

// ─────────────────────────────────────────────────────────
// DataSources
// ─────────────────────────────────────────────────────────

class CreditCardLocalDataSource {
  final Isar _isar;
  CreditCardLocalDataSource(this._isar);

  Future<void> save(CreditCardModel card) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.creditCardModels
          .filter()
          .uuidEqualTo(card.uuid)
          .findFirst();
      if (existing != null) card.id = existing.id;
      await _isar.creditCardModels.put(card);
    });
  }

  Future<List<CreditCardModel>> getAllActive(String userId) async {
    return await _isar.creditCardModels
        .filter()
        .userIdEqualTo(userId)
        .isActiveEqualTo(true)
        .sortByName()
        .findAll();
  }

  Future<CreditCardModel?> getByUuid(String uuid) async {
    return await _isar.creditCardModels
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
  }

  Future<void> deactivate(String uuid) async {
    await _isar.writeTxn(() async {
      final card = await _isar.creditCardModels
          .filter()
          .uuidEqualTo(uuid)
          .findFirst();
      if (card != null) {
        card.isActive = false;
        card.syncStatus = CcSyncStatus.pending;
        card.updatedAt = DateTime.now();
        await _isar.creditCardModels.put(card);
      }
    });
  }
}

class CreditLocalDataSource {
  final Isar _isar;
  CreditLocalDataSource(this._isar);

  Future<void> save(CreditModel credit) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.creditModels
          .filter()
          .uuidEqualTo(credit.uuid)
          .findFirst();
      if (existing != null) credit.id = existing.id;
      await _isar.creditModels.put(credit);
    });
  }

  Future<List<CreditModel>> getAllActive(String userId) async {
    return await _isar.creditModels
        .filter()
        .userIdEqualTo(userId)
        .isActiveEqualTo(true)
        .sortByName()
        .findAll();
  }

  Future<CreditModel?> getByUuid(String uuid) async {
    return await _isar.creditModels
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
  }

  Future<void> deactivate(String uuid) async {
    await _isar.writeTxn(() async {
      final credit = await _isar.creditModels
          .filter()
          .uuidEqualTo(uuid)
          .findFirst();
      if (credit != null) {
        credit.isActive = false;
        credit.syncStatus = CreditSyncStatus.pending;
        credit.updatedAt = DateTime.now();
        await _isar.creditModels.put(credit);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────
// DI Providers
// ─────────────────────────────────────────────────────────

final creditCardLocalDsProvider = Provider<CreditCardLocalDataSource>((ref) {
  return CreditCardLocalDataSource(ref.watch(isarProvider));
});

final creditLocalDsProvider = Provider<CreditLocalDataSource>((ref) {
  return CreditLocalDataSource(ref.watch(isarProvider));
});

// ─────────────────────────────────────────────────────────
// Mappers Isar ↔ Entity (usan enum_mapper centralizado)
// ─────────────────────────────────────────────────────────

CreditCardEntity _cardModelToEntity(CreditCardModel m) {
  return CreditCardEntity(
    uuid: m.uuid,
    userId: m.userId,
    name: m.name,
    lastFourDigits: m.lastFourDigits,
    network: m.network.toCanonical(),
    creditLimit: m.creditLimit,
    currentBalance: m.currentBalance,
    availableCredit: m.availableCredit,
    cutOffDay: m.cutOffDay,
    paymentDueDay: m.paymentDueDay,
    nextCutOffDate: m.nextCutOffDate,
    nextPaymentDueDate: m.nextPaymentDueDate,
    alertsEnabled: m.alertsEnabled,
    isActive: m.isActive,
    createdAt: m.createdAt,
    updatedAt: m.updatedAt,
    syncStatus: m.syncStatus.toCanonical(),
  );
}

CreditCardModel _cardEntityToModel(
  CreditCardEntity e,
  String userId,
  DateTime now,
  bool isNew,
) {
  return CreditCardModel()
    ..uuid = e.uuid.isEmpty ? UuidGenerator.generate() : e.uuid
    ..userId = userId
    ..name = e.name
    ..lastFourDigits = e.lastFourDigits
    ..network = e.network.toIsar()
    ..creditLimit = e.creditLimit
    ..currentBalance = e.currentBalance
    ..availableCredit = e.availableCredit
    ..cutOffDay = e.cutOffDay
    ..paymentDueDay = e.paymentDueDay
    ..nextCutOffDate = e.nextCutOffDate
    ..nextPaymentDueDate = e.nextPaymentDueDate
    ..alertsEnabled = e.alertsEnabled
    ..isActive = e.isActive
    ..createdAt = isNew ? now : e.createdAt
    ..updatedAt = now
    ..syncStatus = SyncStatus.pending.toCcIsar();
}

String _cardModelToJson(CreditCardModel m) {
  return jsonEncode({
    'uuid': m.uuid,
    'user_id': m.userId,
    'name': m.name,
    'last_four_digits': m.lastFourDigits,
    'network': m.network.name,
    'credit_limit': m.creditLimit,
    'current_balance': m.currentBalance,
    'available_credit': m.availableCredit,
    'cut_off_day': m.cutOffDay,
    'payment_due_day': m.paymentDueDay,
    'next_cut_off_date': m.nextCutOffDate?.toIso8601String(),
    'next_payment_due_date': m.nextPaymentDueDate?.toIso8601String(),
    'alerts_enabled': m.alertsEnabled,
    'is_active': m.isActive,
    'created_at': m.createdAt.toIso8601String(),
    'updated_at': m.updatedAt.toIso8601String(),
  });
}

CreditEntity _creditModelToEntity(CreditModel m) {
  return CreditEntity(
    uuid: m.uuid,
    userId: m.userId,
    name: m.name,
    institution: m.institution,
    originalAmount: m.originalAmount,
    currentBalance: m.currentBalance,
    interestRate: m.interestRate,
    monthlyPayment: m.monthlyPayment,
    paymentDay: m.paymentDay,
    nextPaymentDate: m.nextPaymentDate,
    startDate: m.startDate,
    endDate: m.endDate,
    totalInstallments: m.totalInstallments,
    paidInstallments: m.paidInstallments,
    alertsEnabled: m.alertsEnabled,
    isActive: m.isActive,
    createdAt: m.createdAt,
    updatedAt: m.updatedAt,
    syncStatus: m.syncStatus.toCanonical(),
  );
}

CreditModel _creditEntityToModel(
  CreditEntity e,
  String userId,
  DateTime now,
  bool isNew,
) {
  return CreditModel()
    ..uuid = e.uuid.isEmpty ? UuidGenerator.generate() : e.uuid
    ..userId = userId
    ..name = e.name
    ..institution = e.institution
    ..originalAmount = e.originalAmount
    ..currentBalance = e.currentBalance
    ..interestRate = e.interestRate
    ..monthlyPayment = e.monthlyPayment
    ..paymentDay = e.paymentDay
    ..nextPaymentDate = e.nextPaymentDate
    ..startDate = e.startDate
    ..endDate = e.endDate
    ..totalInstallments = e.totalInstallments
    ..paidInstallments = e.paidInstallments
    ..alertsEnabled = e.alertsEnabled
    ..isActive = e.isActive
    ..createdAt = isNew ? now : e.createdAt
    ..updatedAt = now
    ..syncStatus = SyncStatus.pending.toCreditIsar();
}

String _creditModelToJson(CreditModel m) {
  return jsonEncode({
    'uuid': m.uuid,
    'user_id': m.userId,
    'name': m.name,
    'institution': m.institution,
    'original_amount': m.originalAmount,
    'current_balance': m.currentBalance,
    'interest_rate': m.interestRate,
    'monthly_payment': m.monthlyPayment,
    'payment_day': m.paymentDay,
    'next_payment_date': m.nextPaymentDate?.toIso8601String(),
    'start_date': m.startDate?.toIso8601String(),
    'end_date': m.endDate?.toIso8601String(),
    'total_installments': m.totalInstallments,
    'paid_installments': m.paidInstallments,
    'alerts_enabled': m.alertsEnabled,
    'is_active': m.isActive,
    'created_at': m.createdAt.toIso8601String(),
    'updated_at': m.updatedAt.toIso8601String(),
  });
}

// ─────────────────────────────────────────────────────────
// Credit Cards Provider
// ─────────────────────────────────────────────────────────

final creditCardsProvider =
    AsyncNotifierProvider<CreditCardsNotifier, List<CreditCardEntity>>(
  CreditCardsNotifier.new,
);

class CreditCardsNotifier extends AsyncNotifier<List<CreditCardEntity>> {
  @override
  Future<List<CreditCardEntity>> build() async {
    final authState = ref.watch(authProvider);
    if (authState is! AuthAuthenticated) return [];

    final models = await ref
        .watch(creditCardLocalDsProvider)
        .getAllActive(authState.user.supabaseId);
    return models.map(_cardModelToEntity).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }

  Future<void> save(CreditCardEntity entity) async {
    final authState = ref.read(authProvider);
    if (authState is! AuthAuthenticated) return;

    final uid = authState.user.supabaseId;
    final ds = ref.read(creditCardLocalDsProvider);
    final isNew = (await ds.getByUuid(entity.uuid)) == null;
    final now = DateTime.now();

    final model = _cardEntityToModel(entity, uid, now, isNew);
    await ds.save(model);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: uid,
          targetCollection: 'credit_cards',
          targetUuid: model.uuid,
          operation: isNew ? SyncOperation.create : SyncOperation.update,
          payload: _cardModelToJson(model),
        );

    ref.invalidate(healthProvider);
    ref.invalidate(alertProvider);
    await refresh();
  }

  Future<void> deactivate(String uuid) async {
    final authState = ref.read(authProvider);
    if (authState is! AuthAuthenticated) return;

    await ref.read(creditCardLocalDsProvider).deactivate(uuid);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: authState.user.supabaseId,
          targetCollection: 'credit_cards',
          targetUuid: uuid,
          operation: SyncOperation.update,
          payload: jsonEncode({
            'uuid': uuid,
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          }),
        );

    ref.invalidate(healthProvider);
    ref.invalidate(alertProvider);
    await refresh();
  }

  Future<void> addCard({
    required String name,
    String? lastFourDigits,
    required String network,
    required double creditLimit,
    required double currentBalance,
    required int cutOffDay,
    required int paymentDueDay,
  }) async {
    final authState = ref.read(authProvider);
    if (authState is! AuthAuthenticated) return;

    final uid = authState.user.supabaseId;
    final now = DateTime.now();
    final uuid = UuidGenerator.generate();
    final available = creditLimit - currentBalance;

    final model = CreditCardModel()
      ..uuid = uuid
      ..userId = uid
      ..name = name
      ..lastFourDigits = lastFourDigits
      ..network = CcNetwork.values.byName(network)
      ..creditLimit = creditLimit
      ..currentBalance = currentBalance
      ..availableCredit = available
      ..cutOffDay = cutOffDay
      ..paymentDueDay = paymentDueDay
      ..alertsEnabled = true
      ..isActive = true
      ..createdAt = now
      ..updatedAt = now
      ..syncStatus = SyncStatus.pending.toCcIsar();

    await ref.read(creditCardLocalDsProvider).save(model);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: uid,
          targetCollection: 'credit_cards',
          targetUuid: uuid,
          operation: SyncOperation.create,
          payload: _cardModelToJson(model),
        );

    ref.invalidate(healthProvider);
    ref.invalidate(alertProvider);
    await refresh();
  }

  Future<void> deleteCard(String uuid) async {
    await deactivate(uuid);
  }

  Future<void> toggleAlerts(String uuid, bool enabled) async {
    final authState = ref.read(authProvider);
    if (authState is! AuthAuthenticated) return;

    final ds = ref.read(creditCardLocalDsProvider);
    final model = await ds.getByUuid(uuid);
    if (model == null) return;

    model.alertsEnabled = enabled;
    model.updatedAt = DateTime.now();
    model.syncStatus = SyncStatus.pending.toCcIsar();
    await ds.save(model);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: authState.user.supabaseId,
          targetCollection: 'credit_cards',
          targetUuid: uuid,
          operation: SyncOperation.update,
          payload: _cardModelToJson(model),
        );

    ref.invalidate(alertProvider);
    await refresh();
  }
}

// ─────────────────────────────────────────────────────────
// Credits Provider
// ─────────────────────────────────────────────────────────

final creditsProvider =
    AsyncNotifierProvider<CreditsNotifier, List<CreditEntity>>(
  CreditsNotifier.new,
);

class CreditsNotifier extends AsyncNotifier<List<CreditEntity>> {
  @override
  Future<List<CreditEntity>> build() async {
    final authState = ref.watch(authProvider);
    if (authState is! AuthAuthenticated) return [];

    final models = await ref
        .watch(creditLocalDsProvider)
        .getAllActive(authState.user.supabaseId);
    return models.map(_creditModelToEntity).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }

  Future<void> save(CreditEntity entity) async {
    final authState = ref.read(authProvider);
    if (authState is! AuthAuthenticated) return;

    final uid = authState.user.supabaseId;
    final ds = ref.read(creditLocalDsProvider);
    final existing = await ds.getByUuid(entity.uuid);
    final isNew = existing == null;
    final now = DateTime.now();

    final model = _creditEntityToModel(entity, uid, now, isNew);
    await ds.save(model);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: uid,
          targetCollection: 'credits',
          targetUuid: model.uuid,
          operation: isNew ? SyncOperation.create : SyncOperation.update,
          payload: _creditModelToJson(model),
        );

    ref.invalidate(healthProvider);
    ref.invalidate(alertProvider);
    await refresh();
  }

  Future<void> deactivate(String uuid) async {
    final authState = ref.read(authProvider);
    if (authState is! AuthAuthenticated) return;

    await ref.read(creditLocalDsProvider).deactivate(uuid);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: authState.user.supabaseId,
          targetCollection: 'credits',
          targetUuid: uuid,
          operation: SyncOperation.update,
          payload: jsonEncode({
            'uuid': uuid,
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          }),
        );

    ref.invalidate(healthProvider);
    ref.invalidate(alertProvider);
    await refresh();
  }

  Future<void> addCredit({
    required String name,
    String? institution,
    required double originalAmount,
    required double currentBalance,
    double? interestRate,
    required double monthlyPayment,
    required int paymentDay,
    int? totalInstallments,
    int? paidInstallments,
  }) async {
    final authState = ref.read(authProvider);
    if (authState is! AuthAuthenticated) return;

    final uid = authState.user.supabaseId;
    final now = DateTime.now();
    final uuid = UuidGenerator.generate();

    final model = CreditModel()
      ..uuid = uuid
      ..userId = uid
      ..name = name
      ..institution = institution
      ..originalAmount = originalAmount
      ..currentBalance = currentBalance
      ..interestRate = interestRate
      ..monthlyPayment = monthlyPayment
      ..paymentDay = paymentDay
      ..totalInstallments = totalInstallments
      ..paidInstallments = paidInstallments
      ..alertsEnabled = true
      ..isActive = true
      ..createdAt = now
      ..updatedAt = now
      ..syncStatus = SyncStatus.pending.toCreditIsar();

    await ref.read(creditLocalDsProvider).save(model);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: uid,
          targetCollection: 'credits',
          targetUuid: uuid,
          operation: SyncOperation.create,
          payload: _creditModelToJson(model),
        );

    ref.invalidate(healthProvider);
    ref.invalidate(alertProvider);
    await refresh();
  }

  Future<void> deleteCredit(String uuid) async {
    await deactivate(uuid);
  }

  Future<void> toggleAlerts(String uuid, bool enabled) async {
    final authState = ref.read(authProvider);
    if (authState is! AuthAuthenticated) return;

    final ds = ref.read(creditLocalDsProvider);
    final model = await ds.getByUuid(uuid);
    if (model == null) return;

    model.alertsEnabled = enabled;
    model.updatedAt = DateTime.now();
    model.syncStatus = SyncStatus.pending.toCreditIsar();
    await ds.save(model);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: authState.user.supabaseId,
          targetCollection: 'credits',
          targetUuid: uuid,
          operation: SyncOperation.update,
          payload: _creditModelToJson(model),
        );

    ref.invalidate(alertProvider);
    await refresh();
  }
}