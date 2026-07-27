import '../models/beneficiary_model.dart';
import '../models/regional_model.dart';
import '../models/specialty_model.dart';
import '../services/programacion_service.dart';
import '../session/user_session.dart';
import '../utils/app_logger.dart';
import '../utils/error_mapper.dart';
import 'app_session_cache.dart';
import 'grupo_familiar_cache.dart';

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

  /// Tope para un recurso CRÍTICO (regionales, fecha de servidor). Si se agota,
  /// la carga LANZA `TimeoutException` → el inicio muestra "Reintentar" en vez
  /// de colgarse. Se corta antes del techo interno del [ApiClient]
  /// (15 s × reintentos) para fallar rápido y con un mensaje claro.
  static const _criticalTimeout = Duration(seconds: 12);

  /// Tope para un recurso NO crítico (grupo familiar, especialidades). Si se
  /// agota, la carga DEGRADA a lista vacía sin lanzar: un endpoint lento jamás
  /// debe impedir que el titular saque su cita. Se recuperan on-demand después.
  static const _nonCriticalTimeout = Duration(seconds: 8);

  final ProgramacionService _programacion;
  final GrupoFamiliarCache _grupoFamiliarCache;

  InitialDataOrchestrator({
    ProgramacionService? programacion,
    GrupoFamiliarCache? grupoFamiliarCache,
  }) : _programacion = programacion ?? ProgramacionService(),
       _grupoFamiliarCache = grupoFamiliarCache ?? GrupoFamiliarCache();

  // ─── Punto de entrada ────────────────────────────────────────────────────

  /// Lanza las 4 peticiones simultáneamente con [Future.wait].
  ///
  /// Cada carga se AUTO-LIMITA con su propio timeout (no hay un timeout global
  /// que, al vencer por un recurso lento no crítico, tumbe todo el arranque):
  /// - Críticas ([_loadRegionales], [_loadFechaServidor]) → lanzan al vencer →
  ///   [LoadingDataScreen] intercepta y ofrece "Reintentar".
  /// - No críticas ([_loadGrupoFamiliar], [_loadEspecialidades]) → degradan a
  ///   lista vacía al vencer/fallar → el inicio NUNCA se bloquea por ellas.
  ///
  /// Como los no críticos no lanzan, [Future.wait] solo se cae si falla un
  /// crítico — exactamente el comportamiento deseado.
  Future<void> loadAll() async {
    AppLogger.info(_tag, 'Iniciando precarga paralela de datos de sesión…');
    final sw = Stopwatch()..start();

    final results = await Future.wait<dynamic>([
      _loadGrupoFamiliar() // índice 0 — no crítico
          .timeout(
            _nonCriticalTimeout,
            onTimeout: () {
              AppLogger.warn(
                _tag,
                'Grupo familiar excedió ${_nonCriticalTimeout.inSeconds}s; se degrada a vacío',
              );
              return <BeneficiaryModel>[];
            },
          ),
      _loadRegionales() // índice 1 — crítico (lanza al vencer)
          .timeout(_criticalTimeout),
      _loadEspecialidades() // índice 2 — no crítico
          .timeout(
            _nonCriticalTimeout,
            onTimeout: () {
              AppLogger.warn(
                _tag,
                'Especialidades excedió ${_nonCriticalTimeout.inSeconds}s; se degrada a vacío',
              );
              return <SpecialtyModel>[];
            },
          ),
      _loadFechaServidor() // índice 3 — crítico (lanza al vencer)
          .timeout(_criticalTimeout),
    ]);

    sw.stop();
    AppLogger.info(_tag, 'Precarga completada en ${sw.elapsedMilliseconds} ms');

    AppSessionCache.grupoFamiliar = results[0] as List<BeneficiaryModel>;
    AppSessionCache.regionales = results[1] as List<RegionalModel>;
    AppSessionCache.especialidades = results[2] as List<SpecialtyModel>;
    AppSessionCache.fechaServidor = results[3] as Map<String, String>;
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
      // Refresca la caché offline cifrada (read-through).
      if (members.isNotEmpty) _grupoFamiliarCache.save(idper, members);
      return members;
    } catch (e) {
      // Sin conexión: usar la última copia cacheada para que el titular vea su
      // grupo familiar offline. Si no es error de red o no hay caché, se degrada
      // a vacío (no crítico: se recarga on-demand al abrir el selector).
      if (ErrorMapper.isOffline(e)) {
        final cached = await _grupoFamiliarCache.read(idper);
        if (cached != null) {
          AppLogger.info(
            _tag,
            'Grupo familiar desde caché offline: ${cached.miembros.length} miembros',
          );
          return cached.miembros;
        }
      }
      AppLogger.warn(
        _tag,
        'Grupo familiar no disponible (se reintentará on-demand)',
        e,
      );
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
      AppLogger.warn(
        _tag,
        'Especialidades no disponibles (se cargarán por hospital)',
        e,
      );
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
