import '../models/beneficiary_model.dart';
import '../models/regional_model.dart';
import '../models/specialty_model.dart';
import '../utils/app_logger.dart';
import 'app_session_cache.dart';

// ── Cuando vayas a reemplazar los mocks, descomenta estas importaciones ────────
// import '../services/programacion_service.dart';
// import '../session/user_session.dart';

/// Orquesta la precarga paralela de los 4 recursos de inicio de sesión.
///
/// ### Uso
/// ```dart
/// await InitialDataOrchestrator().loadAll();
/// // Los datos quedan en AppSessionCache para toda la sesión.
/// ```
///
/// ### Tolerancia a fallos
/// Si cualquier servicio lanza una excepción, [loadAll] la propaga
/// inmediatamente (gracias a [Future.wait]). La pantalla [LoadingDataScreen]
/// intercepta ese error y ofrece al usuario un botón de "Reintentar".
///
/// ### Reemplazar los mocks
/// Cada método privado `_load*` contiene un `TODO` con la llamada HTTP real.
/// Cuando el backend esté listo, simplemente reemplaza el bloque `Future.delayed`
/// por la llamada al servicio correspondiente.
class InitialDataOrchestrator {
  static const _tag = 'InitialDataOrchestrator';

  // Inyección opcional de servicios para facilitar tests unitarios.
  // final ProgramacionService _programacion;
  // InitialDataOrchestrator({ProgramacionService? programacion})
  //     : _programacion = programacion ?? ProgramacionService();

  // ─── Punto de entrada ────────────────────────────────────────────────────

  /// Lanza las 4 peticiones simultáneamente con [Future.wait].
  ///
  /// - Si todo va bien → guarda resultados en [AppSessionCache.isLoaded = true].
  /// - Si alguna falla → lanza la excepción original sin silenciarla.
  Future<void> loadAll() async {
    AppLogger.info(_tag, 'Iniciando precarga paralela de datos de sesión…');
    final sw = Stopwatch()..start();

    // Las 4 peticiones se lanzan al mismo tiempo. Future.wait espera a que
    // TODAS terminen; si cualquiera falla, cancela y propaga el error.
    // El timeout de 15 s es la red real máxima tolerable; la pantalla
    // tiene su propio timeout de 20 s como segunda línea de defensa.
    final results = await Future.wait<dynamic>([
      _loadGrupoFamiliar(),    // índice 0
      _loadRegionales(),       // índice 1
      _loadEspecialidades(),   // índice 2
      _loadFechaServidor(),    // índice 3
    ]).timeout(const Duration(seconds: 15));

    sw.stop();
    AppLogger.info(_tag, 'Precarga completada en ${sw.elapsedMilliseconds} ms');

    AppSessionCache.grupoFamiliar  = results[0] as List<BeneficiaryModel>;
    AppSessionCache.regionales     = results[1] as List<RegionalModel>;
    AppSessionCache.especialidades = results[2] as List<SpecialtyModel>;
    AppSessionCache.fechaServidor  = results[3] as Map<String, String>;
    AppSessionCache.isLoaded = true;
  }

  // ─── Métodos stub — reemplaza el body con tu llamada HTTP real ────────────

  /// Grupo familiar del asegurado.
  ///
  /// TODO: reemplazar con:
  /// ```dart
  /// final idper = int.parse(UserSession.currentUser.id);
  /// return ProgramacionService().getGrupoFamiliar(idper);
  /// ```
  Future<List<BeneficiaryModel>> _loadGrupoFamiliar() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return [];
  }

  /// Regionales / Hospital asociado al usuario.
  ///
  /// TODO: reemplazar con:
  /// ```dart
  /// final idins = <obtener de UserSession o un config>;
  /// return ProgramacionService().getRegionales(idins);
  /// ```
  Future<List<RegionalModel>> _loadRegionales() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [];
  }

  /// Especialidades médicas directas.
  ///
  /// TODO: reemplazar con:
  /// ```dart
  /// return ProgramacionService().getEspecialidadesDirectas(idins, idsuc);
  /// ```
  Future<List<SpecialtyModel>> _loadEspecialidades() async {
    await Future.delayed(const Duration(milliseconds: 700));
    return [];
  }

  /// Fecha del servidor (para cálculo de citas).
  ///
  /// TODO: reemplazar con:
  /// ```dart
  /// return ProgramacionService().getFechaServidor();
  /// ```
  Future<Map<String, String>> _loadFechaServidor() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return {
      'fechaServidor': DateTime.now().toIso8601String(),
      'fechaCitaMovil': DateTime.now()
          .add(const Duration(days: 1))
          .toString()
          .split(' ')
          .first,
    };
  }
}
