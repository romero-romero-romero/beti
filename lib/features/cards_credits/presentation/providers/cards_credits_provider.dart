import 'dart:convert';
import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/core/providers/core_providers.dart';
import 'package:betty_app/core/utils/uuid_generator.dart';
import 'package:betty_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:betty_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:betty_app/features/cards_credits/data/models/credit_model.dart';
import 'package:betty_app/features/sync/data/models/sync_queue_model.dart';
import 'package:betty_app/features/sync/presentation/providers/sync_provider.dart';
import 'package:betty_app/features/financial_health/presentation/providers/health_provider.dart';

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
// Entities (para la UI)
// ─────────────────────────────────────────────────────────

class CreditCardEntity {
  final String uuid;
  final String name;
  final String? lastFourDigits;
  final String network;
  final double creditLimit;
  final double currentBalance;
  final double availableCredit;
  final int cutOffDay;
  final int paymentDueDay;
  final double? interestRate;
  final bool alertsEnabled;
  final bool isActive;

  const CreditCardEntity({
    required this.uuid,
    required this.name,
    this.lastFourDigits,
    required this.network,
    required this.creditLimit,
    required this.currentBalance,
    required this.availableCredit,
    required this.cutOffDay,
    required this.paymentDueDay,
    this.interestRate,
    this.alertsEnabled = true,
    this.isActive = true,
  });

  double get utilizationPercent =>
      creditLimit > 0 ? (currentBalance / creditLimit * 100) : 0;
}

class CreditEntity {
  final String uuid;
  final String name;
  final String? institution;
  final double originalAmount;
  final double currentBalance;
  final double? interestRate;
  final double monthlyPayment;
  final int paymentDay;
  final int? totalInstallments;
  final int? paidInstallments;
  final bool alertsEnabled;

  const CreditEntity({
    required this.uuid,
    required this.name,
    this.institution,
    required this.originalAmount,
    required this.currentBalance,
    this.interestRate,
    required this.monthlyPayment,
    required this.paymentDay,
    this.totalInstallments,
    this.paidInstallments,
    this.alertsEnabled = true,
  });

  double get progressPercent =>
      originalAmount > 0
          ? ((originalAmount - currentBalance) / originalAmount * 100)
          : 0;
}

// ─────────────────────────────────────────────────────────
// Credit Cards Notifier
// ─────────────────────────────────────────────────────────

class CreditCardsNotifier extends AsyncNotifier<List<CreditCardEntity>> {
  @override
  Future<List<CreditCardEntity>> build() async => _load();

  Future<List<CreditCardEntity>> _load() async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return [];
    final models = await ref
        .read(creditCardLocalDsProvider)
        .getAllActive(auth.user.supabaseId);
    return models.map(_toEntity).toList();
  }

  CreditCardEntity _toEntity(CreditCardModel m) => CreditCardEntity(
        uuid: m.uuid,
        name: m.name,
        lastFourDigits: m.lastFourDigits,
        network: m.network.name,
        creditLimit: m.creditLimit,
        currentBalance: m.currentBalance,
        availableCredit: m.availableCredit,
        cutOffDay: m.cutOffDay,
        paymentDueDay: m.paymentDueDay,
        interestRate: (m.syncStatus == CcSyncStatus.pending) ? null : null,
        alertsEnabled: m.alertsEnabled,
        isActive: m.isActive,
      );

  Future<void> addCard({
    required String name,
    String? lastFourDigits,
    required String network,
    required double creditLimit,
    required double currentBalance,
    required int cutOffDay,
    required int paymentDueDay,
  }) async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return;

    final now = DateTime.now();
    final uuid = UuidGenerator.generate();
    final available = creditLimit - currentBalance;

    final model = CreditCardModel()
      ..uuid = uuid
      ..userId = auth.user.supabaseId
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
      ..syncStatus = CcSyncStatus.pending;

    await ref.read(creditCardLocalDsProvider).save(model);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: auth.user.supabaseId,
          targetCollection: 'credit_cards',
          targetUuid: uuid,
          operation: SyncOperation.create,
          payload: jsonEncode({
            'uuid': uuid,
            'user_id': auth.user.supabaseId,
            'name': name,
            'last_four_digits': lastFourDigits,
            'network': network,
            'credit_limit': creditLimit,
            'current_balance': currentBalance,
            'available_credit': available,
            'cut_off_day': cutOffDay,
            'payment_due_day': paymentDueDay,
            'alerts_enabled': true,
            'is_active': true,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          }),
        );

    ref.invalidate(healthProvider);
    state = AsyncData(await _load());

    // Push inmediato para que otros dispositivos reciban el cambio
    ref.read(syncProvider.notifier).pushNow();
  }

  Future<void> deleteCard(String uuid) async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return;

    await ref.read(creditCardLocalDsProvider).deactivate(uuid);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: auth.user.supabaseId,
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
    state = AsyncData(await _load());
    ref.read(syncProvider.notifier).pushNow();
  }

  Future<void> refresh() async {
    state = AsyncData(await _load());
  }
}

