import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/utils/callable_error_message.dart';

/// Issue 185 / AI11: one mapper, [gameCallableErrorMessage], for the craft and reveal screens.
///
/// It reads `error.code` and `error.details['reason']` -- never the message text, which is
/// free to change and is shown to nobody. Three (action, code, reason) triples have a sentence;
/// everything else is the generic one.
void main() {
  const closed = 'The guessing window has closed.';
  const lockedIn = 'That guess is already locked in.';
  const tooSimilar = 'Too similar to an existing answer! Be more creative.';
  const generic = 'Something went wrong. Try again.';

  FirebaseFunctionsException fe(String code, {Object? details, String message = 'raw server text'}) =>
      FirebaseFunctionsException(code: code, message: message, details: details);

  group('the three mapped triples', () {
    test('unmaskGuess + failed-precondition + deadline_passed', () {
      expect(
        gameCallableErrorMessage(fe('failed-precondition', details: {'reason': 'deadline_passed'}), action: GameAction.unmaskGuess),
        closed,
      );
    });

    test('unmaskGuess + failed-precondition + already_submitted', () {
      expect(
        gameCallableErrorMessage(fe('failed-precondition', details: {'reason': 'already_submitted'}), action: GameAction.unmaskGuess),
        lockedIn,
      );
    });

    test('submitAnswer + invalid-argument + too_similar', () {
      expect(
        gameCallableErrorMessage(fe('invalid-argument', details: {'reason': 'too_similar'}), action: GameAction.submitAnswer),
        tooSimilar,
      );
    });

    test('details as the platform delivers them: a Map<Object?, Object?>', () {
      final Map<Object?, Object?> details = {'reason': 'deadline_passed'};
      expect(gameCallableErrorMessage(fe('failed-precondition', details: details), action: GameAction.unmaskGuess), closed);
    });
  });

  group('everything else is the generic sentence', () {
    test('each mapped code with no details', () {
      expect(gameCallableErrorMessage(fe('failed-precondition'), action: GameAction.unmaskGuess), generic);
      expect(gameCallableErrorMessage(fe('invalid-argument'), action: GameAction.submitAnswer), generic);
    });

    test('details that are not a Map', () {
      for (final details in <Object?>['deadline_passed', ['deadline_passed'], 42, true]) {
        expect(gameCallableErrorMessage(fe('failed-precondition', details: details), action: GameAction.unmaskGuess), generic,
            reason: 'details: $details');
      }
    });

    test('a Map without a reason, with an unknown reason, or with a non-string reason', () {
      for (final details in <Object?>[<String, Object?>{}, {'reason': 'something_new'}, {'reason': 7}, {'why': 'deadline_passed'}]) {
        expect(gameCallableErrorMessage(fe('failed-precondition', details: details), action: GameAction.unmaskGuess), generic,
            reason: 'details: $details');
      }
    });

    test('a reason under the wrong code', () {
      expect(
        gameCallableErrorMessage(fe('invalid-argument', details: {'reason': 'deadline_passed'}), action: GameAction.unmaskGuess),
        generic,
      );
      expect(
        gameCallableErrorMessage(fe('failed-precondition', details: {'reason': 'too_similar'}), action: GameAction.submitAnswer),
        generic,
      );
    });

    test('a reason belongs to its action: one screen\'s reason is nothing on the other', () {
      expect(
        gameCallableErrorMessage(fe('invalid-argument', details: {'reason': 'too_similar'}), action: GameAction.unmaskGuess),
        generic,
      );
      expect(
        gameCallableErrorMessage(fe('failed-precondition', details: {'reason': 'deadline_passed'}), action: GameAction.submitAnswer),
        generic,
      );
      expect(
        gameCallableErrorMessage(fe('failed-precondition', details: {'reason': 'already_submitted'}), action: GameAction.submitAnswer),
        generic,
      );
    });

    test('the message text is never read: the old magic words with no details', () {
      expect(
        gameCallableErrorMessage(
            fe('failed-precondition', message: 'Player has already submitted an unmask guess.'), action: GameAction.unmaskGuess),
        generic,
      );
      expect(
        gameCallableErrorMessage(fe('failed-precondition', message: 'failed-precondition already submitted'), action: GameAction.unmaskGuess),
        generic,
      );
      expect(
        gameCallableErrorMessage(
            fe('invalid-argument', message: "Answer is too similar to another player's answer!"), action: GameAction.submitAnswer),
        generic,
      );
    });

    test('a non-FirebaseFunctionsException', () {
      for (final error in <Object>[Exception('x'), StateError('y'), 'already submitted', 42]) {
        expect(gameCallableErrorMessage(error, action: GameAction.unmaskGuess), generic, reason: '$error');
        expect(gameCallableErrorMessage(error, action: GameAction.submitAnswer), generic, reason: '$error');
      }
    });
  });
}
