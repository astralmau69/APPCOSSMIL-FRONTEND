# Avatar v2 de la instructora — rig de recortes

**Fecha:** 2026-09-23
**Rama:** `v1`
**Estado:** diseño aprobado — 5 secciones, sin riesgos de arte abiertos

## Objetivo

Reemplazar por completo el avatar de la instructora del **tutorial** (hoy:
boina verde, coleta, tablet, 17 PNG de cuerpo entero) por el personaje nuevo
—casco táctico tan con antiparras ámbar— animado con un **rig de recortes**
que interpola movimiento real en tiempo de ejecución, en vez de fundir dibujos
enteros.

El Modo Guiado se diseña aparte, más adelante. Esto cubre sólo el tutorial.

## Por qué no alcanza con más dibujos

El techo del sistema actual está documentado en la memoria del proyecto
[[instructora-tutorial-asset]]:

> Un fundido cruzado entre dos dibujos distintos es una disolvencia, no
> movimiento (la tablet se desvanece en el aire, el brazo se materializa
> arriba). Sólo lo arreglan cuadros intermedios.

Con el repertorio ampliado que se decidió (gestos por paso, reacciones), el
número de dibujos necesarios explota y el resultado sigue siendo una
disolvencia. Un rig articulado resuelve la causa: el movimiento se calcula,
no se dibuja.

## Decisiones ya tomadas

| Decisión | Valor | Cuándo |
|---|---|---|
| Fidelidad del personaje | Mixto: cara fiel como textura, cuerpo riggeado por piezas | Pregunta 1 |
| Repertorio | Ampliado: idle, parpadeo, hablar, señalar, pensar, celebrar, caminar, gestos por paso, reacciones | Pregunta 2 |
| Runtime de animación | Rig de recortes en Flutter puro, sin dependencias nuevas | Elección de enfoque (A sobre Rive) |
| Origen del arte | Generado con ChatGPT contra prompts versionados, evaluado por medición antes de integrar | Requisito del usuario |
| Alcance | Sólo el tutorial. El Modo Guiado va aparte | Este documento |

## Estado del arte (assets)

Las seis láminas fuente están aprobadas y versionadas en
`tools/instructor_v2_src/`. Los prompts que las produjeron y los criterios de
evaluación están en `tools/instructor_v2_prompts.md`. Detalle de cada lámina y
su medición: `tools/instructor_v2_src/README.md`.

---

## Índice de secciones

| # | Sección | Estado |
|---|---|---|
| 1 | Arquitectura: qué se reemplaza y por dónde corta | **Aprobada** |
| 2 | Pipeline de corte: de las láminas a las piezas | **Aprobada** |
| 3 | El rig en Dart: huesos, clips y solver | **Aprobada** |
| 4 | Animaciones y timing | **Aprobada** |
| 5 | Integración, tests y retiro del avatar viejo | **Aprobada** |

---

## Sección 1 — Arquitectura: qué se reemplaza y por dónde corta

**Estado: aprobada.**

### La costura

`TutorialInstructor` expone hoy una API limpia:

```dart
TutorialInstructor({height, pose, entrance, walkIn, idle, speaking, speakDuration})
```

**Esa API se conserva tal cual.** Los tres consumidores
(`tutorial_coach_overlay.dart`, `tutorial_invite_dialog.dart` y el propio
widget) siguen llamándola igual. Lo que cambia son las tripas: hoy adentro hay
un `AnimatedSwitcher` que funde PNG de cuerpo entero; pasa a haber un
renderizador de recortes articulados.

Esto importa porque el coach tiene lógica delicada y ya sufrida —el `_settle()`
de los bucles senoidales, el cabeceo al hablar, el parpadeo irregular
(ver [[animaciones-parar-bucles-sin-saltos]])—. Nada de eso se toca ni se
reescribe. Sólo cambia *qué se dibuja* cuando el estado dice "explica".

### Las piezas nuevas

Cinco unidades, cada una con un trabajo y testeable por separado:

