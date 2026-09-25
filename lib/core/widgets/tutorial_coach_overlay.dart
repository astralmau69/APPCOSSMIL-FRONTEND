import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals;

import '../constants/app_colors.dart';
import '../constants/app_sounds.dart';
import '../extensions/responsive_extensions.dart';
import '../services/tutorial_voice.dart';
import '../theme/sound_manager.dart';
import 'liquid_glass.dart';
import 'tutorial_instructor.dart';
import '../theme/app_constants.dart';

/// Verde esmeralda del héroe "Nueva Reserva" — mismo lenguaje que Inicio/Login
/// y el resto del sistema liquid glass.
const Color kTutorialAccent = Color(0xFF059669);

/// Coach flotante del tutorial: la instructora ([TutorialInstructor]) parada
/// en la esquina inferior izquierda, guiando cada paso con burbujas de chat
/// que se revelan UNA por una, con un indicador de "escribiendo…" (tres
/// puntitos) entre ellas, como una conversación de verdad. La primera aparece
/// de inmediato; las siguientes llegan tras un breve tecleo. Arriba de las
/// burbujas va la insignia "MODO ENTRENAMIENTO · PASO X/N" y el botón para
/// salir.
///
/// Para NO tapar el flujo, el coach es auto-minimizable por tres vías:
///
/// 1. Tras un tiempo proporcional a lo que tarda leer el mensaje, las
///    burbujas se desvanecen y la instructora se encoge a una figurita
///    pegada a la barra de navegación que casi no cubre contenido.
/// 2. En cuanto el usuario interactúa con el contenido (tap o scroll), se
///    minimiza al instante vía [TutorialCoachOverlayState.collapse] — el
///    host conecta un `Listener` translúcido sobre el paso.
/// 3. Tocarla alterna entre minimizada y desplegada a voluntad.
///
/// Cada paso nuevo (o la celebración) la re-despliega solo.
///
/// Accesibilidad: las burbujas del paso son una live region (el lector de
/// pantalla anuncia cada instrucción nueva sin que el usuario tenga que
/// buscarla), y con lector activo el coach NO se auto-minimiza — ni por
/// timer ni por interacción del host — para no quitarle el texto a mitad
/// de lectura; solo el toque directo sobre la instructora lo alterna.
///
/// Diseñado para vivir DENTRO de un [Stack] que cubre el área de contenido
/// (lo monta una sola vez `BookingFlowScreen`, fuera del AnimatedSwitcher de
/// pasos: así la instructora persiste entre pasos y solo las burbujas se
/// renuevan). Solo intercepta toques sobre sus propios elementos — el resto
/// de la pantalla sigue interactivo.
class TutorialCoachOverlay extends StatefulWidget {
  /// Burbujas de texto del paso, en orden de aparición (cada una hace pop).
  final List<String> messages;
  final bool isDark;
  final bool celebrate;
  final VoidCallback onExit;

  /// Posición dentro del recorrido (1-based) y total de pasos, para el
  /// contador "PASO X/N". Si cualquiera es null, el contador no se muestra.
  final int? step;
  final int? totalSteps;

  /// Id del clip de voz de este paso (`assets/vof_tutorial/<voiceId>.mp3`, ver
  /// `tools/rvc/tutorial_lines.md`). Si es null o el clip falta, el coach
  /// funciona igual pero SIN voz: la instructora no adopta la coreografía de
  /// "hablar" (gating audio-primero).
  final String? voiceId;

  const TutorialCoachOverlay({
    super.key,
    required this.messages,
    required this.isDark,
    required this.onExit,
    this.celebrate = false,
    this.step,
    this.totalSteps,
    this.voiceId,
  });

  @override
  State<TutorialCoachOverlay> createState() => TutorialCoachOverlayState();
}

class TutorialCoachOverlayState extends State<TutorialCoachOverlay> {
  bool _expanded = true;
  Timer? _autoCollapse;

