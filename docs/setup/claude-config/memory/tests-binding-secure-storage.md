---
name: tests-binding-secure-storage
description: Varios test files están rojos por no inicializar el binding + mock de flutter_secure_storage; patrón para arreglarlos.
metadata: 
  node_type: memory
  type: project
  originSessionId: 7d00141f-c119-4a05-8a21-72cbae719de7
  modified: 2026-08-04T13:42:52.457Z
---

La suite estaba con 9 tests ROJOS de base en 2 archivos; **arreglados el 23 jul
2026** → suite completa 74/74 verde. Dos causas distintas:

**Causa A — binding/secure-storage** (`programacion_service_test`, y antes
`initial_data_orchestrator_test`): ejercen código que llega a `TokenStorage` (→
`flutter_secure_storage`, canal de plataforma) sin inicializar el binding →
"Binding has not yet been initialized" en `TokenStorage._readResilient`.
`ApiClient` llama `await TokenStorage.getToken()` antes de cada request, así que
cualquier test que instancie `ProgramacionService`/`ApiClient` lo necesita.
Arreglo (inicio de `main()`, antes de `group`):
```dart
TestWidgetsFlutterBinding.ensureInitialized();
FlutterSecureStorage.setMockInitialValues({}); // sin sesión: reads → null
```
Además: el mock de datos debía usar la clave real del backend — `HospitalModel`
lee el nombre de `json['sucursal']`, NO `'nombre'` (test tenía la clave mal → name '').

**Causa B — `pumpAndSettle` + animaciones infinitas** (`responsive_layout_test`,
pantalla LoginScreen): `LoginScreen._floatCtrl.repeat()` nunca asienta →
`pumpAndSettle()` se cuelga (timeout). Y `FadeSlideIn` (optimized_animations.dart)
agenda un `Future.delayed(widget.delay)` que NO se cancela al dispose → "A Timer
is still pending" en teardown si no se avanza el reloj más allá del delay máximo.
Arreglo: NO usar `pumpAndSettle` en pantallas con animación en bucle; usar pumps
acotados que superen el delay máximo (LoginScreen: 450 ms → `pump(600ms)`). Si el
init dispara audio (`SoundManager.playIfAllowed`, deja Timer del plugin), apagar
sonido antes: `SoundManager.soundEnabledNotifier.value = false;` (directo, sin
`setEnabled` para no escribir en storage).

**Causa C — el primer `pump` solo ARRANCA el ticker** (visto el 4 ago 2026 en
`carnet_screen_test`): tras disparar una animación desde un gesto, el reloj del
`Ticker` empieza a contar en el siguiente frame, así que
`tap(); pump(400ms); pump(300ms)` deja el controller en 300/700, no en 700/700.
Patrón correcto: `tap(); await tester.pump(); await tester.pump(duracionTotal);`
— el `pump()` pelado arranca, el siguiente avanza.

Para probar timeouts sin esperar tiempo real: `package:fake_async` (ya en
dev_dependencies) — `fakeAsync((async){ ...; async.elapse(Duration(...)); })`.
Bajo fakeAsync los mocks de canal se procesan al `elapse`/`flushMicrotasks`.

Relacionado: CLAUDE.md sección API Layer; [[liquid-glass-system]] (FadeSlideIn).
