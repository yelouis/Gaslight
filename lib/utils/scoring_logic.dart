import '../models/game_state.dart';
import '../models/card_model.dart';

class ScoreCalculationResult {
  final Map<String, int> deltas;
  final Map<String, List<ScoreBreakdownItem>> breakdown;

  const ScoreCalculationResult({
    required this.deltas,
    required this.breakdown,
  });
}

class ScoringLogic {
  /// Dynamically tallies points and computes rule breakdowns for the Mimicry Edition.
  static ScoreCalculationResult calculateScoresAndBreakdown({
    required GameState state,
    required CardModel currentCard,
    required Map<String, String> playerVotes, // VoterID -> VotedForAuthorID
  }) {
    final Map<String, int> deltas = {};
    final Map<String, List<ScoreBreakdownItem>> breakdown = {};

    void addBreakdown(String playerId, String rule, int points) {
      if (points == 0) return;
      final list = breakdown.putIfAbsent(playerId, () => []);
      final idx = list.indexWhere((item) => item.rule == rule);
      if (idx != -1) {
        list[idx] = ScoreBreakdownItem(rule: rule, points: list[idx].points + points);
      } else {
        list.add(ScoreBreakdownItem(rule: rule, points: points));
      }
    }

    int p = state.totalPlayers;
    int s = currentCard.sabotageAnswers.length;
    int truthReward = ((p - 1) / (s + 1)).ceil();

    // Evaluate every single vote
    playerVotes.forEach((voterId, votedForId) {
      if (voterId == votedForId) return; // Self-vote prevention!

      if (votedForId == currentCard.targetPlayerId) {
        // The voter gets points for finding the truth
        deltas[voterId] = (deltas[voterId] ?? 0) + truthReward;
        addBreakdown(voterId, 'truth_found', truthReward);

        // Bonus: +1 point if the Saboteur *also* correctly identifies the Truth
        if (currentCard.sabotageAnswers.containsKey(voterId)) {
          deltas[voterId] = (deltas[voterId] ?? 0) + 1;
          addBreakdown(voterId, 'sharp_eye', 1);
        }

        // The Target gets 1 point because someone correctly guessed their truth
        deltas[currentCard.targetPlayerId] = (deltas[currentCard.targetPlayerId] ?? 0) + 1;
        addBreakdown(currentCard.targetPlayerId, 'believable_target', 1);
      } else {
        // A Saboteur tricked someone and gets 1 point
        deltas[votedForId] = (deltas[votedForId] ?? 0) + 1;
        addBreakdown(votedForId, 'successful_forgery', 1);
      }
    });

    final multiplier = state.currentRound < 1 ? 1 : state.currentRound;
    if (multiplier > 1) {
      for (final playerId in deltas.keys.toList()) {
        final basePoints = deltas[playerId]!;
        final multBonus = basePoints * (multiplier - 1);
        deltas[playerId] = basePoints * multiplier;
        if (multBonus != 0) {
          addBreakdown(playerId, 'round_multiplier', multBonus);
        }
      }
    }

    return ScoreCalculationResult(deltas: deltas, breakdown: breakdown);
  }

  /// Dynamically tallies points for the Mimicry Edition.
  /// 
  /// The formula `ceil((P - 1) / (S + 1))` ensures EVs stay balanced regardless
  /// of whether there are 4 players with 2 sabotages, or 20 players with 5 sabotages.
  static Map<String, int> calculateScores({
    required GameState state,
    required CardModel currentCard,
    required Map<String, String> playerVotes, // VoterID -> VotedForAuthorID
  }) {
    return calculateScoresAndBreakdown(
      state: state,
      currentCard: currentCard,
      playerVotes: playerVotes,
    ).deltas;
  }

  /// Returns a map of playerId -> list of ScoreBreakdownItem.
  static Map<String, List<ScoreBreakdownItem>> calculateBreakdown({
    required GameState state,
    required CardModel currentCard,
    required Map<String, String> playerVotes,
  }) {
    return calculateScoresAndBreakdown(
      state: state,
      currentCard: currentCard,
      playerVotes: playerVotes,
    ).breakdown;
  }
}

