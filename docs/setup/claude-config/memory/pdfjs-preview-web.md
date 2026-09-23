---
name: pdfjs-preview-web
description: La vista previa de PDFs en web depende de pdf.js precargado en index.html; dartPdfJsBaseUrl crashea printing 5.14.3
metadata: 
  node_type: memory
  type: project
  originSessionId: daf2a6f0-af93-4670-a3c8-4248e1770766
---

La previsualización de trámites en web (`Printing.raster`) funciona solo porque `web/index.html` precarga `pdfjs/pdf.min.js` + `pdfjs/init.js` (workerSrc + shim de eval). Verificado el 2026-07-14.

**Why:** `printing` 5.14.3 tiene un bug de interop: si existe `window.dartPdfJsBaseUrl`, lanza `TypeError: String is not a subtype of Never` y la vista previa muere ("No se pudo generar la vista previa"). Además su detección de pdfjsLib usa `window.eval`, que la CSP de release (`build_release.ps1`, sin 'unsafe-eval') bloquearía; el shim de `init.js` responde esa consulta sin eval. Relacionado con [[web-docker-lan-deploy]]: nada puede venir de CDN.

**How to apply:** No reintroducir `window.dartPdfJsBaseUrl` ni borrar `web/pdfjs/init.js` mientras printing sea 5.14.x (la 5.15+ no resuelve con las restricciones actuales de deps). Si se actualiza `printing`, re-probar la vista previa con una sonda `-t` sin login antes de confiar.
