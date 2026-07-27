import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cossmil/core/services/tutorial_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'el tutorial de ficha arranca como no visto y persiste al marcarse',
    () async {
      SharedPreferences.setMockInitialValues({});

      expect(await TutorialService.hasSeenFichaTutorial(), isFalse);

      await TutorialService.markFichaTutorialSeen();
      expect(await TutorialService.hasSeenFichaTutorial(), isTrue);
    },
  );

  test(
    'el flag es versionado: una clave vieja sin sufijo no cuenta como visto',
    () async {
      SharedPreferences.setMockInitialValues({'tutorial_ficha_seen': true});

      expect(await TutorialService.hasSeenFichaTutorial(), isFalse);
    },
  );
}
