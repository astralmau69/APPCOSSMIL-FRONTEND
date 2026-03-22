import 'package:flutter/material.dart';
import '../theme/app_constants.dart';

/// Widget reutilizable para cabeceras de sección con estilo consistente.
///
/// Ejemplo:
/// ```dart
/// SectionHeader(text: 'CONSULTA DIRECTA')
/// ```
class SectionHeader extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.text,
    this.padding = const EdgeInsets.only(left: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: AppTypography.labelMedium.copyWith(
          letterSpacing: 1.0,
          fontSize: 13,
        ),
      ),
    );
  }
}
