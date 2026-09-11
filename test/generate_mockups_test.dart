import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/theme/app_colors.dart';
import 'package:gaslight/theme/app_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final cormorant = File('assets/fonts/cormorant_garamond/CormorantGaramond-Bold.ttf');
    if (cormorant.existsSync()) {
      final loader = FontLoader('CormorantGaramond');
      loader.addFont(cormorant.readAsBytes().then((b) => ByteData.sublistView(Uint8List.fromList(b))));
      await loader.load();
    }
    final lora = File('assets/fonts/lora/Lora-Regular.ttf');
    if (lora.existsSync()) {
      final loader = FontLoader('Lora');
      loader.addFont(lora.readAsBytes().then((b) => ByteData.sublistView(Uint8List.fromList(b))));
      await loader.load();
    }
  });

  const answers = [
    'I once told my entire team the deadline had moved and then quietly moved it back before anyone check', // exactly 100 chars
    'I accidentally pocketed Lord Harrington\'s silver teaspoon at the winter gala.',
    'I pretended to read French fluently for three years at the embassy.',
    'I hid a stray kitten inside my velvet waistcoat during Sunday sermon.',
    'I forged my uncle\'s wax seal to purchase a secret carriage.',
    'I claimed a severe oyster allergy to avoid the duchess\'s cold soup.',
  ];

  Future<void> captureWidget({
    required WidgetTester tester,
    required Widget widget,
    required double width,
    required double height,
    required String filePath,
  }) async {
    final key = GlobalKey();

    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.ground,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.oxblood,
            secondary: AppColors.brass,
            surface: AppColors.groundRaised,
          ),
          fontFamily: 'Lora',
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            devicePixelRatio: 1.0,
            textScaler: const TextScaler.linear(1.0),
          ),
          child: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: width,
                height: height,
                child: widget,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
    final byteData = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    final bytes = byteData!.buffer.asUint8List();

    final file = File(filePath);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  }

  testWidgets('Generate Treatment 1: Single Card Full Width with Dot Indicators (320 & 430)', (tester) async {
    for (final width in [320.0, 430.0]) {
      final height = width == 320.0 ? 640.0 : 932.0;
      final path = 'docs/mockups/vote_options/treatment_1_single_card_dots_${width.toInt()}.png';

      await captureWidget(
        tester: tester,
        width: width,
        height: height,
        filePath: path,
        widget: MockupScreenFrame(
          width: width,
          treatmentTitle: 'TREATMENT 1: SINGLE CARD + DOT INDICATORS',
          treatmentDescription: 'One option per page with dots and swipe affordance',
          child: Treatment1SingleCardDots(answers: answers, width: width),
        ),
      );

      expect(File(path).existsSync(), isTrue);
      expect(File(path).lengthSync(), greaterThan(1000));
    }
  });

  testWidgets('Generate Treatment 2: Two-Up Carousel (320 & 430)', (tester) async {
    for (final width in [320.0, 430.0]) {
      final height = width == 320.0 ? 640.0 : 932.0;
      final path = 'docs/mockups/vote_options/treatment_2_two_up_carousel_${width.toInt()}.png';

      await captureWidget(
        tester: tester,
        width: width,
        height: height,
        filePath: path,
        widget: MockupScreenFrame(
          width: width,
          treatmentTitle: 'TREATMENT 2: TWO-UP CAROUSEL',
          treatmentDescription: 'Two options visible side-by-side / pair pager',
          child: Treatment2TwoUpCarousel(answers: answers, width: width),
        ),
      );

      expect(File(path).existsSync(), isTrue);
      expect(File(path).lengthSync(), greaterThan(1000));
    }
  });

  testWidgets('Generate Treatment 3: Stacked Deck with Peek (320 & 430)', (tester) async {
    for (final width in [320.0, 430.0]) {
      final height = width == 320.0 ? 640.0 : 932.0;
      final path = 'docs/mockups/vote_options/treatment_3_stacked_deck_peek_${width.toInt()}.png';

      await captureWidget(
        tester: tester,
        width: width,
        height: height,
        filePath: path,
        widget: MockupScreenFrame(
          width: width,
          treatmentTitle: 'TREATMENT 3: STACKED DECK WITH PEEK',
          treatmentDescription: 'Victorian parlour card stack with visible trailing edges',
          child: Treatment3StackedDeckPeek(answers: answers, width: width),
        ),
      );

      expect(File(path).existsSync(), isTrue);
      expect(File(path).lengthSync(), greaterThan(1000));
    }
  });

  testWidgets('Generate Treatment 4: Segmented Pager (320 & 430)', (tester) async {
    for (final width in [320.0, 430.0]) {
      final height = width == 320.0 ? 640.0 : 932.0;
      final path = 'docs/mockups/vote_options/treatment_4_segmented_pager_${width.toInt()}.png';

      await captureWidget(
        tester: tester,
        width: width,
        height: height,
        filePath: path,
        widget: MockupScreenFrame(
          width: width,
          treatmentTitle: 'TREATMENT 4: SEGMENTED PAGER',
          treatmentDescription: 'Direct tab bar (I - VI) with instant comparison access',
          child: Treatment4SegmentedPager(answers: answers, width: width),
        ),
      );

      expect(File(path).existsSync(), isTrue);
      expect(File(path).lengthSync(), greaterThan(1000));
    }
  });
}

