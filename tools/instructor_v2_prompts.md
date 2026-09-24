# Avatar v2 de la instructora — guía de generación paso a paso

Personaje nuevo: instructora militar boliviana, casco táctico tan con antiparras
ámbar. Reemplaza al set viejo `instructora_*.png` (boina verde + coleta + tablet).

---

## Cómo usar este archivo

**Cada PASO tiene un solo bloque de código. Ese bloque es UN mensaje completo
a ChatGPT.** No tenés que armar ni pegar nada más: el estilo del personaje ya
va incluido dentro de cada uno.

El ciclo de cada paso es siempre el mismo:

1. Copiás el bloque entero del paso.
2. Lo pegás en ChatGPT **adjuntando el render de referencia**.
3. Elegís el tamaño de salida que indica el paso.
4. Repasás la lista de "comprobá vos" del paso.
5. Me mandás la imagen. **Esperás mi OK antes de pasar al siguiente paso.**

> El bloque de estilo se repite en cada prompt a propósito. Es más largo de
> leer, pero significa que nunca tenés que ensamblar dos pedazos ni acordarte
> de cuál era el bloque común.

---

## Antes de empezar

**Tené a mano el render original** (la instructora de cuerpo entero con el
casco y las antiparras, fondo oscuro). Ese archivo se adjunta en **todas** las
generaciones, sin excepción. Sin referencia adjunta el modelo deriva: le cambia
el tono al camuflaje, le mueve los parches de lado o le adelgaza el contorno.

**Guardá cada lámina que generes** aunque creas que salió mal. A veces la
descarto por un motivo y te sirve para otra cosa.

**Nombrá los archivos** `lamina0.png`, `lamina1.png`, etc. Me ahorra confusión
cuando vayamos por la tercera versión de la misma.

---

# PASO 1 — A-pose frontal

> **Es el paso que importa.** De esta única imagen salen las 10 piezas del
> cuerpo del rig. Si sale torcida, todo lo demás se cae. Vale la pena
> regenerarla cuantas veces haga falta antes de seguir.

**Qué obtenés:** el cuerpo separable en torso, antena de la radio, brazo y
antebrazo de cada lado, muslo y pantorrilla de cada lado. La cabeza NO sale de
aquí: sale de la Lámina 1, que tiene sus variantes perfectamente registradas.

**Tamaño a pedir:** retrato **1024×1536**.

**Adjuntá:** el render original.

**Copiá y pegá esto:**

