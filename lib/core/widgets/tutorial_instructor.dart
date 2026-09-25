import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../animations/instructor/instructor_clip.dart';
import '../animations/instructor/instructor_clips.dart';
import '../animations/instructor/instructor_rig.dart';
import '../animations/instructor/instructor_rig_view.dart';
import '../animations/instructor/instructor_solver.dart';

/// Poses de la instructora. Cada una es una ilustración distinta recortada de
/// las láminas del personaje con `tools/extract_instructor_frames.py`.
enum InstructorPose {
  /// De pie, relajada, con la tablet al costado. Para cuando no está dando
  /// instrucciones (coach minimizado).
  reposo,

  /// Señalando la tablet: la pose de "te estoy explicando". Es la única con
  /// gemelas de ojos cerrados y de guiño, así que es la única que hace
  /// micro-expresiones.
  explica,

  /// Sonriendo con el visto verde en la tablet: misión cumplida. Al celebrar
  /// alterna con [festeja] para que el festejo tenga movimiento.
  celebra,

  /// Riendo con la mano en alto: festejo. Solo aparece alternando con
  /// [celebra] durante la celebración.
  festeja,

  /// Ojos cerrados, pensativa: "déjame ver…". Se usa mientras el coach
  /// "escribe" la próxima burbuja.
  piensa,

  /// Saludo militar. Presentación del tutorial.
  saludo,

  /// Señala al frente con el índice. Gesto por paso del flujo de reserva.
  senala,

  /// Pulgar arriba: confirmación de que el usuario hizo lo correcto.
  pulgarArriba,

  /// Palma al frente: "espere un momento".
  alto,

  /// Ojos muy abiertos y cabeza atrás: reacción a algo inesperado.
  sorpresa,
}

/// Proporción ancho/alto de la figura mientras el manifest todavía no llegó.
///
/// Existe UNA sola vez: el coach reserva su caja con [TutorialInstructor.aspecto],
/// que devuelve el valor real del manifest en cuanto está cargado. Tener el
/// número escrito a mano en dos sitios fue lo que dejó al coach reservando la
/// proporción del set anterior (0.58) para una figura que ya no la tenía.
const double kInstructorAspectFallback = 0.63;

/// Precarga el rig una sola vez por proceso. Lo llama Inicio antes de que la
/// instructora aparezca, para que su primer fotograma no espere al disco.
Future<void> precacheInstructorRig() => _InstructorAssets.warmUp();

class _InstructorAssets {
  static InstructorRig? rig;
  static InstructorImages? images;
  static Future<InstructorRig>? _rigFuture;
  static Future<InstructorImages>? _imgFuture;

  /// El manifest: un JSON chico. Llega rápido y ya da pose válida.
  ///
  /// Si ya está resuelto devuelve un Future NUEVO en vez del cacheado. No es
  /// un detalle: un Future creado dentro de la zona fake-async de un test
  /// jamás completa en la del siguiente, así que reutilizarlo colgaría a todo
  /// widget montado después del primero.
  static Future<InstructorRig> soloRig() {
    final r = rig;
    if (r != null) return Future.value(r);
    return _rigFuture ??= loadInstructorRig().then((x) => rig = x);
  }

  /// Los PNG decodificados. Tardan más, y la figura puede esperarlos con la
  /// pose ya resuelta en vez de no existir.
  static Future<InstructorImages> imagenes(InstructorRig r) {
    final i = images;
    if (i != null) return Future.value(i);
    // Las dos vistas en el MISMO mapa: la de perfil sólo aparece 1,3 s al
    // entrar, y decodificarla entonces daría el tirón justo en la entrada.
    final perfil = r.profile;
    return _imgFuture ??= InstructorImages.load([
      r,
      if (perfil != null) perfil,
    ]).then((x) => images = x);
  }

  static Future<void> warmUp() async => imagenes(await soloRig());
}

