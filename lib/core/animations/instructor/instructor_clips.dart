import 'package:flutter/painting.dart';

import '../../theme/app_constants.dart';
import 'instructor_clip.dart';

/// El catálogo de animaciones de la instructora.
///
/// Las cinco reglas de timing que hacen que se lea como carne y no como un
/// muñeco articulado:
///
/// 1. **Anticipación** — antes de subir, el brazo baja un poco.
/// 2. **Overshoot y asentamiento** — pasa el objetivo y vuelve.
/// 3. **Follow-through escalonado** — el hombro lidera, el codo llega tarde.
/// 4. **Movimiento secundario** — la antena de la radio llega la última.
/// 5. **Nunca simétrico** — los dos brazos jamás se mueven idénticos.
///
/// Un clip declara SÓLO los huesos que toca: así un gesto mueve el brazo
/// mientras el torso sigue respirando en la capa de abajo.
class InstructorClips {
  const InstructorClips._();

  /// Respiración en reposo. El torso se estira un 1.2%, la cabeza acompaña dos
  /// píxeles, y la antena llega tarde — eso último es lo que lo hace parecer
  /// vivo aunque nadie sepa decir por qué.
  static const idle = InstructorClip(
    name: 'idle',
    duration: Duration(milliseconds: 2600),
    loop: true,
    tracks: {
      'torso': [
        BoneKey(t: 0.0, scale: 1.0),
        BoneKey(t: 0.5, scale: 1.012, curve: AppCurves.smooth),
        BoneKey(t: 1.0, scale: 1.0, curve: AppCurves.smooth),
      ],
      'cabeza': [
        BoneKey(t: 0.0, translate: Offset.zero),
        BoneKey(t: 0.5, translate: Offset(0, -2), curve: AppCurves.smooth),
        BoneKey(t: 1.0, translate: Offset.zero, curve: AppCurves.smooth),
      ],
      'antena': [
        BoneKey(t: 0.0, rot: 0.0),
        BoneKey(t: 0.62, rot: 0.045, curve: AppCurves.smooth),
        BoneKey(t: 1.0, rot: 0.0, curve: AppCurves.smooth),
      ],
      // Los brazos acompañan la respiración, desfasados entre sí: la simetría
      // perfecta es la marca del muñeco.
      'brazo_sup_der': [
        BoneKey(t: 0.0, rot: 0.0),
        BoneKey(t: 0.52, rot: 0.012, curve: AppCurves.smooth),
        BoneKey(t: 1.0, rot: 0.0, curve: AppCurves.smooth),
      ],
      'brazo_sup_izq': [
        BoneKey(t: 0.0, rot: 0.0),
        BoneKey(t: 0.58, rot: -0.014, curve: AppCurves.smooth),
        BoneKey(t: 1.0, rot: 0.0, curve: AppCurves.smooth),
      ],
    },
  );

  /// Igual pero saltarina, para la celebración.
  static const idleParty = InstructorClip(
    name: 'idle_party',
    duration: Duration(milliseconds: 1500),
    loop: true,
    tracks: {
      'torso': [
        BoneKey(t: 0.0, scale: 1.0),
        BoneKey(t: 0.45, scale: 1.022, curve: AppCurves.bounce),
        BoneKey(t: 1.0, scale: 1.0, curve: AppCurves.smooth),
      ],
      'cabeza': [
        BoneKey(t: 0.0, rot: 0.0),
        BoneKey(t: 0.45, rot: 0.03, curve: AppCurves.bounce),
        BoneKey(t: 1.0, rot: 0.0, curve: AppCurves.smooth),
      ],
      'antena': [
        BoneKey(t: 0.0, rot: 0.0),
        BoneKey(t: 0.55, rot: 0.12, curve: AppCurves.smooth),
        BoneKey(t: 1.0, rot: 0.0, curve: AppCurves.smooth),
      ],
    },
  );

  /// Cabeceo mientras habla. No mueve la boca: eso lo hace [mouthSequence]
  /// conmutando sprites, porque una boca no interpola, conmuta.
  static const speak = InstructorClip(
    name: 'speak',
    duration: Duration(milliseconds: 650),
    loop: true,
    tracks: {
      'cabeza': [
        BoneKey(t: 0.0, rot: 0.0),
        BoneKey(t: 0.5, rot: 0.022, curve: AppCurves.smooth),
        BoneKey(t: 1.0, rot: 0.0, curve: AppCurves.smooth),
      ],
    },
  );
}

/// Secuencia de aberturas de boca para una locución.
///
/// **Límite declarado:** no hay datos de fonemas, así que esto es movimiento de
/// boca *verosímil*, no lip-sync real. A 150 px de alto y con la voz encima la
/// diferencia no se percibe, pero conviene decirlo porque el nombre promete más
/// de lo que hace.
///
/// La semilla sale del [voiceId] para que sea determinista —y por tanto
/// testeable— y para que dos pasos distintos no muevan la boca igual. Nunca
/// repite la misma abertura seguida, que es lo que delataría un ciclo fijo, y
/// siempre cierra al final.
List<int> mouthSequence({required String voiceId, required Duration duration}) {
  // ~4,5 aberturas por segundo, acotado para clips muy cortos o muy largos.
  final n = (duration.inMilliseconds / 222).round().clamp(2, 40);
  var seed = 0;
  for (final u in voiceId.codeUnits) {
    seed = (seed * 31 + u) & 0x7fffffff;
  }
  const abiertas = [1, 2, 3, 4];
  final out = <int>[];
  var previa = -1;
  for (var i = 0; i < n - 1; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    var v = abiertas[(seed >> 8) % abiertas.length];
    if (v == previa) v = abiertas[(abiertas.indexOf(v) + 1) % abiertas.length];
    out.add(v);
    previa = v;
  }
  out.add(0); // cierra
  return out;
}

/// Qué sprite de ojos toca según la micro-expresión activa.
enum InstructorEyes { abiertos, medio, cerrados, guino, feliz, sorpresa }

String instructorEyeAsset(InstructorEyes e) => switch (e) {
  InstructorEyes.abiertos => 'ojos_abiertos',
  InstructorEyes.medio => 'ojos_medio',
  InstructorEyes.cerrados => 'ojos_cerrados',
  InstructorEyes.guino => 'ojos_guino',
  InstructorEyes.feliz => 'ojos_feliz',
  InstructorEyes.sorpresa => 'ojos_sorpresa',
};

/// Todos los nombres de hueso que son variantes excluyentes entre sí: de cada
/// grupo se dibuja uno y se ocultan los demás.
const kInstructorEyeBones = [
  'ojos_abiertos',
  'ojos_medio',
  'ojos_cerrados',
  'ojos_guino',
  'ojos_feliz',
  'ojos_sorpresa',
];

const kInstructorMouthBones = [
  'boca_0',
  'boca_1',
  'boca_2',
  'boca_3',
  'boca_4',
  'boca_5',
];

const kInstructorHandBones = [
  'mano_der',
  'mano_g_senala',
  'mano_g_pulgar',
  'mano_g_abierta',
];

/// Los huesos a NO dibujar, dados los tres activos. Se calcula una vez por
/// fotograma y viaja al painter, que simplemente los salta.
Set<String> instructorHidden({
  required String ojos,
  required String boca,
  required String mano,
}) => {
  ...kInstructorEyeBones.where((b) => b != ojos),
  ...kInstructorMouthBones.where((b) => b != boca),
  ...kInstructorHandBones.where((b) => b != mano),
};
