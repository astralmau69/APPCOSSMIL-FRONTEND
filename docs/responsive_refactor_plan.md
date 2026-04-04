# Refactorización Profunda de UI Responsiva — COSSMIL App

## Contexto

La app COSSMIL ya cuenta con una infraestructura responsive sólida (`ResponsiveExtension`, `ResponsiveData`, `AppResponsive`, `ResponsiveBody`) pero **no se usa de forma consistente**. La mayoría de pantallas utilizan constantes `EdgeInsets`, tamaños fijos y `MediaQuery` directo en lugar de los tokens del sistema. Esto genera:

- Overflows en teléfonos pequeños (≤ 360px)
- Espaciado inconsistente entre pantallas
- Componentes que no escalan (teclados PIN, avatares, cards)
- `BreadcrumbChips` que desbordan en anchos reducidos
- Hardcoded `padding: 20`, `82px` keys, `80px` avatares que no se adaptan

> [!IMPORTANT]
> **Bug existente:** `home_screen.dart` tiene errores de compilación (`responsive` undefined en líneas 393-409, debería ser `r`). Se corregirá como primer paso.

## User Review Required

> [!WARNING]
> **Orientación landscape:** `main.dart` fuerza `portraitUp` only. El plan NO habilita landscape ya que podría romper flujos de seguridad (TabShell bloqueo). ¿Quieres que también soporte landscape?

> [!IMPORTANT]
> **Agresividad del refactor:** El plan reemplaza **todas** las constantes hardcoded por tokens `context.r`. Esto cambia muchos archivos pero NO altera lógica de negocio, navegación ni estado. ¿Estás de acuerdo con esta amplitud?

---

## Proposed Changes

### Fase 0: Fix de bugs pre-existentes

#### [MODIFY] [home_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/home/screens/home_screen.dart)
- **Línea 393:** Cambiar `responsive.isSmallPhone` → `r.isSmallPhone`
- **Líneas 399-409:** Cambiar todas las refs a `responsive` → `r`
- Esto corrige los 5 errores de compilación actuales

---

### Fase 1: Refuerzo del Design System Responsive

#### [MODIFY] [responsive_extensions.dart](file:///d:/Cossmil/AFTEREXPO/lib/core/extensions/responsive_extensions.dart)
Agregar tokens faltantes que detecté que se necesitan:

| Token nuevo | Small (≤360) | Medium (≤414) | Large (>414) | Tablet (>600) |
|---|---|---|---|---|
| `avatarSm` | 44 | 50 | 56 | 60 |
| `avatarMd` | 56 | 64 | 72 | 80 |
| `avatarLg` | 72 | 84 | 96 | 120 |
| `pinKeySize` | 64 | 72 | 78 | 82 |
| `iconSm` | 14 | 16 | 18 | 20 |
| `iconMd` | 20 | 22 | 24 | 28 |
| `chipPaddingH` | 6 | 8 | 10 | 12 |
| `chipPaddingV` | 3 | 4 | 4 | 5 |
| `cardPadding` | 12 | 14 | 16 | 20 |
| `bookingStepperLogo` | 32 | 40 | 48 | 56 |
| `bookingStepSize` | 26 | 30 | 34 | 38 |
| `bookingStepSizeCurrent` | 30 | 34 | 36 | 40 |

---

### Fase 2: Refactorización de Componentes Compartidos (core/widgets)

#### [MODIFY] [booking_stepper.dart](file:///d:/Cossmil/AFTEREXPO/lib/core/widgets/booking_stepper.dart)
- Inyectar `context.r` para:
  - Logo size: `r.bookingStepperLogo` (en vez de `48` hardcoded)
  - Step circles: `r.bookingStepSize` / `r.bookingStepSizeCurrent` (en vez de `30`/`36`)
  - Padding: `r.paddingH` (en vez de `12` hardcoded)
  - Font sizes del label: proporcionados por `r.isSmallPhone ? 9 : 10.5`

#### [MODIFY] [breadcrumb_chips.dart](file:///d:/Cossmil/AFTEREXPO/lib/core/widgets/breadcrumb_chips.dart)
- Reemplazar `fontSize: 16` → escala con `r.isSmallPhone ? 13 : 15`
- Reemplazar `padding: 18,10` → `r.chipPaddingH, r.chipPaddingV` escalados
- Hacer scroll horizontal con `SingleChildScrollView` + `Row` para evitar overflow

#### [MODIFY] [appointment_card.dart](file:///d:/Cossmil/AFTEREXPO/lib/core/widgets/appointment_card.dart)
- Ya usa `responsive.isSmallPhone` ✅ — solo ajustar padding exterior con `r.paddingH`

#### [MODIFY] [beneficiary_selector_modal.dart](file:///d:/Cossmil/AFTEREXPO/lib/core/widgets/beneficiary_selector_modal.dart)
- Avatar: `56` → `r.avatarSm`
- Padding horizontal `24` → `r.paddingH`
- Font sizes: escalados con `r`

#### [MODIFY] [skeleton_loading.dart](file:///d:/Cossmil/AFTEREXPO/lib/core/widgets/skeleton_loading.dart)
- Ajustar márgenes hardcoded a tokens `r.paddingH`

---

### Fase 3: Refactorización de Pantallas (features)

#### [MODIFY] [login_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/auth/screens/login_screen.dart)
- Logo size ya tiene lógica responsive ✅ 
- Padding del form: usar `r.paddingH` en vez de hardcoded
- Verificar que botones no desborden en 320px

#### [MODIFY] [local_auth_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/auth/screens/local_auth_screen.dart)
- **Avatar:** `80` → `r.avatarMd`
- **Teclado PIN:** `width/height: 82` → `r.pinKeySize` (×6 ocurrencias)
- **Padding teclado:** `40` → `r.isSmallPhone ? 24 : 40`
- **Indicadores PIN:** `margin: 12` → `r.isSmallPhone ? 8 : 12`

