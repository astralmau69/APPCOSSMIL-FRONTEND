import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/models/reserva_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/session/user_session.dart';
import '../../../core/widgets/appointment_card.dart';
import '../../../core/widgets/app_state_widget.dart';

class ReservasScreen extends StatefulWidget {
  const ReservasScreen({super.key});

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen> {
  final _service = ProgramacionService();

  List<ReservaModel> _history = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalElements = 0;
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _fetchReservas();
  }

  Future<void> _fetchReservas({bool loadMore = false}) async {
    if (!mounted) return;

    if (loadMore) {
      if (_currentPage >= _totalPages || _isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
      });
    }

    try {
      final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
      final page = loadMore ? _currentPage + 1 : 1;
      final result = await _service.getHistorialCitas(
        idper,
        pagina: page,
        cantidad: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _history.addAll(result.reservas);
          _isLoadingMore = false;
        } else {
          _history = result.reservas;
          _isLoading = false;
        }
        _currentPage = page;
        _totalPages = result.totalPages;
        _totalElements = result.totalElements;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _isLoadingMore = false;
        } else {
          _errorMessage = 'No se pudo cargar el historial de reservas.';
          _isLoading = false;
        }
      });
    }
  }

  int get _completedCount =>
      _history.where((a) => a.status == 'Completado').length;

  int get _missedCount =>
      _history.where((a) => a.status == 'Falta').length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return CupertinoPageScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: const AppStateWidget.loading(),
      );
    }

    if (_errorMessage != null) {
      return CupertinoPageScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: AppStateWidget.error(
          title: 'Error',
          message: _errorMessage!,
          onRetry: _fetchReservas,
        ),
      );
    }

    if (_history.isEmpty) {
      return _emptyState(context, isDark);
    }

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ── iOS Large Title Nav Bar ─────────────────────────
          CupertinoSliverNavigationBar(
            largeTitle: Text('Mis Reservas',
                style: TextStyle(color: AppColors.textPrimaryC(isDark))),
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

          // ── Headers ────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeSlideIn(
                  duration: const Duration(milliseconds: 350),
                  child: _buildSummaryBar(
                      context, _completedCount, _missedCount, isDark),
                ),
                FadeSlideIn(
                  duration: AppDurations.slow,
                  delay: const Duration(milliseconds: 100),
                  offsetY: 10,
                  child: _sectionHeader(
                      context, 'HISTORIAL DE ATENCIONES', _totalElements),
                ),
              ]),
            ),
          ),

          // ── Reservas List ───────────────────────────
          SliverPadding(
            padding:
                const EdgeInsets.only(bottom: 120, left: 12, right: 12),
            sliver: SliverList.builder(
              itemCount: _history.length + (_currentPage < _totalPages ? 1 : 0),
              itemBuilder: (context, index) {
                // Botón "Cargar más" al final
                if (index == _history.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: _isLoadingMore
                          ? const CupertinoActivityIndicator()
                          : CupertinoButton(
                              onPressed: () => _fetchReservas(loadMore: true),
                              child: Text(
                                'Cargar más',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentForTheme(isDark),
                                ),
                              ),
                            ),
                    ),
                  );
                }

                final shouldAnimate = index < 5;

                if (shouldAnimate) {
                  return Column(
                    children: [
                      FadeSlideIn(
                        delay:
                            Duration(milliseconds: 300 + (index * 100)),
                        duration: AppDurations.normal,
                        offsetY: 10,
                        child: AppointmentCard(
                            appointment: _history[index]),
                      ),
                      if (index < _history.length - 1)
                        const SizedBox(height: 10),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      AppointmentCard(appointment: _history[index]),
                      if (index < _history.length - 1)
                        const SizedBox(height: 10),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Summary bar: Completados / Faltas.
  Widget _buildSummaryBar(
      BuildContext context, int completed, int missed, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: AppColors.cardShadowFor(isDark),
        border: Border.all(
            color:
                isDark ? AppColors.cardBorder(isDark) : Colors.transparent,
            width: 0.5),
      ),
      child: Row(
        children: [
          _summaryChip(
              '$completed', 'Completados', AppColors.accent,
              isDark: isDark),
          Container(
              width: 0.5,
              height: 28,
              color: AppColors.dividerC(isDark)),
          _summaryChip(
            '$missed',
            missed == 1 ? 'Falta' : 'Faltas',
            isDark ? AppColors.white : const Color(0xFF9333EA),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String count, String label, Color color,
      {required bool isDark}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: AppTypography.displayMedium.copyWith(
              color: color,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondaryC(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: isDark ? AppColors.white : AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondaryC(isDark),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.white.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.white : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, bool isDark) {
    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Mis Reservas',
                style: TextStyle(color: AppColors.textPrimaryC(isDark))),
            backgroundColor: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.92)
                : AppColors.white.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color:
                    AppColors.cardBorder(isDark).withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          SliverFillRemaining(
            child: Center(
              child: FadeSlideIn(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.calendar,
                      size: 64,
                      color: AppColors.textTertiaryC(isDark)
                          .withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No tiene atenciones registradas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondaryC(isDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'El historial de atenciones aparecerá aquí',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiaryC(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
