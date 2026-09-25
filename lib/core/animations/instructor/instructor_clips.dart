import 'package:flutter/painting.dart';

import '../../theme/app_constants.dart';
import '../../widgets/tutorial_instructor.dart' show InstructorPose;
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

  /// Señalar hacia el frente-costado.
  ///
  /// Los ángulos NO son a ojo: salen de resolver la cadena hombro-codo para que
  /// la muñeca caiga en un punto concreto de la figura. Tanteados, el brazo
  /// acababa horizontal (una cruz) y la mano fuera del ancho que declara
  /// `aspect`, que es donde el coach recorta.
  ///
  /// Las tres primeras reglas de timing en un solo clip: anticipa bajando, se
  /// pasa del objetivo y se asienta, y el codo arranca 60 ms después que el
  /// hombro (sobre 620 ms, 0,10 de fase).
  static const senala = InstructorClip(
    name: 'senala',
    duration: Duration(milliseconds: 620),
    tracks: {
      'brazo_sup_der': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.15, rot: 0.08, curve: AppCurves.smooth),
        BoneKey(t: 0.62, rot: -0.87, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: -0.83, curve: AppCurves.bounce),
      ],
      'antebrazo_der': [
        BoneKey(t: 0.10, rot: 0.0),
        BoneKey(t: 0.70, rot: -1.85, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: -1.76, curve: AppCurves.bounce),
      ],
      'antena': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.75, rot: -0.09, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.0, curve: AppCurves.bounce),
      ],
    },
  );

  /// Pulgar arriba. Más lento que señalar: es aprobación, no indicación, y la
  /// prisa lo volvería nervioso.
  static const pulgarArriba = InstructorClip(
    name: 'pulgararriba',
    duration: Duration(milliseconds: 700),
    tracks: {
      'brazo_sup_der': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.15, rot: 0.07, curve: AppCurves.smooth),
        BoneKey(t: 0.66, rot: -1.22, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: -1.16, curve: AppCurves.bounce),
      ],
      'antebrazo_der': [
        BoneKey(t: 0.12, rot: 0.0),
        BoneKey(t: 0.74, rot: -2.23, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: -2.12, curve: AppCurves.bounce),
      ],
      'cabeza': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.58, rot: 0.04, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.00, curve: AppCurves.bounce),
      ],
    },
  );

  /// Palma al frente: "espere". El más corto de todos — un alto que tarda no
  /// detiene a nadie.
  static const alto = InstructorClip(
    name: 'alto',
    duration: Duration(milliseconds: 540),
    tracks: {
      'brazo_sup_der': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.15, rot: 0.06, curve: AppCurves.smooth),
        BoneKey(t: 0.58, rot: -1.56, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: -1.49, curve: AppCurves.bounce),
      ],
      'antebrazo_der': [
        BoneKey(t: 0.09, rot: 0.0),
        BoneKey(t: 0.66, rot: -1.71, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: -1.63, curve: AppCurves.bounce),
      ],
      'antena': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.70, rot: -0.11, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.0, curve: AppCurves.bounce),
      ],
    },
  );

  /// Pensar: la mano sube al pecho y la cabeza se ladea.
  ///
  /// La mano NO llega al mentón: con este esqueleto el codo tendría que cruzar
  /// el pecho para lograrlo. Lo que dice "pensativa" son los ojos cerrados y el
  /// ladeo; la mano sólo acompaña.
  static const piensa = InstructorClip(
    name: 'piensa',
    duration: Duration(milliseconds: 800),
    tracks: {
      'brazo_sup_der': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.15, rot: 0.05, curve: AppCurves.smooth),
        BoneKey(t: 0.70, rot: 0.78, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: 0.74, curve: AppCurves.bounce),
      ],
      'antebrazo_der': [
        BoneKey(t: 0.14, rot: 0.0),
        BoneKey(t: 0.78, rot: 3.15, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: 3.00, curve: AppCurves.bounce),
      ],
      'cabeza': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.80, rot: -0.09, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: -0.08, curve: AppCurves.bounce),
      ],
    },
  );

  /// Celebrar. Los dos brazos suben, pero DESFASADOS: el izquierdo arranca
  /// 55 ms después y llega un poco menos alto. La simetría perfecta es lo que
  /// delata a un muñeco.
  static const celebra = InstructorClip(
    name: 'celebra',
    duration: Duration(milliseconds: 900),
    tracks: {
      'brazo_sup_der': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.15, rot: 0.09, curve: AppCurves.smooth),
        BoneKey(t: 0.60, rot: -1.84, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: -1.75, curve: AppCurves.bounce),
      ],
      'antebrazo_der': [
        BoneKey(t: 0.10, rot: 0.0),
        BoneKey(t: 0.68, rot: -1.08, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: -1.03, curve: AppCurves.bounce),
      ],
      'brazo_sup_izq': [
        BoneKey(t: 0.06, rot: 0.0),
        BoneKey(t: 0.19, rot: -0.08, curve: AppCurves.smooth),
        BoneKey(t: 0.67, rot: 1.83, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: 1.74, curve: AppCurves.bounce),
      ],
      'antebrazo_izq': [
        BoneKey(t: 0.16, rot: 0.0),
        BoneKey(t: 0.74, rot: 1.25, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: 1.19, curve: AppCurves.bounce),
      ],
      'cabeza': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.58, rot: -0.05, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.00, curve: AppCurves.bounce),
      ],
      'antena': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.72, rot: 0.16, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.0, curve: AppCurves.bounce),
      ],
    },
  );

  /// Saludo: la mano abierta sube por encima del hombro.
  ///
  /// No es el saludo militar a la boina, y no por gusto: el antebrazo del rig
  /// mide 66 px contra 149 del brazo, así que llevar la mano a la sien obliga
  /// al brazo entero a apuntar hacia arriba y el codo a cruzar la cara. Un
  /// saludo de mano alta sí es alcanzable y se lee igual de bien.
  ///
  /// Antes esta pose no tenía clip: el brazo quedaba en reposo mientras la mano
  /// abierta del gesto flotaba a la altura de la cadera. Y es la primera cosa
  /// que ve un usuario nuevo, en el diálogo de invitación al tutorial.
  static const saludo = InstructorClip(
    name: 'saludo',
    duration: Duration(milliseconds: 720),
    tracks: {
      'brazo_sup_der': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.15, rot: 0.07, curve: AppCurves.smooth),
        BoneKey(t: 0.62, rot: -1.60, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: -1.52, curve: AppCurves.bounce),
      ],
      'antebrazo_der': [
        BoneKey(t: 0.12, rot: 0.0),
        BoneKey(t: 0.72, rot: -1.42, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: -1.35, curve: AppCurves.bounce),
      ],
      'cabeza': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.58, rot: -0.04, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.00, curve: AppCurves.bounce),
      ],
      'antena': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.76, rot: -0.10, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.0, curve: AppCurves.bounce),
      ],
    },
  );

  /// Sorpresa: la cabeza se va atrás de golpe y vuelve. Sólo cabeza y antena;
  /// el cuerpo no reacciona, que es lo que lo hace leerse como un respingo.
  static const sorpresa = InstructorClip(
    name: 'sorpresa',
    duration: Duration(milliseconds: 400),
    tracks: {
      'cabeza': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.30, rot: -0.12, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: 0.0, curve: AppCurves.bounce),
      ],
      'antena': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.42, rot: -0.20, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.0, curve: AppCurves.bounce),
      ],
    },
  );

  /// Ciclo de caminata de PERFIL, para la entrada. Una zancada (dos pasos).
  ///
  /// Tres decisiones que son las que lo hacen leerse como andar y no como un
  /// compás de metrónomo:
  ///
  /// 1. **Arranca en la pose de paso** (piernas juntas, t=0), no en el
  ///    contacto. Así los extremos caen en 0.25 y 0.75, el ciclo cierra con el
  ///    mismo valor con el que abrió, y encadenar zancadas no da ningún salto.
  /// 2. **El brazo va contra la pierna de su lado.** Es lo que cancela la
  ///    torsión al caminar; con brazo y pierna en fase la figura parece un
  ///    juguete de cuerda.
  /// 3. **La rodilla sólo dobla hacia atrás** (rot positivo: la figura mira a
  ///    la derecha) y justo después de despegar el pie, no en el apoyo — una
  ///    pantorrilla que dobla mientras carga el peso es una pierna rota.
  ///
  /// La cabeza y el torso NO figuran a propósito: en una caminata el cráneo se
  /// queda quieto y sólo se mueven las extremidades. Si el torso cabecea, la
  /// entrada parece un salto de canguro.
  static const walkCycle = InstructorClip(
    name: 'walk',
    duration: Duration(milliseconds: 650),
    loop: true,
    tracks: {
      'perfil_muslo_a': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.25, rot: 0.34, curve: AppCurves.smooth),
        BoneKey(t: 0.50, rot: 0.0, curve: AppCurves.smooth),
        BoneKey(t: 0.75, rot: -0.34, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.0, curve: AppCurves.smooth),
      ],
      'perfil_muslo_b': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.25, rot: -0.34, curve: AppCurves.smooth),
        BoneKey(t: 0.50, rot: 0.0, curve: AppCurves.smooth),
        BoneKey(t: 0.75, rot: 0.34, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.0, curve: AppCurves.smooth),
      ],
      // La pierna A queda atrás en 0.25: despega ahí y la rodilla llega a su
      // máximo en 0.45, ya en vuelo.
      'perfil_pantorrilla_a': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.25, rot: 0.05, curve: AppCurves.smooth),
        BoneKey(t: 0.45, rot: 0.46, curve: AppCurves.smooth),
        BoneKey(t: 0.70, rot: 0.0, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.0),
      ],
      // La B es la misma curva media zancada después: en t=0 viene estirando
      // la rodilla de su propio vuelo, por eso no arranca en cero.
      'perfil_pantorrilla_b': [
        BoneKey(t: 0.00, rot: 0.37),
        BoneKey(t: 0.20, rot: 0.0, curve: AppCurves.smooth),
        BoneKey(t: 0.50, rot: 0.0),
        BoneKey(t: 0.75, rot: 0.05, curve: AppCurves.smooth),
        BoneKey(t: 0.95, rot: 0.46, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.37, curve: AppCurves.smooth),
      ],
      'perfil_brazo': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.25, rot: -0.26, curve: AppCurves.smooth),
        BoneKey(t: 0.50, rot: 0.0, curve: AppCurves.smooth),
        BoneKey(t: 0.75, rot: 0.26, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.0, curve: AppCurves.smooth),
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

/// El clip que corresponde a una pose, o `null` si esa pose no gesticula
/// (se queda en la respiración de base).
InstructorClip? clipForPose(InstructorPose p) => switch (p) {
  InstructorPose.senala => InstructorClips.senala,
  InstructorPose.pulgarArriba => InstructorClips.pulgarArriba,
  InstructorPose.alto => InstructorClips.alto,
  InstructorPose.sorpresa => InstructorClips.sorpresa,
  InstructorPose.piensa => InstructorClips.piensa,
  InstructorPose.celebra || InstructorPose.festeja => InstructorClips.celebra,
  InstructorPose.saludo => InstructorClips.saludo,
  InstructorPose.reposo || InstructorPose.explica => null,
};

/// Qué sprite de mano lleva cada pose. Las que no gesticulan usan el puño de
/// la A-pose, que es el que encaja exacto con su antebrazo.
String instructorHandFor(InstructorPose p) => switch (p) {
  InstructorPose.senala => 'mano_g_senala',
  InstructorPose.pulgarArriba => 'mano_g_pulgar',
  InstructorPose.alto || InstructorPose.saludo => 'mano_g_abierta',
  _ => 'mano_der',
};

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
