---
name: animaciones-parar-bucles-sin-saltos
description: "Cómo apagar un AnimationController en bucle sin que la figura salte, y la trampa de AnimatedSize con Duration.zero."
metadata: 
  node_type: memory
  type: project
  originSessionId: 07deeea5-7840-4029-9e15-191457bb3ecb
  modified: 2026-07-27T17:45:47.925Z
---

Dos patrones aprendidos arreglando los tirones del coach del tutorial
(27 jul 2026, `core/widgets/tutorial_instructor.dart` y `tutorial_coach_overlay.dart`).

**1. Nunca apagues un bucle senoidal con `ctrl.value = 0`.**
Los bucles de flote/cabeceo mapean `value` a una fase `value * 2π`. Cortar con
`stop()` + `value = 0` teletransporta la figura desde donde estuviera — era el
tirón más visible del coach (al minimizarse, al callar la voz, al cambiar de
pose). Igual de malo: `repeat()` sobre un controller YA animando, porque
reinicia la fase a 0.

**Why:** la fase 1 dibuja exactamente lo mismo que la fase 0 (`sin 2π = sin 0`),
así que dejar correr lo que falta del ciclo es indistinguible del reposo pero
continuo.

**How to apply:** helper `_settle(ctrl, onSettled:)` que hace
`animateTo(1.0, duration: ctrl.duration * (1 - ctrl.value), curve: linear)` y
encadena `whenComplete` → vuelve a llamar al propio `_sync*()`, que decide si
reanudar con la cadencia nueva. Las funciones `_sync*` quedan idempotentes y
comparan `ctrl.duration != periodoDeseado` en vez de recibir un `forceRestart`.

**2. `AnimatedSize` con `duration: Duration.zero` revienta en layout.**
Assertion "A RenderAnimatedSize was mutated in its own performLayout
implementation": `RenderAnimatedSize._layoutStable` llama `_controller.forward()`,
que con duración cero completa síncronamente y dispara `markNeedsLayout` sobre
el RenderObject que se está midiendo.

**Why:** el patrón habitual `duration: reduceMotion ? Duration.zero : X` —
correcto en `AnimatedOpacity`/`AnimatedScale`— es una bomba en `AnimatedSize`.

**How to apply:** en modo instantáneo NO envuelvas; devuelve el hijo crudo
(`if (_instant) return child;`). Y usa `clipBehavior: Clip.none` si el contenido
tiene colitas o sombras que sobresalen (el default recorta).

**3. No FUNDAS entre dos dibujos distintos: CORTA.**
El `AnimatedSwitcher` de 180 ms entre poses superponía los dos dibujos durante
~11 fotogramas a 60 fps: se veían DOS boinas, DOS coletas y DOS caras a la vez.
Esa doble exposición era lo que el usuario reportaba como "no fluido", y ninguna
corrección de escala ni de curvas la arreglaba.

**Why:** la animación 2D nunca disuelve entre poses. Corta en el fotograma clave
y esconde el cambio en el extremo de la deformación; el ojo lee el corte como
movimiento rápido, pero lee la disolvencia como un fantasma.

**How to apply:** fuera el AnimatedSwitcher, un solo `Image`. El relevo se
retiene hasta el pico de compresión de un controlador de "golpe"
(`_kSwapCut = 0.32` de 260 ms ≈ 83 ms) y ahí cambia de golpe, con squash del 8%
en alto / 5.5% en ancho anclado en los pies. Ojo: eso RETRASA el cambio de pose
~83 ms, y hay un test que codificaba el relevo inmediato — hubo que añadirle un
pump extra.

**4. Para VER la animación sin dispositivo:** `RepaintBoundary` + `toImage()`
dentro de un widget test, volcando un PNG por frame. Está en
`test/core/tutorial_instructor_frames_test.dart` (tag `frames`, no corre en la
suite normal). Dos trampas: hay que `precacheImage` dentro de `tester.runAsync`
o los PNG salen vacíos, y el capturado sale con ALFA (el fondo del árbol queda
fuera del boundary) — usar el canal alfa como silueta para medir, no
"no-blanco". Con eso se mide boina y línea de pisada cuadro a cuadro y la
fluidez deja de ser opinión.

Relacionado: [[tutorial-voz-rvc]], [[tutorial-flow-system]], [[sintomas-vs-causa-ui]],
[[instructora-tutorial-asset]].
