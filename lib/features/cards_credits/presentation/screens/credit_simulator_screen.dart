// lib/features/cards_credits/presentation/screens/credit_simulator_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:betty_app/core/constants/app_colors.dart';
import 'package:betty_app/core/utils/currency_formatter.dart';
import 'package:betty_app/core/utils/platform_helper.dart';
import 'package:betty_app/features/cards_credits/data/services/credit_simulator_service.dart';
import 'package:betty_app/features/financial_education/presentation/widgets/term_info_icon.dart';
import 'package:go_router/go_router.dart';

class CreditSimulatorScreen extends StatefulWidget {
  const CreditSimulatorScreen({super.key});

  @override
  State<CreditSimulatorScreen> createState() => _CreditSimulatorScreenState();
}

class _CreditSimulatorScreenState extends State<CreditSimulatorScreen> {
  final _debtCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _paymentCtrl = TextEditingController();
  final _extraCtrl = TextEditingController(text: '500');

  SimulationComparison? _comparison;
  String? _error;

  @override
  void dispose() {
    _debtCtrl.dispose();
    _rateCtrl.dispose();
    _paymentCtrl.dispose();
    _extraCtrl.dispose();
    super.dispose();
  }

  void _simulate() {
    FocusScope.of(context).unfocus();

    final debt = double.tryParse(_debtCtrl.text.replaceAll(',', ''));
    final rateRaw = double.tryParse(_rateCtrl.text.replaceAll(',', ''));
    final payment = double.tryParse(_paymentCtrl.text.replaceAll(',', ''));
    final extra = double.tryParse(_extraCtrl.text.replaceAll(',', '')) ?? 500;

    if (debt == null || debt <= 0) {
      setState(() => _error = 'Ingresa el monto de tu deuda');
      return;
    }
    if (rateRaw == null || rateRaw <= 0) {
      setState(() => _error = 'Ingresa la tasa de interés anual');
      return;
    }
    if (payment == null || payment <= 0) {
      setState(() => _error = 'Ingresa tu pago mensual');
      return;
    }

    final annualRate = rateRaw / 100;

    final comparison = CreditSimulatorService.compare(
      debt: debt,
      annualRate: annualRate,
      monthlyPayment: payment,
      extraPayment: extra,
    );

    if (comparison == null) {
      setState(() {
        _error = 'Tu pago mensual no alcanza a cubrir los intereses. '
            'Necesitas pagar más para que la deuda baje.';
        _comparison = null;
      });
      return;
    }

    setState(() {
      _comparison = comparison;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador de deuda'),
        leading: IconButton(
          icon: Icon(
            PlatformHelper.isApple ? CupertinoIcons.back : Icons.arrow_back,
          ),
          onPressed: () {
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
            Text(
              'Descubre cuánto te cuesta realmente tu deuda',
              style: TextStyle(fontSize: 14, color: secondaryColor),
            ),
            const SizedBox(height: 20),

            // ── Deuda actual ──
            Row(
              children: [
                Text('Deuda actual',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor)),
                const SizedBox(width: 4),
                const TermInfoIcon(termKey: 'principal_vs_interest'),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _debtCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: const InputDecoration(
                prefixText: r'$ ',
                hintText: '15000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Tasa anual ──
            Row(
              children: [
                Text('Tasa de interés anual',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor)),
                const SizedBox(width: 4),
                const TermInfoIcon(termKey: 'cat_rate'),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _rateCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: const InputDecoration(
                suffixText: '%',
                hintText: '60',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Pago mensual ──
            Row(
              children: [
                Text('Pago mensual',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor)),
                const SizedBox(width: 4),
                const TermInfoIcon(termKey: 'minimum_payment'),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _paymentCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: const InputDecoration(
                prefixText: r'$ ',
                hintText: '1500',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // ── Botón simular ──
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _simulate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Simular'),
              ),
            ),

            // ── Error ──
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],

            // ── Resultados ──
            if (_comparison != null) ...[
              const SizedBox(height: 24),
              _ResultCard(
                title: 'Con tu pago actual',
                result: _comparison!.current,
                isDark: isDark,
                color: AppColors.expense,
              ),
              const SizedBox(height: 16),

              // ── Pago extra ──
              Row(
                children: [
                  Text('¿Y si pagas más?',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: secondaryColor)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text(r'$ ', style: TextStyle(fontSize: 14)),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _extraCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      decoration: const InputDecoration(
                        hintText: '500',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('extra al mes', style: TextStyle(color: secondaryColor)),
                  const Spacer(),
                  TextButton(
                    onPressed: _simulate,
                    child: const Text('Recalcular'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ResultCard(
                title: 'Pagando ${CurrencyFormatter.format(_comparison!.accelerated.monthlyPayment)}/mes',
                result: _comparison!.accelerated,
                isDark: isDark,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),

              // ── Resumen de ahorro ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pagando ${CurrencyFormatter.format(_comparison!.accelerated.monthlyPayment - _comparison!.current.monthlyPayment)} más al mes:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Terminas ${_comparison!.monthsSaved} meses antes',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ahorras ${CurrencyFormatter.format(_comparison!.interestSaved)} en intereses',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final SimulationResult result;
  final bool isDark;
  final Color color;

  const _ResultCard({
    required this.title,
    required this.result,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight)),
          const SizedBox(height: 12),
          _Row(label: 'Tiempo para liquidar', value: result.timeLabel),
          const SizedBox(height: 6),
          _Row(
              label: 'Total a pagar',
              value: CurrencyFormatter.format(result.totalPaid)),
          const SizedBox(height: 6),
          _Row(
              label: 'Solo en intereses',
              value: CurrencyFormatter.format(result.totalInterest),
              valueColor: Colors.red.shade400),
          const SizedBox(height: 6),
          _Row(
              label: 'Intereses como % del total',
              value: '${result.interestPercent.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Row({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor)),
      ],
    );
  }
}