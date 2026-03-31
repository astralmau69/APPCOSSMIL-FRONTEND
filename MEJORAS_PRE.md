# MEJORAS PRE — Roadmap hacia App Bancaria Profesional

Analisis comparativo con apps como Yape, BancoSol, BCP.
Fecha de analisis: 2026-03-31

---

## Lo que YA esta bien

- Arquitectura modular por features
- Dark/Light mode con ThemeManager
- Seguridad PIN + biometria (cooldown, inactividad, grace window)
- Animaciones de entrada (FadeSlideIn, OptimizedPressButton)
- Responsive breakpoints (phone small/medium/large, tablet)
- Design tokens (AppSpacing, AppTypography, AppColors, AppShadows, AppDurations)
- Floating nav bar con glassmorphism
- Mock data mode para desarrollo offline
- PDF de confirmacion de cita
- Notificaciones locales programadas (3 niveles de recordatorio)
- Skeleton loading en noticias (HomeScreen)
- Bordes consistentes en light/dark en todas las pantallas

---

## Mejoras por implementar

### 1. SKELETON LOADING EN TODAS LAS PANTALLAS
**Prioridad:** Alta
**Impacto:** Percepcion de velocidad profesional

Solo HomeScreen tiene skeleton para noticias. Falta en:
- **ReservasScreen** — skeleton de cards de citas (3-4 placeholders)
- **FamiliaScreen** — skeleton de cards de beneficiarios
- **RegionalScreen** — skeleton de lista de hospitales/departamentos
- **PerfilScreen** — skeleton del header + info grid
- **DetalleCitaScreen** — skeleton del contenido completo
- **SpecialtyScreen** — skeleton de lista de especialidades
- **ScheduleScreen** — skeleton de doctor + slots de horario

**Referencia:** `_NewsCardSkeleton` en `home_screen.dart` (patron existente a replicar)

---

### 2. PULL-TO-REFRESH EN TODAS LAS LISTAS
**Prioridad:** Alta
**Impacto:** UX basica esperada en cualquier app moderna

Solo RegionalScreen tiene `RefreshIndicator`. Agregar en:
- **HomeScreen** — refrescar noticias + datos del usuario
- **ReservasScreen** — refrescar historial de citas (usar `CupertinoSliverRefreshControl`)
- **FamiliaScreen** — refrescar lista de beneficiarios
- **NoticiasScreen** — ya tiene refresh control, verificar que funcione

---

### 3. ANIMACION DE EXITO AL CONFIRMAR CITA
**Prioridad:** Alta
**Impacto:** Satisfaccion del usuario, sensacion premium

Actualmente: icono verde estatico + texto. Mejorar con:
- Animacion de checkmark animado (circular draw + scale bounce)
- Confetti o particulas sutiles
- Sonido de exito corto (opcional)
- Transicion celebratoria antes de mostrar botones de PDF/Volver

**Ubicacion:** `SummaryScreen._buildPostConfirmButtons()` y `_confirmBooking()`

---

### 4. STEPPER VISUAL EN FLUJO DE BOOKING
**Prioridad:** Alta
**Impacto:** Orientacion del usuario en proceso multi-paso

El flujo de 4 pasos no tiene indicador de progreso:
```
[1] Regional  ──  [2] Especialidad  ──  [3] Horario  ──  [4] Confirmar
```
- Barra horizontal con 4 pasos, paso actual resaltado
- Numeros + iconos por paso
- Linea conectora con progreso animado
- Colocar debajo del CupertinoNavigationBar en cada pantalla del flujo

**Pantallas afectadas:** `RegionalScreen`, `SpecialtyScreen`, `ScheduleScreen`, `SummaryScreen`

---

### 5. REDUCIR SPLASH / BIOMETRICO DIRECTO
**Prioridad:** Alta
**Impacto:** Uso diario mas rapido (el usuario abre la app varias veces al dia)

Actualmente: splash de 4 segundos siempre. En apps bancarias:
- Si biometria habilitada → ir directo al lector de huella (sin splash o splash de 1s max)
- Si solo PIN → ir directo a pantalla de PIN
- Splash completo (4s + audio) solo la primera vez o despues de logout

**Ubicacion:** `SplashScreen` + `main.dart` logica de inicializacion

---

