// Excepciones custom que los DataSources lanzan.
// Los Repositories las capturan y convierten en Failures.

class DatabaseException implements Exception {
  final String message;
  const DatabaseException([this.message = 'Error de base de datos local']);

  @override
  String toString() => 'DatabaseException: $message';
}

class AuthException implements Exception {
  final String message;
  const AuthException([this.message = 'Error de autenticación']);

  @override
  String toString() => 'AuthException: $message';
}

class SyncException implements Exception {
  final String message;
  const SyncException([this.message = 'Error de sincronización']);

  @override
  String toString() => 'SyncException: $message';
}

class InputCaptureException implements Exception {
  final String message;
  const InputCaptureException([this.message = 'Error en captura de datos']);

  @override
  String toString() => 'InputCaptureException: $message';
}
