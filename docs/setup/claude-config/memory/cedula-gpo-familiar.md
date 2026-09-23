---
name: cedula-gpo-familiar
description: El endpoint gpo-familiar NO devuelve la cédula (CI) de los familiares; los trámites la recuerdan localmente
metadata: 
  node_type: memory
  type: project
  originSessionId: c278de39-fa9a-454d-b373-4c26597e5e59
---

Confirmado por logcat (2026-07-15): el endpoint `/api/safil/afiliado/gpo-familiar/{idper}` devuelve por persona solo `mat, pat, nom, idper, parentesco, mtrben, mtrtit, atencion, sexo, edad, foto` — **no incluye la cédula de identidad (CI/docide)**. Por eso los formularios de "Procedimientos COSSMIL" no pueden autocompletar la CI de los beneficiarios (sí la del titular, que viene del JWT).

**Solución aplicada:** `TramiteCiStore` (core/services/tramite_ci_store.dart) persiste la CI escrita por persona (clave = matrícula o id) en flutter_secure_storage; el formulario ([[celular-dos-fuentes-perfil]] usa el mismo patrón de fuentes) la autocompleta en visitas siguientes. `BeneficiaryModel.fromJson` ya acepta ci/docide/cedula/nrodoc/numdoc por si el backend lo agrega en el futuro — si eso pasa, se jala automáticamente sin tocar código.

Para que se jale sin escribirla, el backend tendría que agregar la CI a ese endpoint (o exponerla en aseg-tipo-gpo por matrícula, que hoy tampoco la trae en la extracción actual).