```
Usa la imagen adjunta como REFERENCIA EXACTA del personaje y del estilo.
Es la misma instructora militar boliviana, estilo chibi estilizado, dibujo
plano con contorno grueso marrón oscuro y cel-shading sin degradados.

Replica su diseño sin cambiar NADA:

CABEZA
- Casco táctico tipo FAST color tan/coyote, con riel lateral, correas y
  barboquejo beige bajo el mentón.
- Antiparras de lente ámbar dorado con montura negra, apoyadas sobre el casco.
- Tres estrellas doradas pequeñas en el frente superior del casco.
- Parche de la bandera de Bolivia (rojo-amarillo-verde) en el lado del casco
  que queda a la IZQUIERDA DEL ESPECTADOR.
- Pelo castaño oscuro: flequillo, mechones sueltos a los lados, recogido atrás.
- Ojos grandes castaños con brillo y pestañas marcadas, cejas castañas,
  mejillas sonrosadas, sonrisa leve con labios rosados.
- Un aro pequeño en la oreja del lado IZQUIERDO DEL ESPECTADOR.

CUERPO
- Uniforme de camuflaje multicam: manchas medianas en tan, beige, verde oliva
  y marrón.
- Cuello alto verde oliva asomando bajo el cuello del uniforme.
- Chaleco portaplacas tan con: parche negro de tres estrellas doradas en el
  pecho alto, parche de la bandera de Bolivia en el centro del pecho, y tres
  porta-cargadores en la parte baja.
- Parche de la bandera de Bolivia en el hombro IZQUIERDO DEL ESPECTADOR, y
  debajo un parche verde con cañones cruzados.
- Radio negra con antena flexible y cable espiralado en el hombro DERECHO DEL
  ESPECTADOR.
- Guantes tácticos tan con protecciones negras en los nudillos.
- Cinturón táctico con hebillas negras.
- Pistolera tan con pistola en el muslo IZQUIERDO DEL ESPECTADOR.
- Bolsa médica verde oliva con cruz oscura colgando de la cadera DERECHA DEL
  ESPECTADOR.
- Pantalón cargo a juego, rodilleras tan con placa rígida.
- Botas de cuero beige con cordones, completas.

PROPORCIONES (no negociable)
- La cabeza CON CASCO ocupa aproximadamente el 23% de la altura total de la
  figura (una figura de unas 4,3 cabezas de alto).

LA POSE QUE NECESITO
Genera UNA sola figura de cuerpo entero, de frente, en A-POSE de referencia
para animación:
- De pie, mirando al frente, expresión neutra y amable, con la boca cerrada
  sonriendo levemente y los ojos abiertos.
- Los DOS brazos EXTENDIDOS y SEPARADOS del cuerpo, bajando en diagonal a
  unos 45 grados del torso, codos casi rectos. Los brazos NO deben tocar ni
  taparse con el chaleco, las cartucheras ni el cuerpo en ningún punto.
- Manos con el guante en puño relajado, visibles completas, separadas del
  cuerpo.
- Piernas rectas y SEPARADAS a la anchura de los hombros. Los muslos NO se
  tocan entre sí: tiene que verse fondo magenta entre las dos piernas en
  toda su longitud.
- La pistolera del muslo y la bolsa médica de la cadera bien visibles y
  pegadas a su pierna o cadera, sin cruzar al medio.
- Figura completa y centrada, del casco a las suelas, sin recortes en los
  bordes. Deja un margen de al menos 40 px de fondo alrededor.
- La figura ocupa la mayor altura posible del lienzo respetando ese margen.

FONDO Y TÉCNICA (no negociable)
- Fondo relleno PLANO de magenta puro #FF00FF. Sin degradado, sin viñeta,
  sin brillo, sin sombra bajo los pies, sin tablero de ajedrez.
- Sin texto, sin números, sin marca de agua.
```

**Comprobá vos antes de mandármela:**

- [ ] Se ve fondo magenta **entre cada brazo y el torso**, de punta a punta.
- [ ] Se ve fondo magenta **entre los dos muslos**, en toda su longitud.
- [ ] El fondo es magenta parejo: sin viñeta oscura, sin glow, sin sombra
      bajo las botas.
- [ ] La figura no toca ningún borde del lienzo.
- [ ] Los parches siguen del mismo lado que en el render original.

**No pases al Paso 2 hasta que yo confirme que la Lámina 0 pasó la medición.**

---

# PASO 2 — Variantes de ojos

**Qué obtenés:** el parpadeo, el guiño, la cara de alegría y la de sorpresa.

**Tamaño a pedir:** retrato **1024×1536**.

**Adjuntá:** el render original **y** la Lámina 0 ya aprobada.

**Copiá y pegá esto:**