### 6. FILTROS EN RESERVAS
**Prioridad:** Media
**Impacto:** Usabilidad cuando el historial crece

Agregar en ReservasScreen:
- **Filtro por estado:** chips horizontales (Todos / Pendiente / Completado / Falta / Cancelado)
- **Filtro por fecha:** selector de rango de fechas
- Contador de resultados filtrados
- Animacion al cambiar filtro

---

### 7. HAPTIC FEEDBACK GLOBAL
**Prioridad:** Media
**Impacto:** Sensacion tactil premium

Agregar `HapticFeedback` en:
- `HapticFeedback.selectionClick()` — cambio de tab en FloatingNavBar
- `HapticFeedback.lightImpact()` — tap en botones principales (confirmar, reservar)
- `HapticFeedback.mediumImpact()` — confirmacion exitosa de cita
- `HapticFeedback.heavyImpact()` — error en PIN (ya existe shake, agregar haptic)
- `HapticFeedback.selectionClick()` — seleccion de slot de horario, hospital, especialidad

**Archivo clave:** `FloatingNavBar`, `SummaryScreen`, `LocalAuthScreen`, `PinSetupScreen`, `ScheduleScreen`

---

### 8. CANCELAR / REPROGRAMAR CITAS
**Prioridad:** Media
**Impacto:** Feature critica faltante

Funcionalidad necesaria:
- Boton "Cancelar cita" en `DetalleCitaScreen` (solo para estado Pendiente)
- Dialogo de confirmacion antes de cancelar
- Endpoint backend para cancelacion
- Opcional: flujo de reprogramacion (seleccionar nueva fecha/hora)
- Actualizar lista de reservas despues de cancelar

---

### 9. EMPTY STATES CON ILUSTRACIONES
**Prioridad:** Media
**Impacto:** Pulido visual, primera impresion

Reemplazar iconos grises + texto por:
- Ilustraciones SVG/PNG personalizadas por contexto
- Boton de accion contextual ("Reservar tu primera cita", "Agrega un familiar")
- Tono amigable y cercano
- Animacion sutil de entrada

**Pantallas:** ReservasScreen (vacio), FamiliaScreen (sin beneficiarios), NoticiasScreen (sin noticias)

---

### 10. BANNER DE CONEXION / MODO OFFLINE
**Prioridad:** Media
**Impacto:** Confianza del usuario, manejo de errores

Implementar:
- Widget global que escucha `Connectivity` plugin
- Banner animado top "Sin conexion a internet" (color warning)
- Auto-hide cuando vuelve la conexion
- Cache de ultimo estado para mostrar datos offline
- Retry automatico en reconexion

**Ubicacion sugerida:** Dentro de `TabShell` como overlay sobre el body

---

### 11. ONBOARDING PRIMERA VEZ
**Prioridad:** Baja
**Impacto:** Primera impresion para nuevos usuarios

Carousel de 3-4 slides:
1. "Bienvenido a COSSMIL" — logo + descripcion
2. "Reserva citas medicas" — ilustracion del flujo
3. "Seguridad" — PIN y biometria
4. "Notificaciones" — recordatorios automaticos

- Indicador de dots abajo
- Boton "Siguiente" / "Omitir" / "Empezar"
- Se muestra 1 sola vez (flag en `SharedPreferences`)
- Ruta: antes de `/login`, solo si `isFirstLaunch == true`

---

### 12. CENTRO DE NOTIFICACIONES
**Prioridad:** Baja
**Impacto:** Engagement, comunicacion con el usuario

- Icono de campana en el header del HomeScreen con badge de conteo
- Pantalla dedicada con lista de notificaciones
- Estados: leida / no leida
- Tipos: recordatorio de cita, cambio de horario, comunicado nuevo, sistema
- Persistencia local (Hive o SQLite)

---

### 13. TIMELINE VISUAL EN HISTORIAL
**Prioridad:** Baja
**Impacto:** Diferenciador visual vs apps genericas

En vez de lista plana de cards en ReservasScreen:
- Linea vertical conectora entre citas
- Agrupacion por periodo ("Hoy", "Esta semana", "Marzo 2026", "Febrero 2026")
- Punto/dot en la timeline por cada cita
- Animacion de entrada escalonada

---

