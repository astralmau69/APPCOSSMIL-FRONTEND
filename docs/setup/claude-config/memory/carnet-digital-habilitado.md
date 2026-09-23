---
name: carnet-digital-habilitado
description: "El carnet digital se habilitó el 2026-08-04; qué se rediseñó y qué sigue siendo provisional (fechas mock, QR rotativo con secreto local)."
metadata: 
  node_type: memory
  type: project
  originSessionId: 68df365a-7190-4435-a6ab-91c80692d804
  modified: 2026-08-04T14:27:22.486Z
---

El carnet digital dejó de estar en "Próximamente" el **2026-08-04**: la tarjeta
de Inicio vuelve a hacer `openSubRoute` a `CarnetScreen`. El interruptor real es
`AppConfig.carnetDigitalEnabled` (ponerlo en `false` lo oculta y saca su código
del build); ya no hay `comingSoon` en esa tarjeta. Ver [[procedimientos-coming-soon]].

**Why:** el usuario pidió habilitarlo y además mejorarlo ("animaciones fluidas,
consistencia, más profesional"). Lo importante: la feature ya estaba completa
(4 pantallas, PDF, validador), lo que faltaba era el gate y el acabado.

**How to apply:**

- **Lo que sigue siendo mock y hay que conectar al backend cuando exista:**
  `fechaEmision`/`fechaVencimiento` están hardcodeadas en `CarnetData.fromUser`
  (01/05/2025 – 30/04/2027), `estadoCivil` va vacío porque la API móvil no lo
  expone, y el QR rotativo se firma con `_rotatingSecret` compartido en el
  cliente (`COSSMIL-CARNET-ROT-v1`), no con una clave del servidor. Antes de
  presumir el carnet como documento verificable, esto tiene que salir del cliente.
- **Movimiento:** toda la entrada de `CarnetScreen` cuelga de UN solo
  `_introCtrl` con `Interval`s (halo → tarjeta → destello → ayuda → acciones).
  No agregar controladores sueltos ni `FadeSlideIn` con delays ahí: rompe los
  tiempos relativos y el camino de reduce-motion (que salta todo con
  `_introCtrl.value = 1`).
- **Trampa cara:** una `Matrix4` con perspectiva (`setEntry(3,2,·)`) encima de
  la tarjeta **desvía el hit-test** y el toque para girar deja de llegar. Por eso
  la matriz de entrada vuelve a la identidad al terminar, en vez de quitar el
  `Transform` (quitarlo cambiaría la forma del árbol y remontaría el holograma,
  reiniciando ticker y suscripción al acelerómetro).
- **`HolographicCard` ya no gira en vacío:** su `Ticker` se detiene tras ~30
  frames sin movimiento y despierta con `_wake()` (sensor o gesto), y con
  reduce-motion no se suscribe al acelerómetro. `carnet_salud_screen` arranca su
  barrido en `didChangeDependencies`, no en `initState`, por lo mismo.
- **De dónde salía el lag** (arreglado el mismo día): el barrido del holograma
  de `carnet_salud_screen` reconstruía en CADA frame, para siempre, un `Text`
  de 12 líneas a fontSize ≈ ancho·0,16 (más dos `List.filled().join()`). Ahora
  el texto rotado va de `child` cacheado del `AnimatedBuilder` y solo se rehace
  el shader. Mismo patrón aplicable a cualquier `ShaderMask` animado: **lo que
  se anima es el shader, el hijo se pasa por `child`**.
- Las dos tarjetas de captura del PDF (1010×637 cada una) estaban montadas
  fuera de pantalla SIEMPRE. Ahora se montan solo dentro de `_pdfBytes`, con dos
  `endOfFrame` antes de `toImage`. El test lo fija (`findsOneWidget` del frente).
- Los painters del panal reutilizan un `Path` y tienen los vértices del hexágono
  precalculados (`addHexagon` / `_kHexUnit`); el tornasol usa una LUT de 360
  colores en vez de convertir HSV→RGB por celda y por frame.
- **Reparto ancho/estrecho:** `CarnetScreen` pasa a dos columnas (tarjeta |
  acciones) desde `_kTwoPaneWidth` = 880 px de ancho **de contenido**, medido
  con `LayoutBuilder`, no con `r.isDesktop`. Es a propósito: así vale para el
  hueco que deja el SideNavBar, el split-screen y una ventana que se
  redimensiona, y un teléfono en el navegador cae solo en la disposición
  apilada de siempre. Mismo criterio en la vista previa del PDF (900 px → las
  dos páginas lado a lado) y en el carnet de salud (900 px → tope 520 px).
- Las 4 pantallas del carnet reservan `navBarBottomSpace`; ninguna lo hacía
  (ver [[navbar-tapa-contenido]]). Cuidado: ese valor **ya incluye**
  `viewPaddingBottom`, y vale 0 con SideNavBar — sumarlos es doble conteo.
- Cobertura: `test/carnet_screen_test.dart` (5 tests) cubre giro, reduce-motion
  y que el holograma deje de agendar frames. Ver [[tests-binding-secure-storage]].
