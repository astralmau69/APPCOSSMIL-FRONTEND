import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/models/reserva_model.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/session/user_session.dart';

class _RatingLevel {
  final int level;
  final String emoji;
  final String title;
  final String timeCriteria;
  final String attentionCriteria;

  const _RatingLevel({
    required this.level,
    required this.emoji,
    required this.title,
    required this.timeCriteria,
    required this.attentionCriteria,
  });
}

const List<_RatingLevel> _ratingLevels = [
  _RatingLevel(
    level: 4,
    emoji: '😄',
    title: 'Excelente',
    timeCriteria: 'Puntualidad perfecta.',
    attentionCriteria: 'Máxima claridad, resolvió dudas y el trato fue excepcional.',
  ),
  _RatingLevel(
    level: 3,
    emoji: '🙂',
    title: 'Bueno',
    timeCriteria: 'Puntual: Entró a su hora exacta.',
    attentionCriteria: 'Diagnóstico claro y trato amable. Aprovechó bien el tiempo.',
  ),
  _RatingLevel(
    level: 2,
    emoji: '😐',
    title: 'Regular',
    timeCriteria: 'Retraso leve (5-10 min fuera de su turno).',
    attentionCriteria: 'Cumplió lo básico pero sin mucha interacción o detalle.',
  ),
  _RatingLevel(
    level: 1,
    emoji: '😠',
    title: 'Malo',
    timeCriteria: 'Retraso crítico o cita muy breve.',
    attentionCriteria: 'El médico no escuchó, fue rudo o no revisó al paciente.',
  ),
];

class DoctorRatingModal extends StatefulWidget {
  final ReservaModel reserva;
  final VoidCallback onDismiss;

  const DoctorRatingModal({
    super.key,
    required this.reserva,
    required this.onDismiss,
  });

  // ── Claves de persistencia ────────────────────────────────────────────────

  /// Se persiste cuando el modal fue mostrado al usuario (aunque lo omita).
  static String _offeredKey(ReservaModel r) =>
      'offered_reserva_${r.idtran}_${r.dr}';

  /// Se persiste cuando el usuario envió exitosamente una calificación.
  static String _ratedKey(ReservaModel r) =>
      'rated_reserva_${r.idtran}_${r.dr}';

  // ── Guardia de sesión ─────────────────────────────────────────────────────

  /// Evita que se apilen dos modales al mismo tiempo.
  static bool _isShowingModal = false;

  /// IDs de reservas ya ofrecidas en esta sesión (antes de que prefs persista).
  static final Set<String> _offeredThisSession = {};

  // ── API pública ───────────────────────────────────────────────────────────

  /// Retorna `true` si a esta reserva se le mostró el modal pero el usuario
  /// aún no envió una calificación. Usado internamente.
  static Future<bool> isOfferedButNotRated(ReservaModel reserva) async {
    final prefs = await SharedPreferences.getInstance();
    final offered = prefs.getBool(_offeredKey(reserva)) == true ||
        _offeredThisSession.contains(_offeredKey(reserva));
    final rated = prefs.getBool(_ratedKey(reserva)) == true;
    return offered && !rated;
  }

