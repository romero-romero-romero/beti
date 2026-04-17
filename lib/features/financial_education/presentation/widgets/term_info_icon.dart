// lib/features/financial_education/presentation/widgets/term_info_icon.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/features/financial_education/data/financial_terms_catalog.dart';
import 'package:betty_app/features/financial_education/presentation/providers/financial_education_provider.dart';
import 'package:betty_app/features/financial_education/presentation/widgets/term_info_bottom_sheet.dart';

/// Ícono discreto "?" que al tocar abre el bottom sheet educativo
/// del término financiero indicado.
///
/// Se renderea atenuado (opacidad menor) si el usuario ya consultó
/// el término antes, pero nunca desaparece — siempre está disponible.
///
/// Si [termKey] no existe en [FinancialTermsCatalog], el widget
/// se renderea vacío para no romper la UI por un typo.
///
/// Uso:
/// ```dart
/// Row(children: [
///   Text('Fecha de corte'),
///   SizedBox(width: 4),
///   TermInfoIcon(termKey: 'cutoff_date'),
/// ])
/// ```
class TermInfoIcon extends ConsumerWidget {
  final String termKey;
  final double size;

  const TermInfoIcon({
    super.key,
    required this.termKey,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final term = FinancialTermsCatalog.byKey(termKey);
    if (term == null) return const SizedBox.shrink();

    final seen = ref.watch(seenTermsProvider).contains(termKey);
    final theme = Theme.of(context);

    final baseColor = theme.colorScheme.onSurface;
    final opacity = seen ? 0.35 : 0.7;

    return InkWell(
      onTap: () => _openSheet(context, ref),
      borderRadius: BorderRadius.circular(size),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          Icons.help_outline,
          size: size,
          color: baseColor.withValues(alpha: opacity),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final term = FinancialTermsCatalog.byKey(termKey);
    if (term == null) return;

    await ref.read(seenTermsProvider.notifier).markAsSeen(termKey);

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TermInfoBottomSheet(term: term),
    );
  }
}