// test/features/sync/sync_merge_service_test.dart
//
// ════════════════════════════════════════════════════════════════════════
// SyncMergeService — last-write-wins entre Supabase y Isar.
// ════════════════════════════════════════════════════════════════════════
//
// PIEZA CRÍTICA: Decide qué cambios remotos se aplican localmente. Bug
// acá = se sobrescriben cambios pendientes del usuario (pérdida de datos
// silenciosa) o no se propagan deletes (registros zombies).
//
// MATRIZ DE REGLAS POR TABLA:
//
// | Tabla              | Regla principal                                    |
// |--------------------|----------------------------------------------------|
// | transactions       | LWW + is_deleted propaga sin importar pending      |
// | categories         | LWW puro                                           |
// | credit_cards       | LWW + is_active=false propaga sin importar pending |
// | credits            | LWW + is_active=false propaga sin importar pending |
// | budgets            | LWW puro                                           |
// | goals              | LWW puro                                           |
// | health_snapshots   | INSERT-ONLY (nunca update, no tiene updated_at)    |
//
// REGLA UNIVERSAL DE LWW:
//   1. local==null + remote.is_deleted/is_active=false → SKIP (no traer basura)
//   2. local==null + remote OK → INSERT
//   3. remote.is_deleted/is_active=false → UPDATE (override pending)
//   4. local.syncStatus == pending → SKIP (proteger cambios locales)
//   5. remote.updated_at > local.updated_at → UPDATE
//   6. else → SKIP
//
// ESTRATEGIA DE TESTS:
//   transactions cubre TODAS las reglas a fondo (es el caso canónico).
//   Las demás tablas validan solo sus particularidades + un smoke test
//   de LWW para no duplicar 5 veces los mismos casos.
//
// ════════════════════════════════════════════════════════════════════════

import 'package:beti_app/features/budgets_goals/data/models/budget_model.dart';
import 'package:beti_app/features/budgets_goals/data/models/goal_model.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:beti_app/features/cards_credits/data/models/credit_model.dart';
import 'package:beti_app/features/financial_health/data/models/health_snapshot_model.dart';
import 'package:beti_app/features/sync/data/services/sync_merge_service.dart';
import 'package:beti_app/features/transactions/data/models/category_model.dart';
import 'package:beti_app/features/transactions/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../../helpers/fake_data_factory.dart';
import '../../helpers/isar_test_helper.dart';

// ════════════════════════════════════════════════════════════════════════
// Helpers de fila Supabase (Map<String, dynamic> snake_case)
// ════════════════════════════════════════════════════════════════════════

DateTime _at(int day, [int hour = 0]) => DateTime(2026, 5, day, hour);

Map<String, dynamic> _txnRow({
  required String uuid,
  String userId = FakeDataFactory.defaultUserId,
  double amount = 100,
  String description = 'remoto',
  String type = 'expense',
  String category = 'food',
  String inputMethod = 'manual',
  bool isDeleted = false,
  DateTime? transactionDate,
  DateTime? updatedAt,
  DateTime? createdAt,
}) {
  final now = updatedAt ?? _at(15);
  return {
    'uuid': uuid,
    'user_id': userId,
    'type': type,
    'amount': amount,
    'description': description,
    'category': category,
    'category_auto_assigned': false,
    'input_method': inputMethod,
    'transaction_date': (transactionDate ?? _at(15)).toIso8601String(),
    'is_deleted': isDeleted,
    'created_at': (createdAt ?? _at(1)).toIso8601String(),
    'updated_at': now.toIso8601String(),
  };
}

