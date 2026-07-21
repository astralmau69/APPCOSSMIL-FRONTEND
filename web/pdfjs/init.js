// Configura el worker de pdf.js autoalojado. Debe ejecutarse después de
// pdf.min.js (ambos con defer en index.html, que preserva el orden).
// Con workerSrc definido, el paquete `printing` da pdfjsLib por listo y no
// intenta cargarlo desde unpkg.com (bloqueado en la LAN sin internet).
if (window.pdfjsLib) {
  window.pdfjsLib.GlobalWorkerOptions.workerSrc = 'pdfjs/pdf.worker.min.js';
}

// El paquete `printing` comprueba pdfjsLib con window.eval(...), que la CSP
// de release (sin 'unsafe-eval') bloquearía y rompería la vista previa.
// Este shim responde SOLO esa consulta conocida sin evaluar código; cualquier
// otro eval sigue su curso normal (y la CSP sigue aplicando).
(function () {
  var realEval = window.eval;
  window.eval = function (src) {
    if (typeof src === 'string' && src.indexOf('pdfjsLib') !== -1 &&
        src.indexOf('GlobalWorkerOptions') !== -1) {
      return typeof window.pdfjsLib !== 'undefined' &&
        window.pdfjsLib.GlobalWorkerOptions.workerSrc != '';
    }
    return realEval(src);
  };
})();