#### [MODIFY] [pin_setup_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/auth/screens/pin_setup_screen.dart)
- Mismos cambios de teclado PIN que `local_auth_screen`
- **Keys:** `82` → `r.pinKeySize`
- **Padding:** `40` → dinámico
- **Icon size del header:** `64` → `r.isSmallPhone ? 48 : 64`

#### [MODIFY] [regional_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/booking/screens/regional_screen.dart)
- **Profile card avatar:** `80` → `r.avatarMd`
- **Card margins:** `20` → `r.paddingH`
- **Card padding:** `16` → `r.cardPadding`
- **Hospital card icon:** `56` → `r.avatarSm`
- **Font sizes:** escalar con responsive tokens

#### [MODIFY] [specialty_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/booking/screens/specialty_screen.dart)
- **Margins:** `20` → `r.paddingH`
- **Specialty icon:** `52` → `r.avatarSm`
- **Tile padding:** `16` → `r.cardPadding`

#### [MODIFY] [schedule_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/booking/screens/schedule_screen.dart)
- **Margins:** `20` → `r.paddingH`
- **Doctor card avatar:** `52` → `r.avatarSm`
- **Time chip width:** `108` → `r.isSmallPhone ? 90 : 108`
- **Calendar icon container:** `40` → `r.isSmallPhone ? 34 : 40`

#### [MODIFY] [summary_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/booking/screens/summary_screen.dart)
- **Padding:** `20` → `r.paddingH`
- **Photo containers:** `48` → `r.avatarSm - 4`
- **Button border radius:** OK ✅

#### [MODIFY] [reservas_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/reservas/screens/reservas_screen.dart)
- Ya usa `context.r` parcialmente ✅
- **Filter bar:** verificar que chips no desborden en 320px (ya usa horizontal scroll)
- **Summary bar padding:** `14,12` → `r.cardPadding`

#### [MODIFY] [detalle_cita_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/reservas/screens/detalle_cita_screen.dart)
- **Padding:** `20` → `r.paddingH`
- **Doctor avatar:** `52` → `r.avatarSm`
- **Section card padding:** `16` → `r.cardPadding`

#### [MODIFY] [familia_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/familia/screens/familia_screen.dart)
- **Padding:** `20` → `r.paddingH`
- **Avatar:** `60` → `r.avatarSm`
- **Card padding:** `18` → `r.cardPadding`
- **Bottom padding:** `120` → `r.navBarBottomSpace`

#### [MODIFY] [perfil_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/perfil/screens/perfil_screen.dart)
- **Premium avatar:** `120` → `r.avatarLg`
- **Padding:** `20` → `r.paddingH`
- **Info grid padding:** `14,11` → `r.cardPadding`
- **Bottom padding:** `120` → `r.navBarBottomSpace`

#### [MODIFY] [security_setup_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/perfil/screens/security_setup_screen.dart)
- **Status icon:** `88` → `r.avatarLg`
- **Security card icon:** `46` → `r.avatarSm - 4`
- **Padding:** `20` → `r.paddingH`

#### [MODIFY] [home_screen.dart](file:///d:/Cossmil/AFTEREXPO/lib/features/home/screens/home_screen.dart)
- **Fix bug:** `responsive` → `r` (5 lugares)
- **Quick action cards:** verificar que ya use `r` correctamente
- **News section padding:** estandarizar con `r.paddingH`

---

### Fase 4: Refactorización del Shell

#### [MODIFY] [floating_nav_bar.dart](file:///d:/Cossmil/AFTEREXPO/lib/shell/widgets/floating_nav_bar.dart)
- Reemplazar cálculos propios de `barHeight` por tokens `r`
- Escalar `iconSize`, `fontSize`, y `dotSize` con responsive tokens
- Mantener la lógica de `bottomPadding` nativa para safe area

#### [MODIFY] [tab_shell.dart](file:///d:/Cossmil/AFTEREXPO/lib/shell/tab_shell.dart)
- Solo verificar coherencia, no cambiar navegación ni estado
- `navBarBottomSpace` ya existe en responsive system ✅

---

## Alcance Excluido

| Item | Razón |
|---|---|
| Soporte landscape | `main.dart` fuerza portrait; cambiar requeriría revalidar layout de TabShell |
| Dark mode issues | Fuera del scope — es tema de colores, no de responsive |
| Lógica de negocio | Cero cambios en services, models, state management |
| Nuevos widgets | Solo refactorizar los existentes, no crear wrappers nuevos innecesarios |
| Animaciones | No se tocan las animaciones excepto durations si se detectan jank |

---

## Open Questions

> [!IMPORTANT]
> 1. **¿Confirmas que quieres que ejecute todo el plan?** Son ~20 archivos pero cada cambio es quirúrgico (reemplazo de constantes por tokens).
> 2. **¿Quieres que habilite landscape?** Actualmente está bloqueado en `main.dart`.
> 3. **¿Hay alguna pantalla que NO deba tocar?** (ej: si hay pantallas en desarrollo activo)

---

## Verification Plan

### Automated Tests
```bash
# 1. Verificar compilación sin errores
flutter analyze --no-fatal-infos --no-fatal-warnings

# 2. Verificar que la app compila
flutter build apk --debug
```

### Manual Verification
- Test en emulador **320px width** (teléfono pequeño extremo)
- Test en emulador **414px width** (iPhone 14 / reference phone)
- Test en emulador **600px+ width** (tablet mode)
- Verificar que el flujo completo de booking funcione sin overflows
- Verificar que teclado PIN sea usable en pantallas pequeñas
- Verificar que BreadcrumbChips no se corten
