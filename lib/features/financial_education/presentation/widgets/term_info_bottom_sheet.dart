// lib/features/financial_education/presentation/widgets/term_info_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:beti_app/features/financial_education/domain/entities/financial_term.dart';

/// Bottom sheet educativo que muestra un término financiero en tres bloques:
///   1. Qué es (definición simple)
///   2. Por qué importa (impacto concreto al usuario)
///   3. Tip de Beti (consejo accionable empático, opcional)
///
/// Se invoca desde [TermInfoIcon] al tocar el ícono "?".
class TermInfoBottomSheet extends StatelessWidget {
  final FinancialTerm term;

  const TermInfoBottomSheet({super.key, required this.term});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // ── Drag handle ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Contenido scrolleable ──
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    MediaQuery.of(context).padding.bottom + 24,
                  ),
                  children: [
                    // ── Título ──
                    Text(
                      term.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Bloque 1: Qué es ──
                    _SectionBlock(
                      icon: Icons.lightbulb_outline,
                      label: 'Qué es',
                      content: term.whatIs,
                      accentColor: theme.colorScheme.primary,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),

                    // ── Bloque 2: Por qué importa ──
                    _SectionBlock(
                      icon: Icons.trending_up_outlined,
                      label: 'Por qué importa para ti',
                      content: term.whyItMatters,
                      accentColor: Colors.amber.shade700,
                      isDark: isDark,
                    ),

                    // ── Bloque 3: Tip de Beti (opcional) ──
                    if (term.hasTip) ...[
                      const SizedBox(height: 20),
                      _SectionBlock(
                        icon: Icons.favorite_outline,
                        label: 'Tip de Beti',
                        content: term.bettyTip,
                        accentColor: Colors.pinkAccent.shade200,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bloque individual del bottom sheet (ícono + label + contenido).
class _SectionBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String content;
  final Color accentColor;
  final bool isDark;

  const _SectionBlock({
    required this.icon,
    required this.label,
    required this.content,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: accentColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}