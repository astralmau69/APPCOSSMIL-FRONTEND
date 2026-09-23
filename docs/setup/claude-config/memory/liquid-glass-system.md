---
name: liquid-glass-system
description: Sistema centralizado de superficies liquid glass en core/widgets/liquid_glass.dart — regla de cuándo usar blur real vs vidrio simulado
metadata: 
  node_type: memory
  type: project
  originSessionId: 60a35594-061b-43ad-9f51-59b3e7111521
---

La estética de la app es "liquid glass profesional/médico" centralizada en `core/widgets/liquid_glass.dart`: `LiquidGlass` (superficie con borde especular en gradiente + relleno translúcido) y `LiquidGlassButton` (CTA tintado con sheen + filo blanco + háptico).

**Why:** El usuario pidió llevar toda la app a liquid glass sin perder el look médico sobrio; la skill `cossmil_ios_architect` §16 veta `BackdropFilter` por ítem de lista (ahoga la GPU).

**How to apply:**
- `blur: true` SOLO en superficies arquitectónicas y una a la vez: diálogos ([[dialogos-showappdialog]]), bottom sheets, nav bars.
- Tarjetas repetidas en scroll (grilla del Home, listas): `blur: false` (translucidez + borde especular, sin saveLayer).
- CTAs de color pleno con estado propio (login con spinner, héroe "Nueva Reserva"): no reemplazar por `LiquidGlassButton`; aplicar la firma a mano — sheen superior en el gradiente (stop claro al 0.0) + `Border.all(white alpha 0.28-0.30, width 1)`.
- El FloatingNavBar pinta el borde especular con el truco: contenedor exterior con gradiente + padding 1.2 px.
