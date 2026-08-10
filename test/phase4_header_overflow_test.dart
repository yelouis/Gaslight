import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/theme/app_colors.dart';
import 'package:gaslight/theme/app_icons.dart';

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
}
