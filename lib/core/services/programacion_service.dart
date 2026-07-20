import 'package:flutter/foundation.dart';
import '../utils/app_version_helper.dart';
import '../config/app_config.dart';
import '../constants/api_constants.dart';
import '../models/doctor_agenda_model.dart';
import '../models/time_slot_model.dart';
import '../models/beneficiary_model.dart';
import '../models/regional_model.dart';
import '../models/specialty_model.dart';
import '../models/horario_atencion_model.dart';
import '../models/medico_asignado_model.dart';
import '../models/detalle_cita_model.dart';
import '../models/reserva_model.dart';
import 'medsuc_photo_fallback.dart';
import '../mock/mock_regional_data.dart';
import '../mock/mock_reservas_data.dart';
import '../mock/mock_specialty_data.dart';
import 'api_client.dart';

/// Excepción lanzada cuando el backend rechaza explícitamente la versión de la app.
/// Distingue el rechazo de versión de errores de red/timeout para evitar
/// mostrar el diálogo de actualización cuando simplemente no hay conectividad.
class VersionOutdatedException implements Exception {
  final String message;
  const VersionOutdatedException(this.message);
  @override
  String toString() => message;
}

/// Servicio para endpoints de programación médica.
/// Respeta `AppConfig.useMockData` para desarrollo offline.
///
/// Cuando `useMockData` es false, usa [ApiClient] con Bearer token.
class ProgramacionService {
  final ApiClient _api;

  /// Caché en memoria de citas canceladas en la sesión actual.
  /// Previene que el historial rebote a "Pendiente" si el backend tarda en propagar el estado.
  static final Set<String> localCanceledIds = {};

  ProgramacionService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  // ── Verificar Versión ───────────────────────────────────────────────────

  /// Verifica si la versión de la app es válida según el backend.
  /// Lanza [VersionOutdatedException] SOLO cuando el backend rechaza explícitamente
  /// la versión (data.data == false). Errores de red/timeout retornan true para
  /// no bloquear al usuario innecesariamente.
  Future<bool> verificarVersion() async {
    if (AppConfig.useMockData) return true;

    try {
      // Usar AppVersionHelper para leer la versión real del APK/IPA.
      // versionSync devuelve el valor cacheado tras el primer getVersion() en LoadingDataScreen.
      final version = AppVersionHelper.versionSync;

      // ApiClient inyecta Bearer y refresca el token automáticamente en 401
      final response = await _api.get(ApiConstants.verificaVersion(version));

      return switch (response) {
        ApiSuccess(:final data) => () {
          if (data is Map<String, dynamic>) {
            final isOk = data['data'] == true;
            if (!isOk) {
              final msg =
                  data['message'] as String? ??
                  'Es necesario actualizar la versión del aplicativo.';
              throw VersionOutdatedException(msg);
            }
          }
          return true;
        }(),
        // Error de red, 401 sin refresh, etc. → no bloquear al usuario.
        ApiError() => true,
      };
    } on VersionOutdatedException {
      rethrow;
    } catch (_) {
      return true;
    }
  }

  // ── Médicos con agenda por especialidad (nuevo flujo CEX) ──────────────