| Unidad | Qué hace | Depende de |
|---|---|---|
| `InstructorRig` | El esqueleto: lista de piezas, pivotes, jerarquía padre/hijo, transformación en reposo. Datos puros, sin Flutter | nada |
| `InstructorClip` | Una animación: pistas de keyframes por hueso, con su curva. Datos puros | nada |
| `solveInstructorPose` | Dado un clip y un tiempo `t`, calcula la matriz de cada hueso. Función pura | rig + clip |
| `InstructorRigView` | Dibuja las piezas aplicando esas matrices. Widget tonto | solver |
| `TutorialInstructor` | La capa pública de siempre: traduce `pose`/`speaking`/`idle` a clips y los mezcla | todo lo anterior |

El motivo del corte es el testeo. Con el solver como función pura se puede
afirmar *"a los 240 ms el antebrazo derecho está a 42° y la cabeza no se
movió"* sin renderizar un píxel. Encaja con cómo ya testea este repo: hoy hay
un test que mide que la boina tenga el mismo tamaño en todas las poses, y falla
con 9.2% si se saca la corrección.

### Dónde viven

- `lib/core/animations/instructor/` → rig, clips, solver (datos y lógica)
- `lib/core/widgets/tutorial_instructor.dart` → la capa pública, reescrita por dentro
- `assets/images/instructor/` → las piezas nuevas, en carpeta propia

Los 17 PNG viejos (`instructora_*.png`) y sus tres scripts de extracción se
retiran **al final**, no al principio: el set nuevo tiene que estar funcionando
antes de tirar el que anda.

### Lo que el enum gana

Para el repertorio ampliado, `InstructorPose` suma `señala`, `pulgarArriba`,
`alto` y `sorpresa`. Con un rig, cada una es un archivo de keyframes, no un
dibujo nuevo. Ese es el ahorro real de riggear: los gestos salen casi gratis, el
costo está en las piezas y en afinar el timing.

---

## Sección 2 — Pipeline de corte: de las láminas a las piezas

**Estado: aprobada.**

### Anatomía medida de la A-pose

Todo lo que sigue se apoya en estas medidas, no en estimaciones a ojo. Los
porcentajes son sobre la altura de la figura (1490 px nativos).

| Landmark | Altura | Evidencia |
|---|---|---|
| Casco, ancho máximo | 14% | 413 px |
| Estrechamiento del cuello | 26% | 162 px |
| Línea de hombro | 29% | el ancho salta de 162 a 361 px |
| Brazos despegados del torso | 42% | 3 tramos por fila: `176-313 │ 351-686 │ 710-848` |
| Fin de las manos | 58% | vuelve a 1 tramo desde el 60% |
| Entrepierna | 62% | se parte en 2: `282-506 │ 518-744` |
| Rodilleras | ~73% | posición de las placas |

Hallazgo aprovechable: **la antena de la radio es un blob independiente**
(x 623-636, entre el 22% y el 26%). Se corta como pieza propia y recibe
movimiento secundario, que es de las cosas que más venden la fluidez.

### La cabeza sale de la Lámina 1, no de la A-pose

Corrección sobre lo planteado en la Sección 1. Montar los ojos de la Lámina 1
sobre la cabeza de la A-pose significa registrar dos dibujos hechos por
separado: los ojos pueden caer corridos y no hay forma de medir cuánto.

La Lámina 1, en cambio, tiene **0.0% de deriva** entre sus 6 casillas y la
corona dentro de 1 px: sus variantes están perfectamente registradas **entre
sí**. Por lo tanto la cabeza se toma de la Lámina 1 casilla #1 y la A-pose
aporta sólo el cuerpo. El registro de ojos y boca queda exacto por
construcción, y el único empalme aproximado cae en el cuello — tapado por el
cuello alto verde y el barboquejo, la zona más indulgente del personaje.

**Factor de escala medido:** casco de la A-pose 413 px contra casco de la
Lámina 1 394 px → ×1.048. Pero el factor que se aplica es el del **empalme**,
no el del casco: ver abajo.

