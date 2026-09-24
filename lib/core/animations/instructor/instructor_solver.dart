import 'package:flutter/widgets.dart' show Matrix4;

import 'instructor_clip.dart';
import 'instructor_rig.dart';

// El tipo de retorno del solver, para que quien lo consuma no tenga que
// importar vector_math (que aquí es dependencia transitiva).
export 'package:flutter/widgets.dart' show Matrix4;

/// Resuelve la pose del rig: para cada hueso, la matriz que lleva del origen
/// del lienzo canónico a su pivote ya rotado y escalado.
///
/// Función PURA: sin estado, sin tiempo propio, sin widgets. Las capas se suman
/// en el orden dado, cada una ponderada por su `weight`; un hueso que ninguna
/// capa declara se queda en reposo.
///
/// Esa aditividad es lo que hace asequible el repertorio ampliado: un gesto
/// nuevo es una capa que toca tres huesos, no una animación de cuerpo entero.
Map<String, Matrix4> solveInstructorPose(
  InstructorRig rig,
  List<ClipLayer> layers,
) {
  final local = <String, BoneTransform>{};
  for (final bone in rig.bones) {
    var acc = BoneTransform.identity;
    for (final layer in layers) {
      final track = layer.clip.tracks[bone.name];
      if (track == null) continue;
      acc = acc.addWeighted(sampleTrack(track, layer.t), layer.weight);
    }
    local[bone.name] = acc;
  }

  final world = <String, Matrix4>{};

  Matrix4 resolver(InstructorBone bone) {
    final cacheado = world[bone.name];
    if (cacheado != null) return cacheado;

    final padre = bone.parent == null ? null : rig.byName(bone.parent!);
    final base = padre == null ? Matrix4.identity() : resolver(padre);

    final t = local[bone.name] ?? BoneTransform.identity;
    final m = base.clone()
      ..translateByDouble(
        bone.pivot.dx + t.translate.dx,
        bone.pivot.dy + t.translate.dy,
        0,
        1,
      )
      ..rotateZ(t.rot)
      ..scaleByDouble(t.scale, t.scale, 1, 1);
    world[bone.name] = m;
    return m;
  }

  for (final bone in rig.bones) {
    resolver(bone);
  }
  return world;
}
