// Vote options must display the whole answer. Answers are capped at
// kMaxAnswerLength (100) on the client and the server; this proves the card can
// actually render that many characters rather than ellipsing them, which is the
// half of a length cap that is easy to forget.
//
// The assertion is mechanical: RenderParagraph.didExceedMaxLines is true the
// moment Flutter drops text on the floor. Falsified against the pre-fix widget
// (fontSize 16, maxLines 4) — see the test named "falsification" below.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/widgets/card_grid.dart';

void main() {
  // The real font is load-bearing for this test. `flutter test` otherwise
  // substitutes a fallback whose glyphs are square — every character as wide as
  // the font is tall — which needed 10 lines for 100 characters where Lora
  // needs 5. Measuring that font would fail a layout that is perfectly fine on
  // a device, and "fixing" it would shrink real text to nothing.
  setUpAll(() async {
    final loader = FontLoader('Lora');
    loader.addFont(File('assets/fonts/lora/Lora-Bold.ttf')
        .readAsBytes()
        .then((b) => ByteData.sublistView(Uint8List.fromList(b))));
    await loader.load();
  });
  // Tightest real case: mobile portrait, two columns.
  const surface = Size(375, 812);

  Future<void> pumpGrid(WidgetTester tester, List<String> texts) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: surface, accessibleNavigation: true),
          child: Scaffold(
            body: Padding(
              // Mirrors the horizontal padding phase3_vote gives the grid.
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: CardGrid(
                  answers: [
                    for (var i = 0; i < texts.length; i++)
                      VotingAnswer(authorId: 'a$i', text: texts[i]),
                  ],
                  selectedAuthorId: null,
                  currentPlayerId: 'me',
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectNoTruncation(WidgetTester tester, String text) {
    final para = tester.renderObject<RenderParagraph>(find.text(text));
    expect(
      para.didExceedMaxLines,
      isFalse,
      reason: 'a ${text.length}-character answer was truncated in the vote card',
    );
  }

  testWidgets('a 100-character prose answer renders in full', (tester) async {
    // Exactly 100 characters.
    const answer =
        'I once told my entire team the deadline had moved and then quietly moved it back before anyone check';
    expect(answer.length, kMaxAnswerLength);

    await pumpGrid(tester, [answer, 'short one']);
    expectNoTruncation(tester, answer);
  });

  testWidgets('100 characters of long words still render in full', (tester) async {
    const answer =
        'Extraordinarily embarrassing miscommunication involving refrigerated leftovers and unfortunate timin';
    expect(answer.length, kMaxAnswerLength);

    await pumpGrid(tester, [answer, 'short one']);
    expectNoTruncation(tester, answer);
  });

  testWidgets('a 100-character answer renders in full on your own forgery card', (tester) async {
    // The self-answer card also carries a "(Your Forgery)" label, so it has
    // less vertical room than the others.
    const answer =
        'I once told my entire team the deadline had moved and then quietly moved it back before anyone check';
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: surface, accessibleNavigation: true),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: CardGrid(
                  answers: [
                    VotingAnswer(authorId: 'me', text: answer, isSelfAnswer: true),
                    VotingAnswer(authorId: 'b', text: 'short one'),
                  ],
                  selectedAuthorId: null,
                  currentPlayerId: 'me',
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expectNoTruncation(tester, answer);
  });

  testWidgets('100 characters that wrap badly still render in full', (tester) async {
    // Uniform 10-character tokens — the least forgiving wrapping shape short of
    // one unbroken 100-character word.
    const answer =
        'aaaaaaaaaa bbbbbbbbbb cccccccccc dddddddddd eeeeeeeeee ffffffffff gggggggggg hhhhhhhhhh iiiiiiiiii j';
    expect(answer.length, kMaxAnswerLength);

    await pumpGrid(tester, [answer, 'short one']);
    expectNoTruncation(tester, answer);
  });

  testWidgets('P9: 100-character answer renders in full across 320px, 375px, and 430px widths at 1.0 and 1.3 text scale (Issue 132)', (tester) async {
    const answer =
        'I once told my entire team the deadline had moved and then quietly moved it back before anyone check';
    expect(answer.length, kMaxAnswerLength);

    for (final width in [320.0, 375.0, 430.0]) {
      for (final scale in [1.0, 1.3]) {
        final customSurface = Size(width, 700);
        await tester.binding.setSurfaceSize(customSurface);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: customSurface,
                textScaler: TextScaler.linear(scale),
                accessibleNavigation: true,
              ),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    child: CardGrid(
                      answers: [
                        VotingAnswer(authorId: 'a1', text: answer),
                        VotingAnswer(authorId: 'a2', text: 'short one'),
                      ],
                      selectedAuthorId: null,
                      currentPlayerId: 'me',
                      onSelect: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expectNoTruncation(tester, answer);
      }
    }
  });

  testWidgets('P9 discoverability: six options at 320x640 portrait exceed viewport height and option at index 3 has non-zero height below fold', (tester) async {
    const surfaceSize = Size(320, 640);
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final scrollController = ScrollController();
    addTearDown(() => scrollController.dispose());

    final answers = [
      for (int i = 0; i < 6; i++)
        VotingAnswer(authorId: 'a$i', text: 'Option number $i with some believable lie content'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: surfaceSize, accessibleNavigation: true),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    const SizedBox(height: 100), // Prompt header simulation
                    CardGrid(
                      answers: answers,
                      selectedAuthorId: null,
                      currentPlayerId: 'me',
                      onSelect: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The scroll view scrollable extent should exceed viewport
    expect(scrollController.position.maxScrollExtent, greaterThan(0.0),
        reason: 'Content height must exceed 640pt viewport so user can scroll');

    // Scroll to reveal index 3 and verify its height is positive
    await tester.scrollUntilVisible(
      find.text(answers[3].text),
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final item3Finder = find.text(answers[3].text);
    expect(item3Finder, findsOneWidget);
    final renderBox = tester.renderObject<RenderBox>(item3Finder);
    expect(renderBox.size.height, greaterThan(0));
  });

  testWidgets('P9: SEALED stamp appears on placeholder and own-answer options and tap is disabled', (tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? selectedId;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: surface, accessibleNavigation: true),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: CardGrid(
                  answers: [
                    VotingAnswer(authorId: 'self', text: 'My own forgery', isSelfAnswer: true),
                    VotingAnswer(authorId: 'placeholder', text: 'THE SOUL IS SILENT'),
                    VotingAnswer(authorId: 'valid', text: 'A valid candidate'),
                  ],
                  selectedAuthorId: null,
                  currentPlayerId: 'self',
                  onSelect: (id) => selectedId = id,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Two SEALED stamps: self answer and placeholder
    expect(find.text('SEALED'), findsNWidgets(2));

    // Tap self answer -> should not select
    await tester.tap(find.text('My own forgery'));
    await tester.pump();
    expect(selectedId, isNull);

    // Tap placeholder -> should not select
    await tester.tap(find.text('THE SOUL IS SILENT'));
    await tester.pump();
    expect(selectedId, isNull);

    // Tap valid -> should select
    await tester.tap(find.text('A valid candidate'));
    await tester.pump();
    expect(selectedId, equals('valid'));
  });
}
