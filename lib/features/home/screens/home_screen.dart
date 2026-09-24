import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui show TextDirection, lerpDouble;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/session/user_session.dart';
import '../../../core/models/horario_atencion_model.dart';
import '../../../core/models/news_item_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/cossmil_news_service.dart';
import '../../../core/services/tutorial_flow.dart';
import '../../../core/services/tutorial_service.dart';
import '../../../core/widgets/guided_tap_hint.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/tutorial_coach_overlay.dart';
import '../../../core/widgets/tutorial_instructor.dart';
import '../../../core/widgets/tutorial_invite_dialog.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/professional_profile_card.dart';
import '../../../core/widgets/adaptive_sliver_nav_bar.dart';
import 'news_detail_screen.dart';
import '../../../shell/tab_shell.dart';
import '../../carnet/screens/carnet_screen.dart';
import '../../familia/screens/familia_screen.dart';
import '../../notificaciones/screens/notificaciones_screen.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/services/notification_preferences.dart';
import 'contactos_screen.dart';
import 'noticias_screen.dart';
import '../widgets/coming_soon_dialog.dart';

/// Verde esmeralda sobrio de la acción héroe "Nueva Reserva" (coherente con el
/// botón de "Iniciar Sesión" del login). Tono profundo, menos estridente que el
/// verde brillante anterior: se lee más profesional en modo claro y oscuro.
const Color _kHeroGreen = Color(0xFF059669);
const Color _kHeroGreenDark = Color(0xFF047857);

class HomeScreen extends StatefulWidget {
  final TabShellState tabShell;

  const HomeScreen({super.key, required this.tabShell});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<NewsItemModel> _news = [];
  bool _isLoadingNews = true;
  Uint8List? _cachedUserPhoto;
  String? _cachedPhotoB64; // base64 que originó _cachedUserPhoto (memo)
  int _unreadNotifs = 0;

