import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/data/initial_data_orchestrator.dart';
import 'package:flutter_application_1/core/data/app_session_cache.dart';
import 'package:flutter_application_1/core/services/programacion_service.dart';
import 'package:flutter_application_1/core/services/api_client.dart';
import 'package:flutter_application_1/core/session/user_session.dart';
import 'package:flutter_application_1/core/models/user_model.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

http.Client _happyPathClient() {
  return MockClient((request) async {
    if (request.url.path.contains('regionales')) {
      return http.Response(
        jsonEncode({'ok': true, 'data': [
          {'idsuc': 1, 'nombre': 'HMC La Paz', 'departamento': 'La Paz'}
        ]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.contains('fecha-servidor')) {
      return http.Response(
        jsonEncode({'ok': true, 'data': {
          'fechaServidor': '2026-05-04T08:00:00',
          'fechaCitaMovil': '2026-05-05',
        }}),
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
  return MockClient((_) async =>
      http.Response('{"ok":false,"message":"Error"}', 500,
          headers: {'content-type': 'application/json'}));
}

ProgramacionService _service(http.Client client) {
  return ProgramacionService(apiClient: ApiClient(httpClient: client));
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
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
    test('loadAll() rellena AppSessionCache.isLoaded = true en happy path', () async {
      final orchestrator = InitialDataOrchestrator(programacion: _service(_happyPathClient()));
      await orchestrator.loadAll();
      expect(AppSessionCache.isLoaded, isTrue);
    });

    test('loadAll() carga regionales correctamente', () async {
      final orchestrator = InitialDataOrchestrator(programacion: _service(_happyPathClient()));
      await orchestrator.loadAll();
      expect(AppSessionCache.regionales, isNotEmpty);
      expect(AppSessionCache.regionales.first.name, contains('La Paz'));
    });

    test('loadAll() carga fechaServidor correctamente', () async {
      final orchestrator = InitialDataOrchestrator(programacion: _service(_happyPathClient()));
      await orchestrator.loadAll();
      expect(AppSessionCache.fechaServidor['fechaServidor'], contains('2026-05-04'));
      expect(AppSessionCache.fechaServidor['fechaCitaMovil'], equals('2026-05-05'));
    });

    test('loadAll() no bloquea si grupoFamiliar está vacío', () async {
      final orchestrator = InitialDataOrchestrator(programacion: _service(_happyPathClient()));
      await orchestrator.loadAll();
      expect(AppSessionCache.grupoFamiliar, isEmpty);
      expect(AppSessionCache.isLoaded, isTrue); // aún cargado
    });

    test('loadAll() propaga excepción si endpoint crítico falla', () async {
      final orchestrator = InitialDataOrchestrator(programacion: _service(_failingClient()));
      expect(() => orchestrator.loadAll(), throwsException);
    });

    test('AppSessionCache.clear() resetea isLoaded y datos a valores vacíos', () {
      AppSessionCache.isLoaded = true;
      AppSessionCache.regionales = [];
      AppSessionCache.clear();

      expect(AppSessionCache.isLoaded, isFalse);
      expect(AppSessionCache.regionales, isEmpty);
      expect(AppSessionCache.fechaServidor, isEmpty);
    });
  });
}
