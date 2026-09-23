---
name: dialogos-showappdialog
description: Convención de movimiento para diálogos/modales — usar showAppDialog en vez de showCupertinoDialog
metadata: 
  node_type: memory
  type: project
  originSessionId: b60c4c3e-bf5d-4e1b-9d71-81142811e93e
---

**Convención (jul 2026):** todos los diálogos de la app usan el helper `showAppDialog<T>()` de `lib/core/animations/app_dialog.dart` para un movimiento **consistente y suave**: entrada fade + escala 0.94→1.0 (`AppCurves.snappy`), salida animada automática (reversa de `showGeneralDialog`), respeta reduce-motion (`MediaQuery.disableAnimations`), y es seguro en Flutter web/CanvasKit (solo anima opacidad + transform).

**Por qué:** antes cada pantalla resolvía el movimiento a mano — el default de `showCupertinoDialog` se percibía brusco, y varios `showGeneralDialog` no tenían `transitionBuilder` (aparecían de golpe: `doctor_rating_modal`, `tab_shell` cita activa). Se unificó todo.

**How to apply:**
- Para un diálogo nuevo: `showAppDialog(context: ..., builder: (ctx) => CupertinoAlertDialog(...))`. Acepta `barrierDismissible`, `barrierColor`, y genéricos `<bool>/<void>` para devolver resultado con `Navigator.pop(ctx, valor)`.
- El `builder` puede devolver `CupertinoAlertDialog` (se auto-centra) o cualquier widget (envuélvelo en `Center`).
- NO volver a `showCupertinoDialog`. Los diálogos con transición propia ya pulida (ej. modal de recordatorio en `notification_ui.dart` con `easeOutBack`) se dejaron como están.
- Nota: `showGeneralDialog`/`showCupertinoDialog` no exportan `showAppDialog`; cada archivo que lo use necesita `import '.../core/animations/app_dialog.dart';` (la ruta relativa varía por carpeta).

Relacionado: la web se prueba en Docker ([[web-docker-lan-deploy]]); usé la skill `flutter-animations` (no las de `npx ui-skills`, que son CSS/React y no aplican a Flutter).
