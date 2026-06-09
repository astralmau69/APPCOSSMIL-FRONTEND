import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cossmil/core/services/programacion_service.dart';
import 'package:cossmil/core/services/api_client.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Crea un [MockClient] que siempre responde con [statusCode] y [body].
http.Client _mockClient(int statusCode, Map<String, dynamic> body) {
  return MockClient((request) async {
    return http.Response(jsonEncode(body), statusCode,
        headers: {'content-type': 'application/json'});
  });
}

/// [ApiClient] con cliente HTTP inyectado para tests.
/// No hace refresh real de token — el MockClient responde directamente.
ApiClient _apiClient(http.Client httpClient) {
  return ApiClient(httpClient: httpClient);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('ProgramacionService', () {
    // ── getRegionalesPorDepartamento ──────────────────────────────────────────

    test('retorna lista cuando el backend responde OK', () async {
      final client = _mockClient(200, {
        'ok': true,
        'data': [
          {
            'idsuc': 1,
            'nombre': 'Hospital Militar Central N\u00b0 1',
            'departamento': 'La Paz',
          }
        ]
      });
      final service = ProgramacionService(apiClient: _apiClient(client));
      final list = await service.getRegionalesPorDepartamento(1);
      expect(list, isNotEmpty);
    });

    test('getRegionalesPorDepartamento lanza excepci\u00f3n en error de API', () async {
      final client = _mockClient(500, {'ok': false, 'message': 'Error interno'});
      final service = ProgramacionService(apiClient: _apiClient(client));
      expect(
        () => service.getRegionalesPorDepartamento(1),
        throwsException,
      );
    });

    // ── getFechaServidor ──────────────────────────────────────────────────────

    test('getFechaServidor retorna mapa con fechas v\u00e1lidas', () async {
      final client = _mockClient(200, {
        'ok': true,
        'data': {
          'fechaServidor': '2026-05-04T12:00:00',
          'fechaCitaMovil': '2026-05-05',
        }
      });
      final service = ProgramacionService(apiClient: _apiClient(client));
      final fecha = await service.getFechaServidor();
      expect(fecha['fechaServidor'], contains('2026-05-04'));
      expect(fecha['fechaCitaMovil'], equals('2026-05-05'));
    });

    test('getFechaServidor lanza excepci\u00f3n si el formato es inv\u00e1lido', () async {
      final client = _mockClient(200, {'ok': true, 'data': 'no_es_un_mapa'});
      final service = ProgramacionService(apiClient: _apiClient(client));
      expect(() => service.getFechaServidor(), throwsException);
    });

    // ── crearCita ─────────────────────────────────────────────────────────────

    test('crearCita retorna datos de la cita cuando ok=true', () async {
      final client = _mockClient(200, {
        'ok': true,
        'message': 'Cita creada exitosamente',
        'data': {'gestion': 2026, 'idins': 1, 'idsuc': 1, 'idtran': 999, 'dr': 5},
      });
      final service = ProgramacionService(apiClient: _apiClient(client));
      final result = await service.crearCita(payload: {
        'idper': 123,
        'idsuc': 1,
        'idesp': 10,
        'idhora': 'hora-001',
      });
      expect(result['ok'], isTrue);
      expect(result['data']['idtran'], equals(999));
    });

    test('crearCita lanza excepci\u00f3n cuando ok=false en respuesta', () async {
      final client = _mockClient(200, {
        'ok': false,
        'message': 'El asegurado ya tiene una cita activa.',
        'errors': [],
      });
      final service = ProgramacionService(apiClient: _apiClient(client));
      expect(
        () => service.crearCita(payload: {'idper': 123}),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('ya tiene una cita activa'),
          ),
        ),
      );
    });

    // ── getGrupoFamiliar ──────────────────────────────────────────────────────

    test('getGrupoFamiliar retorna lista vac\u00eda si data es vac\u00eda', () async {
      final client = _mockClient(200, {'ok': true, 'data': []});
      final service = ProgramacionService(apiClient: _apiClient(client));
      final list = await service.getGrupoFamiliar(123);
      expect(list, isEmpty);
    });
  });
}
