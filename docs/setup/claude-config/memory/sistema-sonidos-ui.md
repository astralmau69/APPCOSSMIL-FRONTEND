---
name: sistema-sonidos-ui
description: "Familia de sonidos de interfaz generada proceduralmente, catálogo AppSounds y motor de reproducción de SoundManager"
metadata: 
  node_type: memory
  type: project
  originSessionId: 93235790-cb0e-44c4-ab4e-91da0b116506
  modified: 2026-07-21T20:22:15.686Z
---

Sistema de sonidos de interfaz de COSSMIL (creado el 21 jul 2026):

- **Assets**: se generan con `tools/generate_ui_sounds.py` (sintetizador propio en Python puro, sin dependencias ni descargas). Los niveles vienen balanceados ENTRE archivos, así un solo `volume` en Dart escala la familia entera. Total ~120 KB. Cortos en WAV (latencia mínima), largos en MP3 (tamaño). Para cambiar el carácter, editar el diccionario `SOUNDS` y volver a correr el script.
- **Lenguaje sonoro CLÍNICO** (rediseñado el 21 jul 2026 porque la primera versión sonaba a videojuego). Cuatro reglas, documentadas en el encabezado del script: parciales armónicos exactos y discretos (los inarmónicos ×2.01 suenan a campanita de juego), registro medio-grave 330–880 Hz en tonalidad de Re (lo agudo se lee como juguete), ataques de 8–30 ms sin percusión ni ráfagas de ruido, y como mucho DOS notas (cuarta/quinta/tercera) — un arpegio de cuatro notas es una fanfarria de recompensa y esto es una app de salud. La alerta usa tres pulsos iguales, la gramática de prioridad media de los equipos médicos.
- **Catálogo**: `core/constants/app_sounds.dart` — tap, nav, select, back, toggleOn/Off, sheet, coach, advance, success, welcome, error, alert (13, ~103 KB). Nunca poner rutas sueltas en pantallas.
- **Atrás**: `core/routing/sound_navigator_observer.dart` sonoriza TODO el retroceso desde un solo sitio (flecha, botón físico, gesto de borde). Va enganchado al navegador raíz (`app.dart`) y a uno POR pestaña (`_tabSoundObservers` en tab_shell) — un NavigatorObserver no puede servir a dos navegadores, y no debe crearse dentro de `build`. Solo suena para `PageRoute`: los diálogos son `PopupRoute` y quedan fuera. Los pasos del flujo de reserva son estado interno, no rutas, y se sonorizan a mano en `_prevStep`.
- **Bienvenida**: se dispara en `LoadingDataScreen` justo antes de ir a `/home` (los tres caminos de entrada pasan por ahí), pero solo si `SoundManager.isVoicePlaying` es false — la locución del splash dura ~8 s y con huella se llega antes de que termine. El splash registra su player con `SoundManager.registerVoice`.
- **Motor** (`core/theme/sound_manager.dart`): pool de 4 AudioPlayers reciclados, caché de 2 s del modo silencio del ringer (antes era un MethodChannel por cada toque, y llegaba tarde), antirrebote de 45 ms aplicado ANTES del await, y `warmUp()` en main.dart para que el primer sonido de la sesión no se retrase.
- **Regla de diseño**: el sonido acompaña acciones que el usuario inicia y marca resultados; nunca en scroll ni en cada tarjeta de lista. `OptimizedPressButton` tiene `sound:` opcional y por defecto va mudo — solo los CTA (LiquidGlassButton) suenan.
- `showAppDialog` sonoriza la apertura salvo `silent: true` (loaders y modales que ya traen su propio tono).
- Los tres mp3 originales (`ui_pop`, `ui_step`, `ui_warning`) siguen en disco SIN USO: no los sobrescribí porque no estaban en git. Se pueden borrar cuando el usuario confirme.
- Bug del sintetizador que costó encontrar: el corte por envolvente silenciosa debe ignorar la fase de ataque, o mata la voz en la primera muestra (la envolvente arranca en 0) y el archivo sale mudo.
- `SoundManager.debugPlayHook` / `debugResetThrottle` (@visibleForTesting) permiten comprobar qué se reprodujo: `playUi` traga sus errores, así que sin el gancho no habría forma de testear nada de audio.

Relacionado: [[tutorial-flow-system]], [[liquid-glass-system]]
