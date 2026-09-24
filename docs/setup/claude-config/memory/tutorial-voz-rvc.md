---
name: tutorial-voz-rvc
description: "Pipeline para dar voz (RVC v2) a la instructora del tutorial; guion, dataset y receta en tools/rvc."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 7d00141f-c119-4a05-8a21-72cbae719de7
  modified: 2026-09-24T01:01:51.687Z
---

El usuario quiere que la instructora del tutorial DIGA cada paso con la misma
voz que las locuciones `vof` (assets/vof/*.mp3), vía **RVC v2** (conversión de
voz open-source, gratis) — decidido el 22 jul 2026.

RVC NO corre en esta máquina (sin PyTorch/GPU/internet); se entrena/convierte en
Colab. Todo lo previo quedó preparado en **`tools/rvc/`**:
- `prep_dataset.sh` — vof → WAV mono 44.1k normalizado (ffmpeg). ~1 min de voz
  (7 clips): sirve pero conviene sumar más grabaciones de la misma voz.
- `tutorial_lines.md` / `.json` — guion: 19 líneas con id = nombre de archivo
  final (`invite`, `ficha_00..07`, `calendario_00..04`, `tramites_00..04`). El
  texto sale de las burbujas del coach; si cambia una burbuja, regenerar su clip.
- `gen_source_tts.py` — narración FUENTE con edge-tts (gratis) para que RVC solo
  cambie el timbre. `README.md` tiene la receta completa (train → source → batch
  convert → clips).

**Enganche en la app YA cableado (22 jul 2026):**
- `core/services/tutorial_voice.dart` — `TutorialVoice.play(id)` reproduce
  `assets/vof_tutorial/<id>.mp3` (patrón audioplayers como las vof). **Desde el
  27 jul 2026 devuelve `VoiceClip?` = `({Duration duration, int token})`, no un
  `Duration?`.** El `token` existe porque el `AudioPlayer` es un singleton
  estático y en los recorridos push conviven VARIOS coaches montados (la
  pantalla anterior no se destruye al hacer push): sin él, el `complete` del
  clip anterior apagaba el gesto de habla del paso nuevo, y un `play()` que
  resolvía tarde sincronizaba la coreografía con la duración del clip
  equivocado. `onComplete` es `Stream<int>` y emite el token; compáralo con
  `TutorialVoice.currentToken` antes de reaccionar. `play` y `stop` lo
  incrementan. `enabled` = botón de silencio.
- `voiceId` por paso ya pasado desde: home `_homeVoiceId` (`<recorrido>_00`),
  booking `_coachVoiceId` (`ficha_01..07`), los 7 `TutorialFlowHost` de
  calendario/procedimientos (`calendario_01..04`, `tramites_01..04`), e invite.
- **Clips reales YA en su sitio (24 jul 2026):** los 19 mp3 (RVC) llegaron a
  `assets/vof_tutorial/vof_tutorial/*.mp3` (anidados por error, + un zip
  suelto); se reubicaron a `assets/vof_tutorial/*.mp3` — que es donde
  `TutorialVoice.play()` los busca — y se borraron la subcarpeta y el zip.
  IDs verificados contra los 11 `voiceId` grep-eados en pantallas: todos
  calzan. `flutter pub get` corrió limpio. Falta: probar en dispositivo real
  que cada clip suena (nunca se verificó con audio real, solo con el gating
  silencioso). Si en una sesión futura aparecen mp3 nuevos del pipeline RVC,
  revisar que caigan directo en `assets/vof_tutorial/`, no en una subcarpeta.
- **Gating audio-primero (req):** el coach dispara `play()` y SOLO si hay duración
  enciende `_speaking`+`_speakDuration`; sin clip → no cambia el estado (la
  instructora no "habla").
- **Lip-sync de pose:** con `speaking`, `TutorialInstructor` alterna celebra↔festeja
  vía el controller `_talk` cuya duración = la del audio (una pasada; ~1 swap/seg,
  clamp 2..10). Al terminar el audio (`onComplete`) vuelve a su pose. Fundidos
  suaves easeInOutCubic ~180 ms en el AnimatedSwitcher (adiós al timer abrupto de
  950 ms). Sin audio, la celebración alterna en bucle igual.
- OJO tonal: hoy la anim de "hablar" son poses de festejo (check/risa) para TODAS
  las líneas — puede quedar raro celebrando en pasos serios; se puede cambiar a un
  set explica-based. La caminata es la ENTRADA (no un loop idle perpetuo, decisión
  deliberada). Falta ver en dispositivo con clips reales.
**Modo Guiado (nuevo, 22 sep 2026 — rama `preTutorial`):** además del tutorial-demo
(que se CONSERVA), se diseñó un "Modo Guiado" = reserva REAL narrada. Al tocar
"Nueva Reserva" saldrá una hoja con 2 tarjetas (Clásico/Guiado). El guiado se ve
IGUAL al clásico (sin alto contraste); solo agrega instructora+voz+burbujas que no
tapan opciones; crea cita real (no mockea, no bloquea). Arquitectura: bandera
`BookingState.guidedMode` + `TutorialCoachOverlay(narrateOnly:true)` (sin
GuidedTapHint). Voces nuevas `guiado_*` (intro, regional, especialidad, medico,
dia, hora, confirmar, final) YA agregadas a `tools/rvc/tutorial_lines.{md,json}`
en tono profesional/institucional militar, trato de usted. Falta: generarlas en
Colab (reentrenar, no se sabe si el .pth sigue en Drive) y colocarlas en
`assets/vof_tutorial/`. Spec: `docs/superpowers/specs/2026-09-22-modo-guiado-reserva-design.md`;
plan TDD: `docs/superpowers/plans/2026-09-22-modo-guiado-reserva.md`.
**Notebook Colab autocontenido (23 sep 2026, rama `v1`):**
`tools/rvc/COSSMIL_voces_guiado.ipynb` — trae las 7 vof en base64 + las 27 líneas
del guion embebidas (cero subidas); "Ejecutar todo" → ZIP plano de mp3. Se genera
con `tools/rvc/build_colab_notebook.py` (editar ESE script, no el .ipynb, y
regenerar). Lecciones de la 1ª corrida en Colab: (1) `subprocess.run` NO muestra
salida en la celda → se usa Popen + print en vivo; (2) el Applio actual usa CLI
Click/Typer: `--help` (no `-h`) y probablemente flags con guion (`--model-name`)
→ el helper `applio()` lee `<cmd> --help` y adapta `_`↔`-`, omitiendo opcionales
inexistentes; (3) los "dependency conflicts" rojos de pip en Colab son inocuos.
La versión adaptativa AÚN NO se probó en Colab: si falla, pedir el error y el
bloque `===== preprocess =====` de la celda 3. Decisión por defecto
`SOLO_GUIADO=False` (regenerar las 27 para que toda la app quede con la misma
voz, porque el modelo se reentrena). El `.pth` anterior no se ubicó; si aparece,
copiarlo con su `.index` a `MyDrive/cossmil_rvc/modelo/` y la celda 5 no reentrena.
**Bug a arreglar (parte del plan):** `ficha_01` (regional) no suena en el demo por
la carrera Inicio→Reserva (el `stop()` del coach que se desmonta mata el clip
entrante); fix = `TutorialVoice.stopIfToken(token)` y comparar en `dispose`.

Relacionado: [[tutorial-flow-system]], [[instructora-tutorial-asset]], [[entorno-claude-code-replica]].
