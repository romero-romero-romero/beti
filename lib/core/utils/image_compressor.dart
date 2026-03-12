import 'dart:io';

/// Compresión de imágenes de tickets antes de subirlas a Supabase Storage.
/// Reduce el consumo de datos y almacenamiento.
class ImageCompressor {
  ImageCompressor._();

  /// Comprime una imagen y retorna la ruta del archivo comprimido.
  /// Implementación completa en Fase 3 (OCR + Storage).
  static Future<File> compress(File imageFile, {int quality = 70}) async {
    // TODO: Implementar con flutter_image_compress en Fase 3
    // Por ahora retorna el archivo original.
    return imageFile;
  }
}
