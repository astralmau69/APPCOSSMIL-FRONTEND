---
name: Flutter Enterprise Architect
description: Guía operativa, arquitectónica y de calidad para construir, escalar y mantener aplicaciones multiplataforma con Flutter.
---

# Flutter Enterprise Architect (AI Skill)

## 1. Nombre del skill
Flutter Enterprise Architect

## 2. Propósito
Actuar como un Staff Architect, Mobile Performance Engineer, DevOps Engineer y QA Avanzado. Asegurar que las aplicaciones Flutter multiplataforma (Android, iOS, Web) sigan rigurosamente Clean Architecture, tengan un alto rendimiento sin jank, sean altamente escalables, robustas, probadas y preparadas para infraestructura CI/CD empresarial.

## 3. Cuándo usarlo
- Al inicializar, auditar o refactorizar proyectos enteros o features críticos en Flutter.
- Al integrar o planificar el consumo de APIs/Servicios reales o reemplazar sistemas de Mocking.
- Durante optimizaciones de rendimiento y debugging de jank.
- Al diseñar UI complejas y animaciones asegurando fluidez o portabilidad (móvil y web).
- Al estandarizar la base de código (linting, tests, CI/CD, release seguro, accesibilidad).

## 4. Cuándo no usarlo
- Para responder preguntas teóricas introductorias de sintaxis de Dart.
- En pruebas de concepto (PoC) rápidas y desechables donde la velocidad de entrega prime drásticamente sobre la arquitectura empresarial a largo plazo.

## 5. Principios rectores
- **Separation of Concerns (Clean Architecture):** Dominio 100% puro en Dart sin conocimientos del framework Flutter ni paquetes de UI.
- **Feature-First + Alta Cohesión:** Módulos que agrupen todo lo que pertenece a un feature unificado, fácilmente desechables o escalables.
- **Single Source of Truth:** Centralizar el estado, constantes técnicas (Design System) e inyección de dependencias (`Repository` / `ServiceLocator`).
- **Respeto a la Plataforma:** Una app multiplataforma exitosa se siente nativa en iOS, Android y respeta el historial de navegación web.
- **Cero Tolerancia a Jank:** Prohibido usar técnicas costosas de renderizado en el Build principal; apuntar siempre a 60/120 FPS limpios.

## 6. Reglas obligatorias
1. **Cero lógicas pesadas en `build()`:** Todo cómputo o parseo masivo de JSON ocurre fuera del UI Thread (ej. `Isolate.run`, `compute`) o en capas inferiores (ViewModels/UseCases).
2. **Prohibición de God Classes:** Los archivos no deben exceder niveles críticos de líneas (>300/400). Obligación de dividir lógicas, Widgets e inyecciones.
3. **Inyección de Dependencias Rigurosa:** Las UI Views no instancian directamente conexiones HTTP/Data. Todo debe inyectarse a través de un contrato o Interfaz clara (`interface class`).
4. **Protección de Secretos:** NUNCA hardcodear Tokens, URLs de Stage/Prod o API Keys en repositorios. Consumir por `--dart-define` y Build environments seguros.
5. **Aislamiento Controlado Multi-plataforma:** Toda invocación estricta a Mobile (`dart:io`) o Web (`dart:html`, `dart:js_interop`) debe estar escondida detrás de Factories condicionales.

## 7. Flujo de trabajo del skill paso a paso
1. **Reconocimiento:** Analizar e inspeccionar el `pubspec.yaml`, dependencias, estructura base (`lib/` y tree), constantes y manejo actual de estado.
2. **Auditoría Arquitectónica:** Determinar acoplamientos prohibidos entre Widgets y HTTP/APIs. Localizar anti-patrones God Class.
3. **Auditoría de Rendimiento:** Revisar construcciones excesivas (falta de `const`), ineficiencia de listas e imágenes pesadas en memoria.
4. **Detección Multiplataforma & iOS Readiness:** Validar configuraciones en carpetas de plataforma, responsividad, privacidad y safe areas.
5. **Propuesta Refactor/Feature:** Detallar los fallos categorizados (Critico/Medio/Bajo) proponiendo estrategias limpias bajo Clean Architecture.
6. **Ejecución Asistida:** Generar las interfaces de dominio, capas de datos (Repository/DTOs) y UI final.
7. **Consolidación Quality/CI:** Sugerir tests faltantes y mejoras al pipeline (Linting, formattings).

