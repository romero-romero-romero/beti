import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beti_app/core/widgets/password_requirements_list.dart';
import 'package:beti_app/features/auth/presentation/providers/auth_provider.dart';

/// Pantalla de "nueva contraseña" tras un reset.
///
/// Se llega aquí cuando el usuario hizo click en el link de recuperación
/// recibido por email, el deep link abrió la app, y el SDK de Supabase
/// emitió `AuthChangeEvent.passwordRecovery`.
///
/// Tras actualizar la contraseña exitosamente, se cierra la sesión de
/// recuperación y se redirige a `/login` para que el usuario entre con
/// sus credenciales nuevas.
class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  // Blacklist de contraseñas triviales — debe coincidir con register_screen.
  static const _commonPasswords = {
    '12345678',
    'password',
    'password1',
    'qwerty',
    'qwerty123',
    'abc12345',
    '11111111',
    'contrasena',
  };

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;

  bool _ruleMinLength = false;
  bool _ruleHasLetter = false;
  bool _ruleHasDigit = false;
  bool _ruleNotCommon = false;

  bool get _passwordIsValid =>
      _ruleMinLength && _ruleHasLetter && _ruleHasDigit && _ruleNotCommon;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_evaluatePassword);
  }

  void _evaluatePassword() {
    final value = _passwordController.text;
    setState(() {
      _ruleMinLength = value.length >= 8;
      _ruleHasLetter = RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(value);
      _ruleHasDigit = RegExp(r'\d').hasMatch(value);
      _ruleNotCommon =
          value.isNotEmpty && !_commonPasswords.contains(value.toLowerCase());
    });
  }

  @override
  void dispose() {
    _passwordController.removeListener(_evaluatePassword);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    // Capturar referencias ANTES del await (memoria menciona el patrón).
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    setState(() => _submitting = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      // Cerrar la sesión de recuperación: el usuario debe entrar con sus
      // credenciales nuevas. signOut() emite AuthChangeEvent.signedOut, lo
      // que llevará al AuthNotifier a AuthUnauthenticated y el router
      // redirigirá a /login automáticamente.
      await ref.read(authProvider.notifier).signOut();

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada. Inicia sesión nuevamente.'),
          backgroundColor: Colors.green,
        ),
      );
      router.goNamed('login');
    } on AuthException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar la contraseña.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva contraseña'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.1),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Crear nueva contraseña',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: size.height * 0.01),
                  Text(
                    'Establece tu nueva contraseña para acceder a tu cuenta.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  SizedBox(height: size.height * 0.03),

                  // Nueva contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa una contraseña';
                      }
                      if (!_passwordIsValid) {
                        return 'La contraseña no cumple los requisitos';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  PasswordRequirementsList(
                    minLength: _ruleMinLength,
                    hasLetter: _ruleHasLetter,
                    hasDigit: _ruleHasDigit,
                    notCommon: _ruleNotCommon,
                    showAll: _passwordController.text.isNotEmpty,
                  ),
                  SizedBox(height: size.height * 0.015),

                  // Confirmar contraseña
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirma tu contraseña';
                      }
                      if (value != _passwordController.text) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: size.height * 0.03),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Actualizar contraseña'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}