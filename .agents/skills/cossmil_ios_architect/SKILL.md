---
name: COSSMIL iOS Architect (v0.03)
description: Guía UX/UI nativa iOS para auditar, diseñar y refactorizar interfaces de alta fidelidad en el directorio v0.03 garantizando performance y coherencia.
---

# COSSMIL iOS UX/UI Architect (v0.03)

## 1. Nombre del skill
COSSMIL iOS UX/UI Architect

## 2. Propósito
Garantizar una experiencia de usuario (UX) e interfaz (UI) de altísima fidelidad nativa de iOS para la aplicación COSSMIL. El asistente IA utilizará este skill para auditar, diseñar, refactorizar y guiar implementaciones visuales hiper-enfocadas en las *Human Interface Guidelines (HIG)* de Apple, previniendo el "uncanny valley" multiplataforma en Flutter, combatiendo el jank (caídas de cuadros) y mejorando el proyecto sin destruir la arquitectura técnica actual en evolución.

## 3. Directorio objetivo de ejecución
El agente asume por default que su cwd (Current Working Directory) e inspección raíz es la rama y directorio **`v0.03`** del proyecto de repositorio. Si no es así, debe referenciar en ruta estricta los contenidos pertenecientes a `v0.03`.

## 4. Fuente de verdad
1. El código real existente en el directorio `v0.03` (rutas, componentes `auth`, `booking`, `home`, `familia`, `perfil`, `reservas` y `shell`).
2. Si la documentación interna indica un paradigma distinto al de la UI existente, el código dicta cómo operar; la teoría documentada solo sirve como guía referencial para sugerir la estandarización final.

## 5. Cuándo usarlo
- Al iterar, construir o refactorizar el front-end visual de cualquier pantalla.
- Al implementar modales, alertas, listas, botones o tabs buscando la máxima experiencia tipo iPhone/iPad.
- Al detectar cuellos de botella en el rendimiento visual (jank, reconstrucciones pesadas, memory leaks en animaciones).
- Al querer alinear y limpiar inconsistencias entre vistas generadas de forma rápida o sin sistema de diseño.

## 6. Cuándo no usarlo
- Para rediseñar lógicas puras de Backend/Servicios que no tienen ningún impacto visual (`HTTP`, `DTOs`).
- En repositorios que busquen exclusiva compatibilidad gráfica pura de Google Material Design para Android de manera excluyente.

## 7. Supuestos operativos
- La app ya usa la navegación asíncrona por Tabs desde `tab_shell.dart`.
- Mezcla Material y Cupertino actualmente; esta transición debe ir armonizándose iterativamente hacia un render iOS limpio sin demoler masivamente la app en un solo PR (Pull Request).
- Depende centralmente de un `BookingState` para el flujo complejo; los rediseños visuales DEBEN amarrarse y escuchar a este estado de la misma forma en que el original lo interactuaba.

## 8. Principios rectores de UX/UI iOS
- **Clarity (Claridad):** El texto es sumamente legible, los íconos importan, y las decoraciones no compiten contra el contenido central.
- **Deference (Deferencia):** La interfaz cede la atención al contenido. Espacio en blanco generoso, tipografías marcadas. No sobre-cajas, ni bordes groseros e innecesarios entre cada componente.
- **Depth (Profundidad):** Uso intensivo de translucidez (blur dinámico tipo *glassmorphism*), y capas tipo "superficie" que ayudan a comprender intuitivamente dónde está parado el usuario.

## 9. Reglas obligatorias
- **Nativo, no genérico:** Huir del "uncanny valley". Evitar animaciones rígidas, *ripples* duros bajo tabs, y geometrías filosas o burdas. Preferir curvas sutiles continuas.
- **Inspeccionar Antes de Dictar:** Antes de arrojar código visual, debes `view_file` el estado actual de la pantalla para entender el layout original, adaptando la mejora HIG a la limitante estructural impuesta.
- **Respeto a la Evolución:** Toda optimización debe ser incremental y conectable al árbol de `v0.03` de manera segura, sin sobreingeniería excesiva.

## 10. Flujo de trabajo paso a paso
1. **Auditoría UI `cwd`:** Ejecutar inspección profunda a la vista (e.g. `lib/features/home/screens/home_screen.dart`). 
2. **Evaluación iOS HIG:** Diagnosticar la mezcla de Material vs Cupertino, y fallos de proporción/espaciado negativo (ej. padding default vs iOS Standard de 16/20 pts en bordes laterales).
3. **Análisis de Jank (Rendimiento):** Encontrar animaciones que estrangulen el hilo (vistas enteras re-renderizandose, falta de opacidades vectoriales y falta del const).
4. **Propuesta de Mejora Local:** Entregar el snippet ajustado. Ej: Reemplazar un rústico dialog por un `CupertinoActionSheet`.
5. **Aceptación y Cierre:** Validar con el roadmap que el layout devuelto no quebrar la accesibilidad global.

