import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beti_app/features/input_capture/data/datasources/speech_local_ds.dart';
import 'package:beti_app/features/input_capture/data/datasources/ocr_local_ds.dart';

// ── Singletons ──

final speechDataSourceProvider = Provider<SpeechLocalDataSource>((ref) {
  final ds = SpeechLocalDataSource();
  ref.onDispose(() => ds.dispose());
  return ds;
});

final ocrDataSourceProvider = Provider<OcrLocalDataSource>((ref) {
  final ds = OcrLocalDataSource();
  ref.onDispose(() => ds.dispose());
  return ds;
});

// ── Speech State ──

enum SpeechStatus { idle, initializing, listening, processing, error }

class SpeechState {
  final SpeechStatus status;
  final String partialText;
  final String finalText;
  final String? error;

  const SpeechState({
    this.status = SpeechStatus.idle,
    this.partialText = '',
    this.finalText = '',
    this.error,
  });

  SpeechState copyWith({
    SpeechStatus? status,
    String? partialText,
    String? finalText,
    String? error,
  }) {
    return SpeechState(
      status: status ?? this.status,
      partialText: partialText ?? this.partialText,
      finalText: finalText ?? this.finalText,
      error: error,
    );
  }
}

class SpeechNotifier extends StateNotifier<SpeechState> {
  final SpeechLocalDataSource _ds;

  SpeechNotifier(this._ds) : super(const SpeechState());

  Future<void> startListening() async {
    state = state.copyWith(
      status: SpeechStatus.initializing,
      partialText: '',
      finalText: '',
      error: null,
    );

    final available = await _ds.initialize();
    if (!available) {
      // Diferenciar error de permiso vs no disponible
      final errorMsg = _ds.lastError.toLowerCase();
      final isPermission = errorMsg.contains('permission') ||
          errorMsg.contains('denied') ||
          errorMsg.contains('not_allowed');

      state = state.copyWith(
        status: SpeechStatus.error,
        error: isPermission
            ? 'Permiso de micrófono denegado. Habilítalo en Ajustes > Apps > Beti > Permisos.'
            : 'Reconocimiento de voz no disponible. Verifica que el paquete de idioma español esté instalado.',
      );
      return;
    }

    state = state.copyWith(status: SpeechStatus.listening);

    await _ds.startListening(
      onResult: (result) {
        if (result.finalResult) {
          state = state.copyWith(
            status: SpeechStatus.processing,
            finalText: result.recognizedWords,
            partialText: result.recognizedWords,
          );
        } else {
          state = state.copyWith(
            partialText: result.recognizedWords,
          );
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _ds.stopListening();
    // Si hay texto parcial pero no se marcó como final, usarlo
    if (state.finalText.isEmpty && state.partialText.isNotEmpty) {
      state = state.copyWith(
        status: SpeechStatus.processing,
        finalText: state.partialText,
      );
    } else if (state.finalText.isEmpty) {
      state = state.copyWith(status: SpeechStatus.idle);
    }
  }

  Future<void> cancel() async {
    await _ds.cancel();
    state = const SpeechState();
  }

  void reset() {
    state = const SpeechState();
  }
}

final speechProvider =
    StateNotifierProvider<SpeechNotifier, SpeechState>((ref) {
  return SpeechNotifier(ref.watch(speechDataSourceProvider));
});

// ── OCR State ──

enum OcrStatus { idle, processing, done, error }

class OcrState {
  final OcrStatus status;
  final OcrTicketResult? result;
  final String? error;

  const OcrState({
    this.status = OcrStatus.idle,
    this.result,
    this.error,
  });
}

class OcrNotifier extends StateNotifier<OcrState> {
  final OcrLocalDataSource _ds;

  OcrNotifier(this._ds) : super(const OcrState());

  Future<void> processImage(File imageFile) async {
    state = const OcrState(status: OcrStatus.processing);

    try {
      final result = await _ds.processImage(imageFile);
      state = OcrState(status: OcrStatus.done, result: result);
    } catch (e) {
      state = OcrState(
        status: OcrStatus.error,
        error: 'Error al procesar la imagen: $e',
      );
    }
  }

  void reset() {
    state = const OcrState();
  }
}

final ocrProvider = StateNotifierProvider<OcrNotifier, OcrState>((ref) {
  return OcrNotifier(ref.watch(ocrDataSourceProvider));
});
