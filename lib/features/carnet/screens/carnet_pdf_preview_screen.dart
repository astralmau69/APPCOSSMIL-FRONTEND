import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/services/screen_security_service.dart';
import '../widgets/carnet_card.dart' show kCarnetAzul, kCarnetAzulOsc;

/// Vista previa del PDF del carnet ANTES de imprimir/compartir, como una
/// ventana integrada a la estética de la app (no el visor genérico).
///
/// Se muestra dentro de la app (ventana con FLAG_SECURE activo desde el
/// CarnetScreen) y además refuerza el bloqueo, por lo que NO se pueden tomar
/// capturas ni grabar la pantalla mientras se previsualiza. El PDF lleva la
/// marca de agua "COSSMIL" cruzando el carnet para evitar falsificaciones.
class CarnetPdfPreviewScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const CarnetPdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  State<CarnetPdfPreviewScreen> createState() => _CarnetPdfPreviewScreenState();
}

class _CarnetPdfPreviewScreenState extends State<CarnetPdfPreviewScreen> {
  static const Color _azul = kCarnetAzul;
  static const Color _azulOsc = kCarnetAzulOsc;

  late final Future<List<Uint8List>> _pagesFuture;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    ScreenSecurityService.enable();
    _pagesFuture = _rasterize();
  }

  /// Rasteriza el PDF a imágenes para mostrarlo dentro de la app.
  Future<List<Uint8List>> _rasterize() async {
    final pages = <Uint8List>[];
    await for (final page in Printing.raster(widget.pdfBytes, dpi: 160)) {
      pages.add(await page.toPng());
    }
    return pages;
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await task();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo completar la acción.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _imprimir() => _run(() => Printing.layoutPdf(
        onLayout: (_) async => widget.pdfBytes,
        name: widget.fileName,
      ));

  Future<void> _compartir() => _run(() => Printing.sharePdf(
        bytes: widget.pdfBytes,
        filename: '${widget.fileName}.pdf',
      ));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFEDF4FB),
      body: SafeArea(
        child: Column(
          children: [
            _header(isDark, r),
            Expanded(child: _preview(isDark, r)),
            _actions(isDark, r),
          ],
        ),
      ),
    );
  }

  // ── Cabecera ──────────────────────────────────────────────────────────────
  Widget _header(bool isDark, AppResponsive r) {
    return Padding(
      padding: EdgeInsets.fromLTRB(r.spaceSm, r.spaceSm, r.paddingH, r.spaceSm),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.textTertiaryC(isDark)
                        .withValues(alpha: isDark ? 0.25 : 0.18)),
                boxShadow: isDark ? null : AppColors.softShadow,
              ),
              child: Icon(CupertinoIcons.back,
                  size: 20, color: AppColors.textPrimaryC(isDark)),
            ),
          ),
          SizedBox(width: r.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vista previa del carnet',
                    style: context.texts.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryC(isDark))),
                Text('Documento protegido · no se puede capturar',
                    style: context.texts.bodySmall.copyWith(
                        color: AppColors.textSecondaryC(isDark))),
              ],
            ),
          ),
          Icon(CupertinoIcons.lock_shield_fill, size: 20, color: _azul),
        ],
      ),
    );
  }

  // ── Previsualización (páginas rasterizadas) ───────────────────────────────
  Widget _preview(bool isDark, AppResponsive r) {
    return FutureBuilder<List<Uint8List>>(
      future: _pagesFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CupertinoActivityIndicator(radius: 14));
        }
        final pages = snap.data ?? const <Uint8List>[];
        if (pages.isEmpty) {
          return Center(
            child: Text('No se pudo generar la vista previa.',
                style: context.texts.bodyMedium
                    .copyWith(color: AppColors.textSecondaryC(isDark))),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              r.paddingH, r.spaceSm, r.paddingH, r.spaceLg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  for (final png in pages) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(png, fit: BoxFit.contain),
                    ),
                    SizedBox(height: r.spaceMd),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Acciones (Imprimir / Compartir) ───────────────────────────────────────
  Widget _actions(bool isDark, AppResponsive r) {
    return Container(
      padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceSm, r.paddingH,
          r.spaceMd + r.viewPaddingBottom),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: _working ? null : _imprimir,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_azulOsc, _azul]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _azul.withValues(alpha: 0.35),
                      blurRadius: 14,
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
                                size: 19, color: Colors.white),
                            SizedBox(width: 9),
                            Text('Imprimir',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                          ],
                        ),
                ),
              ),
            ),
          ),
          SizedBox(width: r.spaceSm),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _working ? null : _compartir,
              child: Container(
                height: 54,
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
          ),
        ],
      ),
    );
  }
}