```
Usa las imágenes adjuntas como REFERENCIA EXACTA del personaje y del estilo.
Es la misma instructora militar boliviana, estilo chibi estilizado, dibujo
plano con contorno grueso marrón oscuro y cel-shading sin degradados.

EL PERSONAJE (replícalo sin cambiar nada)
- Casco táctico tipo FAST color tan/coyote, con riel lateral, correas y
  barboquejo beige bajo el mentón.
- Antiparras de lente ámbar dorado con montura negra, apoyadas sobre el casco.
- Tres estrellas doradas pequeñas en el frente superior del casco.
- Parche de la bandera de Bolivia (rojo-amarillo-verde) en el lado del casco
  que queda a la IZQUIERDA DEL ESPECTADOR.
- Pelo castaño oscuro: flequillo, mechones sueltos a los lados, recogido atrás.
- Ojos grandes castaños con brillo y pestañas marcadas, cejas castañas,
  mejillas sonrosadas, labios rosados.
- Un aro pequeño en la oreja del lado IZQUIERDO DEL ESPECTADOR.
- En los hombros: cuello alto verde oliva, uniforme multicam, el parche de la
  bandera en el hombro IZQUIERDO DEL ESPECTADOR y la radio negra con antena
  en el hombro DERECHO DEL ESPECTADOR.

LO QUE NECESITO
Una cuadrícula de 2 columnas × 3 filas, 6 casillas exactamente del mismo
tamaño.

En las 6 casillas se ve ÚNICAMENTE LA CABEZA Y LOS HOMBROS, de frente, con
EXACTAMENTE el mismo encuadre, el mismo tamaño y la misma posición dentro de
su casilla. El casco, las antiparras, el pelo y los hombros deben ser
IDÉNTICOS casilla por casilla, como si fuera la misma imagen repetida seis
veces. Lo ÚNICO que cambia son los ojos:

1. ojos abiertos normales mirando al frente (idéntico a la referencia)
2. ojos CERRADOS, párpados en línea curva suave hacia abajo
3. ojos a MEDIO CERRAR, párpados caídos a la mitad
4. GUIÑO: el ojo del lado IZQUIERDO DEL ESPECTADOR cerrado en curva, el otro
   abierto normal
5. ojos cerrados en ARCO FELIZ hacia arriba, de alegría
6. SORPRESA: ojos muy abiertos y redondos, cejas levantadas

La boca queda igual en las 6 casillas: sonrisa leve con la boca cerrada.

FONDO Y TÉCNICA (no negociable)
- Fondo relleno PLANO de magenta puro #FF00FF en todas las casillas. Sin
  degradado, sin viñeta, sin brillo, sin tablero de ajedrez.
- Sin líneas separadoras entre casillas, sin números, sin texto, sin marca
  de agua.
```

**Comprobá vos antes de mandármela:**

- [ ] Las 6 cabezas son del mismo tamaño (compará el ancho del casco).
- [ ] Las 6 cabezas están en el mismo lugar dentro de su casilla.
- [ ] La casilla 1 tiene la cara igual a la referencia.
- [ ] La boca no cambió entre casillas.

---

# PASO 3 — Variantes de boca

**Qué obtenés:** el lip-sync, o sea que la boca se mueva mientras suena la voz
de la instructora.

**Tamaño a pedir:** retrato **1024×1536**.

**Adjuntá:** el render original **y** la Lámina 1 ya aprobada.

**Copiá y pegá esto:**

```
Usa las imágenes adjuntas como REFERENCIA EXACTA del personaje y del estilo.
Es la misma instructora militar boliviana, estilo chibi estilizado, dibujo
plano con contorno grueso marrón oscuro y cel-shading sin degradados.

EL PERSONAJE (replícalo sin cambiar nada)
- Casco táctico tipo FAST color tan/coyote, con riel lateral, correas y
  barboquejo beige bajo el mentón.
- Antiparras de lente ámbar dorado con montura negra, apoyadas sobre el casco.
- Tres estrellas doradas pequeñas en el frente superior del casco.
- Parche de la bandera de Bolivia (rojo-amarillo-verde) en el lado del casco
  que queda a la IZQUIERDA DEL ESPECTADOR.
- Pelo castaño oscuro: flequillo, mechones sueltos a los lados, recogido atrás.
- Ojos grandes castaños con brillo y pestañas marcadas, cejas castañas,
  mejillas sonrosadas, labios rosados.
- Un aro pequeño en la oreja del lado IZQUIERDO DEL ESPECTADOR.
- En los hombros: cuello alto verde oliva, uniforme multicam, el parche de la
  bandera en el hombro IZQUIERDO DEL ESPECTADOR y la radio negra con antena
  en el hombro DERECHO DEL ESPECTADOR.

LO QUE NECESITO
Una cuadrícula de 2 columnas × 3 filas, 6 casillas exactamente del mismo
tamaño.

En las 6 casillas se ve ÚNICAMENTE LA CABEZA Y LOS HOMBROS, de frente, con
EXACTAMENTE el mismo encuadre, el mismo tamaño y la misma posición dentro de
su casilla. El casco, las antiparras, el pelo y los hombros deben ser
IDÉNTICOS casilla por casilla. Los ojos quedan abiertos y normales en las 6.
Lo ÚNICO que cambia es la boca:

1. boca cerrada con sonrisa leve (idéntica a la referencia)
2. boca apenas entreabierta, sonrisa pequeña, se ven un poco los dientes
   de arriba
3. boca abierta en óvalo mediano, como pronunciando una "o"
4. boca bien abierta en óvalo grande, como pronunciando una "a"
5. sonrisa amplia y alegre con la boca abierta, dientes visibles
6. boca en línea neutra, sin sonrisa, expresión seria

FONDO Y TÉCNICA (no negociable)
- Fondo relleno PLANO de magenta puro #FF00FF en todas las casillas. Sin
  degradado, sin viñeta, sin brillo, sin tablero de ajedrez.
- Sin líneas separadoras entre casillas, sin números, sin texto, sin marca
  de agua.
```

