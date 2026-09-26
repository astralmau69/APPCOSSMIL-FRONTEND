# Modo Guiado de Reserva (reserva real narrada por la instructora)

**Fecha:** 2026-09-22
**Rama:** `preTutorial`
**Estado:** Diseño aprobado (Opción A)

## 1. Objetivo

Al tocar **"Nueva Reserva"**, el usuario elige entre dos modos:

- **Modo Clásico** — el flujo de reserva actual, sin cambios.
- **Modo Guiado** — la **misma reserva real** (crea cita, notificaciones, PDF),
  pero con la instructora acompañando por **voz** y **nubes de texto** que
  indican qué hacer en cada pantalla, **sin** tapar ni alterar las opciones.

Público objetivo: personal militar, en buena parte adulto mayor / de tercera
edad. El modo guiado es una **guía de uso real** (no una demostración).

### Diferencia clave con el tutorial-demo existente
El tutorial-demo (`isTutorialMode`) se **conserva intacto**: es para la primera
vez y para practicar desde Perfil > Ayuda; **no** crea cita real, mockea datos y
resalta la primera opción. El Modo Guiado es **algo nuevo y separado**: reserva
real, sin mockeo, sin forzar opciones, y el usuario elige libremente.

## 2. Alcance visual (importante)

- El Modo Guiado se **ve igual que el Modo Clásico**. NO se aplica alto
  contraste, NI tipografías especiales, NI cambios de layout de las pantallas de
  reserva. La única diferencia visible es la instructora + voz + burbujas.
- Las burbujas/nubes de texto **no deben afectar ni tapar** las opciones
  seleccionables (posición y `HitTestBehavior` que no interfieran; el coach se
  minimiza ante cualquier toque/scroll, igual que hoy).

## 3. Arquitectura (Opción A)

### 3.1 Bandera de estado nueva
- Añadir `bool guidedMode` a `BookingState` (en `lib/shell/tab_shell.dart`),
  independiente de `isTutorialMode`.
- `guidedMode`:
  - **NO** mockea datos, **NO** salta pasos, **NO** bloquea la confirmación.
  - La reserva corre real de punta a punta.
- `isTutorialMode` queda **exactamente como está** (salvo el fix del §7).
- Al salir del flujo / resetear (`resetBookingState`) se limpia `guidedMode`
  igual que las demás banderas.

### 3.2 Entrada: hoja de selección de modo
- Nuevo widget `BookingModeSheet` (p. ej.
  `lib/features/booking/widgets/booking_mode_sheet.dart`): dos tarjetas grandes
  ("Modo Clásico" / "Modo Guiado") con ícono, título y descripción corta.
- Se muestra **solo** cuando el usuario entra a Nueva Reserva de forma normal
  (no durante el tutorial-demo, que se salta esta hoja).
- Punto de intercepción: donde hoy "Nueva Reserva" llama a
  `TabShell._tryEnterBookingTab()` (home hero + grid + `reservas_screen`). Se
  antepone la hoja; según la elección:
  - Clásico → `guidedMode=false`, flujo normal.
  - Guiado → `guidedMode=true`, luego `_tryEnterBookingTab()`.
- Estética coherente con el resto (usar `showAppDialog` / hoja Cupertino segun
  convención; ver memoria [[dialogos-showappdialog]]).

### 3.3 Coach en modo "solo narrar"
- Reusar `TutorialCoachOverlay` (`lib/core/widgets/tutorial_coach_overlay.dart`)
  con una bandera nueva `bool narrateOnly` (default `false`).
- `narrateOnly == true`:
  - Muestra burbujas + reproduce voz + botón de silencio + contador de pasos +
    lip-sync (todo lo que ya hace).
  - **No** envuelve el objetivo con `GuidedTapHint` (no resalta/rebota/atenúa) —
    eso vive en las pantallas de reserva bajo `isTutorialMode`; en `guidedMode`
    no se activa.
