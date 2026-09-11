import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/theme/app_colors.dart';
import 'package:gaslight/theme/app_icons.dart';
import 'package:gaslight/widgets/in_game_app_bar.dart';
import 'package:gaslight/widgets/gaslight_route.dart';

void main() {
  testWidgets('unmasking header does not overflow at 360dp width and 1.3 text scale', (WidgetTester tester) async {
    // Recreate header row widget structure from phase4_reveal.dart
    Widget buildHeader({required bool isFooled, required bool isLowTime, required bool isTimerActive}) {
      return MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(1.3),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          ThematicIcon(
                            type: isFooled ? ThematicIconType.confirm : ThematicIconType.hourglass,
                            color: isLowTime ? Colors.redAccent : AppColors.brass,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isFooled ? 'REVENGE UNMASKING!' : 'UNMASKING IN PROGRESS...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'CormorantGaramond',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isLowTime ? Colors.redAccent : AppColors.brass,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isTimerActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.ground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('15s'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Branch 1: REVENGE UNMASKING!
    await tester.pumpWidget(buildHeader(isFooled: true, isLowTime: false, isTimerActive: true));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('REVENGE'), findsOneWidget);

    // Branch 2: UNMASKING IN PROGRESS...
    await tester.pumpWidget(buildHeader(isFooled: false, isLowTime: false, isTimerActive: true));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('UNMASKING'), findsOneWidget);
  });

  testWidgets('Reveal screen AppBar with two trailing actions does not overflow at 320pt width and 2.0 text scale', (WidgetTester tester) async {
    final List<TextSpan> appBarLines = [
      const TextSpan(
        text: 'THE REVEAL',
        style: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 9.0,
        ),
      ),
      const TextSpan(
        text: 'ROOM: TEST',
        style: TextStyle(
          fontFamily: 'Lora',
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    ];

    Widget buildScreen() {
      return MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2.0),
          ),
          child: Builder(
            builder: (context) {
              final double computedHeight = inGameAppBarHeight(context, lines: appBarLines, trailingSlots: 2);
              return Scaffold(
                appBar: AppBar(
                  toolbarHeight: computedHeight,
                  leading: IconButton(
                    icon: const ThematicIcon(type: ThematicIconType.depart),
                    onPressed: () {},
                  ),
                  title: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TitleSettle(text: 'THE REVEAL'),
                      SizedBox(height: 2),
                      Text('ROOM: TEST'),
                    ],
                  ),
                  centerTitle: true,
                  actions: [
                    IconButton(
                      icon: const ThematicIcon(type: ThematicIconType.ledger),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const ThematicIcon(type: ThematicIconType.sound),
                      onPressed: () {},
                    ),
                  ],
                ),
                body: const SizedBox.expand(),
              );
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(buildScreen());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    final appBarFinder = find.byType(AppBar);
    expect(appBarFinder, findsOneWidget);
    final appBarBox = tester.renderObject<RenderBox>(appBarFinder);
    final appBarBottom = appBarBox.localToGlobal(Offset.zero).dy + appBarBox.size.height;

    final roomCodeFinder = find.text('ROOM: TEST');
    expect(roomCodeFinder, findsOneWidget);
    final roomCodeBox = tester.renderObject<RenderBox>(roomCodeFinder);
    final roomCodeBottom = roomCodeBox.localToGlobal(Offset.zero).dy + roomCodeBox.size.height;

    expect(
      roomCodeBottom,
      lessThanOrEqualTo(appBarBottom),
      reason: 'Room code text bottom ($roomCodeBottom) must be inside AppBar bottom ($appBarBottom)',
    );
  });
}
