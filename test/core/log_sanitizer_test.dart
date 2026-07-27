import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/utils/log_sanitizer.dart';

void main() {
  group('LogSanitizer.scrub', () {
    test('enmascara Bearer token', () {
      final out = LogSanitizer.scrub(
        'Authorization: Bearer abc123.DEF-456_ghi==',
      );
      expect(out, contains('Bearer ***'));
      expect(out, isNot(contains('abc123')));
    });

    test('enmascara JWT suelto (eyJ...)', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTYifQ.SflKxwRJSMeKKF2QT4';
      final out = LogSanitizer.scrub('token=$jwt guardado');
      expect(out, isNot(contains('eyJhbGci')));
      expect(out, contains('***'));
    });

    test('enmascara Basic auth', () {
      final out = LogSanitizer.scrub(
        'Authorization: Basic Y2xpZW50OnNlY3JldA==',
      );
      expect(out, contains('Basic ***'));
      expect(out, isNot(contains('Y2xpZW50')));
    });

    test('enmascara password en JSON', () {
      final out = LogSanitizer.scrub('{"user":"juan","password":"S3cr3t!"}');
      expect(out, contains('"password":"***"'));
      expect(out, isNot(contains('S3cr3t')));
      expect(out, contains('"user":"juan"')); // no sensible → intacto
    });

    test('enmascara access_token y refresh_token en JSON', () {
      final out = LogSanitizer.scrub(
        '{"access_token":"aaa.bbb.ccc","refresh_token":"r-e-f-r-e-s-h"}',
      );
      expect(out, contains('"access_token":"***"'));
      expect(out, contains('"refresh_token":"***"'));
      expect(out, isNot(contains('r-e-f-r-e-s-h')));
    });

    test('enmascara CI/cédula/nrodoc en JSON', () {
      final out = LogSanitizer.scrub(
        '{"ci":"1234567","cedula":"7654321 LP","nrodoc":"9999999"}',
      );
      expect(out, contains('"ci":"***"'));
      expect(out, contains('"cedula":"***"'));
      expect(out, contains('"nrodoc":"***"'));
      expect(out, isNot(contains('1234567')));
      expect(out, isNot(contains('7654321')));
    });

    test('NO enmascara "ciudad" (falso positivo de "ci")', () {
      final out = LogSanitizer.scrub('{"ciudad":"La Paz","idsuc":1}');
      expect(out, contains('"ciudad":"La Paz"'));
      expect(out, contains('idsuc'));
    });

    test('enmascara password en form-urlencoded / query', () {
      final out = LogSanitizer.scrub(
        'grant_type=refresh_token&refresh_token=abc123&password=hunter2',
      );
      expect(out, contains('refresh_token=***'));
      expect(out, contains('password=***'));
      expect(out, isNot(contains('abc123')));
      expect(out, isNot(contains('hunter2')));
      // grant_type no es sensible: se conserva su valor.
      expect(out, contains('grant_type=refresh_token'));
    });

    test('NO enmascara datos no sensibles (números de ticket, ids)', () {
      const safe = 'Regionales: 5, idsuc: 1, ticket #987654, fecha 2026-07-23';
      expect(LogSanitizer.scrub(safe), equals(safe));
    });

    test('null → cadena vacía', () {
      expect(LogSanitizer.scrub(null), equals(''));
    });

    test('es idempotente (aplicar dos veces no cambia el resultado)', () {
      const raw = '{"password":"x","ci":"1234567"} Bearer abc.def.ghi';
      final once = LogSanitizer.scrub(raw);
      expect(LogSanitizer.scrub(once), equals(once));
    });
  });
}