**Comprobá vos antes de mandármela:**

- [ ] Las 6 cabezas son del mismo tamaño y están en el mismo lugar.
- [ ] Los ojos no cambiaron entre casillas.
- [ ] Se distinguen claramente las 4 aberturas de boca (cerrada, poco,
      mediana, grande).

---

# PASO 4 — Manos y guantes *(versión 2, corregida)*

> **La primera versión se rechazó.** Medido: 56.7% de deriva de ancho entre
> casillas, 124 px de dispersión vertical, y los dedos cortados por el borde
> superior en dos de ellas. Esta versión baja a 4 casillas y ancla la muñeca,
> que es lo que faltaba.

**Qué obtenés:** los gestos — señalar, pulgar arriba, mano abierta.

**Tamaño a pedir:** cuadrado **1024×1024** (cuadrícula 2×2, casillas de 512×512).

**Adjuntá:** el render original.

**Copiá y pegá esto:**

```
Usa la imagen adjunta como REFERENCIA EXACTA del estilo. Es la misma
instructora militar boliviana, estilo chibi estilizado, dibujo plano con
contorno grueso marrón oscuro y cel-shading sin degradados.

LO QUE NECESITO
Una cuadrícula de 2 columnas × 2 filas: 4 casillas exactamente del mismo
tamaño.

En cada casilla se ve ÚNICAMENTE EL ANTEBRAZO Y LA MANO: la manga del
uniforme de camuflaje multicam (manchas medianas en tan, beige, verde oliva
y marrón), el puño de la manga, y el guante táctico color tan.

EN LAS 4 CASILLAS SE VE EL DORSO DE LA MANO, con las protecciones negras de
los nudillos bien visibles. Nunca la palma.

ENCUADRE IDÉNTICO EN LAS 4 CASILLAS (esto es lo más importante):
- El antebrazo entra por el BORDE INFERIOR de la casilla, vertical, apuntando
  hacia arriba.
- El puño de la manga cruza la casilla siempre a la MISMA altura: al 75% de
  la altura de la casilla, medido desde arriba.
- El antebrazo tiene el MISMO grosor en las 4.
- La mano está centrada horizontalmente, en el MISMO sitio en las 4.
- El guante mide lo MISMO a la altura de los nudillos en las 4.
- Queda al menos un 15% de la altura de la casilla en fondo magenta por
  ENCIMA del dedo más alto. Ningún dedo puede tocar el borde superior.

Imagina que es la MISMA fotografía repetida 4 veces y que sólo se editaron
los dedos. Lo ÚNICO que cambia es el gesto:

1. puño cerrado relajado
2. índice extendido SEÑALANDO hacia arriba, resto de los dedos cerrados
3. pulgar hacia arriba, resto de los dedos cerrados
4. mano completamente abierta, dedos juntos y extendidos hacia arriba

FONDO Y TÉCNICA (no negociable)
- Fondo relleno PLANO de magenta puro #FF00FF en todas las casillas. Sin
  degradado, sin viñeta, sin brillo, sin tablero de ajedrez.
- Sin líneas separadoras entre casillas, sin números, sin texto, sin marca
  de agua.
```