- `booking_flow_screen.dart` monta el coach cuando `guidedMode || isTutorialMode`;
  pasa `narrateOnly: guidedMode`.
- Las pantallas de reserva (`regional/specialty/doctor/agenda/schedule/summary`)
  **NO** cambian su comportamiento real por `guidedMode`: siguen mostrando datos
  reales y confirmando de verdad. Solo `isTutorialMode` sigue disparando el
  resaltado/mockeo (sin cambios).

### 3.4 Voces por paso (guidedMode)
`booking_flow_screen._coachVoiceId()` devuelve, cuando `guidedMode`:
- step 0 (RegionalScreen) → `guiado_regional`
- step 1 (SpecialtyScreen) → `guiado_especialidad`
- step 2 (DoctorScreen) → `guiado_medico`
- step 3 (AgendaScreen) → `guiado_dia`
- step 4 (ScheduleScreen) → `guiado_hora`
- step 5 (SummaryScreen) → `guiado_confirmar`
- emergente "Aviso Importante" (inasistencias, botón "Entiendo, continuar con la reserva") → `guiado_aviso`
- confirmado → `guiado_registrada` (invita a "Ver Imagen de la Cita Médica")
- al abrir la imagen de la cita → `guiado_ficha` (explica "Descargar / Imprimir" y "Compartir"; se despide)
- "Volver al Inicio" sin haber abierto la imagen → `guiado_despedida` (siempre "Gracias por su atención")

> Ampliación 26 sep 2026 (pedido del usuario): `guiado_final` se reemplazó por
> `guiado_registrada` + `guiado_ficha` + `guiado_despedida`, y se agregó `guiado_aviso`.
> `guiado_dia` explica solo verde (disponible) y rojo (fichas agotadas); el gris
> ("Sin consulta") no se narra.

`guiado_intro` se reproduce al iniciar el modo (al elegir "Modo Guiado", antes o
al montar el primer paso). Los mensajes de burbuja de cada paso replican el texto
del guion (§5) — profesional, trato de usted.

## 4. Flujo de datos

```
Home/Reservas: "Nueva Reserva"
      │
      ▼
BookingModeSheet ── Clásico ─► guidedMode=false ─► reserva normal
      │
      └────────── Guiado  ─► guidedMode=true, play(guiado_intro)
                              ─► _tryEnterBookingTab()
                              ─► BookingFlow (coach narrateOnly)
                                   step→voz guiado_*  (real, sin mockeo)
                              ─► Summary: confirma REAL ─► play(guiado_aviso) ─► acepta ─► play(guiado_registrada)
```

## 5. Guion (fuente única: `tools/rvc/tutorial_lines.{md,json}`)

Tono: profesional, institucional militar (COSSMIL, Bolivia), trato de usted, sin
jergas, ortografía cuidada. Recuerda que la cita es real.

| id | texto |
|---|---|
| `guiado_intro` | Bienvenido a la reserva guiada de COSSMIL. Le acompañaré paso a paso. Tenga en cuenta que esta reserva es real, y su cita quedará registrada. Comencemos. |
| `guiado_regional` | Primero, elija el hospital o policlínico donde desea atenderse. Están ordenados por regional. |
| `guiado_especialidad` | Ahora, elija la especialidad médica que necesita. |
| `guiado_medico` | Muy bien. Ahora, elija al médico con quien desea realizar su consulta. |
| `guiado_dia` | Elija el día de su cita. Los días en rojo no tienen fichas disponibles. Para continuar, seleccione un día en verde, que sí tiene fichas disponibles. |
| `guiado_hora` | Ahora, elija el horario de su preferencia. |
| `guiado_confirmar` | Revise que sus datos sean correctos. Cuando esté listo, presione Confirmar. |
| `guiado_aviso` | Antes de continuar, lea con atención este aviso importante. Si acumula tres inasistencias, se suspenderá su acceso para sacar fichas en línea. Cuando termine de leerlo, presione Entiendo, continuar con la reserva. |
| `guiado_registrada` | Su cita fue registrada con éxito. Si desea verla, presione Ver Imagen de la Cita Médica. |
| `guiado_ficha` | Esta es la imagen de su cita médica. Con Descargar, puede guardarla o imprimirla. Con Compartir, puede enviarla a quien desee. Gracias por su atención, que tenga un buen día. |
| `guiado_despedida` | Gracias por su atención. Le esperamos en su próxima reserva. |

