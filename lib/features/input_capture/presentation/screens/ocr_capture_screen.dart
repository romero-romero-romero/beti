import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:beti_app/core/enums/input_method.dart';
import 'package:beti_app/features/input_capture/presentation/providers/input_capture_provider.dart';
import 'package:beti_app/features/intelligence/data/datasources/nlp_entity_extractor.dart';
import 'package:beti_app/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:beti_app/core/enums/payment_method.dart';

/// Pantalla de captura por foto de ticket (OCR).
/// El usuario toma una foto o la selecciona de galería.
/// ML Kit extrae texto localmente y parsea monto/fecha/concepto.
class OcrCaptureScreen extends ConsumerStatefulWidget {
  const OcrCaptureScreen({super.key});

  @override
  ConsumerState<OcrCaptureScreen> createState() => _OcrCaptureScreenState();
}

class _OcrCaptureScreenState extends ConsumerState<OcrCaptureScreen> {
  final _picker = ImagePicker();
  File? _selectedImage;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (xFile == null) return;

      final file = File(xFile.path);
      setState(() => _selectedImage = file);

      // Procesar con OCR
      await ref.read(ocrProvider.notifier).processImage(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _paymentLabel(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'Efectivo',
        PaymentMethod.debitCard => 'Tarjeta de débito',
        PaymentMethod.creditCard => 'Tarjeta de crédito',
        PaymentMethod.transfer => 'Transferencia',
        PaymentMethod.other => 'Otro',
      };

  void _useResult() {
    final ocr = ref.read(ocrProvider);
    if (ocr.result == null) return;

    final ocrResult = ocr.result!;

    // Pasar datos del OCR por el NLP centralizado para categorización
    final nlp = NlpEntityExtractor.extractFromOcr(
      rawText: ocrResult.rawText,
      amount: ocrResult.amount,
      date: ocrResult.date,
      concept: ocrResult.concept,
      paymentMethod: ocrResult.paymentMethod,
    );

    final formNotifier = ref.read(transactionFormProvider.notifier);
    formNotifier.reset();

    if (nlp.amount != null) {
      formNotifier.updateAmount(nlp.amount!);
    }

    if (nlp.date != null) {
      formNotifier.updateDate(nlp.date!);
    }

    formNotifier.updateType(nlp.type);
    formNotifier.updateDescription(nlp.description);

    if (nlp.categoryAutoAssigned) {
      formNotifier.updateCategory(nlp.category);
    }

    // Marcar como input por OCR
    formNotifier.updateInputMethod(InputMethod.ocr);
    formNotifier.updateRawInput(ocrResult.rawText);

    if (nlp.paymentMethod != null) {
      formNotifier.updatePaymentMethod(nlp.paymentMethod);
    }

    // Guardar path de la imagen para referencia
    if (_selectedImage != null) {
      formNotifier.updateTicketImage(_selectedImage!.path);
    }

    // Navegar al formulario para que el usuario complete/corrija
    context.goNamed('addTransaction');
  }

  @override
  void dispose() {
    ref.read(ocrProvider.notifier).reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ocr = ref.watch(ocrProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Foto de ticket'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Imagen seleccionada o placeholder ──
            Expanded(
              flex: 2,
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Toma foto de tu ticket o selecciona de galería',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // ── Resultado OCR ──
            if (ocr.status == OcrStatus.processing)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Procesando ticket...'),
                  ],
                ),
              ),

            if (ocr.status == OcrStatus.done && ocr.result != null)
              Expanded(
                flex: 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Datos detectados',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                if (ocr.result!.amount != null)
                                  _OcrField(
                                    icon: Icons.attach_money,
                                    label: 'Monto',
                                    value:
                                        '\$${ocr.result!.amount!.toStringAsFixed(2)}',
                                  ),
                                if (ocr.result!.date != null)
                                  _OcrField(
                                    icon: Icons.calendar_today,
                                    label: 'Fecha',
                                    value:
                                        '${ocr.result!.date!.day}/${ocr.result!.date!.month}/${ocr.result!.date!.year}',
                                  ),
                                if (ocr.result!.concept != null)
                                  _OcrField(
                                    icon: Icons.store,
                                    label: 'Concepto',
                                    value: ocr.result!.concept!,
                                  ),
                                if (ocr.result!.paymentMethod != null)
                                  _OcrField(
                                    icon: Icons.credit_card,
                                    label: 'Método de pago',
                                    value: _paymentLabel(
                                        ocr.result!.paymentMethod!),
                                  ),
                                if (ocr.result!.cardLastFour != null)
                                  _OcrField(
                                    icon: Icons.pin,
                                    label: 'Tarjeta',
                                    value: '****${ocr.result!.cardLastFour!}',
                                  ),
                                if (ocr.result!.amount == null &&
                                    ocr.result!.concept == null)
                                  const Text(
                                    'No se detectaron datos claros. Puedes ingresarlos manualmente.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _useResult,
                            child: const Text('Usar datos y completar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (ocr.status == OcrStatus.error)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  ocr.error ?? 'Error al procesar',
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // ── Botones de captura ──
            if (ocr.status != OcrStatus.processing) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Cámara'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OcrField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OcrField({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