  /// Lista de médicos para una especialidad.
  /// Endpoint: GET medico-especialidad-consulta/{idins}/{idsuc}/{idesp}
  ///
  /// [especialidadNombre] es opcional pero necesario para el fallback de
  /// fotos: `medico-especialidad-consulta` dejó de enviar `foto` en
  /// producción (confirmado en logs — ver `medsuc_photo_fallback.dart`), así
  /// que si viene el nombre y todas las fotos llegan vacías, se completan
  /// con una segunda llamada a `medsuc-buscar` (el endpoint que sí las trae),
  /// matcheando por `idmed`. Sin nombre, o si el fallback también falla, se
  /// devuelve la lista tal cual (los médicos igual se muestran, sin foto).
  Future<List<DoctorAgendaModel>> getMedicosPorEspecialidad({
    required int idins,
    required int idsuc,
    required int idesp,
    String? especialidadNombre,
  }) async {
    final response = await _api.get(
      ApiConstants.medicoEspecialidadConsulta(idins, idsuc, idesp),
    );
    var medicos = switch (response) {
      ApiSuccess(:final data) => () {
        final list = data is List
            ? data
            : (data is Map ? data['data'] as List? ?? [] : []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(DoctorAgendaModel.fromJson)
            .toList();
      }(),
      ApiError(:final message) => throw Exception(message),
    };

    final fotosAusentes =
        medicos.isNotEmpty && medicos.every((m) => m.foto.isEmpty);
    if (fotosAusentes &&
        especialidadNombre != null &&
        especialidadNombre.isNotEmpty) {
      final fotos = await fetchMedSucBuscarFotos(
        api: _api,
        idins: idins,
        idsuc: idsuc,
        especialidadNombre: especialidadNombre,
      );
      if (fotos.isNotEmpty) {
        medicos = medicos
            .map((m) => fotos.containsKey(m.idmed)
                ? m.copyWith(foto: fotos[m.idmed])
                : m)
            .toList();
      }
      if (kDebugMode) {
        final completadas = medicos.where((m) => m.foto.isNotEmpty).length;
        debugPrint(
          '📸 Fallback medsuc-buscar ($especialidadNombre): '
          '$completadas/${medicos.length} fotos completadas',
        );
      }
    }

    return medicos;
  }

  /// Lista de fechas de la agenda para un médico específico.
  /// Endpoint: agenda-medico-movil/{idins}/{idsuc}/{idmed}
  Future<List<DoctorAgendaModel>> getAgendaMedicoMovil({
    required int idins,
    required int idsuc,
    required String idmed,
  }) async {
    final response = await _api.get(
      ApiConstants.agendaMedicoMovil(idins, idsuc, idmed),
    );
    return switch (response) {
      ApiSuccess(:final data) => () {
        final list = data is List
            ? data
            : (data is Map ? data['data'] as List? ?? [] : []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(DoctorAgendaModel.fromJson)
            .toList();
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  /// Lista de médicos disponibles para una especialidad y fecha.
  /// Endpoint: medico-agenda-especialidad-cex/{idins}/{idsuc}/{fecha}/{idesp}
  Future<List<DoctorAgendaModel>> getMedicosAgenda({
    required int idins,
    required int idsuc,
    required String fecha,
    required int idesp,
  }) async {
    final response = await _api.get(
      ApiConstants.medicoAgendaEspecialidadCex(idins, idsuc, fecha, idesp),
    );
    return switch (response) {
      ApiSuccess(:final data) => () {
        final list = data is List
            ? data
            : (data is Map ? data['data'] as List? ?? [] : []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(DoctorAgendaModel.fromJson)
            .where(
              (d) => d.oferta > d.demanda,
            ) // médicos con al menos un cupo disponible (ope o ase)
            .toList();
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  /// Horas disponibles de una agenda específica.
  /// Endpoint: medico-agenda-fecha-horas/{idagenda}
  Future<List<TimeSlotModel>> getHorasAgenda(String idagenda) async {
    final response = await _api.get(
      ApiConstants.medicoAgendaFechaHoras(idagenda),
    );
    return switch (response) {
      ApiSuccess(:final data) => () {
        final list = data is List
            ? data
            : (data is Map ? data['data'] as List? ?? [] : []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(TimeSlotModel.fromAgendaHora)
            .toList();
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

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
        if (kDebugMode) debugPrint('📦 regionales raw response: $data');
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

  Future<List<SpecialtyModel>> getEspecialidadesInterconsulta(int idper) async {
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

  // ── Verificar validaciones de aportes ─────────────────────────────────

  /// Verifica si el asegurado tiene aportes vigentes (Art. 186 Ley SSML).
  /// Retorna `null` si puede atenderse, o el mensaje de error si no puede.
  Future<String?> verificarValidaciones(String matricula, int idper) async {
    if (AppConfig.useMockData) return null;
    if (matricula.isEmpty || idper == 0) return null;

    try {
      final response = await _api.get(
        ApiConstants.verificaValidaciones(matricula, idper),
      );

      return switch (response) {
        ApiSuccess(:final data) => () {
          if (data is Map<String, dynamic>) {
            final isOk = data['data'] == true;
            if (!isOk) {
              return data['message'] as String? ??
                  'No cuenta con aportes válidos para atención médica.';
            }
          }
          return null; // OK
        }(),
        ApiError(:final message) => message,
      };
    } catch (_) {
      return null; // Error de red → dejar pasar
    }
  }

  // ── Validar inasistencias (penalización por 3 faltas) ──────────────────

  /// Verifica si el asegurado está penalizado por acumular 3 inasistencias.
  ///
  /// El backend retorna `data:true` cuando está penalizado (debe reservar de
  /// forma presencial en ventanilla) y `data:false` cuando puede reservar
  /// normalmente. El `message` contiene el detalle de las faltas acumuladas.
  ///
  /// Retorna el mensaje de penalización si está bloqueado, o `null` si puede
  /// reservar. Ante un error de red devuelve `null` para no bloquear al usuario.
  Future<String?> validarInasistencias(int idper) async {
    if (AppConfig.useMockData) return null;
    if (idper == 0) return null;

    try {
      final response = await _api.get(ApiConstants.validarInasistencias(idper));

      return switch (response) {
        ApiSuccess(:final data) => () {
          if (data is Map<String, dynamic>) {
            final isPenalized = data['data'] == true;
            if (isPenalized) {
              return data['message'] as String? ??
                  'Ha acumulado tres (3) inasistencias. La obtención de '
                      'nuevas citas deberá realizarse de manera presencial '
                      'en ventanilla.';
            }
          }
          return null; // Sin penalización
        }(),
        ApiError() => null, // Error → dejar pasar
      };
    } catch (_) {
      return null; // Error de red → dejar pasar
    }
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
        if (kDebugMode) debugPrint('🔎 verificarHorario raw data: $data');
        if (kDebugMode) {
          debugPrint('🔎 verificarHorario parsed result: $result');
        }
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
          descripcion:
              'HORARIO DE ATENCION - PRIMER TURNO APP-MOVIL Y APLICATIVO WEB',
          horaini: '08:00:00',
          horafin: '12:00:00',
        ),
        const HorarioAtencionModel(
          idhorario: 3,
          descripcion:
              'HORARIO DE ATENCION - SEGUNDO TURNO APP-MOVIL Y APLICATIVO WEB',
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
        if (kDebugMode) debugPrint('📦 horarios-atencion raw response: $data');
        return _parseHorariosAtencion(data);
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Fecha del servidor ────────────────────────────────────────────────

  /// Obtiene la fecha del servidor, útil para determinar la fecha para citas médicas.
  /// Retorna un mapa con 'fechaServidor' y 'fechaCitaMovil'.
  Future<Map<String, String>> getFechaServidor() async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      return {
        'fechaServidor': DateTime.now().toIso8601String(),
        'fechaCitaMovil': DateTime.now()
            .add(const Duration(days: 1))
            .toString()
            .split(' ')
            .first,
      };
    }

    final response = await _api.get(ApiConstants.fechaServidor());

    return switch (response) {
      ApiSuccess(:final data) => () {
        if (data is Map<String, dynamic> &&
            data['data'] is Map<String, dynamic>) {
          final payload = data['data'] as Map<String, dynamic>;
          return {
            'fechaServidor': payload['fechaServidor']?.toString() ?? '',
            'fechaCitaMovil': payload['fechaCitaMovil']?.toString() ?? '',
          };
        }
        throw Exception('Formato de fecha inválido');
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Médico asignado ───────────────────────────────────────────────────

  /// Obtiene médico asignado con agenda y horas disponibles.
  /// [fecha] obtenida por getFechaServidor.
  Future<MedicoAsignadoModel> getMedicoAsignado(
    int idins,
    int idsuc,
    int idesp,
    String fecha,
    String modalidad,
  ) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      return const MedicoAsignadoModel(
        idagenda: 'mock-agenda-001',
        idesp: 42,
        idmed: '18',
        medico: 'VILLAGOMEZ POSTIGO MARIANELA',
        asignado: 3,
        estado: true,
        idcon: 3,
        descripcionConsultorio: 'CONSULTORIO 3 - PLANTA BAJA',
        dia: 'VIERNES',
        fecha: '2026-03-27',
        idcontrol: 'mock-control-123',
        horas: [
          HoraDisponibleModel(
            idhora: 'mock-1',
            numero: 5,
            hora: '09:00',
            estado: true,
          ),
          HoraDisponibleModel(
            idhora: 'mock-2',
            numero: 6,
            hora: '09:15',
            estado: true,
          ),
          HoraDisponibleModel(
            idhora: 'mock-3',
            numero: 7,
            hora: '09:30',
            estado: false,
          ),
        ],
      );
    }

    final response = await _api.get(
      ApiConstants.medicoAsignado(idins, idsuc, idesp, fecha, modalidad),
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

    final response = await _api.post(ApiConstants.crearCita(), body: payload);

    return switch (response) {
      ApiSuccess(:final data) => () {
        final body = data as Map<String, dynamic>;
        if (body['ok'] == false) {
          final msg =
              body['message'] as String? ??
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
      final all = MockReservasData.historial;
      final start = (pagina - 1) * cantidad;
      final end = start + cantidad > all.length ? all.length : start + cantidad;
      final page = start < all.length
          ? all.sublist(start, end)
          : <ReservaModel>[];
      return (
        reservas: page,
        totalElements: all.length,
        totalPages: (all.length / cantidad).ceil(),
      );
    }

    final response = await _api.get(
      ApiConstants.historialCitas(idper, pagina, cantidad),
    );

    return switch (response) {
      ApiSuccess(:final data) => () {
        if (kDebugMode) debugPrint('📦 historial-citas raw response: $data');
        final List<ReservaModel> reservas = _parseReservas(data);
        // Extraer paginación
        int totalElements = 0;
        int totalPages = 0;
        if (data is Map<String, dynamic> && data['pagination'] is Map) {
          final pag = data['pagination'] as Map<String, dynamic>;
          totalElements = pag['totalElements'] as int? ?? 0;
          totalPages = pag['totalPages'] as int? ?? 0;
        }
        return (
          reservas: reservas,
          totalElements: totalElements,
          totalPages: totalPages,
        );
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  /// Obtiene el historial de citas CANCELADAS del asegurado (paginado).
  ///
  /// Retorna un record con la lista de reservas y los datos de paginación.
  Future<({List<ReservaModel> reservas, int totalElements, int totalPages})>
  getHistorialCitasCanceladas(
    int idper, {
    int pagina = 1,
    int cantidad = 10,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      // Filtramos o devolvemos una sublista simulada
      return (reservas: <ReservaModel>[], totalElements: 0, totalPages: 0);
    }

    final response = await _api.get(
      ApiConstants.historialCitasCanceladas(idper, pagina, cantidad),
    );

    return switch (response) {
      ApiSuccess(:final data) => () {
        if (kDebugMode) {
          debugPrint('📦 historial-citas-canceladas raw response: $data');
        }
        final List<ReservaModel> reservas = _parseReservas(data);
        // Extraer paginación
        int totalElements = 0;
        int totalPages = 0;
        if (data is Map<String, dynamic> && data['pagination'] is Map) {
          final pag = data['pagination'] as Map<String, dynamic>;
          totalElements = pag['totalElements'] as int? ?? 0;
          totalPages = pag['totalPages'] as int? ?? 0;
        }
        return (
          reservas: reservas,
          totalElements: totalElements,
          totalPages: totalPages,
        );
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Detalle de cita médica ──────────────────────────────────────────

  /// Obtiene el detalle completo de una cita médica.
  Future<DetalleCitaModel> getDetalleCitaMedica({
    required int gestion,
    required int idins,
    required int idsuc,
    required int idtran,
    required int dr,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      // Buscar la reserva mock que coincida y generar detalle
      final match = MockReservasData.historial.where(
        (r) => r.idtran == idtran && r.dr == dr,
      );
      if (match.isNotEmpty) {
        return MockReservasData.detalleFromReserva(match.first);
      }
      // Fallback genérico
      return MockReservasData.detalleFromReserva(
        MockReservasData.historial.first,
      );
    }

    final response = await _api.get(
      ApiConstants.detalleCitaMedica(gestion, idins, idsuc, idtran, dr),
    );

    return switch (response) {
      ApiSuccess(:final data) => _parseDetalleCita(data),
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

  // ── Grupo familiar ──────────────────────────────────────────────────

  /// Obtiene el grupo familiar del asegurado desde el backend.
  Future<List<BeneficiaryModel>> getGrupoFamiliar(int idper) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      return [];
    }

    final response = await _api.get(ApiConstants.grupoFamiliar(idper));

    return switch (response) {
      ApiSuccess(:final data) => () {
        final list = _extractDataList(data);
        if (kDebugMode && list.isNotEmpty) {
          // Log sin fotos: el Base64 satura logcat y oculta el resto de campos.
          final sample = Map<String, dynamic>.of(
            list.first as Map<String, dynamic>,
          )..removeWhere((k, v) => v is String && v.length > 120);
          debugPrint('📦 grupo-familiar campos (sin fotos): $sample');
        }
        return list
            .map((e) => BeneficiaryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  // ── Parsers ─────────────────────────────────────────────────────────────

  /// Cancela una cita médica.
  ///
  /// El backend puede responder HTTP 200 con `{ ok: false, message: "...", errors: [...] }`
  /// cuando la cancelación no es posible (ej. fuera del plazo de 06:00 a.m.).
  /// En ese caso se lanza una excepción con el mensaje exacto del servidor.
  Future<bool> cancelarCita({
    required int gestion,
    required int idins,
    required int idsuc,
    required int idtran,
    required int dr,
    required String matricula,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 600));
      return true;
    }

    final response = await _api.put(
      ApiConstants.cancelarCitaMedica(
        gestion,
        idins,
        idsuc,
        idtran,
        dr,
        matricula,
      ),
    );

    return switch (response) {
      ApiSuccess(:final data) => () {
        // El backend puede devolver HTTP 200 con { ok: false, message: "..." }
        if (data is Map<String, dynamic> && data['ok'] == false) {
          // Preferir el primer error del arreglo errors, o el campo message
          final errors = data['errors'];
          final apiMsg = (errors is List && errors.isNotEmpty)
              ? errors.first.toString()
              : (data['message'] as String? ?? 'No se pudo cancelar la cita.');
          throw Exception(apiMsg);
        }
        localCanceledIds.add('${idtran}_$dr');
        return true;
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

  /// Registra la calificación del médico.
  ///
  /// Retorna:
  ///   - `null` si se registró exitosamente.
  ///   - Un [String] con el mensaje si ya existía calificación (estado 100)
  ///     u otro estado informativo del backend.
  /// Lanza [Exception] si hay error de red o servidor.
  Future<String?> calificarMedico({
    required String idmed,
    required int idesp,
    required String codadm,
    required int calificacion,
    required String obs,
    required String uc,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 600));
      return null;
    }

    final response = await _api.post(
      ApiConstants.medicoCalificacion(),
      body: {
        'idmed': idmed,
        'idesp': idesp,
        'codadm': codadm,
        'calificacion': calificacion,
        'obs': obs.isNotEmpty ? obs : 'SIN OBS',
        'uc': uc,
      },
    );

    return switch (response) {
      ApiSuccess(:final data) => () {
        // estado 100 = ya calificado
        if (data is Map<String, dynamic>) {
          final estado = data['estado'] ?? data['status'];
          if (estado == 100 || estado?.toString() == '100') {
            return data['mensaje']?.toString() ??
                data['message']?.toString() ??
                'Ya existe una calificación registrada para esta atención.';
          }
        }
        return null; // éxito
      }(),
      ApiError(:final message) => throw Exception(message),
    };
  }

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
      if (kDebugMode) {
        debugPrint(
          '🔎 _extractDataValue: body es Map, data=$data (${data.runtimeType})',
        );
      }
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
    if (kDebugMode) {
      debugPrint(
        '🔎 _extractDataValue: no se pudo extraer valor de $body (${body.runtimeType})',
      );
    }
    return null;
  }

  List<HorarioAtencionModel> _parseHorariosAtencion(dynamic body) {
    final list = _extractDataList(body);
    return list
        .map((e) => HorarioAtencionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  MedicoAsignadoModel _parseMedicoAsignado(dynamic body) {
    if (kDebugMode) debugPrint('📦 Parsing medico-asignado body: $body');
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (kDebugMode) debugPrint('   ↳ data field: $data');
      if (data is Map<String, dynamic>) {
        return MedicoAsignadoModel.fromJson(data);
      }
      // Si data es una lista, tomar el primer elemento
      if (data is List &&
          data.isNotEmpty &&
          data.first is Map<String, dynamic>) {
        if (kDebugMode) debugPrint('   ↳ data is a list, taking first element');
        return MedicoAsignadoModel.fromJson(data.first as Map<String, dynamic>);
      }
    }
    if (kDebugMode) {
      debugPrint(
        '   ⚠️ No hay datos válidos en la respuesta de médico asignado',
      );
    }
    throw Exception('Sin médico asignado para esta especialidad');
  }

  List<ReservaModel> _parseReservas(dynamic body) {
    final list = _extractDataList(body);
    return list.map((e) {
      var model = ReservaModel.fromJson(e as Map<String, dynamic>);
      if (localCanceledIds.contains('${model.idtran}_${model.dr}')) {
        model = model.copyWith(status: 'Cancelado');
      }
      return model;
    }).toList();
  }

  DetalleCitaModel _parseDetalleCita(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        if (kDebugMode) {
          debugPrint('🔍 detalle-cita keys: ${data.keys.toList()}');
          debugPrint('🔍 fotoMedico: ${data['fotoMedico']}');
          debugPrint('🔍 foto: ${data['foto']}');
          debugPrint('🔍 base64: ${data['base64']}');
        }
        return DetalleCitaModel.fromJson(data);
      }
    }
    throw Exception('No se pudo obtener el detalle de la cita');
  }
}