### La línea de corte del cuello

Éste era el único riesgo abierto del diseño —el único punto que mezcla dos
dibujos— y se resolvió midiendo, sin arte nuevo.

**Escala del empalme:** el estrechamiento del cuello mide 158 px en la A-pose
(al 24.8% de la figura) y 152 px en la Lámina 1 (al 69.7% de su recorte). El
factor real es **×1.0395**, y es el que se aplica, porque es donde los dos
dibujos se tocan. El ×1.048 del casco queda como dato de contraste.

**Dónde cortar.** Comparando cómo se abre el hombro bajo el cuello en ambos
dibujos, tras aplicar ×1.0395:

| px bajo el cuello | 0 | 6 | 12 | 18 | 24 | 42 | 60 | 84 |
|---|---|---|---|---|---|---|---|---|
| desajuste | 0.0% | 1.7% | 2.3% | 1.4% | 44.4% | 10.2% | 6.6% | 0.3% |

El pico del 44.4% no es diferencia de forma sino **desfase**: los hombros de la
Lámina 1 empiezan a ensancharse unos 6 px antes. Es irrelevante, porque ese
tramo **nunca se compone**: la pieza de cabeza termina arriba y de ahí para
abajo dibuja el torso de la A-pose; los dos tramos nunca quedan adyacentes.

Lo único que importa es el ancho en la línea de corte. **La pieza de cabeza
incluye el cuello alto y termina entre 12 y 18 px por debajo del
estrechamiento** (a escala nativa de la A-pose), donde el desajuste es de
1.4–2.3%. Además la costura cae sobre el contorno oscuro del cuello, que es un
borde duro en ambos dibujos — un corte sobre una línea de contorno no se ve.

**Color en la costura:** RGB(183,149,90) en la A-pose contra RGB(174,142,90) en
la Lámina 1 → 3.5% de diferencia. Imperceptible; la herramienta iguala los
niveles de la pieza de cabeza a los del torso de todos modos.

### Qué pieza sale de dónde

| Pieza | Fuente | Pivote |
|---|---|---|
| cabeza + cuello alto | Lámina 1 #1, ×1.0395 | base del cuello, 24.8% |
| ojos ×5 + medio parpadeo sintético | Lámina 1, recorte fijo | registrados a la cabeza |
| boca ×6 | Lámina 2, normalizada ×1.020 | registrados a la cabeza |
| antena radio | A-pose, blob suelto | base, en el hombro |
| torso | A-pose, 26–62% | cadera |
| brazo superior ×2 | A-pose, 29–45% | hombro |
| antebrazo ×2 | A-pose, 45–58% | codo |
| mano ×4 gestos | Lámina 3, normalizada por muñeca | muñeca |
| muslo ×2 | A-pose, 62–73% | cadera |
| pantorrilla + bota ×2 | A-pose, 73–100% | rodilla |

La Lámina 3 trae un solo brazo (el del lado derecho del espectador). **La mano
izquierda se obtiene espejando**, que en un guante táctico simétrico no se
nota.

### Cómo se corta

**No automático.** Segmentar un dibujo en partes del cuerpo por color o por
componentes conectados no es confiable: el camuflaje tiene el mismo tono en el
brazo y en el torso. Los cortes van como **polígonos en un archivo de
configuración**, escritos a mano mirando la imagen, y la herramienta los
aplica. Reproducible, versionado y ajustable sin regenerar arte. Mismo
principio que `build_instructor_walk.py`, que hoy guarda el mapa
casilla→nombre en la constante `POSES`.

### El agujero del hombro

Al separar el brazo del torso queda atrás un vacío que se vería al rotarlo. La
solución estándar de recortes: **la pieza del brazo se lleva su casquete de
hombro redondeado**, que gira con el brazo y tapa siempre la articulación.
Igual en la cadera con el muslo. Además la herramienta extiende unos píxeles el
borde del torso por debajo, como colchón para ángulos extremos.

### Las caras

