import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/theme/app_icons.dart';

void main() {
  testWidgets('WaxSealBadge renders at sizes 12, 34, 80 without exceptions', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              children: [
                WaxSealBadge(size: 12),
                WaxSealBadge(size: 34),
                WaxSealBadge(size: 80),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(WaxSealBadge), findsNWidgets(3));
  });
}
