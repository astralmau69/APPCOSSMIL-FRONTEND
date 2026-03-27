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
  static String medicoAsignado(int idins, int idsuc, int idesp, String fecha, int idhorario) =>
      '/api/programacion/medico-asignado/$idins/$idsuc/$idesp/$fecha/ASE/$idhorario';

  /// Crear cita médica (POST).
  static String crearCita() => '/api/programacion/crea-cita';

  /// Historial de reservas de un asegurado.
  static String reservas(int idper) =>
      '/api/programacion/reservas/$idper/ASE';

  /// Foto y datos básicos del asegurado por matrícula.
  static String aseguradoFoto(String matricula) =>
      '/api/safil/asegurado/foto/${matricula.trim()}';
}