class MockupScreenFrame extends StatelessWidget {
  final double width;
  final String treatmentTitle;
  final String treatmentDescription;
  final Widget child;

  const MockupScreenFrame({
    super.key,
    required this.width,
    required this.treatmentTitle,
    required this.treatmentDescription,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.ground,
      child: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.brass.withValues(alpha: 0.2), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_ios, size: 16, color: AppColors.brass),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VOTE PHASE · CARD 1 OF 5',
                          style: TextStyle(
                            fontFamily: 'CormorantGaramond',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brass,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Find the truth among the forgeries',
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 10,
                            color: AppColors.ivory.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Timer Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.groundRaised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.brass.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ThematicIcon(type: ThematicIconType.observe, size: 12, color: AppColors.brass),
                        SizedBox(width: 4),
                        Text(
                          '0:42',
                          style: TextStyle(
                            fontFamily: 'CormorantGaramond',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ivory,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const ThematicIcon(type: ThematicIconType.ledger, size: 18, color: AppColors.brass),
                ],
              ),
            ),

            // Prompt Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.groundRaised,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.brass.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.oxblood,
                      ),
                      alignment: Alignment.center,
                      child: const Text('A', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ivory)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ALICE'S CARD",
                            style: TextStyle(
                              fontFamily: 'CormorantGaramond',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brass,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            '"What secret indiscretion did you commit in high society?"',
                            style: TextStyle(
                              fontFamily: 'Lora',
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppColors.ivory.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main Treatment Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Treatment 1: Single Card + Dot Indicators
// ---------------------------------------------------------------------------
class Treatment1SingleCardDots extends StatelessWidget {
  final List<String> answers;
  final double width;

  const Treatment1SingleCardDots({super.key, required this.answers, required this.width});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Navigation header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'OPTION 1 OF 6',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.brass.withValues(alpha: 0.8),
                letterSpacing: 1.5,
              ),
            ),
            const Row(
              children: [
                ThematicIcon(type: ThematicIconType.secret, size: 14, color: AppColors.brass),
                SizedBox(width: 4),
                Text(
                  '100 CHARACTERS',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 10,
                    color: AppColors.brass,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Large Single Card
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.groundRaised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.brass, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card filigree top
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.oxblood,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'EXHIBIT I',
                        style: TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ivory,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'SEALED TESTIMONY',
                      style: TextStyle(
                        fontFamily: 'CormorantGaramond',
                        fontSize: 11,
                        color: AppColors.brass.withValues(alpha: 0.6),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Genuine 100-character answer
                Center(
                  child: Text(
                    '"${answers[0]}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: width < 360 ? 15 : 18,
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                      color: AppColors.parchment,
                    ),
                  ),
                ),
                const Spacer(),
                // Footer
                Center(
                  child: Text(
                    'Tap card or button below to select as Truth',
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 11,
                      color: AppColors.ivory.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Active dot
            Container(
              width: 22,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.brass,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            for (int i = 1; i < 6; i++) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.brass.withValues(alpha: 0.5)),
                  color: Colors.transparent,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // Swipe hint
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chevron_left, size: 16, color: AppColors.brass.withValues(alpha: 0.4)),
            Text(
              'Swipe to view remaining 5 answers',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 12,
                color: AppColors.brass.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: AppColors.brass.withValues(alpha: 0.8)),
          ],
        ),
        const SizedBox(height: 10),

        // Action button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.oxblood,
              foregroundColor: AppColors.ivory,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.brass, width: 1.5),
              ),
            ),
            onPressed: () {},
            icon: const ThematicIcon(type: ThematicIconType.secret, size: 16, color: AppColors.ivory),
            label: const Text(
              'VOTE FOR THIS ANSWER',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Treatment 2: Two-Up Carousel
// ---------------------------------------------------------------------------
class Treatment2TwoUpCarousel extends StatelessWidget {
  final List<String> answers;
  final double width;

  const Treatment2TwoUpCarousel({super.key, required this.answers, required this.width});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Page banner
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PAGE 1 OF 3',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.brass,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'Answers 1 & 2 of 6',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 10,
                color: AppColors.ivory.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Two cards vertically stacked in the current page
        Expanded(
          child: Column(
            children: [
              // Card 1 (Selected)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.groundRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.brass, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brass.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.brass,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CANDIDATE 1',
                              style: TextStyle(
                                fontFamily: 'CormorantGaramond',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.check_circle, size: 18, color: AppColors.brass),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '"${answers[0]}"',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: width < 360 ? 12 : 14,
                          fontStyle: FontStyle.italic,
                          color: AppColors.parchment,
                          height: 1.35,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Card 2
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.groundRaised.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.brass.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.ground,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.brass.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'CANDIDATE 2',
                              style: TextStyle(
                                fontFamily: 'CormorantGaramond',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ivory,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.radio_button_unchecked, size: 18, color: AppColors.brass.withValues(alpha: 0.5)),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '"${answers[1]}"',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: width < 360 ? 12 : 14,
                          fontStyle: FontStyle.italic,
                          color: AppColors.ivory.withValues(alpha: 0.85),
                          height: 1.35,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Pager navigation row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.brass),
              onPressed: null, // first page
            ),
            Row(
              children: [
                Container(width: 16, height: 6, decoration: BoxDecoration(color: AppColors.brass, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.brass.withValues(alpha: 0.3), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.brass.withValues(alpha: 0.3), shape: BoxShape.circle)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: AppColors.brass),
              onPressed: () {},
            ),
          ],
        ),

        // Action button
        SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.oxblood,
              foregroundColor: AppColors.ivory,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.brass, width: 1.5),
              ),
            ),
            onPressed: () {},
            child: const Text(
              'CONFIRM VOTE FOR CANDIDATE 1',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Treatment 3: Stacked Deck with Peek
// ---------------------------------------------------------------------------
class Treatment3StackedDeckPeek extends StatelessWidget {
  final List<String> answers;
  final double width;

  const Treatment3StackedDeckPeek({super.key, required this.answers, required this.width});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Deck title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'EVIDENCE DECK',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.brass,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'Card 1 of 6 (5 behind)',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 11,
                color: AppColors.brass.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Stacked deck stack container
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Deep Card 3 peek (tilted slightly right)
              Positioned(
                top: 4,
                right: 8,
                left: 20,
                bottom: 24,
                child: Transform.rotate(
                  angle: 0.04,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF181512),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.brass.withValues(alpha: 0.2), width: 1),
                    ),
                  ),
                ),
              ),

              // Card 2 peek (tilted slightly left with visible edge)
              Positioned(
                top: 10,
                left: 10,
                right: 14,
                bottom: 16,
                child: Transform.rotate(
                  angle: -0.025,
                  child: Container(
                    padding: const EdgeInsets.only(top: 8, left: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF221D17),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.brass.withValues(alpha: 0.4), width: 1.5),
                    ),
                    alignment: Alignment.topLeft,
                    child: Text(
                      'CARD II',
                      style: TextStyle(
                        fontFamily: 'CormorantGaramond',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brass.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),

              // Front Card 1 (Active Card)
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.groundRaised,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.brass, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.brass,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CARD 1 · FRONT',
                              style: TextStyle(
                                fontFamily: 'CormorantGaramond',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          const ThematicIcon(type: ThematicIconType.host, size: 16, color: AppColors.brass),
                        ],
                      ),
                      const Spacer(),
                      Center(
                        child: Text(
                          '"${answers[0]}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: width < 360 ? 14 : 17,
                            fontStyle: FontStyle.italic,
                            color: AppColors.parchment,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '100 characters',
                            style: TextStyle(
                              fontFamily: 'Lora',
                              fontSize: 10,
                              color: AppColors.ivory.withValues(alpha: 0.5),
                            ),
                          ),
                          Text(
                            'Swipe card to peel ⟶',
                            style: TextStyle(
                              fontFamily: 'CormorantGaramond',
                              fontSize: 12,
                              color: AppColors.brass.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Deck navigation & Vote button
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brass,
                  side: BorderSide(color: AppColors.brass.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () {},
                child: const Text('PEEL NEXT ⟶', style: TextStyle(fontFamily: 'CormorantGaramond', fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.oxblood,
                  foregroundColor: AppColors.ivory,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.brass, width: 1.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () {},
                child: const Text('CAST BALLOT', style: TextStyle(fontFamily: 'CormorantGaramond', fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Treatment 4: Segmented Pager
// ---------------------------------------------------------------------------
class Treatment4SegmentedPager extends StatelessWidget {
  final List<String> answers;
  final double width;

  const Treatment4SegmentedPager({super.key, required this.answers, required this.width});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Direct Segmented Tabs
        Row(
          children: [
            for (int i = 0; i < 6; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: i == 0 ? AppColors.brass : AppColors.groundRaised,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: i == 0 ? AppColors.brass : AppColors.brass.withValues(alpha: 0.3),
                      width: i == 0 ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _roman(i + 1),
                    style: TextStyle(
                      fontFamily: 'CormorantGaramond',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: i == 0 ? AppColors.ink : AppColors.ivory,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // Single Pane for Selected Tab
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.groundRaised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.brass, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.oxblood,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'OPTION I',
                        style: TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ivory,
                        ),
                      ),
                    ),
                    Text(
                      'Tap any Roman tab to compare',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 10,
                        color: AppColors.brass.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Text(
                    '"${answers[0]}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: width < 360 ? 15 : 18,
                      fontStyle: FontStyle.italic,
                      color: AppColors.parchment,
                      height: 1.45,
                    ),
                  ),
                ),
                const Spacer(),
                Center(
                  child: Text(
                    '100 characters · 0 taps to switch to Option IV',
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 11,
                      color: AppColors.ivory.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Action button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.oxblood,
              foregroundColor: AppColors.ivory,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.brass, width: 1.5),
              ),
            ),
            onPressed: () {},
            child: const Text(
              'CAST BALLOT FOR OPTION I',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _roman(int n) {
    const r = ['I', 'II', 'III', 'IV', 'V', 'VI'];
    return r[n - 1];
  }
}
