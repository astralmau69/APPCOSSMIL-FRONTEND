import '../../../core/services/api_client.dart';
import '../models/medico_model.dart';

/// Servicio para el módulo Calendario de Atención.
/// Usa [ApiClient] centralizado (Bearer token + retry 401 automático).
class CalendarioService {
  final ApiClient _api;

  CalendarioService({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  void dispose() => _api.close();

  // ── API 1: Agenda por especialidad ────────────────────────────────────────

  /// GET /api/programacion/medico-agenda-especialidad-cex/1/1/{fecha}/{idEsp}
  /// Retorna médicos disponibles para una fecha y especialidad.
  Future<List<MedicoCalendarioModel>> getMedicosPorEspecialidad({
    required String fecha,
    required int idEspecialidad,
    int idins = 1,
    int idsuc = 1,
  }) async {
    final path =
        '/api/programacion/medico-agenda-especialidad-cex/$idins/$idsuc/$fecha/$idEspecialidad';
    final response = await _api.get(path);

    if (response is ApiError) {
      throw Exception(response.message);
    }

    final data = (response as ApiSuccess).data;
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => MedicoCalendarioModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── API 2: Horario semanal del médico ─────────────────────────────────────

  /// GET /api/programacion/horario-medico-movil/1/1/{idmed}
  /// Retorna los turnos semanales del médico.
  Future<List<MedicoHorarioModel>> getHorarioMedico({
    required String idmed,
    int idins = 1,
    int idsuc = 1,
  }) async {
    final path = '/api/programacion/horario-medico-movil/$idins/$idsuc/$idmed';
    final response = await _api.get(path);

    if (response is ApiError) {
      throw Exception(response.message);
    }

    final data = (response as ApiSuccess).data;
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => MedicoHorarioModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── API 3: Búsqueda de médico ─────────────────────────────────────────────

  /// POST /api/programacion/medsuc-buscar
  /// Busca médicos por apellido paterno, materno, nombre o especialidad.
  Future<List<MedicoBusquedaModel>> buscarMedicos({
    String pat = '',
    String mat = '',
    String nom = '',
    String esp = '',
    int idins = 1,
    int idsuc = 1,
  }) async {
    const path = '/api/programacion/medsuc-buscar';
    final response = await _api.post(path, body: {
      'idins': idins,
      'idsuc': idsuc,
      'pat': pat,
      'mat': mat,
      'nom': nom,
      'esp': esp,
    });

    if (response is ApiError) {
      throw Exception(response.message);
    }

    final data = (response as ApiSuccess).data;
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => MedicoBusquedaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
