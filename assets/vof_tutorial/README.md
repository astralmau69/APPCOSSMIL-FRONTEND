Clips de voz del tutorial (voz de la instructora, generados con RVC v2).

Nombre de cada archivo = el `id` del guion en `tools/rvc/tutorial_lines.md`:

    invite.mp3
    ficha_00.mp3 … ficha_07.mp3
    calendario_00.mp3 … calendario_04.mp3
    tramites_00.mp3 … tramites_04.mp3
    guiado_intro, guiado_regional, guiado_especialidad, guiado_medico,
    guiado_dia, guiado_hora, guiado_confirmar, guiado_final  (Modo Guiado)

Coloca los .mp3 aquí. Mientras falten, el tutorial funciona igual pero SIN voz
(TutorialVoice.play devuelve null en silencio y la instructora no "habla").

Cómo generarlos: `tools/rvc/README.md`.

Los 27 clips actuales se regeneraron el 25 sep 2026. El texto del guion es
EXACTAMENTE lo que dicen: si cambias una burbuja en el código, cambia también
`tools/rvc/tutorial_lines.{md,json}` y regenera ese clip.
