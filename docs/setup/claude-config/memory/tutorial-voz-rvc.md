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
**Estudio de voz (24 sep 2026, rama `v1-dev`):** el notebook anterior
(`COSSMIL_voces_guiado.ipynb`) se reemplazó por `tools/rvc/COSSMIL_estudio_voz.ipynb`:
texto LIBRE → voz de la locutora vof (edge-tts femenina → RVC/Applio). Entrena una
vez; modelo + `huella.txt` (hash del dataset) en `MyDrive/cossmil_rvc/modelo/`; si
cambia el audio en `MyDrive/cossmil_rvc/audio_extra/` reentrena solo. Celdas: 6
CALIBRACIÓN automática (analizar_voz: F0 mediana/ritmo por picos de energía/rango
tonal; vof = ~218 Hz, ~5,5 síl/s, 12,6 st, -16 LUFS, limpias sin música; prueba 14
voces edge-tts femeninas con velocidad/tono igualados, las pasa por RVC y ordena
por similitud WavLM-SV − 0,02·distancia de rasgos; cache `modelo/calibracion.json`
por huella+pth), 7 voces del MODO GUIADO (+tutorial, activa por defecto), 8 estudio
texto libre (`nombre | texto`, `[pausa 1.5]`, `PRONUNCIACION`, ajuste fino sobre la
calibrada), 9 archivo txt/json/csv. Motor en `tools/rvc/estudio_voz_lib.py`
(embebido por `build_colab_notebook.py`; pruebas `test_estudio_voz_lib.py`).
Lecciones Applio (commit fijado `939d9ed`): CLI Click con GUIONES en comandos y
flags (`batch-infer`, NO `batch_infer`; `--model-name`); flags booleanos sin valor
(`--save-only-latest`, `--pretrained`); `core.py` devuelve 0 aunque falle por
dentro → validar archivos en disco; con ~1 min de voz el batch 8 da <3 lotes y
`train` aborta "Not enough data" → batch adaptativo `max(2, min(8, trozos//6))`;
batch-infer nombra la salida `<base>_output.wav`. 1ª corrida real (24 sep, Colab
Python 3.13, torch CUDA 13): preprocess/extract/index OK (49 s de audio → 21 trozos);
`train` cayó por "nvrtc: failed to open libnvrtc-builtins.so.13.0" (TorchScript de
`fused_add_tanh_sigmoid_multiply` en commons.py) → fix: `PYTORCH_JIT=0` (+ libs
nvidia en LD_LIBRARY_PATH) en el ENV de los subprocesos de Applio. 2ª corrida: train OK;
celda 6 cayó con "cannot import name '_slice' from numpy._core.umath": Colab carga
numpy al iniciar el kernel y `uv pip install` de Applio lo cambia en disco → NUNCA
importar numpy/librosa/soundfile/torch/edge-tts en el kernel. El motor se escribe con
`%%writefile /content/estudio_voz_lib.py` y lo pesado corre vía `remoto(fn, *args)`
(subproceso `python estudio_voz_lib.py fn json`, marca `@@RESULTADO@@`).
**Bug a arreglar (parte del plan):** `ficha_01` (regional) no suena en el demo por
la carrera Inicio→Reserva (el `stop()` del coach que se desmonta mata el clip
entrante); fix = `TutorialVoice.stopIfToken(token)` y comparar en `dispose`.

Relacionado: [[tutorial-flow-system]], [[instructora-tutorial-asset]], [[entorno-claude-code-replica]].
