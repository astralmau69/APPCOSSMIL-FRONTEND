import 'dart:convert';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cossmil/core/data/initial_data_orchestrator.dart';
import 'package:cossmil/core/data/app_session_cache.dart';
import 'package:cossmil/core/services/programacion_service.dart';
import 'package:cossmil/core/services/api_client.dart';
import 'package:cossmil/core/session/user_session.dart';
import 'package:cossmil/core/models/user_model.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

http.Client _happyPathClient() {
  return MockClient((request) async {
    if (request.url.path.contains('regionales')) {
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': [
            {'idsuc': 1, 'sucursal': 'HMC La Paz', 'departamento': 'La Paz'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.contains('fecha-servidor')) {
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': {
            'fechaServidor': '2026-05-04T08:00:00',
            'fechaCitaMovil': '2026-05-05',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    // especialidades y grupo familiar → vacíos pero OK
    return http.Response(
      jsonEncode({'ok': true, 'data': []}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

http.Client _failingClient() {
  return MockClient(
    (_) async => http.Response(
      '{"ok":false,"message":"Error"}',
      500,
      headers: {'content-type': 'application/json'},
    ),
  );
}

/// OK inmediato en todo, salvo el path indicado, que responde tras [delay]
/// (para simular un endpoint colgado bajo reloj falso).
http.Client _slowPathClient(String slowPath, Duration delay) {
  return MockClient((request) async {
    if (request.url.path.contains(slowPath)) {
      await Future.delayed(delay);
    }
    if (request.url.path.contains('regionales')) {
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': [
            {'idsuc': 1, 'sucursal': 'HMC La Paz', 'departamento': 'La Paz'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.contains('fecha-servidor')) {
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': {
            'fechaServidor': '2026-05-04T08:00:00',
            'fechaCitaMovil': '2026-05-05',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      jsonEncode({'ok': true, 'data': []}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

ProgramacionService _service(http.Client client) {
  return ProgramacionService(apiClient: ApiClient(httpClient: client));
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // loadAll() → ApiClient → TokenStorage.getToken() toca flutter_secure_storage
  // (canal de plataforma), así que el binding de test debe existir y el
  // almacén seguro estar mockeado (sin sesión: los reads devuelven null).
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  setUp(() {
    AppSessionCache.clear();
    UserSession.currentUser = const UserModel(
      id: '12345',
      fullName: 'Test Usuario',
      rank: 'Soldado',
      matricula: 'M001',
      bloodType: 'O+',
      age: 30,
      role: 'Titular',
      isEnabled: true,
      beneficiaries: [],
    );
  });

  group('InitialDataOrchestrator', () {
    test(
      'loadAll() rellena AppSessionCache.isLoaded = true en happy path',
      () async {
        final orchestrator = InitialDataOrchestrator(
          programacion: _service(_happyPathClient()),
        );
        await orchestrator.loadAll();
        expect(AppSessionCache.isLoaded, isTrue);
      },
    );

    test('loadAll() carga regionales correctamente', () async {
      final orchestrator = InitialDataOrchestrator(
        programacion: _service(_happyPathClient()),
      );
      await orchestrator.loadAll();
      expect(AppSessionCache.regionales, isNotEmpty);
      expect(AppSessionCache.regionales.first.name, contains('La Paz'));
    });

    test('loadAll() carga fechaServidor correctamente', () async {
      final orchestrator = InitialDataOrchestrator(
        programacion: _service(_happyPathClient()),
      );
      await orchestrator.loadAll();
      expect(
        AppSessionCache.fechaServidor['fechaServidor'],
        contains('2026-05-04'),
      );
      expect(
        AppSessionCache.fechaServidor['fechaCitaMovil'],
        equals('2026-05-05'),
      );
    });

    test('loadAll() no bloquea si grupoFamiliar está vacío', () async {
      final orchestrator = InitialDataOrchestrator(
        programacion: _service(_happyPathClient()),
      );
      await orchestrator.loadAll();
      expect(AppSessionCache.grupoFamiliar, isEmpty);
      expect(AppSessionCache.isLoaded, isTrue); // aún cargado
    });

    test('loadAll() propaga excepción si endpoint crítico falla', () async {
      final orchestrator = InitialDataOrchestrator(
        programacion: _service(_failingClient()),
      );
      expect(() => orchestrator.loadAll(), throwsException);
    });

    test('un NO crítico colgado NO bloquea el inicio: degrada a vacío', () {
      // Grupo familiar cuelga 9s (pasa el tope no crítico de 8s); el resto
      // responde al instante. El inicio debe completar con éxito igualmente.
      fakeAsync((async) {
        final orchestrator = InitialDataOrchestrator(
          programacion: _service(
            _slowPathClient('gpo-familiar', const Duration(seconds: 9)),
          ),
        );

        var completed = false;
        Object? error;
        orchestrator.loadAll().then(
          (_) {
            completed = true;
          },
          onError: (Object e) {
            error = e;
          },
        );

        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        expect(
          error,
          isNull,
          reason: 'un no crítico lento no debe tumbar el inicio',
        );
        expect(completed, isTrue);
        expect(AppSessionCache.isLoaded, isTrue);
        expect(AppSessionCache.grupoFamiliar, isEmpty); // degradó a vacío
        // Los críticos sí quedaron cargados: el titular puede reservar.
        expect(AppSessionCache.regionales, isNotEmpty);
        expect(AppSessionCache.fechaServidor, isNotEmpty);
      });
    });

    test('un crítico colgado falla rápido (lanza al vencer su timeout)', () {
      // Regionales (crítico) cuelga 13s, pasando su tope de 12s → debe lanzar
      // para que LoadingDataScreen muestre "Reintentar".
      fakeAsync((async) {
        final orchestrator = InitialDataOrchestrator(
          programacion: _service(
            _slowPathClient('regionales', const Duration(seconds: 13)),
          ),
        );

        Object? error;
        orchestrator.loadAll().then(
          (_) {},
          onError: (Object e) {
            error = e;
          },
        );

        async.elapse(const Duration(seconds: 14));
        async.flushMicrotasks();

        expect(error, isNotNull);
        expect(AppSessionCache.isLoaded, isFalse);
      });
    });

    test(
      'AppSessionCache.clear() resetea isLoaded y datos a valores vacíos',
      () {
        AppSessionCache.isLoaded = true;
        AppSessionCache.regionales = [];
        AppSessionCache.clear();

        expect(AppSessionCache.isLoaded, isFalse);
        expect(AppSessionCache.regionales, isEmpty);
        expect(AppSessionCache.fechaServidor, isEmpty);
      },
    );
  });
}
