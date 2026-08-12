# Sistema de movimiento coherente + flujo de reserva en pantalla ancha

**Fecha:** 2026-08-03
**Alcance:** animaciones (móvil + web) y layout del flujo de reserva (solo web)

## Problema

Tres síntomas reportados: el tutorial "no fluye", las animaciones no se sienten
profesionales, y el flujo de Nueva Reserva "no se ve bien" en un monitor grande.

La medición sobre el código encontró una causa común y dos problemas de layout:

| Hallazgo | Evidencia |
|---|---|
| Ninguna animación usa el sistema de diseño | 41 `Duration(milliseconds: …)` literales en `features/booking` + `core/widgets/tutorial_*`; **0 usos** de `AppDurations`/`AppCurves`, pese a que CLAUDE.md los exige |
| Reduce-motion aplicado a parches | Solo en `app_dialog.dart`, `guided_tap_hint.dart` y `tutorial_coach_overlay.dart` |
| La instructora concentra demasiada maquinaria | 14 `AnimationController` en `tutorial_instructor.dart` (744 líneas) |
| El flujo desperdicia el ancho | 6 de 7 pantallas del flujo son lista de 1 columna; `r.gridColumns` ya devuelve 3 en desktop pero casi ninguna la usa |
| Avanzar y retroceder se ven igual | `booking_flow_screen.dart:166` usa `AnimatedSwitcher` con `FadeTransition` sin dirección |

La causa raíz de "no se siente fluido" es la primera fila: con 41 duraciones
inventadas, cada elemento se mueve a su propio ritmo y nada se percibe como
parte del mismo sistema.

## Parte D — Pantalla de carga con GSAP (implementada)

Único punto del proyecto donde GSAP aplica: `web/index.html` es DOM real y se
pinta antes de que Flutter arranque. Hasta ahora el `<body>` estaba vacío
(58 líneas, sin loader), de modo que el usuario veía un blanco sin señal —
indistinguible de un cuelgue, y en debug la espera llega a minutos.

- `web/gsap/gsap.min.js` — GSAP 3.13.0 autoalojado, igual que `pdfjs/`. La CSP
  de release es `default-src 'self'`, y los equipos que entran por LAN no tienen
  internet: un `<script src="cdn…">` los dejaría colgados.
- `web/loader/loader.css` — estilos, con variante oscura.
- `web/loader/loader.js` — entrada escalonada, barra indeterminada en bucle y
  salida en el evento `flutter-first-frame`.

Decisiones: la barra **no simula porcentaje** (no conocemos el progreso real del
arranque); a los 20 s aparece un aviso de que sigue cargando, porque una espera
larga sin explicación se lee como app colgada; hay respaldo sin GSAP y
`prefers-reduced-motion` vía `gsap.matchMedia()`.

## No-objetivo: GSAP en la interfaz de la app

Se descarta GSAP (y cualquier librería JS de animación) por imposibilidad
técnica, no por preferencia. Flutter web rasteriza toda la interfaz dentro de un
`<canvas>` mediante CanvasKit; GSAP opera sobre nodos DOM y no tiene nada que
manipular. Aplica igual a Framer Motion, Anime.js y Lottie-web.

El equivalente profesional para este stack es el propio sistema de animación de
Flutter, guiado por las skills ya instaladas (`flutter-animations`,
`flutter-build-responsive-layout`, `frontend-design`).

GSAP solo sería viable en un front-end web independiente en HTML/JS, que es un
proyecto aparte y no forma parte de este diseño.

## Restricción transversal

**El APK de producción no debe cambiar de comportamiento.** Todo cambio de
layout se activa con `kIsWeb && r.isDesktop`, de modo que el binario móvil
recorra exactamente las mismas ramas de código que hoy.

Los cambios de la Parte A sí afectan a móvil (es su objetivo), pero solo
sustituyen valores por tokens equivalentes, sin alterar estructura.

## Parte A — Fundación de movimiento

Sustituir las duraciones y curvas literales por los tokens existentes.