**Comprobá vos antes de mandármela:**

- [ ] **Ningún dedo toca el borde de arriba** en ninguna casilla.
- [ ] Las 4 manos son del mismo tamaño (compará el ancho a la altura de los
      nudillos).
- [ ] El puño de la manga está a la misma altura en las 4.
- [ ] En las 4 se ve el dorso con los protectores negros, nunca la palma.

**Por qué el dorso y no la palma:** la instructora mira al espectador, así que
cuando levanta la mano vemos el dorso. Pedir "palma al frente" fue un error
mío del prompt anterior y por eso salieron mezcladas.

---

# PASO 5 — A-pose de perfil *(opcional)*

> Sólo si querés conservar la entrada caminando que hoy tiene el tutorial.
> El rig frontal funciona sin esto. Se puede dejar para después.

**Tamaño a pedir:** retrato **1024×1536**.

**Adjuntá:** el render original **y** la Lámina 0 ya aprobada.

**Copiá y pegá esto:**

```
Usa las imágenes adjuntas como REFERENCIA EXACTA del personaje y del estilo.
Es la misma instructora militar boliviana, estilo chibi estilizado, dibujo
plano con contorno grueso marrón oscuro y cel-shading sin degradados.

EL PERSONAJE (replícalo sin cambiar nada)
- Casco táctico tipo FAST color tan/coyote con antiparras de lente ámbar
  dorado y barboquejo beige.
- Pelo castaño oscuro recogido atrás.
- Uniforme de camuflaje multicam en tan, beige, verde oliva y marrón, con
  cuello alto verde oliva.
- Chaleco portaplacas tan con porta-cargadores.
- Radio negra con antena flexible en el hombro.
- Guantes tácticos tan, cinturón táctico con hebillas negras, pistolera en
  el muslo, rodilleras tan, botas de cuero beige con cordones.
- La cabeza CON CASCO ocupa aproximadamente el 23% de la altura total.

LO QUE NECESITO
UNA sola figura de cuerpo entero, de PERFIL ESTRICTO mirando hacia la DERECHA
DEL ESPECTADOR, de pie y quieta:
- Brazos colgando relajados y SEPARADOS del torso, sin cruzarlo.
- Piernas rectas, una ligeramente adelantada respecto de la otra, sin
  taparse del todo.
- Se ve el perfil del casco, de las antiparras y de la antena de la radio.
- Figura completa del casco a las suelas, con un margen de al menos 40 px
  de fondo alrededor.
- La misma altura total y el mismo tamaño de cabeza que la figura frontal
  adjunta.

FONDO Y TÉCNICA (no negociable)
- Fondo relleno PLANO de magenta puro #FF00FF. Sin degradado, sin viñeta,
  sin brillo, sin sombra bajo los pies, sin tablero de ajedrez.
- Sin texto, sin números, sin marca de agua.
```

**Comprobá vos antes de mandármela:**

- [ ] Es perfil de verdad, no tres cuartos.
- [ ] Mira hacia la derecha.
- [ ] Mide lo mismo de alto que la Lámina 0.

---

# PASO 6 — Perfil v2 *(opcional: mejora la caminata)*

> La Lámina 4 sirve, pero se midió que **el brazo está pegado al torso en el
> 86% de las filas del tronco**. Eso obliga a riggear la caminata con tres
> piezas (cuerpo entero + dos piernas) en vez de con brazos articulados. A
> 172×263 px no se nota, así que este paso es opcional. Hacelo si querés que la
> instructora mueva los brazos al caminar, o que alguna vez gesticule de perfil.

**Qué obtenés:** un perfil con el brazo separable, para una caminata con
balanceo de brazos.

**Tamaño a pedir:** retrato **1024×1536**.

**Adjuntá:** el render original **y** `lamina4_perfil.png`.

**Copiá y pegá esto:**

