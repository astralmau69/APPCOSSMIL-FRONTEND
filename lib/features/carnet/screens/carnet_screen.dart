import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Carnet de asegurado COSSMIL digital: réplica fiel del carnet físico
/// (frente + reverso) con efecto holográfico, giro al tocar, e impresión.
class CarnetScreen extends StatefulWidget {
  const CarnetScreen({super.key});

  @override
  State<CarnetScreen> createState() => _CarnetScreenState();
}

class _CarnetScreenState extends State<CarnetScreen>
    with SingleTickerProviderStateMixin {
  static const Color _azul = kCarnetAzul;
  static const Color _azulOsc = kCarnetAzulOsc;

  bool _working = false;
  late final AnimationController _flipCtrl;
  bool get _showingBack => _flipCtrl.value >= 0.5;

  // Llaves para capturar las tarjetas reales a imagen (PDF idéntico al digital).
  final GlobalKey _frontKey = GlobalKey();
  final GlobalKey _backKey = GlobalKey();

  // Se calcula una sola vez (no cambia mientras la pantalla está abierta).
  late final CarnetData _data = CarnetData.fromUser(UserSession.currentUser);

  @override
  void initState() {
    super.initState();
    // Bloquea capturas/grabación en todo el apartado del carnet (incluye la
    // subpantalla "Carnet Digital de Seguro", al ser FLAG_SECURE por ventana).
    ScreenSecurityService.enable();
    _flipCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 720));
    // El giro de la tarjeta se anima con un AnimatedBuilder acotado; aquí solo
    // refrescamos el hint al cambiar de estado (no en cada frame).
    _flipCtrl.addStatusListener((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // Restaura la posibilidad de captura al salir del carnet.
    ScreenSecurityService.disable();
    _flipCtrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_flipCtrl.isAnimating) return;
    _showingBack ? _flipCtrl.reverse() : _flipCtrl.forward();
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await task();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo generar el PDF del carnet.'),
          behavior: SnackBarBehavior.floating,
        ));
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
  Future<Uint8List> _pdfBytes() async {
    final front = await _capture(_frontKey);
    final back = await _capture(_backKey);
    if (front != null && back != null) {
      return CarnetPdf.buildFromImages(front: front, back: back, d: _data);
    }
    return CarnetPdf.build(_data);
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
            bytes: bytes, filename: 'Carnet_${_data.matricula}.pdf');
      });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final d = _data;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFEDF4FB),
      body: Stack(
        children: [
          // Tarjetas reales renderizadas FUERA de pantalla, a tamaño fijo, para
          // capturarlas a imagen y que el PDF sea idéntico al carnet digital.
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
          Positioned.fill(child: _backdrop(isDark)),
          SafeArea(
            child: Column(
              children: [
                _header(isDark, r),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        r.paddingH, r.spaceMd, r.paddingH, r.spaceXl),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FadeSlideIn(
                              duration: AppDurations.slow,
                              offsetY: 16,
                              child: HolographicCard(
                                borderRadius: 22,
                                shineStrength: 0.48,
                                honeycombShimmer: true,
                                child: AspectRatio(
                                  aspectRatio: 1.586,
                                  child: GestureDetector(
                                    onTap: _flip,
                                    child: AnimatedBuilder(
                                      animation: _flipCtrl,
                                      builder: (context, _) => _flipBuilder(d),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: r.spaceLg),
                            FadeSlideIn(
                              duration: AppDurations.normal,
                              delay: const Duration(milliseconds: 120),
                              child: _flipHint(isDark),
                            ),
                            SizedBox(height: r.spaceLg),
                            FadeSlideIn(
                              duration: AppDurations.normal,
                              delay: const Duration(milliseconds: 200),
                              offsetY: 12,
                              child: _buttons(isDark, r),
                            ),
                            SizedBox(height: r.spaceLg),
                            _footer(isDark),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Flip ───────────────────────────────────────────────────────────────
  Widget _flipBuilder(CarnetData d) {
    final v = Curves.easeInOutCubic.transform(_flipCtrl.value);
    final angle = v * math.pi;
    final isBack = angle > math.pi / 2;
    final scale = 1 - 0.06 * math.sin(v * math.pi);
    final Widget face = isBack
        ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: _scaled(CarnetCardBack(data: d)),
          )
        : _scaled(CarnetCardFront(data: d));
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..scaleByDouble(scale, scale, 1.0, 1.0)
        ..rotateY(angle),
      child: face,
    );
  }

  Widget _scaled(Widget canvas) => FittedBox(fit: BoxFit.contain, child: canvas);

  // ── Backdrop ─────────────────────────────────────────────────────────────
  Widget _backdrop(bool isDark) {
    if (isDark) return const AppBackground(isDark: true, child: SizedBox.expand());
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3EFFA), Color(0xFFF5F8FC)],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.55),
        child: Container(
          width: 460,
          height: 320,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _azul.withValues(alpha: 0.18),
              _azul.withValues(alpha: 0.0),
            ]),
          ),
        ),
      ),
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
          ),
          SizedBox(width: r.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mi Carnet COSSMIL',
                    style: context.texts.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryC(isDark))),
                Text('Carnet digital de asegurado',
                    style: context.texts.bodySmall.copyWith(
                        color: AppColors.textSecondaryC(isDark))),
              ],
            ),
          ),
          _circleButton(
            icon: _showingBack
                ? CupertinoIcons.arrow_2_circlepath
                : CupertinoIcons.arrow_2_circlepath,
            isDark: isDark,
            onTap: _flip,
            tint: _azul,
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    Color? tint,
  }) {
    return OptimizedPressButton(
      onTap: onTap,
      scaleDown: 0.9,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
              color: (tint ?? AppColors.textTertiaryC(isDark))
                  .withValues(alpha: isDark ? 0.25 : 0.18)),
          boxShadow: isDark ? null : AppColors.softShadow,
        ),
        child: Icon(icon,
            size: 20, color: tint ?? AppColors.textPrimaryC(isDark)),
      ),
    );
  }

  // ── Hint ─────────────────────────────────────────────────────────────────
  Widget _flipHint(bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: _azul.withValues(alpha: isDark ? 0.25 : 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                _showingBack
                    ? CupertinoIcons.arrow_uturn_left
                    : CupertinoIcons.hand_draw,
                size: 14,
                color: _azul),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                _showingBack
                    ? 'Reverso · toca para ver el frente'
                    : 'Toca para girar · mueve el equipo para el holograma',
                style: context.texts.labelSmall.copyWith(
                    color: AppColors.textSecondaryC(isDark),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Botones ───────────────────────────────────────────────────────────────
  Widget _buttons(bool isDark, AppResponsive r) {
    return Column(
      children: [
        // Primario: Descargar / Imprimir (gradiente + sombra).
        OptimizedPressButton(
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
                        Icon(CupertinoIcons.printer_fill,
                            size: 20, color: Colors.white),
                        SizedBox(width: 10),
                        Text('Descargar / Imprimir PDF',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ],
                    ),
            ),
          ),
        ),
        SizedBox(height: r.spaceSm),
        // Secundario: Compartir (tonal).
        OptimizedPressButton(
          onTap: _working ? null : _compartir,
          scaleDown: 0.97,
          child: Container(
            height: 52,
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
                  const SizedBox(width: 9),
                  Text('Compartir',
                      style: TextStyle(
                          color: _azul,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5)),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: r.spaceSm),
        // Terciario: Carnet de Seguro de Salud (vista oficial vertical).
        OptimizedPressButton(
          onTap: _working ? null : _abrirCarnetSalud,
          scaleDown: 0.97,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _azul.withValues(alpha: 0.25)),
              boxShadow: isDark ? null : AppColors.softShadow,
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.checkmark_shield_fill,
                      size: 18, color: _azul),
                  const SizedBox(width: 9),
                  Text('Carnet Digital de Seguro',
                      style: TextStyle(
                          color: AppColors.textPrimaryC(isDark),
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5)),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: r.spaceSm),
        // Cuaternario: Validar un carnet (escanear el QR rotativo de otro).
        OptimizedPressButton(
          onTap: _working ? null : _abrirValidador,
          scaleDown: 0.97,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _azul.withValues(alpha: 0.25)),
              boxShadow: isDark ? null : AppColors.softShadow,
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.qrcode_viewfinder,
                      size: 19, color: _azul),
                  const SizedBox(width: 9),
                  Text('Validar un carnet',
                      style: TextStyle(
                          color: AppColors.textPrimaryC(isDark),
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _abrirCarnetSalud() {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const CarnetSaludScreen()),
    );
  }

  void _abrirValidador() {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const CarnetValidadorScreen()),
    );
  }

  Widget _footer(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(CupertinoIcons.lock_fill,
            size: 12, color: AppColors.textTertiaryC(isDark)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Datos de tu cuenta COSSMIL · representación digital',
            textAlign: TextAlign.center,
            style: context.texts.labelSmall
                .copyWith(color: AppColors.textTertiaryC(isDark)),
          ),
        ),
      ],
    );
  }
}
