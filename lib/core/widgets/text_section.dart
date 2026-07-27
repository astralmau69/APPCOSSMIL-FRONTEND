import 'package:flutter/material.dart';
import '../extensions/responsive_extensions.dart';

/// Widget reutilizable para bloques de texto con título y cuerpo.
///
/// Inspirado en el patrón TextSection de Nick Manning.
/// Separa visualmente un título en negrita de un cuerpo descriptivo.
///
/// Ejemplo:
/// ```dart
/// TextSection('Horarios de Atención', 'Lunes a Viernes 08:00 - 16:00')
/// ```
class TextSection extends StatelessWidget {
  final String _title;
  final String _body;

  const TextSection(this._title, this._body, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title, style: context.texts.titleMedium),
          SizedBox(height: context.r.spaceSm),
          Text(_body, style: context.texts.bodyMedium),
        ],
      ),
    );
  }
}
