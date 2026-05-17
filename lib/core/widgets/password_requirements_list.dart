import 'package:flutter/material.dart';

/// Lista visual de requisitos de contraseña con estado en vivo.
///
/// Usada en flujos de registro y cambio de contraseña para que el usuario
/// vea qué requisitos cumple su entrada actual conforme escribe.
///
/// El padre es responsable de evaluar las reglas y pasar el estado de cada
/// una. Este widget es puramente presentacional.
class PasswordRequirementsList extends StatelessWidget {
  const PasswordRequirementsList({
    super.key,
    required this.minLength,
    required this.hasLetter,
    required this.hasDigit,
    required this.notCommon,
    required this.showAll,
  });

  final bool minLength;
  final bool hasLetter;
  final bool hasDigit;
  final bool notCommon;

  /// Cuando es `false`, el widget se renderiza vacío (cero altura).
  /// Útil para ocultar la lista hasta que el usuario empiece a escribir.
  final bool showAll;

  @override
  Widget build(BuildContext context) {
    if (!showAll) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RequirementRow(met: minLength, label: 'Mínimo 8 caracteres'),
          _RequirementRow(met: hasLetter, label: 'Al menos una letra'),
          _RequirementRow(met: hasDigit, label: 'Al menos un número'),
          _RequirementRow(met: notCommon, label: 'No es una contraseña común'),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.met, required this.label});

  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = met ? Colors.green : Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}