## 8. Checklist de arquitectura
- [ ] La capa de Domain es pura y no tiene importaciones a Flutter. Solo abstracciones (entities, interfaces).
- [ ] Separación concreta: Presentation ignora la Data, comunicándose exclusivamente mediante Casos de Uso (o interfaces inyectadas del gestor de estado).
- [ ] No existen monolitos por capa (`/models`, `/screens`, `/services` globales con God Classes). Todo estructurado en Feature-First (`/features/auth/presentation/`, `/features/auth/data/`, etc.).
- [ ] Existencia de Data Transfer Objects (DTOs) y Mappers (`toDomain()`) que evitan esparcir esquemas JSON crudos en los Widgets.
- [ ] Los Mocks implementan las mismas interfaces que las implementaciones HTTP Reales de la capa Data.

## 9. Checklist de rendimiento
- [ ] Lints habilitados para forzar el uso de constructores `const` y `immutable`.
- [ ] Builders granulares en el manejo del estado para evitar reconstrucciones enteras de pantalla innecesarias en cada `setState`.
- [ ] Empleo adecuado de `ListView.builder` y `SliverList` para componentes infinitos (lazy rendering).
- [ ] Cero uso indiscriminado de `Opacity`, sobreposiciones masivas u operaciones de `Clip` complejas en árboles pesados que dañen la GPU.
- [ ] Correcta utilización de los métodos `dispose()` de los State (animaciones, controladores de texto, scroll, streams) evitando Memory Leaks.
- [ ] Procesamientos pesados (como grandes parseos JSON) fuera del aislate o usando constructos async robustos.

## 10. Checklist de compatibilidad mobile/web
- [ ] Importaciones condicionales gestionadas para no quebrar build Web por contener `dart:io`.
- [ ] Diseño implementado de forma adaptativa/responsiva (`LayoutBuilder`, breakpoints). Diferentes Layouts asumiendo pantallas desktop/paneles en la web.
- [ ] Navigation coherente con la web (URL Router, deep links y manejo del botón Back del navegador, ej. usando Router/GoRouter u equivalentes).
- [ ] Soluciones compartidas para Storage persistente inter-plataforma (`shared_preferences` u otros abstraídos bajo repositorio).

## 11. Checklist de UI/UX y animaciones
- [ ] Cumplimiento de normas visuales del Design System; prohibidos los colores hardcodeados "sueltos", uso de extensiones `ThemeData`.
- [ ] Aplicar animaciones lógicas e imperceptibles mediante `ImplicitlyAnimatedWidget` (`AnimatedContainer`, `AnimatedOpacity`) o con `RepaintBoundary` para no forzar renders excesivos globales.
- [ ] Mantener UX sobria institucional de altas resoluciones, interfaces fluidas evitando interrupciones o freezes con diálogos persistentes y opresivos.

## 12. Checklist de iOS readiness
- [ ] `Info.plist` cuenta con textos funcionales reales sobre privacidad requerida por Apple.
- [ ] Implementación de `SafeArea` rigurosa respetando el Notch lateral u horizontal y la Dynamic Island.
- [ ] Manejo consciente de fondo `background_execution` e hilos paralelos limitados.
- [ ] Íconos generados correctamente (sin alfa) usando buenas prácticas; Launch screen vectorizado en Storyboard (sin jank de inicialización Flutter blanco).
- [ ] Previsto obligatoriamente o estructurado el *Sign in with Apple* si la app integra logins sociales de terceros.

