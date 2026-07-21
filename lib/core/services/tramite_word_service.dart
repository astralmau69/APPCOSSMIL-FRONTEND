import 'dart:convert';
import 'dart:typed_data';

import 'tramite_pdf_service.dart';

/// Genera los formularios oficiales de COSSMIL como documento Word (.doc).
///
/// Usa HTML con el vocabulario de Microsoft Office, que Word, WPS y
/// LibreOffice abren de forma nativa como documento editable — sin
/// dependencias adicionales. El contenido replica el del PDF de
/// [TramitePdfService]: se autocompletan nombre, CI y celular; el resto de
/// campos quedan con líneas de puntos para llenarse a mano.
class TramiteWordService {
  const TramiteWordService._();

  static const _esc = HtmlEscape();

  /// Tramo de puntos suspensivos (campo en blanco para llenar a mano).
  static String _fill([int n = 48]) => '<span class="dots">${'.' * n}</span>';

  static String _b(String s) => '<b>${_esc.convert(s)}</b>';

  /// Renglón subrayado a todo el ancho con altura para escribir a mano.
  /// La etiqueta va sobre la línea; el `padding-top` da el alto de escritura.
  static String _writeLine(String label, {double bottomPt = 14}) =>
      '<p class="wl" style="margin-bottom:${bottomPt}pt">${_esc.convert(label)}</p>';

  /// Espacio vertical en blanco.
  static String _gap([double pt = 12]) =>
      '<p style="margin:0;height:${pt}pt">&nbsp;</p>';

  // ── API pública ──────────────────────────────────────────────────────────

  static Uint8List build({
    required TramiteTipo tipo,
    required String nombre,
    required String ci,
    required String celular,
  }) {
    final n = _esc.convert(nombre.trim().toUpperCase());
    final c = _esc.convert(ci.trim());
    final cel = _esc.convert(celular.trim());

    final String body;
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

    final html =
        '''
<html xmlns:o="urn:schemas-microsoft-com:office:office"
      xmlns:w="urn:schemas-microsoft-com:office:word">
<head>
<meta charset="utf-8">
<!--[if gte mso 9]><xml><w:WordDocument><w:View>Print</w:View></w:WordDocument></xml><![endif]-->
<style>
  @page { size: 21cm 29.7cm; margin: 2.2cm 1.9cm; }
  body { font-family: 'Times New Roman', serif; font-size: 11pt;
         color: #1a1a1a; line-height: 1.45; }
  p { margin: 0 0 8pt 0; text-align: justify; }
  .l { text-align: left; } .c { text-align: center; } .r { text-align: right; }
  .dots { color: #9aa0a6; }
  .wl { text-align: left; border-bottom: 1px solid #888; padding-top: 12pt; }
  ul, ol { margin: 0 0 8pt 24pt; padding: 0; }
  li { margin-bottom: 3pt; text-align: justify; }
</style>
</head>
<body>
$body
</body>
</html>''';
    return Uint8List.fromList(utf8.encode(html));
  }

  /// Encabezado con la fecha "La Paz ..... de ..... de `año`" a la derecha.
  static String _fechaHeader() {
    final anio = DateTime.now().year;
    return '<p class="r" style="margin-bottom:14pt">La Paz ${_fill(6)} de '
        '${_fill(20)} de $anio</p>';
  }

  /// Bloque de firma: línea para firmar arriba y, debajo, directamente el
  /// nombre autocompletado (etiquetas genéricas solo como respaldo).
  static String _firma(String n, String c, String cel, {bool conCi = true}) {
    final buf = StringBuffer('<p class="c" style="margin-top:26pt">')
      ..write('<span class="dots">${'.' * 50}</span><br>');
    if (n.isNotEmpty) buf.write('$_boldOpen$n$_boldClose<br>');
    if (conCi && c.isNotEmpty) buf.write('${_boldOpen}C.I. $c$_boldClose<br>');
    if (n.isEmpty && (!conCi || c.isEmpty)) {
      buf.write(conCi
          ? 'NOMBRE COMPLETO, CEDULA DE IDENTIDAD Y<br>'
              'FIRMA DEL PACIENTE O SOLICITANTE<br>'
          : '${_boldOpen}FIRMA DEL PACIENTE o SOLICITANTE$_boldClose<br>');
    }
    buf.write('Cel. ${cel.isNotEmpty ? '$_boldOpen$cel$_boldClose' : _fill(16)}');
    buf.write('</p>');
    return buf.toString();
  }

