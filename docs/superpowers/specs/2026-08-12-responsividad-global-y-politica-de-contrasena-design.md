# Responsividad global verificable + política de contraseña unificada

**Fecha:** 2026-08-12
**Alcance:** regla de navegación (móvil/tablet/web), arnés de auditoría de
layout, arreglos derivados, y validación de contraseña compartida.

## Problema

Dos pedidos que en el código resultaron estar relacionados: ambos son casos de
**la misma regla escrita dos veces en dos lugares que no coinciden**.

### 1. "Todo tiene que ser adaptativo"

La medición sobre el código descartó la hipótesis obvia. El sistema responsive
(`core/extensions/responsive_extensions.dart`, 561 líneas: `AppResponsive` +
`ResponsiveTypography`) es maduro y **las 48 pantallas ya lo usan**. El problema
no es que falte el sistema, es que hay fugas alrededor:

| Hallazgo | Evidencia |
|---|---|
| La navbar lateral aparece en tablets nativas | `tab_shell.dart:1732` — `useSideNav = r.isDesktop \|\| (r.isTablet && r.isLandscape)`, sin `kIsWeb` |
| Esa misma regla está duplicada | `responsive_extensions.dart:163` la reimplementa para `navBarBottomSpace`; si una cambia, la otra tapa el contenido |
| 17 widgets compartidos fuera del sistema | `carnet_card` (600 l.), `tutorial_instructor` (744 l.), `active_appointment_modal`, `familia_help_dialog`, `side_nav_bar`, `coming_soon_dialog`, `liquid_glass`, `guided_tap_hint`, … |
| 9 pantallas sin ningún widget de scroll | `splash`, `account_unlock`, `local_auth`, `pin_setup`, `pin_verify`, `save_account`, `booking_flow`, `carnet_salud`, `carnet_validador` |
| ~120 `fontSize:` literales | 23 en `perfil_screen`, 16 en `carnet_salud_screen`, 15 en `carnet_card`, 13 en `active_appointment_modal`, … |
| No hay red de pruebas de layout | `test/responsive_layout_test.dart` cubre **solo** `LoginScreen`, en 2 tamaños |

La última fila es la causa raíz de por qué el problema reaparece: nada impide
que una pantalla nueva desborde. Sin medición, "mejorar la responsividad" es un
juicio estético infinito y no verificable.

### 2. "No deja cambiar la contraseña aunque sea fuerte"

`perfil_screen.dart:1992`:

```dart
final isValid = pwd.length >= 6 &&
    RegExp(r'[A-Z]').hasMatch(pwd) &&
    RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pwd);
```

Ese conjunto de caracteres especiales **omite `- _ + = / \ ; ' [ ] ~ \``**. Una
contraseña como `Militar-2026` (12 caracteres, mayúscula, minúsculas, dígitos,
guion) se rechaza como "Contraseña débil" y el usuario no tiene forma de saber
cuál de las tres reglas falló: el mensaje las enumera todas en un alert modal
que aparece **después** de pulsar Guardar.

Problemas secundarios en el mismo bloque:

| Problema | Efecto |
|---|---|
| Dos validadores que no coinciden | Perfil exige mayúscula + especial (`perfil_screen.dart:1992`); primer ingreso solo exige 6 caracteres (`password_change_screen.dart:74`) |
| `.trim()` sobre la contraseña | `perfil_screen.dart:1987` altera en silencio lo que se guarda respecto de lo que el usuario tecleó |
| Error del backend enterrado | `perfil_screen.dart:2044` imprime `'No se pudo cambiar la contraseña: $e'` con el `Exception:` crudo |
| `CupertinoAlertDialog` como host | Ancho fijo y angosto; no entra una lista de requisitos ni una barra de seguridad |

## Diseño

### Parte A — Regla de navegación con una sola fuente de verdad

Se añade a `AppResponsive`:

```dart
/// Única fuente de verdad para la navegación lateral.
/// Solo la web con ventana ancha usa el SideNavBar; en nativo (Android/iOS),
/// sea teléfono o tablet, vertical u horizontal, la barra va siempre abajo.
bool get useSideNav => kIsWeb && screenWidth >= kSideNavMinWidth; // 900
```

`tab_shell.dart:1732` y `navBarBottomSpace` pasan a **consumir** esa propiedad en
vez de reimplementarla.

