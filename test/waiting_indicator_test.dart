import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/widgets/waiting_indicator.dart';
import 'package:gaslight/models/player_state.dart';

void main() {
  testWidgets('CandleFlameIndicator and WaitingOnRow render and animate correctly', (WidgetTester tester) async {
    final List<PlayerState> players = [
      PlayerState(id: 'p1', name: 'Alice', isHost: true, role: PlayerRole.voter, colorValue: 0xFF00FF00, avatarIndex: 1),
      PlayerState(id: 'p2', name: 'Bob', isHost: false, role: PlayerRole.voter, colorValue: 0xFFFF0000, avatarIndex: 2),
    ];
    final readyMap = {'p1': true, 'p2': false};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const CandleFlameIndicator(),
              WaitingOnRow(players: players, readyMap: readyMap),
            ],
          ),
        ),
      ),
    );

    // Verify indicators render
    expect(find.byType(CandleFlameIndicator), findsOneWidget);
    expect(find.byType(WaitingOnRow), findsOneWidget);

    // Verify ready player Alice has name
    expect(find.text('Alice'), findsOneWidget);
    // Verify unready player Bob has name
    expect(find.text('Bob'), findsOneWidget);

    // Alice is ready (no pulse), Bob is unready (pulsing).
    // Plus PlayerAvatar has 1 internal ScaleTransition, so total 2.
    expect(find.byType(ScaleTransition), findsNWidgets(2));
  });

  testWidgets('WaitingOnRow reduces motion when accessibility feature is active', (WidgetTester tester) async {
    final List<PlayerState> players = [
      PlayerState(id: 'p2', name: 'Bob', isHost: false, role: PlayerRole.voter, colorValue: 0xFFFF0000, avatarIndex: 2),
    ];
    final readyMap = {'p2': false};

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: child!,
          );
        },
        home: Scaffold(
          body: WaitingOnRow(players: players, readyMap: readyMap),
        ),
      ),
    );

    // With reduce motion enabled, the pulse ScaleTransition is omitted,
    // leaving only PlayerAvatar's internal entry ScaleTransition (total 1).
    expect(find.byType(ScaleTransition), findsOneWidget);
  });
}
