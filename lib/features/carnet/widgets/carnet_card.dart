import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../carnet_data.dart';
import 'holographic_card.dart';

/// Lienzo de referencia del carnet (proporción ID = 1.586). Las tarjetas se
/// dibujan a este tamaño fijo y se escalan con FittedBox desde afuera, para que
/// las letras queden siempre acomodadas en cualquier pantalla.
const double kCarnetRefW = 1010;
const double kCarnetRefH = kCarnetRefW / 1.586; // ≈ 637

// Paleta fiel al carnet físico.
const Color kCarnetAzulOsc = Color(0xFF0A3A6B);
const Color kCarnetAzul = Color(0xFF1668A8);
const Color kCarnetAzulClaro = Color(0xFF3E92D1);
const Color _amarillo = Color(0xFFF2C200);
const Color _labelAzul = Color(0xFF135C97);

Uint8List? _decodePhoto(String b64) {
  if (b64.isEmpty) return null;
  try {
    final clean = b64.contains(',') ? b64.split(',').last : b64;
    return base64Decode(clean.trim());
  } catch (_) {
    return null;
  }
}

/// Frente del carnet, dibujado en el lienzo fijo [kCarnetRefW]x[kCarnetRefH].
class CarnetCardFront extends StatelessWidget {
  final CarnetData data;
  const CarnetCardFront({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final d = data;
    final photo = _decodePhoto(d.photoBase64);

    return SizedBox(
      width: kCarnetRefW,
      height: kCarnetRefH,
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            // Banda azul con degradado + panal, base diagonal.
            Positioned(
              left: 0, right: 0, top: 0, height: kCarnetRefH * 0.50,
              child: ClipPath(
                clipper: _DiagonalClipper(),
                child: Stack(fit: StackFit.expand, children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kCarnetAzulOsc, kCarnetAzul, kCarnetAzulClaro],
                      ),
                    ),
                  ),
                  CustomPaint(
                      painter: HoneycombPainter(
                          color: Colors.white.withValues(alpha: 0.10),
                          radius: 27)),
                  // Aclarado al fondo de la banda (Matrícula/CI sobre él).
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(0, 0.15),
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00FFFFFF), Color(0xD0FFFFFF)],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            // Esquina amarilla.
            Positioned(
              left: 0, top: 0,
              child: CustomPaint(
                  size: const Size(150, 130), painter: _CornerPainter(_amarillo)),
            ),
            // Panal tenue sobre área blanca.
            Positioned(
              left: 0, right: 0, top: kCarnetRefH * 0.50, bottom: 0,
              child: CustomPaint(
                  painter: HoneycombPainter(
                      color: kCarnetAzulClaro.withValues(alpha: 0.09),
                      radius: 28)),
            ),

