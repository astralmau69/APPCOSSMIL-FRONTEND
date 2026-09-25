import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
// Native playback is the boundary replaced by this deterministic test double.
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/services/tutorial_voice.dart';
import 'package:cossmil/core/theme/sound_manager.dart';
import 'package:cossmil/core/widgets/tutorial_coach_overlay.dart';

/// El ámbito GLOBAL de audioplayers (init del motor), aparte del reproductor.
class _Global extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> init() async {}
  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() =>
      const Stream<GlobalAudioEvent>.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _AssetCache extends AudioCache {
  @override
  Future<String> loadPath(String fileName) async => fileName;
}

class _Playback extends AudioplayersPlatformInterface {
  final events = <String, StreamController<AudioEvent>>{};
  final sources = <String, String>{};
  final playing = <String, bool>{};
  Completer<void>? preparation;

  String? get voice => sources.values
      .where((source) => source.contains('vof_tutorial/'))
      .firstOrNull;
  String get voicePlayer => sources.entries
      .firstWhere((entry) => entry.value.contains('vof_tutorial/'))
      .key;
  void completeVoice() => events[voicePlayer]!.add(
    const AudioEvent(eventType: AudioEventType.complete),
  );
  @override
  Future<void> create(String playerId) async {
    events[playerId] = StreamController<AudioEvent>.broadcast();
  }
  @override
  Stream<AudioEvent> getEventStream(String playerId) => events[playerId]!.stream;
  @override
  Future<void> setSourceUrl(String playerId, String url,
      {bool? isLocal, String? mimeType}) async {
    sources[playerId] = url;
    if (url.contains('vof_tutorial/')) await preparation?.future;
    events[playerId]!.add(const AudioEvent(
        eventType: AudioEventType.prepared, isPrepared: true));
  }
  @override
  Future<void> stop(String playerId) async => playing[playerId] = false;
  @override
  Future<void> resume(String playerId) async => playing[playerId] = true;
  @override
  Future<int?> getDuration(String playerId) async => 4000;
  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Sin blips de interfaz. El coach toca uno al montarse y otro al avanzar de
  // paso, y SoundManager los manda a su propio pool de AudioPlayer, que contra
  // los dobles de abajo llegan a sonar de verdad. Cada uno deja entonces vivo
  // su frame callback de posición y, al terminar el test, el binding los
  // encuentra sueltos y falla con "An animation is still running even after
  // the widget tree was disposed" — por un sonido que este test ni mira.
  SoundManager.soundEnabledNotifier.value = false;
  AudioCache.instance = _AssetCache();

  Widget scene({bool first = false, bool second = false}) => CupertinoApp(
    home: Stack(children: [
      if (first) TutorialCoachOverlay(key: const ValueKey('first'),
        messages: const ['Inicio'], isDark: false, onExit: () {}, voiceId: 'ficha_00'),
      if (second) TutorialCoachOverlay(key: const ValueKey('second'),
        messages: const ['Regional'], isDark: false, onExit: () {}, voiceId: 'ficha_01'),
    ]),
  );

  late _Playback playback;

  setUp(() {
    // Plataformas y reproductor NUEVOS en cada test.
    //
    // audioplayers guarda dos `Completer`: el del init global
    // (`AudioPlayer.global`) y el de creación de cada reproductor. Un
    // `Completer` entrega su resultado en la zona async donde se creó, y cada
    // `testWidgets` trae la suya, así que heredar cualquiera de los dos deja a
    // `play()` esperando para siempre en una zona ya muerta — el archivo
    // entero fallaba por esto aunque cada test pasara suelto.
    //
    // El ámbito global solo se re-inicializa si CAMBIA la instancia de su
    // plataforma, de ahí que se renueve aquí en vez de mockear su canal.
    playback = _Playback();
    AudioplayersPlatformInterface.instance = playback;
    GlobalAudioplayersPlatformInterface.instance = _Global();
    TutorialVoice.debugResetPlayer();
  });

  tearDown(() {
    playback.preparation = null;
  });

  /// Desmonta el árbol y deja la locución REALMENTE detenida: el `stopIfToken`
  /// del dispose es fire-and-forget y sin un pump más el `stop()` queda a
  /// medias, con su frame callback de posición todavía vivo.
  Future<void> cerrar(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump();
  }

  /// Espera a que EMPIECE a sonar [id], como mucho unos fotogramas. Esperar al
  /// clip, en vez de contar `pump()`s a ojo, hace la prueba independiente de
  /// con qué fuente venía el reproductor de un test anterior.
  Future<void> suena(WidgetTester t, String id) async {
    for (var i = 0; i < 20 && playback.voice?.endsWith('$id.mp3') != true; i++) {
      await t.pump();
    }
    expect(playback.voice, endsWith('$id.mp3'));
  }

  testWidgets('dispose saliente conserva el clip del coach entrante', (t) async {
    await t.pumpWidget(scene(first: true));
    await t.pump();
    await t.pumpWidget(scene(first: true, second: true));
    await t.pump();
    final incomingToken = TutorialVoice.currentToken;
    expect(playback.voice, endsWith('ficha_01.mp3'));
    await t.pumpWidget(scene(second: true));
    await t.pump();
    expect(TutorialVoice.currentToken, incomingToken);
    expect(playback.playing[playback.voicePlayer], isTrue);
    await cerrar(t);
  });

  testWidgets('dispose cancela su clip aunque siga preparándose', (t) async {
    playback.preparation = Completer<void>();
    await t.pumpWidget(scene(first: true));
    await t.pump();
    final pendingToken = TutorialVoice.currentToken;
    await t.pumpWidget(const SizedBox());
    expect(TutorialVoice.currentToken, greaterThan(pendingToken));
    playback.preparation!.complete();
    await t.pump();
    expect(playback.playing[playback.voicePlayer], isFalse);
    await cerrar(t);
  });

  Widget guided({String voice = 'guiado_regional'}) => CupertinoApp(
    home: Stack(children: [TutorialCoachOverlay(
      key: const ValueKey('guided'), messages: const ['Seleccione regional'],
      initialVoiceId: 'guiado_intro', initialMessages: const ['Bienvenido'],
      voiceId: voice, narrateOnly: true, isDark: false, onExit: () {},
    )]),
  );

  testWidgets('intro termina antes de narrar regional y cambiar burbujas', (t) async {
    await t.pumpWidget(guided());
    await suena(t, 'guiado_intro');
    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Seleccione regional'), findsNothing);
    playback.completeVoice();
    await suena(t, 'guiado_regional');
    expect(find.text('Seleccione regional'), findsOneWidget);
    // Reconstruir con el MISMO voiceId no relanza el clip.
    await t.pumpWidget(guided());
    expect(playback.voice, endsWith('guiado_regional.mp3'));
    await cerrar(t);
  });

  testWidgets('avanzar durante intro narra el paso nuevo sin volver a regional', (t) async {
    await t.pumpWidget(guided());
    await suena(t, 'guiado_intro');
    await t.pumpWidget(guided(voice: 'guiado_especialidad'));
    await suena(t, 'guiado_especialidad');
    // El `complete` que llega es el de la intro interrumpida: no debe
    // arrastrar al coach de vuelta a regional.
    playback.completeVoice();
    await t.pump();
    expect(playback.voice, endsWith('guiado_especialidad.mp3'));
    await cerrar(t);
  });
}
