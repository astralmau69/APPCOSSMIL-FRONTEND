import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../constants/api_constants.dart';
import '../models/regional_model.dart';
import '../models/specialty_model.dart';
import '../models/horario_atencion_model.dart';
import '../models/medico_asignado_model.dart';
import '../models/reserva_model.dart';
import '../mock/mock_regional_data.dart';
import '../mock/mock_specialty_data.dart';
import 'api_client.dart';

/// Servicio para endpoints de programación médica.
/// Respeta `AppConfig.useMockData` para desarrollo offline.
///
/// Cuando `useMockData` es false, usa [ApiClient] con Bearer token.
class ProgramacionService {
  final ApiClient _api;

  ProgramacionService({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  // ── Regionales por departamento ─────────────────────────────────────────

  Future<List<RegionalModel>> getRegionalesPorDepartamento(int idins) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return MockRegionalData.regionals;
    }

    final response = await _api.get(
      ApiConstants.regionalesPorDepartamento(idins),
    );

    return switch (response) {
      ApiSuccess(:final data) => () {
        debugPrint('📦 regionales raw response: $data');
        return _parseRegionales(data);
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Todas las regionales ────────────────────────────────────────────────

  Future<List<RegionalModel>> getRegionales(int idins) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return MockRegionalData.regionals;
    }

    final response = await _api.get(ApiConstants.regionales(idins));

    return switch (response) {
      ApiSuccess(:final data) => _parseRegionales(data),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Especialidades directas ─────────────────────────────────────────────

  Future<List<SpecialtyModel>> getEspecialidadesDirectas(
    int idins,
    int idsuc,
  ) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return MockSpecialtyData.specialties
          .where((s) => !s.isInterconsulta)
          .toList();
    }

    final response = await _api.get(
      ApiConstants.especialidadesDirectas(idins, idsuc),
    );

    return switch (response) {
      ApiSuccess(:final data) => _parseEspecialidades(data),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Especialidades de interconsulta ─────────────────────────────────────

  Future<List<SpecialtyModel>> getEspecialidadesInterconsulta(
    int idper,
  ) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return MockSpecialtyData.specialties
          .where((s) => s.isInterconsulta)
          .toList();
    }

    final response = await _api.get(
      ApiConstants.especialidadesInterconsulta(idper),
    );

    return switch (response) {
      ApiSuccess(:final data) => _parseEspecialidades(data),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Verificar horario de atención ──────────────────────────────────────

  /// Verifica si hay horario de atención habilitado.
  /// Retorna el código de horario (int) si hay, null si no hay.
  Future<int?> verificarHorarioAtencion(int idins, int idsuc) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return 2; // Mock: siempre hay horario
    }

    final response = await _api.get(
      ApiConstants.verificarHorarioAtencion(idins, idsuc),
    );

    return switch (response) {
      ApiSuccess(:final data) => () {
        final result = _extractDataValue(data);
        debugPrint('🔎 verificarHorario raw data: $data');
        debugPrint('🔎 verificarHorario parsed result: $result');
        return result;
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Horarios de atención ──────────────────────────────────────────────

  /// Lista de horarios de atención habilitados para reserva.
  Future<List<HorarioAtencionModel>> getHorariosAtencion(
    int idins,
    int idsuc,
  ) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return [
        const HorarioAtencionModel(
          idhorario: 2,
          descripcion: 'HORARIO DE ATENCION - PRIMER TURNO APP-MOVIL Y APLICATIVO WEB',
          horaini: '08:00:00',
          horafin: '12:00:00',
        ),
        const HorarioAtencionModel(
          idhorario: 3,
          descripcion: 'HORARIO DE ATENCION - SEGUNDO TURNO APP-MOVIL Y APLICATIVO WEB',
          horaini: '13:00:00',
          horafin: '17:00:00',
        ),
      ];
    }

    final response = await _api.get(
      ApiConstants.horariosAtencion(idins, idsuc),
    );

    return switch (response) {
      ApiSuccess(:final data) => () {
        debugPrint('📦 horarios-atencion raw response: $data');
        return _parseHorariosAtencion(data);
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Médico asignado ───────────────────────────────────────────────────

  /// Obtiene médico asignado con agenda y horas disponibles.
  /// [fecha] formato yyyy-MM-dd. [idhorario] obtenido de verificarHorarioAtencion.
  Future<MedicoAsignadoModel> getMedicoAsignado(
    int idins,
    int idsuc,
    int idesp,
    String fecha,
    int idhorario,
  ) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      return const MedicoAsignadoModel(
        idagenda: 'mock-agenda-001',
        idesp: 42,
        idmed: '18',
        medico: 'VILLAGOMEZ POSTIGO MARIANELA',
        oferta: 2,
        demanda: 0,
        nroini: 4,
        estado: true,
        idcon: 3,
        descripcionConsultorio: 'CONSULTORIO 3 - PLANTA BAJA',
        dia: 'VIERNES',
        fecha: '2026-03-27',
        idcontrol: 'mock-control-123',
        horas: [
          HoraDisponibleModel(idhora: 'mock-1', numero: 5, hora: '09:00', estado: false),
          HoraDisponibleModel(idhora: 'mock-2', numero: 6, hora: '09:15', estado: true),
          HoraDisponibleModel(idhora: 'mock-3', numero: 7, hora: '09:30', estado: true),
        ],
      );
    }

    final response = await _api.get(
      ApiConstants.medicoAsignado(idins, idsuc, idesp, fecha, idhorario),
    );

    return switch (response) {
      ApiSuccess(:final data) => _parseMedicoAsignado(data),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Crear cita ───────────────────────────────────────────────────────

  /// Crea la cita médica definitiva en el backend.
  ///
  /// Retorna el objeto `data` de la respuesta que contiene:
  /// `{ gestion, idins, idsuc, idtran, dr }` — necesarios para el PDF.
  Future<Map<String, dynamic>> crearCita({
    required Map<String, dynamic> payload,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 800));
      return {
        'ok': true,
        'message': 'Cita MOCK creada con éxito',
        'status': 200,
        'data': {
          'gestion': 2026,
          'idins': 1,
          'idsuc': 1,
          'idtran': 165,
          'dr': 12,
        },
      };
    }

    final response = await _api.post(
      ApiConstants.crearCita(),
      body: payload,
    );

    return switch (response) {
      ApiSuccess(:final data) => () {
        final body = data as Map<String, dynamic>;
        if (body['ok'] == false) {
          final msg = body['message'] as String? ??
              (body['errors'] is List && (body['errors'] as List).isNotEmpty
                  ? (body['errors'] as List).first.toString()
                  : 'Error al crear la cita.');
          throw Exception(msg);
        }
        return body;
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Historial de citas ──────────────────────────────────────────────

  /// Obtiene el historial de citas del asegurado (paginado).
  ///
  /// Retorna un record con la lista de reservas y los datos de paginación.
  Future<({List<ReservaModel> reservas, int totalElements, int totalPages})>
      getHistorialCitas(int idper, {int pagina = 1, int cantidad = 10}) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      return (reservas: <ReservaModel>[], totalElements: 0, totalPages: 0);
    }

    final response = await _api.get(
      ApiConstants.historialCitas(idper, pagina, cantidad),
    );

    return switch (response) {
      ApiSuccess(:final data) => () {
        debugPrint('📦 historial-citas raw response: $data');
        final reservas = _parseReservas(data);
        // Extraer paginación
        int totalElements = 0;
        int totalPages = 0;
        if (data is Map<String, dynamic> && data['pagination'] is Map) {
          final pag = data['pagination'] as Map<String, dynamic>;
          totalElements = pag['totalElements'] as int? ?? 0;
          totalPages = pag['totalPages'] as int? ?? 0;
        }
        return (reservas: reservas, totalElements: totalElements, totalPages: totalPages);
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── PDF de cita médica ────────────────────────────────────────────

  /// Descarga el PDF de una cita médica desde el backend.
  /// Retorna los bytes del PDF, o null si falla.
  Future<Uint8List?> getCitaMedicaPdf({
    required int gestion,
    required int idins,
    required int idsuc,
    required int idtran,
    required int dr,
  }) async {
    if (AppConfig.useMockData) {
      return null;
    }

    return _api.getBytes(
      ApiConstants.citaMedicaPdf(gestion, idins, idsuc, idtran, dr),
    );
  }

  // ── Parsers ─────────────────────────────────────────────────────────────

  /// Parsea respuesta estándar: `{ ok, status, message, data: [...] }`
  List<RegionalModel> _parseRegionales(dynamic body) {
    final list = _extractDataList(body);
    return list
        .map((e) => RegionalModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<SpecialtyModel> _parseEspecialidades(dynamic body) {
    final list = _extractDataList(body);
    return list
        .map((e) => SpecialtyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Extrae la lista `data` de la envoltura estándar del backend.
  List<dynamic> _extractDataList(dynamic body) {
    if (body is Map<String, dynamic>) {
      // Formato estándar: { ok: true, data: [...] }
      if (body.containsKey('data') && body['data'] is List) {
        return body['data'] as List<dynamic>;
      }
      // Si 'data' es un solo objeto, lo envuelve en lista
      if (body.containsKey('data')) {
        return [body['data']];
      }
    }
    // Si ya es una lista directa
    if (body is List) return body;
    return [];
  }

  /// Extrae un valor escalar de `data` (e.g. int del verificar-horario).
  int? _extractDataValue(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      debugPrint('🔎 _extractDataValue: body es Map, data=$data (${data.runtimeType})');
      if (data is int) return data;
      if (data is num) return data.toInt();
      // Intentar parsear desde String
      if (data is String) {
        return int.tryParse(data);
      }
    }
    // Si body YA es el valor escalar directamente
    if (body is int) return body;
    if (body is num) return body.toInt();
    debugPrint('🔎 _extractDataValue: no se pudo extraer valor de $body (${body.runtimeType})');
    return null;
  }

  List<HorarioAtencionModel> _parseHorariosAtencion(dynamic body) {
    final list = _extractDataList(body);
    return list
        .map((e) => HorarioAtencionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  MedicoAsignadoModel _parseMedicoAsignado(dynamic body) {
    debugPrint('📦 Parsing medico-asignado body: $body');
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      debugPrint('   ↳ data field: $data');
      if (data is Map<String, dynamic>) {
        return MedicoAsignadoModel.fromJson(data);
      }
      // Si data es una lista, tomar el primer elemento
      if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
        debugPrint('   ↳ data is a list, taking first element');
        return MedicoAsignadoModel.fromJson(data.first as Map<String, dynamic>);
      }
    }
    debugPrint('   ⚠️ No hay datos válidos en la respuesta de médico asignado');
    throw Exception('Sin médico asignado para esta especialidad');
  }

  List<ReservaModel> _parseReservas(dynamic body) {
    final list = _extractDataList(body);
    return list
        .map((e) => ReservaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
