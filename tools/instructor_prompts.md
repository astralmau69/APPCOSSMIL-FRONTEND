# Prompts de Gemini para el juego completo de la instructora

Regeneración del personaje en el **estilo nuevo** (lámina `ar6fse…`, jul 2026):
camuflaje moteado fino, bandera en el pecho de la viewer-derecha, tablet en la
mano de la viewer-izquierda.

## Por qué se regenera todo

El set viejo mezclaba dos láminas: 6 poses buenas (~700 px nativos) y 2
(`piensa`, `festeja`) sacadas de una lámina que empacaba ~120 casillas en
2816×1536 → **240 px nativos reescalados a 520**. Al dibujarse todas con
`height: h` sobre un recorte al bbox, cada pose se escalaba distinto y la
instructora **cambiaba de tamaño** al cambiar de pose. Ese era el tirón.

## Reglas de oro (aprendidas a las malas)

1. **Máximo 9 casillas por lámina.** La calidad por casilla es lo único que
   importa. Con 3×3 en 1696×2528 salen casillas de ~565×836 → sirve. Con ~120
   casillas salen 240 px → basura.
2. **Repite `explica` como PRIMERA casilla de cada lámina.** Es el ancla: sirve
   para medir la deriva de estilo entre láminas y para recalibrar la escala en
   post.
3. **Adjunta siempre la misma imagen de referencia** (la lámina `ar6fse…` o el
   `explica` ya extraído). Sin referencia, Gemini deriva entre generaciones.
4. **Fondo magenta plano `#FF00FF`.** Gemini hornea tableros de ajedrez falsos
   si le pides "transparente". El magenta no existe en el personaje y se
   recorta con un umbral trivial.
5. **Espejado: hay que decirlo en cada prompt.** La lámina anterior salió
   espejada respecto al set viejo. Descríbelo siempre en términos del
   ESPECTADOR, no de la personaje.
6. Gemini mete **marcas de agua** en alguna casilla (apareció una en el muslo de
   f3c3). Se limpian en post; no te preocupes al generar.

---

## BLOQUE DE ESTILO — pégalo al inicio de CADA lámina

```
Usa la imagen adjunta como REFERENCIA EXACTA del personaje y del estilo.
Es la misma instructora militar boliviana, estilo chibi. Replica su diseño
sin cambiar nada:

- Boina verde oliva ladeada con el escudo de Bolivia a color, completo.
- Coleta castaña alta del lado derecho del ESPECTADOR, con lazo de la
  bandera boliviana (rojo-amarillo-verde).
- Ojos grandes castaños con brillo, mejillas sonrosadas, flequillo castaño.
- Uniforme de camuflaje MOTEADO FINO verde oliva (motas pequeñas y densas,
  NO manchas grandes).
- Galones dorados pequeños en AMBAS puntas del cuello.
- Parche de la bandera boliviana en el pecho del lado DERECHO DEL
  ESPECTADOR.
- Cinturón táctico verde con cartucheras y una funda oscura en la cadera
  del lado izquierdo del ESPECTADOR.
- Botas de cuero marrón con cordones, completas y visibles.
- Contorno grueso marrón oscuro, sombreado cel-shading plano.

REQUISITOS TÉCNICOS OBLIGATORIOS (son para animación, no negociables):

1. Cuadrícula de 3 columnas × N filas, casillas del mismo tamaño.
2. Lienzo total lo más grande que puedas generar (mínimo 1696×2528).
3. ESCALA IDÉNTICA en todas las casillas: la boina debe medir exactamente
   lo mismo en cada una. La cabeza (boina incluida) ocupa el 57% del ancho
   de la figura.
4. ALINEACIÓN FIJA: las suelas de las botas apoyan sobre la MISMA línea
   horizontal en todas las casillas, al 97% de la altura de su casilla. La
   coronilla de la boina siempre al 3% de la altura de su casilla.
5. Si levanta un brazo, el brazo sale hacia arriba pero LA CABEZA Y LOS PIES
   NO SE MUEVEN de su sitio. No reencuadres para que quepa el brazo.
6. Cuerpo completo siempre, de la boina a las suelas. Nada recortado.
7. FONDO: relleno plano magenta puro #FF00FF, sin degradados, sin sombra
   bajo los pies, sin tablero de ajedrez, sin transparencia simulada.
8. Sin líneas separadoras entre casillas, sin números, sin texto, sin marca
   de agua.
9. Vista frontal, de pie, salvo donde diga lo contrario.
```

---

## LÁMINA 1 — poses base (3×2, 6 casillas)

```
[BLOQUE DE ESTILO]

POSES, en orden de lectura:

1. explica  — de pie de frente, sostiene una tablet gris con la mano del
              lado IZQUIERDO DEL ESPECTADOR, a la altura del pecho, y la
              señala con el índice de la otra mano. Sonrisa amable, ojos
              abiertos mirando al frente.
2. parpadeo — IDÉNTICA a la casilla 1 en cuerpo, brazos y tablet. Lo único
              que cambia: los ojos cerrados en línea curva suave. Todo lo
              demás debe calcar la casilla 1 píxel a píxel.
3. guino    — IDÉNTICA a la casilla 1. Lo único que cambia: el ojo del lado
              izquierdo del ESPECTADOR cerrado en guiño, el otro abierto,
              sonrisa un poco más amplia.
4. reposo   — de pie relajada, la tablet BAJADA al costado con el brazo
              extendido hacia abajo, la otra mano suelta. Expresión neutral
              y tranquila, ojos abiertos.
5. piensa   — sin tablet a la vista (la sostiene abajo, fuera de foco),
              índice apoyado en el mentón, ojos cerrados, ceja pensativa,
              cabeza ligeramente ladeada.
6. saludo   — saludo militar: mano derecha del ESPECTADOR a la sien, codo
              en alto, postura firme, mirada al frente, sonrisa leve. La
              tablet bajada al otro costado.
```

