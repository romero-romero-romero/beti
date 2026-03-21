import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:betty_app/features/cards_credits/presentation/providers/cards_credits_provider.dart';

class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key});

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _last4Ctrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _cutOffCtrl = TextEditingController();
  final _paymentCtrl = TextEditingController();

  String _network = 'visa';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _last4Ctrl.dispose();
    _limitCtrl.dispose();
    _balanceCtrl.dispose();
    _cutOffCtrl.dispose();
    _paymentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    await ref.read(creditCardsProvider.notifier).addCard(
          name: _nameCtrl.text.trim(),
          lastFourDigits:
              _last4Ctrl.text.trim().isEmpty ? null : _last4Ctrl.text.trim(),
          network: _network,
          creditLimit: double.parse(_limitCtrl.text.trim()),
          currentBalance: double.parse(_balanceCtrl.text.trim()),
          cutOffDay: int.parse(_cutOffCtrl.text.trim()),
          paymentDueDay: int.parse(_paymentCtrl.text.trim()),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarjeta agregada')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva tarjeta'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Nombre ──
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la tarjeta',
                  hintText: 'Ej: BBVA Oro, Nu, Amex Platinum',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              // ── Últimos 4 dígitos + Red ──
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _last4Ctrl,
                      decoration: const InputDecoration(
                        labelText: 'Últimos 4 dígitos',
                        hintText: '1234',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _network,
                      decoration: const InputDecoration(labelText: 'Red'),
                      items: const [
                        DropdownMenuItem(value: 'visa', child: Text('Visa')),
                        DropdownMenuItem(
                            value: 'mastercard', child: Text('Mastercard')),
                        DropdownMenuItem(value: 'amex', child: Text('Amex')),
                        DropdownMenuItem(value: 'other', child: Text('Otra')),
                      ],
                      onChanged: (v) => setState(() => _network = v ?? 'visa'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Límite de crédito ──
              TextFormField(
                controller: _limitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Límite de crédito',
                  prefixText: r'$ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (double.tryParse(v) == null) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Saldo actual ──
              TextFormField(
                controller: _balanceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Saldo actual (lo que debes)',
                  prefixText: r'$ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (double.tryParse(v) == null) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Fechas de corte y pago ──
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cutOffCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Día de corte',
                        hintText: '1-31',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        final day = int.tryParse(v);
                        if (day == null || day < 1 || day > 31) {
                          return '1-31';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _paymentCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Día de pago',
                        hintText: '1-31',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        final day = int.tryParse(v);
                        if (day == null || day < 1 || day > 31) {
                          return '1-31';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Botón guardar ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Agregar tarjeta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}