## 11. Checklist de fidelidad iOS
- [ ] Sustituir `BorderRadius.circular(8)` rústicos por geometría más sofisticada en layouts predominantes.
- [ ] Listas alineadas lógicamente con `ListTile` o equivalentes agrupados al estilo `CupertinoListSection.insetGrouped`.
- [ ] No existen sombras (`boxShadow`) genéricas saturadas o elevadas irreales: preferir sombras translúcidas (ej. opacidad al 3%) super finas y desplazadas en Y, o evitar las sombras del todo adoptando el paradigma Flat/Depth de iOS 15+.
- [ ] Switch, Progress Indicators y Modales de Alerta adoptan el Look and Feel local de Cuppertino instintivamente en su árbol render.

## 12. Checklist de navegación y transiciones
- [ ] Compatibilidad y respeto al *swipe-back* (arrastre natural) nativo de iOS (no bloquearlo).
- [ ] Transiciones tipo `CupertinoPageRoute` priorizadas en sub-listas jerárquicas; Sheets/Modales deslizando desde abajo `modalBottomSheet` de forma elástica.
- [ ] Correcta utilización de los Títulos Grandes (`SliverNavigationBar.largeTitle`) donde aportan autoridad y contexto a listas grandes (Reservas, Familia, Doctores).
- [ ] En TabShell, persistencia estricta de cada Navigator: regresar de una tab no colisiona violentamente la otra.

## 13. Checklist de tipografía y contenido
- [ ] Respeto por familias San Francisco-like o la definida en el branding sin caer en `Roboto` tosco donde destaque como error genérico.
- [ ] Títulos principales de pantallas en fontWeight destacado (ej. `w600` o `w700`), cuerpo de texto legíble (`w400`) y con tracking ajustado.
- [ ] Cero tamaños forzables estáticos en contenido principal (Preparado en Responsive Dynamic Type). Mínimo recomendado base: 17pt de fuente de lectura. 
- [ ] Textos semánticos: contrastes sutiles usando variantes secundarias de colores del sistema (`Colors.grey.shade600` o `secondaryLabel`) en lugar de negros absolutos.

## 14. Checklist de geometría visual y superficies
- [ ] No abusar de "Cards" separadas individualmente en pantallas de formulario. Se agrupan bajo "CupertinoInsetGrouped" para coherencia de setting/perfil.
- [ ] Botones "prominentes" con área de impacto amplia, alineados al fondo de la pantalla (Safe Area) si son Confirmaciones Call To Action vitales (ej. Reservar).

## 15. Checklist de motion, físicas y microinteracciones
- [ ] Prohibido el uso masivo de animaciones lineales acartonadas (`Curves.linear`). Usar físicas de resorte/spring (`Curves.easeOutCubic`, `spring` solvers nativos) típicos en iOS.
- [ ] Microinteracciones: En botones vitales, la pulsación no causa explosiones de splash (ripple effect) tipo default-material. Debe achicarse levemente la opacidad/escala en el down-state.
- [ ] Evitar saltos repentinos y violentos de pantalla o contenido oculto (Jumping UI) al resolver un fallback (HTTP Loader). Transicionar el "Loading" al "Éxito" suavemente (`AnimatedSwitcher`).

## 16. Checklist de blur, translucidez y materiales
- [ ] Barras de navegación/Tabs utilizan `BackdropFilter` o `CupertinoNavigationBar` translúcido, filtrando el contenido scrollable debajo de ellos en listas largas.
- [ ] Cuidado estricto del Rendimiento (`SaveLayer`/`BackdropFilter` ahogan GPUs débiles): restringir estos blurs arquitectónicos solo en los bordes o modales institucionales, no en un tile por item del ListView.
- [ ] Fondos primarios adoptan tonos gris extremadamente claros en LightMode (ej. alternando `F2F2F7` de sistema general contra `FFFFFF` en tarjetas).

## 17. Checklist de accesibilidad
- [ ] Área de toque (Hitbox / Tap Target) respeta el estándar mínimo absoluto de iOS (44x44 pt). 
- [ ] Contraste tipográfico verificable por el ratio de legibilidad WCAG. Ningún texto gris-sobre-gris ilocalizable en descripciones de Doctores o Especialidades.
- [ ] Envoltorios de Semantics (`Semantics(label: ...)`) en imágenes no descriptivas o íconos que actúan solos como botones.

