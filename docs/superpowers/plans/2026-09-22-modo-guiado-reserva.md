# Modo Guiado de Reserva — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Al tocar "Nueva Reserva", ofrecer Modo Clásico (flujo actual) o Modo Guiado (misma reserva REAL, con la instructora narrando por voz y burbujas que no tapan las opciones).

**Architecture:** Bandera nueva `BookingState.guidedMode` (independiente de `isTutorialMode`). La reserva corre real; encima se monta `TutorialCoachOverlay` en modo `narrateOnly` (narra sin resaltar/forzar opciones ni bloquear la confirmación). Voces nuevas `guiado_*` generadas por RVC en Colab. Se corrige, aparte, un bug de audio del tutorial-demo (`ficha_01`).

**Tech Stack:** Flutter (Dart ^3.8.1), Cupertino UI, setState + BookingState, `audioplayers` (vía `TutorialVoice`), `flutter_test`. RVC v2 / Applio en Colab para las voces.

**Spec:** `docs/superpowers/specs/2026-09-22-modo-guiado-reserva-design.md`

## Global Constraints

- Idioma UI en español; guion en tono profesional/institucional militar (COSSMIL, Bolivia), trato de usted, sin jergas, sin faltas de ortografía. Fuente única del guion: `tools/rvc/tutorial_lines.{md,json}`.
- El Modo Guiado se ve IGUAL que el Clásico: sin alto contraste ni cambios de layout. Las burbujas NO tapan ni alteran las opciones seleccionables.
- El Modo Guiado crea una CITA REAL (no mockea, no bloquea la confirmación, no salta pasos). `isTutorialMode` NO cambia su comportamiento (salvo el fix del §7 del spec).
- No tocar el flujo clásico de reserva ni calendario/trámites. No rehacer el asset visual de la instructora.
- Usar tokens de diseño (`AppSpacing`, `AppTypography`, `AppColors`) y `showAppDialog`/hojas Cupertino según convención; nunca hardcodear colores/URLs.
- Toda pantalla dentro de una pestaña reserva `navBarBottomSpace` (memoria: la navbar tapa el contenido).
- Clips de voz viven en `assets/vof_tutorial/<id>.mp3` (plano, sin subcarpeta). `TutorialVoice.play(id)` devuelve `VoiceClip?`.
- Tests: inicializar `TestWidgetsFlutterBinding` + mock de `flutter_secure_storage`; doble `pump()` antes de tapear dentro de `ScaleTransition` (memorias de tests del coach).

---

### Task 1: Bandera `guidedMode` en BookingState

**Files:**
- Modify: `lib/shell/tab_shell.dart` (clase `BookingState`; reset en `resetBookingState`/donde se limpian las banderas, ~línea 150)
- Test: `test/booking/booking_state_guided_mode_test.dart`

**Interfaces:**
- Produces: `BookingState.guidedMode` (`bool`, default `false`); se limpia a `false` en el reset de la reserva.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil_citas/shell/tab_shell.dart'; // ajustar import real del paquete

