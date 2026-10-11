import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/main.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'helpers/rendered_contrast.dart';
import 'simulation_test.dart';

/// Issue 179 / AI3: every House Rules chip number must be readable AS RENDERED.
///
/// The unselected chips painted ivory labels on a parchment fill (1.02 : 1) and
/// no test noticed, because `house_rules_panel_test.dart` reads `selected` flags
/// and `contrast_tokens_test.dart` never visits the lobby. This test pumps the
/// real `GaslightApp` (so the production theme, not a default one, decides the
/// chip fill) and measures pixels with `measureRenderedContrast`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('House Rules chip labels are legible as rendered (Issue 179 / AI3)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    /// Host parlour with 3 players, in the real app, at 375 x 667.
    Future<GlobalKey> pumpHostParlour(WidgetTester tester, {required double textScale}) async {
      const roomCode = 'TEST';
      const hostId = 'player_1';

      final host = PlayerState(id: hostId, name: 'HostUser', isHost: true, joinedAt: 100);
      final guest1 = PlayerState(id: 'guest_1', name: 'Guest One', isHost: false, joinedAt: 200);
      final guest2 = PlayerState(id: 'guest_2', name: 'Guest Two', isHost: false, joinedAt: 300);
      final gameState = GameState(roomCode: roomCode, totalPlayers: 3, forgeriesPerCard: 2);

      await mockDb.collection('rooms').doc(roomCode).set(gameState.toMap());
      for (final p in [host, guest1, guest2]) {
        await mockDb.collection('rooms').doc(roomCode).collection('players').doc(p.id).set(p.toMap());
      }
      gameService.listenToRoom(roomCode);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', roomCode);
      await prefs.setString('player_id', hostId);
      await gameService.tryRejoinSession();
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));

      // Logical pixels == image pixels, so the helper's rect maps straight on.
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // accessibleNavigation puts every animation on its static path (lesson 2.7).
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final rootBoundary = GlobalKey(debugLabel: 'rootBoundary');
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: RepaintBoundary(key: rootBoundary, child: const GaslightApp()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      return rootBoundary;
    }

    /// Top edge of the parchment sheet that overlays the lower part of the page.
    double sheetTop(WidgetTester tester) => tester
        .getRect(find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(Container)).first)
        .top;

    Future<void> expectEveryChipLegible(WidgetTester tester, {required double textScale}) async {
      final rootBoundary = await pumpHostParlour(tester, textScale: textScale);

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      final keys = chips.map((c) => (c.key as ValueKey<String>).value).toList();

      // Non-vacuity: 3 players -> forgeries_1..2, plus rounds_1..5. If the panel
      // grows or loses a chip this must be updated on purpose, not skipped.
      expect(keys.where((k) => k.startsWith('forgeries_')).length, 2, reason: 'forgeries chips for 3 players: $keys');
      expect(keys.where((k) => k.startsWith('rounds_')).length, 5, reason: 'rounds chips: $keys');
      expect(keys.length, 7, reason: 'unexpected chip in the House Rules panel: $keys');

      final failures = <String>[];
      var selectedMeasured = 0;
      var unselectedMeasured = 0;

      for (final key in keys) {
        final chip = find.byKey(ValueKey<String>(key));
        // Scroll THIS chip to the top of the page, well above the draggable sheet
        // (which stays at its normal size: collapsing it at text scale 1.3
        // overflows its own header, a separate matter).
        await tester.ensureVisible(chip);
        await tester.pump();
        // A chip hidden under the draggable sheet would make the pixels below
        // describe the sheet, not the chip.
        expect(chip.hitTestable(), findsOneWidget, reason: '$key is covered by something (the sheet?)');
        // The sheet's shadow (black@0.5, blur 15, spread 2, offset -4) reaches
        // ~21 px above its top; a chip inside it would be measured darkened.
        expect(tester.getRect(chip).bottom + 24, lessThanOrEqualTo(sheetTop(tester)),
            reason: '$key sits in the sheet\'s shadow (sheet top ${sheetTop(tester)}), so its pixels are not the chip\'s own');

        // Measure the LABEL, not the chip: a rect around the whole chip also
        // covers the dark card behind it, which would then be picked as the
        // "foreground" and pass an invisible label.
        final label = find.descendant(of: chip, matching: find.byType(Text));
        expect(label, findsOneWidget, reason: '$key must have exactly one label Text');

        final sample = await measureRenderedContrast(tester, rootBoundary, label);
        final isSelected = tester.widget<ChoiceChip>(chip).selected;
        isSelected ? selectedMeasured++ : unselectedMeasured++;

        if (sample.ratio < 4.5) {
          failures.add('$key (${isSelected ? 'selected' : 'unselected'}, text scale $textScale): '
              '${sample.ratio.toStringAsFixed(2)} : 1 — label ${sample.foreground} on fill ${sample.background}');
        }
      }

      expect(selectedMeasured, greaterThanOrEqualTo(1),
          reason: 'no selected chip was measured, so the test says nothing about the selected state');
      expect(unselectedMeasured, greaterThanOrEqualTo(1),
          reason: 'no unselected chip was measured, so the test says nothing about Issue 179');
      expect(failures, isEmpty, reason: 'chip labels below 4.5 : 1:\n${failures.join('\n')}');
    }

    testWidgets('every chip label is >= 4.5 : 1 at text scale 1.0', (tester) async {
      try {
        await expectEveryChipLegible(tester, textScale: 1.0);
      } finally {
        gameService.dispose(); // stops the heartbeat timer before invariants are checked
      }
    });

    testWidgets('every chip label is >= 4.5 : 1 at text scale 1.3', (tester) async {
      try {
        await expectEveryChipLegible(tester, textScale: 1.3);
      } finally {
        gameService.dispose();
      }
    });
  });
}
