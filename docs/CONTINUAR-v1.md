# Continuar en otra PC — rama `v1` (23 sep 2026)

## Dónde quedamos

Feature en curso: **Modo Guiado de reserva** (reserva REAL narrada por la instructora).

- Spec: `docs/superpowers/specs/2026-09-22-modo-guiado-reserva-design.md`
- Plan TDD (Tasks 1–8): `docs/superpowers/plans/2026-09-22-modo-guiado-reserva.md`
- Código de la app: **todavía no se empezó** (Tasks 1–7 pendientes).
- Voces `guiado_*` (Task 8): guion listo en `tools/rvc/tutorial_lines.{md,json}`;
  **generación en Colab en curso** (ver abajo).

## Voces nuevas — notebook de Colab

`tools/rvc/COSSMIL_voces_guiado.ipynb` es autocontenido (trae las 7 `vof` y las
27 líneas del guion embebidas; no hay que subir nada):

1. colab.research.google.com → Archivo → Subir notebook.
2. Entorno de ejecución → Cambiar tipo → **T4 GPU**.
3. Ejecutar todo (acepta el permiso de Drive). ~30–60 min.
4. Descarga `vof_tutorial.zip` → extraer los mp3 **directo** en
   `assets/vof_tutorial/` (sin subcarpeta).

La voz final es la de la locutora de `assets/vof/` (RVC cambia el timbre de una
narración base de edge-tts). `SOLO_GUIADO=False` regenera las 27 líneas para que
toda la app quede con la misma voz del modelo reentrenado.

**Estado:** la 1ª corrida mostró que el Applio actual usa CLI Click/Typer
(`--help`, no `-h`; flags probablemente con guion). El notebook ya lee la ayuda de
cada comando y adapta los flags solo, pero esa versión **aún no se probó en Colab**.
Si falla: copiar el error y el bloque `===== preprocess =====` de la celda 3.
Los avisos rojos de `pip` ("dependency conflicts") son inocuos.

Para cambiar el notebook, editar `tools/rvc/build_colab_notebook.py` y correr
`python3 tools/rvc/build_colab_notebook.py` (no editar el `.ipynb` a mano).

## Siguientes pasos

1. Terminar la corrida de Colab y colocar los clips (Task 8, pasos 3–4).
2. Implementar Tasks 1–7 del plan (TDD); la Task 7 arregla que `ficha_01` no
   suene en el demo.
3. Probar en dispositivo (Task 8, paso 5).

## Entorno de Claude Code en la PC nueva

Seguir `docs/setup/entorno-claude-code.md` (o `tools/setup/setup-claude-env.sh`).
La memoria del proyecto está actualizada en `docs/setup/claude-config/memory/`;
la más relevante aquí es `tutorial-voz-rvc.md`.
