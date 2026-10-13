import 'package:cloud_functions/cloud_functions.dart';

enum GameAction { unmaskGuess, submitAnswer }

/// The sentence for a failed craft or reveal callable.
///
/// Chosen from the error's `code` and the server's `details['reason']`, never from its message
/// text, which is free to change and was never written for the player. `submitUnmaskGuess`
/// throws `failed-precondition` for six different reasons and `submitAnswer` throws
/// `invalid-argument` for several, so a code alone is not enough: the server names the two
/// reasons the screens act on (Issue 185 / AI11). A server that predates `details` gets the
/// generic sentence.
String gameCallableErrorMessage(Object error, {required GameAction action}) {
  const String generic = 'Something went wrong. Try again.';
  if (error is! FirebaseFunctionsException) return generic;
  final Object? details = error.details;
  final Object? reason = details is Map ? details['reason'] : null;
  switch (action) {
    case GameAction.unmaskGuess:
      if (error.code == 'failed-precondition') {
        if (reason == 'deadline_passed') return 'The guessing window has closed.';
        if (reason == 'already_submitted') return 'That guess is already locked in.';
      }
    case GameAction.submitAnswer:
      if (error.code == 'invalid-argument' && reason == 'too_similar') {
        return 'Too similar to an existing answer! Be more creative.';
      }
  }
  return generic;
}
