# Continuar en otra PC — rama `v1` (23 sep 2026)

## Dónde quedamos

Feature en curso: **Modo Guiado de reserva** (reserva REAL narrada por la instructora).

- Spec: `docs/superpowers/specs/2026-09-22-modo-guiado-reserva-design.md`
- Plan TDD (Tasks 1–8): `docs/superpowers/plans/2026-09-22-modo-guiado-reserva.md`
- Código de la app: **todavía no se empezó** (Tasks 1–7 pendientes).
- Voces `guiado_*` (Task 8): guion listo en `tools/rvc/tutorial_lines.{md,json}`;
  **generación en Colab en curso** (ver abajo).

## Estudio de voz — notebook de Colab (rama `v1-dev`)

`tools/rvc/COSSMIL_estudio_voz.ipynb`: voz **clonada de las vof** con Chatterbox
Multilingual (MIT) — la versión edge-tts + RVC sonaba robótica y quedó como opción.

1. Subir a Colab, GPU T4, **Ejecutar todo** (1ª vez ~15 min; después ~5).
2. Celda 6 elige sola la mejor referencia de la locutora (guardada en Drive).
3. Celda 7 descarga `vof_tutorial_*.zip` con las voces del **Modo Guiado** (+ tutorial)
   → extraer los mp3 **directo** en `assets/vof_tutorial/`.
4. Celda 8: cualquier texto; si una frase no convence, cambiar `SEMILLA`.

Historial de corridas reales: RVC entrenó OK tras `PYTORCH_JIT=0`; el choque de numpy
del kernel se resolvió corriendo todo lo pesado en subprocesos (ahora en el entorno
aislado de Chatterbox). La versión con Chatterbox **aún no se corrió en Colab real**
(validada con simulación completa y la API leída del paquete 0.1.7).

## Siguientes pasos

1. Correr el Estudio de voz en Colab y colocar los clips (Task 8, pasos 3–4).
2. Implementar Tasks 1–7 del plan (TDD); la Task 7 arregla que `ficha_01` no
   suene en el demo.
3. Probar en dispositivo (Task 8, paso 5).

## Entorno de Claude Code en la PC nueva

Seguir `docs/setup/entorno-claude-code.md` (o `tools/setup/setup-claude-env.sh`).
La memoria del proyecto está actualizada en `docs/setup/claude-config/memory/`;
la más relevante aquí es `tutorial-voz-rvc.md`.
