// lib/features/diagnostics/presentation/screens/ocr_evaluator_screen.dart
//
// ─────────────────────────────────────────────────────────────────────────────
// HERRAMIENTA DE DIAGNÓSTICO — NO INCLUIR EN RELEASE BUILD
//
// Uso:
//   1. Copia tus 63 fotos de tickets al dispositivo (Gallery o Files).
//   2. Abre esta pantalla desde Settings > "Modo desarrollador" (solo en debug).
//   3. Pulsa "Seleccionar carpeta / fotos" y elige todas las imágenes.
//   4. Pulsa "Evaluar tickets" — el harness las procesa en lote.
//   5. Pulsa "Exportar CSV" — el archivo aparece en Downloads/beti_ocr_eval.csv.
//
// El CSV tiene las columnas:
//   archivo, amount, date, concept, payment_method, card_last_four,
//   amount_status, date_status, concept_status, raw_text_snippet
//
// "status" = DETECTED | MISSING
// "raw_text_snippet" = primeras 200 chars del texto crudo (para debug manual).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:beti_app/features/input_capture/data/datasources/ocr_local_ds.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de resultado por ticket
// ─────────────────────────────────────────────────────────────────────────────

class TicketEvalResult {
  final String filename;
  final OcrTicketResult ocr;
  final Duration processingTime;

  const TicketEvalResult({
    required this.filename,
    required this.ocr,
    required this.processingTime,
  });

  /// Estado de detección por campo
  String get amountStatus => ocr.amount != null ? 'DETECTED' : 'MISSING';
  String get dateStatus => ocr.date != null ? 'DETECTED' : 'MISSING';
  String get conceptStatus => ocr.concept != null ? 'DETECTED' : 'MISSING';
  String get paymentStatus => ocr.paymentMethod != null ? 'DETECTED' : 'MISSING';

  String get amountDisplay =>
      ocr.amount != null ? '\$${ocr.amount!.toStringAsFixed(2)}' : '—';

  String get dateDisplay => ocr.date != null
      ? '${ocr.date!.day.toString().padLeft(2, '0')}/'
        '${ocr.date!.month.toString().padLeft(2, '0')}/'
        '${ocr.date!.year}'
      : '—';

  String get paymentDisplay => ocr.paymentMethod != null
      ? ocr.paymentMethod!.name
      : '—';

  String get conceptDisplay => ocr.concept ?? '—';

  String get cardDisplay =>
      ocr.cardLastFour != null ? '****${ocr.cardLastFour}' : '—';

  /// Primeras 200 chars del raw text, sin saltos de línea (para el CSV)
  String get rawSnippet =>
      ocr.rawText.replaceAll('\n', ' ').replaceAll(',', ';').trim().take200;
}

extension _StringTake on String {
  String get take200 => length > 200 ? substring(0, 200) : this;
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado del evaluador
// ─────────────────────────────────────────────────────────────────────────────

enum EvalPhase { idle, picking, processing, done, exporting }

class EvalState {
  final EvalPhase phase;
  final List<TicketEvalResult> results;
  final int totalFiles;
  final int processedFiles;
  final String? errorMessage;
  final String? exportPath;

  const EvalState({
    this.phase = EvalPhase.idle,
    this.results = const [],
    this.totalFiles = 0,
    this.processedFiles = 0,
    this.errorMessage,
    this.exportPath,
  });

  EvalState copyWith({
    EvalPhase? phase,
    List<TicketEvalResult>? results,
    int? totalFiles,
    int? processedFiles,
    String? errorMessage,
    String? exportPath,
  }) =>
      EvalState(
        phase: phase ?? this.phase,
        results: results ?? this.results,
        totalFiles: totalFiles ?? this.totalFiles,
        processedFiles: processedFiles ?? this.processedFiles,
        errorMessage: errorMessage ?? this.errorMessage,
        exportPath: exportPath ?? this.exportPath,
      );

  // ── Métricas de resumen ──

