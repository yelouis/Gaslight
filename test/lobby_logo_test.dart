import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/widgets/lobby_logo.dart';
import 'package:gaslight/widgets/raven_mascot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AnimatedLobbyLogo renders RavenMascot and no gaslight_mascot asset', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedLobbyLogo(),
        ),
      ),
    );

    expect(find.byType(AnimatedLobbyLogo), findsOneWidget);

    // 1. Assert RavenMascot is rendered inside AnimatedLobbyLogo
    expect(find.byType(RavenMascot), findsOneWidget);

    // 2. Falsifying assertion: Assert no Image asset in the logo subtree contains gaslight_mascot
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    for (final image in images) {
      if (image.image is AssetImage) {
        final assetName = (image.image as AssetImage).assetName;
        expect(assetName.contains('gaslight_mascot'), isFalse,
            reason: 'Logo must not render gaslight_mascot.png (found $assetName)');
      }
    }

    expect(tester.takeException(), isNull);
  });
}