### 14. FORCE UPDATE / VERSION CHECK
**Prioridad:** Baja
**Impacto:** Mantenibilidad a largo plazo

Al iniciar la app:
- Consultar endpoint de version minima
- Si version actual < minima → modal bloqueante con link a Play Store / App Store
- Si version actual < recomendada → banner dismissable "Nueva version disponible"

---

### 15. COMPARTIR / EXPORTAR
**Prioridad:** Baja
**Impacto:** Conveniencia del usuario

Agregar en DetalleCitaScreen y SummaryScreen:
- "Compartir PDF" via `Share.share()` (WhatsApp, email, etc.)
- "Agregar al calendario" del dispositivo (`device_calendar` plugin)
- "Copiar codigo de reserva" al clipboard con feedback visual (SnackBar/toast)

---

### 16. BUSQUEDA EN LISTAS
**Prioridad:** Baja
**Impacto:** Usabilidad con datos extensos

Agregar barra de busqueda en:
- **ContactosScreen** — filtrar por nombre/numero
- **SpecialtyScreen** — buscar especialidad por nombre
- **ReservasScreen** — buscar por especialidad/medico/codigo

---

### 17. MICROINTERACCIONES FALTANTES
**Prioridad:** Baja
**Impacto:** Pulido premium, atencion al detalle

- Counter animado en badges (cuando cambia el numero)
- Parallax sutil en header de perfil al hacer scroll
- Boton "scroll to top" en listas largas (aparece al bajar 500px+)
- Transicion de color suave cuando cambia estado de cita
- Ripple effect en cards al hacer tap (ya tienen scale, agregar ink)

---

### 18. ACCESIBILIDAD
**Prioridad:** Baja (pero importante para compliance)
**Impacto:** Inclusividad, posible requisito legal

- `Semantics` labels en iconos y botones sin texto
- Contrast ratio minimo 4.5:1 en todos los textos (verificar con tool)
- Tap targets minimo 44x44dp (revisar chips pequenos)
- Testing con TalkBack (Android) y VoiceOver (iOS)
- `ExcludeSemantics` en elementos decorativos

---

### 19. OLVIDE MI CONTRASENA
**Prioridad:** Baja
**Impacto:** Flujo critico que actualmente no funciona

El link existe en LoginScreen pero `onPressed` esta vacio:
- Pantalla de ingreso de matricula
- Envio de codigo al correo/celular registrado
- Pantalla de verificacion de codigo
- Pantalla de nueva contrasena
- Requiere endpoint backend

---

### 20. PREVIEW RAPIDO EN BOTTOM SHEET
**Prioridad:** Baja
**Impacto:** Navegacion mas rapida

En vez de navegar a DetalleCitaScreen siempre:
- Long press o swipe up en AppointmentCard → bottom sheet con resumen
- Opciones rapidas: "Ver detalle", "Descargar PDF", "Cancelar"
- Reduce navegaciones innecesarias

---

## Resumen de prioridades

| # | Mejora | Prioridad | Esfuerzo |
|---|--------|-----------|----------|
| 1 | Skeleton loading en todas las pantallas | Alta | Medio |
| 2 | Pull-to-refresh en listas | Alta | Bajo |
| 3 | Animacion de exito al confirmar | Alta | Medio |
| 4 | Stepper visual en booking | Alta | Medio |
| 5 | Reducir splash / biometrico directo | Alta | Bajo |
| 6 | Filtros en reservas | Media | Medio |
| 7 | Haptic feedback global | Media | Bajo |
| 8 | Cancelar/reprogramar citas | Media | Alto |
| 9 | Empty states con ilustraciones | Media | Medio |
| 10 | Banner de conexion | Media | Medio |
| 11 | Onboarding primera vez | Baja | Medio |
| 12 | Centro de notificaciones | Baja | Alto |
| 13 | Timeline visual | Baja | Medio |
| 14 | Force update check | Baja | Bajo |
| 15 | Compartir/exportar | Baja | Bajo |
| 16 | Busqueda en listas | Baja | Medio |
| 17 | Microinteracciones | Baja | Bajo |
| 18 | Accesibilidad | Baja | Medio |
| 19 | Olvide mi contrasena | Baja | Alto |
| 20 | Preview en bottom sheet | Baja | Medio |