## 18. Checklist de rendimiento visual
- [ ] El inspector visual descartaría `RepaintBoundary` rotos. El jank previsible está encapsulado.
- [ ] Imágenes cargadas desde la carpeta `assets/` en los listados NO deben consumir gigabytes en RA. Configurar ancho max de cache.
- [ ] Minimizar animaciones activas y vivas si el ListView o Sliver se está desplazando velozmente (para que la interpolación no consuma todos los ciclos Ticker).
- [ ] `setState` de controles locales (ej. selección en BookingState) son finitos, contenidos al child y const.

## 19. Reglas para convivir Material + Cupertino en este repo
- **Pragmatismo Visual:** Si una pantalla (como `auth`) ya es profundamente Material en `v0.03` y funcional, no obligues a migrar cada línea en un ticket aislado sobre "un solo texto". Identifica si vas a hacer "Ajustes de espaciado Material para que se vea premium" o un "Cupertino Refactor Total de la Vista".
- Para diálogos de confirmación crítica, fuerza el `CupertinoAlertDialog`. En pantallas form/formularios nativos usa Cupertino Picker. El cruce es aceptable si es iterativo visualmente premium.

## 20. Reglas para refactorizar pantallas existentes sin romper el proyecto
- Respetar al pie de la letra el `BookingState`. Rediseña `reservas_screen` alterando la visual de la UI en la capa `build` y delegando/inyectando las llamadas `state.selectSpecialty()` en idénticas interacciones a la original, para salvaguardar el scope asincrónico.
- Los Layouts se reestructuran sin eliminar features funcionales ya creados o dependencias nativas instaladas (`pdf/printing`).