/// Instructora militar que guía los tutoriales. Está VIVA en tres capas:
///
/// - **Pose**: cambia de ilustración según lo que esté haciendo
///   ([InstructorPose]), con un fundido corto entre una y otra.
/// - **Parpadeo**: en [InstructorPose.explica] cierra los ojos cada pocos
///   segundos. Es el detalle que más hace por que un dibujo quieto parezca
///   estar presente; los intervalos son irregulares a propósito, porque un
///   parpadeo metronómico se nota falso.
/// - **Cuerpo**: flota y se balancea en bucle; en [InstructorPose.celebra]
///   son saltitos enérgicos.
///
/// La entrada tiene dos modos: [entrance] da una aparición elástica al
/// montarse; con [walkIn] la instructora ENTRA CAMINANDO desde fuera del borde
/// izquierdo hasta su sitio (ciclo de 7 fotogramas de perfil) y recién ahí pasa
/// a su pose y empieza a flotar/parpadear. Es lo que la hace sentir "de
/// verdad": no aparece, llega.
///
/// Solo anima transform + opacidad (propiedades del compositor): seguro en
/// web/CanvasKit y GPUs débiles. Con reduce-motion queda estática en su pose
/// neutral, sin parpadeo, sin caminata y con la entrada saltada.
class TutorialInstructor extends StatefulWidget {
  final double height;
  final InstructorPose pose;
  final bool entrance;

  /// Entra caminando desde el borde izquierdo hasta su sitio antes de posar.
  /// Requiere [entrance]. Ignorado con reduce-motion (aparece ya parada).
  final bool walkIn;

  /// Si el bucle de flote/balanceo debe correr. Se apaga cuando la instructora
  /// está minimizada en la esquina (coach colapsado): ahí casi no se mueve, así
  /// que dejar un AnimationController repintando a 60 fps es puro desperdicio en
  /// GPUs débiles. Con `false` queda quieta en su postura de reposo; la entrada
  /// elástica y el cambio de pose siguen funcionando.
  final bool idle;

  /// true mientras suena la locución del paso. Habilita la coreografía de
  /// festejo SOLO si además es el paso de éxito ([pose] == celebra); en pasos
  /// regulares no cambia la pose (narra con explica). Ver [_talking].
  final bool speaking;

  /// Duración de la locución en curso. En el paso de éxito, la alternancia
  /// check↔risa se AJUSTA para caber exactamente en ese tiempo (una pasada,
  /// ~una pose por segundo con clamp 2..10). Sincroniza el gesto con la voz.
  final Duration? speakDuration;

  /// Id del clip de voz en curso. Sólo se usa como SEMILLA del movimiento de
  /// boca, para que dos pasos distintos no muevan los labios igual. Opcional:
  /// sin él la semilla sale de la duración.
  final String? voiceId;

  /// Ancho/alto de la figura, leído del manifest en cuanto cargó. Lo usa quien
  /// tenga que RESERVAR su caja antes de que exista (el coach), para no tener
  /// la proporción del arte escrita a mano.
  static double get aspecto =>
      _InstructorAssets.rig?.aspect ?? kInstructorAspectFallback;

  const TutorialInstructor({
    super.key,
    required this.height,
    this.pose = InstructorPose.explica,
    this.entrance = false,
    this.walkIn = false,
    this.idle = true,
    this.speaking = false,
    this.speakDuration,
    this.voiceId,
  });

  @override
  State<TutorialInstructor> createState() => _TutorialInstructorState();
}

