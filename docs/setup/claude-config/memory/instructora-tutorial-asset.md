---
name: instructora-tutorial-asset
description: Origen y pipeline del asset instructora_tutorial.png (mascota del tutorial); el mascot CustomPainter fue reemplazado por este PNG.
metadata: 
  node_type: memory
  type: project
  originSessionId: cb8b2af5-6fd0-4bc5-9965-ab26af88d43d
  modified: 2026-07-27T16:53:48.990Z
---

`assets/images/instructora_tutorial.png` (457×750, PNG8 con alfa, ~77 KB) nació de
`~/Downloads/Gemini_Generated_Image_rspilfrspilfrspi.png` (jul 2026): la IA generó el
fondo de tablero de ajedrez FALSO (horneado, sin alfa real). Se limpió con PIL:
flood-fill desde los bordes (ojo: `thresh` de PIL compara la SUMA de los 3 canales —
blanco vs gris ≈ 132, usar ~150) + limpieza de islas (el centinela del segundo fill
debe quedar FUERA del thresh vs la semilla o PIL aborta en silencio) + cuantizado
FASTOCTREE 256 colores (559→77 KB sin pérdida visible).

Widget: `TutorialInstructor` en `core/widgets/tutorial_instructor.dart` (flote/celebrate/
entrance, solo transform+opacidad, reduce-motion). Reemplazó al `TutorialMascot` de
CustomPainter. El antiguo `tutorial_mode_banner.dart` fue sustituido por
`tutorial_coach_overlay.dart` (coach flotante abajo-izquierda con burbujas de chat),
montado UNA sola vez en `BookingFlowScreen` (fuera del AnimatedSwitcher de pasos) —
las 6 pantallas del flujo ya no tienen banner propio.
**Actualización 21 jul 2026 — juego de poses.** Aquel PNG único quedó OBSOLETO y SIN USO
(sigue en disco a la espera de que el usuario confirme su borrado). Ahora hay 5 poses en
`assets/images/instructora_{reposo,explica,parpadeo,celebra,saludo}.png` (~700 px de alto,
~70 KB cada una), recortadas de una lámina 2×4 de Gemini con
`tools/extract_instructor_frames.py` (script reproducible: inundación desde los bordes con
predicado "gris y claro", componentes conectados para descartar los números de casilla,
reescalado y cuantizado a 256 colores; el mapa casilla→nombre está en la constante `POSES`).

`TutorialInstructor` recibe ahora un `InstructorPose` en vez de `celebrate`, hace fundido
entre poses y PARPADEA en la pose `explica` (única con gemela de ojos cerrados) a intervalos
irregulares de 2,6–5,8 s. El coach usa `explica` desplegado y `reposo` minimizado; el diálogo
de invitación usa `saludo`.

Queda material sin usar en `~/Downloads/Gemini_Generated_Image_msk116msk116msk1.png`: lámina
4×10 con ciclo de caminata (11–20), pulgar arriba, señalar al frente, radio, dormida y alto
con la mano. Resolución menor (~281×384 por casilla), suficiente para tamaños pequeños.

**Actualización 22 jul 2026 — entra CAMINANDO.** De la lámina grande
`~/Downloads/Gemini_Generated_Image_r8zz8h…png` (2816×1536: giro 360°, expresiones, ciclo de
caminata, acciones) se sacó el ciclo de caminata de perfil (mirando a la derecha) →
`assets/images/instructora_walk_1..7.png` (172×263, ~93 KB los 7) con
`tools/build_instructor_walk.py` (reusa el recorte por componentes de
extract_instructor_frames; `--auto` da el orden, WALK_IDS=[21..27]; alinea por CABEZA
—centro del tercio superior— y PIES —borde inferior—, pad vertical 0 para que la figura
calce con las poses de pie y no "crezca" al parar). Verificado con onion-skin: cabeza quieta,
solo piernas. `TutorialInstructor` ganó `walkIn`: entra desde fuera del borde izquierdo
recorriendo el ciclo (`_walk` controller, 1300 ms, ~2.3 ciclos, easeOutCubic) y al llegar
releva a la pose (`_kWalkSettleFrame=3` = walk_4 con piernas juntas, para que el fundido no
salte); el Image va DENTRO del AnimatedBuilder (fotograma por frame) y el AnimatedSwitcher usa
duration 0 mientras camina (swaps nítidos). El coach pasa `walkIn: !celebrate`. Respeta
reduce-motion (aparece parada). `kInstructorWalkFrames` se precarga en didChangeDependencies y
va incluido en `kInstructorAssets`. Falta verlo EN EL DISPOSITIVO (no verificado en vivo).