final creditCardsProvider =
    AsyncNotifierProvider<CreditCardsNotifier, List<CreditCardEntity>>(
  CreditCardsNotifier.new,
);

// ─────────────────────────────────────────────────────────
// Credits Notifier
// ─────────────────────────────────────────────────────────

class CreditsNotifier extends AsyncNotifier<List<CreditEntity>> {
  @override
  Future<List<CreditEntity>> build() async => _load();

  Future<List<CreditEntity>> _load() async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return [];
    final models = await ref
        .read(creditLocalDsProvider)
        .getAllActive(auth.user.supabaseId);
    return models.map(_toEntity).toList();
  }

  CreditEntity _toEntity(CreditModel m) => CreditEntity(
        uuid: m.uuid,
        name: m.name,
        institution: m.institution,
        originalAmount: m.originalAmount,
        currentBalance: m.currentBalance,
        interestRate: m.interestRate,
        monthlyPayment: m.monthlyPayment,
        paymentDay: m.paymentDay,
        totalInstallments: m.totalInstallments,
        paidInstallments: m.paidInstallments,
        alertsEnabled: m.alertsEnabled,
      );

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
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return;

    final now = DateTime.now();
    final uuid = UuidGenerator.generate();

    final model = CreditModel()
      ..uuid = uuid
      ..userId = auth.user.supabaseId
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
      ..syncStatus = CreditSyncStatus.pending;

    await ref.read(creditLocalDsProvider).save(model);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: auth.user.supabaseId,
          targetCollection: 'credits',
          targetUuid: uuid,
          operation: SyncOperation.create,
          payload: jsonEncode({
            'uuid': uuid,
            'user_id': auth.user.supabaseId,
            'name': name,
            'institution': institution,
            'original_amount': originalAmount,
            'current_balance': currentBalance,
            'interest_rate': interestRate,
            'monthly_payment': monthlyPayment,
            'payment_day': paymentDay,
            'total_installments': totalInstallments,
            'paid_installments': paidInstallments,
            'alerts_enabled': true,
            'is_active': true,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          }),
        );

    ref.invalidate(healthProvider);
    state = AsyncData(await _load());
    ref.read(syncProvider.notifier).pushNow();
  }

  Future<void> deleteCredit(String uuid) async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return;

    await ref.read(creditLocalDsProvider).deactivate(uuid);

    await ref.read(syncRepositoryProvider).enqueueChange(
          userId: auth.user.supabaseId,
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
    state = AsyncData(await _load());
    ref.read(syncProvider.notifier).pushNow();
  }

  Future<void> refresh() async {
    state = AsyncData(await _load());
  }
}

final creditsProvider =
    AsyncNotifierProvider<CreditsNotifier, List<CreditEntity>>(
  CreditsNotifier.new,
);