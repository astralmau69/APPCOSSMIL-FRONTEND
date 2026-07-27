import 'dart:convert';

class ApiConstants {
  // ─── Servidor ──────────────────────────────────────────────────────────────
  // En builds normales (mobile/desktop/web directo) apunta al backend real.
  // El build web en Docker la sobreescribe a '' vía --dart-define=API_BASE_URL=
  // para que las peticiones salgan como rutas relativas (/api/...) y las
  // resuelva el proxy de nginx del mismo origen, evitando CORS en el navegador.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.cossmil.mil.bo',
  );
  //static const String baseUrl = 'http://10.150.10.13:9999';

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

  /// Verificación de versión de la aplicación.
  static String verificaVersion(String version) =>
      '/api/programacion/verifica-version/$version';

  /// Obtener fecha del servidor.
  static String fechaServidor() => '/api/programacion/fecha-servidor';

  /// Regionales por departamento.
  static String regionalesPorDepartamento(int idins) =>
      '/api/programacion/regionales/departamento/$idins';

  /// Todas las regionales.
  static String regionales(int idins) => '/api/programacion/regionales/$idins';

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

  /// Médico asignado con agenda y horas disponibles (flujo legacy).
  static String medicoAsignado(
    int idins,
    int idsuc,
    int idesp,
    String fecha,
    String modalidad,
  ) =>
      '/api/programacion/medico-asignado/$idins/$idsuc/$idesp/$fecha/$modalidad';

  /// Lista de médicos con agendas para una especialidad y fecha (nuevo flujo CEX).
  static String medicoAgendaEspecialidadCex(
    int idins,
    int idsuc,
    String fecha,
    int idesp,
  ) =>
      '/api/programacion/medico-agenda-especialidad-cex/$idins/$idsuc/$fecha/$idesp';

  /// Horas disponibles de una agenda específica por idagenda (nuevo flujo CEX).
  static String medicoAgendaFechaHoras(String idagenda) =>
      '/api/programacion/medico-agenda-fecha-horas/$idagenda';

  /// Crear cita médica (POST).
  static String crearCita() => '/api/programacion/crea-cita';

  /// Historial de citas de un asegurado (paginado).
  static String historialCitas(
    int idper,
    int nroPagina,
    int cantidadRegistros,
  ) => '/api/programacion/historial-citas/$idper/$nroPagina/$cantidadRegistros';

  /// Historial de citas canceladas de un asegurado (paginado).
  static String historialCitasCanceladas(
    int idper,
    int nroPagina,
    int cantidadRegistros,
  ) =>
      '/api/programacion/historial-citas-canceladas/$idper/$nroPagina/$cantidadRegistros';

  /// Detalle completo de una cita médica.
  static String detalleCitaMedica(
    int gestion,
    int idins,
    int idsuc,
    int idtran,
    int dr,
  ) =>
      '/api/programacion/detalle-cita-medica/$gestion/$idins/$idsuc/$idtran/$dr';

  /// PDF de cita médica generado por el backend.
  static String citaMedicaPdf(
    int gestion,
    int idins,
    int idsuc,
    int idtran,
    int dr,
  ) => '/api/programacion/cita-medica-pdf/$gestion/$idins/$idsuc/$idtran/$dr';

  /// Foto y datos básicos del asegurado por matrícula.
  static String aseguradoFoto(String matricula) =>
      '/api/safil/asegurado/foto/${matricula.trim()}';

  /// Datos enriquecidos del asegurado (foto2, tipopersonal, fuerza, tipo, etc.)
  static String aseguradoTipoGpo(String matricula) =>
      '/api/safil/asegurado/aseg-tipo-gpo/${matricula.trim()}';

  /// Cancelar una cita médica.
  /// [matricula]: matrícula del usuario que realiza la cancelación.
  ///   - Cuenta titular  → matrícula del titular (incluso si cancela cita de un familiar).
  ///   - Cuenta beneficiario → matrícula del beneficiario logueado.
  static String cancelarCitaMedica(
    int gestion,
    int idins,
    int idsuc,
    int idtran,
    int dr,
    String matricula,
  ) =>
      '/api/programacion/cancelar-cita-medica/$gestion/$idins/$idsuc/$idtran/$dr/$matricula';

  /// Grupo familiar de un asegurado.
  static String grupoFamiliar(int idper) =>
      '/api/safil/afiliado/gpo-familiar/$idper';

  /// Verificar validaciones de aportes del asegurado (Artículo 186 Ley SSML).
  /// Retorna data:true si puede atenderse, data:false si no tiene aportes vigentes.
  static String verificaValidaciones(String matricula, int idper) =>
      '/api/programacion/verifica-validaciones/$matricula/$idper';

  /// Validar inasistencias del asegurado (penalización por 3 faltas).
  /// Retorna data:true si está penalizado (debe reservar en ventanilla);
  /// data:false si no tiene penalización. El `message` detalla las faltas.
  static String validarInasistencias(int idper) =>
      '/api/programacion/validar-inasistencias/$idper';

  /// Actualizar datos de usuario (contraseña, correo, teléfono).
  static String updateUsuarioWeb(int idper) => '/api/usuarioweb/update/$idper';

  /// Cambiar solo la contraseña del usuario (PUT).
  static String changePassword(int idper) =>
      '/api/usuarioweb/change-password/$idper';

  /// Actualizar correo y teléfono del usuario (PUT).
  static String updateProfile(int idper) =>
      '/api/usuarioweb/update-profile/$idper';

  /// Registrar calificación del médico (POST).
  static String medicoCalificacion() => '/api/programacion/medico-calificacion';

  /// Actualizar datos personales del afiliado: teléfono de emergencia y referencia (PUT).
  static String actualizaDatosPer() => '/api/safil/afiliado/actualiza-datosper';

  // ─── Calendario de Atención (flujo ventanilla) ────────────────────────────

  /// Especialidades disponibles en ventanilla para una regional/sucursal.
  static String especialidadesVentanilla(int idins, int idsuc) =>
      '/api/programacion/especialidades/ventanilla/$idins/$idsuc';

  /// Horario semanal móvil de un médico (GET).
  static String horarioMedicoMovil(int idins, int idsuc, String idMedico) =>
      '/api/programacion/horario-medico-movil/$idins/$idsuc/$idMedico';

  /// Agenda móvil de un médico (GET).
  static String agendaMedicoMovil(int idins, int idsuc, String idmed) =>
      '/api/programacion/agenda-medico-movil/$idins/$idsuc/$idmed';

  /// Médicos por especialidad (GET).
  /// Reemplaza a medsuc-buscar para el flujo de reserva. OJO: en producción
  /// este endpoint dejó de enviar el campo `foto`; las fotos se recuperan
  /// con [medSucBuscar] como fallback.
  static String medicoEspecialidadConsulta(int idins, int idsuc, int idesp) =>
      '/api/programacion/medico-especialidad-consulta/$idins/$idsuc/$idesp';

  /// Buscar médicos de una sucursal por especialidad (POST, flujo antiguo).
  /// Se conserva SOLO como fuente de la foto del médico: es el único endpoint
  /// que sigue devolviéndola (medico-especialidad-consulta ya no la manda).
  static String medSucBuscar() => '/api/programacion/medsuc-buscar';

  // ─── Noticias ──────────────────────────────────────────────────────────────

  /// Detalles de una publicación (imágenes adicionales).
  static String publicationDetail(int gestion, int idpub) =>
      '/api/publicaciondet/$gestion/$idpub';

  /// Base para imágenes de publicaciones.
  static String newsImagesBase(int gestion, int idpub, String filename) =>
      'https://www.cossmil.mil.bo/api/publicsImg/$gestion/$idpub/$filename';
}
