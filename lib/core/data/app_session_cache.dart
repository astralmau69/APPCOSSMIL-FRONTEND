import '../models/beneficiary_model.dart';
import '../models/regional_model.dart';
import '../models/specialty_model.dart';

/// Cache en memoria de los datos precargados tras el login/biometría.
///
/// Poblado por [InitialDataOrchestrator.loadAll] a través de [LoadingDataScreen].
/// Consumido por Home, Booking, Perfil, etc. sin necesidad de volver a llamar
/// a la API. Se limpia en logout junto con [UserSession].
///
/// Patrón idéntico a [UserSession]: singleton de acceso estático, sin estado
/// reactivo, ya que los datos de inicio de sesión raramente cambian en la sesión.
class AppSessionCache {
  AppSessionCache._();

  // ─── Datos precargados ────────────────────────────────────────────────────

  /// Grupo familiar del asegurado (titular + beneficiarios).
  static List<BeneficiaryModel> grupoFamiliar = [];

  /// Regionales/hospitales disponibles para el usuario.
  static List<RegionalModel> regionales = [];

  /// Especialidades médicas directas disponibles.
  static List<SpecialtyModel> especialidades = [];

  /// Fechas del servidor: `fechaServidor` y `fechaCitaMovil`.
  static Map<String, String> fechaServidor = {};

  // ─── Estado ───────────────────────────────────────────────────────────────

  /// true cuando [InitialDataOrchestrator.loadAll] completó con éxito.
  static bool isLoaded = false;

  // ─── Limpieza ─────────────────────────────────────────────────────────────

  /// Llamar en logout para evitar que datos de un usuario persistan
  /// si otro inicia sesión en el mismo dispositivo.
  static void clear() {
    grupoFamiliar = [];
    regionales = [];
    especialidades = [];
    fechaServidor = {};
    isLoaded = false;
  }
}
