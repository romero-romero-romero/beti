import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:betty_app/core/enums/category_type.dart';
import 'package:betty_app/core/enums/transaction_type.dart';
import 'package:betty_app/core/utils/currency_formatter.dart';
import 'package:betty_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:betty_app/features/intelligence/presentation/providers/category_learning_provider.dart';
import 'package:betty_app/features/transactions/presentation/providers/transactions_provider.dart';

/// Pantalla de Vista Previa obligatoria.
/// El usuario DEBE confirmar los datos antes de guardar.
/// Aquí puede corregir categoría, monto, tipo, etc.
class PreviewCorrectionScreen extends ConsumerStatefulWidget {
  const PreviewCorrectionScreen({super.key});

  @override
  ConsumerState<PreviewCorrectionScreen> createState() =>
      _PreviewCorrectionScreenState();
}

class _PreviewCorrectionScreenState
    extends ConsumerState<PreviewCorrectionScreen> {
  bool _saving = false;
  CategoryType? _originalCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draft = ref.read(transactionFormProvider);
      _originalCategory = draft.category;
    });
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);

    try {
      final authState = ref.read(authProvider);
      final userId = authState is AuthAuthenticated
          ? authState.user.supabaseId
          : '';

      // Feedback loop: si el usuario corrigió la categoría, aprender
      final currentDraft = ref.read(transactionFormProvider);
      if (_originalCategory != null &&
          _originalCategory != currentDraft.category) {
        await learnCategoryCorrection(
          ref,
          description: currentDraft.description,
          originalCategory: _originalCategory!,
          correctedCategory: currentDraft.category,
        );
      }

      final entity = ref
          .read(transactionFormProvider.notifier)
          .toEntity(userId);

      await ref.read(transactionsProvider.notifier).save(entity);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Movimiento guardado'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(transactionFormProvider);
    final theme = Theme.of(context);
    final isExpense = draft.type == TransactionType.expense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirma los datos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Tipo ──
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: (isExpense ? Colors.red : Colors.green)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isExpense ? 'GASTO' : 'INGRESO',
                            style: TextStyle(
                              color: isExpense ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Monto ──
                      Center(
                        child: Text(
                          CurrencyFormatter.format(draft.amount),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isExpense ? Colors.red : Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Divider(),
                      const SizedBox(height: 16),

                      // ── Descripción ──
                      _DetailRow(
                        icon: Icons.description_outlined,
                        label: 'Descripción',
                        value: draft.description,
                      ),
                      const SizedBox(height: 16),

                      // ── Categoría ──
                      _DetailRow(
                        icon: draft.categoryAutoAssigned
                            ? Icons.auto_awesome
                            : Icons.category_outlined,
                        label: 'Categoría',
                        value: _categoryLabel(draft.category),
                        trailing: draft.categoryAutoAssigned
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'auto',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Fecha ──
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Fecha',
                        value:
                            '${draft.transactionDate.day}/${draft.transactionDate.month}/${draft.transactionDate.year}',
                      ),

                      // ── Notas ──
                      if (draft.notes != null && draft.notes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DetailRow(
                          icon: Icons.notes_outlined,
                          label: 'Notas',
                          value: draft.notes!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Botones ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => context.pop(),
                    child: const Text('Corregir'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _confirm,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar y guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}