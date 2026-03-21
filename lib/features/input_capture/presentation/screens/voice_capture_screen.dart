import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:betty_app/core/enums/input_method.dart';
import 'package:betty_app/features/input_capture/presentation/providers/input_capture_provider.dart';
import 'package:betty_app/features/intelligence/data/datasources/nlp_entity_extractor.dart';
import 'package:betty_app/features/transactions/presentation/providers/transactions_provider.dart';

/// Pantalla de captura por voz.
/// El usuario dicta el gasto y el sistema lo transcribe localmente.
/// Luego navega a la Vista Previa para confirmar/corregir.
class VoiceCaptureScreen extends ConsumerStatefulWidget {
  const VoiceCaptureScreen({super.key});

  @override
  ConsumerState<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

class _VoiceCaptureScreenState extends ConsumerState<VoiceCaptureScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    ref.read(speechProvider.notifier).cancel();
    super.dispose();
  }

  void _toggleListening() {
    final speech = ref.read(speechProvider);
    if (speech.status == SpeechStatus.listening) {
      ref.read(speechProvider.notifier).stopListening();
      _pulseController.stop();
    } else {
      ref.read(speechProvider.notifier).startListening();
      _pulseController.repeat(reverse: true);
    }
  }

  void _processResult(String text) {
    if (text.trim().isEmpty) return;

    // Extraer entidades con el NLP centralizado
    final result = NlpEntityExtractor.extract(text);

    final formNotifier = ref.read(transactionFormProvider.notifier);
    formNotifier.reset();

    if (result.amount != null) {
      formNotifier.updateAmount(result.amount!);
    }

    formNotifier.updateType(result.type);
    formNotifier.updateDescription(result.description);

    if (result.categoryAutoAssigned) {
      formNotifier.updateCategory(result.category);
    }

    if (result.date != null) {
      formNotifier.updateDate(result.date!);
    }

    // Marcar como input por voz
    ref.read(transactionFormProvider.notifier).updateInputMethod(InputMethod.voice);

    // Guardar texto crudo para referencia
    ref.read(transactionFormProvider.notifier).updateRawInput(text);

    // Navegar a Vista Previa
    context.goNamed('addTransaction');
  }

  @override
  Widget build(BuildContext context) {
    final speech = ref.watch(speechProvider);
    final theme = Theme.of(context);
    final isListening = speech.status == SpeechStatus.listening;

    // Cuando el resultado final llega, procesar
    ref.listen<SpeechState>(speechProvider, (prev, next) {
      if (next.status == SpeechStatus.processing && next.finalText.isNotEmpty) {
        _processResult(next.finalText);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictar movimiento'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(speechProvider.notifier).cancel();
            context.pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),

            // ── Instrucciones ──
            if (speech.status == SpeechStatus.idle)
              Column(
                children: [
                  Icon(
                    Icons.mic_none_rounded,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Toca el micrófono y dicta tu gasto',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ejemplo: "Compré quinientos pesos de tacos"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

            // ── Texto en tiempo real ──
            if (isListening || speech.status == SpeechStatus.processing)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    if (isListening)
                      Text(
                        'Escuchando...',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      speech.partialText.isNotEmpty
                          ? speech.partialText
                          : '...',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            // ── Error ──
            if (speech.status == SpeechStatus.error)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        speech.error ?? 'Error desconocido',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // ── Botón de micrófono ──
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = isListening
                    ? 1.0 + (_pulseController.value * 0.15)
                    : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isListening
                        ? Colors.red
                        : theme.colorScheme.primary,
                    boxShadow: [
                      if (isListening)
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                    ],
                  ),
                  child: Icon(
                    isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isListening ? 'Toca para detener' : 'Toca para dictar',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}