import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/data/grupo_familiar_cache.dart';
import 'package:cossmil/core/models/beneficiary_model.dart';
import 'package:cossmil/core/security/secure_storage_service.dart';

BeneficiaryModel _ben({String id = 'B1', String rel = 'Hijo'}) =>
    BeneficiaryModel(
      id: id,
      fullName: 'María Pérez',
      relationship: rel,
      ci: '1234567',
      matricula: 'M-001',
      photoBase64: 'AAAA==', // retrato: debe sobrevivir el round-trip
      age: 12,
      gender: 'FEMENINO',
      grado: '',
      serviceStatus: 'A',
      atencion: 'S',
    );

void main() {
  group('BeneficiaryModel round-trip de caché', () {
    test('toJson → fromCacheMap conserva TODO (incluida la foto)', () {
      final original = _ben();
      final clon = BeneficiaryModel.fromCacheMap(original.toJson());
      expect(clon.id, original.id);
      expect(clon.fullName, original.fullName);
      expect(clon.relationship, original.relationship);
      expect(clon.ci, original.ci);
      expect(clon.matricula, original.matricula);
      expect(clon.photoBase64, original.photoBase64); // <- fromJson lo perdería
      expect(clon.age, original.age);
      expect(clon.gender, original.gender);
      expect(clon.atencion, original.atencion);
    });
  });

  group('GrupoFamiliarCache', () {
    late GrupoFamiliarCache cache;
    late InMemorySecureStorage storage;

    setUp(() {
      storage = InMemorySecureStorage();
      cache = GrupoFamiliarCache(storage: storage);
    });

    test('save → read devuelve los miembros con marca de tiempo', () async {
      await cache.save(100, [_ben(id: 'A'), _ben(id: 'B', rel: 'Esposa')]);
      final cached = await cache.read(100);
      expect(cached, isNotNull);
      expect(cached!.miembros.map((b) => b.id), ['A', 'B']);
      expect(cached.age.inSeconds, lessThan(5));
    });

    test('aislamiento por titular (idper distinto)', () async {
      await cache.save(1, [_ben(id: 'X')]);
      expect(await cache.read(2), isNull);
    });

    test('sin caché → null', () async {
      expect(await cache.read(999), isNull);
    });

    test('caché corrupta → null, no lanza', () async {
      await storage.write(key: 'grupo_familiar_cache_v1_1', value: '{roto');
      expect(await cache.read(1), isNull);
    });

    test('clearAll borra todo (logout)', () async {
      await cache.save(1, [_ben()]);
      await cache.save(2, [_ben()]);
      await cache.clearAll();
      expect(await cache.read(1), isNull);
      expect(await cache.read(2), isNull);
    });
  });
}
