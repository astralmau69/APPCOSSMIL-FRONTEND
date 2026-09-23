---
name: numero-soporte-cossmil
description: "El número de soporte técnico (DNTIC/COSSMIL) vive en dos lugares independientes del código — Contactos y Login — y ahora es 71292794 (móvil, con WhatsApp)."
metadata: 
  node_type: memory
  type: project
  originSessionId: 0ecdcb35-dccf-4706-9f0f-aaec49a9766a
  modified: 2026-07-28T19:36:02.345Z
---

Hay DOS números de "soporte" distintos y sin relación en el código, fácil de confundir:

1. `_DnticSupportCard._phone` en `lib/features/home/screens/contactos_screen.dart` (tarjeta "Soporte DNTIC", dentro de Contactos COSSMIL). Antes era un fijo `22248745`.
2. El botón flotante de soporte en `lib/features/auth/screens/login_screen.dart` (`_buildSupportFab` / `_showSupportSheet`). Antes era `71527970`.

Ambos se actualizaron el 2026-07-28 al mismo número: **71292794**.

**Why:** pedido explícito del usuario. Al ser ahora un número móvil boliviano (prefijo 7, no un fijo 2xxxxxx de La Paz), sí soporta WhatsApp — el usuario pidió explícitamente aprovechar eso ("mejora esta parte") para agregar acceso a WhatsApp en la tarjeta de Contactos, igual que ya existía en el botón de soporte de Login (`https://wa.me/591$numero`).

**How to apply:** se agregó `_ContactosScreenState._openWhatsApp` (mismo patrón `wa.me/591` que login) y un botón "WhatsApp" (verde `0xFF25D366`) junto al de "Llamar" en la tarjeta Soporte DNTIC, más un `_ActionButton` de WhatsApp junto a copiar/llamar. Si el número de soporte vuelve a cambiar, actualizar los DOS sitios (no hay una constante compartida) y revisar si sigue siendo móvil antes de dejar el botón de WhatsApp.