  int get detectedAmount =>
      results.where((r) => r.ocr.amount != null).length;
  int get detectedDate =>
      results.where((r) => r.ocr.date != null).length;
  int get detectedConcept =>
      results.where((r) => r.ocr.concept != null).length;
  int get detectedPayment =>
      results.where((r) => r.ocr.paymentMethod != null).length;

  double pct(int detected) =>
      totalFiles == 0 ? 0 : (detected / totalFiles) * 100;
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class OcrEvaluatorNotifier extends StateNotifier<EvalState> {
  OcrEvaluatorNotifier() : super(const EvalState());

  final _ds = OcrLocalDataSource();
  final _picker = ImagePicker();

  // ── Paso 1: seleccionar imágenes ──────────────────────────────────────────

  Future<List<File>?> pickImages() async {
    state = state.copyWith(phase: EvalPhase.picking);
    try {
      final xFiles = await _picker.pickMultiImage(imageQuality: 85);
      if (xFiles.isEmpty) {
        state = state.copyWith(phase: EvalPhase.idle);
        return null;
      }
      return xFiles.map((x) => File(x.path)).toList();
    } catch (e) {
      state = state.copyWith(
        phase: EvalPhase.idle,
        errorMessage: 'Error al seleccionar fotos: $e',
      );
      return null;
    }
  }

  // ── Paso 2: procesar en lote ──────────────────────────────────────────────

  Future<void> evaluate(List<File> files) async {
    state = state.copyWith(
      phase: EvalPhase.processing,
      totalFiles: files.length,
      processedFiles: 0,
      results: [],
      errorMessage: null,
    );

    final results = <TicketEvalResult>[];

    for (final file in files) {
      final filename = file.path.split('/').last;
      try {
        final sw = Stopwatch()..start();
        final ocr = await _ds.processImage(file);
        sw.stop();

        results.add(TicketEvalResult(
          filename: filename,
          ocr: ocr,
          processingTime: sw.elapsed,
        ));
      } catch (e) {
        // En caso de error en un ticket individual, lo registramos como vacío
        // para no interrumpir el lote.
        results.add(TicketEvalResult(
          filename: filename,
          ocr: OcrTicketResult(
            rawText: 'ERROR: $e',
          ),
          processingTime: Duration.zero,
        ));
      }

      state = state.copyWith(
        processedFiles: results.length,
        results: List.from(results),
      );
    }

    state = state.copyWith(phase: EvalPhase.done, results: results);
  }

  // ── Paso 3: exportar CSV ──────────────────────────────────────────────────

  Future<void> exportCsv() async {
  if (state.results.isEmpty) return;
  state = state.copyWith(phase: EvalPhase.exporting);

  try {
    final csv = _buildCsv(state.results);

    // Android 10+ bloquea escritura directa a Downloads sin permisos especiales.
    // Usamos temp dir (siempre accesible) y compartimos via share sheet.
    final temp = await getTemporaryDirectory();
    final outFile = File('${temp.path}/beti_ocr_eval.csv');
    await outFile.writeAsString(csv, flush: true);

    state = state.copyWith(
      phase: EvalPhase.done,
      exportPath: outFile.path,
    );

    await Share.shareXFiles(
      [XFile(outFile.path, mimeType: 'text/csv')],
      subject: 'Beti OCR Eval — ${state.results.length} tickets',
    );
  } catch (e) {
    state = state.copyWith(
      phase: EvalPhase.done,
      errorMessage: 'Error al exportar: $e',
    );
  }
}

  // ── Reset ─────────────────────────────────────────────────────────────────

  void reset() {
    state = const EvalState();
  }

  @override
  void dispose() {
    _ds.dispose();
    super.dispose();
  }

  // ── Construcción del CSV ──────────────────────────────────────────────────

  String _buildCsv(List<TicketEvalResult> results) {
    final buf = StringBuffer();

    // Cabecera
    buf.writeln(
      'archivo,'
      'amount,'
      'amount_status,'
      'date,'
      'date_status,'
      'concept,'
      'concept_status,'
      'payment_method,'
      'payment_status,'
      'card_last_four,'
      'processing_ms,'
      'raw_text_snippet',
    );

    // Filas
    for (final r in results) {
      // Escapar concepto por si contiene comas
      final concept = '"${r.conceptDisplay.replaceAll('"', "'")}"';
      final snippet = '"${r.rawSnippet.replaceAll('"', "'")}"';

      buf.writeln(
        '${r.filename},'
        '${r.amountDisplay},'
        '${r.amountStatus},'
        '${r.dateDisplay},'
        '${r.dateStatus},'
        '$concept,'
        '${r.conceptStatus},'
        '${r.paymentDisplay},'
        '${r.paymentStatus},'
        '${r.cardDisplay},'
        '${r.processingTime.inMilliseconds},'
        '$snippet',
      );
    }

    return buf.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final ocrEvaluatorProvider =
    StateNotifierProvider.autoDispose<OcrEvaluatorNotifier, EvalState>(
  (_) => OcrEvaluatorNotifier(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla de diagnóstico
// ─────────────────────────────────────────────────────────────────────────────

class OcrEvaluatorScreen extends ConsumerWidget {
  const OcrEvaluatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ocrEvaluatorProvider);
    final notifier = ref.read(ocrEvaluatorProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Evaluator [DEV]'),
        actions: [
          if (state.results.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
              onPressed: notifier.reset,
            ),
        ],
      ),
      body: switch (state.phase) {
        EvalPhase.idle => _IdleView(notifier: notifier),
        EvalPhase.picking => const _LoadingView(message: 'Abriendo galería…'),
        EvalPhase.processing => _ProcessingView(state: state),
        EvalPhase.done => _ResultsView(state: state, notifier: notifier),
        EvalPhase.exporting =>
          const _LoadingView(message: 'Generando CSV…'),
      },
    );
  }
}

// ─── Vistas de estado ────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final OcrEvaluatorNotifier notifier;
  const _IdleView({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Harness de evaluación OCR',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecciona tus 63 fotos de tickets para evaluar '
              'qué campos detecta el parser actual.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Seleccionar fotos'),
              onPressed: () async {
                final files = await notifier.pickImages();
                if (files != null && files.isNotEmpty) {
                  await notifier.evaluate(files);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      );
}

class _ProcessingView extends StatelessWidget {
  final EvalState state;
  const _ProcessingView({required this.state});

  @override
  Widget build(BuildContext context) {
    final pct = state.totalFiles == 0
        ? 0.0
        : state.processedFiles / state.totalFiles;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${state.processedFiles} / ${state.totalFiles}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'tickets procesados',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(value: pct),
          const SizedBox(height: 16),
          // Último resultado procesado
          if (state.results.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            _LastResultChip(result: state.results.last),
          ],
        ],
      ),
    );
  }
}

class _LastResultChip extends StatelessWidget {
  final TicketEvalResult result;
  const _LastResultChip({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          result.filename,
          style: const TextStyle(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatusDot(label: 'Monto', detected: result.ocr.amount != null),
            const SizedBox(width: 12),
            _StatusDot(label: 'Fecha', detected: result.ocr.date != null),
            const SizedBox(width: 12),
            _StatusDot(label: 'Concepto', detected: result.ocr.concept != null),
            const SizedBox(width: 12),
            _StatusDot(label: 'Pago', detected: result.ocr.paymentMethod != null),
          ],
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String label;
  final bool detected;
  const _StatusDot({required this.label, required this.detected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          detected ? Icons.check_circle : Icons.cancel,
          size: 14,
          color: detected ? Colors.green : Colors.red.shade300,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ─── Vista de resultados ─────────────────────────────────────────────────────

class _ResultsView extends StatefulWidget {
  final EvalState state;
  final OcrEvaluatorNotifier notifier;
  const _ResultsView({required this.state, required this.notifier});

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView> {
  // Filtro rápido para mostrar solo los que fallan un campo
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;

    final filtered = _applyFilter(s.results, _filter);

    return Column(
      children: [
        // ── Banner de resumen ──────────────────────────────────────────────
        _SummaryBanner(state: s),

        // ── Filtros ───────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: _Filter.values
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_filterLabel(f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        // ── Lista de tickets ──────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _TicketResultTile(result: filtered[i]),
          ),
        ),

        // ── Botón exportar ────────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.download),
                label: Text('Exportar CSV (${s.results.length} tickets)'),
                onPressed: widget.notifier.exportCsv,
              ),
            ),
          ),
        ),

        if (s.exportPath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '✓ Guardado en: ${s.exportPath}',
              style: const TextStyle(fontSize: 11, color: Colors.green),
              textAlign: TextAlign.center,
            ),
          ),

        if (s.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              s.errorMessage!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  List<TicketEvalResult> _applyFilter(
    List<TicketEvalResult> all,
    _Filter filter,
  ) =>
      switch (filter) {
        _Filter.all => all,
        _Filter.missingAmount =>
          all.where((r) => r.ocr.amount == null).toList(),
        _Filter.missingDate =>
          all.where((r) => r.ocr.date == null).toList(),
        _Filter.missingConcept =>
          all.where((r) => r.ocr.concept == null).toList(),
        _Filter.fullyDetected => all
            .where((r) =>
                r.ocr.amount != null &&
                r.ocr.date != null &&
                r.ocr.concept != null)
            .toList(),
      };

  String _filterLabel(_Filter f) => switch (f) {
        _Filter.all => 'Todos',
        _Filter.missingAmount => 'Sin monto',
        _Filter.missingDate => 'Sin fecha',
        _Filter.missingConcept => 'Sin concepto',
        _Filter.fullyDetected => 'Completos ✓',
      };
}

enum _Filter { all, missingAmount, missingDate, missingConcept, fullyDetected }

// ─── Tile individual ─────────────────────────────────────────────────────────

class _TicketResultTile extends StatelessWidget {
  final TicketEvalResult result;
  const _TicketResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final allGood = result.ocr.amount != null &&
        result.ocr.date != null &&
        result.ocr.concept != null;

    return ExpansionTile(
      leading: Icon(
        allGood ? Icons.check_circle : Icons.warning_amber,
        color: allGood ? Colors.green : Colors.orange,
      ),
      title: Text(
        result.filename,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${result.amountDisplay} · ${result.dateDisplay} · ${result.processingTime.inMilliseconds}ms',
        style: const TextStyle(fontSize: 11),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Field('Monto', result.amountDisplay, result.ocr.amount != null),
              _Field('Fecha', result.dateDisplay, result.ocr.date != null),
              _Field(
                  'Concepto', result.conceptDisplay, result.ocr.concept != null),
              _Field('Método pago', result.paymentDisplay,
                  result.ocr.paymentMethod != null),
              _Field('Tarjeta', result.cardDisplay,
                  result.ocr.cardLastFour != null),
              const SizedBox(height: 8),
              const Text(
                'Texto crudo (primeras 200 chars):',
                style:
                    TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  result.rawSnippet,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final bool detected;
  const _Field(this.label, this.value, this.detected);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            detected ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: 14,
            color: detected ? Colors.green : Colors.red.shade300,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: detected ? Colors.black87 : Colors.red.shade400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Banner de resumen ───────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final EvalState state;
  const _SummaryBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.indigo.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Metric(
            label: 'Monto',
            detected: state.detectedAmount,
            total: state.totalFiles,
          ),
          _Metric(
            label: 'Fecha',
            detected: state.detectedDate,
            total: state.totalFiles,
          ),
          _Metric(
            label: 'Concepto',
            detected: state.detectedConcept,
            total: state.totalFiles,
          ),
          _Metric(
            label: 'Pago',
            detected: state.detectedPayment,
            total: state.totalFiles,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int detected;
  final int total;
  const _Metric(
      {required this.label, required this.detected, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : detected / total * 100;
    final color = pct >= 80
        ? Colors.green
        : pct >= 50
            ? Colors.orange
            : Colors.red;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${pct.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          '$detected/$total',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}