  /// Retorna `true` si la reserva puede ser calificada (no ha sido calificada aún).
  /// Usado para mostrar el botón "Calificar" en el historial.
  static Future<bool> isRatable(ReservaModel reserva) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ratedKey(reserva)) != true;
  }

  /// Muestra el modal automáticamente si la cita ya pasó (15 min de gracia)
  /// y no ha sido ofrecida/calificada. Solo se muestra UNA vez por sesión
  /// y UNA vez por reserva en toda la vida de la app.
  static Future<void> showIfNeeded(
    BuildContext context,
    ReservaModel reserva,
  ) async {
    if (_isShowingModal) return;

    final prefs = await SharedPreferences.getInstance();
    final offeredKey = _offeredKey(reserva);
    final ratedKey = _ratedKey(reserva);

    // Ya calificada o ya ofrecida anteriormente → no auto-mostrar de nuevo.
    if (prefs.getBool(ratedKey) == true) return;
    if (prefs.getBool(offeredKey) == true) return;
    if (_offeredThisSession.contains(offeredKey)) return;

    // Ignorar canceladas / falta.
    final status = reserva.status.toUpperCase();
    if (status == 'CANCELADO' || status == 'FALTA' ||
        reserva.estadoCancelacion == '1') { return; }

    // Ventana de tiempo: 15 min después de la cita y dentro de las 24 h siguientes.
    try {
      final parts = reserva.date.split('-');
      if (parts.length != 3) return;
      final tParts = reserva.time.split(':');
      if (tParts.length < 2) return;

      final appointmentEnd = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]),
        int.parse(tParts[0]), int.parse(tParts[1]),
      ).add(const Duration(minutes: 15));
      final now = DateTime.now();

      if (!now.isAfter(appointmentEnd)) return; // Cita aún no terminó
      if (now.difference(appointmentEnd).inHours >= 24) return; // Pasaron más de 24 h

      // Marcar como ofrecida ANTES de mostrar: impide que un refresh simultáneo
      // lance otro modal mientras este aún está abierto.
      _offeredThisSession.add(offeredKey);
      await prefs.setBool(offeredKey, true);

      _isShowingModal = true;
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();

      if (!context.mounted) {
        _isShowingModal = false;
        return;
      }

      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Califica tu cita',
        barrierColor: Colors.black.withValues(alpha: 0.65),
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (ctx, _, __) => DoctorRatingModal(
          reserva: reserva,
          onDismiss: () => Navigator.pop(ctx),
        ),
      );

      _isShowingModal = false;
    } catch (_) {
      _isShowingModal = false;
    }
  }

  /// Muestra el modal manualmente desde el botón "Calificar" de la lista.
  /// No verifica ventana de tiempo — el usuario lo pidió explícitamente.
  static Future<void> showManual(
    BuildContext context,
    ReservaModel reserva,
  ) async {
    if (_isShowingModal) return;
    _isShowingModal = true;

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Califica tu cita',
        barrierColor: Colors.black.withValues(alpha: 0.65),
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (ctx, _, __) => DoctorRatingModal(
          reserva: reserva,
          onDismiss: () => Navigator.pop(ctx),
        ),
      );
    } finally {
      _isShowingModal = false;
    }
  }

  @override
  State<DoctorRatingModal> createState() => _DoctorRatingModalState();
}

