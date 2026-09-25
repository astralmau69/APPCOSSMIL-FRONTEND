import 'dart:convert';

import 'package:cossmil/core/models/reserva_model.dart';
import 'package:cossmil/core/services/api_client.dart';
import 'package:cossmil/core/services/programacion_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Devuelve el cuerpo dado y anota qué ruta se pidió.
http.Client _mock(int status, Map<String, dynamic> body, List<String> rutas) =>
    MockClient((request) async {
      rutas.add(request.url.path);
      return http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('estado de calificación del historial', () {
    // El backend manda 0 = sin calificar, 1 = calificada. De ahí cuelgan el
    // botón "Calificar" de Mis Reservas y el recordatorio por notificación.
    test('velo 1 es calificada y velo 0 no lo es', () {
      expect(ReservaModel.fromJson({'velo': 1}).calificado, isTrue);
      expect(ReservaModel.fromJson({'velo': '1'}).calificado, isTrue);
      expect(ReservaModel.fromJson({'velo': 0}).calificado, isFalse);
      expect(ReservaModel.fromJson({'velo': '0'}).calificado, isFalse);
    });

    test('se aceptan las otras etiquetas del mismo estado', () {
      expect(ReservaModel.fromJson({'calificado': true}).calificado, isTrue);
      expect(ReservaModel.fromJson({'yaCalificado': false}).calificado, isFalse);
      expect(
        ReservaModel.fromJson({'estadoCalificacion': 'S'}).calificado,
        isTrue,
      );
    });

    test('sin el estado, una nota distinta de cero implica calificada', () {
      expect(ReservaModel.fromJson({'calificacion': 4}).calificado, isTrue);
      expect(ReservaModel.fromJson({'calificacion': 0}).calificado, isFalse);
    });

    test('una fila sin ningún dato de calificación queda sin calificar', () {
      expect(ReservaModel.fromJson({'idtran': 1}).calificado, isFalse);
      // null explícito no debe leerse como calificada.
      expect(ReservaModel.fromJson({'velo': null}).calificado, isFalse);
    });

    test('el estado sobrevive al round-trip por la caché offline', () {
      final r = ReservaModel.fromJson({'velo': 1, 'idtran': 9});
      expect(ReservaModel.fromCacheMap(r.toCacheMap()).calificado, isTrue);
    });
  });

  group('getCalificacionesPendientes', () {
    test('mapea las atenciones pendientes con los datos que necesita la '
        'calificación', () async {
      final rutas = <String>[];
      final service = ProgramacionService(
        apiClient: ApiClient(
          httpClient: _mock(200, {
            'ok': true,
            'data': [
              {
                'codadm': '2026-1-1-468-10',
                'medico': 'VILLAGOMEZ POSTIGO MARIANELA',
                'especialidad': 'MEDICINA GENERAL',
                'fechaCita': '2026-01-13',
                'idmed': '77',
                'idesp': 42,
                'gestion': 2026,
                'idins': 1,
                'idsuc': 1,
                'idtran': 165,
                'dr': 10,
              },
            ],
          }, rutas),
        ),
      );

      final pendientes = await service.getCalificacionesPendientes(5179);

      expect(rutas.single, '/api/programacion/calificaciones-pendientes/5179');
      expect(pendientes, hasLength(1));
      final r = pendientes.single;
      // Sin estos tres, el POST de calificación no se puede armar.
      expect(r.codigoReserva, '2026-1-1-468-10');
      expect(r.idmed, '77');
      expect(r.idesp, 42);
      // Y estos identifican la fila para tacharla de la barrera.
      expect(r.idtran, 165);
      expect(r.dr, 10);
      expect(r.doctorName, 'Villagomez Postigo Marianela');
    });

    test('sin pendientes devuelve lista vacía', () async {
      final service = ProgramacionService(
        apiClient: ApiClient(
          httpClient: _mock(200, {'ok': true, 'data': []}, []),
        ),
      );
      expect(await service.getCalificacionesPendientes(5179), isEmpty);
    });

    test('un fallo del backend se propaga: no se puede confundir "no pude '
        'consultar" con "no hay nada"', () async {
      final service = ProgramacionService(
        apiClient: ApiClient(
          httpClient: _mock(500, {'ok': false, 'message': 'boom'}, []),
        ),
      );
      expect(
        () => service.getCalificacionesPendientes(5179),
        throwsA(isA<Exception>()),
      );
    });
  });
}