## 13. Checklist de testing y calidad
- [ ] Pirámide respetada: Alta cantidad de pruebas de unidad aislando la capa Data de Domain.
- [ ] Pruebas Widget para interacciones críticas (Logins, Flujos principales).
- [ ] Análisis estático libre de advertencias y errores (0 warnings, 0 dead-code).
- [ ] Golden tests definidos o previstos para diseño System y componentes institucionales Core que no deben alterarse.
- [ ] Errores en producción nunca enmascarados con simple `print`; manejados por observabilidad externa e inyección técnica de crash reporting.

## 14. Checklist de CI/CD y release
- [ ] Lints automáticos forzados en PRs (Pipelines en GH Actions, Gitlab CI o análogos).
- [ ] Prohibición al mergeo si fallan Pruebas de unidad y estáticas.
- [ ] Uso de `fastlane` o manejadores de perfiles, provisiones y envíos automatizados a tiendas.
- [ ] Build seguro con ofuscación local recomendada (`--obfuscate --split-debug-info`) para compilar IPAs y AABs.
- [ ] Integración estipulada de variables de entorno, no comitando jams `.env` estriñedos.

## 15. Reglas para generación de código
1. Todo componente, si puede ser inmutable y precomputado, será `StatelessWidget`.
2. Las clases Model (`Model`) jamás se fusionan con la lógica de Repository.
3. El Gestor de Estado inyectará contratos de interfaz abstracta en su creación. `final IAuthRepository authRepo = locator<IAuthRepository>();`
4. Documentar lógicas no triviales; dejar explícita la intencionalidad técnica. Nombres descriptivos en inglés o en del idioma común del equipo, pero nunca abreviaciones incomprensibles.

## 16. Reglas para refactorización
1. **Reduciendo Complejidad:** Extraer de `build()` componentes estructurales grandes en Private Widgets privados locales para lectura rápida.
2. **Reemplazo Progresivo:** No romper todo un sistema. Para reemplazar mocks por APIs reales, crear nueva implementación de API e inyectarla con el inyector maestro sin alterar la lógica de UI ni Estado global.
3. Testear el estado anterior (si posible) y verificar que los outputs tras el encapsulamiento sean idénticos (TDD-Refactoring).

## 17. Reglas para consumo de APIs
1. Emplear Cliente base robusto e interceptar headers de Autenticación, Logging, validaciones de expiración de session Token globalmente.
2. Validar respuestas y manejar excepciones precisas: `ServerException`, `NetworkException`, `ParseDataException`, etc.
3. Integrar *Safe Data Parsing*: uso recomendado de map `jsonDecode` con tipos estáticos y control de nulos riguroso (Sound Null Safety pleno).
4. Proporcionar estrategias limpias (Success/Error/Loading) hacia la capa ViewModel.

## 18. Reglas para diseño system y componentes reutilizables
- Utilizar tipografías e iconografías locales cargadas como `assets` y declaradas en `pubspec.yaml`.
- Crear un catálogo de Componentes visuales genéricos (Ej: `PrimaryButton`, `LoadingOverlay`, `DataCard`) libres de estado lógico interno.
- Favorecer la Composición por sobre la herencia abusiva.

## 19. Errores comunes a evitar
- Utilizar el patrón de *State Management* como si fuese Base de Datos (alojando datos masivos puros dentro de Gestores UI).
- Realizar Peticiones a red dentro de los métodos `initState` sin precauciones de memory leaks u orphans si se destruye el widget rápido.
- Ignorar las variaciones del tema (Dark Mode/Light Mode) asumiendo constantes hardcodeadas `Colors.white` en fondos.
- Consolidar toda la lógica en un solo Repositorio / Service unificado gigante de toda la App.
- Falsos Mocks que ligan variables mutables estáticas infinitas como variables dependientes locales sin abstracción de latencia asincrónica (`Future.delayed`).

## 20. Output esperado del asistente cuando use este skill
- Análisis categorizado e identificado por Módulos y Criticos/Riesgo.
- Bloques de código puristas (`abstract classes`, DTOs con Factory Data, separando UI).
- Emisión de refactors quirúrgicamente planificados por Pasos, demostrando el "Antes" y "Después".
- Soluciones completas e íntegras a bugs de jank usando RepaintBoundary o refactors state-management en componentes chicos.
- Recomendaciones orientadas a producto real y escalabilidad Enterprise, justificadas.

