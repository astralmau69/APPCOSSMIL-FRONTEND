import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

/// Tipos de trámite/formulario disponibles en "Procedimientos COSSMIL".
enum TramiteTipo {
  /// Carta de solicitud de llenado del Formulario Médico de Derivación (FMD).
  cartaDerivacion,

  /// Solicitud de devolución por compra de servicios médicos externos.
  devolucionServicios,

  /// Solicitud de devolución de gastos por compra de medicamentos sin stock.
  devolucionMedicamentos,
}

/// Genera los formularios oficiales de COSSMIL como PDF.
///
/// El contenido reproduce fielmente los documentos oficiales; lo único que
/// se autocompleta son el **nombre**, la **cédula de identidad** y el
/// **celular** del paciente/solicitante. El resto de campos (monto, N° de
/// factura, fechas, firmas) se imprimen en blanco con líneas de puntos para
/// llenarse a mano tras la impresión.
class TramitePdfService {
  const TramitePdfService._();

  // ── Estilos base ─────────────────────────────────────────────────────────
  static const double _fs = 10;
  static final PdfColor _ink = PdfColor.fromHex('#1A1A1A');
  static final PdfColor _dot = PdfColor.fromHex('#9AA0A6');

  static pw.TextStyle get _base =>
      pw.TextStyle(fontSize: _fs, color: _ink, height: 1.42);
  static pw.TextStyle get _bold => _base.copyWith(fontWeight: pw.FontWeight.bold);

  static pw.TextSpan _t(String s) => pw.TextSpan(text: s, style: _base);
  static pw.TextSpan _b(String s) => pw.TextSpan(text: s, style: _bold);

  /// Tramo de puntos suspensivos (campo en blanco para llenar a mano).
  static pw.TextSpan _fill([int n = 48]) => pw.TextSpan(
        text: '.' * n,
        style: _base.copyWith(color: _dot),
      );

  /// Valor autocompletado, resaltado en negrita.
  static pw.TextSpan _val(String s) => _b(s);

