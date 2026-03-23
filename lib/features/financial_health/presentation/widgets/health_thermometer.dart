import 'package:flutter/material.dart';
import 'package:betty_app/core/constants/app_colors.dart';
import 'package:betty_app/core/enums/health_level.dart';

/// Termómetro animado de Salud Financiera Emocional.
/// Cambia color, pulso y mensaje según el nivel del usuario.
class HealthThermometer extends StatefulWidget {
  final double score;
  final HealthLevel level;
  final String message;

  const HealthThermometer({
    super.key,
    required this.score,
    required this.level,
    required this.message,
  });

  @override
  State<HealthThermometer> createState() => _HealthThermometerState();
}

class _HealthThermometerState extends State<HealthThermometer>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _scoreController;
  late Animation<double> _breathAnimation;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();

    // Animación de respiración (pulso suave continuo)
    _breathController = AnimationController(
      vsync: this,
      duration: _breathDuration(widget.level),
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    // Animación del score (entrada)
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scoreAnimation = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic),
    );

    _scoreController.forward();
  }

  @override
  void didUpdateWidget(HealthThermometer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _scoreAnimation = Tween<double>(
        begin: oldWidget.score,
        end: widget.score,
      ).animate(CurvedAnimation(
          parent: _scoreController, curve: Curves.easeOutCubic));
      _scoreController
        ..reset()
        ..forward();
    }
    if (oldWidget.level != widget.level) {
      _breathController.duration = _breathDuration(widget.level);
    }
  }

  Duration _breathDuration(HealthLevel level) {
    return switch (level) {
      HealthLevel.peace => const Duration(milliseconds: 3000),
      HealthLevel.stable => const Duration(milliseconds: 2500),
      HealthLevel.warning => const Duration(milliseconds: 1800),
      HealthLevel.danger => const Duration(milliseconds: 1200),
      HealthLevel.crisis => const Duration(milliseconds: 800),
    };
  }

  @override
  void dispose() {
    _breathController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromHealthLevel(widget.level);
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([_breathAnimation, _scoreAnimation]),
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Círculo principal con score ──
            Transform.scale(
              scale: _breathAnimation.value,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.15),
                      color.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.5, 0.8, 1.0],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.1),
                      border: Border.all(color: color, width: 3),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _scoreAnimation.value.toInt().toString(),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            _levelLabel(widget.level),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Barra de progreso ──
            _HealthBar(score: _scoreAnimation.value, color: color),
            const SizedBox(height: 16),

            // ── Mensaje emocional ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                widget.message,
                key: ValueKey(widget.message),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _levelLabel(HealthLevel level) {
    // Si el score es 0, mostrar label neutro (sin datos)
    if (widget.score == 0) return 'INICIO';
    return switch (level) {
      HealthLevel.peace => 'PAZ',
      HealthLevel.stable => 'ESTABLE',
      HealthLevel.warning => 'ALERTA',
      HealthLevel.danger => 'PELIGRO',
      HealthLevel.crisis => 'CRISIS',
    };
  }
}

/// Barra horizontal de salud con gradiente.
class _HealthBar extends StatelessWidget {
  final double score;
  final Color color;

  const _HealthBar({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            // Fondo
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Progreso
            FractionallySizedBox(
              widthFactor: (score / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.7),
                      color,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
