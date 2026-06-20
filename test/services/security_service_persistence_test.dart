import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/services/security_service.dart';

/// QA de persistencia de seguridad local (PIN + biometría).
///
/// Invariante a garantizar:
///   Una vez configurado el PIN/huella, NO debe perderse nunca, salvo que:
///     1. El usuario desinstale la app (el SO borra el almacenamiento), o
///     2. Cambie de cuenta / cierre sesión explícitamente
///        (se llama [SecurityService.clearSecurityData]).
///
/// El PIN y la preferencia biométrica viven en `flutter_secure_storage`
/// (Keystore/Keychain). Aquí se mockea ese canal nativo con un almacén en
/// memoria que **persiste entre llamadas** dentro de un test, simulando un
/// storage que sobrevive a reinicios de la app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  // Almacén en memoria que imita Keystore/Keychain.
  final store = <String, String>{};

  // Cantidad de lecturas que deben fallar (simula un Keystore que no está
  // listo justo tras un reinicio del dispositivo). Sirve para verificar que un
  // fallo transitorio NO se interprete como "sin PIN".
  int failNextReads = 0;

  // Claves cuya lectura SIEMPRE falla (simula un fallo persistente del Keystore
  // para esa clave concreta).
  final failKeys = <String>{};

  setUp(() {
    store.clear();
    failNextReads = 0;
    failKeys.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      final args =
          (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
      switch (call.method) {
        case 'write':
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          final rk = args['key'] as String;
          if (failKeys.contains(rk) || failNextReads > 0) {
            if (failNextReads > 0) failNextReads--;
            throw PlatformException(
              code: 'Keystore',
              message: 'Keystore error (simulado)',
            );
          }
          return store[rk];
        case 'delete':
          store.remove(args['key'] as String);
          return null;
        case 'containsKey':
          return store.containsKey(args['key'] as String);
        case 'readAll':
          return Map<String, String>.from(store);
        case 'deleteAll':
          store.clear();
          return null;
        case 'isProtectedDataAvailable':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('SecurityService · persistencia de PIN', () {
    test('El PIN persiste tras configurarlo (sobrevive "reinicios")', () async {
      await SecurityService.savePin('1234');

      // Verificación inmediata.
      expect(await SecurityService.hasPin(), isTrue);

      // Simular varios "reinicios": el storage persiste, hasPin sigue true.
      for (var i = 0; i < 5; i++) {
        expect(await SecurityService.hasPin(), isTrue,
            reason: 'El PIN no debe perderse entre reinicios (iter $i)');
      }
    });

    test('verifyPin acepta el PIN correcto y rechaza el incorrecto', () async {
      await SecurityService.savePin('4821');
      expect(await SecurityService.verifyPin('4821'), isTrue);
      expect(await SecurityService.verifyPin('0000'), isFalse);
      expect(await SecurityService.verifyPin('482'), isFalse);
    });

    test('savePin rechaza PINs que no sean 4 dígitos numéricos', () async {
      expect(() => SecurityService.savePin('12'), throwsException);
      expect(() => SecurityService.savePin('abcd'), throwsException);
      expect(() => SecurityService.savePin('12345'), throwsException);
      // Tras los rechazos no debe haber PIN guardado.
      expect(await SecurityService.hasPin(), isFalse);
    });
  });

  group('SecurityService · persistencia de biometría', () {
    test('La preferencia de biometría persiste tras habilitarla', () async {
      await SecurityService.setBiometricsEnabled(true);
      for (var i = 0; i < 5; i++) {
        expect(await SecurityService.isBiometricsEnabled(), isTrue,
            reason: 'La huella no debe perderse entre reinicios (iter $i)');
      }
    });

    test('PIN + biometría sobreviven juntos múltiples "reinicios"', () async {
      await SecurityService.savePin('1234');
      await SecurityService.setBiometricsEnabled(true);

      for (var i = 0; i < 10; i++) {
        expect(await SecurityService.hasPin(), isTrue);
        expect(await SecurityService.isBiometricsEnabled(), isTrue);
      }
    });
  });

  group('SecurityService · únicos casos que SÍ deben borrar la seguridad', () {
    test('Cambio de cuenta / logout (clearSecurityData) borra PIN y huella',
        () async {
      await SecurityService.savePin('1234');
      await SecurityService.setBiometricsEnabled(true);
      expect(await SecurityService.hasPin(), isTrue);
      expect(await SecurityService.isBiometricsEnabled(), isTrue);

      // Cambio de cuenta / desactivación explícita.
      await SecurityService.clearSecurityData();

      expect(await SecurityService.hasPin(), isFalse);
      expect(await SecurityService.isBiometricsEnabled(), isFalse);
      expect(await SecurityService.verifyPin('1234'), isFalse);
    });

    test('Desinstalación (el SO borra el almacenamiento) borra todo', () async {
      await SecurityService.savePin('1234');
      await SecurityService.setBiometricsEnabled(true);

      // Simular desinstalación: el SO elimina los datos de la app.
      store.clear();

      expect(await SecurityService.hasPin(), isFalse);
      expect(await SecurityService.isBiometricsEnabled(), isFalse);
    });
  });

  group('SecurityService · resiliencia (no perder el PIN por error transitorio)',
      () {
    test('Un fallo transitorio del Keystore NO borra ni oculta el PIN',
        () async {
      await SecurityService.savePin('1234');

      // Las próximas 2 lecturas fallan (Keystore aún no listo tras reiniciar).
      // _readResilient reintenta hasta 2 veces → debe seguir devolviendo true.
      failNextReads = 2;
      expect(await SecurityService.hasPin(), isTrue,
          reason:
              'Un fallo transitorio no debe interpretarse como "sin PIN"');
    });

    test('Un fallo PERSISTENTE relanza la excepción (no asume "sin PIN")',
        () async {
      await SecurityService.savePin('1234');

      // Más fallos que reintentos disponibles → debe propagar la excepción,
      // para que el llamador caiga en su ruta segura (conservar el PIN), nunca
      // en "no hay PIN" (que lo resetearía).
      failNextReads = 99;
      await expectLater(SecurityService.hasPin(), throwsA(isA<Exception>()));
    });
  });

  group('SecurityService · isLocalAuthConfiguredSafe (nunca degradar al login)',
      () {
    test('Con PIN configurado → true (va al desbloqueo)', () async {
      await SecurityService.savePin('1234');
      expect(await SecurityService.isLocalAuthConfiguredSafe(), isTrue);
    });

    test('Con huella (sin PIN) → true', () async {
      await SecurityService.setBiometricsEnabled(true);
      expect(await SecurityService.isLocalAuthConfiguredSafe(), isTrue);
    });

    test('Sin PIN ni huella → false (login normal, correcto)', () async {
      expect(await SecurityService.isLocalAuthConfiguredSafe(), isFalse);
    });

    test('Si falla la lectura del PIN → asume configurado (true)', () async {
      await SecurityService.savePin('1234');
      failKeys.add('local_pin_hash'); // lectura del PIN falla siempre
      expect(await SecurityService.isLocalAuthConfiguredSafe(), isTrue,
          reason:
              'Un fallo de lectura NUNCA debe degradar al login normal si hay PIN');
    });

    test('Si falla la lectura de la huella (sin PIN) → asume configurado',
        () async {
      failKeys.add('use_biometrics'); // sin PIN, pero la huella no se puede leer
      expect(await SecurityService.isLocalAuthConfiguredSafe(), isTrue);
    });
  });

  group('SecurityService · bloqueo anti fuerza bruta del PIN', () {
    test('Tras 5 intentos fallidos activa cooldown y reinicia la ventana',
        () async {
      for (var i = 0; i < SecurityService.maxPinAttempts; i++) {
        await SecurityService.recordFailedAttempt();
      }
      final cd = await SecurityService.cooldownRemaining();
      expect(cd, isNotNull);
      expect(cd!.inSeconds, greaterThan(0));
      // La ventana de intentos se reinicia (el conteo de bloqueos persiste).
      expect(await SecurityService.getFailedAttempts(), 0);
    });

    test('resetFailedAttempts limpia intentos, cooldown y bloqueos', () async {
      for (var i = 0; i < SecurityService.maxPinAttempts; i++) {
        await SecurityService.recordFailedAttempt();
      }
      await SecurityService.resetFailedAttempts();
      expect(await SecurityService.cooldownRemaining(), isNull);
      expect(await SecurityService.getFailedAttempts(), 0);
    });
  });
}