            // Logo.
            Positioned(
              left: 120, top: 26,
              child: Image.asset('assets/images/cossmil_logo.png',
                  width: 150, height: 150,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const Icon(
                      CupertinoIcons.shield_fill, size: 130, color: Colors.white)),
            ),
            // Título institucional.
            Positioned(
              left: 58, top: 182, width: 540,
              child: Text('CORPORACIÓN DEL\nSEGURO SOCIAL MILITAR',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 39,
                      height: 1.16,
                      letterSpacing: 0.4,
                      shadows: [
                        Shadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 4,
                            offset: const Offset(0, 1)),
                      ])),
            ),
            // Foto.
            Positioned(
              right: 40, top: 24,
              child: Container(
                width: 290, height: 260,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 6),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30), blurRadius: 8)
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: photo != null
                    ? Image.memory(photo,
                        fit: BoxFit.cover, filterQuality: FilterQuality.high)
                    : const Icon(CupertinoIcons.person_fill,
                        size: 120, color: Colors.grey),
              ),
            ),
            // Matrícula y CI: abajo-derecha de la banda, DEBAJO de la foto,
            // con los dos puntos alineados (como el carnet físico).
            // Matrícula arriba y CI debajo, alineado a la altura del nombre.
            Positioned(
              left: 430, top: 302,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bandRow('Matrícula', d.matricula),
                  const SizedBox(height: 6),
                  _bandRow('CI', d.ci),
                ],
              ),
            ),

            // Nombre completo: SOLO en el lado izquierdo, "Nombre Completo:" a
            // la misma altura que el CI.
            const Positioned(
              left: 55, top: 350,
              child: Text('Nombre Completo:',
                  style: TextStyle(
                      color: _labelAzul,
                      fontWeight: FontWeight.w700,
                      fontSize: 29,
                      letterSpacing: 0.2)),
            ),
            Positioned(
              left: 55, top: 388, width: 545,
              child: Text(d.nombreCompleto.toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFF111111),
                      fontWeight: FontWeight.w900,
                      fontSize: 46,
                      height: 1.04,
                      letterSpacing: -0.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),

            // Fila inferior 1.
            Positioned(
              left: 55, top: 500, width: 430,
              child: _frontField('Fuerza', d.fuerza, 178),
            ),
            Positioned(
              left: 498, top: 500, width: 478,
              child: _frontField('Matrícula Tit.', CarnetData.orDash(d.matriculaTitular), 245),
            ),
            // Fila inferior 2 — Fecha Nac. con etiqueta de ancho suficiente.
            Positioned(
              left: 55, top: 560, width: 430,
              child: _frontField('Fecha Nac.', d.fechaNacimiento, 178),
            ),
            Positioned(
              left: 498, top: 560, width: 478,
              child: _frontField('Estado Civil', CarnetData.orDash(d.estadoCivil), 245),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reverso del carnet, dibujado en el lienzo fijo.
class CarnetCardBack extends StatelessWidget {
  final CarnetData data;
  const CarnetCardBack({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final d = data;
    return SizedBox(
      width: kCarnetRefW,
      height: kCarnetRefH,
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                  painter: HoneycombPainter(
                      color: kCarnetAzulClaro.withValues(alpha: 0.08),
                      radius: 28)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 30, 48, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: ClipRect(
                      child: RichText(
                        textAlign: TextAlign.justify,
                        text: const TextSpan(
                          style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 18.5,
                              height: 1.26,
                              fontWeight: FontWeight.w600),
                          children: [
                            TextSpan(
                                text: 'LEY DE SEGURIDAD SOCIAL MILITAR: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 19.5,
                                    color: kCarnetAzulOsc)),
                            TextSpan(
                                text:
                                    'Art. 186 Inc. c) Las Prestaciones de Salud dejarán de otorgarse después de 6 meses del último aporte. '),
                            TextSpan(
                                text: 'REGLAMENTO DE PRESTACIONES DE SALUD: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 19.5,
                                    color: kCarnetAzulOsc)),
                            TextSpan(
                                text:
                                    'Art. 100° (Riesgo Extraordinario) Se considera riesgo extraordinario a la lesión orgánica o trastorno funcional producido por la acción súbita y violenta de una causa externa a las cuales se exponga el asegurado o beneficiario.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _kvFixed('Grupo sanguíneo', d.grupoSanguineo),
                              _kvFixed('Alergias', d.alergias),
                              _kvFixed('Telf. de referencia', d.telefonoReferencia),
                              _kvFixed('Fecha de emisión', d.fechaEmision),
                              _kvFixed('Fecha de vencimiento', d.fechaVencimiento),
                              _kvFixed('Atención', d.atencion),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              kvInline('Código', d.codigo,
                                  labelColor: Colors.black,
                                  valueColor: Colors.black,
                                  size: 28),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.white,
                                child: QrImageView(
                                  data: d.qrPayload,
                                  version: QrVersions.auto,
                                  size: 168,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo del frente (zona blanca): etiqueta azul de ancho fijo (para alinear
/// los dos puntos) + valor en negro.
Widget _frontField(String label, String value, double labelWidth) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: labelWidth,
        child: Text(label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: const TextStyle(
                color: _labelAzul, fontWeight: FontWeight.w700, fontSize: 31)),
      ),
      const Text(': ',
          style: TextStyle(
              color: _labelAzul, fontWeight: FontWeight.w700, fontSize: 31)),
      Flexible(
        child: Text(CarnetData.orDash(value),
            style: const TextStyle(
                color: Color(0xFF111111),
                fontWeight: FontWeight.w900,
                fontSize: 33),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}

/// Fila de la banda (Matrícula/CI): etiqueta oscura alineada a la derecha + " : "
/// + valor en negrita negra, con los dos puntos alineados entre filas.
Widget _bandRow(String label, String value) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 215,
        child: Text(label,
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: kCarnetAzulOsc, fontWeight: FontWeight.w700, fontSize: 32)),
      ),
      const Text(' :  ',
          style: TextStyle(
              color: kCarnetAzulOsc, fontWeight: FontWeight.w700, fontSize: 32)),
      Text(CarnetData.orDash(value),
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w900, fontSize: 34)),
    ],
  );
}

Widget kvInline(String label, String value,
    {required Color labelColor, required Color valueColor, required double size}) {
  return RichText(
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    text: TextSpan(children: [
      TextSpan(
          text: '$label : ',
          style: TextStyle(
              color: labelColor, fontWeight: FontWeight.w600, fontSize: size)),
      TextSpan(
          text: CarnetData.orDash(value),
          style: TextStyle(
              color: valueColor, fontWeight: FontWeight.w900, fontSize: size + 2)),
    ]),
  );
}

Widget _kvFixed(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 290,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 26)),
        ),
        const Text(': ',
            style: TextStyle(
                color: Colors.black, fontSize: 26, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(CarnetData.orDash(value),
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w900, fontSize: 28),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}

/// Recorte diagonal de la base de la banda azul (como el carnet real).
class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    // Banda más baja a la izquierda y más alta (extendida) a la derecha, como
    // el carnet físico (donde Matrícula/CI quedan dentro de la banda).
    return Path()
      ..lineTo(0, s.height * 0.82)
      ..lineTo(s.width, s.height)
      ..lineTo(s.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// Triángulo de la esquina superior izquierda (acento amarillo).
class _CornerPainter extends CustomPainter {
  final Color color;
  _CornerPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}