Map<String, dynamic> _categoryRow({
  required String uuid,
  String userId = FakeDataFactory.defaultUserId,
  String name = 'Comida',
  String parentCategoryKey = 'food',
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? _at(15);
  return {
    'uuid': uuid,
    'user_id': userId,
    'name': name,
    'parent_category_key': parentCategoryKey,
    'icon': '🍔',
    'keywords': ['comida'],
    'is_system': false,
    'is_income': false,
    'sort_order': 0,
    'created_at': _at(1).toIso8601String(),
    'updated_at': now.toIso8601String(),
  };
}

Map<String, dynamic> _creditCardRow({
  required String uuid,
  String userId = FakeDataFactory.defaultUserId,
  bool isActive = true,
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? _at(15);
  return {
    'uuid': uuid,
    'user_id': userId,
    'name': 'BBVA Azul',
    'last_four_digits': '1234',
    'network': 'visa',
    'credit_limit': 30000,
    'current_balance': 5000,
    'available_credit': 25000,
    'annual_rate': 0.45,
    'cut_off_day': 15,
    'payment_due_day': 5,
    'next_cut_off_date': null,
    'next_payment_due_date': null,
    'alerts_enabled': true,
    'belvo_link_id': null,
    'belvo_account_id': null,
    'last_belvo_sync_at': null,
    'is_active': isActive,
    'created_at': _at(1).toIso8601String(),
    'updated_at': now.toIso8601String(),
  };
}

Map<String, dynamic> _creditRow({
  required String uuid,
  String userId = FakeDataFactory.defaultUserId,
  bool isActive = true,
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? _at(15);
  return {
    'uuid': uuid,
    'user_id': userId,
    'name': 'Préstamo personal',
    'institution': 'Nu',
    'original_amount': 50000,
    'current_balance': 30000,
    'interest_rate': 0.18,
    'monthly_payment': 2500,
    'payment_day': 10,
    'next_payment_date': null,
    'start_date': null,
    'end_date': null,
    'total_installments': null,
    'paid_installments': null,
    'alerts_enabled': true,
    'belvo_link_id': null,
    'belvo_account_id': null,
    'last_belvo_sync_at': null,
    'is_active': isActive,
    'created_at': _at(1).toIso8601String(),
    'updated_at': now.toIso8601String(),
  };
}

Map<String, dynamic> _budgetRow({
  required String uuid,
  String userId = FakeDataFactory.defaultUserId,
  double budgetedAmount = 5000,
  double spentAmount = 1000,
  String period = '2026-05',
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? _at(15);
  return {
    'uuid': uuid,
    'user_id': userId,
    'category_key': 'food',
    'budgeted_amount': budgetedAmount,
    'spent_amount': spentAmount,
    'consumption_ratio': budgetedAmount > 0 ? spentAmount / budgetedAmount : 0,
    'period': period,
    'is_suggested': false,
    'created_at': _at(1).toIso8601String(),
    'updated_at': now.toIso8601String(),
  };
}

Map<String, dynamic> _goalRow({
  required String uuid,
  String userId = FakeDataFactory.defaultUserId,
  String name = 'Vacaciones',
  double targetAmount = 20000,
  double savedAmount = 5000,
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? _at(15);
  return {
    'uuid': uuid,
    'user_id': userId,
    'name': name,
    'target_amount': targetAmount,
    'saved_amount': savedAmount,
    'progress': targetAmount > 0 ? savedAmount / targetAmount : 0,
    'deadline': null,
    'icon': null,
    'is_completed': false,
    'is_active': true,
    'created_at': _at(1).toIso8601String(),
    'updated_at': now.toIso8601String(),
  };
}

Map<String, dynamic> _healthSnapshotRow({
  required String uuid,
  String userId = FakeDataFactory.defaultUserId,
  double healthScore = 75,
  DateTime? createdAt,
}) {
  return {
    'uuid': uuid,
    'user_id': userId,
    'snapshot_date': (createdAt ?? _at(15)).toIso8601String(),
    'total_income': 30000,
    'total_expenses': 15000,
    'expense_to_income_ratio': 0.5,
    'total_debt': 5000,
    'overdue_payments': 0,
    'credit_utilization_ratio': 0.16,
    'goal_progress_avg': 0.25,
    'health_score': healthScore,
    'health_level': 'stable',
    'emotional_message': '',
    'created_at': (createdAt ?? _at(15)).toIso8601String(),
    // No tiene updated_at — esa es su peculiaridad.
  };
}

// ════════════════════════════════════════════════════════════════════════
// MAIN
// ════════════════════════════════════════════════════════════════════════

void main() {
  setUpAll(IsarTestHelper.initCore);

  late Isar isar;
  late SyncMergeService merge;

  setUp(() async {
    isar = await IsarTestHelper.openIsar();
    merge = SyncMergeService(isar);
  });

  tearDown(() async {
    await IsarTestHelper.closeIsar(isar);
  });

  // ══════════════════════════════════════════════════════════════════════
  // TRANSACTIONS — caso canónico (cubre las 6 reglas)
  // ══════════════════════════════════════════════════════════════════════

  group('transactions', () {
    test('inserta cuando no existe local', () async {
      final result = await merge.mergeAll({
        'transactions': [_txnRow(uuid: 'new-1')],
      });

      expect(result.inserted, 1);
      expect(result.updated, 0);
      expect(result.skipped, 0);

      final saved = await isar.transactionModels
          .filter()
          .uuidEqualTo('new-1')
          .findFirst();
      expect(saved, isNotNull);
      expect(saved!.syncStatus, TxSyncStatus.synced,
          reason: 'datos del pull se marcan synced');
    });

    test('NO inserta si remote.is_deleted=true y no existe local', () async {
      final result = await merge.mergeAll({
        'transactions': [_txnRow(uuid: 'deleted-on-remote', isDeleted: true)],
      });

      expect(result.inserted, 0);
      expect(result.skipped, 1);
      expect(await isar.transactionModels.count(), 0);
    });

    test('actualiza cuando remote.updated_at > local.updated_at', () async {
      // Local: synced, fechado en día 10.
      await isar.writeTxn(() async {
        await isar.transactionModels.put(
          FakeDataFactory.transaction(
            uuid: 'tx-1',
            description: 'local antiguo',
            updatedAt: _at(10),
            syncStatus: TxSyncStatus.synced,
          ),
        );
      });

      // Remote: actualizado en día 20.
      final result = await merge.mergeAll({
        'transactions': [
          _txnRow(
            uuid: 'tx-1',
            description: 'remoto nuevo',
            updatedAt: _at(20),
          ),
        ],
      });

      expect(result.updated, 1);

      final saved = await isar.transactionModels
          .filter()
          .uuidEqualTo('tx-1')
          .findFirst();
      expect(saved!.description, 'remoto nuevo');
    });

    test('SKIP cuando remote.updated_at <= local.updated_at', () async {
      await isar.writeTxn(() async {
        await isar.transactionModels.put(
          FakeDataFactory.transaction(
            uuid: 'tx-1',
            description: 'local nuevo',
            updatedAt: _at(20),
            syncStatus: TxSyncStatus.synced,
          ),
        );
      });

      final result = await merge.mergeAll({
        'transactions': [
          _txnRow(
            uuid: 'tx-1',
            description: 'remoto antiguo',
            updatedAt: _at(10),
          ),
        ],
      });

      expect(result.skipped, 1);
      expect(result.updated, 0);

      final saved = await isar.transactionModels
          .filter()
          .uuidEqualTo('tx-1')
          .findFirst();
      expect(saved!.description, 'local nuevo',
          reason: 'el local sobrevive intacto');
    });

    test('PENDING local protege contra overwrite (NO sobrescribe)', () async {
      // Local: PENDING (cambios sin sync), aunque remoto sea más nuevo.
      await isar.writeTxn(() async {
        await isar.transactionModels.put(
          FakeDataFactory.transaction(
            uuid: 'tx-pending',
            description: 'local pending',
            updatedAt: _at(5),
            syncStatus: TxSyncStatus.pending,
          ),
        );
      });

      final result = await merge.mergeAll({
        'transactions': [
          _txnRow(
            uuid: 'tx-pending',
            description: 'remoto nuevo',
            updatedAt: _at(25),
          ),
        ],
      });

      expect(result.skipped, 1, reason: 'pending bloquea overwrite');

      final saved = await isar.transactionModels
          .filter()
          .uuidEqualTo('tx-pending')
          .findFirst();
      expect(saved!.description, 'local pending',
          reason: 'el cambio local pendiente se preserva');
      expect(saved.syncStatus, TxSyncStatus.pending,
          reason: 'syncStatus se mantiene pending');
    });

    test('is_deleted remoto SOBRESCRIBE incluso un local pending', () async {
      // Caso especial: delete siempre gana, incluso vs pending.
      await isar.writeTxn(() async {
        await isar.transactionModels.put(
          FakeDataFactory.transaction(
            uuid: 'tx-tombstone',
            description: 'local pending',
            updatedAt: _at(20),
            syncStatus: TxSyncStatus.pending,
            isDeleted: false,
          ),
        );
      });

      final result = await merge.mergeAll({
        'transactions': [
          _txnRow(
            uuid: 'tx-tombstone',
            isDeleted: true,
            updatedAt: _at(10), // incluso si es más antiguo
          ),
        ],
      });

      expect(result.updated, 1, reason: 'delete propaga aunque sea anterior');

      final saved = await isar.transactionModels
          .filter()
          .uuidEqualTo('tx-tombstone')
          .findFirst();
      expect(saved!.isDeleted, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CATEGORIES — LWW puro (sin flags especiales)
  // ══════════════════════════════════════════════════════════════════════

  group('categories', () {
    test('insert cuando no existe', () async {
      final result = await merge.mergeAll({
        'categories': [_categoryRow(uuid: 'cat-1')],
      });
      expect(result.inserted, 1);

      final saved = await isar.categoryModels
          .filter()
          .uuidEqualTo('cat-1')
          .findFirst();
      expect(saved, isNotNull);
      expect(saved!.syncStatus, CatSyncStatus.synced);
    });

    test('PENDING local protege contra overwrite', () async {
      await isar.writeTxn(() async {
        await isar.categoryModels.put(
          FakeDataFactory.category(
            uuid: 'cat-1',
            name: 'local pending',
            syncStatus: CatSyncStatus.pending,
          ),
        );
      });

      final result = await merge.mergeAll({
        'categories': [
          _categoryRow(
            uuid: 'cat-1',
            name: 'remoto',
            updatedAt: DateTime.now().add(const Duration(days: 1)),
          ),
        ],
      });

      expect(result.skipped, 1);
      final saved = await isar.categoryModels
          .filter()
          .uuidEqualTo('cat-1')
          .findFirst();
      expect(saved!.name, 'local pending');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CREDIT CARDS — is_active propaga (similar a is_deleted en transactions)
  // ══════════════════════════════════════════════════════════════════════

  group('credit_cards', () {
    test('NO inserta si remote.is_active=false y no existe local', () async {
      final result = await merge.mergeAll({
        'credit_cards': [_creditCardRow(uuid: 'cc-1', isActive: false)],
      });
      expect(result.inserted, 0);
      expect(result.skipped, 1);
      expect(await isar.creditCardModels.count(), 0);
    });

    test('is_active=false remoto sobrescribe incluso un local pending',
        () async {
      await isar.writeTxn(() async {
        await isar.creditCardModels.put(
          FakeDataFactory.creditCard(
            uuid: 'cc-pending-active',
            syncStatus: CcSyncStatus.pending,
            isActive: true,
          ),
        );
      });

      final result = await merge.mergeAll({
        'credit_cards': [
          _creditCardRow(uuid: 'cc-pending-active', isActive: false),
        ],
      });

      expect(result.updated, 1,
          reason: 'desactivación remota propaga aunque local sea pending');

      final saved = await isar.creditCardModels
          .filter()
          .uuidEqualTo('cc-pending-active')
          .findFirst();
      expect(saved!.isActive, isFalse);
    });

    test('LWW normal cuando ambos activos (skip si pending, update si OK)',
        () async {
      await isar.writeTxn(() async {
        await isar.creditCardModels.put(
          FakeDataFactory.creditCard(
            uuid: 'cc-synced',
            syncStatus: CcSyncStatus.synced,
            isActive: true,
          ),
        );
      });

      // Damos al remoto un updated_at futuro para garantizar que gane.
      final result = await merge.mergeAll({
        'credit_cards': [
          _creditCardRow(
            uuid: 'cc-synced',
            isActive: true,
            updatedAt: DateTime.now().add(const Duration(days: 1)),
          ),
        ],
      });

      expect(result.updated, 1);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CREDITS — misma regla que credit_cards
  // ══════════════════════════════════════════════════════════════════════

  group('credits', () {
    test('NO inserta si remote.is_active=false y no existe local', () async {
      final result = await merge.mergeAll({
        'credits': [_creditRow(uuid: 'cr-1', isActive: false)],
      });
      expect(result.inserted, 0);
      expect(result.skipped, 1);
    });

    test('is_active=false propaga incluso sobre pending', () async {
      await isar.writeTxn(() async {
        await isar.creditModels.put(
          FakeDataFactory.credit(
            uuid: 'cr-1',
            syncStatus: CreditSyncStatus.pending,
            isActive: true,
          ),
        );
      });

      final result = await merge.mergeAll({
        'credits': [_creditRow(uuid: 'cr-1', isActive: false)],
      });

      expect(result.updated, 1);

      final saved =
          await isar.creditModels.filter().uuidEqualTo('cr-1').findFirst();
      expect(saved!.isActive, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // BUDGETS — LWW puro
  // ══════════════════════════════════════════════════════════════════════

  group('budgets', () {
    test('insert + update + skip(pending) en un solo merge', () async {
      // Sembrar uno synced (será updated) y uno pending (será skipped).
      await isar.writeTxn(() async {
        await isar.budgetModels.put(
          FakeDataFactory.budget(
            uuid: 'b-synced',
            spentAmount: 500,
            syncStatus: BudgetSyncStatus.synced,
          )..updatedAt = _at(5),
        );
        await isar.budgetModels.put(
          FakeDataFactory.budget(
            uuid: 'b-pending',
            spentAmount: 999,
            syncStatus: BudgetSyncStatus.pending,
          )..updatedAt = _at(5),
        );
      });

      final result = await merge.mergeAll({
        'budgets': [
          _budgetRow(uuid: 'b-new', updatedAt: _at(20)),
          _budgetRow(
            uuid: 'b-synced',
            spentAmount: 1500,
            updatedAt: _at(20),
          ),
          _budgetRow(
            uuid: 'b-pending',
            spentAmount: 1500,
            updatedAt: _at(20),
          ),
        ],
      });

      expect(result.inserted, 1, reason: 'b-new entra');
      expect(result.updated, 1, reason: 'b-synced se actualiza');
      expect(result.skipped, 1, reason: 'b-pending se protege');

      final pendingPreserved = await isar.budgetModels
          .filter()
          .uuidEqualTo('b-pending')
          .findFirst();
      expect(pendingPreserved!.spentAmount, 999);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // GOALS — LWW puro
  // ══════════════════════════════════════════════════════════════════════

  group('goals', () {
    test('insert cuando no existe', () async {
      final result = await merge.mergeAll({
        'goals': [_goalRow(uuid: 'g-1')],
      });
      expect(result.inserted, 1);
    });

    test('PENDING local protege', () async {
      await isar.writeTxn(() async {
        await isar.goalModels.put(
          FakeDataFactory.goal(
            uuid: 'g-1',
            name: 'local pending',
            syncStatus: GoalSyncStatus.pending,
          ),
        );
      });

      final result = await merge.mergeAll({
        'goals': [
          _goalRow(
            uuid: 'g-1',
            name: 'remoto',
            updatedAt: DateTime.now().add(const Duration(days: 1)),
          ),
        ],
      });

      expect(result.skipped, 1);

      final saved =
          await isar.goalModels.filter().uuidEqualTo('g-1').findFirst();
      expect(saved!.name, 'local pending');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // HEALTH SNAPSHOTS — insert-only
  // ══════════════════════════════════════════════════════════════════════

  group('health_snapshots', () {
    test('inserta cuando no existe', () async {
      final result = await merge.mergeAll({
        'health_snapshots': [_healthSnapshotRow(uuid: 'h-1')],
      });
      expect(result.inserted, 1);
      expect(await isar.healthSnapshotModels.count(), 1);
    });

    test('SKIP si ya existe (no se actualiza nunca)', () async {
      // Insertamos via merge primero.
      await merge.mergeAll({
        'health_snapshots': [_healthSnapshotRow(uuid: 'h-1', healthScore: 50)],
      });

      // Reintentamos con un health_score distinto. NO debe actualizarse.
      final result = await merge.mergeAll({
        'health_snapshots': [_healthSnapshotRow(uuid: 'h-1', healthScore: 90)],
      });

      expect(result.skipped, 1);
      expect(result.updated, 0);

      final saved = await isar.healthSnapshotModels
          .filter()
          .uuidEqualTo('h-1')
          .findFirst();
      expect(saved!.healthScore, 50,
          reason: 'snapshots son inmutables, el primero gana');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // mergeAll — orquestador
  // ══════════════════════════════════════════════════════════════════════

  group('mergeAll', () {
    test('suma resultados de todas las tablas', () async {
      final result = await merge.mergeAll({
        'transactions': [_txnRow(uuid: 't1'), _txnRow(uuid: 't2')],
        'categories': [_categoryRow(uuid: 'c1')],
        'goals': [_goalRow(uuid: 'g1')],
      });

      expect(result.inserted, 4);
      expect(result.updated, 0);
      expect(result.skipped, 0);
    });

    test('salta tablas con lista vacía sin errores', () async {
      final result = await merge.mergeAll({
        'transactions': [],
        'categories': [],
        'budgets': [_budgetRow(uuid: 'b1')],
      });
      expect(result.inserted, 1);
    });

    test('tabla desconocida no causa fallo (default empty MergeResult)',
        () async {
      final result = await merge.mergeAll({
        'unknown_table': [
          {'uuid': 'x', 'foo': 'bar'},
        ],
        'transactions': [_txnRow(uuid: 't1')],
      });
      expect(result.inserted, 1, reason: 'transactions sí entra');
      // unknown_table → MergeResult vacío, sin lanzar.
    });

    test('mapa vacío → MergeResult cero', () async {
      final result = await merge.mergeAll({});
      expect(result.inserted, 0);
      expect(result.updated, 0);
      expect(result.skipped, 0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // MergeResult — operador +
  // ══════════════════════════════════════════════════════════════════════

  group('MergeResult', () {
    test('operador + suma componentes individualmente', () {
      const a = MergeResult(inserted: 1, updated: 2, skipped: 3);
      const b = MergeResult(inserted: 10, updated: 20, skipped: 30);
      final sum = a + b;

      expect(sum.inserted, 11);
      expect(sum.updated, 22);
      expect(sum.skipped, 33);
    });

    test('default constructor da ceros', () {
      const r = MergeResult();
      expect(r.inserted, 0);
      expect(r.updated, 0);
      expect(r.skipped, 0);
    });
  });
}