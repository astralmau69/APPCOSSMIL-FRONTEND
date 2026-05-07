import '../models/beneficiary_model.dart';
import '../models/regional_model.dart';
import '../models/specialty_model.dart';
import '../services/programacion_service.dart';
import '../session/user_session.dart';
import '../utils/app_logger.dart';
import 'app_session_cache.dart';

/// Orquesta la precarga paralela de los 4 recursos de inicio de sesión.
///
/// ### Uso
/// ```dart
/// await InitialDataOrchestrator().loadAll();
/// // Los datos quedan en AppSessionCache para toda la sesión.
/// ```
///
/// ### Tolerancia a fallos
/// [grupoFamiliar] y [especialidades] son tolerantes: si fallan, guardan
/// lista vacía y no bloquean el inicio. [regionales] y [fechaServidor]
/// propagan excepción porque son críticos para el flujo de reserva.
class InitialDataOrchestrator {
  static const _tag = 'InitialDataOrchestrator';

  final ProgramacionService _programacion;

  InitialDataOrchestrator({ProgramacionService? programacion})
      : _programacion = programacion ?? ProgramacionService();

  // ─── Punto de entrada ────────────────────────────────────────────────────

  /// Lanza las 4 peticiones simultáneamente con [Future.wait].
  ///
  /// - Si todo va bien → guarda resultados en [AppSessionCache], `isLoaded = true`.
  /// - Si alguna falla  → lanza la excepción original para que [LoadingDataScreen]
  ///   la intercepte y ofrezca "Reintentar".
  Future<void> loadAll() async {
    AppLogger.info(_tag, 'Iniciando precarga paralela de datos de sesión…');
    final sw = Stopwatch()..start();

    final results = await Future.wait<dynamic>([
      _loadGrupoFamiliar(),   // índice 0
      _loadRegionales(),      // índice 1
      _loadEspecialidades(),  // índice 2
      _loadFechaServidor(),   // índice 3
    ]).timeout(const Duration(seconds: 15));

    sw.stop();
    AppLogger.info(_tag, 'Precarga completada en ${sw.elapsedMilliseconds} ms');

    AppSessionCache.grupoFamiliar  = results[0] as List<BeneficiaryModel>;
    AppSessionCache.regionales     = results[1] as List<RegionalModel>;
    AppSessionCache.especialidades = results[2] as List<SpecialtyModel>;
    AppSessionCache.fechaServidor  = results[3] as Map<String, String>;
    AppSessionCache.isLoaded = true;
  }

  // ─── Métodos de carga reales ─────────────────────────────────────────────

  /// Grupo familiar del asegurado titular.
  /// Tolerante: si falla retorna lista vacía (se puede rellenar on-demand
  /// en [TabShell._tryEnterBookingTab]).
  Future<List<BeneficiaryModel>> _loadGrupoFamiliar() async {
    final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
    if (idper == 0) {
      AppLogger.warn(_tag, 'idper=0, se omite carga de grupo familiar');
      return [];
    }
    try {
      final members = await _programacion.getGrupoFamiliar(idper);
      AppLogger.info(_tag, 'Grupo familiar: ${members.length} miembros');
      return members;
    } catch (e) {
      // No crítico: el flujo de reserva puede recargar el grupo familiar
      // cuando el usuario abre el selector de beneficiario.
      AppLogger.warn(_tag, 'Grupo familiar no disponible (se reintentará on-demand)', e);
      return [];
    }
  }

  /// Regionales / hospitales disponibles para reserva.
  /// idins=1 siempre (institución COSSMIL).
  Future<List<RegionalModel>> _loadRegionales() async {
    final list = await _programacion.getRegionalesPorDepartamento(1);
    AppLogger.info(_tag, 'Regionales: ${list.length} regionales');
    return list;
  }

  /// Especialidades médicas directas del Hospital Central La Paz (idins=1, idsuc=1).
  /// Se usa como caché base; cada pantalla puede refetch para su sucursal específica.
  /// Tolerante: si falla retorna lista vacía.
  Future<List<SpecialtyModel>> _loadEspecialidades() async {
    try {
      final list = await _programacion.getEspecialidadesDirectas(1, 1);
      AppLogger.info(_tag, 'Especialidades: ${list.length} especialidades');
      return list;
    } catch (e) {
      AppLogger.warn(_tag, 'Especialidades no disponibles (se cargarán por hospital)', e);
      return [];
    }
  }

  /// Fecha del servidor (para cálculo de fecha de cita disponible).
  Future<Map<String, String>> _loadFechaServidor() async {
    final fecha = await _programacion.getFechaServidor();
    AppLogger.info(_tag, 'Fecha servidor: ${fecha['fechaServidor']}');
    return fecha;
  }
}
