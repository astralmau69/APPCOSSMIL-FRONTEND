import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/models/doctor_agenda_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
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
    try {
      final bs = widget.tabShell.bookingState;
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
              return FadeSlideIn(
                offsetY: 12,
                child: Padding(
                  padding: EdgeInsets.only(bottom: r.spaceMd),
                  child: _buildDoctorCard(_medicos[i], isDark, r),
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
    final photoBytes = doctor.photoBytes;

    return OptimizedPressButton(
      onTap: () => _onDoctorSelected(doctor),
      scaleDown: 0.98,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(r.cardRadius),
          border: Border.all(color: AppColors.cardBorder(isDark), width: 0.8),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Padding(
          padding: EdgeInsets.all(r.cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Foto del médico
              _buildAvatar(photoBytes, doctor.medico, isDark, r),
              SizedBox(width: r.spaceMd),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.medico,
                      style: context.texts.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryC(isDark),
                        height: 1.2,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (doctor.mtrmin.isNotEmpty) ...[
                      SizedBox(height: r.spaceXs),
                      Text(
                        'Matrícula prof.: ${doctor.mtrmin}',
                        style: context.texts.bodySmall.copyWith(
                          color: AppColors.textSecondaryC(isDark),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Botón de favorito OCULTO (feature aún no funcional).
              SizedBox(width: r.spaceSm),
              Icon(
                CupertinoIcons.chevron_right,
                size: r.iconSm,
                color: AppColors.textTertiaryC(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    Uint8List? bytes,
    String name,
    bool isDark,
    AppResponsive r,
  ) {
    final size = r.listAvatarSize * 1.3;
    Widget content;

    if (bytes != null) {
      content = ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _buildInitials(name, size, isDark, r),
        ),
      );
    } else {
      content = _buildInitials(name, size, isDark, r);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? AppColors.darkElevated : AppColors.primaryLight,
      ),
      child: content,
    );
  }

  Widget _buildInitials(
    String name,
    double size,
    bool isDark,
    AppResponsive r,
  ) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty ? parts[0][0].toUpperCase() : '?');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r.radiusMd),
        color: AppColors.primary.withValues(alpha: 0.12),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.32,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
