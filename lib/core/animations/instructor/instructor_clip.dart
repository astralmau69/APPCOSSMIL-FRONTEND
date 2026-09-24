import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Lo que una capa le hace a un hueso en un instante: girarlo, correrlo y
/// escalarlo. Las capas se SUMAN, por eso el neutro es rot 0 / translate 0 /
/// scale 1 y [addWeighted] suma `scale - 1`.
class BoneTransform {
  final double rot;
  final Offset translate;
  final double scale;

  const BoneTransform({
    this.rot = 0,
    this.translate = Offset.zero,
    this.scale = 1,
  });

  static const identity = BoneTransform();

  BoneTransform addWeighted(BoneTransform o, double w) => BoneTransform(
    rot: rot + o.rot * w,
    translate: translate + o.translate * w,
    scale: scale + (o.scale - 1) * w,
  );
}

/// Un keyframe. [t] va de 0 a 1 sobre la duración del clip, y [curve] es la
/// interpolación HACIA este keyframe desde el anterior.
class BoneKey {
  final double t;
  final double rot;
  final Offset translate;
  final double scale;
  final Curve curve;

  const BoneKey({
    required this.t,
    this.rot = 0,
    this.translate = Offset.zero,
    this.scale = 1,
    this.curve = Curves.linear,
  });
}

/// Una animación: qué le pasa a cada hueso a lo largo del tiempo.
///
/// Un clip declara SÓLO los huesos que toca. Eso es lo que permite que un gesto
/// mueva el brazo mientras el torso sigue respirando en otra capa.
class InstructorClip {
  final String name;
  final Duration duration;
  final bool loop;
  final Map<String, List<BoneKey>> tracks;

  const InstructorClip({
    required this.name,
    required this.duration,
    required this.tracks,
    this.loop = false,
  });
}

/// Un clip aplicándose ahora mismo, en el instante [t] (0..1) y con [weight].
class ClipLayer {
  final InstructorClip clip;
  final double t;
  final double weight;

  const ClipLayer({required this.clip, required this.t, this.weight = 1.0});
}

/// Muestrea una pista en [t]. Fuera de rango devuelve el keyframe extremo.
BoneTransform sampleTrack(List<BoneKey> keys, double t) {
  if (keys.isEmpty) return BoneTransform.identity;

  BoneTransform de(BoneKey k) =>
      BoneTransform(rot: k.rot, translate: k.translate, scale: k.scale);

  if (t <= keys.first.t) return de(keys.first);
  if (t >= keys.last.t) return de(keys.last);

  for (var i = 0; i < keys.length - 1; i++) {
    final a = keys[i];
    final b = keys[i + 1];
    if (t >= a.t && t <= b.t) {
      final span = b.t - a.t;
      final crudo = span <= 0 ? 1.0 : (t - a.t) / span;
      final k = b.curve.transform(crudo.clamp(0.0, 1.0));
      return BoneTransform(
        rot: a.rot + (b.rot - a.rot) * k,
        translate: Offset.lerp(a.translate, b.translate, k)!,
        scale: a.scale + (b.scale - a.scale) * k,
      );
    }
  }
  return BoneTransform.identity;
}
