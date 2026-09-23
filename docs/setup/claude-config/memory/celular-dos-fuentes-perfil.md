---
name: celular-dos-fuentes-perfil
description: El celular del perfil viene de dos tablas distintas (usuarioweb vs safil.asegurado); solo phone persiste al editar
metadata: 
  node_type: memory
  type: project
  originSessionId: b60c4c3e-bf5d-4e1b-9d71-81142811e93e
---

El "celular" del usuario tiene **dos fuentes de backend distintas** y esto causa confusión al editar:

- `UserModel.phone` ← JWT del login (`tokenModel.numeroCelular`) → tabla **`usuarioweb`**. Es lo que el usuario edita en `perfil_screen.dart` (`_savePhone` → `AuthService.updateProfile` → `PUT /api/usuarioweb/update-profile/{idper}`). **SÍ persiste** tras re-loguear (verificado empíricamente jul 2026).
- `UserModel.numCel` ← endpoint `aseg-tipo-gpo` (`GET /api/safil/asegurado/aseg-tipo-gpo/{matricula}`) → tabla **`safil.asegurado`**. `update-profile` NO escribe aquí, así que **revierte** al valor viejo en cada login/restore.

**Síntoma que lo delata:** editar el celular se guardaba en Perfil (muestra `phone`) pero NO en la tarjeta de inicio (`ProfessionalProfileCard` mostraba `numCel`) tras cerrar y reabrir.

**Fix aplicado (frontend):** `professional_profile_card.dart` ahora prefiere `phone` sobre `numCel` (`phone.isNotEmpty ? phone : numCel`). Además `_savePhone`/`_saveEmail` en `perfil_screen.dart` actualizan `UserSession.currentUser` + `SessionRestoreService.saveUserSession(...)` (antes solo hacían setState local → no persistía ni refrescaba la tarjeta reactiva de Home vía `userNotifier`).

**Pendiente backend (Capa B):** para que `numCel` (safil.asegurado) también se actualice, el backend debe sincronizar ambas tablas o exponer un endpoint tipo `actualiza-datosper`. El **carnet** (`carnet_data.dart`) aún usa `numCel` como teléfono de referencia. Ver [[web-docker-lan-deploy]] para cómo se sirve/prueba la web.
