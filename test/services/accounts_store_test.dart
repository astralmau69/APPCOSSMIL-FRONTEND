import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/models/saved_account.dart';
import 'package:cossmil/core/services/accounts_store.dart';
import 'package:cossmil/core/utils/pin_hasher.dart';

/// QA de la capa de datos del login multi-cuenta (estilo Facebook).
///
/// Verifica que las cuentas guardadas (matrícula + contraseña + PIN por cuenta
/// + huella) se persistan en el almacenamiento seguro y sobrevivan reinicios,
/// y que solo se borren al quitar la cuenta explícitamente.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final store = <String, String>{};

  SavedAccount makeAccount(String matricula, String name, String pin) {
    final ph = PinHasher.hash(pin);
    return SavedAccount(
      matricula: matricula,
      displayName: name,
      pinHash: ph.hash,
      pinSalt: ph.salt,
    );
  }

  setUp(() {
    store.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      final args =
          (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
      switch (call.method) {
        case 'write':
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return store[args['key'] as String];
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
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('AccountsStore · guardar y listar', () {
    test('Guarda una cuenta y la recupera con su contraseña', () async {
      await AccountsStore.upsert(
        account: makeAccount('010325AQJ', 'Juan Perez', '1234'),
        password: 'secreta1',
      );

      expect(await AccountsStore.hasAny(), isTrue);
      final list = await AccountsStore.list();
      expect(list, hasLength(1));
      expect(list.first.matricula, '010325AQJ');
      expect(list.first.displayName, 'Juan Perez');
      expect(await AccountsStore.getPassword('010325AQJ'), 'secreta1');
    });

    test('Soporta varias cuentas (multi-cuenta)', () async {
      await AccountsStore.upsert(
          account: makeAccount('AAA111', 'Ana', '1111'), password: 'pa');
      await AccountsStore.upsert(
          account: makeAccount('BBB222', 'Beto', '2222'), password: 'pb');
      await AccountsStore.upsert(
          account: makeAccount('CCC333', 'Cira', '3333'), password: 'pc');

      final list = await AccountsStore.list();
      expect(list, hasLength(3));
      expect(await AccountsStore.getPassword('BBB222'), 'pb');
    });

    test('upsert reemplaza la misma matrícula (no duplica)', () async {
      await AccountsStore.upsert(
          account: makeAccount('AAA111', 'Ana', '1111'), password: 'vieja');
      await AccountsStore.upsert(
          account: makeAccount(' aaa111 ', 'Ana Maria', '9999'),
          password: 'nueva');

      final list = await AccountsStore.list();
      expect(list, hasLength(1), reason: 'la matrícula es la misma');
      expect(list.first.displayName, 'Ana Maria');
      expect(await AccountsStore.getPassword('AAA111'), 'nueva');
    });
  });

  group('AccountsStore · PIN por cuenta y huella', () {
    test('Cada cuenta verifica su propio PIN', () async {
      await AccountsStore.upsert(
          account: makeAccount('AAA111', 'Ana', '1234'), password: 'pa');
      await AccountsStore.upsert(
          account: makeAccount('BBB222', 'Beto', '5678'), password: 'pb');

      final ana = await AccountsStore.find('AAA111');
      final beto = await AccountsStore.find('BBB222');

      expect(AccountsStore.verifyPin(ana!, '1234'), isTrue);
      expect(AccountsStore.verifyPin(ana, '5678'), isFalse,
          reason: 'el PIN de Beto no debe abrir la cuenta de Ana');
      expect(AccountsStore.verifyPin(beto!, '5678'), isTrue);
    });

    test('setPin cambia el PIN de una cuenta', () async {
      await AccountsStore.upsert(
          account: makeAccount('AAA111', 'Ana', '1234'), password: 'pa');
      expect(await AccountsStore.setPin('AAA111', '4321'), isTrue);

      final ana = await AccountsStore.find('AAA111');
      expect(AccountsStore.verifyPin(ana!, '4321'), isTrue);
      expect(AccountsStore.verifyPin(ana, '1234'), isFalse);
    });

    test('setBiometric persiste la preferencia de huella por cuenta', () async {
      await AccountsStore.upsert(
          account: makeAccount('AAA111', 'Ana', '1234'), password: 'pa');
      expect(await AccountsStore.setBiometric('AAA111', true), isTrue);

      final ana = await AccountsStore.find('AAA111');
      expect(ana!.biometricEnabled, isTrue);
    });
  });

  group('AccountsStore · persistencia y borrado', () {
    test('Las cuentas sobreviven "reinicios" (storage persiste)', () async {
      await AccountsStore.upsert(
          account: makeAccount('AAA111', 'Ana', '1234'), password: 'pa');
      for (var i = 0; i < 5; i++) {
        expect(await AccountsStore.hasAny(), isTrue);
        expect(await AccountsStore.getPassword('AAA111'), 'pa');
      }
    });

    test('remove borra la cuenta y su contraseña; el resto queda', () async {
      await AccountsStore.upsert(
          account: makeAccount('AAA111', 'Ana', '1111'), password: 'pa');
      await AccountsStore.upsert(
          account: makeAccount('BBB222', 'Beto', '2222'), password: 'pb');

      await AccountsStore.remove('AAA111');

      final list = await AccountsStore.list();
      expect(list, hasLength(1));
      expect(list.first.matricula, 'BBB222');
      expect(await AccountsStore.getPassword('AAA111'), isNull);
      expect(await AccountsStore.getPassword('BBB222'), 'pb');
    });
  });
}
