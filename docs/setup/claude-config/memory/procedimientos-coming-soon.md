---
name: procedimientos-coming-soon
description: "La tarjeta \"Procedimientos COSSMIL\" en Inicio se gateó a \"Estamos trabajando\" (comingSoon), igual que Mi Carnet COSSMIL; el tutorial guiado queda intacto."
metadata: 
  node_type: memory
  type: project
  originSessionId: 0ecdcb35-dccf-4706-9f0f-aaec49a9766a
  modified: 2026-08-04T13:42:27.220Z
---

La tarjeta "Procedimientos COSSMIL" (home_screen.dart) ya no abre `ProcedimientosScreen` directamente: ahora tiene `comingSoon: true` y su `onTap` llama a `showComingSoonDialog`. El import de `procedimientos_screen.dart` se quitó de home_screen.dart por quedar sin uso ahí.

**OJO (2026-08-04):** "Mi Carnet COSSMIL" ya NO está gateado — se habilitó y su tarjeta vuelve a hacer `openSubRoute` a `CarnetScreen`. Procedimientos es ahora el único `comingSoon` de Inicio. Ver [[carnet-digital-habilitado]].

**Why:** pedido explícito del usuario 2026-07-28: "en procedimientos cossmil ciérralo con el mensaje de trabajando al igual que su tutorial" — confirmado vía pregunta de aclaración que quería gatear TODA la tarjeta, no solo el paso final del tutorial. La feature de trámites (PDF/Word autocompletado, ver [[tramite-flow-...]]) sigue implementada y funcional en el código, solo el acceso real desde Inicio quedó oculto hasta autorización oficial de COSSMIL (mismo motivo que Carnet Digital).

**How to apply:** el tutorial guiado ("Cómo generar un trámite", Perfil → Ayuda → `TabShell.startTramitesTutorial()` → `enterHomeTutorialTarget`) sigue empujando `ProcedimientosScreen` de forma independiente del `onTap` de la tarjeta — no se tocó, porque es inofensivo (termina en `formularios_screen.dart` paso 5/5 SIN pulsar "Generar", ver [[tutorial-flow-system]]). Si en el futuro COSSMIL autoriza el lanzamiento real: quitar `comingSoon: true` y restaurar `onTap: () => widget.tabShell.openSubRoute(context, (_) => const ProcedimientosScreen())` (mismo texto de reactivación que dejamos en el comentario del código).
