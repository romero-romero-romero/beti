import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:betty_app/features/input_capture/presentation/providers/input_capture_provider.dart';
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

    // Parsear el texto dictado y poblar el formulario
    final parsed = _parseVoiceInput(text);

    final formNotifier = ref.read(transactionFormProvider.notifier);
    formNotifier.reset();

    if (parsed.amount != null) {
      formNotifier.updateAmount(parsed.amount!);
    }

    formNotifier.updateDescription(parsed.description);

    // Marcar como input por voz
    final current = ref.read(transactionFormProvider);
    ref.read(transactionFormProvider.notifier).updateDescription(
      current.description,
    );

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
                    'Ejemplo: "Cien pesos en Uber al trabajo"',
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

  /// Parsea texto dictado para extraer monto y descripción.
  /// Ejemplo: "Cien pesos en Uber" → amount: 100, description: "Uber"
  _VoiceParsed _parseVoiceInput(String text) {
    final normalized = text.toLowerCase().trim();

    // Intentar extraer monto numérico: "150 pesos en uber"
    final numericPattern = RegExp(r'(\d+(?:\.\d+)?)\s*(?:pesos|varos|bolas)?(?:\s+(?:en|de|por|para)\s+)?(.*)');
    final numMatch = numericPattern.firstMatch(normalized);
    if (numMatch != null) {
      final amount = double.tryParse(numMatch.group(1) ?? '');
      final desc = numMatch.group(2)?.trim() ?? text;
      return _VoiceParsed(amount: amount, description: desc.isNotEmpty ? desc : text);
    }

    // Mapa de números en texto español
    const wordToNumber = {
      'un': 1.0, 'uno': 1.0, 'una': 1.0,
      'dos': 2.0, 'tres': 3.0, 'cuatro': 4.0, 'cinco': 5.0,
      'seis': 6.0, 'siete': 7.0, 'ocho': 8.0, 'nueve': 9.0,
      'diez': 10.0, 'veinte': 20.0, 'treinta': 30.0, 'cuarenta': 40.0,
      'cincuenta': 50.0, 'sesenta': 60.0, 'setenta': 70.0,
      'ochenta': 80.0, 'noventa': 90.0, 'cien': 100.0, 'ciento': 100.0,
      'doscientos': 200.0, 'trescientos': 300.0, 'quinientos': 500.0,
      'mil': 1000.0,
    };

    // Buscar palabras numéricas
    final words = normalized.split(RegExp(r'\s+'));
    for (int i = 0; i < words.length; i++) {
      if (wordToNumber.containsKey(words[i])) {
        final amount = wordToNumber[words[i]];
        // Buscar el resto como descripción
        final descWords = words.sublist(i + 1).where((w) =>
            w != 'pesos' && w != 'varos' && w != 'en' && w != 'de' && w != 'por' && w != 'para'
        ).toList();
        final desc = descWords.isNotEmpty ? descWords.join(' ') : text;
        return _VoiceParsed(amount: amount, description: desc);
      }
    }

    // No se detectó monto, devolver todo como descripción
    return _VoiceParsed(description: text);
  }
}

class _VoiceParsed {
  final double? amount;
  final String description;

  _VoiceParsed({this.amount, required this.description});
}
