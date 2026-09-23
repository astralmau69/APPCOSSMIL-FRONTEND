---
name: sintomas-vs-causa-ui
description: "El usuario describe problemas de UI por su síntoma, no por su causa; investigar el layout antes de actuar"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 93235790-cb0e-44c4-ab4e-91da0b116506
  modified: 2026-07-21T21:07:13.239Z
---

Cuando pide un cambio de tamaño ("haz las pantallas un poco más pequeñas", "que se note completo"), casi nunca quiere un cambio de escala: está describiendo el SÍNTOMA de un problema de layout concreto. En jul 2026 "haz las pantallas más pequeñas" resultó ser "el contenido queda tapado por la barra de navegación flotante" — ver [[navbar-tapa-contenido]].

**Por qué importa:** aplicar literalmente un cambio de escala global habría tocado todas las pantallas sin arreglar nada, y el recorte habría seguido ahí.

**Cómo aplicarlo:** ante una petición de tamaño, auditar primero el layout buscando la causa (recortes, solapamientos, padding que falta) y proponer el arreglo concreto. Si de verdad quedan varias lecturas posibles, preguntar con opciones que describan el EFECTO visible, no el parámetro técnico. Escribe en español y describe los problemas por lo que se ve, no por el widget que falla.