  /// Renglón subrayado a todo el ancho, con altura para escribir cómodamente a
  /// mano. Opcionalmente lleva una etiqueta a la izquierda.
  static pw.Widget _writeLine({String? label, double bottom = 14}) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: bottom),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (label != null) pw.Text(label, style: _base),
          pw.Expanded(
            child: pw.Container(
              height: 16,
              margin: const pw.EdgeInsets.only(left: 4),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(width: 0.7, color: PdfColors.grey500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Espacio vertical en blanco.
  static pw.Widget _gap([double h = 10]) => pw.SizedBox(height: h);

  static pw.Widget _p(List<pw.TextSpan> spans,
      {pw.TextAlign align = pw.TextAlign.justify, double bottom = 7}) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: bottom),
      child: pw.RichText(
        textAlign: align,
        text: pw.TextSpan(style: _base, children: spans),
      ),
    );
  }

  /// Ítem de lista con viñeta o numeración manual.
  static pw.Widget _li(String marker, List<pw.TextSpan> spans,
      {double bottom = 3}) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: bottom, left: 14),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 20,
            child: pw.Text(marker, style: _base),
          ),
          pw.Expanded(
            child: pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(style: _base, children: spans),
            ),
          ),
        ],
      ),
    );
  }

  /// Encabezado con la fecha "La Paz ..... de ..... de 2026" alineada a la derecha.
  static pw.Widget _fechaHeader() {
    final anio = DateTime.now().year;
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(bottom: 22),
      child: pw.RichText(
        text: pw.TextSpan(style: _base, children: [
          _t('La Paz '),
          _fill(8),
          _t(' de '),
          _fill(24),
          _t(' de $anio'),
        ]),
      ),
    );
  }

  // ── API pública ──────────────────────────────────────────────────────────

  static Future<Uint8List> build({
    required TramiteTipo tipo,
    required String nombre,
    required String ci,
    required String celular,
  }) async {
    final doc = pw.Document();
    final n = nombre.trim().toUpperCase();
    final c = ci.trim();
    final cel = celular.trim();

    final List<pw.Widget> body;
    switch (tipo) {
      case TramiteTipo.cartaDerivacion:
        body = _cartaDerivacion(n, c, cel);
        break;
      case TramiteTipo.devolucionServicios:
        body = _devolucionServicios(n, c, cel);
        break;
      case TramiteTipo.devolucionMedicamentos:
        body = _devolucionMedicamentos(n, c, cel);
        break;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 54),
        build: (context) => body,
      ),
    );
    return doc.save();
  }

  // ── Documento 1: Carta de Derivación (FMD) ───────────────────────────────
  static List<pw.Widget> _cartaDerivacion(String n, String c, String cel) {
    return [
      _fechaHeader(),
      _p([_t('Sr. Tcnl. DIM. José Antonio Guerrero Flores')], bottom: 1),
      _p([_b('DIRECTOR GENERAL HOSPITAL MILITAR CENTRAL "COSSMIL"')],
          bottom: 1),
      _p([_t('Presente. -')], bottom: 16),
      _p([_t('Señor Teniente Coronel:')], bottom: 14),
      _p([
        _t('        Tengo a bien dirigirme a Usted, a objeto de solicitar el '
            'llenado del '),
        _b('FORMULARIO MÉDICO DE DERIVACIÓN (FMD)'),
        _t(', para iniciar el trámite en la Gestora Pública de la Seguridad '
            'Social de Largo Plazo con las siguientes especialidades:'),
      ], bottom: 12),
      // Renglones subrayados amplios para escribir a mano la especialidad y el
      // médico de cada derivación (más espacio de escritura).
      for (int i = 0; i < 4; i++) _writeLine(label: 'Especialidad y médico:', bottom: 18),
      _gap(6),
      _p([_t('Para este fin adjunto documentación requerida:')], bottom: 5),
      _li('·', [_t('Fotocopia de CI')]),
      _li('·', [_t('Fotocopia legible de certificado de nacimiento')]),
      _li('·', [_t('Fotocopia Carnet de seguro')], bottom: 48),

      // Bloque de firma: línea para firmar arriba y, debajo, directamente el
      // nombre y CI autocompletados (las etiquetas genéricas solo aparecen
      // como respaldo cuando no hay datos).
      pw.Center(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('.' * 52, style: _base.copyWith(color: _dot)),
            if (n.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(n, style: _bold.copyWith(fontSize: 11)),
              ),
            if (c.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text('C.I. $c', style: _bold),
              ),
            if (n.isEmpty && c.isEmpty) ...[
              pw.Text('NOMBRE COMPLETO, CEDULA DE IDENTIDAD Y',
                  style: _base, textAlign: pw.TextAlign.center),
              pw.Text('FIRMA DEL PACIENTE O SOLICITANTE',
                  style: _base, textAlign: pw.TextAlign.center),
            ],
            pw.SizedBox(height: 6),
            pw.RichText(
              text: pw.TextSpan(style: _base, children: [
                _t('Cel. '),
                cel.isNotEmpty ? _val(cel) : _fill(16),
              ]),
            ),
          ],
        ),
      ),
    ];
  }

  // ── Bloques comunes de las devoluciones (terceros + depósito + firma) ─────
  static List<pw.Widget> _bloqueTerceros() {
    return [
      _li('1.', [
        _b('COBROS EXCEPCIONALES: '),
        _t('PARA LA DEVOLUCION A TERCERAS PERSONAS (ESPOSA (O), HIJA(O), PADRE '
            'O MADRE DEL MENOR DE EDAD LLENE Y ADJUNTE:'),
      ], bottom: 5),
      _li('·', [_t('Fotocopia de Carnet de identidad')]),
      _li('·', [
        _t('Fotocopia de carnet de asegurado de COSSMIL, de no contar con el '
            'seguro, adjuntar certificado de matrimonio para esposo (a) y/o '
            'certificado de nacimiento del hijo (a) o del paciente menor de edad.'),
      ]),
      _li('·', [
        _t('Cuenta del Banco Unión (Extracto Bancario, Comprobante de depósito, '
            'o Captura impresa de UNINET)'),
      ], bottom: 10),
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 14, bottom: 4),
        child: pw.Text('DECLARACIÓN JURADA PARA DEVOLUCION A PARIENTES DEL PACIENTE',
            style: _bold),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 14, bottom: 8),
        child: pw.RichText(
          textAlign: pw.TextAlign.justify,
          text: pw.TextSpan(
              style: _base.copyWith(height: 2.1),
              children: [
                _t('Yo '),
                _fill(40),
                _t(' con C.I. N° '),
                _fill(16),
                _t(' en calidad de '),
                _fill(20),
                _b(' DECLARO '),
                _t('ser la persona que erogó los gastos médicos solicitados, '
                    'deslindando de toda responsabilidad administrativa y legal al '
                    'HMC-COSSMIL que pudiera surgir posteriormente.'),
              ]),
        ),
      ),
      _gap(6),
      _li('2.', [
        _b('PARA DEVOLUCION A TRAVÉS DE DEPÓSITO BANCARIO SOLO A BANCO UNION '
            'LLENE AQUÍ:'),
      ], bottom: 6),
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 14, bottom: 26),
        child: pw.RichText(
          textAlign: pw.TextAlign.justify,
          text: pw.TextSpan(
              style: _base.copyWith(height: 2.1),
              children: [
                _t('Yo '),
                _fill(40),
                _t(' en calidad de '),
                _fill(18),
                _b(' AUTORIZO '),
                _t('a la U.A.F. del H.M.C. la devolución del gasto a través de '
                    'depósito bancario al Banco Unión según Extracto Bancario, '
                    'Comprobante de depósito, o UNINET adjunto.'),
              ]),
        ),
      ),
    ];
  }

  static pw.Widget _firmaSolicitante(String n, String cel,
      {String refLabel = 'Otro celular de Referencia para la Devolución:'}) {
    // Bajo la línea de firma va directamente el nombre autocompletado, sin la
    // etiqueta "Nombre del solicitante" adelante; la etiqueta genérica solo se
    // imprime como respaldo cuando no hay nombre.
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text('.' * 46, style: _base.copyWith(color: _dot)),
              if (n.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(n, style: _bold.copyWith(fontSize: 11)),
                )
              else
                pw.Text('FIRMA DEL PACIENTE o SOLICITANTE', style: _bold),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        pw.RichText(
          text: pw.TextSpan(style: _base, children: [
            _b('Cel. '),
            cel.isNotEmpty ? _val(cel) : _fill(18),
          ]),
        ),
        pw.SizedBox(height: 12),
        pw.RichText(
          text: pw.TextSpan(style: _base, children: [
            _b('$refLabel '),
            _fill(24),
          ]),
        ),
      ],
    );
  }

  // ── Documento 2: Devolución por Compra de Servicios ──────────────────────
  static List<pw.Widget> _devolucionServicios(String n, String c, String cel) {
    return [
      _fechaHeader(),
      _p([_t('Sr. Sof. 2do. DEPSS. Franklin Luis Quispe Yujra')], bottom: 1),
      _p([_b('JEFE DE LA UNIDAD ADMINISTRATIVA FINANCIERA')], bottom: 1),
      _p([_b('HOSPITAL MILITAR CENTRAL  "COSSMIL"')], bottom: 1),
      _p([_t('Presente. -')], bottom: 14),
      _p([_t('Señor Suboficial:')], bottom: 12),
      _p([
        _t('        Tengo a bien dirigirme a Usted, a objeto de solicitar la '),
        _b('DEVOLUCION POR COMPRA DE SERVICIOS MEDICOS EXTERNOS DE: '),
        _fill(20),
      ], bottom: 6),
      n.isNotEmpty
          ? _p([_t('Nombre el paciente: '), _val(n)],
              align: pw.TextAlign.left, bottom: 8)
          : _writeLine(label: 'Nombre el paciente:', bottom: 14),
      c.isNotEmpty
          ? _p([_t('C.I. N°: '), _val(c)], align: pw.TextAlign.left, bottom: 8)
          : _writeLine(label: 'C.I. N°:', bottom: 14),
      _writeLine(label: 'Monto total en Bs:', bottom: 14),
      _writeLine(label: 'N° de Factura:', bottom: 16),
      _p([_t('Para este fin adjunto documentación requerida:')], bottom: 5),
      _li('1.', [_t('Factura Original')]),
      _li('2.', [_t('Fotocopia simple de la Factura')]),
      _li('3.', [
        _t('Fotocopia LEGALIZADA de la factura (por el médico o clínica) para '
            'montos igual o mayor a Bs 2.500.-'),
      ]),
      _li('4.', [_t('Fotocopia de resultados del estudio y/o informe médico realizado')]),
      _li('5.', [
        _t('Original o fotocopia del Formulario de Compra de Servicios (del '
            'estudio realizado)'),
      ]),
      _li('6.', [
        _t('Fotocopia de carnet de Identidad del paciente y de asegurado de '
            'COSSMIL del paciente biometrizado y vigente'),
      ]),
      _li('7.', [
        _t('Cuenta del Banco Unión (Extracto Bancario, Comprobante de depósito, '
            'o Captura impresa de UNINET)'),
      ], bottom: 14),
      ..._bloqueTerceros(),
      _gap(30),
      _firmaSolicitante(n, cel),
    ];
  }

  // ── Documento 3: Devolución de Medicamentos sin stock ────────────────────
  static List<pw.Widget> _devolucionMedicamentos(String n, String c, String cel) {
    return [
      _fechaHeader(),
      _p([_t('Sr. Sof. 2do. DEPSS. Franklin Luis Quispe Yujra')], bottom: 1),
      _p([_b('JEFE DE LA UNIDAD ADMINISTRATIVA FINANCIERA  - H.M.C. "COSSMIL')],
          bottom: 1),
      _p([_t('Presente. -')], bottom: 14),
      _p([_t('Señor Suboficial:')], bottom: 12),
      _p([
        _t('        Tengo a bien dirigirme a Usted, a objeto de '),
        _b('SOLICITAR LA DEVOLUCION DE GASTOS POR COMPRA DE MEDICAMENTOS SIN '
            'STOCK EN FARMACIA H.M.C. '),
        _t('según detalle:'),
      ], bottom: 6),
      n.isNotEmpty
          ? _p([_t('Nombre el paciente: '), _val(n)],
              align: pw.TextAlign.left, bottom: 8)
          : _writeLine(label: 'Nombre el paciente:', bottom: 14),
      c.isNotEmpty
          ? _p([_t('C.I. N°: '), _val(c)], align: pw.TextAlign.left, bottom: 8)
          : _writeLine(label: 'C.I. N°:', bottom: 14),
      _writeLine(label: 'Monto total en Bs:', bottom: 14),
      _writeLine(label: 'N° de Factura:', bottom: 16),
      _p([_t('Para este fin adjunto documentación requerida:')], bottom: 5),
      _li('1.', [_t('Factura Original sellada por Serv. Médicos')]),
      _li('2.', [
        _t('Receta emita en COSSMIL original con sello SIN STOCK de Farmacia y '
            'sellada por Jefatura de Servicios Médicos (Dirección Médica).'),
      ]),
      _li('3.', [_t('Fotocopia de la Factura')]),
      _li('4.', [_t('Fotocopia de carnet de Identidad del paciente (vigente)')]),
      _li('5.', [
        _t('Fotocopia de carnet de asegurado de COSSMIL del paciente '
            'biometrizado y vigente'),
      ]),
      _li('6.', [
        _t('Cuenta del Banco Unión (Extracto Bancario, Comprobante de depósito, '
            'o Captura impresa de UNINET)'),
      ], bottom: 14),
      ..._bloqueTerceros(),
      _gap(30),
      _firmaSolicitante(n, cel,
          refLabel: 'Otro Telf. De Referencia :'),
    ];
  }
}