**Poses expresivas nuevas (22 jul 2026).** De la lámina `~/Downloads/…6fesow…png` (2816×1536,
~120 poses: giro, expresiones, pizarra "Enemigo/Aliado" —NO usar en app médica—, hologramas,
gestos) se sacaron con `tools/build_instructor_poses.py` (POSES={38:'piensa',39:'festeja'},
índices del volcado `--auto`, escala 520 px):
- `instructora_piensa.png` (dedo/ojos cerrados, pensativa): el coach la usa mientras muestra el
  indicador de "escribiendo…" (pose = celebra? : !expanded? reposo : typing? piensa : explica).
  El estado `_typing` de `_CoachBubbles` sube al overlay por callback `onTyping`.
- `instructora_festeja.png` (riendo, mano en alto): al celebrar, `TutorialInstructor` ALTERNA
  celebra↔festeja con `_celebrateTimer` (950 ms) para que el festejo no sea una lámina fija.
Ojo: como la instructora vive en la esquina, la pose "señala al piso" (p40) NO se usó (no
apunta al objetivo). Quedan sin usar muchos gestos (sorpresa p32, alto/stop p36, hologramas
p26-30) por si se quieren gestos por-paso.

**27 jul 2026 — el salto de tamaño, medido.** Esa mezcla de dos láminas tenía un
coste real: como cada pose se recorta a su propio bbox y el widget dibuja con
`height: h`, a igual altura de render la boina de `piensa`/`festeja` salía **~10%
más grande** que la del resto. La instructora pegaba un salto de tamaño en CADA
cambio de pose — y `explica→piensa` ocurre entre cada par de burbujas.
Medido con tres métricas; las dos válidas coinciden dentro del 1% (ancho de
cabeza 0.905/0.916, ancho de boina 0.916/0.907). La tercera (altura de cabeza
hasta el cuello) se DESCARTA: se rompe cuando un brazo o la tablet tapan el
cuello, y daba 1.196x para `celebra`, que es el mismo dibujo que `explica`.
Parche vivo: `_kPoseScale = {piensa: 0.91, festeja: 0.91}` en
`tutorial_instructor.dart`, más un `layoutBuilder` bottomCenter en el
AnimatedSwitcher (el apilado por defecto centra, y con alturas distintas los
pies se despegaban durante el fundido). Test de regresión con dientes
verificados en `test/core/tutorial_instructor_test.dart` ("la boina mide lo
mismo en todas las poses"): sin la corrección falla con 9.2%.
Los 7 fotogramas de caminata NO tienen este problema (lienzo común 172x263) —
no tocarlos; la métrica de boina no aplica ahí porque de perfil la coleta
ensancha la silueta.

**Límite estructural:** un fundido cruzado entre dos dibujos distintos es una
disolvencia, no movimiento (la tablet se desvanece en el aire, el brazo se
materializa arriba). Solo lo arreglan cuadros intermedios — prompts listos en
`tools/instructor_prompts.md`. Paliativo aplicado: golpe de compresión+rebote
de 260 ms sobre cada cambio de pose (`_swap`), anclado en los pies.

Relacionado: [[animaciones-parar-bucles-sin-saltos]].