class _TutorialInstructorState extends State<TutorialInstructor>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _pop;

  /// Entrada caminando: recorre el ciclo mientras se traslada hasta su sitio.
  late final AnimationController _walk;

  /// Golpe de cambio de pose: una compresión corta con rebote que corre SOBRE
  /// el fundido cruzado.
  ///
  /// Un fundido entre dos dibujos DISTINTOS se lee como una disolvencia
  /// fantasmal (la tablet se desvanece en el aire, el brazo se materializa
  /// arriba). Acompañarlo de movimiento hace que el ojo lea el movimiento como
  /// la causa del cambio y la disolvencia deje de saltar a la vista — truco
  /// clásico de animación 2D. Es un paliativo mientras no existan los cuadros
  /// intermedios (ver `tools/instructor_prompts.md`); cuando lleguen, este
  /// golpe se queda igual y sirve de acento.
  late final AnimationController _swap;
  static const _swapDur = Duration(milliseconds: 260);

  /// Última casilla de la alternancia festejo vista, para disparar el golpe
  /// solo cuando el asset REALMENTE cambia (no en cada frame).
  int _lastTalkIdx = -1;

  /// Los seis controladores fundidos en un solo Listenable, creado UNA vez.
  /// Construirlo dentro de `build` (como estaba) le daba al AnimatedBuilder un
  /// objeto distinto en cada reconstrucción, así que desenganchaba y volvía a
  /// enganchar los cinco listeners en cada parpadeo y en cada cambio de pose.
  late final Listenable _loop;

  static const _idleCalm = Duration(milliseconds: 2600);
  static const _idleParty = Duration(milliseconds: 1500);

  /// Duración de la caminata de entrada y cuántas zancadas da en ese trayecto.
  ///
  /// Dos, no una: el trayecto es 1,25 veces su altura, y cruzarlo de una sola
  /// zancada le daría trancos de gigante. Como [InstructorClips.walkCycle]
  /// cierra donde abrió, encadenarlas no produce ningún corte, y en `value=1`
  /// la fase vuelve a 0 — o sea que llega con los pies juntos, no a media
  /// tranca.
  static const _walkDur = Duration(milliseconds: 1300);
  static const _walkStrides = 2;

  /// true mientras la caminata de entrada está en curso.
  bool get _walking => widget.walkIn && !_reduceMotion && _walk.value < 1.0;

  /// Cuánto dura cada micro-expresión y cada cuánto vuelve (con margen
  /// aleatorio). Un guiño dura bastante más que un parpadeo: es un gesto
  /// dirigido a ti, no un reflejo.
  static const _blinkDur = Duration(milliseconds: 130);
  static const _winkDur = Duration(milliseconds: 780);
  static const _blinkMinGap = 2600;
  static const _blinkJitter = 3200;

  /// De cada tantas micro-expresiones, una es guiño. Poco frecuente a
  /// propósito: si guiñara a menudo dejaría de sentirse espontáneo.
  static const _winkEveryN = 4;

  final _rng = math.Random();
  Timer? _blinkTimer;

  /// Cuántas vueltas lleva dadas el bucle de cabeceo. Sin esto la boca
  /// recorrería las mismas cuatro aberturas cada segundo, que es exactamente la
  /// cadencia de metrónomo que el guion pide evitar.
  /// Gesto en curso (señalar, pulgar arriba, alto…). Es un disparo único que
  /// se QUEDA en su pose final: soltarlo al terminar haría que el brazo cayera
  /// solo, que es justo lo que no hace un brazo de verdad.
  late final AnimationController _gesto;
  InstructorClip? _clipGesto;

  int _cicloBoca = 0;
  double _ultimoSpeak = 0;

  /// Micro-expresión activa (parpadeo o guiño); nula con su cara normal.
  InstructorEyes? _microOjos;

  /// El esqueleto y sus piezas. Llegan en dos fases: primero el manifest
  /// (rápido, es un JSON) y después los PNG decodificados. Así la figura tiene
  /// pose válida desde el primer fotograma aunque las texturas tarden.
  InstructorRig? _rig;
  InstructorImages? _images;
  bool _reduceMotion = false;

  /// Recorre la alternancia celebra↔festeja mientras "habla"/celebra. Su
  /// duración se ajusta a la locución (o a un periodo por defecto en bucle),
  /// así el conteo de poses cabe exactamente en el audio.
  late final AnimationController _talk;

  /// Cabeceo suave de "estoy hablando" para los pasos NORMALES. No hay
  /// fotograma de boca abierta, así que el movimiento es lo que comunica que
  /// ella dice las palabras: corre en bucle SOLO mientras suena la locución y
  /// se detiene en cuanto calla, para que el gesto quede atado a la voz.
  late final AnimationController _speak;

  bool get _celebrating => widget.pose == InstructorPose.celebra;

  /// true cuando corresponde el cabeceo de "hablar" de un paso normal: suena
  /// la voz, no es el paso de éxito (ese ya festeja) y hay movimiento.
  bool get _speakBob => !_reduceMotion && widget.speaking && !_celebrating;

  /// true SOLO cuando corresponde la alternancia dinámica de festejo
  /// (check verde ↔ risa). Se reserva —a propósito— al paso de ÉXITO (pose
  /// [InstructorPose.celebra]) y únicamente mientras suena su locución. En los
  /// pasos regulares la instructora narra con su pose neutral (explica): en una
  /// app de citas médicas festejar en cada paso desentona. Sin audio o al
  /// terminar, cae al `else` del build → su pose de reposo (nunca festejo).
  bool get _talking => !_reduceMotion && _celebrating && widget.speaking;

  /// Cuántas veces alterna check↔risa. Con audio, ~una por segundo (4–5 en 5 s);
  /// sin audio, un número par para que el bucle cierre limpio.
  int get _talkSwaps {
    final d = widget.speakDuration;
    if (d != null) return (d.inMilliseconds / 1050).round().clamp(2, 10);
    return 6;
  }

  /// Cuánto dura una pasada completa de la alternancia.
  Duration get _talkPeriod =>
      widget.speakDuration ?? Duration(milliseconds: _talkSwaps * 950);

  /// Cadencia del cabeceo cuando no hay duración de locución que seguir.
  static const _speakBobDefault = Duration(milliseconds: 650);

  /// Cuánto dura UN asentimiento. Con locución se ajusta para que quepa un
  /// número ENTERO de cabeceos en el audio: así el último se cierra justo
  /// cuando ella calla, en vez de quedar cortado a media caída. Antes era un
  /// bucle fijo de 650 ms sin ninguna relación con el clip, de modo que el
  /// gesto y la voz iban cada uno por su lado por mucho que el comentario
  /// dijera "sincronizado".
  Duration get _speakBobPeriod {
    final d = widget.speakDuration;
    if (d == null || d == Duration.zero) return _speakBobDefault;
    // ~un asentimiento por segundo, redondeado a un divisor exacto del clip.
    final n = (d.inMilliseconds / 900).round().clamp(1, 12);
    return Duration(milliseconds: (d.inMilliseconds / n).round());
  }

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: _celebrating ? _idleParty : _idleCalm,
    );
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _walk = AnimationController(vsync: this, duration: _walkDur);
    _talk = AnimationController(vsync: this, duration: _talkPeriod);
    _speak = AnimationController(vsync: this, duration: _speakBobPeriod);
    _swap = AnimationController(vsync: this, duration: _swapDur);
    _gesto = AnimationController(vsync: this, duration: _swapDur);
    _clipGesto = clipForPose(widget.pose);
    if (_clipGesto != null) _gesto.value = 1.0;
    _loop = Listenable.merge([_idle, _pop, _walk, _talk, _speak, _swap, _gesto]);
    // La alternancia check↔risa no pasa por didUpdateWidget (la mueve _talk),
    // así que el golpe se engancha a su cruce de casilla.
    _talk.addListener(_watchTalkSwap);
    _speak.addListener(_watchSpeakWrap);
    // Al caminar hasta su sitio, la aparición elástica sobra (llegaría dando un
    // respingo tras el último paso): la pose ya entra fundida desde el andar.
    if (!widget.entrance || widget.walkIn) _pop.value = 1.0;
    _cargarRig();
    _walk.addStatusListener((s) {
      // Al llegar, arranca la vida "de pie": flote, parpadeo y la pose real
      // relevan al último fotograma de caminata.
      if (s == AnimationStatus.completed && mounted) {
        setState(() {});
        _syncIdle();
        _syncBlinking();
        // Aterrizaje: el relevo perfil→frente es el fundido más brusco de
        // todos, y el golpe lo lee como "llegó y se plantó".
        _kickSwap();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precarga TODAS las poses la primera vez (no solo las gemelas de parpadeo
    // y los fotogramas de caminata). Al lanzar el tutorial desde Perfil → Ayuda
    // NO se pasa por la precarga de la invitación de Inicio, así que sin esto
    // cada cambio de pose (explica↔piensa↔celebra↔festeja) y cada fotograma del
    // andar se decodificaban sobre la marcha — la causa principal de los
    // tirones. Ya en caché, el relevo entre poses es instantáneo. Es async y
    // fuera del hilo de UI, así que no bloquea el primer frame.
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _pop.value = 1.0;
      _walk.value = 1.0;
      _stopBlinking();
    } else {
      // Arranca la caminata de entrada una sola vez.
      if (widget.walkIn && _walk.value == 0 && !_walk.isAnimating) {
        _walk.forward();
      } else if (!widget.walkIn && _pop.value < 1.0 && !_pop.isAnimating) {
        _pop.forward();
      }
      // Mientras camina, la vida "de pie" (flote/parpadeo) espera a que llegue.
      if (!_walking) _syncBlinking();
    }
    if (!_walking) _syncIdle();
    _syncTalk();
    _syncSpeak();
  }

  @override
  void didUpdateWidget(covariant TutorialInstructor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final poseChanged = oldWidget.pose != widget.pose;
    final speakChanged =
        oldWidget.speaking != widget.speaking ||
        oldWidget.speakDuration != widget.speakDuration;
    if (poseChanged) {
      _syncGesto();
      _syncBlinking();
      // Se sigue pintando la pose vieja hasta el pico de compresión.
      _kickSwap();
    }
    // La cadencia (calmo ↔ saltitos de festejo) la resuelve _syncIdle
    // comparando duraciones: solo interrumpe el bucle cuando REALMENTE cambia
    // el ritmo, y esperando a que cierre el ciclo. Pasar de explica a piensa ya
    // no reinicia el flote.
    _syncIdle();
    // Reinicia la coreografía de voz si empezó a hablar o cambió la locución.
    _syncTalk(restart: speakChanged || poseChanged);
    if (speakChanged || poseChanged) _syncSpeak();
  }

  /// Arranca/detiene la coreografía de "hablar" (alternancia check↔risa). Con
  /// audio ([TutorialInstructor.speakDuration]) hace UNA pasada que cubre justo
  /// esa duración; sin audio (celebración), va en bucle. El fundido suave entre
  /// poses lo pone el AnimatedSwitcher (easeInOutCubic, ~180 ms).
  void _syncTalk({bool restart = false}) {
    if (_talking) {
      _talk.duration = _talkPeriod;
      if (widget.speakDuration != null) {
        if (!_talk.isAnimating || restart) _talk.forward(from: 0);
      } else {
        if (!_talk.isAnimating || restart) _talk.repeat();
      }
    } else {
      if (_talk.isAnimating) _talk.stop();
      if (_talk.value != 0) _talk.value = 0;
    }
  }

  /// Dispara el golpe del cambio de pose. Con reduce-motion no hay golpe: el
  /// relevo de imagen es instantáneo y añadirle rebote sería justo el tipo de
  /// movimiento que ese ajuste pide evitar.
  void _kickSwap() {
    if (_reduceMotion || _walking) return;
    _swap.forward(from: 0);
  }

  /// Vigila el cruce de casilla de la alternancia celebra↔festeja para acentuar
  /// cada relevo con el golpe.
  void _watchTalkSwap() {
    if (!_talking) {
      _lastTalkIdx = -1;
      return;
    }
    final idx = (_talk.value * _talkSwaps).floor();
    if (idx == _lastTalkIdx) return;
    final primera = _lastTalkIdx < 0;
    _lastTalkIdx = idx;
    if (!primera) _kickSwap();
  }

  /// Arranca el gesto de la pose nueva, o deshace el anterior si la pose
  /// entrante no gesticula.
  void _syncGesto() {
    final nuevo = clipForPose(widget.pose);
    if (nuevo != null) {
      _clipGesto = nuevo;
      _gesto.duration = nuevo.duration;
      if (_reduceMotion) {
        _gesto.value = 1.0;
      } else {
        _gesto.forward(from: 0);
      }
      return;
    }
    // Sin gesto nuevo: el brazo vuelve por donde vino, no se desploma.
    if (_clipGesto == null) return;
    if (_reduceMotion) {
      _gesto.value = 0.0;
      _clipGesto = null;
      return;
    }
    _gesto.reverse().whenComplete(() {
      if (mounted && clipForPose(widget.pose) == null) _clipGesto = null;
    });
  }

  /// Cuenta las vueltas del cabeceo detectando el salto de fase de 1 a 0.
  void _watchSpeakWrap() {
    final v = _speak.value;
    if (v < _ultimoSpeak) _cicloBoca++;
    _ultimoSpeak = v;
  }

  /// Apaga un bucle SIN teletransportar la figura: lo deja terminar el ciclo en
  /// curso y recién ahí llama a [onSettled].
  ///
  /// Es el arreglo del tirón más visible del coach. Estos bucles son senoidales
  /// sobre la fase `value * 2π`, así que la fase 1 dibuja exactamente lo mismo
  /// que la fase 0: dejar correr lo que falta del ciclo es indistinguible del
  /// reposo, pero continuo. Cortar con `value = 0` (como estaba) hacía que la
  /// instructora SALTARA desde donde estuviera el flote — al minimizarse, al
  /// callar y en cada cambio de pose.
  void _settle(AnimationController c, {required VoidCallback onSettled}) {
    if (!c.isAnimating) {
      onSettled();
      return;
    }
    final total = c.duration ?? Duration.zero;
    c
        .animateTo(
          1.0,
          duration: total * (1 - c.value),
          curve: Curves.linear, // el bucle ya trae su propia curva senoidal
        )
        .whenComplete(() {
          if (mounted) onSettled();
        });
  }

  /// Enciende/apaga el cabeceo de "hablar" de los pasos normales. Atado a la
  /// voz: corre mientras suena y se cierra al callar, para que el movimiento
  /// sea consistente con la locución. Transform-only, no toca la pose.
  void _syncSpeak() {
    if (!_speakBob) {
      if (_speak.isAnimating) {
        _settle(
          _speak,
          onSettled: () {
            if (_speakBob) _syncSpeak(); // volvió a hablar mientras cerraba
          },
        );
      }
      return;
    }
    final period = _speakBobPeriod;
    if (!_speak.isAnimating) {
      _speak.duration = period;
      _speak.repeat();
    } else if (_speak.duration != period) {
      // Locución nueva con otra cadencia: cierra el asentimiento en curso y
      // arranca con el periodo del clip nuevo.
      _settle(_speak, onSettled: _syncSpeak);
    }
  }

  /// Enciende o apaga el bucle de flote según reduce-motion y
  /// [TutorialInstructor.idle], y adopta la cadencia de la pose activa (el
  /// festejo es más rápido que el flote calmo). Los cambios de cadencia esperan
  /// a que cierre el ciclo en curso: `repeat()` en caliente reinicia la fase a
  /// 0, que es justo el brinco que se veía al cambiar de pose.
  void _syncIdle() {
    if (_reduceMotion || !widget.idle) {
      if (_idle.isAnimating) _settle(_idle, onSettled: _syncIdle);
      return;
    }
    final period = _celebrating ? _idleParty : _idleCalm;
    if (!_idle.isAnimating) {
      _idle.duration = period;
      _idle.repeat();
    } else if (_idle.duration != period) {
      _settle(_idle, onSettled: _syncIdle);
    }
  }

  Future<void> _cargarRig() async {
    final rig = await _InstructorAssets.soloRig();
    if (!mounted) return;
    setState(() => _rig = rig);
    final imgs = await _InstructorAssets.imagenes(rig);
    if (!mounted) return;
    setState(() => _images = imgs);
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _talk.removeListener(_watchTalkSwap);
    _speak.removeListener(_watchSpeakWrap);
    _idle.dispose();
    _pop.dispose();
    _walk.dispose();
    _talk.dispose();
    _speak.dispose();
    _swap.dispose();
    _gesto.dispose();
    // Las texturas NO se liberan aqui: las posee `_InstructorAssets`, que las
    // comparte entre todas las instancias y vive lo que el proceso. Liberarlas
    // al desmontar una dejaria a las demas dibujando sobre imagenes muertas.
    super.dispose();
  }

  /// Solo parpadea la pose que tiene gemela de ojos cerrados (y nunca mientras
  /// camina: entra de perfil, no mira al usuario).
  void _syncBlinking() {
    final debe =
        !_reduceMotion && !_walking && widget.pose == InstructorPose.explica;
    if (debe) {
      if (_blinkTimer == null) _scheduleBlink();
    } else {
      _stopBlinking();
    }
  }

  void _stopBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    if (_microOjos != null && mounted) setState(() => _microOjos = null);
  }

  void _scheduleBlink() {
    final gap = _blinkMinGap + _rng.nextInt(_blinkJitter);
    _blinkTimer = Timer(Duration(milliseconds: gap), () {
      if (!mounted) return;
      final guina = _rng.nextInt(_winkEveryN) == 0;
      setState(
        () => _microOjos = guina ? InstructorEyes.guino : InstructorEyes.cerrados,
      );
      _blinkTimer = Timer(guina ? _winkDur : _blinkDur, () {
        if (!mounted) return;
        setState(() => _microOjos = null);
        _scheduleBlink();
      });
    });
  }

  /// Qué ojos corresponden a la pose cuando no hay micro-expresión encima.
  InstructorEyes _ojosDePose(InstructorPose pose) => switch (pose) {
    InstructorPose.celebra || InstructorPose.festeja => InstructorEyes.feliz,
    InstructorPose.piensa => InstructorEyes.cerrados,
    InstructorPose.sorpresa => InstructorEyes.sorpresa,
    _ => InstructorEyes.abiertos,
  };

  /// Sprite de boca activo.
  ///
  /// Callada, la boca cerrada. Hablando, se camina la secuencia determinista de
  /// [mouthSequence]: unas cuatro aberturas por vuelta del cabeceo, y el
  /// contador de vueltas evita que se repita el mismo tramo cada segundo.
  String _bocaActiva() {
    if (_reduceMotion || !widget.speaking) return 'boca_0';
    final seq = mouthSequence(
      voiceId: widget.voiceId ?? 'd${widget.speakDuration?.inMilliseconds ?? 0}',
      duration: widget.speakDuration ?? _speakBobDefault,
    );
    const porVuelta = 4;
    final dentro = (_speak.value * porVuelta).floor().clamp(0, porVuelta - 1);
    return 'boca_${seq[(_cicloBoca * porVuelta + dentro) % seq.length]}';
  }

  /// Las capas de animación activas en este instante, de base a encima.
  ///
  /// Cada capa declara sólo los huesos que toca, así que la respiración sigue
  /// corriendo por debajo de cualquier gesto. Con reduce-motion no hay ninguna:
  /// la figura queda en su pose de reposo.
  List<ClipLayer> _capas() {
    if (_reduceMotion) {
      // Estática, pero en la pose del gesto: quitar el movimiento no es quitar
      // la postura. Sin esto, "señalar" con reduce-motion no señalaría nada.
      final g = _clipGesto;
      return g == null ? const [] : [ClipLayer(clip: g, t: 1.0)];
    }
    if (!widget.idle) {
      final g = _clipGesto;
      return g == null ? const [] : [ClipLayer(clip: g, t: _gesto.value)];
    }
    final base = _celebrating ? InstructorClips.idleParty : InstructorClips.idle;
    return [
      ClipLayer(clip: base, t: _idle.value),
      // El cabeceo de hablar se SUMA a la respiración: la cabeza asiente
      // mientras el torso sigue subiendo y bajando por debajo.
      if (_speakBob) ClipLayer(clip: InstructorClips.speak, t: _speak.value),
      // El gesto va ENCIMA: mueve el brazo sin tocar el torso, que sigue
      // respirando por debajo. Eso es lo que hace barato el repertorio.
      if (_clipGesto != null) ClipLayer(clip: _clipGesto!, t: _gesto.value),
    ];
  }

  /// Fase del ciclo de caminata (0..1), encadenando [_walkStrides] zancadas a
  /// lo largo de la entrada.
  double get _faseCaminata => (_walk.value * _walkStrides) % 1.0;

  @override
  Widget build(BuildContext context) {
    final h = widget.height;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _loop,
        // El Image va DENTRO del builder (no como child cacheado): durante la
        // caminata y el habla el fotograma cambia en cada frame.
        builder: (context, _) {
          final walking = _walking;
          // Las micro-expresiones no esperan al corte del golpe: un parpadeo
          // tiene que ser instantáneo.
          final ojos = _microOjos ?? _ojosDePose(widget.pose);
          final hidden = instructorHidden(
            ojos: instructorEyeAsset(ojos),
            boca: _bocaActiva(),
            mano: instructorHandFor(widget.pose),
          );

          final double dx; // desplazamiento horizontal (solo al caminar)
          final double dy;
          final double tilt;
          final double scale;
          final double opacity;
          if (walking) {
            // Entra desde fuera del borde izquierdo y desacelera hasta su sitio.
            final ease = Curves.easeOutCubic.transform(_walk.value);
            dx = -h * 1.25 * (1 - ease);
            dy = 0;
            tilt = 0;
            scale = 1.0;
            opacity = 1.0;
          } else {
            final phase = _idle.value * 2 * math.pi;
            if (_celebrating) {
              // Dos saltitos por ciclo + sacudida rápida de festejo.
              dy = -math.sin(phase * 2).abs() * h * 0.055;
              tilt = math.sin(phase * 4) * 0.05;
            } else {
              // Al hablar, UN asentimiento suave por ciclo SOBRE el flote:
              // parece que ella dice las palabras. `(1-cos)/2` es una caída y
              // regreso limpios (nada de tembleque); un leve vaivén lateral lo
              // acompaña. Empieza y termina con la voz (ver [_syncSpeak]), así
              // el gesto va sincronizado con ella.
              final s = _speak.value * 2 * math.pi;
              final nod = (1 - math.cos(s)) / 2; // 0→1→0, un cabeceo por ciclo
              final bobY = _speakBob ? -nod * h * 0.02 : 0.0;
              final bobTilt = _speakBob ? math.sin(s) * 0.014 : 0.0;
              // Flote respirado + balanceo apenas perceptible, desfasados para
              // que el movimiento no se sienta mecánico.
              dy = math.sin(phase) * h * 0.018 + bobY;
              tilt = math.sin(phase + 0.8) * 0.022 + bobTilt;
            }
            dx = 0;
            // Entrada elástica: crece desde los pies mientras aparece.
            scale = 0.4 + 0.6 * Curves.elasticOut.transform(_pop.value);
            opacity = (_pop.value * 3).clamp(0.0, 1.0);
          }

          // Qué tan "en el aire" está (0 = apoyada, 1 = punto más alto del
          // salto). La sombra de contacto se encoge y aclara con la altura:
          // es lo que ancla el flote al piso en vez de verse recortada.
          final lift = (-dy / (h * 0.055)).clamp(-1.0, 1.0);

          // Golpe del cambio de pose (0 = en reposo, 1 = máxima compresión):
          // baja rápido en el primer tercio y vuelve con un rebote corto. Se
          // ancla en los pies, así que comprime "de rodillas" sin despegarla
          // del piso — que es como reacciona una figura de pie.
          final double golpe;
          final sw = _swap.value;
          if (sw == 0 || sw == 1) {
            golpe = 0.0;
          } else if (sw < 0.32) {
            golpe = Curves.easeOut.transform(sw / 0.32);
          } else {
            golpe = 1 - Curves.easeOutBack.transform((sw - 0.32) / 0.68);
          }
          // Volumen constante: lo que pierde de alto lo gana de ancho. La
          // amplitud es la que es porque ahora el golpe carga con TODO el peso
          // de vender el relevo (antes lo acompañaba un fundido): con menos, el
          // corte seco se leía como un salto.
          final squashY = 1 - golpe * 0.080;
          final squashX = 1 + golpe * 0.055;

          // Un solo Image, sin AnimatedSwitcher: TODOS los relevos son cortes
          // secos. El fundido cruzado que había antes superponía los dos
          // dibujos durante ~11 fotogramas y se veía como una doble exposición
          // (ver [_kSwapCut]); quitarlo es lo que arregla la sensación de
          // "fantasma". Lo que vende el cambio es el golpe de compresión, que
          // ocurre justo encima del corte.
          // El rig sustituye a la lámina de cuerpo entero. Las
          // transformaciones de AFUERA (flote, cabeceo, golpe, sombra) siguen
          // siendo de figura completa y no cambian; lo que el rig añade es el
          // movimiento INTERNO que un PNG no podía dar: respiración del torso,
          // cabeceo propio y la antena llegando tarde.
          final rig = _rig;
          // Al entrar camina DE PERFIL: es otro rig, con sus propias piezas y
          // la mitad de ancho. Si el manifest no lo trae, la entrada cae al rig
          // de frente deslizándose, que es lo que hacía antes de articularla.
          final perfil = walking ? rig?.profile : null;
          final Widget figura;
          if (perfil != null) {
            figura = InstructorRigView(
              rig: perfil,
              images: _images ?? InstructorImages.empty,
              pose: solveInstructorPose(perfil, [
                ClipLayer(
                  clip: InstructorClips.walkCycle,
                  t: _faseCaminata,
                ),
              ]),
              height: h,
            );
          } else if (rig == null) {
            figura = SizedBox(height: h, width: h * kInstructorAspectFallback);
          } else {
            figura = InstructorRigView(
              rig: rig,
              images: _images ?? InstructorImages.empty,
              pose: solveInstructorPose(rig, _capas()),
              height: h,
              hidden: hidden,
            );
          }

          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  // Sombra elíptica bajo los pies — NO se traslada con dy.
                  // Se ensancha con el golpe: más peso apoyado en el suelo.
                  Transform.scale(
                    scaleX: (1.0 - 0.20 * lift) * scale * squashX,
                    scaleY: scale,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: h * 0.40,
                      height: h * 0.045,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(h * 0.20, h * 0.0225),
                        ),
                        gradient: RadialGradient(
                          colors: [
                            const Color(
                              0xFF000000,
                            ).withValues(alpha: 0.20 - 0.08 * lift),
                            const Color(0x00000000),
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.rotate(
                      angle: tilt,
                      alignment: Alignment.bottomCenter,
                      child: Transform.scale(
                        scaleX: scale * squashX,
                        scaleY: scale * squashY,
                        alignment: Alignment.bottomCenter,
                        child: figura,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