## 21. Reglas para crear nuevos componentes visuales
- Todos los componentes nuevos puramente UI deben residir en la carpeta de *features/nombre_feature/widgets/* subasociada sin anidar lógicas allí.
- Su implementación primaria se basa en la inmutabilidad plena (StatelessWidget de constructores robustos, o AnimatedWidgets dedicados).

## 22. Reglas para definir patrones reutilizables
- Si auditas dos alertas visuales (ej. Modales de Error API) construidas diversificadamente en home vs auth, centralízalos de inmediato en `lib/core/widgets/cossmil_ios_alert.dart`.
- Evita exportar librerías completas en barriles destructivos, mantener scopes minimales.

## 23. Errores comunes a evitar en v0.03
- Anidar un `CupertinoScaffold` dentro de un `Scaffold` Material ignorante solapando las *Status Bars* y anulando las *Safe Areas*.
- Ignorar que el "splash" ya se ejecuta al volver del background por variables del main app y reescribir un segundo splash nativo defectuoso pisando lógicas.
- Invertir componentes: forzar que un ScrollView dicte el tamaño rígido a su padre perdiendo la elástica `bouncingScrollPhysics` nativa iOS.

## 24. Output esperado del asistente cuando use este skill
- Identificación de discrepancias del archivo contra los "HIG de iOS" (Ej: *Demasiado padding material genérico*, *Falta tap-target mínimo en este AppBar*).
- Fragmentos exactos de reemplazo que integren widgets const y opcionalmente adaptadores (Themes/CupertinoStyles).
- Claridad técnica si la edición puede introducir Jank en la lista de Doctores o Especialidades pre-optimizadas.

## 25. Definition of Done UX/UI
La mejora está completa si y solo si: 
- Navega fluidamente integrándose con el Swipe-to-back.
- Mantiene sus sombras o profundidad sin ahogar los milisegundos de GPU Ticker en profile mode.
- Todo tap target es 44+ píxeles absolutos.
- Las tipografías de contraste pasaron auditoría visual primaria.
- La pantalla y lógica Mock/Intranet en paralelo del `BookingState` o `tab_shell` no sufrió alteración funcional en el backend.

## 26. Roadmap por fases para elevar la fidelidad iOS del repo
1. **Fase 1 (Saneamiento Tipográfico y Dimensional):** Eliminar paddings, fonts y colores Material asfixiantes. Reforzar SafeAreas e introducir jerarquía de contraste iOS global en perfiles y home.
2. **Fase 2 (Homogeneidad de Interacción):** Estandarizar Modales, Alertas y Dropdowns hacia `CupertinoContextMenu`/`ActionSheets`/`Dialogs`, desplazando selectores Materiales y ripples estridentes.
3. **Fase 3 (Flujos de Animación Complex):** Reescribir las listas asimilando "bouncing", agrupados de estilo settings en familia/perfiles y "LargeTitles" de navegación por Tabs.
4. **Fase 4 (Motion Perfection):** Blur adaptativo general de cabeceras, microinteracciones elásticas robustas, transiciones de Hero animations limpias y soporte para *Dynamic Type / Theme Switching oscuro* infalible.

## 27. Ejemplo de auditoría aplicada a una pantalla del proyecto
**Evaluación Asistente sobre `perfil_screen.dart`**
*"Al revisar `/features/perfil/screens/perfil_screen.dart`, noto 3 violaciones higiénicas contra HIG iOS:
1. Material Density: Utilizas listas genéricas asfixiando el contenido.
2. Falsa Profundidad: Sombras negras gruesas en un entorno nativo ensucian.
3. Tap Targets Pobres en Editar Datos.
Procedo a inyectar un `CupertinoListSection.insetGrouped` con iconos predefinidos de sistema, aligerando el background a un gris sutil y ampliando hits a 44px."*

## 28. Ejemplo de respuesta ideal del skill ante una solicitud de mejora visual
**Usuario:** *"Mejora la visual del botón para sacar PDF en confirmación de reserva y dalo vuelta iOS".*
**Asistente:** *"Estando en `v0.03` de tu booking feature. El botón actual tiene un ripple violento rojo sobre la pantalla verde. 
Voy a extraer ese CTA al fondo del SafeArea.
Lo diseñaré como `CupertinoButton.filled`, eliminando la caja perimetral gris. Cambiaré la animación por una opacidad sutil inyectada en el onTap garantizando que respete el async del `pdf_service.dart` atado a `BookingState`. Adjunto código del widget:"*

## 29. Señales de alarma
- Multiplicidad incontrolada de `Scaffold` sobrepuestos (Material-Material-Cupertino) bloqueando físicas.
- Sombras excesivas `BoxShadow` con `blurRadius` superior a 15 y opacidades negras superiores a `0.2`.
- Textos cortados y desbordamientos infernales visualmente mostrados (A-B testing de UI quebrada amarilla en debug).
- Rutas colapsando la barra inferior (`tab_shell`) sin un `rootNavigator: true` estipulado, dejando a los usuarios encerrados en vistas oscuras y callejones sin salida sin SwipeBack.

## 30. Primeras 10 acciones recomendadas
1. **Reemplazo de Scaffold Principal:** Transicionar las pestañas root visuales del Home a `CupertinoPageScaffold`.
2. **Sliver Integration:** Instaurar en home y listas base el `CupertinoSliverNavigationBar` para el título elástico masivo iOS y blur del background transitorio.
3. **Limpieza de Diálogos:** Erradicar todo `AlertDialog` genérico por `CupertinoAlertDialog` en las advertencias CRUD o vaciados del tab `Familia`.
4. **Sanidad de Sombras (Shadows):** Purgar los contenedores Material sueltos desbordantes de sombra y opacidades oscuras, usando bordes o contornos finos en el listado de Doctores.
5. **Cero Ripples Subrepticios:** Transformar InkWells que chocan en UI densas por manejadores de toques opacos finos nativos `GestureDetector (opaque)`.
6. **Manejo Seguro del Loading:** Abstraer *CircularProgressIndicators* duros Material en overlays con opacidad usando `CupertinoActivityIndicator` nativo iOS para validaciones de login o auth token.
7. **Organización del Setting View:** Refactorizar el tab `Perfil` empleando `CupertinoListSection` agrupadas nativas (iOS Setting style) y erradicando tarjetas dispersas.
8. **Expansión de Tap Targets:** Purgar padding cero o botones menores a 44x44 en cruces de salidas/retrocesos.
9. **Eliminación Uncanny Button:** Quitar los *ElevatedButtons* rígidos con esquinas de 4px por botones llenos redondeados (ej. `borderRadius = 10` a `14` pletóricos)
10. **Sanitización Tipográfica Títular:** Normalizar variables de espaciado en la fuente asumiendo fuentes nativas del equipo `Theme.of().textTheme...` priorizando pesos definidos en las Guidelines de san francisco.

---

### Cómo debe actuar el agente en `v0.03`
- **Inspección Profunda Pragmática:** El agente NUNCA tira código en el aire ni alucina rutas genéricas. Si el usuario pide "Mejorar la lista", el agente corre silenciosamente una búsqueda o lectura hacia el recurso en `v0.03` (ej. `.agents/` o `/features/` o `/shell/`).
- **Priorizar Código Vivo:** Si el UI hoy funciona consumiendo variables Mocks hardcodeadas temporalmente, el agente las amarra y respeta la vitalidad.
- **Riesgos Suavizados:** No va a desmantelar una pantalla perdiendo la compatibilidad actual por cumplir la norma 100% teórica HIG. Entrega el snippet escalado de tal forma que al introducirlo no arruine los tabs.
- **Proponer Gradualidad Nativa:** Si observa un formulario denso estilo web en la reserva de turnos, el agente orienta el ticket aislando el componente material para encapsularlo en el envoltorio Cupertino limpio en el siguiente bloque, recomendando por fases.
