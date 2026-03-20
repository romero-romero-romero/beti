import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:betty_app/core/providers/core_providers.dart';
import 'package:betty_app/core/utils/currency_formatter.dart';
import 'package:betty_app/core/utils/date_utils.dart';
import 'package:betty_app/core/utils/uuid_generator.dart';
import 'package:betty_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:betty_app/features/cards_credits/data/models/credit_card_model.dart';
import 'package:betty_app/features/sync/data/models/sync_queue_model.dart';
import 'package:betty_app/features/sync/presentation/providers/sync_provider.dart';

// ── Lightweight cards provider (no Belvo dependency for MVP) ──

class CardItem {
  final String uuid;
  final String name;
  final String? lastFour;
  final String network;
  final double creditLimit;
  final double currentBalance;
  final double availableCredit;
  final int cutOffDay;
  final int paymentDueDay;
  final bool alertsEnabled;

  const CardItem({
    required this.uuid, required this.name, this.lastFour,
    this.network = 'other', this.creditLimit = 0,
    this.currentBalance = 0, this.availableCredit = 0,
    required this.cutOffDay, required this.paymentDueDay,
    this.alertsEnabled = true,
  });
}

class CardsScreenNotifier extends AsyncNotifier<List<CardItem>> {
  @override
  Future<List<CardItem>> build() async => _load();

  Future<List<CardItem>> _load() async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return [];
    final isar = ref.read(isarProvider);
    final models = await isar.creditCardModels
        .filter().userIdEqualTo(auth.user.supabaseId).isActiveEqualTo(true).findAll();
    return models.map((m) => CardItem(
      uuid: m.uuid, name: m.name, lastFour: m.lastFourDigits,
      network: m.network.name, creditLimit: m.creditLimit,
      currentBalance: m.currentBalance, availableCredit: m.availableCredit,
      cutOffDay: m.cutOffDay, paymentDueDay: m.paymentDueDay,
      alertsEnabled: m.alertsEnabled,
    )).toList();
  }

  Future<void> addCard({
    required String name, String? lastFour, String network = 'other',
    double creditLimit = 0, double currentBalance = 0,
    required int cutOffDay, required int paymentDueDay,
  }) async {
    final auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return;
    final now = DateTime.now();
    final uuid = UuidGenerator.generate();
    final model = CreditCardModel()
      ..uuid = uuid ..userId = auth.user.supabaseId ..name = name
      ..lastFourDigits = lastFour ..network = CcNetwork.values.byName(network)
      ..creditLimit = creditLimit ..currentBalance = currentBalance
      ..availableCredit = creditLimit - currentBalance
      ..cutOffDay = cutOffDay ..paymentDueDay = paymentDueDay
      ..nextCutOffDate = BettyDateUtils.nextOccurrence(cutOffDay)
      ..nextPaymentDueDate = BettyDateUtils.nextOccurrence(paymentDueDay)
      ..alertsEnabled = true ..isActive = true
      ..createdAt = now ..updatedAt = now ..syncStatus = CcSyncStatus.pending;

    final isar = ref.read(isarProvider);
    await isar.writeTxn(() => isar.creditCardModels.put(model));
    await ref.read(syncRepositoryProvider).enqueueChange(
      userId: auth.user.supabaseId, targetCollection: 'credit_cards',
      targetUuid: uuid, operation: SyncOperation.create,
      payload: jsonEncode({'uuid': uuid, 'user_id': auth.user.supabaseId,
        'name': name, 'last_four_digits': lastFour, 'network': network,
        'credit_limit': creditLimit, 'current_balance': currentBalance,
        'available_credit': creditLimit - currentBalance,
        'cut_off_day': cutOffDay, 'payment_due_day': paymentDueDay,
        'alerts_enabled': true, 'is_active': true,
        'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String()}),
    );
    state = AsyncData(await _load());
  }

  Future<void> deleteCard(String uuid) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final c = await isar.creditCardModels.filter().uuidEqualTo(uuid).findFirst();
      if (c != null) { c.isActive = false; await isar.creditCardModels.put(c); }
    });
    state = AsyncData(await _load());
  }
}

final cardsScreenProvider = AsyncNotifierProvider<CardsScreenNotifier, List<CardItem>>(CardsScreenNotifier.new);

// ── Screen ──

class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsScreenProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: cardsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (cards) {
            if (cards.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.credit_card_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('Sin tarjetas registradas', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddCardDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar tarjeta'),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cards.length + 1,
              itemBuilder: (ctx, i) {
                if (i == cards.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddCardDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar tarjeta'),
                    ),
                  );
                }
                final c = cards[i];
                return _CardTile(card: c, onDelete: () {
                  ref.read(cardsScreenProvider.notifier).deleteCard(c.uuid);
                });
              },
            );
          },
        ),
      ),
    );
  }

  void _showAddCardDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final lastFourCtrl = TextEditingController();
    final limitCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    final cutOffCtrl = TextEditingController();
    final paymentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nueva tarjeta', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre (ej: BBVA Oro)')),
              const SizedBox(height: 12),
              TextField(controller: lastFourCtrl, decoration: const InputDecoration(labelText: 'Últimos 4 dígitos'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: limitCtrl, decoration: const InputDecoration(labelText: 'Límite', prefixText: r'$ '), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: balanceCtrl, decoration: const InputDecoration(labelText: 'Saldo actual', prefixText: r'$ '), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: cutOffCtrl, decoration: const InputDecoration(labelText: 'Día de corte'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: paymentCtrl, decoration: const InputDecoration(labelText: 'Día de pago'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final cutOff = int.tryParse(cutOffCtrl.text) ?? 1;
                    final payment = int.tryParse(paymentCtrl.text) ?? 15;
                    if (name.isEmpty) return;
                    ref.read(cardsScreenProvider.notifier).addCard(
                      name: name, lastFour: lastFourCtrl.text.isNotEmpty ? lastFourCtrl.text : null,
                      creditLimit: double.tryParse(limitCtrl.text) ?? 0,
                      currentBalance: double.tryParse(balanceCtrl.text) ?? 0,
                      cutOffDay: cutOff.clamp(1, 31), paymentDueDay: payment.clamp(1, 31),
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final CardItem card;
  final VoidCallback onDelete;
  const _CardTile({required this.card, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final utilization = card.creditLimit > 0 ? card.currentBalance / card.creditLimit : 0.0;
    final utilColor = utilization > 0.7 ? Colors.red : utilization > 0.3 ? Colors.orange : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(card.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (card.lastFour != null) ...[const SizedBox(width: 8), Text('•••• ${card.lastFour}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))],
                const Spacer(),
                IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: onDelete),
              ],
            ),
            const SizedBox(height: 12),
            // Utilization bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: utilization.clamp(0.0, 1.0), color: utilColor, backgroundColor: Colors.grey.shade200, minHeight: 6),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Usado: ${CurrencyFormatter.format(card.currentBalance)}', style: theme.textTheme.bodySmall),
                Text('Límite: ${CurrencyFormatter.format(card.creditLimit)}', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Corte: día ${card.cutOffDay}', style: theme.textTheme.bodySmall),
                const SizedBox(width: 16),
                Icon(Icons.payment, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Pago: día ${card.paymentDueDay}', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
