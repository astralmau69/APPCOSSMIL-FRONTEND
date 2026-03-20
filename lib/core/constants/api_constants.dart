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

  /// Foto y datos básicos del asegurado por matrícula.
  static String aseguradoFoto(String matricula) =>
      '/api/safil/asegurado/foto/${matricula.trim()}';
}