## 6. Pipeline de voz (Colab, RVC v2 — igual que antes)

- Reutiliza `tools/rvc/COLAB_notebook.md` (Applio/RVC v2, GPU T4).
- Como no se tiene certeza del `.pth` en Drive → **reentrenar desde cero**:
  1. `bash tools/rvc/prep_dataset.sh` rearma el dataset desde las `vof`.
  2. Celdas 1–4: instalar, narración fuente (`gen_source_tts.py` sobre el JSON
     ya actualizado con las líneas `guiado_*`), entrenar.
  3. Celdas 5–6: conversión en lote → mp3.
- Los clips nuevos caen en `assets/vof_tutorial/guiado_*.mp3` (mismo directorio
  que busca `TutorialVoice.play()`; ojo con la subcarpeta anidada, ver memoria
  [[tutorial-voz-rvc]]).
- Registrar los `.mp3` en `pubspec.yaml` si el asset no está por carpeta.
- **Recomendación:** sumar 3–5 min de grabaciones limpias de la misma voz al
  dataset mejora mucho la claridad (relevante para adulto mayor).

## 7. Bug a corregir: `ficha_01` (regional) no suena en el demo

- Síntoma: al entrar a seleccionar regional en el tutorial-demo, `ficha_01` no
  se reproduce.
- Hipótesis principal: carrera en la transición Inicio→Reserva — el coach de
  Inicio hace `TutorialVoice.stop()` en `dispose()` y mata el `ficha_01` recién
  lanzado por el coach de Reserva (patrón de token/singleton ya documentado en
  [[tutorial-voz-rvc]]).
- Acción: root-cause con depuración sistemática y corregir (posible: ignorar el
  `stop()` del coach que se desmonta si otro coach ya tomó el token, o retrasar
  el arranque de voz del nuevo paso hasta después del `dispose`).

## 8. Accesibilidad

- Sin alto contraste especial (decisión del usuario): el guiado se ve como el
  clásico. Se conservan las mejoras de accesibilidad ya existentes del coach
  (live region, sin auto-colapso con lector, respeto a reduce-motion).
- Targets táctiles de las tarjetas de la hoja ≥ 48 px.

## 9. Pruebas

- Widget: la hoja muestra 2 tarjetas y enruta a Clásico/Guiado.
- Widget: en `guidedMode`, el Summary confirma de verdad (no bloqueado) y las
  pantallas NO resaltan/mockean.
- Widget: el coach en `narrateOnly` NO monta `GuidedTapHint`.
- Widget: `booking_flow_screen._coachVoiceId()` mapea cada paso a `guiado_*`.
- Regresión: arranque de voz cubre el caso `ficha_01` (§7) sin que el `stop()`
  de un coach saliente mate el clip entrante.
- (Ver patrón de test del coach en memoria [[tutorial-flow-system]]: doble
  `pump()` antes de tapear dentro de `ScaleTransition`.)

## 10. Fuera de alcance

- No se toca el flujo de reserva clásico ni su UI.
- No se tocan los recorridos de calendario/trámites.
- No se rehace el asset visual de la instructora.
- La grabación de más voz para el dataset es recomendada pero opcional.

## Referencias
- Memorias: [[tutorial-voz-rvc]], [[tutorial-flow-system]], [[dialogos-showappdialog]], [[navbar-tapa-contenido]], [[sintomas-vs-causa-ui]].
- Pipeline de voz: `tools/rvc/README.md`, `tools/rvc/COLAB_notebook.md`.