  /// true mientras las burbujas muestran el indicador de "escribiendo…": la
  /// instructora adopta la pose pensativa, como componiendo la frase.
  bool _typing = false;

  /// La instructora está "hablando" (hay locución sonando). Se enciende SOLO
  /// después de confirmar que el audio arrancó (ver [_playVoice]); su duración
  /// sincroniza la coreografía con lo que dura la voz.
  bool _speaking = false;
  Duration? _speakDuration;
  StreamSubscription<int>? _voiceSub;

  /// Token del clip que ESTE coach puso a sonar. Todo lo que llegue con otro
  /// token (el `complete` del paso anterior, o un `play()` que resolvió tarde)
  /// se descarta: es lo que mantenía la coreografía atada al audio equivocado.
  int? _voiceToken;

  /// true con lector de pantalla activo (TalkBack/VoiceOver): se desactiva
  /// todo auto-colapso — quitarle las instrucciones a un usuario que las está
  /// escuchando sería hostil; conserva el control manual tocando a la
  /// instructora.
  bool _accessibleNav = false;

  /// Escala de la instructora cuando está minimizada en la esquina.
  static const _collapsedScale = 0.45;

  @override
  void initState() {
    super.initState();
    _scheduleAutoCollapse();
    // La instructora llega: pop suave, en sintonía con su entrada elástica.
    SoundManager.playUi(AppSounds.coach);
    // Al terminar la locución, la instructora deja de "hablar" y vuelve a su
    // pose normal — justo cuando calla la voz.
    _voiceSub = TutorialVoice.onComplete.listen((token) {
      // Solo el fin de NUESTRA locución calla a la instructora. En los
      // recorridos push hay varios coaches vivos escuchando el mismo
      // reproductor estático, y el `complete` del clip anterior cortaba el
      // gesto de habla a mitad del paso nuevo.
      if (!mounted || !_speaking || token != _voiceToken) return;
      setState(() {
        _speaking = false;
        _speakDuration = null;
        _voiceToken = null;
      });
    });
    _playVoice();
  }

