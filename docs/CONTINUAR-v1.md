# Continuar en otra PC — rama `v1` (23 sep 2026)

## Dónde quedamos

Feature en curso: **Modo Guiado de reserva** (reserva REAL narrada por la instructora).

- Spec: `docs/superpowers/specs/2026-09-22-modo-guiado-reserva-design.md`
- Plan TDD (Tasks 1–8): `docs/superpowers/plans/2026-09-22-modo-guiado-reserva.md`
- Código de la app: **todavía no se empezó** (Tasks 1–7 pendientes).
- Voces `guiado_*` (Task 8): guion listo en `tools/rvc/tutorial_lines.{md,json}`;
  **generación en Colab en curso** (ver abajo).

## Estudio de voz — notebook de Colab (rama `v1-dev`)

`tools/rvc/COSSMIL_estudio_voz.ipynb` reemplaza al notebook `COSSMIL_voces_guiado`.
Es autocontenido (trae las 7 `vof`, el guion de 27 líneas y el motor) y sirve para
generar **cualquier texto** con la voz femenina de la locutora de `assets/vof/`:

1. colab.research.google.com → Archivo → Subir notebook.
2. Entorno de ejecución → Cambiar tipo → **T4 GPU**.
3. Ejecutar todo (acepta el permiso de Drive). La 1ª vez entrena (~30–45 min) y
   guarda el modelo en `MyDrive/cossmil_rvc/modelo/`; después no reentrena.
4. Celda 6 · Estudio: una línea por audio (`nombre | texto`, `[pausa 1.5]`),
   ajustes de voz/velocidad/tono, previsualización y ZIP (copia en
   `MyDrive/cossmil_rvc/salidas/`).
5. Clips de la app: celda 8 (`GENERAR_GUION_APP`, `SOLO_GUIADO`) → extraer los mp3
   **directo** en `assets/vof_tutorial/`.

Más parecido: dejar grabaciones limpias de la locutora en
`MyDrive/cossmil_rvc/audio_extra/`; la huella del dataset cambia y reentrena solo.

**Estado:** validado con una corrida simulada completa (dobles de Colab/Applio/
edge-tts) y con los argumentos pasados por el parser Click real de Applio fijado
en `939d9ed` (esto descubrió que el comando es `batch-infer`, con guion). **Aún
no se corrió en Colab real.** Si falla, copiar el error de la celda.

Para cambiarlo: editar `tools/rvc/build_colab_notebook.py` o
`tools/rvc/estudio_voz_lib.py` y correr `python3 tools/rvc/build_colab_notebook.py`
(no editar el `.ipynb`). Pruebas del motor: `python3 tools/rvc/test_estudio_voz_lib.py`.

## Siguientes pasos

1. Correr el Estudio de voz en Colab y colocar los clips (Task 8, pasos 3–4).
2. Implementar Tasks 1–7 del plan (TDD); la Task 7 arregla que `ficha_01` no
   suene en el demo.
3. Probar en dispositivo (Task 8, paso 5).

## Entorno de Claude Code en la PC nueva

Seguir `docs/setup/entorno-claude-code.md` (o `tools/setup/setup-claude-env.sh`).
La memoria del proyecto está actualizada en `docs/setup/claude-config/memory/`;
la más relevante aquí es `tutorial-voz-rvc.md`.
