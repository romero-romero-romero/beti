/// Textos constantes de la aplicación.
class AppStrings {
  AppStrings._();

  static const String appName = 'Betty';
  static const String appTagline = 'Tu bienestar financiero';

  // ── Auth ──
  static const String login = 'Iniciar Sesión';
  static const String register = 'Registrarse';
  static const String logout = 'Cerrar Sesión';
  static const String email = 'Correo Electrónico';
  static const String password = 'Contraseña';
  static const String confirmPassword = 'Confirmar Contraseña';
  static const String forgotPassword = '¿Olvidaste tu contraseña?';
  static const String noAccount = '¿No tienes cuenta?';
  static const String hasAccount = '¿Ya tienes cuenta?';
  static const String continueWithGoogle = 'Continuar con Google';
  static const String fullName = 'Nombre completo';
  static const String termsAgreement = 'Acepto los términos y condiciones';

  // ── Transacciones ──
  static const String addTransaction = 'Registrar movimiento';
  static const String income = 'Ingreso';
  static const String expense = 'Gasto';
  static const String amount = 'Monto';
  static const String description = 'Descripción';
  static const String category = 'Categoría';
  static const String date = 'Fecha';

  // ── Input ──
  static const String voiceInput = 'Dictar por voz';
  static const String photoInput = 'Foto de ticket';
  static const String manualInput = 'Ingreso manual';
  static const String previewTitle = 'Confirma los datos';
  static const String previewSubtitle = 'Verifica que la información sea correcta';

  // ── Salud Financiera ──
  static const String healthTitle = 'Tu salud financiera';
  static const String peacefulMessage = 'Excelente. Estás en paz financiera.';
  static const String stableMessage = 'Vas bien. Mantén el ritmo.';
  static const String warningMessage = 'Cuidado. Tus gastos están creciendo.';
  static const String dangerMessage = 'Alerta. Estás cerca del límite.';
  static const String crisisMessage = 'Necesitas actuar. Tus gastos superan tus ingresos.';

  // ── Errores ──
  static const String errorGeneric = 'Ocurrió un error. Intenta de nuevo.';
  static const String errorInvalidCredentials = 'Credenciales inválidas';
  static const String errorEmailNotConfirmed = 'Correo electrónico no confirmado';
  static const String errorUserExists = 'El correo ya está registrado';
  static const String errorNoInternet = 'Sin conexión. Tus datos se guardan localmente.';
}