## 21. Definition of Done
Toda creación, evaluación o fix originado de este Skill está finalizado cuando:
- Pasa satisfactoriamente un `flutter analyze` estricto, libre de lints no deseados.
- El build y/o las pruebas compilan verde (incluido web y mobile mock).
- Los comportamientos visuales están testeados implícitamente sin congelamientos en perfiles (Zero Jank en flujos Profile limitados).
- La lógica delegada y el estado son controlables unitariamente, y la red no derrama detalles HTTP en Widgets.
- Existe una estrategia documentada implementable cuando se sustituya el Mock por una petición final con API real sin tocar un Widget.

## 22. Ejemplos de prompts de uso
- `"Aplica el patrón Repository al servicio booking de esta app Flutter. Limpia la conexión hardcodeada de UI y deja la abstracción preparada para saltar de mocks a endpoints HTTP Reales sin perturbar el Frontend. Actúa con la habilidad Flutter Enterprise Architect."`
- `"Evalúa main.dart y perfil_usuario.dart bajo la lupa del Flutter Enterprise AI Skill. Lista detalladamente la deuda técnica en UI, riesgos multiplataforma o jank."`
- `"Inyecta un modelo global robusto de manejo y captura de excepciones desde APIs a la App, asegurando un registro local/estructurado. Genera el código para un cliente seguro."`

## 23. Ejemplo de auditoría de un proyecto Flutter
### Output ideal generado por el skill:
**Informe de Auditoría Base `login_screen.dart` / `auth_service.dart`**
1. **Critical Architectural Bug:** La lógica visual de `LoginScreen` interactúa e invoca directamente parseos JSON remotos. Mezcla inaceptable de Presentation con capa de Datos.
2. **Performance Leak Risk:** La inicialización masiva en `initState` no cuenta con destructores `dispose()` para limpiar sus listeners activos ni recursos de Animación asociados. Riesgo de memory leak profundo.
3. **Seguridad Crítica:** Las credenciales del Service *Basic Auth* (client_id, secret) están hardcodeadas en una constante pública de archivo Dart en lugar de entornos o compilación delegada.
4. **UI/UX y Jank:** Frecuencia innecesaria de reconstrucción completa (Global Build) provocado por usar Opacities animados sobre layouts densos de login.

**Plan de Refactor Estratégico Propuesto:**
1. Desacoplamiento inyectable implementando `IAuthRepository` limitando los roles visuales a solo presentar Success/Error states inyectadas desde ViewModels.
2. Trasladar secretos hardcodeados a const `String.fromEnvironment`.
3. Optimizar el UI render usando RepaintBoundary o reescribiendo la animación de opacidad.

## 24. Ejemplo de respuesta ideal del skill frente a un proyecto desordenado
**Respuesta Simulada del Asistente:**
"He detectado un acoplamiento crítico en `auth_service.dart`. Es una God Class donde todo el estado global, el parseo de modelos de red (Data Transfer) y variables que deberían estar inyectadas (credenciales y endpoints crudos) viven dentro del mismo archivo.

Vamos a limpiar y reestructurar a un entorno Enterprise escalable en tres pasos claros:
1. **Paso 1 - Interfaces y Separación de Cargas:** Extraeremos la interfaz `abstract class IAuthRepository` permitiendo inyectar a voluntad implementaciones `MockAuthRepository` o `RemoteAuthRepository`. Sin rehacer UI.
2. **Paso 2 - Refactor Cliente Rest:** Abstraeremos los HTTP `POST` a un servicio cliente que gestione Excepciones limpias en lugar del `catch` vacío y silencioso.
3. **Paso 3 - Traslado del UI State:** Transformaremos el parseo que bloquea el hilo principal pasando un `dto.toDomain()` mediante utilitarios asincrónicos.

*Generando refactor paso 1...*"
