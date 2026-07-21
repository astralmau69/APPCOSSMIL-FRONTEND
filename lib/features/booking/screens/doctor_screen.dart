import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/models/doctor_agenda_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../core/widgets/doctor_card.dart';
import '../../../core/widgets/guided_tap_hint.dart';
import '../../../shell/tab_shell.dart';
// Favoritos OCULTO (feature aún no funcional): imports comentados.
// import '../../../core/services/favorites_service.dart';
// import '../../../core/services/push_notification_service.dart';

class DoctorScreen extends StatefulWidget {
  final TabShellState tabShell;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  const DoctorScreen({
    super.key,
    required this.tabShell,
    this.onNext,
    this.onBack,
  });

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

/// Médicos ilustrativos para el modo tutorial — evita que la demo quede sin
/// salida si el hospital+especialidad real elegido no tiene médicos con
/// agenda abierta en este momento (un caso perfectamente posible y real,
/// pero que no debe interrumpir una demostración).
const _tutorialMedicos = [
  DoctorAgendaModel(
    idagenda: 'tutorial-agenda-1',
    idmed: 'tutorial-doc-1',
    idcon: 0,
    medico: 'Dr. Roberto Guzmán',
    dia: '',
    fecha: '',
    horaini: '',
    horafin: '',
    ase: 0,
    oferta: 0,
    demanda: 0,
    ope: 0,
    med: 0,
    adm: 0,
    foto: '',
    consultorio: 'Consultorio 204 - Planta Baja',
    mtrmin: '4521',
  ),
  DoctorAgendaModel(
    idagenda: 'tutorial-agenda-2',
    idmed: 'tutorial-doc-2',
    idcon: 0,
    medico: 'Dra. Fátima Rojas',
    dia: '',
    fecha: '',
    horaini: '',
    horafin: '',
    ase: 0,
    oferta: 0,
    demanda: 0,
    ope: 0,
    med: 0,
    adm: 0,
    foto: '',
    consultorio: 'Consultorio 108 - Primer Piso',
    mtrmin: '3897',
  ),
];

class _DoctorScreenState extends State<DoctorScreen> {
  final _service = ProgramacionService();

  List<DoctorAgendaModel> _medicos = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMedicos();
  }

  // ── Favoritos OCULTO (feature aún no funcional) ──────────────────────────
  // Se conserva la lógica comentada para reactivarla cuando esté lista.
  /*
  List<String> _favoriteDoctorIds = [];

  Future<void> _loadFavorites() async {
    final favs = await FavoritesService.getFavoriteDoctorIds();
    if (mounted) {
      setState(() {
        _favoriteDoctorIds = favs;
      });
    }
  }

  Future<void> _toggleFavorite(DoctorAgendaModel doctor) async {
    final doctorId = doctor.idmed;
    if (doctorId.isEmpty) return;
    try {
      final bs = widget.tabShell.bookingState;
      final specialtyName = bs.specialty?.name ?? '';

      final details = {
        'idmed': doctor.idmed,
        'medico': doctor.medico,
        'especialidad': specialtyName,
        'foto': doctor.foto,
        'mtrmin': doctor.mtrmin,
      };

      final isAdded = await FavoritesService.toggleFavorite(doctorId, details: details);

      if (isAdded) {
        await PushNotificationService.subscribeToDoctor(doctorId);
      } else {
        await PushNotificationService.unsubscribeFromDoctor(doctorId);
      }

      await _loadFavorites();

      if (mounted) {
        showAppDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(isAdded ? 'Médico Favorito' : 'Eliminado de Favoritos'),
            content: Text(isAdded
                ? 'Te notificaremos cuando se libere un turno con este médico.'
                : 'Ya no recibirás notificaciones para este médico.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Aceptar'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }
  */

  Future<void> _loadMedicos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final bs = widget.tabShell.bookingState;
    if (bs.isTutorialMode) {
      // Instantáneo y sin red: la demo nunca debe depender de que el
      // hospital+especialidad real elegido tenga médicos de verdad.
      setState(() {
        _medicos = _tutorialMedicos;
        _isLoading = false;
      });
      return;
    }

    try {
      final idsuc = int.tryParse(bs.hospital?.id ?? '') ?? 0;
      final idesp = int.tryParse(bs.specialty?.id ?? '') ?? 0;

      final medicos = await _service.getMedicosPorEspecialidad(
        idins: 1,
        idsuc: idsuc,
        idesp: idesp,
        especialidadNombre: bs.specialty?.name,
      );

      if (!mounted) return;
      setState(() {
        _medicos = medicos;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron cargar los médicos disponibles.';
        _isLoading = false;
      });
    }
  }

  void _onDoctorSelected(DoctorAgendaModel doctor) {
    final bs = widget.tabShell.bookingState;
    bs.doctor = doctor.toDoctorModel();

    if (widget.onNext != null) {
      widget.onNext!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final bs = widget.tabShell.bookingState;

    final breadcrumbs = [
      bs.beneficiaryLabel ?? 'Para mí',
      bs.regional?.name ?? '',
      bs.hospital?.name ?? '',
      bs.specialty?.name ?? '',
    ];

    if (_isLoading) {
      return const AppStateWidget.loading();
    }

    if (_errorMessage != null) {
      return AppStateWidget.error(
        title: 'Error',
        message: _errorMessage!,
        onRetry: _loadMedicos,
      );
    }

    if (_medicos.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: AppStateWidget.empty(
              title: 'Sin médicos disponibles',
              message:
                  'No hay médicos con agenda abierta para esta especialidad '
                  'en este establecimiento.',
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              r.paddingH,
              0,
              r.paddingH,
              r.navBarBottomSpace + r.spaceMd,
            ),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(r.radiusMd),
                onPressed: widget.onBack,
                child: const Text(
                  'Volver a Especialidades',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        // Breadcrumbs
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceSm, r.paddingH, 0),
            child: BreadcrumbChips(labels: breadcrumbs),
          ),
        ),

        // Cabecera
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              r.paddingH,
              r.spaceMd,
              r.paddingH,
              r.spaceSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Médicos disponibles',
                  style: context.texts.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Lista de médicos
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            r.paddingH,
            0,
            r.paddingH,
            r.navBarBottomSpace + 16,
          ),
          sliver: SliverList.builder(
            itemCount: _medicos.length,
            itemBuilder: (context, i) {
              final card = _buildDoctorCard(_medicos[i], isDark, r);
              return FadeSlideIn(
                offsetY: 12,
                child: Padding(
                  padding: EdgeInsets.only(bottom: r.spaceMd),
                  child: (bs.isTutorialMode && i == 0)
                      ? GuidedTapHint(child: card)
                      : card,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorCard(
    DoctorAgendaModel doctor,
    bool isDark,
    AppResponsive r,
  ) {
    // Botón de favorito OCULTO (feature aún no funcional): antes vivía a la
    // derecha de la tarjeta; DoctorCard no lo expone todavía.
    return DoctorCard(
      name: doctor.medico,
      photoBytes: doctor.photoBytes,
      subtitle: doctor.mtrmin.isNotEmpty ? 'Matrícula prof.: ${doctor.mtrmin}' : null,
      isDark: isDark,
      onTap: () => _onDoctorSelected(doctor),
    );
  }

}
