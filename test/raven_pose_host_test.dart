import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/widgets/raven_mascot.dart';
import 'package:gaslight/widgets/raven_pose_host.dart';

class _TestPoseWidget extends StatefulWidget {
  final bool reduceMotion;
  const _TestPoseWidget({this.reduceMotion = false});

  @override
  State<_TestPoseWidget> createState() => _TestPoseWidgetState();
}

class _TestPoseWidgetState extends State<_TestPoseWidget> with RavenPoseHost<_TestPoseWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          RavenMascot(state: ravenPose, size: 64),
          ElevatedButton(
            onPressed: () => playRavenPose(RavenState.peck, onceKey: 'test_key_1'),
            child: const Text('Fire Key 1'),
          ),
          ElevatedButton(
            onPressed: () => playRavenPose(RavenState.startle, onceKey: 'test_key_2'),
            child: const Text('Fire Key 2'),
          ),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task T5 — RavenPoseHost Mixin Contract Tests', () {
    testWidgets('onceKey deduplication: repeated onceKey fires pose only once', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestPoseWidget()));

      final state = tester.state<_TestPoseWidgetState>(find.byType(_TestPoseWidget));
      expect(state.ravenPose, equals(RavenState.idle));

      // 1. Fire Key 1
      await tester.tap(find.text('Fire Key 1'));
      await tester.pump(); // Post frame callback
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.ravenPose, equals(RavenState.peck), reason: 'First invocation with onceKey must play pose');

      // Revert after hold duration
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.ravenPose, equals(RavenState.idle));

      // 2. Fire Key 1 again -> must be ignored
      await tester.tap(find.text('Fire Key 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.ravenPose, equals(RavenState.idle), reason: 'Repeated onceKey must not re-fire pose');
    });

    testWidgets('distinct onceKey fires a new pose', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestPoseWidget()));

      final state = tester.state<_TestPoseWidgetState>(find.byType(_TestPoseWidget));

      // Fire Key 1
      await tester.tap(find.text('Fire Key 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.ravenPose, equals(RavenState.peck));

      await tester.pump(const Duration(milliseconds: 300));
      expect(state.ravenPose, equals(RavenState.idle));

      // Fire Key 2 (distinct key)
      await tester.tap(find.text('Fire Key 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.ravenPose, equals(RavenState.startle), reason: 'Distinct onceKey must fire new pose');
    });

    testWidgets('reduced motion consumes onceKey but plays no animation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(accessibleNavigation: true),
          child: const MaterialApp(home: _TestPoseWidget(reduceMotion: true)),
        ),
      );

      final state = tester.state<_TestPoseWidgetState>(find.byType(_TestPoseWidget));

      await tester.tap(find.text('Fire Key 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.ravenPose, equals(RavenState.idle), reason: 'Under reduced motion pose must remain idle');

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposal mid-pose cancels timer without throwing', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestPoseWidget()));

      await tester.tap(find.text('Fire Key 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Unmount widget mid-pose
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      expect(tester.takeException(), isNull);
    });
  });
}
