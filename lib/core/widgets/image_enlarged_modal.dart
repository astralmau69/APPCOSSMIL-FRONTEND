import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';

class ImageEnlargedModal extends StatelessWidget {
  final Uint8List decodedPhoto;
  final String fallbackText;

  const ImageEnlargedModal({
    super.key,
    required this.decodedPhoto,
    this.fallbackText = 'U',
  });

  static Future<void> show({
    required BuildContext context,
    required String base64Photo,
    String fallbackText = 'M',
  }) async {
    if (base64Photo.isEmpty) return;
    Uint8List? decoded;
    try {
      decoded = base64Decode(base64Photo);
    } catch (_) {
      return; // Si no es válido o está corrupto
    }

    await showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent, // Lo manejamos con BackdropFilter
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      pageBuilder: (context, _, __) {
        return ImageEnlargedModal(
          decodedPhoto: decoded!,
          fallbackText: fallbackText,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    // Un tamaño grande (ej. 75% del ancho de la pantalla)
    final imageSize = r.screenWidth * 0.75;
    
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(), // Cerrar al tocar fuera
        child: Stack(
          children: [
            // Difuminado de fondo
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: isDark ? Colors.black87 : Colors.black54,
                ),
              ),
            ),
            
            // Botón cerrar esquina
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 24),
                ),
              ),
            ),

            // Foto centrada con Hero potential y zoom effect
            Center(
              child: GestureDetector(
                onTap: () {}, // Bloquear que cierre al tocar la imagen misma
                child: Hero(
                  tag: 'enlarged-image',
                  child: Container(
                    width: imageSize,
                    height: imageSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      border: Border.all(
                        color: AppColors.accentForTheme(isDark).withValues(alpha: 0.8),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          blurRadius: 32,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.memory(
                        decodedPhoto,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              fallbackText,
                              style: TextStyle(
                                fontSize: imageSize * 0.4,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