```
Usa las imágenes adjuntas como REFERENCIA EXACTA del personaje y del estilo.
Es la misma instructora militar boliviana, estilo chibi estilizado, dibujo
plano con contorno grueso marrón oscuro y cel-shading sin degradados. La
segunda imagen es un perfil del mismo personaje: copia su diseño y su altura
exactamente, y cambia SOLO la posición de los brazos y las piernas.

EL PERSONAJE (replícalo sin cambiar nada)
- Casco táctico tipo FAST color tan/coyote con antiparras de lente ámbar
  dorado, correas y barboquejo beige.
- Parche de la bandera de Bolivia en el lateral del casco.
- Pelo castaño oscuro recogido en un rodete bajo en la nuca.
- Uniforme de camuflaje multicam en tan, beige, verde oliva y marrón, con
  cuello alto verde oliva.
- Chaleco portaplacas tan con porta-cargadores y parches en el pecho.
- Radio negra con antena flexible en el hombro.
- Guantes tácticos tan, cinturón táctico con hebillas negras, pistolera en
  el muslo, bolsa médica en la cadera, rodilleras tan, botas de cuero beige
  con cordones.

LO QUE NECESITO
UNA sola figura de cuerpo entero, de PERFIL ESTRICTO mirando hacia la DERECHA
DEL ESPECTADOR, de pie.

LO MÁS IMPORTANTE — LOS BRAZOS SEPARADOS DEL CUERPO:
- El brazo que queda del lado del espectador va ADELANTADO unos 30 grados
  respecto del torso, con el codo apenas flexionado, de modo que entre ese
  brazo y el pecho SE VEA FONDO MAGENTA en todo el recorrido, desde la axila
  hasta la mano.
- El otro brazo va ATRASADO unos 20 grados, también despegado del cuerpo.
- Ningún brazo debe cruzar el chaleco ni las cartucheras.

LAS PIERNAS:
- De pie, rectas, con una pierna ligeramente adelantada respecto de la otra,
  de modo que se distingan las dos y NO se tapen entre sí.

ENCUADRE:
- Figura completa del casco a las suelas, con un margen de al menos 40 px de
  fondo alrededor.
- La MISMA altura total y el MISMO tamaño de cabeza que la figura de perfil
  adjunta.

FONDO Y TÉCNICA (no negociable)
- Fondo relleno PLANO de magenta puro #FF00FF. Sin degradado, sin viñeta,
  sin brillo, sin sombra bajo los pies, sin tablero de ajedrez.
- Sin texto, sin números, sin marca de agua.
```

**Comprobá vos antes de mandármela:**

- [ ] **Se ve fondo magenta entre el brazo de adelante y el pecho**, de la
      axila a la mano. Es el punto de todo este paso.
- [ ] Es perfil de verdad, no tres cuartos.
- [ ] Mira hacia la derecha.
- [ ] Se distinguen las dos piernas.
- [ ] Mide lo mismo de alto que la Lámina 4.

---

# Anexo A — Por qué cada regla

Estas no son manías: cada una salió de romper el asset anterior.

**Adjuntar siempre la referencia.** Sin ella el modelo deriva entre láminas.
Al set viejo le pasó: cambió el tono del camuflaje y movió los parches.

**Fondo magenta, nunca "transparente".** Si le pedís transparencia, hornea un
tablero de ajedrez falso dentro del PNG — sin canal alfa real. El asset
original nació así y hubo que limpiarlo con flood-fill. El magenta no aparece
en ningún lado del personaje, así que se recorta con un umbral trivial.

**Sin viñeta ni sombra.** El render original tiene un glow oscuro alrededor.
Al recortar, ese degradado deja un halo sucio en el borde de cada pieza.

**Máximo 6 casillas.** Lo único que importa es el tamaño nativo de cada
casilla. El set viejo mezcló una lámina de 700 px con otra de 240 px
reescalados, y la instructora **cambiaba de tamaño al cambiar de pose**. Con
6 casillas en 1024×1536 cada una mide 512×512, que alcanza de sobra.

