import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/animations/app_dialog.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/models/reserva_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/session/user_session.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/utils/app_logger.dart';
import 'doctor_rating_modal.dart';

/// Barrera de calificaciones pendientes: al entrar a la app, si el asegurado
/// dejó atenciones sin calificar, no puede seguir hasta calificarlas.
///
/// Quién está pendiente lo dice el backend
/// (`/api/programacion/calificaciones-pendientes/{idper}`), no el teléfono. El
/// cálculo local que hacía [DoctorRatingModal.showIfNeeded] —ventana de
/// tiempo + banderas en SharedPreferences— no sobrevivía a reinstalar la app
/// ni a cambiar de equipo, y dejaba atenciones sin calificar para siempre.
///
/// Es deliberadamente inescapable: sin botón de cerrar, sin descartar tocando
/// fuera y con el botón atrás anulado. Si la consulta falla tampoco deja
/// pasar, porque no poder saber qué hay pendiente no es lo mismo que no haya
/// nada. La única salida que no es calificar es cerrar sesión, y está ahí a
/// propósito: sin ella, alguien sin señal se queda con la app inservible y sin
/// ninguna acción posible.
class CalificacionesPendientesGate extends StatefulWidget {
  final ProgramacionService service;

  const CalificacionesPendientesGate({super.key, required this.service});

  /// Evita que dos disparos (arranque + volver del background) apilen dos
  /// barreras encima de la misma pantalla.
  static bool _abierta = false;

  /// Olvida que hay una barrera abierta. Solo para tests, que terminan con la
  /// barrera en pantalla justamente porque no se puede cerrar.
  @visibleForTesting
  static void debugReset() => _abierta = false;

  /// Muestra la barrera si hay algo pendiente. No hace nada si ya está
  /// abierta o si la sesión no tiene un idper usable.
  static Future<void> showIfNeeded(
    BuildContext context, {
    required ProgramacionService service,
  }) async {
    if (_abierta) return;
    final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
    if (idper == 0) return;

    // La consulta va ANTES de montar nada: si no hay pendientes —el caso
    // normal— el usuario no ve ni un parpadeo.
    final List<ReservaModel> pendientes;
    try {
      pendientes = await service.getCalificacionesPendientes(idper);
    } catch (e) {
      AppLogger.warn(
        'CalificacionesGate',
        'No se pudo consultar lo pendiente; se bloquea con reintento',
        e,
      );
      if (!context.mounted) return;
      await _mostrar(context, service, null);
      return;
    }

    if (pendientes.isEmpty || !context.mounted) return;
    await _mostrar(context, service, pendientes);
  }

  static Future<void> _mostrar(
    BuildContext context,
    ProgramacionService service,
    List<ReservaModel>? iniciales,
  ) async {
    _abierta = true;
    try {
      await showAppDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Calificaciones pendientes',
        barrierColor: Colors.black.withValues(alpha: 0.75),
        builder: (ctx) => _GateScope(
          iniciales: iniciales,
          child: CalificacionesPendientesGate(service: service),
        ),
      );
    } finally {
      _abierta = false;
    }
  }

  @override
  State<CalificacionesPendientesGate> createState() =>
      _CalificacionesPendientesGateState();
}

/// Pasa la lista ya consultada al widget sin ensanchar su constructor público:
/// `null` significa "la consulta falló, arranca en error".
class _GateScope extends InheritedWidget {
  final List<ReservaModel>? iniciales;

  const _GateScope({required this.iniciales, required super.child});

  static List<ReservaModel>? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_GateScope>()
      ?.iniciales;

  @override
  bool updateShouldNotify(_GateScope oldWidget) => false;
}