  /// Acceso al coach del paso de Inicio para minimizarlo apenas el usuario
  /// interactúa con el contenido (mismo patrón que BookingFlowScreen).
  final _coachKey = GlobalKey<TutorialCoachOverlayState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // El paso de Inicio del tutorial vive en TabShell (también se relanza
    // desde Perfil) — Home solo reacciona a sus cambios.
    widget.tabShell.homeTutorialNotifier.addListener(_onHomeTutorialChanged);
    final photo = UserSession.currentUser.photoBase64;
    if (photo.isNotEmpty) {
      _cachedPhotoB64 = photo;
      try {
        _cachedUserPhoto = base64Decode(photo);
      } catch (_) {}
    }
    _loadNews();
    _maybeOfferFichaTutorial();
  }

  /// Invita al tutorial de "sacar una ficha" SOLO la primera vez que el
  /// usuario llega a Inicio (ver [TutorialService]). Se marca como visto
  /// apenas se decide mostrar la invitación — así nunca vuelve a interrumpir
  /// solo; después queda disponible bajo demanda desde Perfil → Ayuda.
  Future<void> _maybeOfferFichaTutorial() async {
    final alreadySeen = await TutorialService.hasSeenFichaTutorial();
    if (alreadySeen || !mounted) return;

    // Pequeña espera para no competir con las animaciones de entrada de la
    // pantalla (FadeSlideIn escalonado de la tarjeta de perfil y accesos).
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    await TutorialService.markFichaTutorialSeen();
    if (!mounted) return;

    // Precarga el rig de la instructora: entra saludando y en cuanto el
    // usuario acepta empieza a explicar y a parpadear, así que decodificar
    // sobre la marcha se vería como un salto.
    await precacheInstructorRig();
    if (!mounted) return;

    await showTutorialInviteDialog(
      context,
      isDark: Theme.of(context).brightness == Brightness.dark,
      onAccept: () => widget.tabShell.startTutorialFromHome(),
    );
  }

  void _onHomeTutorialChanged() {
    if (mounted) setState(() {});
  }

  /// Salida del tutorial desde su paso de Inicio: misma hoja de confirmación
  /// que en el flujo de reserva, para que "Salir del tutorial" se comporte
  /// igual en todos los pasos.
  Future<void> _exitHomeTutorial() async {
    if (await confirmExitTutorial(context) && mounted) {
      widget.tabShell.homeTutorialNotifier.value = GuidedTutorial.none;
    }
  }

  @override
  void dispose() {
    widget.tabShell.homeTutorialNotifier.removeListener(_onHomeTutorialChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Recarga noticias cuando el usuario vuelve a primer plano
  /// (p.ej. tras desbloquear la app con PIN).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNews();
    }
  }

  Future<void> _loadNews() async {
    if (!mounted) return;
    setState(() => _isLoadingNews = true);

    // Cargar cantidad de notificaciones no leídas en background
    try {
      final userId = UserSession.currentUser.id;
      if (userId.isNotEmpty) {
        await NotificationPreferences.loadHistory(userId);
        if (mounted) {
          setState(() => _unreadNotifs = AppNotificationRepository.unreadCount);
        }
      }
    } catch (_) {}

    List<NewsItemModel> items;
    try {
      items = await CossmilNewsService.fetchComunicados();
    } catch (_) {
      items = const [];
    }
    if (!mounted) return;

    // Ordenar por fecha descendente (más recientes primero)
    items.sort((a, b) {
      if (a.dateTime == null && b.dateTime == null) return 0;
      if (a.dateTime == null) return 1;
      if (b.dateTime == null) return -1;
      return b.dateTime!.compareTo(a.dateTime!);
    });

    setState(() {
      _news = items.take(3).toList();
      _isLoadingNews = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // La tarjeta de perfil se construye dentro de un ValueListenableBuilder
    // (UserSession.userNotifier), por eso aquí ya no se lee currentUser.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final tutorial = widget.tabShell.homeTutorialNotifier.value;
    final tutorialActive = tutorial != GuidedTutorial.none;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      child: Stack(
        children: [
          // En el paso de Inicio del tutorial, cualquier interacción con el
          // contenido (tap o inicio de scroll) minimiza al coach para que no
          // tape el menú; el Listener es translúcido y no roba gestos.
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: tutorialActive
                ? (_) => _coachKey.currentState?.collapse()
                : null,
            child: _buildScrollContent(isDark, r),
          ),
          if (tutorialActive)
            TutorialCoachOverlay(
              key: _coachKey,
              messages: _homeCoachMessages(tutorial),
              isDark: isDark,
              // Los tres recorridos comparten este primer paso, y cada uno
              // tiene su propia longitud.
              step: 1,
              totalSteps: _homeTutorialSteps(tutorial),
              voiceId: _homeVoiceId(tutorial),
              onExit: _exitHomeTutorial,
            ),
        ],
      ),
    );
  }

  /// Lo que dice la instructora en el menú, según a dónde vaya el recorrido.
  /// Siempre nombra la tarjeta EXACTA que hay que tocar: el objetivo del paso
  /// es que el usuario memorice la puerta de entrada, no solo el destino.
  /// Clip de voz del paso de Inicio de cada recorrido (`<recorrido>_00.mp3`).
  String? _homeVoiceId(GuidedTutorial t) => switch (t) {
    GuidedTutorial.ficha => 'ficha_00',
    GuidedTutorial.calendario => 'calendario_00',
    GuidedTutorial.tramites => 'tramites_00',
    GuidedTutorial.none => null,
  };

  List<String> _homeCoachMessages(GuidedTutorial t) => switch (t) {
    GuidedTutorial.ficha => const [
      '¡Hola! Vamos a sacar tu primera ficha juntos.',
      'Todo empieza aquí, en Inicio: toca la primera opción del menú, el '
          'botón verde "Nueva Reserva".',
    ],
    GuidedTutorial.calendario => const [
      '¡Hola! Te voy a enseñar a consultar los horarios de los médicos.',
      'Empezamos desde Inicio: toca la tarjeta "Calendario de Atención".',
    ],
    GuidedTutorial.tramites => const [
      '¡Hola! Vamos a generar un trámite paso a paso.',
      'Empezamos desde Inicio: toca la tarjeta "Procedimientos COSSMIL".',
    ],
    GuidedTutorial.none => const [],
  };

  int _homeTutorialSteps(GuidedTutorial t) => switch (t) {
    GuidedTutorial.ficha => 7,
    GuidedTutorial.calendario || GuidedTutorial.tramites => 5,
    GuidedTutorial.none => 1,
  };

  /// Etiqueta del menú que hay que resaltar en el paso de Inicio. `null`
  /// cuando el objetivo es el botón héroe, que se resalta aparte.
  String? _homeTutorialTarget(GuidedTutorial t) => switch (t) {
    GuidedTutorial.calendario => 'Calendario de Atención',
    GuidedTutorial.tramites => 'Procedimientos COSSMIL',
    _ => null,
  };

  Widget _buildScrollContent(bool isDark, AppResponsive r) {
    final tutorialActive =
        widget.tabShell.homeTutorialNotifier.value != GuidedTutorial.none;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        AdaptiveSliverNavBar(
          largeTitle: Text(
            'Inicio',
            style: TextStyle(color: AppColors.textPrimaryC(isDark)),
          ),
          backgroundColor: AppColors.navBarBg(isDark),
          border: null,
          trailing: _TutorialDim(
            dimmed: tutorialActive,
            child: Semantics(
              label: 'Notificaciones, $_unreadNotifs no leídas',
              button: true,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await widget.tabShell.openSubRoute(
                    context,
                    (_) => const NotificacionesScreen(),
                  );
                  _loadNews(); // Recargar count al volver
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.bell_fill,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    if (_unreadNotifs > 0)
                      Positioned(
                        right: -2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444), // Rojo alerta
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.navBarBg(isDark),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _unreadNotifs > 9 ? '9+' : _unreadNotifs.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: _loadNews),
        // Banner de estado de horario
        if (widget.tabShell.isInHorario != null)
          SliverToBoxAdapter(
            child: _TutorialDim(
              dimmed: tutorialActive,
              child: _HorarioBanner(
                isInHorario: widget.tabShell.isInHorario!,
                horariosApp: widget.tabShell.horariosApp,
              ),
            ),
          ),
        SliverPadding(
          padding: r.screenPadding,
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: r.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(
                      duration: AppDurations.normal,
                      delay: const Duration(milliseconds: 0),
                      offsetY: 10,
                      // Reactivo: refresca la tarjeta (foto, sangre, alergias…)
                      // apenas el enriquecimiento en segundo plano actualiza al
                      // usuario, sin tener que reiniciar la app.
                      child: _TutorialDim(
                        dimmed: tutorialActive,
                        child: ValueListenableBuilder<UserModel>(
                          valueListenable: UserSession.userNotifier,
                          builder: (context, liveUser, _) =>
                              _buildProfileCard(liveUser),
                        ),
                      ),
                    ),
                    SizedBox(height: r.spaceLg),
                    // ── Acciones principales (entrada escalonada dentro) ──
                    _buildQuickActions(),
                    SizedBox(height: r.spaceXl),
                    // ── COSSMIL Te Informa: header + botón en la misma línea ──
                    FadeSlideIn(
                      duration: AppDurations.normal,
                      delay: const Duration(milliseconds: 100),
                      offsetY: 10,
                      child: _TutorialDim(
                        dimmed: tutorialActive,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: SectionHeader(
                                text: 'COSSMIL TE INFORMA',
                                padding: EdgeInsets.only(left: 4),
                              ),
                            ),
                            Semantics(
                              label: 'Ver todos los comunicados',
                              button: true,
                              child: OptimizedPressButton(
                                onTap: () => widget.tabShell.openSubRoute(
                                  context,
                                  (_) => const NoticiasScreen(),
                                ),
                                scaleDown: 0.95,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: isDark ? 0.18 : 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: isDark ? 0.35 : 0.2,
                                      ),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Ver todos',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        CupertinoIcons.arrow_right,
                                        size: 11,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: r.spaceSm),
                    FadeSlideIn(
                      duration: AppDurations.normal,
                      delay: const Duration(milliseconds: 150),
                      offsetY: 10,
                      child: _TutorialDim(
                        dimmed: tutorialActive,
                        child: _buildCompactNewsList(),
                      ),
                    ),
                    SizedBox(height: r.navBarBottomSpace),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tarjeta de perfil profesional ───────────────────────────────────────────

  Widget _buildProfileCard(UserModel user) {
    return ProfessionalProfileCard(
      user: user,
      cachedPhoto: _photoFor(user),
      onTap: () => widget.tabShell.goToTab(4), // Ir al perfil
    );
  }

  /// Devuelve la foto decodificada del usuario, re-decodificando SOLO cuando
  /// el base64 cambia (evita trabajo en cada rebuild). null si no hay foto.
  Uint8List? _photoFor(UserModel user) {
    final b64 = user.photoBase64;
    if (b64.isEmpty) {
      _cachedPhotoB64 = null;
      _cachedUserPhoto = null;
      return null;
    }
    if (b64 != _cachedPhotoB64) {
      _cachedPhotoB64 = b64;
      try {
        _cachedUserPhoto = base64Decode(b64);
      } catch (_) {
        _cachedUserPhoto = null;
      }
    }
    return _cachedUserPhoto;
  }

  // ── Acciones rápidas (grandes y prominentes) ────────────────────────────────

  Widget _buildQuickActions() {
    final r = context.r;

    // Acción primaria (héroe): agendar una cita es el trabajo central de la
    // app, por eso se destaca en una tarjeta ancha con el verde esmeralda
    // sobrio (_kHeroGreen), coherente con el botón de "Iniciar Sesión" del
    // login. El resto de accesos quedan en una grilla neutra y tranquila.
    final hero = _QuickAction(
      icon: CupertinoIcons.calendar_badge_plus,
      label: 'Nueva Reserva',
      subtitle: 'Agendar cita médica',
      color: _kHeroGreen,
      onTap: () {
        // Paso 1 del tutorial: este mismo tap (el gesto real de siempre)
        // entra al flujo de reserva pero en modo demostración, sin
        // verificaciones de negocio que puedan bloquear al usuario.
        if (widget.tabShell.homeTutorialNotifier.value ==
            GuidedTutorial.ficha) {
          widget.tabShell.enterHomeTutorialTarget(context);
          return;
        }
        final bens = UserSession.currentUser.beneficiaries;
        final titular = bens.isNotEmpty
            ? bens.firstWhere((b) => b.isTitular, orElse: () => bens.first)
            : null;
        widget.tabShell.startBooking('Para mí', titular);
      },
    );

    final items = [
      _QuickAction(
        icon: CupertinoIcons.clock,
        label: 'Mis Reservas',
        subtitle: 'Ver historial',
        color: AppColors.accent,
        onTap: () => widget.tabShell.goToTab(1),
      ),
      _QuickAction(
        icon: CupertinoIcons.person_2,
        label: 'Grupo Familiar',
        subtitle: 'Beneficiarios',
        color: const Color(
          0xFF0D9488,
        ), // teal — se diferencia del verde del héroe
        onTap: () =>
            widget.tabShell.openSubRoute(context, (_) => const FamiliaScreen()),
      ),
      _QuickAction(
        icon: CupertinoIcons.phone,
        label: 'Contactos COSSMIL',
        subtitle: 'Llamar',
        color: AppColors.info,
        onTap: () => widget.tabShell.openSubRoute(
          context,
          (_) => const ContactosScreen(),
        ),
      ),
      _QuickAction(
        icon: CupertinoIcons.calendar,
        label: 'Calendario de Atención',
        subtitle: 'Horarios Médicos',
        color: const Color(0xFF7C3AED),
        onTap: () => widget.tabShell.goToTab(3),
      ),
      // Carnet digital: habilitado. Para volver a ocultarlo basta con poner
      // `AppConfig.carnetDigitalEnabled` en false (la tarjeta desaparece y el
      // código del carnet se excluye del build).
      if (AppConfig.carnetDigitalEnabled)
        _QuickAction(
          icon: CupertinoIcons.creditcard_fill,
          label: 'Mi Carnet COSSMIL',
          subtitle: 'Carnet digital de asegurado',
          color: const Color(0xFF0E63A6),
          onTap: () => widget.tabShell.openSubRoute(
            context,
            (_) => const CarnetScreen(),
          ),
        ),
      // Procedimientos COSSMIL: marcado "Próximamente" hasta autorización
      // oficial de COSSMIL, igual que Mi Carnet COSSMIL más arriba. El
      // tutorial guiado (Perfil → Ayuda → "Cómo generar un trámite") queda
      // intacto: es inofensivo porque termina antes de generar cualquier
      // documento real. Para reactivarlo: quitar `comingSoon: true` y
      // restaurar la navegación con openSubRoute a ProcedimientosScreen.
      _QuickAction(
        icon: CupertinoIcons.doc_text_fill,
        label: 'Procedimientos COSSMIL',
        subtitle: 'Formularios y trámites',
        color: const Color(0xFFD97706),
        comingSoon: true,
        onTap: () => showComingSoonDialog(
          context,
          featureLabel: 'Procedimientos COSSMIL',
          icon: CupertinoIcons.doc_text_fill,
          color: const Color(0xFFD97706),
        ),
      ),
    ];

    final spacing = r.gridSpacing;

    // Columnas derivadas del ancho REAL disponible (no del tipo de
    // dispositivo): así el menú se adapta a landscape, split-screen y
    // ventanas de navegador redimensionadas, donde el ancho no coincide
    // con la categoría del dispositivo. Cada tarjeta necesita ~168 px para
    // que "Mis Reservas", "Grupo Familiar", etc. respiren sin desbordar.
    final tutorial = widget.tabShell.homeTutorialNotifier.value;
    final objetivo = _homeTutorialTarget(tutorial);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 168).floor().clamp(2, 3);
        // Ancho real de cada tarjeta: de él se deriva la tipografía interior,
        // para que el texto escale con el espacio disponible (resize del
        // navegador, split-screen, landscape) y no con el tipo de dispositivo.
        final cardWidth =
            (constraints.maxWidth - r.gridSpacing * (cols - 1)) / cols;

        final rows = <Widget>[];
        for (int i = 0; i < items.length; i += cols) {
          final end = (i + cols > items.length) ? items.length : i + cols;
          final chunk = items.sublist(i, end);

          final rowChildren = <Widget>[];
          for (int j = 0; j < chunk.length; j++) {
            // Stagger: cada tarjeta entra 45 ms después de la anterior,
            // guiando el ojo en cascada (héroe → grilla) sin alargar la
            // percepción de carga (todo termina en < 700 ms).
            final accion = items[i + j];
            final esObjetivo = objetivo != null && accion.label == objetivo;
            rowChildren.add(
              Expanded(
                child: FadeSlideIn(
                  duration: AppDurations.normal,
                  delay: Duration(milliseconds: 100 + (i + j) * 45),
                  offsetY: 12,
                  child: esObjetivo
                      ? GuidedTapHint(
                          // Durante el tutorial, la tarjeta resaltada NO ejecuta
                          // su navegación normal (goToTab/openSubRoute): eso deja
                          // `homeTutorialNotifier` activo (navbar muerta) y nunca
                          // arranca el coach. Debe pasar por enterHomeTutorialTarget,
                          // que resetea el estado y entra al recorrido guiado.
                          child: _buildActionCard(
                            _QuickAction(
                              icon: accion.icon,
                              label: accion.label,
                              subtitle: accion.subtitle,
                              color: accion.color,
                              // Se conserva el look "Próximamente" (p. ej.
                              // Procedimientos COSSMIL) aunque el tutorial SÍ
                              // entre al recorrido real: solo cambia el tap,
                              // no la apariencia de la tarjeta.
                              comingSoon: accion.comingSoon,
                              onTap: () => widget.tabShell
                                  .enterHomeTutorialTarget(context),
                            ),
                            cardWidth,
                          ),
                        )
                      : _buildActionCard(accion, cardWidth),
                ),
              ),
            );
            if (j < chunk.length - 1) {
              rowChildren.add(SizedBox(width: spacing));
            }
          }

          // Si la última fila tiene menos elementos, añadimos espacios vacíos
          if (chunk.length < cols) {
            for (int j = chunk.length; j < cols; j++) {
              rowChildren.add(SizedBox(width: spacing));
              rowChildren.add(const Expanded(child: SizedBox.shrink()));
            }
          }

          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rowChildren,
              ),
            ),
          );

          if (i + cols < items.length) {
            rows.add(SizedBox(height: spacing));
          }
        }

        // Durante el paso de Inicio del tutorial, el héroe lleva el mismo
        // borde pulsante + "Toca aquí" que las tarjetas del flujo de reserva:
        // un solo elemento resaltado; el resto del menú se ve pero queda
        // atenuado e inerte (_TutorialDim) para no sacar al usuario de la guía.
        final heroCard = tutorial == GuidedTutorial.ficha
            ? GuidedTapHint(child: _buildHeroAction(hero))
            : _buildHeroAction(hero);

        return Column(
          children: [
            FadeSlideIn(
              duration: AppDurations.normal,
              delay: const Duration(milliseconds: 50),
              offsetY: 12,
              // Cuando el objetivo está en la grilla, el héroe se atenúa como
              // el resto: un solo elemento resaltado por paso.
              child: _TutorialDim(dimmed: objetivo != null, child: heroCard),
            ),
            SizedBox(height: spacing),
            // La grilla solo se atenúa entera cuando el objetivo NO está en
            // ella (tutorial de la ficha); si el objetivo es una de sus
            // tarjetas, atenuarla taparía justo lo que hay que tocar.
            _TutorialDim(
              dimmed: tutorial == GuidedTutorial.ficha,
              child: Column(children: rows),
            ),
          ],
        );
      },
    );
  }

  // ── Acción héroe (ancha, verde esmeralda) ───────────────────────────────────

  Widget _buildHeroAction(_QuickAction action) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final texts = context.texts;

    return Semantics(
      label: '${action.label}: ${action.subtitle}',
      hint: 'Toca para agendar una cita',
      button: true,
      child: OptimizedPressButton(
        onTap: action.onTap,
        scaleDown: 0.97,
        haptic: true,
        child: Container(
          decoration: BoxDecoration(
            // Sheen superior + verde institucional: el vidrio tintado recibe
            // la luz por arriba, como el resto de superficies liquid glass.
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10A878), _kHeroGreen, _kHeroGreenDark],
              stops: [0.0, 0.45, 1.0],
            ),
            borderRadius: BorderRadius.circular(r.cardRadius),
            // Filo especular blanco: firma liquid glass sobre color pleno.
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _kHeroGreen.withValues(alpha: isDark ? 0.45 : 0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: r.tileVerticalPad + 4,
              horizontal: r.tileHorizontalPad,
            ),
            child: Row(
              children: [
                Container(
                  width: r.listAvatarSize,
                  height: r.listAvatarSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(r.radiusMd),
                  ),
                  child: Icon(action.icon, size: r.iconMd, color: Colors.white),
                ),
                SizedBox(width: r.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texts.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: (r.isTablet || r.isDesktop) ? 19 : 17,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: r.spaceXs),
                      Text(
                        action.subtitle,
                        style: texts.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.arrow_right,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mayor tamaño de fuente (≤ [preferred], ≥ [min]) con el que [text] cabe
  /// en [maxWidth] sin desbordar [maxLines] y sin partir palabras: la palabra
  /// más larga debe entrar completa en una línea. Medido con TextPainter
  /// respetando el TextScaler de accesibilidad.
  double _fitFontSize({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double preferred,
    required double min,
    required TextScaler scaler,
    int maxLines = 1,
  }) {
    if (maxWidth <= 0) return min;
    // Margen de seguridad: el ancho medido puede diferir del de render por
    // redondeos sub-píxel, y un exceso mínimo parte la palabra a media línea
    // (p. ej. la "s" de "Procedimientos" caía sola a la segunda línea).
    final safeWidth = maxWidth - 2;
    final words = text.split(' ');
    for (var size = preferred; size >= min; size -= 0.5) {
      final s = style.copyWith(fontSize: size);
      var fits = true;
      for (final word in words) {
        final tp = TextPainter(
          text: TextSpan(text: word, style: s),
          textDirection: ui.TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        if (tp.width > safeWidth) {
          fits = false;
          break;
        }
      }
      if (!fits) continue;
      final tp = TextPainter(
        text: TextSpan(text: text, style: s),
        textDirection: ui.TextDirection.ltr,
        textScaler: scaler,
        maxLines: maxLines,
      )..layout(maxWidth: safeWidth);
      if (!tp.didExceedMaxLines) return size;
    }
    return min;
  }

  Widget _buildActionCard(_QuickAction action, double cardWidth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final texts = context.texts;

    // Tarjeta de vidrio + chip de ícono a color: la grilla queda tranquila y
    // coherente (mismo lenguaje que la lista de noticias); el color de cada
    // acción vive en su chip, no en fondos dispares.
    final textMainColor = AppColors.textPrimaryC(isDark);
    final textSubColor = AppColors.textSecondaryC(isDark);

    // Tipografía e ícono derivados del ancho REAL de la tarjeta: interpola
    // entre tarjetas angostas (~140 px) y anchas (~240 px), con clamp en los
    // extremos. Así "Procedimientos COSSMIL", "Calendario de Atención", etc.
    // nunca desbordan al reducir la ventana ni quedan diminutos en desktop.
    final t = ((cardWidth - 140.0) / 100.0).clamp(0.0, 1.0);
    final iconBox = ui.lerpDouble(
      r.listAvatarSize * 0.85,
      r.listAvatarSize,
      t,
    )!;
    final iconSize = ui.lerpDouble(r.iconSm, r.iconMd, t)!;
    final labelSize = ui.lerpDouble(12.5, 16.0, t)!;
    final subSize = ui.lerpDouble(10.0, 13.5, t)!;

    // Diseño vertical (ícono arriba, texto debajo): la etiqueta dispone del
    // ancho COMPLETO de la tarjeta, así en tablets cabe en una sola línea y
    // en teléfonos angostos salta por palabra completa, nunca a media palabra.
    final textWidth = cardWidth - 2 * r.tileHorizontalPad;
    final scaler = MediaQuery.textScalerOf(context);
    final labelStyle = texts.titleMedium.copyWith(
      fontSize: labelSize,
      // "Próximamente": título en tono secundario para leerse como acceso
      // aún no activo, sin llegar al gris de deshabilitado (sigue siendo
      // tocable: abre el diálogo informativo).
      color: action.comingSoon ? textSubColor : textMainColor,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );
    final subStyle = texts.bodySmall.copyWith(
      fontSize: subSize,
      color: textSubColor,
      fontWeight: FontWeight.w600,
      height: 1.1,
    );
    final fittedLabel = _fitFontSize(
      text: action.label,
      style: labelStyle,
      maxWidth: textWidth,
      preferred: labelSize,
      min: 10.0,
      scaler: scaler,
      maxLines: 2,
    );
    final fittedSub = _fitFontSize(
      text: action.subtitle,
      style: subStyle,
      maxWidth: textWidth,
      preferred: subSize,
      min: 8.5,
      scaler: scaler,
    );

    final contentColumn = Padding(
      padding: EdgeInsets.symmetric(
        vertical: r.tileVerticalPad + 2,
        horizontal: r.tileHorizontalPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ícono (+ pastilla "Próximamente" alineada al borde derecho)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: action.color.withValues(
                    alpha: action.comingSoon
                        ? (isDark ? 0.14 : 0.08)
                        : (isDark ? 0.22 : 0.12),
                  ),
                  borderRadius: BorderRadius.circular(r.radiusMd),
                ),
                child: Icon(
                  action.icon,
                  size: iconSize,
                  color: action.comingSoon
                      ? action.color.withValues(alpha: 0.55)
                      : action.color,
                ),
              ),
              if (action.comingSoon)
                Expanded(
                  child: Align(
                    alignment: Alignment.topRight,
                    // scaleDown: en tarjetas angostas (~140 px) la pastilla se
                    // encoge en vez de desbordar contra el chip del ícono.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _ComingSoonBadge(isDark: isDark),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: r.spaceSm + 2),
          Text(
            action.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: labelStyle.copyWith(fontSize: fittedLabel),
          ),
          SizedBox(height: r.spaceXs),
          Text(
            action.subtitle,
            style: subStyle.copyWith(fontSize: fittedSub),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return Semantics(
      label: action.comingSoon
          ? '${action.label}: próximamente, estamos trabajando en esta función'
          : '${action.label}: ${action.subtitle}',
      hint: action.comingSoon ? 'Toca para más información' : 'Toca para abrir',
      button: true,
      child: OptimizedPressButton(
        onTap: action.onTap,
        scaleDown: 0.96,
        haptic: true,
        // Vidrio simulado (sin blur): translucidez + borde especular. El blur
        // real está vetado en tarjetas repetidas de una grilla (costo GPU).
        child: LiquidGlass(
          isDark: isDark,
          borderRadius: BorderRadius.circular(r.cardRadius),
          shadow: AppColors.cardShadowFor(isDark),
          child: contentColumn,
        ),
      ),
    );
  }

  // ── COSSMIL Te Informa — Lista compacta ───────────────────────────────────

  Widget _buildCompactNewsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final r = context.r;
    return LiquidGlass(
      isDark: isDark,
      borderRadius: BorderRadius.circular(r.cardRadius),
      shadow: AppColors.cardShadowFor(isDark),
      child: Column(
        children: [
          if (_isLoadingNews) ...[
            for (int i = 0; i < 3; i++)
              _buildSkeletonRow(isDark, isLast: i == 2),
          ] else if (_news.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.news,
                    size: r.iconSm,
                    color: AppColors.textTertiaryC(isDark),
                  ),
                  SizedBox(width: r.spaceMd),
                  Text(
                    'Sin comunicados recientes',
                    style: TextStyle(
                      color: AppColors.textSecondaryC(isDark),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            for (int i = 0; i < _news.length; i++)
              _buildNewsRow(_news[i], isDark, isLast: i == _news.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _buildNewsRow(NewsItemModel item, bool isDark, {bool isLast = false}) {
    final r = context.r;
    final thumbSize = r.avatarSm;
    final hasImage = item.imageUrl.isNotEmpty;

    return Semantics(
      label: item.title,
      hint: 'Toca para leer el comunicado completo',
      button: true,
      child: OptimizedPressButton(
        onTap: () => _showNewsDetail(item),
        scaleDown: 0.98,
        child: Column(
          children: [
            Padding(
              padding: r.tilePadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Miniatura de imagen (si existe) o dot+fecha
                  if (hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(r.radiusSm),
                      child: SizedBox(
                        width: thumbSize,
                        height: thumbSize,
                        child: Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          cacheWidth:
                              200, // Optimización: carga la imagen al tamaño necesario
                          errorBuilder: (_, __, ___) =>
                              _buildNewsDotDate(item, isDark, r),
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                              ? child
                              : _buildNewsDotDate(item, isDark, r),
                        ),
                      ),
                    )
                  else
                    _buildNewsDotDate(item, isDark, r),
                  SizedBox(width: r.spaceSm),
                  // Título + fecha secundaria cuando hay imagen
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryC(isDark),
                          ),
                        ),
                        if (hasImage && item.dateTime != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _shortDate(item.dateTime),
                            style: context.texts.labelSmall.copyWith(
                              color: AppColors.textTertiaryC(isDark),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: r.spaceXs),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: r.iconSm * 0.6,
                    color: AppColors.textTertiaryC(isDark),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.tileHorizontalPad),
                child: Container(
                  height: 0.5,
                  color: isDark
                      ? AppColors.darkDivider
                      : const Color(0xFF191C1E).withValues(alpha: 0.06),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Bloque de dot + fecha (fallback cuando no hay imagen).
  Widget _buildNewsDotDate(NewsItemModel item, bool isDark, AppResponsive r) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: item.clase == 'A' ? AppColors.primary : AppColors.accent,
          ),
        ),
        SizedBox(width: r.spaceXs),
        Text(
          _shortDate(item.dateTime),
          style: context.texts.labelSmall.copyWith(
            color: AppColors.textTertiaryC(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonRow(bool isDark, {bool isLast = false}) {
    final r = context.r;
    return Column(
      children: [
        Padding(
          padding: r.tilePadding,
          child: Row(
            children: [
              Container(
                width: 50,
                height: 10,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkElevated
                      : const Color(0xFFE8ECF0),
                  borderRadius: BorderRadius.circular(r.spaceXs),
                ),
              ),
              SizedBox(width: r.spaceMd),
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkElevated
                        : const Color(0xFFE8ECF0),
                    borderRadius: BorderRadius.circular(r.spaceXs),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.tileHorizontalPad),
            child: Container(
              height: 0.5,
              color: isDark
                  ? AppColors.darkDivider
                  : const Color(0xFF191C1E).withValues(alpha: 0.06),
            ),
          ),
      ],
    );
  }

  /// Formato de fecha corta: "17 Mar"
  String _shortDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('d MMM', 'es').format(dt);
  }

  // ── Modal de detalle de noticia ───────────────────────────────────────────

  void _showNewsDetail(NewsItemModel item) {
    widget.tabShell.openSubRoute(context, (_) => NewsDetailScreen(item: item));
  }
}

/// Atenúa y desactiva un bloque de Inicio mientras la instructora espera en
/// el paso 1 del tutorial: las demás opciones siguen visibles (dan contexto
/// del menú real) pero no responden al toque — solo "Nueva Reserva" queda
/// activa, así la guía no se rompe por un tap accidental.
class _TutorialDim extends StatelessWidget {
  final bool dimmed;
  final Widget child;

  const _TutorialDim({required this.dimmed, required this.child});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      ignoring: dimmed,
      child: AnimatedOpacity(
        opacity: dimmed ? 0.38 : 1.0,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  /// Acceso visible pero aún no habilitado: la tarjeta se atenúa, muestra la
  /// pastilla "Próximamente" y su onTap abre el diálogo informativo en lugar
  /// de navegar.
  final bool comingSoon;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.comingSoon = false,
  });
}

/// Pastilla "PRÓXIMAMENTE" de las tarjetas de acceso aún no habilitadas.
/// Ámbar con contraste ajustado por tema (oscuro más luminoso, claro más
/// profundo para cumplir contraste WCAG sobre fondo de tarjeta).
class _ComingSoonBadge extends StatelessWidget {
  final bool isDark;

  const _ComingSoonBadge({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Color amber = isDark
        ? const Color(0xFFF59E0B)
        : const Color(0xFFB45309);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: amber.withValues(alpha: isDark ? 0.45 : 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        'PRÓXIMAMENTE',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          height: 1,
          color: amber,
        ),
      ),
    );
  }
}

// ─── Banner de estado de horario (extraído para evitar rebuilds del Home) ─────

class _HorarioBanner extends StatelessWidget {
  final bool isInHorario;
  final List<HorarioAtencionModel> horariosApp;

  const _HorarioBanner({required this.isInHorario, required this.horariosApp});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final horarioTexts = horariosApp.isNotEmpty
        ? horariosApp.map((h) => h.rangoHorario).join(' | ')
        : '';

    final Color accentColor;
    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String mensaje;

    if (isInHorario) {
      accentColor = AppColors.success;
      bgColor = isDark
          ? AppColors.success.withValues(alpha: 0.15)
          : const Color(0xFFECFDF5);
      textColor = isDark ? AppColors.success : const Color(0xFF065F46);
      icon = CupertinoIcons.checkmark_seal_fill;
      mensaje = 'Reservas habilitadas. Puede agendar su cita médica ahora.';
    } else {
      accentColor = AppColors.warning;
      bgColor = isDark
          ? AppColors.warning.withValues(alpha: 0.15)
          : const Color(0xFFFFFBEB);
      textColor = isDark ? AppColors.warning : const Color(0xFF92400E);
      icon = CupertinoIcons.clock_fill;
      mensaje = horarioTexts.isNotEmpty
          ? 'Fuera de horario de reservas. Horarios: $horarioTexts'
          : 'Fuera de horario de reservas.';
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.paddingH,
        vertical: r.spaceSm,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.maxContentWidth),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.spaceMd,
              vertical: r.spaceSm,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(r.radiusMd),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: r.iconSm, color: accentColor),
                ),
                SizedBox(width: r.spaceSm),
                Expanded(
                  child: Text(
                    mensaje,
                    style: context.texts.labelSmall.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
