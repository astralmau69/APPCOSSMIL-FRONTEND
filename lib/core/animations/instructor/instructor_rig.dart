import 'dart:convert';

import 'package:flutter/services.dart';

import '../../utils/app_logger.dart';

/// Una pieza del rig de la instructora: su PNG, dónde gira y de quién cuelga.
///
/// Datos puros generados por `tools/build_instructor_v2.py`. Las coordenadas
/// están en la figura canónica (800 px de alto); [pivot] es relativo al pivote
/// del padre, y [anchor] es dónde cae ese pivote DENTRO del PNG de la pieza.
class InstructorBone {
  final String name;
  final String? parent;
  final Offset pivot;
  final Offset anchor;
  final Size size;
  final String asset;

  /// Orden de dibujo: mayor = más adelante.
  final int z;

  const InstructorBone({
    required this.name,
    required this.parent,
    required this.pivot,
    required this.anchor,
    required this.size,
    required this.asset,
    required this.z,
  });

  factory InstructorBone.fromJson(Map<String, dynamic> j) {
    Offset off(String k) {
      final v = (j[k] as List).cast<num>();
      return Offset(v[0].toDouble(), v[1].toDouble());
    }

    final s = (j['size'] as List).cast<num>();
    return InstructorBone(
      name: j['name'] as String,
      parent: j['parent'] as String?,
      pivot: off('pivot'),
      anchor: off('anchor'),
      size: Size(s[0].toDouble(), s[1].toDouble()),
      asset: j['asset'] as String,
      z: (j['z'] as num).toInt(),
    );
  }
}

/// El esqueleto completo. Sin estado ni tiempo: sólo la jerarquía en reposo.
class InstructorRig {
  final List<InstructorBone> bones;
  final double canonicalHeight;

  /// Ancho/alto de la figura. Los consumidores lo leen de aquí en vez de tener
  /// la proporción escrita a mano, para que no se desincronice del arte.
  final double aspect;

  /// La misma figura DE PERFIL, con su propia jerarquía y su propio `aspect`
  /// (de costado es la mitad de ancha). `null` si el manifest no la trae: sin
  /// ella la caminata de entrada cae al rig de frente, que es lo que hacía
  /// antes. Es un rig hermano y no un hueso más, porque las dos vistas no
  /// comparten ni piezas ni proporción.
  final InstructorRig? profile;

  final Map<String, InstructorBone> _byName;
  final List<InstructorBone> _drawOrder;

  InstructorRig._(this.bones, this.canonicalHeight, this.aspect, this.profile)
    : _byName = {for (final b in bones) b.name: b},
      _drawOrder = [...bones]..sort((a, b) => a.z.compareTo(b.z));

  factory InstructorRig.fromJson(Map<String, dynamic> json) {
    final alto = (json['canonicalHeight'] as num).toDouble();
    final perfil = json['profile'] as Map<String, dynamic>?;

    InstructorRig? perfilRig;
    if (perfil != null) {
      try {
        // El bloque de perfil no repite `canonicalHeight`: es la misma figura
        // canónica medida de costado, así que hereda la del padre.
        perfilRig = InstructorRig._desde(perfil, alto);
      } catch (e) {
        // Un perfil ilegible cuesta la entrada caminando y nada más. Dejarlo
        // propagar costaría el rig de frente, que es TODO lo que el tutorial
        // dibuja el resto del tiempo.
        AppLogger.warn(
          'InstructorRig',
          'Bloque de perfil inservible; la entrada cae al rig de frente',
          e,
        );
      }
    }

    return InstructorRig._desde(json, alto, perfil: perfilRig);
  }

  factory InstructorRig._desde(
    Map<String, dynamic> json,
    double canonicalHeight, {
    InstructorRig? perfil,
  }) {
    final bones = (json['pieces'] as List)
        .cast<Map<String, dynamic>>()
        .map(InstructorBone.fromJson)
        .toList();

    final porNombre = {for (final b in bones) b.name: b};
    for (final b in bones) {
      if (b.parent != null && !porNombre.containsKey(b.parent)) {
        throw FormatException(
          'El hueso "${b.name}" cuelga de "${b.parent}", que no existe.',
        );
      }
    }
    // Un ciclo colgaría el solver en una recursión infinita, así que se
    // rechaza al cargar en vez de al dibujar.
    for (final b in bones) {
      final vistos = <String>{};
      String? cur = b.name;
      while (cur != null) {
        if (!vistos.add(cur)) {
          throw FormatException('Ciclo en la jerarquía del rig en "${b.name}".');
        }
        cur = porNombre[cur]?.parent;
      }
    }

    return InstructorRig._(
      bones,
      canonicalHeight,
      (json['aspect'] as num).toDouble(),
      perfil,
    );
  }

  InstructorBone? byName(String n) => _byName[n];

  /// De atrás hacia adelante.
  List<InstructorBone> get drawOrder => List.unmodifiable(_drawOrder);
}

/// Carga el rig frontal desde el manifest empaquetado.
Future<InstructorRig> loadInstructorRig({
  String asset = 'assets/images/instructor/manifest.json',
  AssetBundle? bundle,
}) async {
  final raw = await (bundle ?? rootBundle).loadString(asset);
  return InstructorRig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
