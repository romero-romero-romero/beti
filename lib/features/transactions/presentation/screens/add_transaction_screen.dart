import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beti_app/core/enums/category_type.dart';
import 'package:beti_app/core/enums/transaction_type.dart';
import 'package:beti_app/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:beti_app/features/transactions/presentation/widgets/category_picker.dart';
import 'package:beti_app/core/enums/payment_method.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  bool _initializedFromDraft = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si venimos de voz u OCR, poblar los campos con el draft existente
    if (!_initializedFromDraft) {
      final draft = ref.read(transactionFormProvider);
      if (draft.amount > 0) {
        _amountController.text = draft.amount.toStringAsFixed(2);
      }
      if (draft.description.isNotEmpty) {
        _descriptionController.text = draft.description;
      }
      _initializedFromDraft = true;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onDescriptionChanged(String value) {
    ref.read(transactionFormProvider.notifier).updateDescription(value);
  }

  void _onSave() {
    final draft = ref.read(transactionFormProvider);

    if (draft.amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    if (draft.description.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una descripción')),
      );
      return;
    }

    context.pushNamed('preview');
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(transactionFormProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar movimiento'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(transactionFormProvider.notifier).reset();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Métodos de captura rápida ──
            Row(
              children: [
                Expanded(
                  child: _CaptureButton(
                    icon: Icons.mic_rounded,
                    label: 'Voz',
                    color: Colors.indigo,
                    onTap: () {
                      ref.read(transactionFormProvider.notifier).reset();
                      context.pushNamed('voiceCapture');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CaptureButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Ticket',
                    color: Colors.teal,
                    onTap: () {
                      ref.read(transactionFormProvider.notifier).reset();
                      context.pushNamed('ocrCapture');
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Center(
              child: Text(
                'o ingresa manualmente',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),

            // ── Tipo: Ingreso / Gasto ──
            Row(
              children: [
                Expanded(
                  child: _TypeChip(
                    label: 'Gasto',
                    icon: Icons.arrow_downward_rounded,
                    selected: draft.type == TransactionType.expense,
                    color: Colors.red,
                    onTap: () => ref
                        .read(transactionFormProvider.notifier)
                        .updateType(TransactionType.expense),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeChip(
                    label: 'Ingreso',
                    icon: Icons.arrow_upward_rounded,
                    selected: draft.type == TransactionType.income,
                    color: Colors.green,
                    onTap: () => ref
                        .read(transactionFormProvider.notifier)
                        .updateType(TransactionType.income),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Monto ──
            Text('Monto', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                prefixText: r'$ ',
                hintText: '0.00',
              ),
              onChanged: (value) {
                final amount = double.tryParse(value) ?? 0;
                ref.read(transactionFormProvider.notifier).updateAmount(amount);
              },
            ),
            const SizedBox(height: 20),

            // ── Descripción ──
            Text('Descripción', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ej: Uber al trabajo, Nómina quincenal...',
              ),
              onChanged: _onDescriptionChanged,
            ),
            const SizedBox(height: 4),

            // ── Categoría auto-detectada ──
            if (draft.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      draft.categoryAutoAssigned
                          ? Icons.auto_awesome
                          : Icons.category_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      draft.categoryAutoAssigned
                          ? 'Auto: ${_categoryLabel(draft.category)}'
                          : _categoryLabel(draft.category),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _showCategoryPicker(context),
                      child: const Text('Cambiar'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // ── Fecha ──
            Text('Fecha', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: draft.transactionDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  ref
                      .read(transactionFormProvider.notifier)
                      .updateDate(picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  '${draft.transactionDate.day}/${draft.transactionDate.month}/${draft.transactionDate.year}',
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Método de pago ──
            Text('Método de pago', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: PaymentMethod.values
                  .where((m) => m != PaymentMethod.other)
                  .map((method) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _PaymentChip(
                            method: method,
                            selected: draft.paymentMethod == method,
                            onTap: () => ref
                                .read(transactionFormProvider.notifier)
                                .updatePaymentMethod(method),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // ── Notas ──
            Text('Notas (opcional)', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Detalles adicionales...',
              ),
              onChanged: (value) =>
                  ref.read(transactionFormProvider.notifier).updateNotes(value),
            ),
            const SizedBox(height: 32),

            // ── Botón de continuar ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _onSave,
                child: const Text('Revisar y guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryPicker(
        currentCategory: ref.read(transactionFormProvider).category,
        isIncome:
            ref.read(transactionFormProvider).type == TransactionType.income,
        onSelected: (category) {
          ref.read(transactionFormProvider.notifier).updateCategory(category);
          Navigator.pop(context);
        },
      ),
    );
  }

  String _categoryLabel(CategoryType cat) {
    return switch (cat) {
      CategoryType.food => 'Alimentación',
      CategoryType.transport => 'Transporte',
      CategoryType.housing => 'Vivienda',
      CategoryType.utilities => 'Servicios',
      CategoryType.health => 'Salud',
      CategoryType.education => 'Educación',
      CategoryType.entertainment => 'Entretenimiento',
      CategoryType.clothing => 'Ropa',
      CategoryType.subscriptions => 'Suscripciones',
      CategoryType.debtPayment => 'Pago de deudas',
      CategoryType.groceries => 'Supermercado',
      CategoryType.personalCare => 'Cuidado personal',
      CategoryType.gifts => 'Regalos',
      CategoryType.pets => 'Mascotas',
      CategoryType.salary => 'Nómina',
      CategoryType.freelance => 'Freelance',
      CategoryType.investment => 'Inversión',
      CategoryType.refund => 'Reembolso',
      CategoryType.otherIncome => 'Otro ingreso',
      CategoryType.other => 'Sin categoría',
    };
  }
}

class _CaptureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CaptureButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.grey,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentChip({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : Colors.grey;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(_iconFor(method), size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              _labelFor(method),
              style: TextStyle(fontSize: 10, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => Icons.money_rounded,
        PaymentMethod.debitCard => Icons.credit_card_outlined,
        PaymentMethod.creditCard => Icons.credit_card,
        PaymentMethod.transfer => Icons.swap_horiz_rounded,
        PaymentMethod.other => Icons.more_horiz,
      };

  String _labelFor(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'Efectivo',
        PaymentMethod.debitCard => 'Débito',
        PaymentMethod.creditCard => 'Crédito',
        PaymentMethod.transfer => 'Transfer.',
        PaymentMethod.other => 'Otro',
      };
}