  static const _boldOpen = '<b>';
  static const _boldClose = '</b>';

  // ── Documento 1: Formulario de Derivación (FMD) ──────────────────────────
  static String _cartaDerivacion(String n, String c, String cel) {
    final lineas = StringBuffer();
    for (var i = 0; i < 4; i++) {
      lineas.write(_writeLine('Especialidad y médico:', bottomPt: 18));
    }
    return '''
${_fechaHeader()}
<p style="margin-bottom:1pt">Sr. Tcnl. DIM. José Antonio Guerrero Flores</p>
<p style="margin-bottom:1pt">${_b('DIRECTOR GENERAL HOSPITAL MILITAR CENTRAL "COSSMIL"')}</p>
<p style="margin-bottom:14pt">Presente. -</p>
<p style="margin-bottom:12pt">Señor Teniente Coronel:</p>
<p style="margin-bottom:10pt">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Tengo
a bien dirigirme a Usted, a objeto de solicitar el llenado del
${_b('FORMULARIO MÉDICO DE DERIVACIÓN (FMD)')}, para iniciar el trámite en la
Gestora Pública de la Seguridad Social de Largo Plazo con las siguientes
especialidades:</p>
$lineas
<p style="margin-bottom:4pt">Para este fin adjunto documentación requerida:</p>
<ul>
  <li>Fotocopia de CI</li>
  <li>Fotocopia legible de certificado de nacimiento</li>
  <li>Fotocopia Carnet de seguro</li>
</ul>
${_firma(n, c, cel)}
''';
  }

  // ── Bloques comunes de las devoluciones ───────────────────────────────────
  static String _bloqueTerceros() {
    return '''
<ol>
  <li>${_b('COBROS EXCEPCIONALES: ')}PARA LA DEVOLUCION A TERCERAS PERSONAS
  (ESPOSA (O), HIJA(O), PADRE O MADRE DEL MENOR DE EDAD LLENE Y ADJUNTE:
    <ul>
      <li>Fotocopia de Carnet de identidad</li>
      <li>Fotocopia de carnet de asegurado de COSSMIL, de no contar con el
      seguro, adjuntar certificado de matrimonio para esposo (a) y/o
      certificado de nacimiento del hijo (a) o del paciente menor de edad.</li>
      <li>Cuenta del Banco Unión (Extracto Bancario, Comprobante de depósito,
      o Captura impresa de UNINET)</li>
    </ul>
    <p style="margin-top:6pt">${_b('DECLARACIÓN JURADA PARA DEVOLUCION A PARIENTES DEL PACIENTE')}</p>
    <p style="line-height:210%">Yo ${_fill(40)} con C.I. N° ${_fill(16)} en calidad de ${_fill(20)}
    ${_b(' DECLARO ')} ser la persona que erogó los gastos médicos solicitados,
    deslindando de toda responsabilidad administrativa y legal al HMC-COSSMIL
    que pudiera surgir posteriormente.</p>
  </li>
  <li>${_b('PARA DEVOLUCION A TRAVÉS DE DEPÓSITO BANCARIO SOLO A BANCO UNION LLENE AQUÍ:')}
    <p style="line-height:210%">Yo ${_fill(40)} en calidad de ${_fill(18)} ${_b(' AUTORIZO ')} a la
    U.A.F. del H.M.C. la devolución del gasto a través de depósito bancario al
    Banco Unión según Extracto Bancario, Comprobante de depósito, o UNINET
    adjunto.</p>
  </li>
</ol>
''';
  }

  static String _refLine(String refLabel) =>
      '<p class="c" style="margin-top:4pt">${_b(refLabel)} ${_fill(20)}</p>';

