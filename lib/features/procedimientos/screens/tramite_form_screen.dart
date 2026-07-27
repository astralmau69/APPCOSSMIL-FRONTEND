import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/session/user_session.dart';
import '../../../core/services/tramite_pdf_service.dart';
import '../../../core/services/tramite_word_service.dart';
import '../../../core/services/tramite_ci_store.dart';
import '../../../core/widgets/adaptive_sliver_nav_bar.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../tramite_catalog.dart';
import 'document_preview_screen.dart';

/// Formulario previo a la generación del PDF de un trámite.
///
/// Autocompleta **nombre** y **CI**: si el usuario es titular puede elegir para
/// quién es el trámite (él mismo o cualquier beneficiario); si es beneficiario,
/// solo puede tramitar para sí mismo. Todos los campos quedan editables porque
/// el CI de los beneficiarios no siempre viene del backend.
class TramiteFormScreen extends StatefulWidget {
  final TramiteInfo info;
  const TramiteFormScreen({super.key, required this.info});

  @override
  State<TramiteFormScreen> createState() => _TramiteFormScreenState();
}

class _Persona {
  final String nombre;
  String ci;
  final String rel;

  /// Clave estable (matrícula o id) para recordar la CI escrita a mano.
  final String key;
  _Persona(this.nombre, this.ci, this.rel, this.key);
}

class _TramiteFormScreenState extends State<TramiteFormScreen> {
  late final List<_Persona> _personas;
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _ciCtrl;
  late final TextEditingController _celCtrl;
  int _selected = 0;
  bool _generating = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final user = UserSession.currentUser;

    if (user.isTitular && user.beneficiaries.isNotEmpty) {
      final bens = [...user.beneficiaries]
        ..sort((a, b) => (b.isTitular ? 1 : 0).compareTo(a.isTitular ? 1 : 0));
      _personas = bens
          .map(
            (b) => _Persona(
              b.fullName,
              b.ci.isNotEmpty ? b.ci : (b.isTitular ? user.ci : ''),
              b.isTitular
                  ? 'Titular'
                  : (b.relationship.isEmpty ? 'Beneficiario' : b.relationship),
              _personKey(b.matricula, b.id, b.fullName),
            ),
          )
          .toList();
    } else {
      _personas = [
        _Persona(
          user.fullName,
          user.ci,
          user.isTitular ? 'Titular' : 'Asegurado',
          _personKey(user.matricula, user.id, user.fullName),
        ),
      ];
    }

    _nombreCtrl = TextEditingController(text: _personas.first.nombre);
    _ciCtrl = TextEditingController(text: _personas.first.ci);
    _celCtrl = TextEditingController(
      text: user.phone.isNotEmpty ? user.phone : user.numCel,
    );

