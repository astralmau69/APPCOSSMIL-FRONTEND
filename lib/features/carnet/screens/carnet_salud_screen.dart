import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/services/screen_security_service.dart';
import '../../../core/session/user_session.dart';
import '../carnet_data.dart';

/// Carnet de Seguro de Salud (vista oficial vertical), réplica fiel del diseño
/// institucional pero integrada a la estética de la app: fondo temático,
/// cabecera con botón circular y tarjeta contenida y centrada (no ocupa toda
/// la pantalla). Escala de forma proporcional en cualquier tamaño de equipo.
///
/// El QR es fijo por ahora ([CarnetData.fixedHealthQrPayload]); se reemplazará
/// luego por el servicio de verificación que lo actualice periódicamente.
class CarnetSaludScreen extends StatefulWidget {
  const CarnetSaludScreen({super.key});

  @override
  State<CarnetSaludScreen> createState() => _CarnetSaludScreenState();
}

class _CarnetSaludScreenState extends State<CarnetSaludScreen>
    with SingleTickerProviderStateMixin {
  // Paleta oficial de la tarjeta (fiel al diseño físico).
  static const Color _navy = Color(0xFF0A2A4E);
  static const Color _navyDark = Color(0xFF071E38);
  static const Color _ink = Color(0xFF0C2D52);
  static const Color _green = Color(0xFF1E8E3E);
  static const Color _label = Color(0xFF7B8AA0);

  // Holograma: barrido diagonal (izq → der) que se repite cada 5 segundos.
  late final AnimationController _holoCtrl;

  // Datos del carnet y QR rotativo (hash que cambia cada 15 s).
  late final CarnetData _data;
  // Notificadores aislados: solo el QR y el contador se reconstruyen, no toda
  // la tarjeta (evita que la foto parpadee al refrescar el QR cada segundo).
  late final ValueNotifier<String> _qrNotifier;
  late final ValueNotifier<int> _secondsNotifier;
  Timer? _qrTimer;

  @override
  void initState() {
    super.initState();
    // Refuerza el bloqueo de capturas/grabación en esta pantalla (el carnet ya
    // lo activa a nivel de ventana). No se desactiva al salir: lo gestiona el
    // CarnetScreen al abandonar todo el apartado.
    ScreenSecurityService.enable();
    // El barrido arranca en didChangeDependencies: ahí ya se puede consultar
    // reduce-motion, y un bucle infinito a 60 fps es justo lo que no debe
    // correr en una pantalla que el usuario deja abierta en el mostrador.
    _holoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    );

    _data = CarnetData.fromUser(UserSession.currentUser);
    _qrNotifier = ValueNotifier<String>(_data.rotatingQrPayload());
    _secondsNotifier = ValueNotifier<int>(CarnetData.secondsToNextWindow());
    // Cada segundo: actualiza el contador y regenera el QR cuando cambia la
    // ventana de 15 s. El ValueNotifier del QR solo notifica si el hash cambió,
    // por lo que el QR únicamente se redibuja cada 15 s (sin parpadeos).
    _qrTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _qrNotifier.value = _data.rotatingQrPayload();
      _secondsNotifier.value = CarnetData.secondsToNextWindow();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con reduce-motion el holograma se queda quieto a mitad del barrido: la
    // tarjeta conserva su textura de seguridad, pero nada se mueve.
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_holoCtrl.isAnimating) _holoCtrl.stop();
      _holoCtrl.value = 0.5;
    } else if (!_holoCtrl.isAnimating) {
      _holoCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    _qrNotifier.dispose();
    _secondsNotifier.dispose();
    _holoCtrl.dispose();
    super.dispose();
  }

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
          Positioned.fill(child: _backdrop(isDark)),
          SafeArea(
            child: Column(
              children: [
                _header(context, isDark, r),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      // La tarjeta se dibuja a un ancho de referencia (360) y se
                      // escala con FittedBox para que SIEMPRE quepa completa en
                      // pantalla (ancho y alto) sin necesidad de desplazar.
                      final pad = r.spaceMd;
                      // La barra de navegación flotante del shell se superpone
                      // a esta pantalla: se le descuenta su alto para que la
                      // tarjeta quede centrada en el espacio realmente visible.
                      final navSpace = r.navBarBottomSpace;
                      // En una ventana ancha sobra alto, así que la tarjeta
                      // puede crecer un poco más antes de que el FittedBox la
                      // limite: en un monitor, 440 px la dejaban pequeña en
                      // medio de la pantalla. En teléfono el tope no cambia.
                      final maxCard = c.maxWidth >= 900 ? 520.0 : 440.0;
                      final w = (c.maxWidth - pad * 2).clamp(0.0, maxCard);
                      final h = (c.maxHeight - pad * 2 - navSpace).clamp(
                        0.0,
                        double.infinity,
                      );
                      return Padding(
                        padding: EdgeInsets.only(bottom: navSpace),
                        child: Center(
                          child: SizedBox(
                            width: w,
                            height: h,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              child: SizedBox(width: 360, child: _card(d)),
                            ),
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

  // ── Fondo (igual que el carnet principal) ─────────────────────────────────
  Widget _backdrop(bool isDark) {
    if (isDark) {
      return const AppBackground(isDark: true, child: SizedBox.expand());
    }
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3EFFA), Color(0xFFF5F8FC)],
        ),
      ),
    );
  }

  // ── Cabecera de la app (botón circular + título) ──────────────────────────
  Widget _header(BuildContext context, bool isDark, AppResponsive r) {
    return Padding(
      padding: EdgeInsets.fromLTRB(r.spaceSm, r.spaceSm, r.paddingH, r.spaceSm),
      child: Row(
        children: [
          _circleButton(
            context,
            icon: CupertinoIcons.back,
            isDark: isDark,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          SizedBox(width: r.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carnet Digital de Seguro',
                  style: context.texts.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
                Text(
                  'Verificación en línea',
                  style: context.texts.bodySmall.copyWith(
                    color: AppColors.textSecondaryC(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(
    BuildContext context, {
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.textTertiaryC(
              isDark,
            ).withValues(alpha: isDark ? 0.25 : 0.18),
          ),
          boxShadow: isDark ? null : AppColors.softShadow,
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimaryC(isDark)),
      ),
    );
  }

  // ── Tarjeta (banner navy + cuerpo blanco), contenida y con sombra ──────────
  // Se dibuja a tamaño de referencia (sc=1); el FittedBox externo la escala para
  // que quepa completa en cualquier dispositivo.
  Widget _card(CarnetData d) {
    const double sc = 1.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22 * sc),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Holograma de seguridad DETRÁS del contenido: se pinta sobre el fondo
          // blanco pero por debajo de textos/foto/QR (opacos), así NO tapa ningún
          // dato del carnet; solo se ve en los espacios libres. Barre en diagonal
          // y no intercepta toques (RepaintBoundary aísla el repintado).
          Positioned.fill(
            child: IgnorePointer(child: RepaintBoundary(child: _hologram())),
          ),
          Column(
            children: [
              _banner(sc),
              Padding(
                padding: EdgeInsets.all(16 * sc),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _brand(sc),
                    SizedBox(height: 16 * sc),
                    _photoAndIdentity(d, sc),
                    SizedBox(height: 14 * sc),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    SizedBox(height: 14 * sc),
                    _detailsAndQr(d, sc),
                    SizedBox(height: 16 * sc),
                    _useNotice(sc),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Holograma de seguridad ────────────────────────────────────────────────
  // Letras grandes "COSSMIL" en diagonal (esquina inferior izquierda → superior
  // derecha) que cruzan toda la tarjeta, con el logo tenue de fondo y un brillo
  // tornasol que barre lentamente sobre las letras. [t] ∈ [0,1] es el avance del
  // ciclo (la duración del controlador define la velocidad).
  /// Patrón repetido de "COSSMIL" que cubre toda la tarjeta. Se arma una sola
  /// vez para toda la app: antes se reconstruían las dos listas y sus `join`
  /// en cada frame del barrido.
  static final String _watermarkBlock = List.filled(
    12,
    List.filled(6, 'COSSMIL').join('   '),
  ).join('\n');

  /// Base tenue (plata azulada) para que las letras se noten sobre el blanco
  /// aun cuando el brillo no esté encima.
  static const Color _holoBase = Color(0x1C8FA0BC);

  static const List<Color> _holoColors = [
    _holoBase,
    _holoBase,
    Color(0x8CFF2D9B),
    Color(0xA600E0FF),
    Color(0x8C49FF8B),
    _holoBase,
    _holoBase,
  ];

  /// Paradas del degradado para el avance [t] del barrido. Es lo ÚNICO que
  /// cambia por frame; todo lo demás (logo, texto rotado, layout) se construye
  /// una vez y se reutiliza como hijo cacheado del AnimatedBuilder.
  static List<double> _holoStops(double t) {
    // Centro del brillo tornasol, de la esquina inferior-izquierda a la
    // superior-derecha. Al llegar arriba el controlador reinicia (repeat) y la
    // banda vuelve a entrar por abajo, sin pausa marcada en los extremos.
    final cen = t * 1.2 - 0.1; // -0.1 → 1.1
    const hw = 0.17;
    double cl(double v) => v.clamp(0.0, 1.0);
    final stops = <double>[
      0.0,
      cl(cen - hw),
      cl(cen - hw * 0.5),
      cl(cen),
      cl(cen + hw * 0.5),
      cl(cen + hw),
      1.0,
    ];
    for (var i = 1; i < stops.length; i++) {
      if (stops[i] < stops[i - 1]) stops[i] = stops[i - 1];
    }
    return stops;
  }

  Widget _hologram() {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        // Orientación diagonal: inferior-izquierda → superior-derecha.
        final angle = math.atan2(-h, w);

        // El texto se mide y rota UNA vez por tamaño de tarjeta. Es un bloque
        // de 12 líneas a fontSize ≈ w*0.16: rehacer su layout en cada frame
        // era el verdadero coste del barrido.
        final Widget letras = OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.rotate(
            angle: angle,
            child: Text(
              _watermarkBlock,
              textAlign: TextAlign.center,
              softWrap: false,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: w * 0.16,
                height: 1.7,
                letterSpacing: w * 0.012,
              ),
            ),
          ),
        );

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1) Logo de fondo grande y muy tenue, centrado (fuera del
              //    barrido: no lo tiñe el tornasol).
              Center(
                child: Opacity(
                  opacity: 0.05,
                  child: Image.asset(
                    'assets/images/cossmil_logo.png',
                    width: w * 0.62,
                    height: w * 0.62,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              // 2) Patrón "COSSMIL" en diagonal con el brillo tornasol que lo
              //    barre. Solo se rehace el shader; las letras van de hijo
              //    cacheado y no se vuelven a medir.
              AnimatedBuilder(
                animation: _holoCtrl,
                child: letras,
                builder: (context, child) => ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: _holoColors,
                    stops: _holoStops(_holoCtrl.value),
                  ).createShader(rect),
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Banner superior "CARNET DIGITAL / SEGURO DE SALUD".
  Widget _banner(double sc) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 14 * sc),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_navyDark, _navy],
        ),
      ),
      child: Column(
        children: [
          Text(
            'CARNET DIGITAL',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20 * sc,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 2 * sc),
          Text(
            'SEGURO DE SALUD',
            style: TextStyle(
              color: const Color(0xFFB9C9DD),
              fontWeight: FontWeight.w600,
              fontSize: 11 * sc,
              letterSpacing: 2.5,
            ),
          ),
          SizedBox(height: 2 * sc),
          Text(
            'MINISTERIO DE DEFENSA',
            style: TextStyle(
              color: const Color(0xFFB9C9DD),
              fontWeight: FontWeight.w600,
              fontSize: 11 * sc,
              letterSpacing: 2.5,
            ),
          ),
        ],
      ),
    );
  }

  // Logo + título institucional + insignia "CARNET VIGENTE".
  Widget _brand(double sc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/cossmil_logo.png',
          width: 54 * sc,
          height: 54 * sc,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) =>
              Icon(CupertinoIcons.shield_fill, size: 46 * sc, color: _navy),
        ),
        SizedBox(width: 11 * sc),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CORPORACIÓN DEL\nSEGURO SOCIAL MILITAR',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5 * sc,
                  height: 1.2,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 2 * sc),
              Text(
                'COSSMIL',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 25 * sc,
                  height: 1.05,
                ),
              ),
              Text(
                'BOLIVIA',
                style: TextStyle(
                  color: _label,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5 * sc,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 6 * sc),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(
              CupertinoIcons.checkmark_shield_fill,
              color: _green,
              size: 25 * sc,
            ),
            SizedBox(height: 3 * sc),
            Text(
              'CARNET',
              style: TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
                fontSize: 11 * sc,
              ),
            ),
            Text(
              'VIGENTE',
              style: TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
                fontSize: 11 * sc,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Foto + datos de identidad.
  Widget _photoAndIdentity(CarnetData d, double sc) {
    final photo = _decodePhoto(d.photoBase64);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 104 * sc,
          height: 128 * sc,
          decoration: BoxDecoration(
            color: const Color(0xFFEDF1F5),
            borderRadius: BorderRadius.circular(10 * sc),
            border: Border.all(color: const Color(0xFFD7DEE8)),
          ),
          clipBehavior: Clip.antiAlias,
          child: photo != null
              ? Image.memory(
                  photo,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                )
              : Icon(
                  CupertinoIcons.person_fill,
                  size: 54 * sc,
                  color: const Color(0xFFB0BAC8),
                ),
        ),
        SizedBox(width: 13 * sc),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(
                'NOMBRE COMPLETO',
                d.nombreCompleto.toUpperCase(),
                sc,
                valueSize: 16.5,
                valueColor: _ink,
                maxLines: 2,
              ),
              SizedBox(height: 9 * sc),
              _field(
                'FECHA DE NACIMIENTO',
                CarnetData.orDash(d.fechaNacimiento),
                sc,
                valueSize: 14,
              ),
              SizedBox(height: 9 * sc),
              _field(
                'MATRÍCULA DEL ASEGURADO',
                CarnetData.orDash(d.matricula),
                sc,
                valueSize: 17.5,
                valueColor: _green,
              ),
              SizedBox(height: 9 * sc),
              _field(
                'TIPO DE ASEGURADO',
                CarnetData.orDash(d.tipoAsegurado),
                sc,
                valueSize: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Columna de detalles + QR y leyenda de verificación.
  Widget _detailsAndQr(CarnetData d, double sc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconRow(
                CupertinoIcons.calendar,
                'FECHA DE EMISIÓN',
                CarnetData.orDash(d.fechaEmision),
                sc,
              ),
              _iconRow(
                CupertinoIcons.calendar,
                'FECHA DE VENCIMIENTO',
                CarnetData.orDash(d.fechaVencimiento),
                sc,
                valueColor: _green,
              ),
              _iconRow(
                CupertinoIcons.chevron_up_circle_fill,
                'GRADO',
                CarnetData.orDash(d.grado),
                sc,
              ),
              _iconRow(
                CupertinoIcons.person_fill,
                'FUERZA',
                CarnetData.orDash(d.fuerza),
                sc,
              ),
              _iconRow(
                CupertinoIcons.creditcard_fill,
                'N° DE CARNET (BOLIVIA)',
                CarnetData.orDash(d.ci),
                sc,
              ),
            ],
          ),
        ),
        SizedBox(width: 10 * sc),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(7 * sc),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12 * sc),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ValueListenableBuilder<String>(
                  valueListenable: _qrNotifier,
                  builder: (_, data, __) => QrImageView(
                    data: data,
                    version: QrVersions.auto,
                    size: 122 * sc,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              SizedBox(height: 6 * sc),
              // Contador del QR rotativo (se renueva cada 15 s).
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.arrow_2_circlepath,
                    color: _green,
                    size: 12 * sc,
                  ),
                  SizedBox(width: 4 * sc),
                  ValueListenableBuilder<int>(
                    valueListenable: _secondsNotifier,
                    builder: (_, s, __) => Text(
                      'Cambia en ${s}s',
                      style: TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w700,
                        fontSize: 10 * sc,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 7 * sc),
              Row(
                children: [
                  Icon(
                    CupertinoIcons.checkmark_shield_fill,
                    color: _navy,
                    size: 15 * sc,
                  ),
                  SizedBox(width: 5 * sc),
                  Expanded(
                    child: Text(
                      'VERIFICACIÓN EN LÍNEA',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5 * sc,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 3 * sc),
              // Una sola idea: qué hacer con el QR. Que se renueva cada 15 s ya
              // lo dice el contador de arriba, y decirlo dos veces resta.
              Text(
                'Escanéalo con el validador COSSMIL para comprobar que el carnet está vigente.',
                style: TextStyle(
                  color: _label,
                  fontSize: 10.5 * sc,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Leyenda verde de uso personal e intransferible.
  Widget _useNotice(double sc) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(13 * sc),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6EE),
        borderRadius: BorderRadius.circular(14 * sc),
        border: Border.all(color: const Color(0xFFCBE8D5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.plus_app_fill, color: _green, size: 26 * sc),
          SizedBox(width: 11 * sc),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'USO PERSONAL E INTRANSFERIBLE',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5 * sc,
                  ),
                ),
                SizedBox(height: 3 * sc),
                Text(
                  'Este carnet acredita su condición de asegurado del Seguro de Salud de la COSSMIL.',
                  style: TextStyle(
                    color: const Color(0xFF3F5670),
                    fontSize: 12 * sc,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers de campos ─────────────────────────────────────────────────────
  Widget _field(
    String label,
    String value,
    double sc, {
    double valueSize = 14,
    Color valueColor = _ink,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _label,
            fontWeight: FontWeight.w600,
            fontSize: 10 * sc,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 2 * sc),
        Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w800,
            fontSize: valueSize * sc,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _iconRow(
    IconData icon,
    String label,
    String value,
    double sc, {
    Color valueColor = _ink,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 11 * sc),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _navy, size: 18 * sc),
          SizedBox(width: 8 * sc),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _label,
                    fontWeight: FontWeight.w600,
                    fontSize: 9.5 * sc,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 1 * sc),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5 * sc,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Uint8List? _decodePhoto(String b64) {
    if (b64.isEmpty) return null;
    try {
      final clean = b64.contains(',') ? b64.split(',').last : b64;
      return base64Decode(clean.trim());
    } catch (_) {
      return null;
    }
  }
}
