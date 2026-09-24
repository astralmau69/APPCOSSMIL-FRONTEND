# Láminas fuente del avatar v2

Material original del que se cortan todas las piezas del rig de la instructora
nueva (casco táctico + antiparras ámbar). Generadas con ChatGPT el 23 sep 2026
siguiendo `tools/instructor_v2_prompts.md`.

**No borrar.** Si se pierden hay que regenerar el set entero y volver a pasar
la evaluación. El set anterior no tiene sus fuentes versionadas —viven sueltas
en `~/Downloads` con nombres como `Gemini_Generated_Image_r8zz8h….png`— y por
eso hoy es irreproducible.

| Archivo | Paso del prompt | Qué contiene | Medición |
|---|---|---|---|
| `referencia_original.png` | — | El render de diseño. Se adjunta en TODAS las generaciones | 1024×1536 |
| `lamina0_apose_frontal.png` | Paso 1 | A-pose frontal → las 10 piezas del cuerpo | figura 941×1490; piernas separadas en 94% de las filas; brazos separados del 40% al 57% de la altura |
| `lamina1_ojos.png` | Paso 2 | 2×3, variantes de ojos | deriva de casco 0.0%, corona ±1 px. Casilla #3 salió igual a la #1 |
| `lamina2_boca.png` | Paso 3 | 2×3, variantes de boca (lip-sync) | deriva 1.0%, corona ±1 px, las 6 aberturas presentes |
| `lamina3_manos.png` | Paso 4 v2 | 2×2, dorso del guante | deriva de muñeca 7.1%, ninguna casilla cortada |
| `lamina4_perfil.png` | Paso 5 | Perfil v1 — **superada**, se conserva como respaldo | brazo pegado al torso en 85% de las filas |
| `lamina5_perfil_v2.png` | Paso 6 | **Perfil en uso** para la caminata | brazo separado en 59% del torso y en 95% de la banda de brazos; piernas separadas 87%; altura 2.2% bajo la frontal |

## Notas heredadas de la evaluación

- **Casilla #3 de `lamina1_ojos.png`** (ojos a medio cerrar) salió idéntica a
  la #1. El cuadro intermedio del parpadeo se **sintetiza** aplastando
  verticalmente el sprite de ojo abierto, no se regenera.
- **`lamina3_manos.png` es la v2.** La v1 se rechazó por 56.7% de deriva de
  escala y dedos cortados en dos casillas; no se conservó.
- **El perfil en uso es `lamina5_perfil_v2.png`.** La v1 tenía el brazo pegado
  al torso en el 85% de las filas, lo que obligaba a riggear la caminata con
  tres piezas rígidas. La v2 lo separa y habilita brazos articulados. La v1 se
  conserva como respaldo, no se usa.
- Fondo magenta `#FF00FF` en todas. Las desviaciones medidas del fondo van de
  std 1.9 a 4.6 sobre 255 — plano en todos los casos.

## Relacionado

- Prompts y criterios de evaluación: `tools/instructor_v2_prompts.md`
- Diseño del rig: `docs/superpowers/specs/2026-09-23-avatar-v2-rig-design.md`
- Set anterior (a retirar): `assets/images/instructora_*.png`
