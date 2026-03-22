import 'package:flutter/material.dart';

/// Widget reutilizable para banners de imagen con altura fija.
///
/// Inspirado en el patrón ImageBanner de Nick Manning.
/// Usa BoxConstraints.expand para garantizar altura consistente.
///
/// Ejemplo:
/// ```dart
/// ImageBanner('assets/images/cossmil_logo.png', height: 200)
/// ```
class ImageBanner extends StatelessWidget {
  final String _assetPath;
  final double height;

  const ImageBanner(this._assetPath, {super.key, this.height = 200.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints.expand(height: height),
      child: Image.asset(
        _assetPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[200],
          child: const Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
