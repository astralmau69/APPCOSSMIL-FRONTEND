import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/data/citas_cache.dart';
import 'package:cossmil/core/models/reserva_model.dart';
import 'package:cossmil/core/security/secure_storage_service.dart';
import 'package:cossmil/core/utils/error_mapper.dart';

ReservaModel _cita({String id = 'C1', String status = 'Pendiente'}) =>
    ReservaModel(
      id: id,
      patientName: 'Juan Pérez',
      relationship: 'Titular',
      specialty: 'Medicina General',
      doctorName: 'Dra. Villagómez',
      hospital: 'Hospital Militar Central',
      city: 'La Paz',
      date: '2026-07-25',
      time: '08:30',
      status: status,
      idtran: 165,
      dr: 10,
      idesp: 42,
      idmed: '777',
      estadoCancelacion: '0',
    );

void main() {
  group('ReservaModel round-trip de caché', () {
    test('toCacheMap → fromCacheMap reconstruye idéntico', () {
      final original = _cita();
      final clon = ReservaModel.fromCacheMap(original.toCacheMap());
      expect(clon.id, original.id);
      expect(clon.patientName, original.patientName);
      expect(clon.specialty, original.specialty);
      expect(clon.doctorName, original.doctorName);
      expect(clon.hospital, original.hospital); // NO se re-normaliza
      expect(clon.status, original.status);
      expect(clon.idtran, original.idtran);
      expect(clon.idesp, original.idesp);
      expect(clon.estadoCancelacion, original.estadoCancelacion);
    });
  });

  group('CitasCache', () {
    late CitasCache cache;
    late InMemorySecureStorage storage;

    setUp(() {
      storage = InMemorySecureStorage();
      cache = CitasCache(storage: storage);
    });

    test('save → read devuelve las citas con marca de tiempo', () async {
      await cache.save(123, CitasCache.bucketHistorial, [
        _cita(id: 'A'),
        _cita(id: 'B'),
      ]);
      final cached = await cache.read(123, CitasCache.bucketHistorial);
      expect(cached, isNotNull);
      expect(cached!.reservas.map((r) => r.id), ['A', 'B']);
      expect(cached.age.inSeconds, lessThan(5)); // recién guardado
    });

    test('sin caché previa → null', () async {
      expect(await cache.read(999, CitasCache.bucketHistorial), isNull);
    });

    test(
      'aislamiento por usuario: idper distinto no ve las citas de otro',
      () async {
        await cache.save(1, CitasCache.bucketHistorial, [_cita(id: 'DEL_1')]);
        expect(await cache.read(2, CitasCache.bucketHistorial), isNull);
        final u1 = await cache.read(1, CitasCache.bucketHistorial);
        expect(u1!.reservas.single.id, 'DEL_1');
      },
    );

    test('los cubos historial y cancelados no se pisan', () async {
      await cache.save(1, CitasCache.bucketHistorial, [_cita(id: 'H')]);
      await cache.save(1, CitasCache.bucketCancelados, [
        _cita(id: 'X', status: 'Cancelado'),
      ]);
      expect(
        (await cache.read(1, CitasCache.bucketHistorial))!.reservas.single.id,
        'H',
      );
      expect(
        (await cache.read(1, CitasCache.bucketCancelados))!.reservas.single.id,
        'X',
      );
    });

    test('clearAll borra todas las claves de citas (logout)', () async {
      await cache.save(1, CitasCache.bucketHistorial, [_cita()]);
      await cache.save(2, CitasCache.bucketCancelados, [_cita()]);
      await cache.clearAll();
      expect(await cache.read(1, CitasCache.bucketHistorial), isNull);
      expect(await cache.read(2, CitasCache.bucketCancelados), isNull);
    });

    test('caché corrupta → null, no lanza', () async {
      await storage.write(
        key: 'citas_cache_v1_1_historial',
        value: 'no-es-json{',
      );
      expect(await cache.read(1, CitasCache.bucketHistorial), isNull);
    });
  });

  group('ErrorMapper.isOffline', () {
    test('detecta el error envuelto por ApiClient', () {
      expect(
        ErrorMapper.isOffline(Exception('No se pudo conectar al servidor.')),
        isTrue,
      );
    });
    test('detecta socket/timeout/network', () {
      expect(
        ErrorMapper.isOffline(Exception('SocketException: failed host lookup')),
        isTrue,
      );
      expect(
        ErrorMapper.isOffline(Exception('TimeoutException after 0:00:15')),
        isTrue,
      );
    });
    test('un error de negocio NO es offline', () {
      expect(
        ErrorMapper.isOffline(Exception('Fuera del plazo de cancelación')),
        isFalse,
      );
      expect(ErrorMapper.isOffline(null), isFalse);
    });
  });
}
