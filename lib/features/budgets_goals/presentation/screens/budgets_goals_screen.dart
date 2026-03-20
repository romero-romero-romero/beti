import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/core/enums/category_type.dart';
import 'package:betty_app/core/utils/currency_formatter.dart';
import 'package:betty_app/features/budgets_goals/presentation/providers/budgets_goals_provider.dart';

class BudgetsGoalsScreen extends ConsumerWidget {
  const BudgetsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text('Presupuestos y Metas', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const TabBar(tabs: [Tab(text: 'Presupuestos'), Tab(text: 'Metas')]),
              Expanded(
                child: TabBarView(
                  children: [_BudgetsTab(), _GoalsTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    return budgetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (budgets) {
        return Column(
          children: [
            Expanded(
              child: budgets.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Sin presupuestos este mes', style: TextStyle(color: Colors.grey.shade500)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: budgets.length,
                      itemBuilder: (ctx, i) {
                        final b = budgets[i];
                        final progress = b.budgetedAmount > 0 ? (b.spentAmount / b.budgetedAmount).clamp(0.0, 1.5) : 0.0;
                        final color = progress > 1.0 ? Colors.red : progress > 0.8 ? Colors.orange : Colors.green;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(_categoryLabel(b.categoryKey), style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text('${CurrencyFormatter.format(b.spentAmount)} / ${CurrencyFormatter.format(b.budgetedAmount)}', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
                              ]),
                              const SizedBox(height: 8),
                              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), color: color, backgroundColor: Colors.grey.shade200, minHeight: 6)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () => _showAddBudgetDialog(context, ref),
                icon: const Icon(Icons.add), label: const Text('Agregar presupuesto'),
              )),
            ),
          ],
        );
      },
    );
  }

  void _showAddBudgetDialog(BuildContext ctx, WidgetRef ref) {
    final amountCtrl = TextEditingController();
    String selectedCategory = 'food';

    showModalBottomSheet(context: ctx, isScrollControlled: true, builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Nuevo presupuesto', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedCategory,
          decoration: const InputDecoration(labelText: 'Categoría'),
          items: CategoryType.values.where((c) => c.index < 14).map((c) => DropdownMenuItem(value: c.name, child: Text(_categoryLabel(c.name)))).toList(),
          onChanged: (v) => selectedCategory = v ?? 'food',
        ),
        const SizedBox(height: 12),
        TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Monto mensual', prefixText: r'$ '), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {
            final amount = double.tryParse(amountCtrl.text) ?? 0;
            if (amount <= 0) return;
            ref.read(budgetsProvider.notifier).addBudget(categoryKey: selectedCategory, amount: amount);
            Navigator.pop(c);
          },
          child: const Text('Guardar'),
        )),
      ]),
    ));
  }
}

class _GoalsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    return goalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (goals) {
        return Column(
          children: [
            Expanded(
              child: goals.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.flag_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Sin metas activas', style: TextStyle(color: Colors.grey.shade500)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: goals.length,
                      itemBuilder: (ctx, i) {
                        final g = goals[i];
                        final color = g.isCompleted ? Colors.green : Colors.blue;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(g.icon ?? '🎯', style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${CurrencyFormatter.format(g.savedAmount)} / ${CurrencyFormatter.format(g.targetAmount)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                ])),
                                if (!g.isCompleted) IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _showAddSavingsDialog(ctx, ref, g.uuid)),
                              ]),
                              const SizedBox(height: 8),
                              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: g.progress.clamp(0.0, 1.0), color: color, backgroundColor: Colors.grey.shade200, minHeight: 6)),
                              if (g.isCompleted) Padding(padding: const EdgeInsets.only(top: 8), child: Text('¡Meta alcanzada! 🎉', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600))),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () => _showAddGoalDialog(context, ref),
                icon: const Icon(Icons.add), label: const Text('Nueva meta'),
              )),
            ),
          ],
        );
      },
    );
  }

  void _showAddGoalDialog(BuildContext ctx, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    showModalBottomSheet(context: ctx, isScrollControlled: true, builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Nueva meta', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre (ej: Viaje a Europa)'), textCapitalization: TextCapitalization.sentences),
        const SizedBox(height: 12),
        TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Monto objetivo', prefixText: r'$ '), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            final amount = double.tryParse(amountCtrl.text) ?? 0;
            if (name.isEmpty || amount <= 0) return;
            ref.read(goalsProvider.notifier).addGoal(name: name, targetAmount: amount);
            Navigator.pop(c);
          },
          child: const Text('Crear meta'),
        )),
      ]),
    ));
  }

  void _showAddSavingsDialog(BuildContext ctx, WidgetRef ref, String goalUuid) {
    final ctrl = TextEditingController();
    showDialog(context: ctx, builder: (c) => AlertDialog(
      title: const Text('Abonar a meta'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Monto', prefixText: r'$ '), keyboardType: const TextInputType.numberWithOptions(decimal: true), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () {
          final amount = double.tryParse(ctrl.text) ?? 0;
          if (amount > 0) { ref.read(goalsProvider.notifier).addSavings(goalUuid, amount); Navigator.pop(c); }
        }, child: const Text('Abonar')),
      ],
    ));
  }
}

String _categoryLabel(String key) {
  return switch (key) {
    'food' => 'Alimentación', 'transport' => 'Transporte', 'housing' => 'Vivienda',
    'utilities' => 'Servicios', 'health' => 'Salud', 'education' => 'Educación',
    'entertainment' => 'Entretenimiento', 'clothing' => 'Ropa',
    'subscriptions' => 'Suscripciones', 'debtPayment' => 'Pago de deudas',
    'groceries' => 'Supermercado', 'personalCare' => 'Cuidado personal',
    'gifts' => 'Regalos', 'pets' => 'Mascotas', _ => key,
  };
}
