import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/animations/animated_gradient_background.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/data/initial_data_orchestrator.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/cossmil_loader.dart';

// ─── Estados internos ─────────────────────────────────────────────────────────

enum _LoadState { loading, error }

// ─── Pantalla ─────────────────────────────────────────────────────────────────

/// Pantalla de transición que precarga los datos de sesión en paralelo.
///
/// Flujo:
///   1. Se monta → dispara [InitialDataOrchestrator.loadAll].
///   2. Mientras carga → muestra [CossmilLoader] + etiquetas animadas.
///   3. Si tiene éxito  → navega automáticamente a `/home`.
///   4. Si falla        → muestra error + botón "Reintentar conexión".
class LoadingDataScreen extends StatefulWidget {
  const LoadingDataScreen({super.key});

  @override
  State<LoadingDataScreen> createState() => _LoadingDataScreenState();
}

class _LoadingDataScreenState extends State<LoadingDataScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;

  // ── FIX BUG 1 + BUG 2: Generation counter ────────────────────────────────
  // Cada llamada a _startLoading incrementa este contador.
  // _cycleLabels y la navegación final comprueban que su generación
  // sigue siendo la activa antes de actuar — esto cancela coroutines "zombie"
  // del intento anterior y previene la doble navegación por doble tap.
  int _generation = 0;

  static const _steps = [
    'Verificando grupo familiar…',
    'Cargando información del hospital…',
    'Obteniendo directorio médico…',
    'Sincronizando horarios disponibles…',
  ];

  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  // ─── Lógica de carga ─────────────────────────────────────────────────────

  Future<void> _startLoading() async {
    if (!mounted) return;

    // Incrementar la generación invalida cualquier coroutine anterior.
    final gen = ++_generation;

    setState(() {
      _state = _LoadState.loading;
      _errorMessage = null;
      _stepIndex = 0;
    });

    // _cycleLabels recibe su generación y se auto-cancela si es obsoleta.
    _cycleLabels(gen);

    try {
      // BUG 3 FIX: timeout de 20 s — si el servidor cuelga, el usuario
      // ve el error en lugar de quedar atrapado infinitamente.
      await InitialDataOrchestrator()
          .loadAll()
          .timeout(const Duration(seconds: 20));

      // Re-agendar notificaciones pendientes tras login/reinicio.
      // Fire-and-forget: no bloquea la navegación si el storage tarda.
      NotificationService.rescheduleNotificationsForCurrentUser()
          .catchError((_) {});

      // Verificar que esta generación sigue siendo la activa antes de navegar.
      // Sin este guard, un doble tap en "Reintentar" puede lanzar dos instancias
      // que ambas intentan hacer pushReplacementNamed.
      if (!mounted || gen != _generation) return;

      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted || gen != _generation) return;

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e, st) {
      AppLogger.error('LoadingDataScreen', 'Error en precarga de datos', e, st);
      if (!mounted || gen != _generation) return;
      setState(() {
        _state = _LoadState.error;
        _errorMessage = _friendlyMessage(e);
      });
    }
  }

  /// Cicla los labels cosméticamiente cada 700 ms.
  ///
  /// Recibe [gen] para auto-cancelarse si _startLoading fue llamado de nuevo:
  ///   - Reintentar → nuevo gen → esta coroutine vieja retorna inmediatamente.
  ///   - Estado error → también aborta.
  Future<void> _cycleLabels(int gen) async {
    for (var i = 1; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 700));
      // Doble guard: generación obsoleta O estado de error → abortar.
      if (!mounted || gen != _generation || _state == _LoadState.error) return;
      setState(() => _stepIndex = i);
    }
  }

  String _friendlyMessage(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('timeoutexception')) {
      return 'El servidor tardó demasiado en responder.\nIntenta de nuevo.';
    }
    if (raw.contains('socketexception') ||
        raw.contains('network') ||
        raw.contains('connection') ||
        raw.contains('unreachable')) {
      return 'Sin conexión a internet.\nVerifica tu red e intenta de nuevo.';
    }
    return 'No se pudieron cargar los datos del servidor.\nIntenta de nuevo.';
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // BUG 6 FIX: color real del tema en lugar de Colors.transparent.
    // Evita el flash negro durante transiciones en algunos dispositivos.
    final bgColor = isDark ? const Color(0xFF101214) : const Color(0xFFF7F9FB);

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedGradientBackground(
        isDark: isDark,
        // BUG 7 FIX: LayoutBuilder da a AnimatedSwitcher un espacio de
        // constraints fijo → los dos hijos (loading / error) ocupan exactamente
        // el mismo BoxConstraints → cero saltos de layout durante la transición.
        child: LayoutBuilder(
          builder: (context, constraints) => SafeArea(
            child: AnimatedSwitcher(
              duration: AppDurations.normal,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _state == _LoadState.error
                  ? _buildErrorState(isDark, constraints)
                  : _buildLoadingState(isDark, constraints),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Estado: Cargando ─────────────────────────────────────────────────────

  Widget _buildLoadingState(bool isDark, BoxConstraints constraints) {
    final r = context.r;

    // BUG 4 FIX: tamaño del loader proporcional a la pantalla, con clamp para
    // evitar que sea demasiado pequeño en phones (90px) o enorme en tablets (160px).
    final loaderSize = (constraints.maxHeight * 0.16).clamp(90.0, 160.0);

    return SizedBox(
      key: const ValueKey('loading'),
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      child: Center(
        child: Padding(
          // BUG 4 FIX: paddingH del sistema responsive en lugar de 32 fijo.
          padding: EdgeInsets.symmetric(horizontal: r.paddingH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CossmilLoader(size: loaderSize),

              // BUG 4 FIX: spaceXxl responsive (28–48 según device).
              SizedBox(height: r.spaceXxl),

              // Etiqueta de paso — fade + slide al cambiar
              AnimatedSwitcher(
                duration: AppDurations.fast,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    )),
                    child: child,
                  ),
                ),
                child: Text(
                  _steps[_stepIndex],
                  key: ValueKey(_stepIndex),
                  textAlign: TextAlign.center,
                  // BUG 4 FIX: bodyMedium del sistema tipográfico responsive.
                  style: context.texts.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryC(isDark),
                  ),
                ),
              ),

              // BUG 4 FIX: spaceLg responsive (16–28) en lugar de 20 fijo.
              SizedBox(height: r.spaceLg),

              // Dots de progreso
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (i) {
                  final isActive = i == _stepIndex;
                  return AnimatedContainer(
                    duration: AppDurations.fast,
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: isActive
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.22),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Estado: Error ────────────────────────────────────────────────────────

  Widget _buildErrorState(bool isDark, BoxConstraints constraints) {
    final r = context.r;

    // BUG 4 FIX: tamaños del ícono proporcionales al sistema de tokens.
    final iconContainerSize = r.avatarMd * 1.5; // 60–78 según device
    final iconSize = r.iconLg;                   // 28–40 según device

    return SizedBox(
      key: const ValueKey('error'),
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      // BUG 5 FIX: SingleChildScrollView garantiza que en pantallas pequeñas
      // con fuente de accesibilidad grande el contenido no haga overflow;
      // en pantallas normales el Center lo mantiene centrado verticalmente.
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.paddingH),
              child: FadeSlideIn(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ícono de error
                    Container(
                      // BUG 4 FIX: tamaño del contenedor via token responsive.
                      width: iconContainerSize,
                      height: iconContainerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        CupertinoIcons.wifi_slash,
                        size: iconSize,
                        color: AppColors.error,
                      ),
                    ),

                    SizedBox(height: r.spaceLg),

                    // BUG 4 FIX: titleLarge del sistema tipográfico.
                    Text(
                      'Error de conexión',
                      style: context.texts.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryC(isDark),
                      ),
                    ),

                    SizedBox(height: r.spaceSm),

                    // BUG 4 FIX: bodyMedium responsive.
                    Text(
                      _errorMessage ?? 'Ocurrió un error inesperado.',
                      textAlign: TextAlign.center,
                      style: context.texts.bodyMedium.copyWith(
                        height: 1.55,
                        color: AppColors.textSecondaryC(isDark),
                      ),
                    ),

                    SizedBox(height: r.spaceXl),

                    // Botón de reintento
                    SizedBox(
                      width: double.infinity,
                      // BUG 4 FIX: buttonHeight responsive (48–56 según device).
                      height: r.buttonHeight,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        // BUG 4 FIX: buttonRadius del sistema de tokens.
                        borderRadius: BorderRadius.circular(r.buttonRadius),
                        color: AppColors.primary,
                        onPressed: _startLoading,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.arrow_clockwise,
                              // BUG 4 FIX: iconSm responsive (18–24).
                              size: r.iconSm,
                              color: Colors.white,
                            ),
                            SizedBox(width: r.spaceSm),
                            Text(
                              'Reintentar conexión',
                              // BUG 4 FIX: bodyLarge del sistema tipográfico.
                              style: context.texts.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