| Contexto | Navegación | ¿Cambia? |
|---|---|---|
| Android/iOS teléfono | Abajo | no |
| Android/iOS tablet vertical | Abajo | no |
| Android/iOS tablet horizontal | Abajo | **sí** (hoy: lateral) |
| Web < 900 px (teléfono o ventana partida) | Abajo | no |
| Web ≥ 900 px | Lateral | no |

El umbral de 900 px (y no los 600 px de `isTablet`) es deliberado: deja que una
ventana de navegador a media pantalla (500–800 px) conserve el aspecto móvil
completo en vez de caer en un híbrido que no es ni una cosa ni la otra.

`kSideNavMinWidth` se declara como constante nombrada junto a los breakpoints,
no como literal suelto.

### Parte B — Arnés de auditoría (se construye ANTES de arreglar nada)

`test/responsive_audit_test.dart` monta cada pantalla en una matriz de
viewports y falla ante cualquier excepción de layout. Flutter reporta
`RenderFlex overflowed` como excepción capturable vía
`tester.takeException()`, así que el criterio es objetivo, no estético.

Viewports:

| Nombre | Tamaño | Representa |
|---|---|---|
| `phoneSmall` | 320 × 568 | iPhone SE / Android gama baja |
| `phoneMedium` | 375 × 812 | iPhone 13 mini |
| `phoneLarge` | 430 × 932 | iPhone Pro Max |
| `tabletPortrait` | 768 × 1024 | SM-T735 vertical |
| `tabletLandscape` | 1024 × 768 | SM-T735 horizontal |
| `desktop` | 1440 × 900 | web nginx:8080 |

Cada viewport se ejercita en dos condiciones: normal, y **con teclado**
(`MediaQuery.viewInsets.bottom = 336`), que es lo que revienta las 9 pantallas
sin scroll. Las pantallas sin campos de texto omiten la segunda condición.

Restricciones ya conocidas del repo que el arnés debe respetar:

- **Nada de `pumpAndSettle`.** Varias pantallas tienen animaciones en bucle
  (`_floatCtrl.repeat` en login, la instructora del tutorial) y `pumpAndSettle`
  nunca asienta: se cuelga. Se usan `pump()` acotados, como ya documenta
  `responsive_layout_test.dart:31-34`.
- **Binding + secure storage.** `TestWidgetsFlutterBinding.ensureInitialized()`
  más el mock de `flutter_secure_storage`, patrón ya registrado en memoria.
- **Sonido apagado** (`SoundManager.soundEnabledNotifier.value = false`) para no
  dejar timers de `audioplayers` pendientes en el teardown.
- Las pantallas que exigen sesión reciben un `UserSession` sembrado con datos de
  prueba; las que exigen datos de red usan `AppSessionCache` precargada.

**Cobertura.** Las 48 pantallas de `lib/features/**/screens/` más los widgets
compartidos que se montan a pantalla completa (modales y diálogos de
`core/widgets/` y `shell/widgets/`). Cada una se registra en una tabla del test
con su constructor y el sembrado que necesita, de forma que agregar una pantalla
nueva sea una línea.

Una pantalla que resulte imposible de montar en test (dependencia de plugin
nativo sin mock viable) se anota **explícitamente en la tabla como excluida, con
el motivo**, y se verifica a mano. Lo que no se admite es que quede fuera en
silencio: la lista de exclusiones es parte del entregable.

Sembrar datos de prueba para 48 pantallas es la parte más costosa del arnés y
donde puede aparecer trabajo imprevisto; si alguna resulta desproporcionada, se
excluye con motivo antes que bloquear el resto.

El arnés se escribe con las pantallas **en su estado actual roto**, de modo que
su primera ejecución produzca la lista de defectos reales. Esa lista es el
insumo de la Parte C. Un arnés que pasa a la primera no habría medido nada.

### Parte C — Arreglos, en orden de gravedad

1. **Scroll y teclado** en las 9 pantallas sin scroll. Envolver en un scroll que
   respete `viewInsets`, no añadir padding fijo.
2. **Los 17 widgets compartidos** pasan a `context.r` / `context.texts`.
3. **Los ~120 `fontSize:` literales** → tokens de `ResponsiveTypography`.
4. **`Row`/`Text` sin `Flexible`**, que recortan nombres largos de médicos y
   especialidades.