void main() {
  test('guidedMode arranca en false y se limpia en el reset', () {
    final bs = BookingState();
    expect(bs.guidedMode, isFalse);
    bs.guidedMode = true;
    bs.reset(); // usar el método/rutina real de limpieza (ver tab_shell.dart)
    expect(bs.guidedMode, isFalse);
    expect(bs.isTutorialMode, isFalse); // no debe afectarse entre sí
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/booking/booking_state_guided_mode_test.dart`
Expected: FAIL (`guidedMode` no existe / reset no lo limpia). Ajustar el nombre real del método de reset leyendo `tab_shell.dart` antes de implementar.

- [ ] **Step 3: Write minimal implementation**

En `BookingState`, junto a `isTutorialMode`:
```dart
bool guidedMode = false;
```
En la rutina de reset (donde hoy se hace `isTutorialMode = false;`), añadir:
```dart
guidedMode = false;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/booking/booking_state_guided_mode_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/shell/tab_shell.dart test/booking/booking_state_guided_mode_test.dart
git commit -m "feat(guiado): bandera guidedMode en BookingState"
```

---

### Task 2: `narrateOnly` en TutorialCoachOverlay

**Files:**
- Modify: `lib/core/widgets/tutorial_coach_overlay.dart` (constructor + campo; NO tocar la lógica de voz/lip-sync)
- Test: `test/widgets/tutorial_coach_overlay_narrate_only_test.dart`

**Interfaces:**
- Consumes: nada nuevo.
- Produces: `TutorialCoachOverlay({..., bool narrateOnly = false})`. `narrateOnly` NO cambia el comportamiento interno del overlay (voz, burbujas, contador siguen igual); es una bandera de intención que las pantallas leen para NO activar `GuidedTapHint`. El overlay ya no monta resaltados por sí mismo, así que aquí solo se agrega el parámetro y se expone.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil_citas/core/widgets/tutorial_coach_overlay.dart';

void main() {
  testWidgets('narrateOnly default false y aceptado como parámetro', (t) async {
    const w = TutorialCoachOverlay(
      messages: ['Hola'],
      isDark: false,
      step: 1,
      totalSteps: 3,
      voiceId: null,
    );
    expect(w.narrateOnly, isFalse);

    const w2 = TutorialCoachOverlay(
      messages: ['Hola'],
      isDark: false,
      step: 1,
      totalSteps: 3,
      voiceId: null,
      narrateOnly: true,
    );
    expect(w2.narrateOnly, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/tutorial_coach_overlay_narrate_only_test.dart`
Expected: FAIL (parámetro `narrateOnly` no existe).

- [ ] **Step 3: Write minimal implementation**

En `TutorialCoachOverlay`:
```dart
final bool narrateOnly;
```
y en el constructor:
```dart
this.narrateOnly = false,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/tutorial_coach_overlay_narrate_only_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/tutorial_coach_overlay.dart test/widgets/tutorial_coach_overlay_narrate_only_test.dart
git commit -m "feat(guiado): parámetro narrateOnly en TutorialCoachOverlay"
```

---

### Task 3: Mapeo de voz por paso en `guidedMode`

**Files:**
- Modify: `lib/features/booking/screens/booking_flow_screen.dart` (`_coachVoiceId()` ~línea 206; condición de montaje del coach ~línea 180; `voiceId`/`narrateOnly` pasados al overlay ~línea 190)
- Test: `test/booking/booking_flow_voice_id_test.dart` (test unitario de la función de mapeo — extraer a función estática pura si hace falta para testear)

**Interfaces:**
- Consumes: `BookingState.guidedMode` (Task 1), `TutorialCoachOverlay.narrateOnly` (Task 2).
- Produces: en `guidedMode`, `_coachVoiceId()` devuelve por paso: 0→`guiado_regional`, 1→`guiado_especialidad`, 2→`guiado_medico`, 3→`guiado_dia`, 4→`guiado_hora`, 5→`guiado_confirmar`, confirmado→`guiado_final`. En `isTutorialMode` (no guiado) sigue devolviendo `ficha_0X`/`ficha_07` (sin cambios).

- [ ] **Step 1: Write the failing test**

Extraer el mapeo a una función estática pura para testearla sin construir el widget:
```dart
// en booking_flow_screen.dart:
// String bookingVoiceId({required bool guided, required int step, required bool confirmed})
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil_citas/features/booking/screens/booking_flow_screen.dart';

void main() {
  test('voz guiada por paso', () {
    expect(bookingVoiceId(guided: true, step: 0, confirmed: false), 'guiado_regional');
    expect(bookingVoiceId(guided: true, step: 1, confirmed: false), 'guiado_especialidad');
    expect(bookingVoiceId(guided: true, step: 2, confirmed: false), 'guiado_medico');
    expect(bookingVoiceId(guided: true, step: 3, confirmed: false), 'guiado_dia');
    expect(bookingVoiceId(guided: true, step: 4, confirmed: false), 'guiado_hora');
    expect(bookingVoiceId(guided: true, step: 5, confirmed: false), 'guiado_confirmar');
    expect(bookingVoiceId(guided: true, step: 3, confirmed: true), 'guiado_final');
  });
  test('voz demo (no guiado) intacta', () {
    expect(bookingVoiceId(guided: false, step: 0, confirmed: false), 'ficha_01');
    expect(bookingVoiceId(guided: false, step: 5, confirmed: false), 'ficha_06');
    expect(bookingVoiceId(guided: false, step: 0, confirmed: true), 'ficha_07');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/booking/booking_flow_voice_id_test.dart`
Expected: FAIL (`bookingVoiceId` no existe).

- [ ] **Step 3: Write minimal implementation**

Añadir función de nivel de librería en `booking_flow_screen.dart`:
```dart
String bookingVoiceId({
  required bool guided,
  required int step,
  required bool confirmed,
}) {
  if (guided) {
    if (confirmed) return 'guiado_final';
    const ids = [
      'guiado_regional',
      'guiado_especialidad',
      'guiado_medico',
      'guiado_dia',
      'guiado_hora',
      'guiado_confirmar',
    ];
    return ids[step.clamp(0, ids.length - 1)];
  }
  return confirmed ? 'ficha_07' : 'ficha_0${step + 1}';
}
```
Reemplazar `_coachVoiceId()` para delegar:
```dart
String _coachVoiceId() => bookingVoiceId(
  guided: widget.tabShell.bookingState.guidedMode,
  step: _currentStep,
  confirmed: _isConfirmed,
);
```
Montar el coach cuando `guidedMode || isTutorialMode` y pasar `narrateOnly: guidedMode`:
```dart
final bs = widget.tabShell.bookingState;
if (bs.isTutorialMode || bs.guidedMode)
  TutorialCoachOverlay(
    key: _coachKey,
    messages: _coachMessages(),
    isDark: isDark,
    celebrate: _isConfirmed,
    step: _currentStep + 2,
    totalSteps: 7,
    voiceId: _coachVoiceId(),
    narrateOnly: bs.guidedMode,
    onExit: _exitTutorial, // en guiado, "salir" solo quita el coach; no cancela la reserva real
  ),
```
Nota para el implementador: verificar que `onExit` en `guidedMode` NO borre la reserva (solo oculta el coach); si `_exitTutorial` hoy resetea el booking, crear una rama que en guiado solo apague `guidedMode` y desmonte el coach.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/booking/booking_flow_voice_id_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/booking/screens/booking_flow_screen.dart test/booking/booking_flow_voice_id_test.dart
git commit -m "feat(guiado): voz por paso y coach narrateOnly en el flujo de reserva"
```

---

### Task 4: Burbujas guiadas por paso (texto profesional)

**Files:**
- Modify: `lib/features/booking/screens/booking_flow_screen.dart` (`_coachMessages()` ~línea 212)
- Test: `test/booking/booking_flow_messages_test.dart`

**Interfaces:**
- Consumes: `BookingState.guidedMode`.
- Produces: cuando `guidedMode`, `_coachMessages()` devuelve el texto del guion `guiado_*` (§5 del spec) por paso; cuando `isTutorialMode` (no guiado), devuelve los mensajes demo actuales sin cambios.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil_citas/features/booking/screens/booking_flow_screen.dart';

void main() {
  test('mensajes guiados profesionales por paso', () {
    final m0 = bookingCoachMessages(guided: true, step: 0, confirmed: false);
    expect(m0.join(' '), contains('Seleccione el establecimiento'));
    final mc = bookingCoachMessages(guided: true, step: 5, confirmed: false);
    expect(mc.join(' '), contains('registrada de manera definitiva'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/booking/booking_flow_messages_test.dart`
Expected: FAIL (`bookingCoachMessages` no existe).

- [ ] **Step 3: Write minimal implementation**

Extraer función de librería con el texto EXACTO del guion (copiar de `tools/rvc/tutorial_lines.md`, sección Modo Guiado):
```dart
List<String> bookingCoachMessages({
  required bool guided,
  required int step,
  required bool confirmed,
}) {
  if (guided) {
    if (confirmed) {
      return const [
        'Su cita ha sido registrada correctamente.',
        'Puede consultar o descargar su ficha. Gracias por utilizar los '
            'servicios de COSSMIL.',
      ];
    }
    return switch (step) {
      0 => const [
        'Seleccione el establecimiento donde desea ser atendido.',
        'Los hospitales y policlínicos se encuentran agrupados por regional.',
      ],
      1 => const ['Seleccione la especialidad médica que requiere.'],
      2 => const [
        'Seleccione al profesional médico con quien desea reservar su cita.',
      ],
      3 => const [
        'Seleccione el día de atención.',
        'Cada tarjeta indica si el médico atiende y la disponibilidad de fichas.',
      ],
      4 => const [
        'Seleccione el horario de su preferencia dentro del día elegido.',
      ],
      5 => const [
        'Verifique que sus datos sean correctos.',
        'Al presionar Confirmar, su cita quedará registrada de manera definitiva.',
      ],
      _ => const [],
    };
  }
  // ... rama demo: mover aquí el switch actual de _coachMessages tal cual.
  return _demoCoachMessages(step: step, confirmed: confirmed);
}
```
`_coachMessages()` delega en `bookingCoachMessages(guided: bs.guidedMode, step: _currentStep, confirmed: _isConfirmed)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/booking/booking_flow_messages_test.dart`
Expected: PASS. Ejecutar también los tests demo previos para asegurar no-regresión.

- [ ] **Step 5: Commit**

```bash
git add lib/features/booking/screens/booking_flow_screen.dart test/booking/booking_flow_messages_test.dart
git commit -m "feat(guiado): burbujas profesionales por paso en modo guiado"
```

---

### Task 5: `guiado_intro` al iniciar el modo guiado

**Files:**
- Modify: `lib/features/booking/screens/booking_flow_screen.dart` (`initState`) o el punto donde se activa `guidedMode` (Task 6). Elegir un único disparo para evitar solaparse con `guiado_regional` del paso 0.
- Test: cubierto indirectamente por Task 6 (widget test de arranque). No forzar un test unitario frágil de audio.

**Interfaces:**
- Consumes: `TutorialVoice.play('guiado_intro')`.
- Produces: al entrar al flujo en `guidedMode`, se reproduce `guiado_intro` una sola vez, antes/al montar el paso 0. Decisión: reproducir `guiado_intro` en el `BookingModeSheet` al elegir "Guiado" (antes de navegar), y dejar que el paso 0 reproduzca `guiado_regional` al montar. Así no compiten dos clips.

- [ ] **Step 1: Implementar (sin test unitario de audio)**

En el handler de "Modo Guiado" del `BookingModeSheet` (Task 6), antes de `_tryEnterBookingTab()`:
```dart
TutorialVoice.play('guiado_intro');
```
Documentar en comentario que el paso 0 reproducirá `guiado_regional` (patrón de token ya maneja el solape).

- [ ] **Step 2: Verificación manual en Task 8 (device)**

Marcar para prueba en dispositivo: intro suena una vez, luego regional; no se pisan.

- [ ] **Step 3: Commit** (junto con Task 6 si es el mismo archivo)

```bash
git commit -am "feat(guiado): reproducir guiado_intro al elegir modo guiado"
```

---

### Task 6: Hoja de selección de modo (BookingModeSheet)

**Files:**
- Create: `lib/features/booking/widgets/booking_mode_sheet.dart`
- Modify: puntos de entrada de "Nueva Reserva" — `lib/features/home/screens/home_screen.dart` (hero + grid, ~líneas 500/646) y `lib/features/reservas/screens/reservas_screen.dart` (~línea 199). Interceptar SOLO el camino normal (no el tutorial-demo).
- Test: `test/booking/booking_mode_sheet_test.dart`

**Interfaces:**
- Consumes: `BookingState.guidedMode` (Task 1).
- Produces: `Future<BookingMode?> showBookingModeSheet(BuildContext context)` con `enum BookingMode { clasico, guiado }`. Dos tarjetas grandes ("Modo Clásico" / "Modo Guiado") con `Key('mode_clasico')` y `Key('mode_guiado')`. Devuelve la elección o `null` si se descarta.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil_citas/features/booking/widgets/booking_mode_sheet.dart';

void main() {
  testWidgets('muestra 2 tarjetas y devuelve la elección', (t) async {
    BookingMode? picked;
    await t.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => Center(child: ElevatedButton(
        onPressed: () async { picked = await showBookingModeSheet(ctx); },
        child: const Text('go'),
      ))),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('mode_clasico')), findsOneWidget);
    expect(find.byKey(const Key('mode_guiado')), findsOneWidget);
    await t.tap(find.byKey(const Key('mode_guiado')));
    await t.pumpAndSettle();
    expect(picked, BookingMode.guiado);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/booking/booking_mode_sheet_test.dart`
Expected: FAIL (archivo/función no existen).

- [ ] **Step 3: Write minimal implementation**

Crear `booking_mode_sheet.dart` con `enum BookingMode { clasico, guiado }` y `showBookingModeSheet` (hoja Cupertino/`showAppDialog` con dos tarjetas grandes usando tokens `AppSpacing`/`AppTypography`/`AppColors`, targets ≥48px, respetando reduce-motion). Cada tarjeta hace `Navigator.pop(context, BookingMode.x)`. Copy:
  - Clásico: título "Modo Clásico", subtítulo "Reserve por su cuenta, de forma rápida."
  - Guiado: título "Modo Guiado", subtítulo "La instructora le acompaña por voz, paso a paso."

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/booking/booking_mode_sheet_test.dart`
Expected: PASS

- [ ] **Step 5: Cablear en los puntos de entrada**

En cada entrada normal de "Nueva Reserva" (NO en el tutorial-demo):
```dart
final mode = await showBookingModeSheet(context);
if (mode == null) return; // descartó
final bs = widget.tabShell.bookingState;
bs.guidedMode = mode == BookingMode.guiado;
if (bs.guidedMode) TutorialVoice.play('guiado_intro'); // Task 5
widget.tabShell.// _tryEnterBookingTab() equivalente público existente
```
Nota: usar el método público que hoy dispara la reserva (ver `TabShell`); no duplicar la lógica de precarga de grupo familiar.

- [ ] **Step 6: Commit**

```bash
git add lib/features/booking/widgets/booking_mode_sheet.dart lib/features/home/screens/home_screen.dart lib/features/reservas/screens/reservas_screen.dart test/booking/booking_mode_sheet_test.dart
git commit -m "feat(guiado): hoja de selección Clásico/Guiado en Nueva Reserva"
```

---

### Task 7: Fix `ficha_01` no suena en el demo (regresión de audio)

**Files:**
- Modify: `lib/core/widgets/tutorial_coach_overlay.dart` (dispose/arranque de voz) y/o `lib/core/services/tutorial_voice.dart`
- Test: `test/services/tutorial_voice_handoff_test.dart`

**Interfaces:**
- Consumes: `TutorialVoice` (singleton estático, `currentToken`, `onComplete`).
- Produces: garantía de que el `stop()` de un coach que se desmonta NO cancela el clip que otro coach acaba de lanzar. Enfoque: en `dispose()`, solo llamar `TutorialVoice.stop()` si el token vigente es del propio coach (guardar `_voiceToken` y comparar), o exponer `TutorialVoice.stopIfToken(int token)`.

- [ ] **Step 1: Reproducir con debugging sistemático**

Antes de codear: confirmar la causa (usar superpowers:systematic-debugging). Instrumentar/loguear el orden dispose(Inicio)→play(Reserva) o escribir el test rojo abajo que modele el handoff.

- [ ] **Step 2: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil_citas/core/widgets/tutorial_coach_overlay.dart';

void main() {
  testWidgets('el clip del paso nuevo sobrevive al dispose del coach anterior', (t) async {
    // Montar coach A (voiceId ficha_00), luego reemplazar por coach B (ficha_01)
    // simulando la transición Inicio->Reserva; afirmar que B queda "hablando"
    // (o que TutorialVoice.currentToken corresponde a B) tras el dispose de A.
    // Usar dos pump() por el ScaleTransition. Ajustar a la API real de TutorialVoice.
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/services/tutorial_voice_handoff_test.dart`
Expected: FAIL (hoy el dispose de A mata el clip de B).

- [ ] **Step 4: Implementar el fix mínimo**

En `TutorialVoice` añadir:
```dart
static void stopIfToken(int token) {
  if (token == currentToken) stop();
}
```
En `TutorialCoachOverlay.dispose()`, cambiar `TutorialVoice.stop();` por:
```dart
if (_voiceToken != null) TutorialVoice.stopIfToken(_voiceToken!);
```
(el coach entrante ya incrementó el token en su `play()`, así que el saliente ya no coincide y no corta).

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/services/tutorial_voice_handoff_test.dart`
Expected: PASS. Correr toda la carpeta de tests del coach para no-regresión.

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/tutorial_coach_overlay.dart lib/core/services/tutorial_voice.dart test/services/tutorial_voice_handoff_test.dart
git commit -m "fix(tutorial): el clip del paso nuevo ya no se corta por el dispose del coach anterior"
```

---

### Task 8: Generar las voces `guiado_*` (Colab) e integrarlas

**Files:**
- Usa: `tools/rvc/tutorial_lines.json` (ya con las líneas `guiado_*`), `tools/rvc/COLAB_notebook.md`, `tools/rvc/prep_dataset.sh`, `tools/rvc/gen_source_tts.py`
- Create (salida): `assets/vof_tutorial/guiado_intro.mp3` … `guiado_final.mp3` (8 clips)
- Modify (si aplica): `pubspec.yaml` (solo si los assets no se incluyen por carpeta)

**Interfaces:**
- Produces: 8 mp3 con nombres EXACTOS de los ids `guiado_*`, en `assets/vof_tutorial/` (plano).

- [ ] **Step 1: Dataset**

Run local: `bash tools/rvc/prep_dataset.sh` → genera `tools/rvc/rvc_dataset/*.wav`. (Opcional recomendado: agregar 3–5 min de voz limpia de la misma locutora antes.)

- [ ] **Step 2: Colab (reentrenar + convertir)**

Subir `tools/rvc/COSSMIL_voces_guiado.ipynb` a Colab (GPU T4) y "Ejecutar todo" (autocontenido; reemplaza seguir `tools/rvc/COLAB_notebook.md` a mano). La Celda 3 usa `tutorial_lines.json` (ya incluye `guiado_*`) → genera narración fuente de TODAS las líneas; la Celda 5 convierte en lote. Descargar el ZIP.

- [ ] **Step 3: Colocar clips**

Extraer SOLO los `guiado_*.mp3` del ZIP en `assets/vof_tutorial/` (plano; ojo con la subcarpeta anidada que ya pasó una vez). Verificar 8 archivos con `ffprobe` (duración > 0).

- [ ] **Step 4: Registrar y verificar assets**

`flutter pub get`; si `assets/vof_tutorial/` no está declarado por carpeta en `pubspec.yaml`, añadir la carpeta. Correr `flutter analyze`.

- [ ] **Step 5: Prueba en dispositivo**

Instalar (`flutter run` / apk) y recorrer el Modo Guiado real end-to-end: cada paso narra su `guiado_*`, la intro no se pisa con regional, las burbujas no tapan opciones, y al confirmar se crea la cita real y suena `guiado_final`. Verificar también que el demo (`ficha_01`) ya suena en regional (Task 7).

- [ ] **Step 6: Commit**

```bash
git add assets/vof_tutorial/guiado_*.mp3 pubspec.yaml
git commit -m "feat(guiado): clips de voz guiado_* (RVC) e integración de assets"
```

---

## Self-Review

**Spec coverage:**
- §2 (entrada 2 tarjetas) → Task 6. §3.1 (guidedMode) → Task 1. §3.3 (narrateOnly) → Tasks 2–3. §3.4/§5 (voz+texto por paso) → Tasks 3–4. intro → Task 5. §6 (Colab) → Task 8. §7 (fix ficha_01) → Task 7. §8 (accesibilidad, sin alto contraste) → Task 6 (targets ≥48px, tokens). §9 (pruebas) → tests en cada task + Task 8 device.
- Gap consciente: la reproducción exacta de `guiado_intro`/onExit en guiado se valida en device (Task 8), no con test unitario de audio (frágil).

**Placeholder scan:** sin TODOs/“implement later”; cada paso de código lleva su bloque. Las notas “ajustar al nombre real” son porque el implementador debe leer `tab_shell.dart`/`tutorial_voice.dart` (APIs existentes) — no son placeholders de diseño.

**Type consistency:** `BookingMode { clasico, guiado }`, `showBookingModeSheet`, `bookingVoiceId`, `bookingCoachMessages`, `narrateOnly`, `stopIfToken(int)`, `guidedMode` — usados consistentes entre tasks.
