import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:betty_app/features/cards_credits/presentation/providers/cards_credits_provider.dart';
import 'package:betty_app/features/financial_education/presentation/widgets/term_info_icon.dart';
import 'package:betty_app/features/cards_credits/data/credit_card_catalog.dart';

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
  final _rateCtrl = TextEditingController();

  String _network = 'visa';
  bool _saving = false;
  List<CatalogCard> _suggestions = [];
  bool _rateLocked = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _last4Ctrl.dispose();
    _limitCtrl.dispose();
    _balanceCtrl.dispose();
    _cutOffCtrl.dispose();
    _paymentCtrl.dispose();
    _rateCtrl.dispose();
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
          annualRate: _rateCtrl.text.trim().isNotEmpty
              ? double.parse(_rateCtrl.text.trim()) / 100
              : null,
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
              // ── Buscar tarjeta ──
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la tarjeta',
                  hintText: 'Busca tu banco o tarjeta...',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: (v) {
                  setState(() {
                    _suggestions = CreditCardCatalog.search(v);
                    if (_suggestions.isNotEmpty) _rateLocked = false;
                  });
                },
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (_, i) {
                      final card = _suggestions[i];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(card.displayLabel,
                            style: const TextStyle(fontSize: 13)),
                        trailing: Text('${card.catPercent}%',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600)),
                        onTap: () {
                          _nameCtrl.text = card.displayLabel;
                          _rateCtrl.text = card.catPercent.toString();
                          setState(() {
                            _suggestions = [];
                            _rateLocked = true;
                          });
                        },
                      );
                    },
                  ),
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
              const Row(
                children: [
                  TermInfoIcon(termKey: 'available_credit'),
                  SizedBox(width: 4),
                  Text(
                      'El límite es lo que el banco te presta, no lo que tienes',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 4),
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

              // ── Tasa de interés anual ──
              Row(
                children: [
                  Text('Tasa de interés anual (opcional)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                  const SizedBox(width: 4),
                  const TermInfoIcon(termKey: 'cat_rate'),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _rateCtrl,
                enabled: !_rateLocked,
                decoration: InputDecoration(
                  labelText: 'CAT o tasa anual',
                  suffixText: '%',
                  hintText: 'Ej: 57',
                  suffixIcon: _rateLocked
                      ? IconButton(
                          icon: const Icon(Icons.lock_outline, size: 18),
                          onPressed: () => setState(() => _rateLocked = false),
                          tooltip: 'Desbloquear para editar',
                        )
                      : null,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
              ),
              const SizedBox(height: 16),

              // ── Fechas de corte y pago ──
              Row(
                children: [
                  const TermInfoIcon(termKey: 'cutoff_date'),
                  const SizedBox(width: 4),
                  Text('Día de corte',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(width: 16),
                  const TermInfoIcon(termKey: 'payment_due_date'),
                  const SizedBox(width: 4),
                  Text('Día de pago',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 4),
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