1. Normalizar cada casilla contra la #1 por ancho de casco (la Lámina 2 está a
   2.0% de la 1; se corrige exacto porque ambas traen casilla ancla).
2. Recortar sólo la región de ojos y la de boca con un rectángulo fijo
   relativo a la cabeza.
3. **Sintetizar el medio parpadeo** aplastando verticalmente el ojo abierto al
   50%, anclado en el párpado superior — la casilla #3 de la Lámina 1 salió
   duplicada de la #1.

### Resolución canónica y peso

La instructora se dibuja a `min(profileAvatarSize × 1.55, alto × 0.30)`, o sea
entre **124 px lógicos** (teléfono chico) y **186 px** (tablet). A DPR 4 el
peor caso son 744 px físicos.

Las piezas se normalizan a una **figura canónica de 800 px de alto**. Los 1490
px nativos de la A-pose sobran, y bajar a 800 reduce a la mitad la memoria de
texturas sin pérdida visible.

Salida a `assets/images/instructor/`, cuantizada a 256 colores como el resto
del repo. Estimación de peso: 250–400 KB para el set completo, contra los
~700 KB de los 17 PNG actuales.

### Manifest y verificación

La herramienta emite un `manifest.json` con nombre, archivo, pivote, padre y
ángulo de reposo de cada pieza. Ese manifest es lo que consume el rig de la
Sección 3.

Al terminar reporta cuántas piezas, el tamaño de cada una, el peso total, y
genera una **imagen de control** con todas las piezas recompuestas en su pose
de reposo. Si esa recomposición no se ve idéntica a la A-pose original, el
corte está mal y se nota de inmediato.

## Sección 3 — El rig en Dart: huesos, clips y solver

**Estado: aprobada.**

### Lo que NO se reescribe

`_TutorialInstructorState` ya tiene una capa de comportamiento afinada a lo
largo de meses: `_idle` (2600 ms calmo / 1500 ms festejo), `_talk`, `_speak`
(650 ms), `_swap` (260 ms), `_walk` (1300 ms, 2.3 ciclos), el `_blinkTimer` con
separación 2600 ms + jitter 3200 ms y guiño cada 4, y sobre todo el helper
`_settle()` — el patrón que evita el tirón al apagar un bucle senoidal
([[animaciones-parar-bucles-sin-saltos]]).

**Todo eso se conserva tal cual.** Son constantes que costaron sesiones de
ajuste. Lo único que cambia es el consumidor: hoy esos controladores eligen qué
PNG mostrar; a partir de ahora alimentan valores de huesos.

### Datos puros

```dart
class InstructorBone {
  final String name;
  final String? parent;   // null = raíz
  final Offset pivot;     // en la figura canónica de 800 px
  final Offset anchor;    // dónde cae el pivote dentro del PNG de la pieza
  final String asset;
  final int z;            // orden de dibujo
}

class InstructorRig {
  final List<InstructorBone> bones;  // orden topológico
  final Size canvas;
}

class BoneKey {
  final double t;         // 0..1 normalizado sobre la duración del clip
  final double rot;       // radianes
  final Offset translate;
  final double scale;
  final Curve curve;      // tokens de AppCurves
}

class InstructorClip {
  final String name;
  final Duration duration;
  final bool loop;
  final Map<String, List<BoneKey>> tracks;  // hueso -> keyframes
}
```

Ambas clases salen del `manifest.json` que produce la herramienta de corte
(Sección 2). Ningún import de Flutter salvo `Offset`/`Curve`.

### El solver

```dart
Map<String, Matrix4> solveInstructorPose(
  InstructorRig rig,
  List<ClipLayer> layers,   // (clip, t, peso)
);
```

Función pura. Sin estado, sin tiempo propio, sin widgets.

**Capas aditivas.** Cada capa declara sólo los huesos que toca y se suma sobre
la anterior con su peso. Así el gesto de señalar mueve el brazo mientras el
torso sigue respirando, y soltar el gesto no corta la respiración. Es lo que
hace asequible el repertorio ampliado: un gesto nuevo es una capa que toca tres
huesos, no una animación de cuerpo entero.

