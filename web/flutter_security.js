// flutter_security.js — capa de seguridad SOLO para la versión web.
// El móvil (Android/iOS) NO usa este archivo ni index.html.
//
// Limitaciones reales (sin humo):
//   • Esto NO impide abrir DevTools desde el menú del navegador, ni protege
//     contra alguien técnico. Frena a usuarios casuales.
//   • NO se pueden bloquear capturas de pantalla en web (no existe API).
//     Eso solo aplica en móvil con FLAG_SECURE.
(function () {
  'use strict';

  // ── 1) Disuasivos de inspección ──────────────────────────────────────
  document.addEventListener('contextmenu', function (e) { e.preventDefault(); });
  document.addEventListener('keydown', function (e) {
    var key = (e.key || '').toLowerCase();
    var cmd = e.ctrlKey || e.metaKey; // Cmd en Mac
    if (key === 'f12' ||
        (cmd && e.shiftKey && (key === 'i' || key === 'j' || key === 'c')) || // DevTools
        (cmd && key === 'u')) { // Ver código fuente
      e.preventDefault();
      e.stopPropagation();
    }
  });

  // ── 2) Anti-clickjacking ─────────────────────────────────────────────
  // Si cargan la app dentro de un iframe ajeno, la sacamos al frente.
  // La protección robusta es la cabecera frame-ancestors / X-Frame-Options
  // del servidor; esto es el equivalente del lado cliente.
  try {
    if (window.top !== window.self) {
      window.top.location = window.self.location.href;
    }
  } catch (e) {
    document.documentElement.style.display = 'none';
  }

  // ── 3) Cierre de sesión por inactividad (web) ────────────────────────
  // Equivalente web del bloqueo por inactividad que ya existe en móvil.
  // Tras IDLE_MS sin interacción, borra el token y recarga → vuelve al login.
  var IDLE_MS = 10 * 60 * 1000; // 10 minutos (ajustable)
  var TOKEN_KEYS = ['access_token', 'refresh_token']; // sessionStorage (web_secure_storage)
  var SESSION_KEY = 'user_session_data';              // localStorage (SessionRestoreService)
  var idleTimer = null;

  function hasSession() {
    try {
      return TOKEN_KEYS.some(function (k) { return !!sessionStorage.getItem(k); });
    } catch (e) { return false; }
  }

  function logoutByIdle() {
    if (!hasSession()) return; // en el login no hacemos nada
    try {
      TOKEN_KEYS.forEach(function (k) { sessionStorage.removeItem(k); });
      localStorage.removeItem(SESSION_KEY);
    } catch (e) { /* ignore */ }
    window.location.reload();
  }

  function resetIdle() {
    if (idleTimer) clearTimeout(idleTimer);
    idleTimer = setTimeout(logoutByIdle, IDLE_MS);
  }

  ['mousemove', 'mousedown', 'keydown', 'touchstart', 'scroll', 'click']
    .forEach(function (evt) {
      window.addEventListener(evt, resetIdle, { passive: true });
    });
  resetIdle();
})();
