import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/models/doctor_agenda_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../shell/tab_shell.dart';

class DoctorScreen extends StatefulWidget {
  final TabShellState tabShell;
  final VoidCallback? onNext;

  const DoctorScreen({super.key, required this.tabShell, this.onNext});

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

  Future<void> _loadMedicos() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final bs = widget.tabShell.bookingState;
      final idsuc = int.tryParse(bs.hospital?.id ?? '') ?? 0;
      final idesp = int.tryParse(bs.specialty?.id ?? '') ?? 0;

      // Obtener la fecha del servidor (mañana)
      final fecha = await _getFecha();

      final medicos = await _service.getMedicosAgenda(
        idins: 1,
        idsuc: idsuc,
        fecha: fecha,
        idesp: idesp,
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

  Future<String> _getFecha() async {
    try {
      final result = await _service.getFechaServidor();
      final fecha = result['fechaCitaMovil'] ?? '';
      if (fecha.isEmpty) throw Exception('fecha vacía');
      return fecha;
    } catch (_) {
      // Fallback a mañana local
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      return DateFormat('yyyy-MM-dd').format(tomorrow);
    }
  }

  void _onDoctorSelected(DoctorAgendaModel doctor) {
    final bs = widget.tabShell.bookingState;
    bs.doctor    = doctor.toDoctorModel();
    bs.idagenda  = doctor.idagenda;
    bs.idcon     = doctor.idcon;
    bs.idcontrol = ''; // el nuevo endpoint no lo provee

    if (widget.onNext != null) {
      widget.onNext!();
    }
  }

  String _formatFecha(String fecha) {
    try {
      final dt = DateFormat('yyyy-MM-dd').parse(fecha);
      final f  = DateFormat("EEEE d 'de' MMMM", 'es').format(dt);
      return f[0].toUpperCase() + f.substring(1);
    } catch (_) {
      return fecha;
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
      return AppStateWidget.empty(
        title: 'Sin médicos disponibles',
        message: 'No hay médicos con fichas disponibles para esta especialidad mañana.',
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
            padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceMd, r.paddingH, r.spaceSm),
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
                if (_medicos.isNotEmpty)
                  Text(
                    _formatFecha(_medicos.first.fecha),
                    style: context.texts.bodySmall.copyWith(
                      color: AppColors.textSecondaryC(isDark),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Lista de médicos
        SliverPadding(
          padding: EdgeInsets.fromLTRB(r.paddingH, 0, r.paddingH, r.navBarBottomSpace + 16),
          sliver: SliverList.builder(
            itemCount: _medicos.length,
            itemBuilder: (context, i) {
              return FadeSlideIn(
                delay: Duration(milliseconds: i * 60),
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

  Widget _buildDoctorCard(DoctorAgendaModel doctor, bool isDark, AppResponsive r) {
    final photoBytes = doctor.photoBytes;
    final noFichas = doctor.ase == 0;

    final cardContent = Opacity(
      opacity: noFichas ? 0.55 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(r.cardRadius),
          border: Border.all(
            color: AppColors.cardBorder(isDark),
            width: 0.8,
          ),
          boxShadow: (isDark || noFichas) ? [] : [
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: r.spaceXs),

                    // Consultorio
                    Row(
                      children: [
                        Icon(Icons.meeting_room_outlined, size: 13,
                            color: AppColors.textTertiaryC(isDark)),
                        SizedBox(width: r.spaceXs),
                        Expanded(
                          child: Text(
                            doctor.consultorio,
                            style: context.texts.bodySmall.copyWith(
                              color: AppColors.textSecondaryC(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.spaceXs),

                    // Horario
                    Row(
                      children: [
                        Icon(CupertinoIcons.clock, size: 13,
                            color: AppColors.textTertiaryC(isDark)),
                        SizedBox(width: r.spaceXs),
                        Text(
                          doctor.rangoHorario,
                          style: context.texts.bodySmall.copyWith(
                            color: AppColors.textSecondaryC(isDark),
                          ),
                        ),
                      ],
                    ),

                    // Sin fichas
                    if (noFichas) ...[
                      SizedBox(height: r.spaceSm),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.spaceXs + 2,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'Sin fichas disponibles',
                          style: context.texts.labelSmall.copyWith(
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: r.spaceSm),
                  ],
                ),
              ),

              // Flecha (solo si hay fichas)
              if (!noFichas) ...[
                SizedBox(width: r.spaceSm),
                Icon(CupertinoIcons.chevron_right,
                    size: r.iconSm, color: AppColors.textTertiaryC(isDark)),
              ],
            ],
          ),
        ),
      ),
    );

    if (noFichas) return cardContent;

    return OptimizedPressButton(
      onTap: () => _onDoctorSelected(doctor),
      scaleDown: 0.98,
      child: cardContent,
    );
  }

  Widget _buildAvatar(Uint8List? bytes, String name, bool isDark, AppResponsive r) {
    final size = r.listAvatarSize * 1.3;
    Widget content;

    if (bytes != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(r.radiusMd),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
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
        borderRadius: BorderRadius.circular(r.radiusMd),
        color: isDark ? AppColors.darkElevated : AppColors.primaryLight,
      ),
      child: content,
    );
  }

  Widget _buildInitials(String name, double size, bool isDark, AppResponsive r) {
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