class _CalificacionesPendientesGateState
    extends State<CalificacionesPendientesGate> {
  List<ReservaModel> _pendientes = const [];
  bool _cargando = false;
  bool _error = false;
  bool _cerrandoSesion = false;
  bool _inicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inicializado) return;
    _inicializado = true;
    final iniciales = _GateScope.of(context);
    if (iniciales == null) {
      _error = true;
    } else {
      _pendientes = iniciales;
    }
  }

  Future<void> _reintentar() async {
    setState(() {
      _cargando = true;
      _error = false;
    });
    try {
      final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
      final frescas = await widget.service.getCalificacionesPendientes(idper);
      if (!mounted) return;
      if (frescas.isEmpty) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        _pendientes = frescas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = true;
      });
    }
  }

  Future<void> _calificar(ReservaModel reserva) async {
    await DoctorRatingModal.showManual(context, reserva);
    if (!mounted) return;
    // La califique o no, se le pregunta al registro local: el modal marca la
    // atención al enviarla (y también cuando el backend responde que ya
    // estaba calificada).
    final sigueSinCalificar = await DoctorRatingModal.isRatable(reserva);
    if (!mounted || sigueSinCalificar) return;

    final quedan = _pendientes.where((r) => !_mismaAtencion(r, reserva));
    if (quedan.isEmpty) {
      // Se levanta la barrera con lo que ya sabemos. No se revalida contra el
      // backend a propósito: si esa consulta fallara, el usuario acabaría de
      // calificar todo y aun así se quedaría encerrado. El próximo ingreso
      // vuelve a preguntar, que es la red de seguridad.
      Navigator.pop(context);
      return;
    }
    setState(() => _pendientes = quedan.toList());
  }

  /// Dos filas son la misma atención si coinciden sus claves del backend.
  bool _mismaAtencion(ReservaModel a, ReservaModel b) =>
      a.idtran == b.idtran && a.dr == b.dr && a.gestion == b.gestion;

  Future<void> _cerrarSesion() async {
    final confirmado = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text(
          '¿Está seguro que desea cerrar sesión? '
          'Las calificaciones pendientes seguirán ahí al volver a entrar.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Cerrar Sesión'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _cerrandoSesion = true);
    try {
      await AuthRepositoryImpl().logout();
    } catch (e) {
      AppLogger.error('CalificacionesGate', 'Error al cerrar sesión', e);
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return PopScope(
      // El botón atrás no puede saltarse la barrera.
      canPop: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.paddingH),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: r.modalMaxWidth,
              maxHeight: context.height * 0.8,
            ),
            child: Material(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(r.modalRadius),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.all(r.modalPadding),
                child: _contenido(isDark, r),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido(bool isDark, AppResponsive r) {
    if (_cerrandoSesion || _cargando) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: CupertinoActivityIndicator(radius: 16),
      );
    }
    if (_error) return _vistaError(isDark, r);
    return _vistaLista(isDark, r);
  }

  Widget _vistaError(bool isDark, AppResponsive r) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          CupertinoIcons.wifi_exclamationmark,
          size: AppSpacing.iconXl,
          color: AppColors.warning,
        ),
        SizedBox(height: r.spaceMd),
        Text(
          'No pudimos verificar sus calificaciones',
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.textPrimaryC(isDark),
          ),
        ),
        SizedBox(height: r.spaceSm),
        Text(
          'Revise su conexión e intente de nuevo. Necesitamos consultarlo '
          'antes de continuar.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondaryC(isDark),
          ),
        ),
        SizedBox(height: r.spaceLg),
        CupertinoButton(
          color: AppColors.accentForTheme(isDark),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          onPressed: _reintentar,
          child: const Text('Reintentar'),
        ),
        _botonCerrarSesion(isDark),
      ],
    );
  }

  Widget _vistaLista(bool isDark, AppResponsive r) {
    final total = _pendientes.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          CupertinoIcons.star_circle_fill,
          size: AppSpacing.iconXl,
          color: AppColors.accentForTheme(isDark),
        ),
        SizedBox(height: r.spaceMd),
        Text(
          total == 1
              ? 'Le falta calificar una atención'
              : 'Le faltan calificar $total atenciones',
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.textPrimaryC(isDark),
          ),
        ),
        SizedBox(height: r.spaceSm),
        Text(
          'Su opinión nos ayuda a mejorar la atención. Califíquelas para '
          'continuar.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondaryC(isDark),
          ),
        ),
        SizedBox(height: r.spaceMd),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: total,
            separatorBuilder: (_, __) => SizedBox(height: r.spaceSm),
            itemBuilder: (_, i) => _Fila(
              reserva: _pendientes[i],
              isDark: isDark,
              onTap: () => _calificar(_pendientes[i]),
            ),
          ),
        ),
        _botonCerrarSesion(isDark),
      ],
    );
  }

  /// Única salida que no es calificar. Ver la doc de la clase.
  Widget _botonCerrarSesion(bool isDark) => CupertinoButton(
    onPressed: _cerrarSesion,
    child: Text(
      'Cerrar sesión',
      style: AppTypography.bodyMedium.copyWith(
        color: AppColors.textSecondaryC(isDark),
      ),
    ),
  );
}

/// Una atención pendiente. Toda la fila es tocable y abre su calificación.
class _Fila extends StatelessWidget {
  final ReservaModel reserva;
  final bool isDark;
  final VoidCallback onTap;

  const _Fila({
    required this.reserva,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final detalle = [
      reserva.specialty,
      if (reserva.date.isNotEmpty) _fecha(reserva.date),
    ].where((t) => t.isNotEmpty).join(' · ');

    return CupertinoButton(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.scaffoldBg(isDark),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reserva.doctorName.isEmpty
                      ? 'Atención médica'
                      : reserva.doctorName,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
                if (detalle.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detalle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryC(isDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            CupertinoIcons.chevron_right,
            size: AppSpacing.iconSm,
            color: AppColors.textSecondaryC(isDark),
          ),
        ],
      ),
    );
  }

  /// "2026-01-13" → "13/01/2026". Si viene en otro formato se muestra tal cual.
  static String _fecha(String iso) {
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
  }
}
