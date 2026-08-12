/*
  Animación de la pantalla de carga previa a Flutter (GSAP 3.13).

  Por qué existe: hasta que el motor de Flutter termina de descargarse y
  arrancar, el <body> está vacío y el usuario ve un blanco sin señal alguna.
  En debug eso puede durar minutos (el compilador sirve ~3000 módulos sueltos),
  y no había forma de distinguir "cargando" de "colgado".

  Este es el ÚNICO lugar de la app donde GSAP puede operar: aquí hay DOM real.
  Una vez que Flutter arranca, pinta todo dentro de un <canvas> y ninguna
  librería JS de animación tiene acceso a su contenido.

  GSAP se sirve desde web/gsap/ (no CDN): la CSP de release es
  `default-src 'self'` y los equipos que entran por LAN no tienen internet.
*/
(function () {
  'use strict';

  var loader = document.getElementById('cossmil-loader');
  if (!loader) return;

  var bar = loader.querySelector('.cl-bar');
  var hint = loader.querySelector('.cl-hint');
  var pieces = loader.querySelectorAll('.cl-logo, .cl-title, .cl-track');

  var gsap = window.gsap;
  var removed = false;

  /** Retira el loader del DOM. Idempotente: `flutter-first-frame` puede
   *  dispararse más de una vez si Flutter re-inicializa la vista. */
  function remove() {
    if (removed) return;
    removed = true;
    if (loader.parentNode) loader.parentNode.removeChild(loader);
  }

  // ── Respaldo sin GSAP ────────────────────────────────────────────────────
  // Si el script de GSAP no cargó, el loader debe verse igual (estático) y
  // desaparecer igual. Nunca dejar la pantalla invisible ni bloqueada.
  if (!gsap) {
    loader.style.visibility = 'visible';
    window.addEventListener('flutter-first-frame', remove);
    return;
  }

  var mm = gsap.matchMedia();

  mm.add({ reduce: '(prefers-reduced-motion: reduce)' }, function (ctx) {
    var reduce = ctx.conditions.reduce;

    gsap.set(loader, { visibility: 'visible' });

    // Entrada escalonada. Con reduce-motion no hay desplazamiento ni escala:
    // los elementos simplemente aparecen.
    var intro = gsap.timeline();
    if (reduce) {
      intro.set(pieces, { autoAlpha: 1 });
    } else {
      intro.from(pieces, {
        autoAlpha: 0,
        y: 14,
        duration: 0.5,
        ease: 'power2.out',
        stagger: 0.08
      });
    }

    // Barra indeterminada: recorre el riel en bucle. No finge un porcentaje
    // — no conocemos el progreso real del arranque de Flutter — solo comunica
    // que el proceso sigue vivo. Con reduce-motion se queda quieta y llena.
    if (reduce) {
      gsap.set(bar, { xPercent: 0, width: '100%' });
    } else {
      gsap.fromTo(
        bar,
        { xPercent: -105 },
        {
          xPercent: 240,
          duration: 1.15,
          ease: 'power1.inOut',
          repeat: -1
        }
      );
    }

    return function () {
      intro.kill();
    };
  });

  // ── Mensajes ─────────────────────────────────────────────────────────────
  // El primero aparece enseguida. El de los 20 s existe porque una espera
  // larga sin explicación se lee como app colgada: se dice explícitamente que
  // sigue trabajando en vez de dejar al usuario adivinando.
  var hintTimers = [
    setTimeout(function () {
      setHint('Preparando la aplicación…');
    }, 600),
    setTimeout(function () {
      setHint('Esto está tardando más de lo normal. Seguimos cargando…');
    }, 20000)
  ];

  function setHint(text) {
    if (removed || !hint) return;
    gsap.to(hint, {
      autoAlpha: 0,
      duration: 0.18,
      onComplete: function () {
        hint.textContent = text;
        gsap.to(hint, { autoAlpha: 1, duration: 0.25 });
      }
    });
  }

  // ── Salida ───────────────────────────────────────────────────────────────
  // `flutter-first-frame` es el evento que Flutter web dispara cuando ya pintó
  // su primer frame: recién ahí hay algo debajo que mostrar. Salir antes
  // dejaría ver un blanco.
  window.addEventListener('flutter-first-frame', function () {
    if (removed) return;

    hintTimers.forEach(clearTimeout);
    mm.revert();

    gsap.to(loader, {
      autoAlpha: 0,
      duration: 0.4,
      ease: 'power2.inOut',
      onComplete: remove
    });
  });
})();
