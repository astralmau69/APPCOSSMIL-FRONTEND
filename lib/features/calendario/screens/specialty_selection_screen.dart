import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/models/specialty_model.dart';
import '../../../core/services/calendario_service.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/liquid_glass.dart';
import 'doctor_selection_screen.dart';

class SpecialtySelectionScreen extends StatefulWidget {
  final int idsuc;
  final String hospitalName;
  final String regionalName;

  const SpecialtySelectionScreen({
    super.key,
    required this.idsuc,
    required this.hospitalName,
    required this.regionalName,
  });

  @override
  State<SpecialtySelectionScreen> createState() =>
      _SpecialtySelectionScreenState();
}

class _SpecialtySelectionScreenState extends State<SpecialtySelectionScreen> {
  late final CalendarioService _service;

  List<SpecialtyModel> _specialties = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = CalendarioService(idsuc: widget.idsuc);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _service.getEspecialidades();
      if (!mounted) return;
      setState(() {
        _specialties = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e'.replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _onTap(SpecialtyModel specialty) {
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => DoctorSelectionScreen(
          specialty: specialty,
          idsuc: widget.idsuc,
          hospitalName: widget.hospitalName,
          regionalName: widget.regionalName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? Colors.transparent : AppColors.background,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Calendario',
        middle: Text(
          'Especialidades',
          style: TextStyle(
            color: AppColors.textPrimaryC(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.92)
            : AppColors.white.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder(isDark).withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: _buildBody(isDark, r),
      ),
    );
  }

  Widget _buildBody(bool isDark, AppResponsive r) {
    if (_isLoading) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceLg, r.paddingH, r.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoBanner(isDark, r),
            SizedBox(height: r.spaceLg),
            SkeletonSpecialtyList(count: 7),
          ],
        ),
      );
    }

    if (_error != null) {
      return AppStateWidget.error(
        title: 'No se pudo cargar las especialidades',
        message: _error,
        onRetry: _load,
      );
    }

    if (_specialties.isEmpty) {
      return const AppStateWidget.empty(
        title: 'Sin especialidades disponibles',
        message: 'No hay especialidades activas para ventanilla en este momento.',
        icon: CupertinoIcons.calendar_badge_minus,
      );
    }

    final filteredSpecialties = _searchQuery.isEmpty 
        ? _specialties 
        : _specialties.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: r.maxContentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceLg, r.paddingH, r.spaceXl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoBanner(isDark, r),
                    SizedBox(height: r.spaceLg),
                    CupertinoSearchTextField(
                      placeholder: 'Buscar especialidad...',
                      style: TextStyle(color: AppColors.textPrimaryC(isDark)),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    SizedBox(height: r.spaceLg),
                    _buildSectionHeader(isDark, r, filteredSpecialties.length),
                    SizedBox(height: r.spaceSm),
                    _buildSpecialtyCard(isDark, r, filteredSpecialties),
                    SizedBox(height: r.spaceXl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner(bool isDark, AppResponsive r) {
    return Container(
        padding: EdgeInsets.all(r.cardPadding),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkCard.withValues(alpha: 0.7)
              : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(r.radiusMd),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder
                : AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentForTheme(isDark).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(r.radiusSm),
            ),
            child: Icon(
              CupertinoIcons.building_2_fill,
              color: AppColors.accentForTheme(isDark),
              size: 18,
            ),
          ),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.hospitalName,
                  style: context.texts.titleMedium.copyWith(
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
                Text(
                  '${widget.regionalName} · Consulta en Ventanilla',
                  style: context.texts.bodySmall.copyWith(
                    color: AppColors.textSecondaryC(isDark),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r.spaceSm),
          Icon(
            CupertinoIcons.chevron_left,
            size: 16,
            color: AppColors.textTertiaryC(isDark),
          ),
        ],
      ),
    ); // end Container
  }

  Widget _buildSectionHeader(bool isDark, AppResponsive r, int count) {
    return Row(
      children: [
        Container(
          width: r.sectionBarWidth,
          height: r.sectionBarHeight,
          decoration: BoxDecoration(
            color: AppColors.accentForTheme(isDark),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: r.spaceSm),
        Expanded(
          child: Text(
            'ESPECIALIDADES DISPONIBLES',
            style: context.texts.labelSmall.copyWith(
              color: AppColors.textTertiaryC(isDark),
              letterSpacing: 0.8,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: context.texts.labelSmall.copyWith(
            color: AppColors.accentForTheme(isDark),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialtyCard(bool isDark, AppResponsive r, List<SpecialtyModel> items) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: r.spaceMd),
        child: Text(
          'Ninguna especialidad coincide con su búsqueda.',
          style: TextStyle(color: AppColors.textTertiaryC(isDark)),
        ),
      );
    }
    return LiquidGlass(
      isDark: isDark,
      borderRadius: BorderRadius.circular(r.cardRadius),
      shadow: AppColors.cardShadowFor(isDark),
      child: Column(
        children: List.generate(items.length, (i) {
          final sp = items[i];
          final isLast = i == items.length - 1;
          return FadeSlideIn(
            delay: Duration(milliseconds: 40 + i * 35),
            offsetY: 8,
            child: Column(
              children: [
                _SpecialtyTile(
                  specialty: sp,
                  index: i,
                  isDark: isDark,
                  onTap: () => _onTap(sp),
                ),
                if (!isLast)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.cardPadding),
                    child: Container(height: 0.5, color: AppColors.dividerC(isDark)),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── Tile individual de especialidad ──────────────────────────────────────────

class _SpecialtyTile extends StatelessWidget {
  final SpecialtyModel specialty;
  final int index;
  final bool isDark;
  final VoidCallback onTap;

  const _SpecialtyTile({
    required this.specialty,
    required this.index,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final color = _colorForIndex(index, isDark);
    final icon = _iconForName(specialty.name);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: r.tileHorizontalPad,
          vertical: r.tileVerticalPad,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: r.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    specialty.name,
                    style: context.texts.titleMedium.copyWith(
                      color: AppColors.textPrimaryC(isDark),
                    ),
                  ),
                  if (specialty.description.isNotEmpty)
                    Text(
                      specialty.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall.copyWith(
                        color: AppColors.textSecondaryC(isDark),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: r.spaceSm),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.textTertiaryC(isDark),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForName(String name) {
    final n = name.toLowerCase();
    if (n.contains('cardio')) return CupertinoIcons.heart_fill;
    if (n.contains('pediatr')) return CupertinoIcons.person_2_fill;
    if (n.contains('ginec') || n.contains('obstet')) return CupertinoIcons.person_fill;
    if (n.contains('traumat') || n.contains('ortop')) return CupertinoIcons.bandage_fill;
    if (n.contains('neurol')) return CupertinoIcons.waveform_path;
    if (n.contains('oftalm') || n.contains('ocul')) return CupertinoIcons.eye_fill;
    if (n.contains('dermat')) return CupertinoIcons.paintbrush_fill;
    if (n.contains('odonto') || n.contains('dental')) return CupertinoIcons.smiley_fill;
    if (n.contains('psiquiat') || n.contains('psicol')) return CupertinoIcons.person_circle_fill;
    if (n.contains('ciru')) return CupertinoIcons.scissors_alt;
    if (n.contains('radiol') || n.contains('imagen')) return CupertinoIcons.photo_fill;
    if (n.contains('neumol') || n.contains('pulmon')) return CupertinoIcons.wind;
    if (n.contains('gastro')) return CupertinoIcons.layers_fill;
    if (n.contains('endocrin') || n.contains('diabet')) return CupertinoIcons.chart_bar_fill;
    if (n.contains('urolog')) return CupertinoIcons.drop_fill;
    return CupertinoIcons.heart_circle_fill;
  }

  static const List<Color> _palette = [
    Color(0xFF3B82F6), // blue
    Color(0xFF10B981), // green
    Color(0xFFF59E0B), // amber
    Color(0xFF8B5CF6), // violet
    Color(0xFFEC4899), // pink
    Color(0xFF06B6D4), // cyan
    Color(0xFF6366F1), // indigo
    Color(0xFFEF4444), // red
    Color(0xFF14B8A6), // teal
    Color(0xFFF97316), // orange
  ];

  static Color _colorForIndex(int i, bool isDark) {
    final base = _palette[i % _palette.length];
    return isDark ? base.withValues(alpha: 0.85) : base;
  }
}
