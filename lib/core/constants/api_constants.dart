import 'dart:convert';

class ApiConstants {
  // ─── Servidor ──────────────────────────────────────────────────────────────
  static const String baseUrl = 'http://10.150.10.13:9999';

  // ─── Endpoints ─────────────────────────────────────────────────────────────
  static const String tokenEndpoint = '/api/security/oauth/token';

  // ─── Credenciales del cliente OAuth2 (app, no del usuario) ─────────────────
  static const String _clientId = 'frontendapp';
  static const String _clientSecret = '12345';

  // Header Basic Auth generado en tiempo de ejecución
  static String get basicAuthHeader {
    final credentials = '$_clientId:$_clientSecret';
    final encoded = base64Encode(utf8.encode(credentials));
    return 'Basic $encoded';
  }

  // URL completa del endpoint de token
  static Uri get tokenUri => Uri.parse('$baseUrl$tokenEndpoint');

  // ─── Programación (endpoints protegidos con Bearer) ────────────────────────

  /// Regionales por departamento.
  static String regionalesPorDepartamento(int idins) =>
      '/api/programacion/regionales/departamento/$idins';

  /// Todas las regionales.
  static String regionales(int idins) =>
      '/api/programacion/regionales/$idins';

  /// Especialidades directas de una sucursal.
  static String especialidadesDirectas(int idins, int idsuc) =>
      '/api/programacion/especialidades/directas/$idins/$idsuc';

  /// Especialidades de interconsulta para un asegurado.
  static String especialidadesInterconsulta(int idper) =>
      '/api/programacion/especialidades/interconsulta/$idper';

  /// Verificar si hay horario de atención habilitado.
  /// Retorna el código de horario asignado (int) en `data`.
  static String verificarHorarioAtencion(int idins, int idsuc) =>
      '/api/programacion/verificar-horario-atencion/$idins/$idsuc/ASE';

  /// Horarios de atención habilitados para reserva.
  static String horariosAtencion(int idins, int idsuc) =>
      '/api/programacion/horarios-atencion/$idins/$idsuc';

  /// Médico asignado con agenda y horas disponibles.
  /// [fecha] formato yyyy-MM-dd (fecha de la cita, típicamente mañana).
  /// [idturno] es el código de turno/horario (idhorario del HorarioAtencionModel).
  static String medicoAsignado(int idins, int idsuc, int idesp, String fecha, String modalidad, int idturno) =>
      '/api/programacion/medico-asignado/$idins/$idsuc/$idesp/$fecha/$modalidad/$idturno';

  /// Crear cita médica (POST).
  static String crearCita() => '/api/programacion/crea-cita';

  /// Historial de citas de un asegurado (paginado).
  static String historialCitas(int idper, int nroPagina, int cantidadRegistros) =>
      '/api/programacion/historial-citas/$idper/$nroPagina/$cantidadRegistros';

  /// Detalle completo de una cita médica.
  static String detalleCitaMedica(int gestion, int idins, int idsuc, int idtran, int dr) =>
      '/api/programacion/detalle-cita-medica/$gestion/$idins/$idsuc/$idtran/$dr';

  /// PDF de cita médica generado por el backend.
  static String citaMedicaPdf(int gestion, int idins, int idsuc, int idtran, int dr) =>
      '/api/programacion/cita-medica-pdf/$gestion/$idins/$idsuc/$idtran/$dr';

  /// Foto y datos básicos del asegurado por matrícula.
  static String aseguradoFoto(String matricula) =>
      '/api/safil/asegurado/foto/${matricula.trim()}';
}

