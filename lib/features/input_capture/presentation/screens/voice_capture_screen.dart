import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beti_app/core/constants/app_colors.dart';
import 'package:beti_app/core/enums/input_method.dart';
import 'package:beti_app/features/input_capture/presentation/providers/input_capture_provider.dart';
import 'package:beti_app/features/intelligence/data/datasources/nlp_entity_extractor.dart';
import 'package:beti_app/features/transactions/presentation/providers/transactions_provider.dart';

class VoiceCaptureScreen extends ConsumerStatefulWidget {
  const VoiceCaptureScreen({super.key});

  @override
  ConsumerState<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

class _VoiceCaptureScreenState extends ConsumerState<VoiceCaptureScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(speechProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _fadeController.dispose();
    ref.read(speechProvider.notifier).cancel();
    super.dispose();
  }

  void _toggleListening() {
    final speech = ref.read(speechProvider);
    if (speech.status == SpeechStatus.listening) {
      ref.read(speechProvider.notifier).stopListening();
      _pulseController.stop();
      _waveController.stop();
    } else {
      ref.read(speechProvider.notifier).startListening();
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    }
  }

  void _processResult(String text) {
    if (text.trim().isEmpty) return;

    final result = NlpEntityExtractor.extract(text);
    final formNotifier = ref.read(transactionFormProvider.notifier);
    formNotifier.reset();

    if (result.amount != null) formNotifier.updateAmount(result.amount!);
    formNotifier.updateType(result.type);
    formNotifier.updateDescription(result.description);
    if (result.categoryAutoAssigned) {
      formNotifier.updateCategory(result.category);
    }
    if (result.date != null) formNotifier.updateDate(result.date!);
    formNotifier.updateInputMethod(InputMethod.voice);
    formNotifier.updateRawInput(text);
    if (result.paymentMethod != null) {
      formNotifier.updatePaymentMethod(result.paymentMethod);
    }

    context.goNamed('addTransaction');
  }

  @override
  Widget build(BuildContext context) {
    final speech = ref.watch(speechProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isListening = speech.status == SpeechStatus.listening;
    final isProcessing = speech.status == SpeechStatus.processing;
    final hasText = speech.partialText.isNotEmpty;

    ref.listen<SpeechState>(speechProvider, (prev, next) {
      if (next.status == SpeechStatus.processing && next.finalText.isNotEmpty) {
        _processResult(next.finalText);
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close,
                          color:
                              isDark ? AppColors.grey : Colors.grey.shade600),
                      onPressed: () {
                        ref.read(speechProvider.notifier).cancel();
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                    ),
                    const Spacer(),
                    Text(
                      'Registro por voz',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // Balance para centrar el título
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Zona de transcripción ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _buildTranscriptionArea(
                    speech,
                    theme,
                    isDark,
                    isListening,
                    isProcessing,
                    hasText,
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // ── Ondas de audio animadas ──
              if (isListening)
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) => _buildWaveIndicator(isDark),
                ),
              if (!isListening) const SizedBox(height: 32),

              const SizedBox(height: 16),

              // ── Botón de micrófono ──
              _buildMicButton(theme, isDark, isListening),

              const SizedBox(height: 16),

              // ── Label del botón ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  isListening
                      ? 'Escuchando... toca para detener'
                      : 'Toca para dictar',
                  key: ValueKey(isListening),
                  style: TextStyle(
                    fontSize: 13,
                    color: isListening
                        ? (isDark ? Colors.red.shade300 : Colors.red.shade400)
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Sugerencias ──
              if (speech.status == SpeechStatus.idle)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      _SuggestionChip(
                        text: '"Gasté doscientos pesos en el súper"',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 6),
                      _SuggestionChip(
                        text: '"Me depositaron la quincena, quince mil"',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 6),
                      _SuggestionChip(
                        text: '"Pagué el recibo de luz, ochocientos pesos"',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),

              // ── Error ──
              if (speech.status == SpeechStatus.error)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.red.shade900.withValues(alpha: 0.3)
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 20,
                            color: isDark ? Colors.red.shade300 : Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            speech.error ?? 'Error desconocido',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.red.shade300
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  // ── Área de transcripción ──

  Widget _buildTranscriptionArea(
    SpeechState speech,
    ThemeData theme,
    bool isDark,
    bool isListening,
    bool isProcessing,
    bool hasText,
  ) {
    if (speech.status == SpeechStatus.idle) {
      return Column(
        key: const ValueKey('idle'),
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isDark ? AppColors.primary : AppColors.primary)
                  .withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.mic_none_rounded,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Dicta tu movimiento',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Beti entiende montos, categorías\ny fechas automáticamente',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    // Escuchando o procesando
    return Container(
      key: const ValueKey('listening'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isListening
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          if (isListening)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Escuchando',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.red.shade300 : Colors.red.shade400,
                  ),
                ),
              ],
            ),
          if (isProcessing)
            Text(
              'Procesando...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          const SizedBox(height: 16),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: hasText ? 22 : 18,
              fontWeight: hasText ? FontWeight.w500 : FontWeight.w400,
              color: hasText
                  ? (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight)
                  : (isDark ? AppColors.grey : Colors.grey),
            ),
            child: Text(
              hasText ? speech.partialText : 'Di algo...',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ── Ondas de audio ──

  Widget _buildWaveIndicator(bool isDark) {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(7, (i) {
          final delay = i * 0.12;
          final t = (_waveController.value + delay) % 1.0;
          final height = 8.0 + (24.0 * _waveCurve(t));
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: 0.4 + (0.6 * _waveCurve(t)),
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  double _waveCurve(double t) {
    // Simula una onda suave tipo sin
    return (1 + _sin(t * 2 * 3.14159)) / 2;
  }

  /// Aproximación de sin(x) sin importar dart:math
  double _sin(double x) {
    // Normalizar x a [-pi, pi]
    while (x > 3.14159) {
      x -= 6.28318;
    }
    while (x < -3.14159) {
      x += 6.28318;
    }
    // Taylor series: sin(x) ≈ x - x³/6 + x⁵/120
    final x3 = x * x * x;
    final x5 = x3 * x * x;
    return x - (x3 / 6) + (x5 / 120);
  }

  // ── Botón de micrófono ──

  Widget _buildMicButton(ThemeData theme, bool isDark, bool isListening) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = isListening ? 1.0 + (_pulseController.value * 0.1) : 1.0;
        final ringAlpha =
            isListening ? (0.15 + _pulseController.value * 0.15) : 0.0;

        return Column(
          children: [
            // Anillo exterior animado
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isListening ? Colors.red : AppColors.primary)
                    .withValues(alpha: ringAlpha),
              ),
              child: Center(
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      child: GestureDetector(
        onTap: _toggleListening,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isListening ? Colors.red : AppColors.primary,
          ),
          child: Icon(
            isListening ? Icons.stop_rounded : Icons.mic_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
      ),
    );
  }
}

// ── Chip de sugerencia ──

class _SuggestionChip extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SuggestionChip({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}
