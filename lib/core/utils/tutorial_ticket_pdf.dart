import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Genera el "ticket" de ejemplo para el paso final del tutorial de sacar
/// una ficha — construido 100% en el dispositivo (jamás llama al backend),
/// con una marca de agua "DEMOSTRACIÓN" en toda la hoja para que nunca se
/// confunda con el comprobante real de una cita médica.
class TutorialTicketPdf {
  static const PdfColor _accent = PdfColor.fromInt(0xFF059669);
  static const PdfColor _accentBg = PdfColor.fromInt(0xFFECFDF5);
  static const PdfColor _label = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _text = PdfColor.fromInt(0xFF191C1E);
  static const PdfColor _divider = PdfColor.fromInt(0xFFE5E7EB);

  static Future<Uint8List> build({
    required String hospital,
    required String especialidad,
    required String medico,
    required String consultorio,
    required String paciente,
    required String fecha,
    required String hora,
    required int ficha,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          buildForeground: (_) => _watermark(),
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                'COSSMIL',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _accent,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'COMPROBANTE DE CITA MÉDICA · DEMOSTRACIÓN',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: _label,
                  letterSpacing: 1,
                ),
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _accentBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _accent, width: 0.8),
              ),
              child: pw.Text(
                'Este es un documento de ejemplo generado por el tutorial. '
                'No corresponde a una cita médica real.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _accent,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 24),
            _row('Hospital', hospital),
            _divide(),
            _row('Especialidad', especialidad),
            _divide(),
            _row('Médico', medico),
            _divide(),
            _row('Consultorio', consultorio),
            _divide(),
            _row('Paciente', paciente),
            _divide(),
            _row('Fecha', fecha),
            _divide(),
            _row('Hora', hora),
            pw.SizedBox(height: 28),
            pw.Center(
              child: pw.Text(
                'N° DE FICHA (EJEMPLO)',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _label,
                  letterSpacing: 1,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                '$ficha',
                style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                  color: _text,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 10,
              color: _label,
              letterSpacing: 0.5,
            ),
          ),
          pw.Text(
            value.isEmpty ? '—' : value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _divide() => pw.Container(height: 0.6, color: _divider);

  static pw.Widget _watermark() {
    final pageW = PdfPageFormat.a4.width;
    final pageH = PdfPageFormat.a4.height;
    final angle = math.atan2(pageH, pageW);
    final diag = math.sqrt(pageW * pageW + pageH * pageH);
    final line = List.filled(3, 'DEMOSTRACIÓN').join('   ');

    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Opacity(
        opacity: 0.10,
        child: pw.Center(
          child: pw.Transform.rotate(
            angle: angle,
            child: pw.SizedBox(
              width: diag * 1.15,
              height: diag * 1.1,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: List.generate(
                  12,
                  (_) => pw.Text(
                    line,
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: _accent,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