**Mapeo:** 100→`ultra`, 150→`fast`, 250/300/350→`normal`, 500→`slow`,
700→`verySlow`, 1000→`extra`. Curvas: `easeOutCubic`→`snappy`,
`easeOut`→`smooth`, `easeIn`→`smoothIn`, `easeOutBack`→`bounce`,
`elasticOut`→`elasticity`.

**Excepción explícita — duraciones acopladas a audio.** El tutorial sincroniza
la voz de la instructora con su animación (ver commit 45e449f, "sincroniza la
voz"). Una duración que exista para calzar con un clip de audio **no se migra**
salvo que el token coincida exactamente con el valor actual. Cada exclusión se
marca con un comentario que explique a qué audio responde.

**Reduce-motion.** Extender el patrón ya usado en `app_dialog.dart:35` a las
animaciones no esenciales del flujo y del tutorial: leer
`MediaQuery.disableAnimationsOf(context)` y colapsar a `Duration.zero` o al
estado final. No se aplica a la barra de progreso ni a nada que comunique estado
del sistema.

## Parte B — Flujo de reserva en pantalla ancha (solo web)

Layout aprobado: **grid + panel de resumen**.

```
┌───────────────────────────────────────────────┐
│  Especialidad          ●──●──○──○──○──○       │
├──────────────────────────────┬────────────────┤
│  ┌─────┐ ┌─────┐ ┌─────┐     │  TU RESERVA    │
│  │Card │ │Card │ │Card │     │  Hospital  …   │
│  └─────┘ └─────┘ └─────┘     │  Paciente  …   │
└──────────────────────────────┴────────────────┘
```

**Componentes:**

1. `BookingSummaryPanel` — nuevo widget en `lib/core/widgets/`, junto a
   `booking_stepper.dart` y demás piezas del flujo, siguiendo la convención de
   CLAUDE.md (las features solo contienen `screens/`). Recibe el `BookingState`
   y muestra las selecciones ya hechas. Se renderiza únicamente bajo
   `kIsWeb && r.isDesktop`.

2. `booking_flow_screen.dart` — cuando la condición se cumple, el contenido del
   paso y el panel se colocan en un `Row`; en cualquier otro caso el árbol de
   widgets queda **idéntico al actual**.

3. Pantallas de paso — `regional`, `specialty` y `doctor` pasan de lista a grid
   usando la `r.gridColumns` que ya existe. `agenda` y `schedule` se evalúan
   caso por caso: `schedule` ya es grid.

**Fuera de alcance:** `summary_screen.dart` (1461 líneas) no se reorganiza en
esta iteración; solo hereda el ancho del contenedor.

## Parte C — Fluidez del tutorial

1. **Transición direccional entre pasos.** Reemplazar el fade plano de
   `booking_flow_screen.dart:166` por deslizamiento con dirección: avanzar entra
   desde la derecha, retroceder desde la izquierda. Requiere que
   `BookingFlowScreenState` recuerde el sentido del último cambio de paso.

2. **Auditoría de los 14 controllers de `tutorial_instructor.dart`.** Objetivo:
   identificar cuáles pueden derivarse de un controller común mediante
   `Interval`, y cuáles tienen ciclo de vida propio y deben permanecer. No se
   fija de antemano un número objetivo: se reduce solo donde el comportamiento
   quede demostrablemente igual.

3. **Frenado sin saltos.** Verificar que los bucles usen el patrón `_settle`
   (dejar terminar el ciclo) en vez de `controller.value = 0`, que produce el
   salto visible ya corregido antes en este widget.

## Verificación

- `flutter analyze` limpio en cada parte.
- `dart format` sobre los archivos tocados.
- **Móvil sin cambios de layout:** confirmar que el árbol de widgets fuera de
  `kIsWeb && isDesktop` es el mismo (revisión de diff, no solo del analizador).
- **Visual:** revisar en el navegador a ~1920 px y en ventana angosta; revisar el
  tutorial completo de reserva con audio para descartar desincronización.
- Los tests existentes que toquen booking o tutorial deben seguir pasando.

Queda **visualmente sin verificar** todo lo que no pueda observarse en el
navegador local (por ejemplo, comportamiento en un dispositivo físico), y se
reportará como tal.
