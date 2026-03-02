enum ScoreResult { bullseye, nearMiss, exposed, mindReader, saboteur, standard }

class ScoringLogic {
  static const int bullseyePoints = 10;
  static const int nearMissPoints = 2;
  static const int exposedPenalty = -5;
  static const int mindReaderPoints = 5;

  /// Calculates scores at the end of a round (Reveal phase).
  ///
  /// [target] is the Trickster's secret target number of votes.
  /// [actualVotes] is how many people actually voted for Option B.
  /// [playerGuesses] is a map of Player ID -> What they guessed the target was.
  /// [totalVoters] is the total number of Voters (Marks).
  static Map<String, int> calculateScores({
    required String tricksterId,
    required int target,
    required int actualVotes,
    required Map<String, int> playerGuesses,
    required int totalVoters,
  }) {
    final Map<String, int> deltas = {};
    int tricksterDelta = 0;

    // Evaluate the Trickster based on actual votes
    if (actualVotes == target) {
      tricksterDelta += bullseyePoints;
    } else if ((actualVotes - target).abs() == 1) {
      tricksterDelta += nearMissPoints;
    }

    // Evaluate Voters (Mind Reader logic & Exposed Penalty)
    int correctGuesses = 0;
    
    playerGuesses.forEach((playerId, guess) {
      if (playerId == tricksterId) return; // Trickster doesn't guess
      
      if (guess == target) {
        correctGuesses++;
        deltas[playerId] = (deltas[playerId] ?? 0) + mindReaderPoints;
      } else {
        deltas[playerId] = (deltas[playerId] ?? 0) + 0;
      }
    });

    // Check if Truth was Exposed
    if (totalVoters > 0 && correctGuesses > (totalVoters / 2)) {
      tricksterDelta += exposedPenalty;
    }

    deltas[tricksterId] = tricksterDelta;
    return deltas;
  }
}
