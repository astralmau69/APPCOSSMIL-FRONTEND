---
name: applicationid-real-android
description: "El applicationId real de Android es com.cossmil.citamedicapp, NO el bo.mil.cossmil.app que dice CLAUDE.md."
metadata: 
  node_type: memory
  type: project
  originSessionId: 07deeea5-7840-4029-9e15-191457bb3ecb
  modified: 2026-07-27T17:24:40.002Z
---

`android/app/build.gradle.kts` declara **`applicationId = "com.cossmil.citamedicapp"`**
y `namespace = "com.cossmil.citamedicapp"` (líneas 21 y 36).

CLAUDE.md decía `bo.mil.cossmil.app`, que era falso; **corregido el 27 jul 2026**
tras verificarlo contra el gradle y contra `pm list packages` en la tablet.

**Why:** me llevó a decirle al usuario que un `adb install` se instalaría AL LADO
de la app existente sin pisarla. Falso: es el mismo id, así que la actualizó en
sitio. Por suerte `install -r` conserva los datos (`firstInstallTime` no cambió),
pero la sesión de login SÍ se perdió y hubo que volver a entrar.

**How to apply:** antes de prometer que una instalación no pisa nada, leer el
`applicationId` del gradle, no CLAUDE.md. Y para instalar de verdad en paralelo
haría falta `--flavor` o un sufijo de id, que este proyecto no tiene configurado.

Ya no hay pendiente en CLAUDE.md: la línea de "Android build" lleva el id correcto
y una nota explícita de que un `adb install` REEMPLAZA la app en vez de instalarse
al lado.

Relacionado: [[entorno-build-android-linux]].
