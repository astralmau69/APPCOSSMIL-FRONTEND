---
name: tutorial-flow-system
description: Cómo agregar tutoriales guiados multi-pantalla (TutorialFlow + TutorialFlowHost) y trucos de test del coach
metadata: 
  node_type: memory
  type: project
  originSessionId: 93235790-cb0e-44c4-ab4e-91da0b116506
  modified: 2026-07-22T17:56:47.544Z
---

Sistema de tutoriales guiados de COSSMIL (además del de "sacar una ficha" que usa `bookingState.isTutorialMode`):

- `core/services/tutorial_flow.dart` — `TutorialFlow` (ValueNotifier estático, enum `GuidedTutorial`: calendario | tramites). Para recorridos sobre pantallas push que no reciben `tabShell`.
- `core/widgets/tutorial_flow_host.dart` — `TutorialFlowHost` monta el coach + Listener de colapso sobre cada pantalla; el `builder` recibe `tutorialActive` para envolver el objetivo con `GuidedTapHint`.
- Reglas: paso final → `celebrate: true, confirmOnExit: false`; pantalla raíz de recorrido push → `stopOnDispose: true`; `goToTab` cancela en silencio solo al cambiar a OTRO tab.
- **Los TRES tutoriales arrancan en el menú de Inicio** (21 jul 2026). `homeTutorialNotifier` pasó de `ValueNotifier<bool>` a `ValueNotifier<GuidedTutorial>` (el enum ganó `ficha`): su valor dice quién espera en Inicio. `_esperarEnInicio()` es el arranque común y `enterHomeTutorialTarget()` el salto al recorrido cuando el usuario toca la tarjeta resaltada. HomeScreen resalta la tarjeta objetivo con `_homeTutorialTarget()` (por etiqueta del menú) y atenúa el resto; ojo: si el objetivo está en la grilla NO se atenúa la grilla, solo el héroe. Calendario y Trámites pasaron de 4 a 5 pasos.
- Arranque: `TabShell.startCalendarioTutorial()` / `startTramitesTutorial()`, tiles en Perfil → AYUDA.
- Accesibilidad del coach (jul 2026): burbujas en live region, sin auto-colapso con lector de pantalla, contador "X/N" en el globito minimizado.
- Truco de tests: en fake-async el primer tick de un AnimationController reporta elapsed 0 — hacen falta DOS `pump()` antes de tapear widgets dentro de ScaleTransition (si no, escala 0 y el hit-test falla). `containsSemantics` está deprecado en Flutter 3.44 → usar `isSemantics`.
- La memoria MCP de ruflo (`memory_store`) puede fallar con "active native WAL connection" — no es bloqueante, reintentar en otra sesión.
- **Bug arreglado (22 jul 2026): tutoriales de Calendario/Trámites quedaban ATRAPADOS.** La tarjeta resaltada del menú de Inicio usa su `onTap` normal (`goToTab(3)` / `openSubRoute(Procedimientos)`), que NO resetea `homeTutorialNotifier` ni llama a `TutorialFlow.start`. Resultado: al entrar, la navbar seguía muerta (`_guardNavDuringTutorial` la envuelve en `IgnorePointer(ignoring: homeTutorialNotifier!=none)`) y el coach nunca montaba → "no se puede hacer nada", sin botón Salir. Fix en `home_screen._buildQuickActions`: cuando la tarjeta ES el objetivo (`esObjetivo`), se construye con `onTap: () => tabShell.enterHomeTutorialTarget(context)` (que sí resetea el notifier y arranca el recorrido). El héroe "Nueva Reserva" (ficha) ya lo hacía inline; solo faltaba en las tarjetas de la grilla.
- **Burbujas del coach = chat de verdad (22 jul 2026).** `_CoachBubbles` pasó a stateful: la 1ª burbuja se muestra ya, las siguientes se revelan una por una tras un indicador de "escribiendo…" (`_TypingBubble`, tres puntitos en oleada). Con reduce-motion o lector de pantalla salen todas de golpe (instant). El typing bubble usa `key: ValueKey('typing')` (útil en tests). GuidedTapHint ganó respiración (`Transform.scale` 1.02), dedito que rebota (mano derecha rotada 90°) y RepaintBoundary.

Relacionado: [[liquid-glass-system]], [[instructora-tutorial-asset]], [[ruflo-instalado]]
