import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../carnet_data.dart';

/// Validador de carnet COSSMIL: escanea el QR rotativo del "Carnet Digital de
/// Seguro" y muestra en texto si el carnet está VIGENTE.
///
/// La validación es local: recalcula el hash de la ventana de 15 s y confirma
/// que coincide con el del QR (tolerando ±1 ventana por desfase de reloj).
class CarnetValidadorScreen extends StatefulWidget {
  const CarnetValidadorScreen({super.key});

  @override
  State<CarnetValidadorScreen> createState() => _CarnetValidadorScreenState();
}

class _CarnetValidadorScreenState extends State<CarnetValidadorScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _handled = false;
  bool? _valid; // null = escaneando, true/false = resultado
  // Datos de identidad que venían en el QR (nombre, grado, tipo), para mostrarlos
  // en la pantalla de resultado cuando el carnet es válido.
  RotatingValidation? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      await _controller.start();
    } catch (_) {
      // Permiso denegado o cámara no disponible: MobileScanner muestra el error.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_valid == null) _startCamera();
    } else {
      _controller.stop();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      // Solo procesar QR de carnet COSSMIL.
      final lower = raw.toLowerCase();
      if (!lower.contains('cossmil') && !lower.contains('mat=')) continue;

      final res = CarnetData.validateRotating(raw);
      if (res == null) continue; // QR sin datos de carnet COSSMIL legibles.
      _handled = true;
      _controller.stop();
      if (mounted) {
        setState(() {
          _result = res;
          _valid = res.valid;
        });
      }
      return;
    }
  }

  void _reset() {
    _handled = false;
    setState(() {
      _valid = null;
      _result = null;
    });
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Con resultado: pantalla COMPLETA (no una tarjeta pegada al borde inferior).
    if (_valid != null) return _buildResult(context, _valid == true);
    return _buildScanner(context);
  }

  // ── Escáner (cámara) ──────────────────────────────────────────────────────
  Widget _buildScanner(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Cámara a pantalla completa (Positioned.fill para que ocupe todo;
          // en un Stack los hijos sin posicionar no reciben tamaño completo).
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              fit: BoxFit.cover,
            ),
          ),

          // Marco guía de escaneo.
          const Positioned.fill(child: _ScanFrame()),

          // Cabecera.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  _circleBtn(
                    CupertinoIcons.back,
                    () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Validador de carnet',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instrucción inferior.
          Align(alignment: Alignment.bottomCenter, child: _hint()),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _hint() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          24, 18, 24, 24 + MediaQuery.of(context).viewPadding.bottom),
      child: const Text(
        'Apunte al código QR del carnet para validar su vigencia.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
        ),
      ),
    );
  }

  // ── Resultado (pantalla completa) ─────────────────────────────────────────
  Widget _buildResult(BuildContext context, bool ok) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = ok ? const Color(0xFF1E8E3E) : const Color(0xFFC62828);
    final r = context.r;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF5F8FC),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.paddingH),
          child: Column(
            children: [
              // Barra superior con botón para volver al carnet.
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: IconButton(
                    icon: Icon(CupertinoIcons.back,
                        color: AppColors.textPrimaryC(isDark)),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),

              // Contenido centrado a pantalla completa.
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          ok
                              ? CupertinoIcons.checkmark_seal_fill
                              : CupertinoIcons.xmark_seal_fill,
                          color: color,
                          size: 76,
                        ),
                      ),
                      SizedBox(height: r.spaceLg),
                      Text(
                        ok ? 'CARNET VIGENTE' : 'CARNET NO VÁLIDO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 32,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: r.spaceSm),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          ok
                              ? 'El código QR es auténtico y el carnet está vigente.'
                              : 'El código no es válido o el QR ya expiró. Pida que se regenere e intente de nuevo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondaryC(isDark),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                      // Identidad del titular del carnet (cuando es válido y el
                      // QR trajo los datos).
                      if (ok && _result != null) ...[
                        SizedBox(height: r.spaceLg),
                        _identityCard(isDark, _result!),
                      ],
                    ],
                  ),
                ),
              ),

              // Acciones inferiores.
              GestureDetector(
                onTap: _reset,
                child: Container(
                  height: 54,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.qrcode_viewfinder,
                            color: Colors.white, size: 20),
                        SizedBox(width: 9),
                        Text(
                          'Escanear otro carnet',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: r.spaceSm),
              CupertinoButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(
                  'Volver al carnet',
                  style: TextStyle(
                    color: AppColors.textSecondaryC(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: r.spaceMd),
            ],
          ),
        ),
      ),
    );
  }

  // Tarjeta con los datos del titular leídos del QR (nombre, grado, tipo) y la
  // foto. La foto NO viaja en el QR, así que se muestra un ícono; cuando exista
  // el backend de verificación se reemplazará por la foto real del asegurado.
  Widget _identityCard(bool isDark, RotatingValidation res) {
    final hasName = res.nombre.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.textTertiaryC(isDark).withValues(alpha: 0.2),
        ),
        boxShadow: isDark ? null : AppColors.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Foto (placeholder por ahora: el QR no la transporta).
          Container(
            width: 76,
            height: 92,
            decoration: BoxDecoration(
              color: const Color(0xFFEDF1F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD7DEE8)),
            ),
            child: const Icon(
              CupertinoIcons.person_fill,
              size: 40,
              color: Color(0xFFB0BAC8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasName ? res.nombre.toUpperCase() : 'NOMBRE NO DISPONIBLE',
                  style: TextStyle(
                    color: AppColors.textPrimaryC(isDark),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                _idRow(isDark, 'Grado', CarnetData.orDash(res.grado)),
                const SizedBox(height: 4),
                _idRow(isDark, 'Tipo', CarnetData.orDash(res.tipo)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _idRow(bool isDark, String label, String value) {
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: AppColors.textSecondaryC(isDark),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: AppColors.textPrimaryC(isDark),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Marco cuadrado guía centrado para el escaneo.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.of(context).size.width * 0.68;
    return Center(
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
