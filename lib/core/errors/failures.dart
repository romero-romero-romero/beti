// Clases base de errores para Clean Architecture.
// Los Use Cases retornan Failure en lugar de lanzar excepciones.

abstract class Failure {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  String toString() => 'Failure($code): $message';
}

class DatabaseFailure extends Failure {
  const DatabaseFailure({required super.message, super.code});
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Sin conexión a internet',
    super.code,
  });
}

class SyncFailure extends Failure {
  const SyncFailure({required super.message, super.code});
}

class MlFailure extends Failure {
  const MlFailure({required super.message, super.code});
}

class InputCaptureFailure extends Failure {
  const InputCaptureFailure({required super.message, super.code});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}

class BelvoFailure extends Failure {
  const BelvoFailure({required super.message, super.code});
}