**Los lados, siempre desde el espectador.** "Su izquierda" es ambiguo y ya
salió una lámina espejada por eso.

**Repetir la pose base como primera casilla.** Es el ancla: me deja medir
cuánto derivó la escala en esa lámina y corregirla en post.

**Las marcas de agua no importan.** Si aparece una, no regeneres por eso —
la limpio yo.

---

# Anexo B — Qué mido antes de integrar

El script de validación reporta números, no opiniones:

| Chequeo | Cómo | Se rechaza si |
|---|---|---|
| Fondo limpio | histograma del borde | hay viñeta, degradado o sombra |
| Halo magenta | anillo de píxeles al recortar | queda borde rosa tras el umbral |
| Escala entre láminas | ancho del casco en la casilla ancla | difiere más del 2% |
| Alineación de casillas | centroide de la cabeza por casilla | se mueve más del 1% |
| Encuadre | bbox de la figura | toca el borde del lienzo |
| Separación de piezas | magenta entre brazo y torso, y entre muslos | los miembros se tocan |
| Resolución útil | alto de la figura en px nativos | menos de 900 px en Lámina 0 |
| Estilo | comparación con el render de referencia | parches cambiados de lado, camuflaje de otro tono |

Si algo falla te devuelvo el número medido y el prompt corregido, no un
"salió feo".

---

# Anexo C — Resumen de un vistazo

| Paso | Lámina | Tamaño | Adjuntar | Da |
|---|---|---|---|---|
| 1 | A-pose frontal | 1024×1536 | render original | las 10 piezas del cuerpo |
| 2 | Ojos (2×3) | 1024×1536 | render + Lámina 0 | parpadeo, guiño, alegría, sorpresa |
| 3 | Boca (2×3) | 1024×1536 | render + Lámina 1 | lip-sync con la voz |
| 4 | Manos (**2×2**) | 1024×1024 | render original | señalar, pulgar, mano abierta |
| 5 | Perfil *(opcional)* | 1024×1536 | render + Lámina 0 | entrada caminando |
| 6 | Perfil v2 *(opcional)* | 1024×1536 | render + Lámina 4 | caminata con balanceo de brazos |

## Estado de la primera tanda (23 sep 2026)

| Lámina | Veredicto | Medición |
|---|---|---|
| 0 · A-pose | **Aprobada** | fondo std 2.8/1.3/2.6; piernas separadas 94% de las filas; brazos separados del 40% al 57% de la altura |
| 1 · Ojos | **Aprobada** | deriva de casco 0.0%, corona ±1 px. Casilla #3 (medio cerrar) salió igual a la #1 → se sintetiza aplastando el ojo abierto, no se regenera |
| 2 · Boca | **Aprobada** | deriva 1.0%, corona ±1 px, las 6 aberturas llegaron. Contra la de ojos: 2.0% (normalizable por la casilla ancla) |
| 3 · Manos v1 | **Rechazada** | deriva de ancho 56.7%, dispersión vertical 124 px, dedos cortados en #5 y #6 |
| 3 · Manos v2 | **Aprobada** | deriva de muñeca 7.1%, ninguna casilla cortada, dorso del guante en las 4, fondo std 1.9/1.3/1.8 |
| 4 · Perfil | **Usable con reserva** | altura coincide con la frontal al 0.6%; brazo pegado al torso en 86% de las filas → sirve para la caminata a tamaño chico, no para gestos de perfil |

**Sobre el 7.1% de las manos:** el umbral del 2% de la tabla de arriba vale para
las láminas de CARA, donde el recorte debe calzar sobre una cabeza concreta y
no hay anclaje inequívoco. En las manos sí lo hay —la muñeca— así que la
desviación se normaliza midiendo y reescalando, igual que
`build_instructor_walk.py` alinea la caminata por cabeza y pies. No se rechaza.

**Set completo al 23 sep 2026.** Falta sólo el corte y la normalización.

**Una lámina a la vez, y esperá mi OK antes de la siguiente.** Así no gastás
generaciones arrastrando un error que ya venía de la anterior.