Criterio: **no se cambia el diseño visual**. El objetivo es que nada desborde ni
se recorte, no rediseñar. Un cambio que altere la apariencia en el viewport de
teléfono medio (donde hoy se ve bien) está fuera de alcance.

Cada arreglo se verifica contra el arnés. El arnés queda en el repo.

### Parte D — `PasswordPolicy` compartida

Nuevo `lib/core/utils/password_policy.dart`, consumido por **ambas** pantallas,
eliminando los dos validadores divergentes.

**Requisitos (todos bloqueantes, todos tildados en vivo):**

| Regla | Comprobación |
|---|---|
| Al menos 6 caracteres | `length >= 6` |
| Una mayúscula | `[A-ZÁÉÍÓÚÑ]` |
| Una minúscula | `[a-záéíóúñ]` |
| Un número | `[0-9]` |
| Un carácter especial | `[^A-Za-z0-9]` — cualquier no alfanumérico |
| Las contraseñas coinciden | solo en el formulario de cambio |

El mínimo se mantiene en **6** (no 8) por pedido explícito. La longitud extra no
bloquea pero sí alimenta la barra de seguridad. El set de especiales pasa a ser
"cualquier carácter no alfanumérico", lo que corrige el rechazo de `-` y `_`.

Las clases de caracteres incluyen acentos y `ñ`: el teclado en español los pone
a un toque de distancia y hoy `Contraseña1` no cuenta la `ñ` como nada.

**Barra de seguridad** — cuatro niveles, derivados de reglas cumplidas más
longitud:

| Nivel | Condición | Color |
|---|---|---|
| Muy débil | < 3 reglas | `AppColors.error` |
| Débil | 3–4 reglas | naranja |
| Buena | todas las reglas, < 12 caracteres | ámbar |
| Fuerte | todas las reglas, ≥ 12 caracteres | `AppColors.success` |

La barra es informativa; el botón se habilita con "todas las reglas cumplidas",
que corresponde a "Buena" o superior.

**Presentación.** El `CupertinoAlertDialog` se reemplaza por un bottom sheet
(`showAppDialog` sigue siendo el helper, conforme a la memoria del proyecto):
la lista de requisitos y la barra no entran en el ancho fijo de un alert. El
botón "Cambiar contraseña" está deshabilitado hasta que todas las reglas se
cumplan, de modo que **el rechazo deja de ser una sorpresa post-envío**: el
usuario ve en todo momento qué falta.

Cada requisito se tilda en verde en el momento en que se cumple, mientras
escribe. La transición del tilde usa los tokens de `AppDurations`/`AppCurves` y
respeta reduce-motion.

**Correcciones asociadas:**

- Se quita el `.trim()`, que altera en silencio la contraseña guardada.
- El fallo de `changePassword` muestra el mensaje real del servidor vía
  `ErrorMapper` (que `password_change_screen.dart:125` ya usa y el diálogo de
  Perfil no), en lugar del `Exception:` crudo.

**Riesgo señalado:** si el backend rechaza ciertos caracteres especiales, el
usuario podría cumplir las 5 reglas locales y aun así fallar en el servidor. Por
eso el mensaje real del backend deja de estar enterrado. No se restringe el set
localmente a ciegas: eso reintroduciría exactamente el bug que se está
arreglando.

## Pruebas

| Parte | Verificación |
|---|---|
| A | Tests de `useSideNav` en la matriz nativo/web × teléfono/tablet × orientación; y que `navBarBottomSpace` sea > 0 exactamente cuando la barra va abajo |
| B | El arnés es la prueba |
| C | El arnés pasa en 6 viewports × 2 condiciones de teclado |
| D | Tests unitarios de `PasswordPolicy` — incluido `Militar-2026`, el caso que hoy falla — y test de widget de que el botón se habilita solo con todo cumplido |

`PasswordPolicy` es lógica pura sin dependencias de Flutter, así que se
desarrolla con TDD: los casos de la tabla de requisitos se escriben como tests
antes que la implementación.

## Fuera de alcance

- Rediseño visual de ninguna pantalla.
- Desbloquear la orientación horizontal en móvil (`main.dart:54` sigue fijando
  `portraitUp`); tablet horizontal ya funciona porque el bloqueo no aplica ahí.
- Cambiar reglas de contraseña en el backend.
- Refactorizar `perfil_screen.dart` (2062 líneas) más allá de extraer el
  diálogo de contraseña.
