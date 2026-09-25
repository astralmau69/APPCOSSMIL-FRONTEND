import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/widgets/tutorial_instructor.dart';

/// Lo que ata el rig al BUNDLE y a la app: que el manifest viaje en el
/// paquete, que cada pieza que nombra exista, que el set viejo ya no viaje, y
/// que nadie tenga la proporción de la figura escrita a mano.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, dynamic>> manifest() async => jsonDecode(
    await rootBundle.loadString('assets/images/instructor/manifest.json'),
  );

  test('el manifest está empaquetado y es coherente', () async {
    final m = await manifest();
    expect(m['canonicalHeight'], 800);
    final piezas = (m['pieces'] as List).cast<Map<String, dynamic>>();
    final nombres = piezas.map((p) => p['name'] as String).toSet();
    for (final n in [
      'torso',
      'cabeza',
      'antena',
      'brazo_sup_der',
      'antebrazo_der',
      'muslo_izq',
      'pantorrilla_der',
    ]) {
      expect(nombres, contains(n));
    }
    expect(m.containsKey('profile'), isTrue);
  });

  test('cada asset del manifest existe en el bundle', () async {
    final m = await manifest();
    final todas = [
      ...(m['pieces'] as List).cast<Map<String, dynamic>>(),
      ...(((m['profile'] as Map<String, dynamic>?)?['pieces'] ?? []) as List)
          .cast<Map<String, dynamic>>(),
    ];
    expect(todas, hasLength(greaterThan(30)));
    for (final p in todas) {
      final path = 'assets/images/instructor/${p['asset']}';
      // Se AWAITEA de verdad: `expect(() async => …, returnsNormally)` pasa
      // siempre, porque una closure async nunca lanza en el acto.
      final bytes = await rootBundle.load(path);
      expect(bytes.lengthInBytes, greaterThan(0), reason: 'vacío: $path');
    }
  });

  test('el set de poses viejo ya no está en el repo', () {
    // Se mira el REPO, no el bundle: `build/unit_test_assets` copia pero no
    // poda, así que un asset borrado sigue apareciendo ahi hasta el siguiente
    // clean — y el test diría lo contrario de la verdad en los dos sentidos.
    final sueltas = Directory('assets/images')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.startsWith('instructora_'))
        .toList();
    expect(sueltas, isEmpty, reason: 'quedan láminas del set retirado');
  });

  test('ningún código referencia el set viejo', () {
    final refs = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.readAsStringSync().contains('instructora_')) refs.add(f.path);
    }
    expect(refs, isEmpty, reason: 'referencias al set retirado');
  });

  testWidgets('la proporción de la figura sale del manifest', (tester) async {
    // Nadie vuelve a escribir 0.58 a mano: el ancho que reserva el coach sale
    // del mismo sitio que el ancho con que se dibuja la figura.
    expect(
      TutorialInstructor.aspecto,
      kInstructorAspectFallback,
      reason: 'sin manifest cargado tiene que caer al valor de respaldo',
    );
    // Leer el manifest desde la zona real: dentro de la fake-async el Future
    // que cachea `rootBundle` (creado por los tests de arriba) no completa.
    final esperado = await tester.runAsync(
      () async => (await manifest())['aspect'] as num,
    );
    await tester.pumpWidget(
      const CupertinoApp(home: Center(child: TutorialInstructor(height: 120))),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 16));
    expect(TutorialInstructor.aspecto, esperado);
  });
}