class _DoctorRatingModalState extends State<DoctorRatingModal>
    with SingleTickerProviderStateMixin {
  int _selectedScore = 0;
  bool _isSubmitting = false;
  String _errorMessage = '';
  late AnimationController _appearController;
  final _obsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _appearController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  void _onScoreSelected(int score) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedScore = score;
      _errorMessage = '';
    });
  }

  Future<void> _submitRating() async {
    if (_selectedScore == 0) return;
    HapticFeedback.mediumImpact();

    final reserva = widget.reserva;

    final codadm = reserva.codigoReserva ?? reserva.id;
    final idmed = reserva.idmed ?? reserva.dr?.toString() ?? '';
    final idesp = reserva.idesp ?? 0;
    final uc = UserSession.currentUser.uc ?? 'sistema';

    if (codadm.isEmpty || idmed.isEmpty || idesp == 0) {
      // Datos insuficientes — cerrar y marcar como calificada localmente.
      await _markRated();
      widget.onDismiss();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      final service = ProgramacionService();
      final mensaje = await service.calificarMedico(
        idmed: idmed,
        idesp: idesp,
        codadm: codadm,
        calificacion: _selectedScore,
        obs: _obsController.text.trim(),
        uc: uc,
      );

      if (!mounted) return;

      // Mensaje informativo (ej: "Ya existe una calificación registrada").
      if (mensaje != null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = mensaje;
        });
        await _markRated();
        if (mounted) widget.onDismiss();
        return;
      }

      // Éxito.
      await _markRated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gracias por tu calificación, nos ayuda a mejorar.'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onDismiss();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'No se pudo enviar la calificación. Intente nuevamente.';
      });
    }
  }

  /// Persiste la calificación exitosa. El botón "Calificar" desaparecerá.
  Future<void> _markRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(DoctorRatingModal._ratedKey(widget.reserva), true);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final texts = context.texts;

    _RatingLevel? selectedLevel;
    if (_selectedScore > 0) {
      selectedLevel = _ratingLevels.firstWhere((e) => e.level == _selectedScore);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _appearController, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _appearController, curve: Curves.elasticOut),
            child: Container(
              width: MediaQuery.of(context).size.width * r.modalWidthFactor,
              constraints: BoxConstraints(maxWidth: r.modalMaxWidth),
              decoration: BoxDecoration(
                color: AppColors.cardBg(isDark),
                borderRadius: BorderRadius.circular(r.modalRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Encabezado ──────────────────────────────────────────
                    Container(
                      padding: EdgeInsets.all(r.modalPadding),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(r.modalRadius)),
                        border: Border(
                            bottom: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.1))),
                      ),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/cossmil_logo.png',
                            width: r.listAvatarSize * 1.2,
                            height: r.listAvatarSize * 1.2,
                            fit: BoxFit.contain,
                          ),
                          SizedBox(height: r.spaceMd),
                          Text(
                            '¿Cómo fue tu atención?',
                            style: texts.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryC(isDark),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: r.spaceXs),
                          Text(
                            'Dr. ${widget.reserva.doctorName}\nEspecialidad: ${widget.reserva.specialty}',
                            style: texts.bodyMedium.copyWith(
                              color: AppColors.textSecondaryC(isDark),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // ── Contenido interactivo ────────────────────────────────
                    Padding(
                      padding: EdgeInsets.all(r.modalPadding),
                      child: Column(
                        children: [
                          Text(
                            'Selecciona un nivel de satisfacción:',
                            style: texts.bodyMedium.copyWith(
                              color: AppColors.textTertiaryC(isDark),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: r.spaceLg),

                          // ── Fila de Emojis ───────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _ratingLevels.map((lvl) {
                              final isSelected = _selectedScore == lvl.level;
                              final dimmed = _selectedScore > 0 && !isSelected;
                              return OptimizedPressButton(
                                onTap: () => _onScoreSelected(lvl.level),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeOutBack,
                                      padding: EdgeInsets.all(isSelected ? 6.0 : 4.0),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary.withValues(alpha: 0.15)
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        lvl.emoji,
                                        style: TextStyle(
                                          fontSize: isSelected ? 36 : 28,
                                          color: Colors.white
                                              .withValues(alpha: dimmed ? 0.3 : 1.0),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: TextStyle(
                                        fontSize: r.isSmallPhone ? 9 : 11,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textSecondaryC(isDark)
                                                .withValues(alpha: dimmed ? 0.4 : 1.0),
                                      ),
                                      child: Text(lvl.title, textAlign: TextAlign.center),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),

                          // ── Descripción del nivel ────────────────────────
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            alignment: Alignment.topCenter,
                            child: selectedLevel != null
                                ? Container(
                                    margin: EdgeInsets.only(top: r.spaceLg),
                                    padding: EdgeInsets.all(r.spaceMd),
                                    decoration: BoxDecoration(
                                      color: AppColors.scaffoldBg(isDark),
                                      borderRadius: BorderRadius.circular(r.radiusMd),
                                      border: Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(CupertinoIcons.info_circle_fill,
                                                size: r.iconSm, color: AppColors.primary),
                                            SizedBox(width: r.spaceXs),
                                            Text(
                                              selectedLevel.title,
                                              style: texts.labelLarge.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: r.spaceSm),
                                        Text(
                                          '🕒 Nivel de tiempo:\n${selectedLevel.timeCriteria}',
                                          style: texts.bodySmall.copyWith(
                                              color: AppColors.textPrimaryC(isDark)),
                                        ),
                                        SizedBox(height: r.spaceXs),
                                        Text(
                                          '👤 Criterio de Atención:\n${selectedLevel.attentionCriteria}',
                                          style: texts.bodySmall.copyWith(
                                              color: AppColors.textPrimaryC(isDark)),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          SizedBox(height: r.spaceLg),

                          // ── Comentario (solo para Malo) ─────────────────
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            alignment: Alignment.topCenter,
                            child: _selectedScore == 1
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '¿Qué falló? (opcional)',
                                        style: texts.bodySmall.copyWith(
                                          color: AppColors.textSecondaryC(isDark),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: r.spaceXs),
                                      CupertinoTextField(
                                        controller: _obsController,
                                        placeholder: 'Cuéntanos qué mejorar...',
                                        maxLines: 3,
                                        maxLength: 200,
                                        padding: EdgeInsets.all(r.spaceMd),
                                        style: texts.bodyMedium.copyWith(
                                            color: AppColors.textPrimaryC(isDark)),
                                        placeholderStyle: texts.bodyMedium.copyWith(
                                            color: AppColors.textTertiaryC(isDark)),
                                        decoration: BoxDecoration(
                                          color: AppColors.scaffoldBg(isDark),
                                          borderRadius: BorderRadius.circular(r.radiusMd),
                                          border: Border.all(
                                            color: AppColors.primary.withValues(alpha: 0.2),
                                            width: 0.8,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: r.spaceSm),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // ── Error ────────────────────────────────────────
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            alignment: Alignment.topCenter,
                            child: _errorMessage.isNotEmpty
                                ? Padding(
                                    padding: EdgeInsets.only(top: r.spaceSm),
                                    child: Row(
                                      children: [
                                        Icon(
                                            CupertinoIcons
                                                .exclamationmark_circle_fill,
                                            size: r.iconSm,
                                            color: AppColors.warning),
                                        SizedBox(width: r.spaceXs),
                                        Expanded(
                                          child: Text(
                                            _errorMessage,
                                            style: texts.bodySmall.copyWith(
                                                color: AppColors.warning,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          SizedBox(height: r.spaceXl),

                          // ── Acciones ─────────────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(r.buttonRadius),
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.darkBorder
                                          : const Color(0xFF191C1E)
                                              .withValues(alpha: 0.15),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: CupertinoButton(
                                    padding: EdgeInsets.symmetric(
                                        vertical: r.spaceMd),
                                    color: isDark
                                        ? AppColors.darkElevated
                                        : AppColors.divider,
                                    borderRadius:
                                        BorderRadius.circular(r.buttonRadius),
                                    onPressed:
                                        _isSubmitting ? null : widget.onDismiss,
                                    child: Text(
                                      'Omitir',
                                      style: texts.titleMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.white
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: r.spaceSm),
                              Expanded(
                                flex: 2,
                                child: CupertinoButton(
                                  padding: EdgeInsets.symmetric(
                                      vertical: r.spaceMd),
                                  color: _selectedScore > 0
                                      ? AppColors.primary
                                      : AppColors.textSecondary
                                          .withValues(alpha: 0.5),
                                  borderRadius:
                                      BorderRadius.circular(r.buttonRadius),
                                  onPressed:
                                      (_isSubmitting || _selectedScore == 0)
                                          ? null
                                          : _submitRating,
                                  child: _isSubmitting
                                      ? const CupertinoActivityIndicator(
                                          color: Colors.white)
                                      : Text(
                                          'Enviar Evaluación',
                                          style: texts.titleMedium.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
