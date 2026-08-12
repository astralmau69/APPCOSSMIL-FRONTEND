import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/session/user_session.dart';
import '../../../core/services/screen_security_service.dart';
import '../carnet_data.dart';
import '../carnet_pdf.dart';
import '../widgets/carnet_card.dart';
import '../widgets/holographic_card.dart';
import 'carnet_pdf_preview_screen.dart';
import 'carnet_salud_screen.dart';
import 'carnet_validador_screen.dart';

/// Zona sensible al toque de la tarjeta (la que dispara el giro). Expuesta para
/// que las pruebas apunten al gesto correcto y no a un `AspectRatio` cualquiera.
const Key carnetFlipKey = ValueKey('carnet-flip');

/// A partir de este ancho de contenido la tarjeta y sus acciones se reparten en
/// dos columnas. Por debajo (cualquier teléfono, también en el navegador) se
/// mantiene la disposición apilada, idéntica a la de la app.
///
/// El umbral sale de sumar lo que necesita cada panel: ~480 px para que la
/// tarjeta se lea bien, ~320 px para que "Descargar PDF" y "Compartir" quepan
/// uno al lado del otro, más la separación y los márgenes.
const double _kTwoPaneWidth = 880;

/// Carnet de asegurado COSSMIL digital: réplica fiel del carnet físico
/// (frente + reverso) con efecto holográfico, giro al tocar, e impresión.
///
/// El movimiento de esta pantalla es una sola secuencia orquestada desde
/// [_introCtrl]: el halo se enciende detrás, la tarjeta se endereza como si se
/// sacara de la billetera, un destello la cruza una vez y recién entonces
/// aparecen la ayuda y las acciones. Un único controlador (en vez de un
/// temporizador por widget) mantiene los tiempos relativos entre sí y permite
/// saltarse todo de golpe cuando el sistema pide reducir el movimiento.
class CarnetScreen extends StatefulWidget {
  const CarnetScreen({super.key});

  @override
  State<CarnetScreen> createState() => _CarnetScreenState();
}

