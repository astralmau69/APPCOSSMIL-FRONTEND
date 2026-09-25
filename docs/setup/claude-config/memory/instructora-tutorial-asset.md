---
name: instructora-tutorial-asset
description: La instructora del tutorial es un RIG de recortes (avatar v2), no un juego de láminas; pipeline, unidades y trampas de test.
metadata:
  node_type: memory
  type: project
  originSessionId: cb8b2af5-6fd0-4bc5-9965-ab26af88d43d
  modified: 2026-09-25T00:00:00.000Z
---

**Desde el 25 sep 2026 la instructora es un RIG de recortes articulado** (avatar v2:
casco táctico + antiparras ámbar), no un juego de PNG de cuerpo entero. El set
anterior (`assets/images/instructora_*.png`, 16 láminas) y sus tres scripts
(`extract_instructor_frames.py`, `build_instructor_poses.py`,
`build_instructor_walk.py`) fueron RETIRADOS: no volver a buscarlos.

**Por qué se cambió — la lección que sigue valiendo.** Un fundido cruzado entre dos
dibujos distintos es una disolvencia, no movimiento: la tablet se desvanece en el
aire y el brazo se materializa arriba. Con láminas enteras eso no tiene arreglo
(sólo cuadros intermedios), y encima cada pose recortada a su propio bbox hacía que
la cabeza cambiara de tamaño entre poses. Un rig interpola de verdad, así que el
problema desaparece por construcción.

**Arte:** `tools/build_instructor_v2.py` corta las 6 láminas de `tools/instructor_v2_src/`
en 34 piezas con pivote + `manifest.json` (figura canónica 800 px, 256 colores,
~242 KB de 450 KB de presupuesto). `tools/verify_instructor_v2.py` es el que manda:
cobertura, solape por par, peso y halos. Las imágenes de control `_control.png` y
`_control_perfil.png` recomponen la figura para mirarla.

**Código** (`lib/core/animations/instructor/`), cinco unidades puras:
`InstructorRig`/`InstructorBone` (datos + manifest), `InstructorClip`/`BoneKey`
(keyframes), `InstructorClips` (catálogo: idle, gestos, speak, `walkCycle`),
`solveInstructorPose` (solver puro, capas ADITIVAS: un gesto toca tres huesos y el
torso sigue respirando debajo) e `InstructorRigView` + painter. `TutorialInstructor`
conservó su API pública exacta.

- La entrada caminando usa un rig HERMANO, `InstructorRig.profile` (la misma figura
  de costado, mira a la derecha), con dos zancadas de `InstructorClips.walkCycle`.
- La proporción de la figura sale del manifest: `TutorialInstructor.aspecto`. No
  escribirla a mano (el coach tenía 0.58, del set viejo).

**Trampas de test, todas por la zona fake-async** (ninguna es bug de producción):
- `precacheInstructorRig` va ANTES de `pumpWidget`. Al revés, el widget cachea el
  Future del rig en la zona falsa y el `runAsync` posterior espera para siempre.
- `rootBundle` cachea el Future CON su zona: si un `test()` plano ya pidió el
  manifest, el `testWidgets` siguiente necesita abrir con `tester.runAsync`.
- `build/unit_test_assets` copia pero NO poda: un asset borrado sigue "en el bundle"
  hasta el próximo clean. Los tests que verifican retiros miran el repo, no el bundle.
- Volcador de fotogramas para mirar la animación sin dispositivo:
  `flutter test --tags frames --run-skipped test/core/tutorial_instructor_frames_test.dart`
  (escribe PNG en `.dart_tool/instructor_frames`).

Relacionado: [[animaciones-parar-bucles-sin-saltos]], [[tutorial-flow-system]].
