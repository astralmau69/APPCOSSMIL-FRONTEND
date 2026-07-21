import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';

/// Vista previa genérica de un PDF con acciones de Imprimir, Descargar y
/// Compartir.
///
/// Integrada a la estética de la app: rasteriza el PDF a imágenes y las
/// muestra como hojas sobre un fondo suave, con una barra de acciones fija.
/// Si se provee [wordBytes], "Descargar" ofrece elegir entre PDF y Word.
/// A diferencia del visor del carnet, aquí NO se activa el bloqueo de captura
/// (estos son formularios que el asegurado debe poder guardar/compartir).
class DocumentPreviewScreen extends StatefulWidget {
  final Uint8List pdfBytes;

  /// Versión Word (.doc) del mismo documento; opcional.
  final Uint8List? wordBytes;
  final String fileName;
  final String title;
  final String subtitle;

  const DocumentPreviewScreen({
    super.key,
    required this.pdfBytes,
    this.wordBytes,
    required this.fileName,
    required this.title,
    this.subtitle = 'Revisa el documento antes de imprimir o compartir',
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  static const Color _verde = Color(0xFF059669);
  static const Color _verdeOsc = Color(0xFF047857);

  late final Future<List<Uint8List>> _pagesFuture;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _pagesFuture = _rasterize();
  }

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

  /// Pregunta el formato (PDF o Word) y guarda/abre el archivo.
  Future<void> _descargar() async {
    final String? formato;
    if (widget.wordBytes == null) {
      formato = 'pdf';
    } else {
      formato = await showCupertinoModalPopup<String>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Descargar documento'),
          message: const Text('Elige el formato del archivo'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'pdf'),
              child: const Text('PDF (.pdf)'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'doc'),
              child: const Text('Word (.doc)'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ),
      );
    }
    if (formato == null) return;
    final ext = formato;
    final bytes = ext == 'pdf' ? widget.pdfBytes : widget.wordBytes!;

    await _run(() async {
      if (kIsWeb) {
        // En web, compartir dispara la descarga del navegador.
        await Printing.sharePdf(bytes: bytes, filename: '${widget.fileName}.$ext');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${widget.fileName}.$ext');
      await file.writeAsBytes(bytes, flush: true);
      final res = await OpenFile.open(file.path);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.type == ResultType.noAppToOpen
              ? 'Documento guardado, pero no hay una app para abrir .$ext.'
              : 'Documento guardado en: ${file.path}'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFEDF4F0),
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
                Text(widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryC(isDark))),
                Text(widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall.copyWith(
                        color: AppColors.textSecondaryC(isDark))),
              ],
            ),
          ),
          const Icon(CupertinoIcons.doc_text_fill, size: 20, color: _verde),
        ],
      ),
    );
  }

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
          padding:
              EdgeInsets.fromLTRB(r.paddingH, r.spaceSm, r.paddingH, r.spaceLg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  for (final png in pages) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
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

  Widget _actions(bool isDark, AppResponsive r) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          r.paddingH, r.spaceSm, r.paddingH, r.spaceMd + r.viewPaddingBottom),
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
                  gradient: const LinearGradient(colors: [_verdeOsc, _verde]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _verde.withValues(alpha: 0.35),
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
            flex: 3,
            child: GestureDetector(
              onTap: _working ? null : _descargar,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : _verde.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _verde.withValues(alpha: 0.25)),
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.arrow_down_circle_fill,
                          size: 19, color: _verde),
                      SizedBox(width: 8),
                      Text('Descargar',
                          style: TextStyle(
                              color: _verde,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: r.spaceSm),
          GestureDetector(
            onTap: _working ? null : _compartir,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : _verde.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _verde.withValues(alpha: 0.25)),
              ),
              child: const Center(
                child: Icon(CupertinoIcons.share, size: 19, color: _verde),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