  // ── Documento 2: Devolución por Compra de Servicios ──────────────────────
  static String _devolucionServicios(String n, String c, String cel) {
    return '''
${_fechaHeader()}
<p style="margin-bottom:1pt">Sr. Sof. 2do. DEPSS. Franklin Luis Quispe Yujra</p>
<p style="margin-bottom:1pt">${_b('JEFE DE LA UNIDAD ADMINISTRATIVA FINANCIERA')}</p>
<p style="margin-bottom:1pt">${_b('HOSPITAL MILITAR CENTRAL  "COSSMIL"')}</p>
<p style="margin-bottom:14pt">Presente. -</p>
<p style="margin-bottom:12pt">Señor Suboficial:</p>
<p style="margin-bottom:6pt">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Tengo
a bien dirigirme a Usted, a objeto de solicitar la
${_b('DEVOLUCION POR COMPRA DE SERVICIOS MEDICOS EXTERNOS DE: ')}${_fill(20)}</p>
${n.isNotEmpty ? '<p class="l" style="margin-bottom:8pt">Nombre el paciente: $_boldOpen$n$_boldClose</p>' : _writeLine('Nombre el paciente:')}
${c.isNotEmpty ? '<p class="l" style="margin-bottom:8pt">C.I. N°: $_boldOpen$c$_boldClose</p>' : _writeLine('C.I. N°:')}
${_writeLine('Monto total en Bs:')}
${_writeLine('N° de Factura:', bottomPt: 16)}
<p style="margin-bottom:4pt">Para este fin adjunto documentación requerida:</p>
<ol>
  <li>Factura Original</li>
  <li>Fotocopia simple de la Factura</li>
  <li>Fotocopia LEGALIZADA de la factura (por el médico o clínica) para montos
  igual o mayor a Bs 2.500.-</li>
  <li>Fotocopia de resultados del estudio y/o informe médico realizado</li>
  <li>Original o fotocopia del Formulario de Compra de Servicios (del estudio
  realizado)</li>
  <li>Fotocopia de carnet de Identidad del paciente y de asegurado de COSSMIL
  del paciente biometrizado y vigente</li>
  <li>Cuenta del Banco Unión (Extracto Bancario, Comprobante de depósito, o
  Captura impresa de UNINET)</li>
</ol>
${_bloqueTerceros()}
${_gap(20)}
${_firma(n, '', cel, conCi: false)}
${_refLine('Otro celular de Referencia para la Devolución:')}
''';
  }

  // ── Documento 3: Devolución de Medicamentos sin stock ────────────────────
  static String _devolucionMedicamentos(String n, String c, String cel) {
    return '''
${_fechaHeader()}
<p style="margin-bottom:1pt">Sr. Sof. 2do. DEPSS. Franklin Luis Quispe Yujra</p>
<p style="margin-bottom:1pt">${_b('JEFE DE LA UNIDAD ADMINISTRATIVA FINANCIERA  - H.M.C. "COSSMIL')}</p>
<p style="margin-bottom:14pt">Presente. -</p>
<p style="margin-bottom:12pt">Señor Suboficial:</p>
<p style="margin-bottom:6pt">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Tengo
a bien dirigirme a Usted, a objeto de
${_b('SOLICITAR LA DEVOLUCION DE GASTOS POR COMPRA DE MEDICAMENTOS SIN STOCK EN FARMACIA H.M.C. ')}
según detalle:</p>
${n.isNotEmpty ? '<p class="l" style="margin-bottom:8pt">Nombre el paciente: $_boldOpen$n$_boldClose</p>' : _writeLine('Nombre el paciente:')}
${c.isNotEmpty ? '<p class="l" style="margin-bottom:8pt">C.I. N°: $_boldOpen$c$_boldClose</p>' : _writeLine('C.I. N°:')}
${_writeLine('Monto total en Bs:')}
${_writeLine('N° de Factura:', bottomPt: 16)}
<p style="margin-bottom:4pt">Para este fin adjunto documentación requerida:</p>
<ol>
  <li>Factura Original sellada por Serv. Médicos</li>
  <li>Receta emita en COSSMIL original con sello SIN STOCK de Farmacia y
  sellada por Jefatura de Servicios Médicos (Dirección Médica).</li>
  <li>Fotocopia de la Factura</li>
  <li>Fotocopia de carnet de Identidad del paciente (vigente)</li>
  <li>Fotocopia de carnet de asegurado de COSSMIL del paciente biometrizado y
  vigente</li>
  <li>Cuenta del Banco Unión (Extracto Bancario, Comprobante de depósito, o
  Captura impresa de UNINET)</li>
</ol>
${_bloqueTerceros()}
${_gap(20)}
${_firma(n, '', cel, conCi: false)}
${_refLine('Otro Telf. De Referencia :')}
''';
  }
}
