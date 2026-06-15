import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'carnet_data.dart';

/// Genera el PDF del carnet de asegurado COSSMIL: una hoja oficial con header
/// de logos + el carnet (frente y reverso) como copia fiel, listo para
/// imprimir o compartir.
class CarnetPdf {
  static const PdfColor _azulOsc = PdfColor.fromInt(0xFF0A3A6B);
  static const PdfColor _azul = PdfColor.fromInt(0xFF1668A8);
  static const PdfColor _azulClaro = PdfColor.fromInt(0xFF3E92D1);
  static const PdfColor _amarillo = PdfColor.fromInt(0xFFF2C200);
  static const PdfColor _gris = PdfColor.fromInt(0xFF555555);
  static const PdfColor _label = PdfColor.fromInt(0xFF135C97);

  static Future<Uint8List> build(CarnetData d) async {
    final doc = pw.Document();

    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/images/cossmil_logo.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    pw.MemoryImage? foto;
    if (d.photoBase64.isNotEmpty) {
      try {
        foto = pw.MemoryImage(base64Decode(
            d.photoBase64.contains(',') ? d.photoBase64.split(',').last : d.photoBase64));
      } catch (_) {}
    }

    final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(logo, d, ahora),
              pw.SizedBox(height: 22),
              pw.Center(
                child: pw.Text('CARNET DE ASEGURADO',
                    style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: _azulOsc,
                        letterSpacing: 1)),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Container(width: 120, height: 2, color: _amarillo),
              ),
              pw.SizedBox(height: 26),
              // Carnet (frente + reverso) centrado, tamaño tarjeta ampliado.
              pw.Center(child: _frente(d, logo, foto)),
              pw.SizedBox(height: 22),
              pw.Center(child: _reverso(d)),
              pw.Spacer(),
              pw.Container(height: 0.6, color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Text(
                'NOTA: La presente imagen es una representación del carnet de asegurado en formato físico. '
                'Generado desde la aplicación móvil COSSMIL el $ahora.',
                style: pw.TextStyle(fontSize: 7.5, color: _gris),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // ── Header de la hoja ───────────────────────────────────────────────────
  static pw.Widget _header(pw.MemoryImage? logo, CarnetData d, String ahora) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(colors: [_azulOsc, _azul, _azulClaro]),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.Container(
              width: 46,
              height: 46,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                shape: pw.BoxShape.circle,
              ),
              padding: const pw.EdgeInsets.all(3),
              child: pw.Image(logo),
            ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('CORPORACIÓN DEL SEGURO SOCIAL MILITAR',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('Estado Plurinacional de Bolivia',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 8)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _tag('App Móvil', 'COSSMIL'),
              _tag('Matrícula', d.matricula),
              _tag('Fecha impr.', ahora),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _tag(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(
                text: '$k: ',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 7)),
            pw.TextSpan(
                text: v,
                style: pw.TextStyle(
                    color: PdfColors.white, fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      );

  // ── Frente del carnet ───────────────────────────────────────────────────
  static pw.Widget _frente(
      CarnetData d, pw.MemoryImage? logo, pw.MemoryImage? foto) {
    const w = 360.0;
    const h = w / 1.586;
    return pw.Container(
      width: w,
      height: h,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _azul, width: 1),
        boxShadow: [
          pw.BoxShadow(color: PdfColors.grey400, blurRadius: 3, offset: const PdfPoint(0, 2)),
        ],
      ),
      child: pw.Stack(
        children: [
          // Banda azul superior.
          pw.Positioned(
            left: 0, top: 0, right: 0,
            child: pw.Container(
              height: h * 0.50,
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                    colors: [_azulOsc, _azul, _azulClaro],
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight),
                borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(10), topRight: pw.Radius.circular(10)),
              ),
            ),
          ),
          // Logo + título.
          pw.Positioned(
            left: 12, top: 10,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Container(width: 34, height: 34, child: pw.Image(logo)),
                pw.SizedBox(width: 8),
                pw.Text('CORPORACIÓN DEL\nSEGURO SOCIAL MILITAR',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          // Foto.
          pw.Positioned(
            right: 14, top: 10,
            child: pw.Container(
              width: w * 0.27,
              height: h * 0.42,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                border: pw.Border.all(color: PdfColors.white, width: 2),
              ),
              child: foto != null
                  ? pw.Image(foto, fit: pw.BoxFit.cover)
                  : pw.SizedBox(),
            ),
          ),
          // Matrícula y CI: abajo-derecha de la banda, debajo de la foto.
          pw.Positioned(
            right: 14, top: h * 0.40,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _kv('Matrícula', d.matricula, PdfColors.white, PdfColors.white),
                _kv('CI', d.ci, PdfColors.white, PdfColors.white),
              ],
            ),
          ),
          // Datos inferiores.
          pw.Positioned(
            left: 12, top: h * 0.55, right: 12,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Nombre Completo:',
                    style: pw.TextStyle(color: _label, fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                pw.Text(d.nombreCompleto.toUpperCase(),
                    style: pw.TextStyle(
                        color: PdfColors.black, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Row(children: [
                  pw.Expanded(child: _kv('Fuerza', d.fuerza, _label, PdfColors.black)),
                  pw.Expanded(child: _kv('Matrícula Tit.', CarnetData.orDash(d.matriculaTitular), _label, PdfColors.black)),
                ]),
                pw.Row(children: [
                  pw.Expanded(child: _kv('Fecha Nac.', d.fechaNacimiento, _label, PdfColors.black)),
                  pw.Expanded(child: _kv('Estado Civil', CarnetData.orDash(d.estadoCivil), _label, PdfColors.black)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Reverso del carnet ──────────────────────────────────────────────────
  static pw.Widget _reverso(CarnetData d) {
    const w = 360.0;
    const h = w / 1.586;
    return pw.Container(
      width: w,
      height: h,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _azul, width: 1),
        boxShadow: [
          pw.BoxShadow(color: PdfColors.grey400, blurRadius: 3, offset: const PdfPoint(0, 2)),
        ],
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            textAlign: pw.TextAlign.justify,
            text: pw.TextSpan(
              style: pw.TextStyle(fontSize: 6.5, color: PdfColors.black, lineSpacing: 1.5),
              children: [
                pw.TextSpan(
                    text: 'LEY DE SEGURIDAD SOCIAL MILITAR: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                const pw.TextSpan(
                    text: 'Art. 186 Inc. c) Las Prestaciones de Salud dejarán de otorgarse después de 6 meses del último aporte. '),
                pw.TextSpan(
                    text: 'REGLAMENTO DE PRESTACIONES DE SALUD: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                const pw.TextSpan(
                    text: 'Art. 100° (Riesgo Extraordinario) Se considera riesgo extraordinario a la lesión orgánica o trastorno funcional producido por la acción súbita y violenta de una causa externa a las cuales se exponga el asegurado o beneficiario.'),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _kv('Grupo sanguíneo', d.grupoSanguineo, PdfColors.black, PdfColors.black),
                      _kv('Alergias', d.alergias, PdfColors.black, PdfColors.black),
                      _kv('Telf. de referencia', d.telefonoReferencia, PdfColors.black, PdfColors.black),
                      _kv('Fecha de emisión', d.fechaEmision, PdfColors.black, PdfColors.black),
                      _kv('Fecha de vencimiento', d.fechaVencimiento, PdfColors.black, PdfColors.black),
                      _kv('Atención', d.atencion, PdfColors.black, PdfColors.black),
                    ],
                  ),
                ),
                pw.Column(
                  children: [
                    _kv('Código', d.codigo, PdfColors.black, PdfColors.black),
                    pw.SizedBox(height: 6),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: d.qrPayload,
                      width: 70,
                      height: 70,
                      drawText: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _kv(String k, String v, PdfColor lc, PdfColor vc) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(
              text: '$k : ',
              style: pw.TextStyle(color: lc, fontSize: 7.5)),
          pw.TextSpan(
              text: CarnetData.orDash(v),
              style: pw.TextStyle(color: vc, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        ]),
      ),
    );
  }
}