class _CarnetScreenState extends State<CarnetScreen>
    with TickerProviderStateMixin {
  static const Color _azul = kCarnetAzul;
  static const Color _azulOsc = kCarnetAzulOsc;

  bool _working = false;

  late final AnimationController _flipCtrl;
  late final AnimationController _introCtrl;

  /// Cara visible. Es un notifier (y no `setState`) porque solo la ayuda y el
  /// botón de girar dependen de él: la tarjeta y las acciones no se reconstruyen.
  final ValueNotifier<bool> _showingBack = ValueNotifier<bool>(false);

  // Tramos de la secuencia de entrada (fracciones de [_introCtrl]).
  late final Animation<double> _halo = _interval(0.00, 0.55);
  late final Animation<double> _card = _interval(0.05, 0.65);
  late final Animation<double> _sweep = _interval(
    0.38,
    0.92,
    curve: AppCurves.smooth,
  );
  late final Animation<double> _hint = _interval(0.50, 0.78);
  late final Animation<double> _actions = _interval(0.56, 0.86);
  late final Animation<double> _more = _interval(0.64, 0.94);
  late final Animation<double> _foot = _interval(0.74, 1.00);

  bool _reduceMotion = false;
  bool _introStarted = false;

  // Llaves para capturar las tarjetas reales a imagen (PDF idéntico al digital).
  final GlobalKey _frontKey = GlobalKey();
  final GlobalKey _backKey = GlobalKey();

  /// Solo `true` mientras se genera un PDF (ver [_pdfBytes]).
  bool _mountCaptureCards = false;

  // Se calcula una sola vez (no cambia mientras la pantalla está abierta).
  late final CarnetData _data = CarnetData.fromUser(UserSession.currentUser);

  // Las dos caras se construyen UNA vez: durante el giro solo se recomponen,
  // no se reconstruye el árbol del carnet (fotos, QR y painters) en cada frame.
  late final Widget _frontFace = _scaled(CarnetCardFront(data: _data));
  late final Widget _backFace = _scaled(CarnetCardBack(data: _data));

  Animation<double> _interval(
    double begin,
    double end, {
    Curve curve = AppCurves.snappy,
  }) => CurvedAnimation(
    parent: _introCtrl,
    curve: Interval(begin, end, curve: curve),
  );

  @override
  void initState() {
    super.initState();
    // Bloquea capturas/grabación en todo el apartado del carnet (incluye la
    // subpantalla "Carnet Digital de Seguro", al ser FLAG_SECURE por ventana).
    ScreenSecurityService.enable();

    _introCtrl = AnimationController(vsync: this, duration: AppDurations.extra);
    _flipCtrl = AnimationController(
      vsync: this,
      duration: AppDurations.verySlow,
    );
    // Solo interesa el cruce de la mitad del giro (cuándo cambia la cara), no
    // cada frame: así el listener no dispara reconstrucciones a 60 fps.
    _flipCtrl.addListener(() {
      final back = _flipCtrl.value >= 0.5;
      if (back != _showingBack.value) _showingBack.value = back;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_introStarted) return;
    _introStarted = true;
    // Con reduce-motion la pantalla aparece ya montada, sin secuencia.
    if (_reduceMotion) {
      _introCtrl.value = 1.0;
    } else {
      _introCtrl.forward();
    }
  }

  @override
  void dispose() {
    // Restaura la posibilidad de captura al salir del carnet.
    ScreenSecurityService.disable();
    _flipCtrl.dispose();
    _introCtrl.dispose();
    _showingBack.dispose();
    super.dispose();
  }

  void _flip() {
    if (_flipCtrl.isAnimating) return;
    final toBack = !_showingBack.value;
    // El giro es una acción física: se acompaña con un toque háptico, igual que
    // al dar vuelta una tarjeta real.
    HapticFeedback.selectionClick();
    if (_reduceMotion) {
      _flipCtrl.value = toBack ? 1.0 : 0.0;
      _showingBack.value = toBack;
      return;
    }
    toBack ? _flipCtrl.forward() : _flipCtrl.reverse();
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await task();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo generar el PDF del carnet.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Captura una tarjeta (RepaintBoundary) a PNG en alta resolución.
  Future<Uint8List?> _capture(GlobalKey key) async {
    try {
      final ctx = key.currentContext;
      if (ctx == null) return null;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bd?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Arma el PDF usando las imágenes reales de las tarjetas (idéntico al
  /// carnet digital). Si la captura falla, usa el PDF dibujado como respaldo.
  ///
  /// Las tarjetas de captura se montan solo aquí: tenerlas siempre en el árbol
  /// obligaba a medir y pintar dos carnets completos a tamaño 1010×637 (con sus
  /// panales, foto y QR) cada vez que se entraba a la pantalla, y nunca se ven.
  Future<Uint8List> _pdfBytes() async {
    setState(() => _mountCaptureCards = true);
    try {
      // Dos frames: uno monta las tarjetas y otro garantiza que ya se pintaron
      // (toImage exige un RepaintBoundary sin pintura pendiente).
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      final front = await _capture(_frontKey);
      final back = await _capture(_backKey);
      if (front != null && back != null) {
        return CarnetPdf.buildFromImages(front: front, back: back, d: _data);
      }
      return CarnetPdf.build(_data);
    } finally {
      if (mounted) setState(() => _mountCaptureCards = false);
    }
  }

  Future<void> _imprimir() => _run(() async {
    final bytes = await _pdfBytes();
    if (!mounted) return;
    // Primero la vista previa dentro de la app (sin capturas); desde ahí el
    // usuario imprime o comparte.
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => CarnetPdfPreviewScreen(
          pdfBytes: bytes,
          fileName: 'Carnet_${_data.matricula}',
        ),
      ),
    );
  });

  Future<void> _compartir() => _run(() async {
    final bytes = await _pdfBytes();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Carnet_${_data.matricula}.pdf',
    );
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final d = _data;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : const Color(0xFFEDF4FB),
      body: Stack(
        children: [
          // Tarjetas reales renderizadas FUERA de pantalla, a tamaño fijo, para
          // capturarlas a imagen y que el PDF sea idéntico al carnet digital.
          // Solo existen mientras se genera el PDF (ver [_pdfBytes]).
          if (_mountCaptureCards) ...[
            Positioned(
              left: -20000,
              top: -20000,
              child: RepaintBoundary(
                key: _frontKey,
                child: SizedBox(
                  width: kCarnetRefW,
                  height: kCarnetRefH,
                  child: CarnetCardFront(data: d),
                ),
              ),
            ),
            Positioned(
              left: -20000,
              top: -10000,
              child: RepaintBoundary(
                key: _backKey,
                child: SizedBox(
                  width: kCarnetRefW,
                  height: kCarnetRefH,
                  child: CarnetCardBack(data: d),
                ),
              ),
            ),
          ],
          Positioned.fill(child: _backdrop(isDark)),
          SafeArea(
            child: Column(
              children: [
                _header(isDark, r),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      // El reparto se decide por el ancho REALMENTE disponible,
                      // no por el tipo de dispositivo: así vale igual para una
                      // ventana de navegador que se redimensiona, para el
                      // split-screen y para el hueco que deja el SideNavBar. Un
                      // teléfono en el navegador cae por debajo del umbral y ve
                      // exactamente la misma pantalla que en la app.
                      final wide = c.maxWidth >= _kTwoPaneWidth;
                      return SingleChildScrollView(
                        // La barra de navegación flotante del shell se superpone
                        // a esta pantalla (se abre dentro de una pestaña): sin
                        // este respiro taparía el pie y la última acción.
                        padding: EdgeInsets.fromLTRB(
                          r.paddingH,
                          r.spaceMd,
                          r.paddingH,
                          r.navBarBottomSpace + r.spaceMd,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: wide ? 1040 : 480,
                            ),
                            child: wide
                                ? _twoPaneBody(isDark, r)
                                : _stackedBody(isDark, r),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Disposición de teléfono: todo en una columna, la tarjeta arriba.
  Widget _stackedBody(bool isDark, AppResponsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cardStage(_data),
        SizedBox(height: r.spaceLg),
        _enter(_hint, dy: 0.35, child: _flipHint(isDark)),
        SizedBox(height: r.spaceLg),
        // El desplazamiento de SlideTransition es una fracción del alto del
        // propio bloque: cuanto más alto el bloque, menor la fracción, para
        // que todos recorran una distancia parecida en pantalla.
        _enter(_actions, dy: 0.4, child: _primaryActions(isDark, r)),
        SizedBox(height: r.spaceMd),
        _enter(_more, dy: 0.18, child: _moreActions(isDark)),
        SizedBox(height: r.spaceLg),
        _enter(_foot, dy: 0.2, child: _footer(isDark)),
      ],
    );
  }

  /// Disposición de pantalla ancha: la tarjeta a un lado y lo que se puede
  /// hacer con ella al otro. En una sola columna, sobre un monitor, el carnet
  /// quedaba como una tira estrecha en el centro con las acciones muy por
  /// debajo del pliegue; aquí ambas cosas se ven a la vez y sin desplazar.
  Widget _twoPaneBody(bool isDark, AppResponsive r) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _cardStage(_data),
              SizedBox(height: r.spaceLg),
              _enter(_hint, dy: 0.35, child: _flipHint(isDark)),
            ],
          ),
        ),
        SizedBox(width: r.spaceXl),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _enter(_actions, dy: 0.4, child: _primaryActions(isDark, r)),
              SizedBox(height: r.spaceMd),
              _enter(_more, dy: 0.18, child: _moreActions(isDark)),
              SizedBox(height: r.spaceLg),
              _enter(_foot, dy: 0.2, child: _footer(isDark)),
            ],
          ),
        ),
      ],
    );
  }

  /// Entrada estándar de un bloque: aparece y sube un poco, con el desfase que
  /// le toque dentro de la secuencia. Usa transiciones nativas (el hijo no se
  /// reconstruye) y respeta reduce-motion vía el valor fijo de [_introCtrl].
  Widget _enter(Animation<double> t, {double dy = 0.5, required Widget child}) {
    if (_reduceMotion) return child;
    return FadeTransition(
      opacity: t,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, dy),
          end: Offset.zero,
        ).animate(t),
        child: child,
      ),
    );
  }

  // ── Escenario de la tarjeta ─────────────────────────────────────────────
  /// La tarjeta entra enderezándose: empieza inclinada hacia atrás y baja hasta
  /// quedar de frente, como al sacarla de la billetera. El destello holográfico
  /// la cruza una sola vez al final del movimiento.
  Widget _cardStage(CarnetData d) {
    final card = Semantics(
      button: true,
      label: 'Carnet de asegurado COSSMIL. Toca para ver la otra cara.',
      child: HolographicCard(
        borderRadius: 22,
        shineStrength: 0.48,
        honeycombShimmer: true,
        entrySweep: _reduceMotion ? null : _sweep,
        child: AspectRatio(
          aspectRatio: 1.586,
          child: GestureDetector(
            key: carnetFlipKey,
            onTap: _flip,
            child: AnimatedBuilder(
              animation: _flipCtrl,
              builder: (context, _) => _flipBuilder(),
            ),
          ),
        ),
      ),
    );

    if (_reduceMotion) return card;

    return AnimatedBuilder(
      animation: _card,
      child: card,
      builder: (context, child) {
        final t = _card.value;
        // Terminada la entrada la matriz vuelve a la identidad: una matriz con
        // perspectiva encima de la tarjeta desvía el hit-test y el toque para
        // girar deja de llegar. Los envoltorios se mantienen (aunque no hagan
        // nada) para no cambiar la forma del árbol y remontar el holograma;
        // con opacidad 1 el Opacity ni siquiera crea capa.
        return Opacity(
          opacity: t,
          child: Transform(
            alignment: Alignment.center,
            transform: t >= 1.0
                ? Matrix4.identity()
                : (Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..translateByDouble(0.0, 44 * (1 - t), 0.0, 1.0)
                    ..rotateX(0.22 * (1 - t))),
            child: child,
          ),
        );
      },
    );
  }

  // ── Flip ───────────────────────────────────────────────────────────────
  Widget _flipBuilder() {
    final v = Curves.easeInOutCubic.transform(_flipCtrl.value);
    final angle = v * math.pi;
    final isBack = angle > math.pi / 2;
    final scale = 1 - 0.06 * math.sin(v * math.pi);
    final Widget face = isBack
        ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: _backFace,
          )
        : _frontFace;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..scaleByDouble(scale, scale, 1.0, 1.0)
        ..rotateY(angle),
      child: face,
    );
  }

  Widget _scaled(Widget canvas) =>
      FittedBox(fit: BoxFit.contain, child: canvas);

  // ── Backdrop ─────────────────────────────────────────────────────────────
  /// Halo que se enciende detrás de la tarjeta al entrar: da la sensación de
  /// que la tarjeta trae su propia luz, en vez de aparecer sobre un fondo plano.
  Widget _backdrop(bool isDark) {
    final halo = AnimatedBuilder(
      animation: _halo,
      builder: (context, _) {
        final t = _halo.value;
        return Align(
          alignment: const Alignment(0, -0.55),
          child: Transform.scale(
            scale: 0.82 + 0.18 * t,
            child: Opacity(
              opacity: t,
              child: Container(
                width: 460,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _azul.withValues(alpha: isDark ? 0.26 : 0.18),
                      _azul.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (isDark) {
      return Stack(
        children: [
          const AppBackground(isDark: true, child: SizedBox.expand()),
          Positioned.fill(child: IgnorePointer(child: halo)),
        ],
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3EFFA), Color(0xFFF5F8FC)],
        ),
      ),
      child: IgnorePointer(child: halo),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _header(bool isDark, AppResponsive r) {
    return Padding(
      padding: EdgeInsets.fromLTRB(r.spaceSm, r.spaceSm, r.paddingH, r.spaceSm),
      child: Row(
        children: [
          _circleButton(
            icon: CupertinoIcons.back,
            isDark: isDark,
            onTap: () => Navigator.of(context).maybePop(),
            tooltip: 'Volver',
          ),
          SizedBox(width: r.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mi Carnet COSSMIL',
                  style: context.texts.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
                Text(
                  'Carnet digital de asegurado',
                  style: context.texts.bodySmall.copyWith(
                    color: AppColors.textSecondaryC(isDark),
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _showingBack,
            builder: (context, back, _) => _circleButton(
              icon: back
                  ? CupertinoIcons.arrow_uturn_left
                  : CupertinoIcons.arrow_2_circlepath,
              isDark: isDark,
              onTap: _flip,
              tint: _azul,
              tooltip: back ? 'Ver el frente' : 'Ver el reverso',
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    required String tooltip,
    Color? tint,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: OptimizedPressButton(
        onTap: onTap,
        scaleDown: 0.9,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: (tint ?? AppColors.textTertiaryC(isDark)).withValues(
                alpha: isDark ? 0.25 : 0.18,
              ),
            ),
            boxShadow: isDark ? null : AppColors.softShadow,
          ),
          child: Icon(
            icon,
            size: 20,
            color: tint ?? AppColors.textPrimaryC(isDark),
          ),
        ),
      ),
    );
  }

  // ── Hint ─────────────────────────────────────────────────────────────────
  Widget _flipHint(bool isDark) {
    return Center(
      child: ValueListenableBuilder<bool>(
        valueListenable: _showingBack,
        builder: (context, back, _) => AnimatedSwitcher(
          duration: _reduceMotion ? Duration.zero : AppDurations.quick,
          switchInCurve: AppCurves.snappy,
          child: Container(
            key: ValueKey(back),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: _azul.withValues(alpha: isDark ? 0.25 : 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  back
                      ? CupertinoIcons.arrow_uturn_left
                      : CupertinoIcons.hand_draw,
                  size: 14,
                  color: _azul,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    back
                        ? 'Reverso · toca para volver al frente'
                        : 'Toca para ver el reverso',
                    style: context.texts.labelSmall.copyWith(
                      color: AppColors.textSecondaryC(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Acciones sobre el documento ──────────────────────────────────────────
  /// Las dos acciones que producen algo (un PDF) van juntas y arriba: la
  /// principal con peso visual, la secundaria en tono. Todo lo que navega a
  /// otra pantalla vive más abajo, en su propia lista.
  Widget _primaryActions(bool isDark, AppResponsive r) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: OptimizedPressButton(
            onTap: _working ? null : _imprimir,
            scaleDown: 0.97,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_azulOsc, _azul]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _azul.withValues(alpha: 0.38),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: _working
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.printer_fill,
                            size: 20,
                            color: Colors.white,
                          ),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Descargar PDF',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        SizedBox(width: r.spaceSm),
        Expanded(
          flex: 2,
          child: OptimizedPressButton(
            onTap: _working ? null : _compartir,
            scaleDown: 0.97,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : _azul.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _azul.withValues(alpha: 0.25)),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.share, size: 18, color: _azul),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Compartir',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _azul,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Destinos del apartado, agrupados en una sola tarjeta con el mismo lenguaje
  /// que las listas de Perfil. Cada fila dice qué encontrarás al entrar, en vez
  /// de repetir tres botones idénticos que no se distinguen entre sí.
  Widget _moreActions(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _azul.withValues(alpha: isDark ? 0.18 : 0.14),
        ),
        boxShadow: isDark ? null : AppColors.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _navRow(
            isDark: isDark,
            icon: CupertinoIcons.checkmark_shield_fill,
            title: 'Carnet Digital de Seguro',
            subtitle: 'Vista oficial con QR que cambia cada 15 segundos',
            onTap: _working ? null : _abrirCarnetSalud,
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 56,
            color: _azul.withValues(alpha: isDark ? 0.14 : 0.10),
          ),
          _navRow(
            isDark: isDark,
            icon: CupertinoIcons.qrcode_viewfinder,
            title: 'Validar un carnet',
            subtitle: 'Escanea el QR de otro asegurado para verificarlo',
            onTap: _working ? null : _abrirValidador,
          ),
        ],
      ),
    );
  }

  Widget _navRow({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return OptimizedPressButton(
      onTap: onTap,
      scaleDown: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _azul.withValues(alpha: isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: _azul),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimaryC(isDark),
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.texts.labelSmall.copyWith(
                      color: AppColors.textSecondaryC(isDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: AppColors.textTertiaryC(isDark),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirCarnetSalud() {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (_) => const CarnetSaludScreen()));
  }

  void _abrirValidador() {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (_) => const CarnetValidadorScreen()));
  }

  Widget _footer(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          CupertinoIcons.lock_fill,
          size: 12,
          color: AppColors.textTertiaryC(isDark),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Datos de tu cuenta COSSMIL · representación digital',
            textAlign: TextAlign.center,
            style: context.texts.labelSmall.copyWith(
              color: AppColors.textTertiaryC(isDark),
            ),
          ),
        ),
      ],
    );
  }
}
