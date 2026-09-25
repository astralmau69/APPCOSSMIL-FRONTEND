import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
// Native playback is the boundary replaced by this deterministic test double.
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/services/tutorial_voice.dart';
import 'package:cossmil/core/widgets/tutorial_coach_overlay.dart';

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
  final playback = _Playback();
  AudioplayersPlatformInterface.instance = playback;
  AudioCache.instance = _AssetCache();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'), (_) async => null);

  Widget scene({bool first = false, bool second = false}) => CupertinoApp(
    home: Stack(children: [
      if (first) TutorialCoachOverlay(key: const ValueKey('first'),
        messages: const ['Inicio'], isDark: false, onExit: () {}, voiceId: 'ficha_00'),
      if (second) TutorialCoachOverlay(key: const ValueKey('second'),
        messages: const ['Regional'], isDark: false, onExit: () {}, voiceId: 'ficha_01'),
    ]),
  );

  tearDown(() {
    playback.preparation = null;
  });

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
    await t.pumpWidget(const SizedBox());
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
    await t.pump();
    expect(playback.voice, endsWith('guiado_intro.mp3'));
    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Seleccione regional'), findsNothing);
    playback.completeVoice();
    await t.pump();
    await t.pump();
    expect(playback.voice, endsWith('guiado_regional.mp3'));
    expect(find.text('Seleccione regional'), findsOneWidget);
    await t.pumpWidget(guided());
    expect(playback.voice, endsWith('guiado_regional.mp3'));
    await t.pumpWidget(const SizedBox());
    await t.pump();
  });

  testWidgets('avanzar durante intro narra el paso nuevo sin volver a regional', (t) async {
    await t.pumpWidget(guided());
    await t.pump();
    await t.pumpWidget(guided(voice: 'guiado_especialidad'));
    await t.pump();
    expect(playback.voice, endsWith('guiado_especialidad.mp3'));
    playback.completeVoice();
    await t.pump();
    expect(playback.voice, endsWith('guiado_especialidad.mp3'));
    await t.pumpWidget(const SizedBox());
    await t.pump();
  });
}
