import '../config/app_config.dart';
import '../constants/api_constants.dart';
import '../models/regional_model.dart';
import '../models/specialty_model.dart';
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
      ApiSuccess(:final data) => _parseRegionales(data),
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
}
