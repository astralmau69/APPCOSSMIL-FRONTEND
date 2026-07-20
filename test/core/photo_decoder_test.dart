import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/utils/photo_decoder.dart';

void main() {
  group('decodeApiPhoto', () {
    // JPEG mínimo simulado: los magic bytes FF D8 FF.
    final jpegBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];
    final jpegB64 = base64Encode(jpegBytes);

    test('base64 estándar', () {
      expect(decodeApiPhoto(jpegB64), jpegBytes);
    });

    test('base64 con saltos de línea y padding faltante', () {
      final conRuido = '${jpegB64.substring(0, 4)}\n${jpegB64.substring(4)}'
          .replaceAll('=', '');
      expect(decodeApiPhoto(conRuido), jpegBytes);
    });

    test('Data URI (la coma del encabezado NO debe romper la foto)', () {
      expect(decodeApiPhoto('data:image/jpeg;base64,$jpegB64'), jpegBytes);
    });

    test('enteros con signo separados por coma (legacy)', () {
      // -1 → 255, -40 → 216 (complemento a 256)
      expect(decodeApiPhoto('-1,-40,-1,-32,0,16'), jpegBytes);
    });

    test('lista JSON de enteros', () {
      expect(decodeApiPhoto([-1, -40, -1, -32, 0, 16]), jpegBytes);
      expect(decodeApiPhoto([255, 216, 255, 224, 0, 16]), jpegBytes);
    });

    test('lista serializada con corchetes', () {
      expect(decodeApiPhoto('[255, 216, 255, 224, 0, 16]'), jpegBytes);
    });

    test('entradas vacías o nulas → null', () {
      expect(decodeApiPhoto(null), isNull);
      expect(decodeApiPhoto(''), isNull);
      expect(decodeApiPhoto('   '), isNull);
      expect(decodeApiPhoto(const []), isNull);
    });

    test('basura no decodificable → null sin lanzar', () {
      expect(decodeApiPhoto('esto no es una foto @@ ###'), isNull);
    });
  });
}
