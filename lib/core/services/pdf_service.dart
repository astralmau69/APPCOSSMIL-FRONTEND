import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';

/// Genera y muestra el PDF de confirmación de reserva.
class PdfService {
  static Future<void> generateAndShowBookingPdf({
    required UserModel user,
    required String paciente,
    required String especialidad,
    required String establecimiento,
    required String ciudad,
    required String medico,
    required String fecha,
    required String hora,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(now);
    final codigoReserva =
        'RES-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(7)}';

    final oliveColor = PdfColor.fromHex('#6B6830');
    final greyColor = PdfColor.fromHex('#8E8E93');
    final darkColor = PdfColor.fromHex('#1C1C1E');
    final bgColor = PdfColor.fromHex('#F8F8F5');
    final borderColor = PdfColor.fromHex('#E5E5EA');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: oliveColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'COSSMIL',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Corporación del Seguro Social Militar',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColor.fromHex('#D4D2B8'),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // ── Título ────────────────────────────────────────
              pw.Center(
                child: pw.Text(
                  'COMPROBANTE DE RESERVA MÉDICA',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: darkColor,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Container(
                  width: 60,
                  height: 2,
                  color: oliveColor,
                ),
              ),
              pw.SizedBox(height: 20),

              // ── Código y fecha ────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: bgColor,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Código de Reserva',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: greyColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          codigoReserva,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: oliveColor,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Fecha de emisión',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: greyColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          formattedDate,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: darkColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // ── Datos del paciente ────────────────────────────
              _sectionTitle('DATOS DEL PACIENTE', oliveColor),
              pw.SizedBox(height: 8),
              _infoTable([
                ['Nombre Completo', paciente],
                ['Matrícula', user.matricula],
                ['Grado', '${user.rank} ${user.role}'],
                ['Grupo Sanguíneo', user.bloodType],
              ], darkColor, greyColor, borderColor),
              pw.SizedBox(height: 20),

              // ── Datos de la cita ──────────────────────────────
              _sectionTitle('DATOS DE LA CITA', oliveColor),
              pw.SizedBox(height: 8),
              _infoTable([
                ['Especialidad', especialidad],
                ['Establecimiento', '$establecimiento — $ciudad'],
                ['Médico', medico],
                ['Fecha', fecha],
                ['Hora', hora],
              ], darkColor, greyColor, borderColor),
              pw.SizedBox(height: 30),

              // ── Nota ──────────────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FFF9E6'),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(
                      color: PdfColor.fromHex('#E6D9A3')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'IMPORTANTE',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#8B7D2E'),
                        letterSpacing: 1,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '• Presentar este comprobante el día de la cita.\n'
                      '• Llegar 15 minutos antes de la hora programada.\n'
                      '• Traer su carnet de identidad y carnet militar vigente.\n'
                      '• En caso de no poder asistir, cancelar con 24h de anticipación.',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColor.fromHex('#5C5020'),
                        lineSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // ── Footer ────────────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(top: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: borderColor, width: 0.5),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'COSSMIL — Sistema de Citas Médicas',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: greyColor,
                      ),
                    ),
                    pw.Text(
                      'FLOWV1.',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: greyColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Reserva_COSSMIL_$codigoReserva',
    );
  }

  static pw.Widget _sectionTitle(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: color, width: 1.5),
        ),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  static pw.Widget _infoTable(
    List<List<String>> rows,
    PdfColor darkColor,
    PdfColor greyColor,
    PdfColor borderColor,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
      children: rows.map((row) {
        return pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: pw.Text(
                row[0],
                style: pw.TextStyle(
                  fontSize: 10,
                  color: greyColor,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: pw.Text(
                row[1],
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: darkColor,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