### El dibujo

`InstructorRigView` es un `CustomPainter` que recorre los huesos por `z` y
llama `canvas.drawImageRect` con la matriz de cada uno. No un `Stack` de
`Transform` + `Image`: con 13 huesos repintando por fotograma, un solo painter
sobre `RepaintBoundary` evita reconstruir árbol de widgets 120 veces por
segundo.

Las piezas se cargan como `ui.Image` en `didChangeDependencies` —igual que hoy
se precachea `kInstructorAssets`— y viven en un `Map<String, ui.Image>`.

### Cómo se testea

El solver es puro, así que se puede afirmar *"a los 240 ms el antebrazo derecho
está a 42° y la cabeza no se movió"* sin renderizar un píxel.

Además, invariantes baratos y valiosos: ningún hueso con padre inexistente, sin
ciclos en la jerarquía, sin `NaN` en ninguna matriz, y todo asset del manifest
existe en disco y está declarado en `pubspec.yaml`.

**Un bug entero desaparece por construcción.** El test vivo
`test/core/tutorial_instructor_test.dart` ("la boina mide lo mismo en todas las
poses") existe porque el set viejo mezclaba dos láminas y la instructora
cambiaba de tamaño al cambiar de pose — falla con 9.2% sin la corrección
`_kPoseScale`. Con un rig hay **una sola cabeza**, así que esa clase de fallo
es imposible. El test se conserva igualmente como guardia de regresión.

---

## Sección 4 — Animaciones y timing

**Estado: aprobada.**

Es la sección que decide si se siente AAA. El rig sólo habilita; lo que
convence es el timing.

### Catálogo de clips

| Clip | Tipo | Duración | Lo dispara |
|---|---|---|---|
| `idle` | bucle base | 2600 ms | `_idle` (ya existe) |
| `idle_party` | bucle base | 1500 ms | `_idle` al celebrar |
| `blink` / `wink` | capa, ojos | 130 / 780 ms | `_blinkTimer` (ya existe) |
| `speak` | capa, cabeza + boca | = duración del clip de voz | `_speak` / `_talk` |
| `señala` | capa, brazo | 620 ms | pose |
| `pulgar_arriba` | capa, brazo | 700 ms | pose |
| `alto` | capa, brazo | 540 ms | pose |
| `piensa` | capa, brazo + cabeza | 800 ms | pose |
| `celebra` | capa, ambos brazos | 900 ms | pose |
| `sorpresa` | capa, cabeza + ojos | 400 ms | pose |
| `walk_in` | rig de perfil | 1300 ms | `_walk` (ya existe) |

### Las cinco reglas de timing

1. **Anticipación.** Antes de que el brazo suba, baja un 8% del recorrido
   durante ~90 ms. Sin esto el movimiento arranca de la nada y se lee mecánico.
2. **Overshoot y asentamiento.** El brazo pasa el objetivo unos 6° y vuelve en
   ~180 ms. `AppCurves` ya tiene `bounce` y `elasticity`.
3. **Follow-through escalonado.** El hombro lidera, el codo llega 60 ms
   después, la muñeca 100 ms. En un rig esto es gratis: se corren los tiempos
   de los keyframes por hueso. Es lo que separa "carne" de "robot".
4. **Movimiento secundario.** La antena de la radio —que salió como pieza
   suelta— se modela como muelle amortiguado alimentado por la velocidad
   angular de la cabeza. Igual la bolsa médica de la cadera. El ojo lo registra
   sin saber por qué.
5. **Nunca simétrico.** Los dos brazos jamás se mueven idénticos; van
   desfasados 40–70 ms. La simetría perfecta es la marca del muñeco.

### Lip-sync

`TutorialVoice.play(id)` devuelve `VoiceClip?` con su duración. Hoy `_talk`
calcula `n = (d.inMilliseconds / 900).round().clamp(1, 12)` cambios de pose;
con las 6 aberturas de boca, esos cambios pasan a ser cambios de sprite,
alternando entre cerrada, poco, mediana y grande con una **semilla fija por
`voiceId`** — determinista, por tanto testeable, y sin la cadencia robótica de
un ciclo fijo. La boca cierra al terminar el clip.

**Límite honesto:** no hay datos de fonemas, así que esto es movimiento de boca
*verosímil*, no lip-sync real. A 150 px de alto y con la voz encima, la
diferencia no se percibe; decirlo igual porque el nombre promete más de lo que
hace.

### Reduce-motion

Todos los bucles apagados, los gestos colapsan a su pose final sin
anticipación ni overshoot, sin movimiento secundario. La app ya respeta esta
preferencia en el resto de sus animaciones y el widget actual también.

### Sobre los 120 fps

Flutter dibuja al refresh del panel; el rig se evalúa por fotograma desde el
`Listenable` combinado. Los 120 fps los pone el dispositivo, no el código. Se
verifica con el overlay de rendimiento en el dispositivo real (Sección 5); no
se promete.

---

## Sección 5 — Integración, tests y retiro del avatar viejo

**Estado: aprobada.**

### Consumidores

`TutorialInstructor` conserva su firma, así que los tres sitios siguen
llamándola igual. Dos cambios puntuales:

- `tutorial_coach_overlay.dart:249` tiene
  `final charW = charH * 0.58; // proporción del asset (405×700)`. La figura
  nueva es 941×1490 → 0.63. Esa constante deja de estar escrita a mano y pasa a
  leerse del manifest, para que no vuelva a desincronizarse del arte.
- `InstructorPose` suma `señala`, `pulgarArriba`, `alto` y `sorpresa`.

### Tests

| Test | Qué protege |
|---|---|
| Solver puro por clip | ángulos y posiciones de hueso en instantes concretos |
| Invariantes del rig | padres existentes, sin ciclos, sin `NaN` |
| Manifest ↔ disco ↔ pubspec | que ninguna pieza falte o quede sin declarar |
| "la cabeza mide lo mismo en todas las poses" | regresión del bug histórico |
| Smoke del widget | monta sin excepciones y respeta reduce-motion |

Los tests de widget necesitan `TestWidgetsFlutterBinding` y el mock de
`flutter_secure_storage`, y doble `pump()` antes de tapear dentro de un
`ScaleTransition` — patrones ya documentados en
[[tests-binding-secure-storage]].

### Verificación en dispositivo

No se da por terminado sin: recorrer el tutorial entero en el teléfono real,
mirar el overlay de rendimiento durante un gesto y durante la caminata, y
comprobar la legibilidad de la cara en el peor caso (`charH` = 124 px lógicos
en teléfono chico).

### Orden de retiro

Estricto, y el borrado va al final:

1. El rig nuevo funciona en el coach.
2. Después en el diálogo de invitación.
3. Recién entonces se borran los 17 `instructora_*.png`, se los saca de
   `kInstructorAssets`, y se retiran `extract_instructor_frames.py`,
   `build_instructor_poses.py` y `build_instructor_walk.py`.
4. Se actualiza la memoria [[instructora-tutorial-asset]], que hoy describe el
   pipeline viejo.

### Riesgos conocidos

- ~~**El empalme del cuello.**~~ **Resuelto por medición**, ver "La línea de
  corte del cuello" en la Sección 2. No requiere arte nuevo.
- ~~**El rig de perfil es pobre.**~~ **Resuelto con `lamina5_perfil_v2.png`**
  (Paso 6): el brazo queda separado en el 59% del torso y en el 95% de la banda
  de brazos, contra 15% y 0% de la v1. La caminata lleva brazos articulados.
  Altura 2.2% por debajo de la frontal, normalizable.
- **El repertorio ampliado es mucho ajuste.** Once clips con anticipación,
  overshoot y desfases no se aciertan a la primera y no hay timeline visual. Se
  afina iterando sobre el dispositivo.
