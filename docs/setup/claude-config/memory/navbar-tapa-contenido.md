---
name: navbar-tapa-contenido
description: La barra flotante tapa el fondo de las pantallas si no reservan navBarBottomSpace; cómo auditarlo
metadata: 
  node_type: memory
  type: project
  originSessionId: 93235790-cb0e-44c4-ab4e-91da0b116506
  modified: 2026-07-21T21:06:56.792Z
---

El `FloatingNavBar` se dibuja ENCIMA del contenido (`Scaffold` con `extendBody`), así que toda pantalla que viva dentro de una pestaña debe reservar `r.navBarBottomSpace` en el padding inferior de su scroll **y** en cualquier barra de acciones fija al fondo. Si no, el último elemento queda cortado — el síntoma que el usuario describe como "no se ve completo" o "hazlo más pequeño".

Auditoría rápida (21 jul 2026 encontró 6 pantallas + 2 barras de PDF sin reservar espacio):

```bash
for f in $(grep -rln "CustomScrollView\|ListView\|SingleChildScrollView" lib/features --include="*.dart"); do
  grep -q "navBarBottomSpace" "$f" || echo "${f#lib/features/}"
done | sort
```

Falsos positivos legítimos (no llevan barra, no tocar): rutas del navegador RAÍZ (login, password_change, loading_data, security_setup — se empuja con `rootNavigator: true`), diálogos y modales, y `features/carnet/` (pantallas sin instanciar; el menú muestra "Próximamente").

Ojo con lo que NO detecta ese grep: barras de acciones fijas al fondo de visores de PDF, que se empujan con `Navigator.push` en el navigator de la pestaña y también quedan debajo.

Relacionado: [[tutorial-flow-system]]