    // Recuperar en segundo plano las cédulas escritas antes (el backend no las
    // envía para los familiares), y autocompletar las que aún estén vacías.
    _hydrateSavedCis();
  }

  static String _personKey(String matricula, String id, String fullName) {
    if (matricula.trim().isNotEmpty) return matricula.trim();
    if (id.trim().isNotEmpty) return id.trim();
    return fullName.trim().toLowerCase();
  }

  Future<void> _hydrateSavedCis() async {
    for (final p in _personas) {
      if (p.ci.isNotEmpty) continue;
      final saved = await TramiteCiStore.getCi(p.key);
      if (saved != null && saved.isNotEmpty) {
        p.ci = saved;
      }
    }
    if (!mounted) return;
    // Reflejar en el campo la CI recuperada de la persona seleccionada.
    if (_ciCtrl.text.trim().isEmpty && _personas[_selected].ci.isNotEmpty) {
      _ciCtrl.text = _personas[_selected].ci;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ciCtrl.dispose();
    _celCtrl.dispose();
    super.dispose();
  }

  void _selectPersona(int i) {
    if (i == _selected) return;
    setState(() {
      // Conservar lo escrito para la persona actual antes de cambiar.
      _personas[_selected].ci = _ciCtrl.text.trim();
      _selected = i;
      _nombreCtrl.text = _personas[i].nombre;
      _ciCtrl.text = _personas[i].ci;
      _showErrors = false;
    });
  }

  Future<void> _generar() async {
    FocusScope.of(context).unfocus();
    final nombre = _nombreCtrl.text.trim();
    final ci = _ciCtrl.text.trim();
    if (nombre.isEmpty || ci.isEmpty) {
      setState(() => _showErrors = true);
      return;
    }

    // Recordar la CI escrita para esta persona (el backend no la envía para
    // los familiares); así queda autocompletada la próxima vez.
    final persona = _personas[_selected];
    persona.ci = ci;
    unawaited(TramiteCiStore.saveCi(persona.key, ci));

    setState(() => _generating = true);
    try {
      final bytes = await TramitePdfService.build(
        tipo: widget.info.tipo,
        nombre: nombre,
        ci: ci,
        celular: _celCtrl.text.trim(),
      );
      final wordBytes = TramiteWordService.build(
        tipo: widget.info.tipo,
        nombre: nombre,
        ci: ci,
        celular: _celCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _generating = false);
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => DocumentPreviewScreen(
            pdfBytes: bytes,
            wordBytes: wordBytes,
            fileName: widget.info.fileName,
            title: widget.info.titulo,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo generar el documento. Intenta de nuevo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final info = widget.info;
    final showSelector = _personas.length > 1;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          AdaptiveSliverNavBar(
            largeTitle: Text(
              'Solicitud',
              style: TextStyle(color: AppColors.textPrimaryC(isDark)),
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
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              r.paddingH,
              12,
              r.paddingH,
              r.navBarBottomSpace + 90,
            ),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: r.maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(child: _heroCard(info, isDark, r)),
                      SizedBox(height: r.spaceLg),
                      if (showSelector) ...[
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 60),
                          child: _sectionLabel(
                            '¿PARA QUIÉN ES EL TRÁMITE?',
                            isDark,
                          ),
                        ),
                        SizedBox(height: r.spaceSm),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 90),
                          child: _personaSelector(info, isDark, r),
                        ),
                        SizedBox(height: r.spaceLg),
                      ],
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: _sectionLabel('DATOS DEL SOLICITANTE', isDark),
                      ),
                      SizedBox(height: r.spaceSm),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 150),
                        child: _datosCard(info, isDark, r),
                      ),
                      SizedBox(height: r.spaceLg),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 180),
                        child: _sectionLabel('DOCUMENTOS A ADJUNTAR', isDark),
                      ),
                      SizedBox(height: r.spaceSm),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 210),
                        child: _requisitosCard(info, isDark, r),
                      ),
                      if (info.nota != null) ...[
                        SizedBox(height: r.spaceMd),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 240),
                          child: _notaCard(info, isDark, r),
                        ),
                      ],
                      SizedBox(height: r.spaceXl),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 270),
                        child: _generarButton(info, r),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero del trámite ──────────────────────────────────────────────────────
  Widget _heroCard(TramiteInfo info, bool isDark, AppResponsive r) {
    return Container(
      padding: EdgeInsets.all(r.cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [info.color, _darken(info.color)],
        ),
        borderRadius: BorderRadius.circular(r.cardRadius),
        boxShadow: [
          BoxShadow(
            color: info.color.withValues(alpha: isDark ? 0.4 : 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: r.listAvatarSize,
            height: r.listAvatarSize,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(r.radiusMd),
            ),
            child: Icon(info.icon, size: r.iconMd, color: Colors.white),
          ),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.titulo,
                  style: context.texts.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: r.spaceXs),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.building_2_fill,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        info.destinatario,
                        style: context.texts.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.spaceSm),
                Text(
                  info.descripcion,
                  style: context.texts.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Selector de persona ───────────────────────────────────────────────────
  Widget _personaSelector(TramiteInfo info, bool isDark, AppResponsive r) {
    return Column(
      children: [
        for (int i = 0; i < _personas.length; i++) ...[
          _personaTile(info, i, isDark, r),
          if (i < _personas.length - 1) SizedBox(height: r.spaceSm),
        ],
      ],
    );
  }

  Widget _personaTile(TramiteInfo info, int i, bool isDark, AppResponsive r) {
    final p = _personas[i];
    final sel = i == _selected;
    final initial = p.nombre.trim().isNotEmpty
        ? p.nombre.trim()[0].toUpperCase()
        : '?';
    return OptimizedPressButton(
      onTap: () => _selectPersona(i),
      scaleDown: 0.98,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: EdgeInsets.symmetric(
          horizontal: r.cardPadding,
          vertical: r.spaceMd,
        ),
        decoration: BoxDecoration(
          color: sel
              ? info.color.withValues(alpha: isDark ? 0.18 : 0.08)
              : AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(r.cardRadius),
          border: Border.all(
            color: sel
                ? info.color.withValues(alpha: 0.55)
                : AppColors.cardBorder(isDark),
            width: sel ? 1.5 : 0.5,
          ),
          boxShadow: sel ? null : AppColors.cardShadowFor(isDark),
        ),
        child: Row(
          children: [
            Container(
              width: r.avatarSm,
              height: r.avatarSm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: info.color.withValues(alpha: sel ? 0.22 : 0.12),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: info.color,
                    fontSize: r.avatarSm * 0.42,
                  ),
                ),
              ),
            ),
            SizedBox(width: r.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryC(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.rel,
                    style: context.texts.bodySmall.copyWith(
                      color: AppColors.textTertiaryC(isDark),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              sel
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              size: r.iconMd,
              color: sel ? info.color : AppColors.textTertiaryC(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ── Datos editables ───────────────────────────────────────────────────────
  Widget _datosCard(TramiteInfo info, bool isDark, AppResponsive r) {
    return LiquidGlass(
      isDark: isDark,
      borderRadius: BorderRadius.circular(r.cardRadius),
      padding: EdgeInsets.all(r.cardPadding),
      shadow: AppColors.cardShadowFor(isDark),
      child: Column(
        children: [
          _field(
            label: 'Nombre completo',
            controller: _nombreCtrl,
            icon: CupertinoIcons.person_fill,
            accent: info.color,
            isDark: isDark,
            textCapitalization: TextCapitalization.characters,
            error: _showErrors && _nombreCtrl.text.trim().isEmpty
                ? 'Ingresa el nombre completo'
                : null,
          ),
          SizedBox(height: r.spaceMd),
          _field(
            label: 'Cédula de identidad',
            controller: _ciCtrl,
            icon: CupertinoIcons.creditcard_fill,
            accent: info.color,
            isDark: isDark,
            keyboardType: TextInputType.text,
            error: _showErrors && _ciCtrl.text.trim().isEmpty
                ? 'Ingresa la cédula de identidad'
                : null,
          ),
          SizedBox(height: r.spaceMd),
          _field(
            label: 'Celular (opcional)',
            controller: _celCtrl,
            icon: CupertinoIcons.phone_fill,
            accent: info.color,
            isDark: isDark,
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: r.spaceSm),
          Row(
            children: [
              Icon(
                CupertinoIcons.checkmark_seal_fill,
                size: 13,
                color: info.color.withValues(alpha: 0.8),
              ),
              SizedBox(width: r.spaceXs + 2),
              Expanded(
                child: Text(
                  'Guardamos la cédula de cada persona para autocompletarla la '
                  'próxima vez.',
                  style: context.texts.labelSmall.copyWith(
                    color: AppColors.textTertiaryC(isDark),
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color accent,
    required bool isDark,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType? keyboardType,
    String? error,
  }) {
    final r = context.r;
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkElevated : const Color(0xFFF6F8FA),
            borderRadius: BorderRadius.circular(r.inputRadius),
            border: Border.all(
              color: hasError
                  ? AppColors.error.withValues(alpha: 0.7)
                  : AppColors.cardBorder(isDark),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: r.cardPadding,
            vertical: r.spaceSm,
          ),
          child: Row(
            children: [
              Icon(icon, size: r.iconMd, color: accent),
              SizedBox(width: r.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: context.texts.labelSmall.copyWith(
                        color: AppColors.textSecondaryC(isDark),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: r.spaceXs),
                    CupertinoTextField(
                      controller: controller,
                      padding: EdgeInsets.zero,
                      decoration: null,
                      textCapitalization: textCapitalization,
                      keyboardType: keyboardType,
                      onChanged: (_) {
                        if (_showErrors) setState(() {});
                      },
                      style: context.texts.bodyLarge.copyWith(
                        color: AppColors.textPrimaryC(isDark),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 5),
            child: Text(
              error,
              style: context.texts.labelSmall.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // ── Requisitos ────────────────────────────────────────────────────────────
  Widget _requisitosCard(TramiteInfo info, bool isDark, AppResponsive r) {
    return LiquidGlass(
      isDark: isDark,
      borderRadius: BorderRadius.circular(r.cardRadius),
      padding: EdgeInsets.symmetric(
        horizontal: r.cardPadding,
        vertical: r.spaceSm,
      ),
      shadow: AppColors.cardShadowFor(isDark),
      child: Column(
        children: [
          for (int i = 0; i < info.requisitos.length; i++)
            Padding(
              padding: EdgeInsets.symmetric(vertical: r.spaceSm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    size: r.iconSm,
                    color: info.color,
                  ),
                  SizedBox(width: r.spaceSm),
                  Expanded(
                    child: Text(
                      info.requisitos[i],
                      style: context.texts.bodyMedium.copyWith(
                        color: AppColors.textPrimaryC(isDark),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _notaCard(TramiteInfo info, bool isDark, AppResponsive r) {
    return Container(
      padding: EdgeInsets.all(r.spaceMd),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.warning.withValues(alpha: 0.12)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(r.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.info_circle_fill,
            size: r.iconSm,
            color: AppColors.warning,
          ),
          SizedBox(width: r.spaceSm),
          Expanded(
            child: Text(
              info.nota!,
              style: context.texts.bodySmall.copyWith(
                color: isDark ? AppColors.warning : const Color(0xFF92400E),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: context.texts.labelSmall.copyWith(
          color: AppColors.textTertiaryC(isDark),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ── Botón generar ─────────────────────────────────────────────────────────
  Widget _generarButton(TramiteInfo info, AppResponsive r) {
    return SizedBox(
      width: double.infinity,
      height: r.buttonHeight,
      child: OptimizedPressButton(
        onTap: _generating ? null : _generar,
        scaleDown: 0.97,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [info.color, _darken(info.color)]),
            borderRadius: BorderRadius.circular(r.buttonRadius),
            boxShadow: [
              BoxShadow(
                color: info.color.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: _generating
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.doc_text_viewfinder,
                        size: 20,
                        color: Colors.white,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Previsualizar documento',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  static Color _darken(Color c, [double amount = 0.14]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
