import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/app_logger.dart';
import 'instructor_rig.dart';

const String _kDir = 'assets/images/instructor/';

/// Las piezas del rig ya decodificadas.
///
/// Una pieza que no carga NO entra al mapa y el painter simplemente la salta:
/// mejor una instructora sin antena que un tutorial en blanco.
class InstructorImages {
  final Map<String, ui.Image> byAsset;

  const InstructorImages._(this.byAsset);

  /// Mientras el manifest ya cargó pero los PNG todavía no. El painter dibuja
  /// nada y la pose sigue siendo observable.
  static const empty = InstructorImages._({});

  @visibleForTesting
  factory InstructorImages.forTest(Map<String, ui.Image> m) =>
      InstructorImages._(m);

  static Future<InstructorImages> load(
    Iterable<InstructorRig> rigs, {
    AssetBundle? bundle,
    String dir = _kDir,
  }) async {
    final b = bundle ?? rootBundle;
    final out = <String, ui.Image>{};
    for (final rig in rigs) {
      for (final bone in rig.bones) {
        if (out.containsKey(bone.asset)) continue;
        try {
          final data = await b.load('$dir${bone.asset}');
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          out[bone.asset] = (await codec.getNextFrame()).image;
        } catch (e) {
          AppLogger.warn(
            'InstructorImages',
            'No se pudo cargar ${bone.asset}, se dibuja sin ella',
            e,
          );
        }
      }
    }
    return InstructorImages._(out);
  }

  void dispose() {
    for (final img in byAsset.values) {
      img.dispose();
    }
  }
}

/// Dibuja el rig con la pose dada. Widget tonto: no anima, sólo pinta.
class InstructorRigView extends StatelessWidget {
  final InstructorRig rig;
  final InstructorImages images;
  final Map<String, Matrix4> pose;
  final double height;

  /// Huesos que NO se dibujan. Los ojos, la boca y la mano son grupos de
  /// variantes excluyentes: de cada grupo se pinta una y el resto se oculta.
  final Set<String> hidden;

  const InstructorRigView({
    super.key,
    required this.rig,
    required this.images,
    required this.pose,
    required this.height,
    this.hidden = const {},
  });

  @override
  Widget build(BuildContext context) {
    // `height` llega de `min(profileAvatarSize * 1.55, alto * 0.30)`, que en
    // horizontal o en pantallas muy bajas puede quedar en nada.
    final h = (height.isFinite && height > 0) ? height : 0.0;
    return RepaintBoundary(
      child: SizedBox(
        height: h,
        width: h * rig.aspect,
        child: CustomPaint(
          painter: InstructorRigPainter(
            rig: rig,
            images: images.byAsset,
            pose: pose,
            scale: h / rig.canonicalHeight,
            hidden: hidden,
          ),
        ),
      ),
    );
  }
}

class InstructorRigPainter extends CustomPainter {
  final InstructorRig rig;
  final Map<String, ui.Image> images;
  final Map<String, Matrix4> pose;
  final double scale;
  final Set<String> hidden;

  const InstructorRigPainter({
    required this.rig,
    required this.images,
    required this.pose,
    required this.scale,
    this.hidden = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scale <= 0 || !scale.isFinite) return;
    // `low` (bilineal) es el filtrado recomendado para imagenes ANIMADAS:
    // lo hace la GPU, mientras `medium` (cubico) se nota en equipos flojos.
    // Antes esa decision estaba tomada y documentada para UNA lamina; aqui
    // son 28 `drawImageRect` por fotograma, asi que pesa 28 veces mas.
    final paint = Paint()..filterQuality = FilterQuality.low;
    canvas.save();
    canvas.scale(scale);
    for (final bone in rig.drawOrder) {
      if (hidden.contains(bone.name)) continue;
      final img = images[bone.asset];
      final m = pose[bone.name];
      if (img == null || m == null) continue;
      canvas.save();
      canvas.transform(m.storage);
      canvas.translate(-bone.anchor.dx, -bone.anchor.dy);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(0, 0, bone.size.width, bone.size.height),
        paint,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(InstructorRigPainter old) =>
      old.pose != pose ||
      old.scale != scale ||
      old.images != images ||
      !setEquals(old.hidden, hidden);
}