## LÁMINA 2 — festejo + transiciones a piensa (3×2, 6 casillas)

```
[BLOQUE DE ESTILO]

POSES, en orden de lectura:

1. explica       — ANCLA. Repite exactamente la casilla 1 de la lámina
                   anterior: tablet en la mano del lado izquierdo del
                   ESPECTADOR, señalándola, sonrisa, ojos abiertos.
2. celebra       — sostiene la tablet igual que en explica, pero en la
                   pantalla se ve un CHEQUE VERDE grande. Sonrisa abierta
                   y alegre, ojos brillantes, un leve resplandor verde en
                   la tablet.
3. festeja       — riendo con la boca abierta, ojos cerrados en arco feliz,
                   el brazo del lado derecho del ESPECTADOR levantado en
                   alto saludando con la mano abierta. Sin tablet.
4. explica_a_piensa_1 — CUADRO INTERMEDIO, a un tercio del camino entre la
                   casilla 1 y "piensa": la tablet empieza a bajar, los ojos
                   a medio cerrar, la cabeza empezando a ladearse.
5. explica_a_piensa_2 — CUADRO INTERMEDIO, a dos tercios: la tablet casi
                   abajo, el índice subiendo hacia el mentón sin tocarlo
                   todavía, ojos casi cerrados.
6. explica_a_reposo_1 — CUADRO INTERMEDIO: la tablet a media altura entre el
                   pecho y el costado, el brazo señalador ya bajando,
                   expresión relajándose.
```

## LÁMINA 3 — transiciones del festejo (2×2, 4 casillas)

```
[BLOQUE DE ESTILO]
La cuadrícula aquí es de 2 columnas × 2 filas.

POSES, en orden de lectura:

1. explica_a_celebra_1 — CUADRO INTERMEDIO entre "explica" y "celebra": la
                   sonrisa abriéndose, el cheque verde apareciendo tenue en
                   la tablet, los ojos empezando a iluminarse.
2. explica_a_celebra_2 — CUADRO INTERMEDIO, casi en celebra: cheque verde ya
                   nítido, sonrisa amplia.
3. celebra_a_festeja_1 — CUADRO INTERMEDIO: la boca abriéndose en risa, el
                   brazo empezando a subir (codo a la altura del hombro),
                   la tablet todavía en la mano.
4. celebra_a_festeja_2 — CUADRO INTERMEDIO, casi en festeja: ya riendo con
                   los ojos cerrados, el brazo casi arriba del todo.
```

## LÁMINA 4 — ciclo de caminata (RIESGO ALTO, ver nota)

```
[BLOQUE DE ESTILO]
Excepción al punto 9: aquí NO es vista frontal.
La cuadrícula es de 4 columnas × 2 filas (8 casillas).

Genera un CICLO DE CAMINATA de perfil, mirando hacia la DERECHA del
espectador, en 8 fotogramas consecutivos de un paso completo:

1. contacto: pierna del frente estirada tocando el suelo, la de atrás
   extendida hacia atrás.
2. amortiguación: peso sobre la pierna del frente, rodilla flexionada, el
   cuerpo en su punto más bajo.
3. paso: piernas cruzándose, casi juntas, cuerpo subiendo.
4. impulso: cuerpo en su punto más alto, la pierna de atrás despegando.
5..8: la misma secuencia con las piernas invertidas.

CRÍTICO para este ciclo:
- La CABEZA debe quedar a la MISMA altura y en la MISMA posición horizontal
  dentro de su casilla en los 8 fotogramas. Solo se mueven piernas, brazos y
  levemente el torso.
- La coleta puede ondear ligeramente, pero la boina no se mueve.
- Sostiene la tablet contra el pecho con el brazo del lado visible.
```

**Nota sobre la lámina 4:** el ciclo de caminata actual
(`instructora_walk_1..7.png`) YA está bien alineado y verificado con
onion-skin — es la única parte del personaje que hoy no salta. Se ve de perfil
a 172×263 px, donde el patrón de camuflaje es prácticamente indistinguible.
**Considera conservarlo** en vez de regenerarlo: es la pieza más difícil de
acertar y la que menos se beneficia del cambio de estilo. Si la lámina 4 sale
mal, no insistas — vuelve al ciclo viejo.

---

## Después de generar

Trae las láminas a `~/Downloads/` y avísame. Yo escribo
`tools/build_instructor_set.py`, que:

1. Detecta las casillas por los canales de fondo magenta.
2. Quita el magenta con umbral (`R>170 & G<130 & B>170`) y limpia el halo.
3. **Normaliza a lienzo común**: alinea por línea de pies y coronilla, a
   escala única, con el mismo padding — de modo que la deriva de encuadre que
   Gemini SIEMPRE deja deje de importar. Es lo que hace hoy
   `build_instructor_walk.py` con la caminata.
4. Cuantiza a 256 colores (FASTOCTREE) como el resto de assets.
5. Reporta la dispersión de escala y de línea de pies para verificar.

Y en la app añado soporte de **transiciones multi-cuadro** en
`TutorialInstructor`: hoy el `AnimatedSwitcher` solo funde A→B; con los
intermedios se reproduce A → i1 → i2 → B como secuencia, y a la inversa
reproduciendo los mismos cuadros al revés (no hace falta generarlos dos veces).
