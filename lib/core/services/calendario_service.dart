import '../constants/api_constants.dart';
import '../models/specialty_model.dart';
import '../models/calendario_models.dart';
import 'api_client.dart';

/// Servicio para el flujo de Calendario de Atención (ventanilla).
///
/// Regional La Paz e Hospital Militar Central están hardcodeados como 1/1
/// según las especificaciones del backend para este flujo.
class CalendarioService {
  static const int _idins = 1;
  static const int _idsuc = 1;

  final ApiClient _api;

  CalendarioService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  // ── Especialidades Ventanilla ─────────────────────────────────────────────

  /// Retorna las especialidades disponibles para consulta en ventanilla.
  /// Endpoint: GET /api/programacion/especialidades/ventanilla/1/1
  Future<List<SpecialtyModel>> getEspecialidades() async {
    final response = await _api.get(
      ApiConstants.especialidadesVentanilla(_idins, _idsuc),
    );
    return switch (response) {
      ApiSuccess(:final data) => () {
          final list = data is List
              ? data
              : (data is Map ? data['data'] as List? ?? [] : []);
          return list
              .whereType<Map<String, dynamic>>()
              .map(SpecialtyModel.fromJson)
              .where((s) => s.name.isNotEmpty)
              .toList();
        }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Médicos por Especialidad ──────────────────────────────────────────────

  /// Retorna los médicos disponibles para la especialidad indicada.
  /// Endpoint: GET /api/programacion/medico-especialidad-consulta/1/1/{idesp}
  Future<List<MedicoSucModel>> getMedicos({required int idesp}) async {
    final response = await _api.get(
      ApiConstants.medicoEspecialidadConsulta(_idins, _idsuc, idesp),
    );
    return switch (response) {
      ApiSuccess(:final data) => () {
          final list = data is List
              ? data
              : (data is Map ? data['data'] as List? ?? [] : []);
          return list
              .whereType<Map<String, dynamic>>()
              .map(MedicoSucModel.fromJson)
              .where((m) => m.nombre.isNotEmpty)
              .toList();
        }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Horario Médico (ventana móvil de 7 días) ──────────────────────────────

  /// Retorna la agenda del médico filtrada a una ventana de 7 días,
  /// agrupada por día y ordenada cronológicamente.
  ///
  /// Endpoint: GET /api/programacion/horario-medico-movil/1/1/{idMedico}
  Future<List<HorarioDia>> getHorario({required int idMedico}) async {
    final response = await _api.get(
      ApiConstants.horarioMedicoMovil(_idins, _idsuc, idMedico),
    );
    return switch (response) {
      ApiSuccess(:final data) => () {
          final list = data is List
              ? data
              : (data is Map ? data['data'] as List? ?? [] : []);
          final raw = list.whereType<Map<String, dynamic>>().toList();

          // Si la respuesta trae `iddia`/`dia` sin `fecha`, calculamos la
          // próxima fecha de ese día de la semana a partir de hoy.
          final slots = raw.map((json) {
            final hasFecha = (json['fecha'] ?? '').toString().isNotEmpty;
            if (hasFecha) return HorarioMovilSlot.fromJson(json);

            final iddia = int.tryParse(json['iddia']?.toString() ?? '') ?? 0;
            final fechaCalculada = iddia > 0 ? _nextWeekday(iddia) : '';
            final augmented = Map<String, dynamic>.from(json)
              ..['fecha'] = fechaCalculada;
            return HorarioMovilSlot.fromJson(augmented);
          }).where((s) => s.fecha.isNotEmpty).toList();

          return _groupByDay(slots);
        }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  /// Devuelve la fecha (yyyy-MM-dd) de la próxima ocurrencia del [iddia] dado.
  /// [iddia]: 1=Lunes, 2=Martes, ... 7=Domingo (ISO weekday).
  static String _nextWeekday(int iddia) {
    final today = DateTime.now();
    for (int offset = 0; offset <= 7; offset++) {
      final candidate = today.add(Duration(days: offset));
      if (candidate.weekday == iddia) {
        return '${candidate.year.toString().padLeft(4, '0')}-'
            '${candidate.month.toString().padLeft(2, '0')}-'
            '${candidate.day.toString().padLeft(2, '0')}';
      }
    }
    return '';
  }

  // ── Lógica de negocio: ventana de 7 días ─────────────────────────────────

  /// Filtra los slots para mostrar solo los comprendidos entre hoy
  /// y exactamente 7 días en el futuro (inclusive ambos extremos).
  static List<HorarioMovilSlot> _applyVentana7d(List<HorarioMovilSlot> slots) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 7));

    return slots.where((s) {
      final raw = s.date;
      if (raw == null) return false;
      final d = DateTime(raw.year, raw.month, raw.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
  }

  /// Agrupa los slots por fecha en objetos [HorarioDia].
  static List<HorarioDia> _groupByDay(List<HorarioMovilSlot> slots) {
    final Map<String, List<HorarioMovilSlot>> map = {};
    for (final s in slots) {
      map.putIfAbsent(s.fecha, () => []).add(s);
    }
    return map.entries
        .map((e) => HorarioDia(
              fecha: e.key,
              dia: e.value.first.dia,
              slots: e.value,
            ))
        .toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
  }
}
