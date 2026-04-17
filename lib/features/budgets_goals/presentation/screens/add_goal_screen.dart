import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beti_app/core/constants/app_colors.dart';
import 'package:beti_app/core/utils/platform_helper.dart';
import 'package:beti_app/features/budgets_goals/presentation/providers/budgets_goals_provider.dart';

class AddGoalScreen extends ConsumerStatefulWidget {
  const AddGoalScreen({super.key});

  @override
  ConsumerState<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends ConsumerState<AddGoalScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _deadline;

  static const _iconOptions = [
    {'icon': Icons.home, 'label': 'Casa', 'key': 'home'},
    {'icon': Icons.directions_car, 'label': 'Auto', 'key': 'car'},
    {'icon': Icons.flight, 'label': 'Viaje', 'key': 'travel'},
    {'icon': Icons.school, 'label': 'Educación', 'key': 'education'},
    {'icon': Icons.phone_android, 'label': 'Tech', 'key': 'tech'},
    {'icon': Icons.savings, 'label': 'Emergencia', 'key': 'emergency'},
    {'icon': Icons.favorite, 'label': 'Salud', 'key': 'health'},
    {'icon': Icons.card_giftcard, 'label': 'Otro', 'key': 'other'},
  ];

  String _selectedIcon = 'other';

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    if (PlatformHelper.isApple) {
      await showCupertinoModalPopup(
        context: context,
        builder: (_) => Container(
          height: 260,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            minimumDate: now,
            maximumDate: DateTime(now.year + 30),
            onDateTimeChanged: (date) => setState(() => _deadline = date),
          ),
        ),
      );
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: _deadline ?? DateTime(now.year + 1, now.month, now.day),
        firstDate: now,
        lastDate: DateTime(now.year + 30),
      );
      if (picked != null) setState(() => _deadline = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre para tu meta')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    await ref.read(goalsProvider.notifier).addGoal(
          name: name,
          targetAmount: amount,
          deadline: _deadline,
          icon: _selectedIcon,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meta creada'),
          backgroundColor: AppColors.primary,
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva meta'),
        leading: IconButton(
          icon: Icon(PlatformHelper.isApple ? CupertinoIcons.back : Icons.arrow_back),
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
            // ── Nombre ──
            _SectionLabel('Nombre de la meta', isDark: isDark),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Ej: Fondo de emergencia',
                filled: true,
                fillColor: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Icono ──
            _SectionLabel('Icono', isDark: isDark),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _iconOptions.map((opt) {
                final key = opt['key'] as String;
                final selected = key == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = key),
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: AppColors.primary, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(opt['icon'] as IconData, size: 20,
                            color: selected ? AppColors.primary : (isDark ? AppColors.grey : Colors.grey)),
                        Text(opt['label'] as String,
                            style: TextStyle(fontSize: 8,
                                color: selected ? AppColors.primary : (isDark ? AppColors.grey : Colors.grey))),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Monto ──
            _SectionLabel('Monto objetivo', isDark: isDark),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '0.00',
                filled: true,
                fillColor: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Se ajustará automáticamente por inflación (~4.5% anual)',
              style: TextStyle(fontSize: 11,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 20),

            // ── Fecha límite ──
            _SectionLabel('Fecha límite (opcional)', isDark: isDark),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDeadline,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18,
                        color: isDark ? AppColors.grey : Colors.grey),
                    const SizedBox(width: 10),
                    Text(
                      _deadline != null
                          ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}'
                          : 'Sin fecha límite',
                      style: TextStyle(fontSize: 15,
                          color: _deadline != null
                              ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                              : (isDark ? AppColors.grey : Colors.grey)),
                    ),
                    const Spacer(),
                    if (_deadline != null)
                      GestureDetector(
                        onTap: () => setState(() => _deadline = null),
                        child: Icon(Icons.close, size: 16,
                            color: isDark ? AppColors.grey : Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Guardar ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Crear meta', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight));
  }
}