  /// Reproduce la locución del paso y, SOLO si arrancó de verdad, enciende la
  /// coreografía de "hablar" sincronizada con su duración. El orden importa
  /// (req. audio-primero): primero se dispara el audio; el estado de animación
  /// cambia después y únicamente si hay voz. Sin clip → no cambia nada.
  void _playVoice() {
    final id = widget.voiceId;
    // Deja de reconocer como propio cualquier clip anterior: si el `play()` del
    // paso previo aún está en vuelo, su resultado ya no debe encender nada.
    _voiceToken = null;
    if (id == null) return;
    TutorialVoice.play(id).then((clip) {
      // clip == null → sin voz: la instructora no "habla".
      if (!mounted || clip == null) return;
      // Entre el disparo y la respuesta pudo avanzar otro paso: si ya no es el
      // clip vigente, no hay nada que sincronizar.
      if (clip.token != TutorialVoice.currentToken) return;
      setState(() {
        _voiceToken = clip.token;
        _speaking = true;
        _speakDuration = clip.duration;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final a11y = MediaQuery.accessibleNavigationOf(context);
    if (a11y == _accessibleNav) return;
    _accessibleNav = a11y;
    if (a11y) {
      // Lector activado a mitad del tutorial: las instrucciones vuelven a
      // desplegarse y se quedan hasta que el usuario decida.
      _autoCollapse?.cancel();
      if (!_expanded) setState(() => _expanded = true);
    } else if (_expanded) {
      _scheduleAutoCollapse();
    }
  }

  @override
  void didUpdateWidget(covariant TutorialCoachOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Paso nuevo o celebración → re-desplegar y reiniciar el temporizador.
    if (!listEquals(oldWidget.messages, widget.messages) ||
        oldWidget.celebrate != widget.celebrate) {
      _autoCollapse?.cancel();
      // Paso nuevo: el estado de "escribiendo" y de "hablar" del paso anterior
      // no aplican hasta confirmar el nuevo audio.
      setState(() {
        _expanded = true;
        _typing = false;
        _speaking = false;
        _speakDuration = null;
        _voiceToken = null;
      });
      _scheduleAutoCollapse();
      // Avance de paso: dos notas ascendentes de confirmación. La celebración
      // no suena aquí — ya la cubre la locución de cita registrada (AUDIO 5).
      if (!widget.celebrate) {
        SoundManager.playUi(AppSounds.advance, volume: 0.45);
      }
    }
    // La locución sigue al paso: si cambió el id, reproduce el nuevo clip.
    if (oldWidget.voiceId != widget.voiceId) _playVoice();
  }

  @override
  void dispose() {
    _autoCollapse?.cancel();
    _voiceSub?.cancel();
    // Corta la locución al salir del paso/tutorial: nunca debe quedar sonando.
    TutorialVoice.stop();
    super.dispose();
  }

  /// Minimiza sola cuando ya hubo tiempo de sobra para leer: base + ritmo de
  /// lectura cómodo (~55 ms por carácter), entre 6 y 12 segundos. Con lector
  /// de pantalla activo no se programa nada.
  void _scheduleAutoCollapse() {
    if (_accessibleNav) return;
    final chars = widget.messages.join().length;
    final ms = (3000 + chars * 55).clamp(6000, 12000);
    _autoCollapse = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  /// Minimiza de inmediato (la llama el host cuando el usuario interactúa
  /// con el contenido del paso: el coach se aparta para no estorbar). Con
  /// lector de pantalla es un no-op: los toques de exploración no deben
  /// esconder las instrucciones.
  void collapse() {
    if (_accessibleNav || !_expanded) return;
    _autoCollapse?.cancel();
    setState(() => _expanded = false);
  }

  void _toggle() {
    _autoCollapse?.cancel();
    setState(() => _expanded = !_expanded);
    if (_expanded) _scheduleAutoCollapse();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    // La instructora es la guía: tiene que leerse de cuerpo entero y con la
    // cara reconocible, no como una miniatura al margen. Se limita contra la
    // altura REAL disponible para que nunca se recorte en pantallas bajas
    // (o en horizontal), que es como se perdía antes de vista.
    final maxChar = context.height * 0.30;
    final charH = math.min(r.profileAvatarSize * 1.55, maxChar);
    // La proporción sale del manifest del rig, no de un número a mano: el 0.58
    // de antes era el del set de láminas retirado y dejaba la figura estrecha.
    final charW = charH * TutorialInstructor.aspecto;
    // Lo más abajo posible sin chocar con el FloatingNavBar: justo en la
    // zona de respiro que las listas ya reservan (navBarBottomSpace incluye
    // spaceLg de aire), así incluso desplegada pisa lo mínimo de contenido.
    // En desktop/tablet-landscape (SideNavBar, navBarBottomSpace = 0) queda
    // un margen mínimo respecto al borde.
    final bottom = math.max(r.spaceSm, r.navBarBottomSpace - r.spaceLg + 4);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dur = reduceMotion ? Duration.zero : AppDurations.normal;

    return Positioned(
      left: r.spaceSm,
      right: r.paddingH,
      bottom: bottom,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Semantics(
            label:
                'Instructora del tutorial'
                '${widget.step != null && widget.totalSteps != null ? ', paso ${widget.step} de ${widget.totalSteps}' : ''}. '
                '${_expanded ? 'Ocultar' : 'Mostrar'} instrucciones',
            button: true,
            child: GestureDetector(
              onTap: _toggle,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: _expanded ? 1.0 : _collapsedScale,
                    alignment: Alignment.bottomLeft,
                    duration: dur,
                    curve: AppCurves.bounce,
                    child: TutorialInstructor(
                      height: charH,
                      // Explica mientras habla (y parpadea); piensa mientras
                      // "escribe" la próxima burbuja; al minimizarse baja la
                      // tablet y descansa. Ese cambio de postura es lo que la
                      // hace parecer alguien acompañando, y no una calcomanía
                      // pegada a la pantalla.
                      // Mientras suena la voz se queda EXPLICANDO (con el
                      // cabeceo de "hablar"): quedarse en "piensa" mientras la
                      // locución narra se veía incoherente. Solo piensa cuando
                      // teclea la próxima burbuja SIN voz sonando.
                      pose: widget.celebrate
                          ? InstructorPose.celebra
                          : !_expanded
                          ? InstructorPose.reposo
                          : (_typing && !_speaking)
                          ? InstructorPose.piensa
                          : InstructorPose.explica,
                      // Minimizada y sin celebrar: se queda quieta en reposo,
                      // sin gastar frames flotando en la esquina.
                      idle: _expanded || widget.celebrate,
                      entrance: true,
                      // Llega CAMINANDO hasta la esquina la primera vez (no
                      // aparece de golpe). Al celebrar ya está en su sitio: no
                      // camina, festeja.
                      walkIn: !widget.celebrate,
                      // Mientras suena la locución, "habla": alterna check↔risa
                      // sincronizado con la duración del audio (lip-sync de pose).
                      speaking: _speaking,
                      speakDuration: _speakDuration,
                      // Semilla del movimiento de boca. Sin ella, dos pasos
                      // con locuciones de la misma duración mueven los labios
                      // idéntico, que es lo que el parámetro evita.
                      voiceId: widget.voiceId,
                    ),
                  ),
                  // Globito de "tengo algo que decirte" junto a su cabeza
                  // cuando está minimizada — invita a tocarla. Si el paso es
                  // conocido muestra "X/N" para no perder la orientación del
                  // recorrido mientras el coach está fuera del camino.
                  Positioned(
                    left: charW * _collapsedScale - 6,
                    bottom: charH * _collapsedScale - 4,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _expanded ? 0.0 : 1.0,
                        duration: dur,
                        child: AnimatedScale(
                          scale: _expanded ? 0.3 : 1.0,
                          alignment: Alignment.bottomLeft,
                          duration: dur,
                          curve: AppCurves.bounce,
                          child: Container(
                            padding:
                                (widget.step != null &&
                                    widget.totalSteps != null)
                                ? const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  )
                                : const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: kTutorialAccent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: kTutorialAccent.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child:
                                (widget.step != null &&
                                    widget.totalSteps != null)
                                ? Text(
                                    '${widget.step}/${widget.totalSteps}',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                      color: Color(0xFFFFFFFF),
                                    ),
                                  )
                                : const Icon(
                                    CupertinoIcons.chat_bubble_fill,
                                    size: 11,
                                    color: Color(0xFFFFFFFF),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: r.spaceXs),
          // Las burbujas ceden espacio: la instructora ya ocupa su ancho y el
          // texto no necesita llegar al borde para leerse. Menos globo y más
          // personaje es justo lo que hace que se note quién está guiando.
          Flexible(
            child: IgnorePointer(
              // Minimizada, las burbujas son invisibles y NO bloquean toques
              // sobre el contenido que queda detrás.
              ignoring: !_expanded,
              child: AnimatedOpacity(
                opacity: _expanded ? 1.0 : 0.0,
                duration: dur,
                child: AnimatedScale(
                  scale: _expanded ? 1.0 : 0.85,
                  alignment: Alignment.bottomLeft,
                  duration: dur,
                  curve: AppCurves.bounce,
                  child: Padding(
                    // Las burbujas flotan a la altura de la cabeza de la
                    // instructora, como en un cómic.
                    padding: EdgeInsets.only(bottom: charH * 0.5),
                    child: _CoachBubbles(
                      // Renueva el pop escalonado cuando cambia el contenido
                      // (nuevo paso o celebración) sin remontar a la
                      // instructora.
                      key: ValueKey(widget.messages.join('\n')),
                      messages: widget.messages,
                      isDark: widget.isDark,
                      onExit: widget.onExit,
                      step: widget.step,
                      totalSteps: widget.totalSteps,
                      onTyping: (v) {
                        if (_typing != v) setState(() => _typing = v);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Columna de burbujas: insignia de modo + botón de salida, y una burbuja de
/// vidrio por mensaje. Las burbujas se revelan UNA por una, con un indicador de
/// "escribiendo…" (tres puntitos) entre ellas, como una conversación de verdad
/// — el paso completo se lee con ritmo de chat en vez de aparecer de golpe.
///
/// Con reduce-motion o lector de pantalla el revelado secuencial se salta:
/// todas las burbujas salen a la vez (el lector debe recibir el texto entero,
/// no a cuentagotas).
class _CoachBubbles extends StatefulWidget {
  final List<String> messages;
  final bool isDark;
  final VoidCallback onExit;
  final int? step;
  final int? totalSteps;

  /// Avisa cuando entra/sale el indicador de "escribiendo…", para que la
  /// instructora cambie a la pose pensativa mientras tanto.
  final ValueChanged<bool>? onTyping;

  const _CoachBubbles({
    super.key,
    required this.messages,
    required this.isDark,
    required this.onExit,
    this.step,
    this.totalSteps,
    this.onTyping,
  });

  @override
  State<_CoachBubbles> createState() => _CoachBubblesState();
}

class _CoachBubblesState extends State<_CoachBubbles> {
  /// Cuántas burbujas ya se revelaron. La primera aparece de inmediato (la guía
  /// tiene que poder leerse ya); las siguientes llegan con ritmo de chat.
  int _shown = 0;

  /// El indicador de "escribiendo…" está visible antes de la próxima burbuja.
  bool _typing = false;

  Timer? _timer;
  bool _instant = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final instant =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    // Solo (re)arranca en el primer montaje o si cambia el modo instantáneo
    // (p. ej. se enciende el lector de pantalla a mitad del paso).
    if (_started && instant == _instant) return;
    _started = true;
    _instant = instant;
    _timer?.cancel();
    setState(() {
      // Instantáneo (reduce-motion / lector) o un solo mensaje: todo de una.
      _shown = (_instant || widget.messages.length <= 1)
          ? widget.messages.length
          : 1;
      _typing = false;
    });
    if (!_instant && _shown < widget.messages.length) _scheduleTyping();
  }

  /// Tras un respiro enciende los puntitos y "teclea" un rato (proporcional a
  /// lo larga que sea la frase que viene) antes de revelar la próxima burbuja.
  void _scheduleTyping() {
    // NO migrar a AppDurations: este respiro y el typingMs de abajo marcan
    // el ritmo con el que el texto acompana a la voz de la instructora.
    // Cambiarlos desincroniza burbuja y audio (ver commit 45e449f).
    _timer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _typing = true);
      widget.onTyping?.call(true);
      final typingMs = (450 + widget.messages[_shown].length * 13).clamp(
        600,
        1200,
      );
      _timer = Timer(Duration(milliseconds: typingMs), _revealNext);
    });
  }

  void _revealNext() {
    if (!mounted) return;
    setState(() {
      _shown += 1;
      _typing = false;
    });
    widget.onTyping?.call(false);
    if (_shown < widget.messages.length) _scheduleTyping();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Interpola el ALTO de la pila de burbujas. La columna crece hacia arriba
  /// (el coach está anclado abajo), así que cada burbuja revelada y cada
  /// entrada/salida de los puntitos cambiaba la altura de golpe y toda la pila
  /// pegaba un salto seco: `_BubblePop` fundía la burbuja nueva, pero el
  /// reacomodo de las que ya estaban era instantáneo.
  ///
  /// En modo instantáneo NO se envuelve: `AnimatedSize` con `Duration.zero`
  /// arranca y termina su controlador dentro de su propio `performLayout`, y el
  /// listener resultante hace `markNeedsLayout` sobre un RenderObject que se
  /// está midiendo — assertion "A RenderAnimatedSize was mutated in its own
  /// performLayout implementation". Sin animación no hay nada que interpolar,
  /// así que la columna va cruda.
  Widget _sized(Widget child) {
    if (_instant) return child;
    return AnimatedSize(
      duration: AppDurations.normal,
      curve: AppCurves.snappy,
      alignment: Alignment.bottomLeft,
      // Sin recorte: las colitas y las sombras sobresalen de la caja.
      clipBehavior: Clip.none,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BubblePop(
          delayMs: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeBadge(step: widget.step, total: widget.totalSteps),
              SizedBox(width: r.spaceSm),
              _ExitButton(isDark: widget.isDark, onExit: widget.onExit),
            ],
          ),
        ),
        // Live region: al montarse (cada paso remonta esta columna vía la
        // ValueKey del host) el lector de pantalla anuncia la instrucción
        // completa sin que el usuario tenga que ir a buscarla. MergeSemantics
        // la vuelve UNA sola frase en vez de una burbuja por nodo.
        MergeSemantics(
          child: Semantics(
            liveRegion: true,
            child: _sized(
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _shown; i++) ...[
                    SizedBox(height: r.spaceXs),
                    _BubblePop(
                      key: ValueKey('bubble-$i'),
                      delayMs: 0,
                      child: _SpeechBubble(
                        text: widget.messages[i],
                        isDark: widget.isDark,
                        // La colita (hacia la instructora) va en la burbuja más
                        // baja que se muestre: la última revelada mientras no
                        // estén los puntitos.
                        withTail: !_typing && i == _shown - 1,
                      ),
                    ),
                  ],
                  if (_typing) ...[
                    SizedBox(height: r.spaceXs),
                    _BubblePop(
                      key: const ValueKey('typing'),
                      delayMs: 0,
                      child: _TypingBubble(isDark: widget.isDark),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Insignia "MODO ENTRENAMIENTO · PASO X/N" — refuerza que nada de lo que se
/// haga aquí es real, con sensación de progreso tipo videojuego.
class _ModeBadge extends StatelessWidget {
  final int? step;
  final int? total;

  const _ModeBadge({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final label = (step != null && total != null)
        ? 'MODO ENTRENAMIENTO · PASO $step/$total'
        : 'MODO ENTRENAMIENTO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kTutorialAccent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kTutorialAccent.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: Color(0xFFFFFFFF),
        ),
      ),
    );
  }
}

class _ExitButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onExit;

  const _ExitButton({required this.isDark, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Semantics(
      label: 'Salir del tutorial',
      button: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onExit,
        child: Icon(
          CupertinoIcons.xmark_circle_fill,
          size: r.iconMd,
          color: AppColors.textTertiaryC(isDark),
        ),
      ),
    );
  }
}

/// Burbuja de chat de vidrio con la colita opcional apuntando a la izquierda
/// (hacia la instructora). Sin blur real: flota sobre contenido que scrollea.
class _SpeechBubble extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool withTail;

  const _SpeechBubble({
    required this.text,
    required this.isDark,
    required this.withTail,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final bubble = LiquidGlass(
      isDark: isDark,
      borderRadius: BorderRadius.circular(r.radiusLg),
      padding: EdgeInsets.symmetric(
        horizontal: r.spaceMd,
        vertical: r.spaceSm + 2,
      ),
      shadow: AppColors.cardShadowFor(isDark),
      child: Text(
        text,
        style: context.texts.bodySmall.copyWith(
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryC(isDark),
        ),
      ),
    );

    if (!withTail) return bubble;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        bubble,
        Positioned(
          left: -7,
          bottom: 11,
          child: _BubbleTailMark(isDark: isDark),
        ),
      ],
    );
  }
}

/// Indicador de "escribiendo…": tres puntitos que rebotan en oleada dentro de
/// una burbuja de vidrio, con la colita apuntando a la instructora. Aparece
/// entre una burbuja y la siguiente; nunca con reduce-motion ni lector de
/// pantalla (ahí las burbujas salen todas de una).
class _TypingBubble extends StatefulWidget {
  final bool isDark;

  const _TypingBubble({required this.isDark});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppDurations.extra)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final dotColor = AppColors.textSecondaryC(widget.isDark);
    final bubble = LiquidGlass(
      isDark: widget.isDark,
      borderRadius: BorderRadius.circular(r.radiusLg),
      padding: EdgeInsets.symmetric(
        horizontal: r.spaceMd,
        vertical: r.spaceSm + 5,
      ),
      shadow: AppColors.cardShadowFor(widget.isDark),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _dot(i, dotColor),
              ],
            ],
          );
        },
      ),
    );

    // Sin semántica propia: el indicador solo se muestra a usuarios SIN lector
    // de pantalla (con lector, el revelado es instantáneo y no hay puntitos).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        bubble,
        Positioned(
          left: -7,
          bottom: 11,
          child: _BubbleTailMark(isDark: widget.isDark),
        ),
      ],
    );
  }

  Widget _dot(int i, Color color) {
    // Cada punto va desfasado un poco: la oleada sube de izquierda a derecha.
    final phase = _ctrl.value * 2 * math.pi - i * 0.9;
    final lift = math.sin(phase).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, -3 * lift),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.35 + 0.55 * lift),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Triangulito de vidrio que apunta a la izquierda (hacia la instructora).
/// Va dentro de un [Positioned] para pegarse al borde de la burbuja.
class _BubbleTailMark extends StatelessWidget {
  final bool isDark;

  const _BubbleTailMark({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(9, 16),
      painter: _BubbleTailPainter(
        color: isDark
            ? const Color(0xFF223047).withValues(alpha: 0.85)
            : const Color(0xFFFFFFFF).withValues(alpha: 0.92),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;

  const _BubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Pop de entrada de cada burbuja: escala con rebote + fade, creciendo desde
/// abajo-izquierda (el lado de la instructora), tras un retraso escalonado.
/// Con reduce-motion aparece de inmediato, sin animar.
class _BubblePop extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _BubblePop({super.key, required this.child, required this.delayMs});

  @override
  State<_BubblePop> createState() => _BubblePopState();
}

class _BubblePopState extends State<_BubblePop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppDurations.normal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _delay?.cancel();
      _ctrl.value = 1.0;
    } else if (_ctrl.value == 0 && !_ctrl.isAnimating && _delay == null) {
      // Sin retraso, arranca en el acto: pasar por un Timer solo para esperar
      // cero milisegundos le regalaba un frame muerto a cada burbuja.
      if (widget.delayMs <= 0) {
        _ctrl.forward();
      } else {
        _delay = Timer(Duration(milliseconds: widget.delayMs), () {
          if (mounted) _ctrl.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _ctrl, curve: AppCurves.smooth),
      child: SlideTransition(
        // Deslizamiento mínimo desde el lado de la instructora: el pop gana
        // dirección (ella "lanza" la burbuja) sin volverse aparatoso.
        position: Tween<Offset>(
          begin: const Offset(-0.035, 0.10),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _ctrl, curve: AppCurves.snappy)),
        child: ScaleTransition(
          scale: CurvedAnimation(parent: _ctrl, curve: AppCurves.bounce),
          alignment: Alignment.bottomLeft,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Hoja de confirmación "¿Salir del tutorial?" — se llama antes de abandonar
/// el modo demostración desde cualquiera de las pantallas reales.
Future<bool> confirmExitTutorial(BuildContext context) async {
  final confirmed = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('¿Salir del tutorial?'),
      message: const Text(
        'Puedes volver a verlo cuando quieras desde tu Perfil.',
      ),
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Salir del tutorial'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx, false),
        child: const Text('Continuar viendo'),
      ),
    ),
  );
  return confirmed ?? false;
}
