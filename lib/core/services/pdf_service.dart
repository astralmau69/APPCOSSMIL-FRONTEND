import 'package:flutter/services.dart';
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
    required String especialidad,    required String establecimiento,
    required String consultorio,
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
    final darkColor = PdfColor.fromHex('#1C1C1E');
    final bgColor = PdfColor.fromHex('#F9FAFB');
    final borderColor = PdfColor.fromHex('#E5E7EB');
    final greyText = PdfColor.fromHex('#6B7280');

    final format = PdfPageFormat.roll80;
    
    // Load local logo image
    final ByteData bytes = await rootBundle.load('assets/images/logo_cossmil.png');
    final Uint8List imageBytes = bytes.buffer.asUint8List();
    final logoImage = pw.MemoryImage(imageBytes);

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Logo & Titulo Principal
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                   pw.Column(
                     crossAxisAlignment: pw.CrossAxisAlignment.start,
                     children: [
                        pw.Text(
                          'TICKET DE',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: oliveColor,
                          ),
                        ),
                        pw.Text(
                          'RESERVA',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: oliveColor,
                          ),
                        ),
                     ]
                   ),
                   // Logo real a la derecha
                   pw.Container(
                     height: 35,
                     child: pw.Image(logoImage),
                   )
                ]
              ),
              
              pw.SizedBox(height: 12),

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: bgColor,
                  border: pw.Border.all(color: borderColor, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'CÓDIGO',
                      style: pw.TextStyle(fontSize: 7, color: greyText),
                    ),
                    pw.Text(
                      codigoReserva,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: darkColor,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // 1. HOSPITAL
              _ticketRow('ESTABLECIMIENTO', establecimiento),
              
              // 2. CONSULTORIO
              _ticketRow('CONSULTORIO / UBICACIÓN', consultorio),
              
              // 3. FECHA Y HORA (Destacado)
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F3F4F6'),
                  border: pw.Border.all(color: oliveColor, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      fecha.toUpperCase(),
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      hora,
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: oliveColor),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // 4. ESPECIALIDAD
              _ticketRow('ESPECIALIDAD', especialidad),

              // 5. MÉDICO
              _ticketRow('MÉDICO ASIGNADO', medico),
              
              pw.Divider(color: borderColor, thickness: 0.5),
              pw.SizedBox(height: 4),

              // 7. DATOS DEL PACIENTE
              _ticketRow('PACIENTE', paciente),
              _ticketRow('MATRÍCULA', user.matricula),
              if (user.rank.isNotEmpty) _ticketRow('GRADO', user.rank),
              
              pw.Divider(color: borderColor, thickness: 0.5),
              pw.SizedBox(height: 4),
              
              // QR CODE simulado
              pw.Container(
                height: 60,
                width: 60,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: codigoReserva,
                  color: darkColor,
                ),
              ),

              pw.SizedBox(height: 12),
              pw.Text(
                'Presentarse 15 min antes de la hora indicada con carnet de identidad.',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 7, color: greyText),
              ),
              pw.SizedBox(height: 6),
              
              // ADVERTENCIA PENALIZACIÓN
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                   color: PdfColor.fromHex('#FEF2F2'),
                   border: pw.Border.all(color: PdfColor.fromHex('#FECACA'), width: 0.5),
                   borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                   'ADVERTENCIA: Si falta 3 veces a sus consultas reservadas por la app será penalizado y no podrá volver a reservar fichas.',
                   textAlign: pw.TextAlign.center,
                   style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#991B1B'), fontWeight: pw.FontWeight.bold),
                ),
              ),
              
              pw.SizedBox(height: 6),
              pw.Text(
                'Emitido el: $formattedDate',
                style: pw.TextStyle(fontSize: 6, color: greyText),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Ticket_COSSMIL_$codigoReserva',
    );
  }

  static pw.Widget _ticketRow(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      width: double.infinity,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#6B7280')),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
