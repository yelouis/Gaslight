import '../models/game_state.dart';
import '../models/card_model.dart';
import 'dart:math';

class ScoringLogic {
  /// Dynamically tallies points for the Mimicry Edition.
  /// 
  /// The formula `ceil((P - 1) / (S + 1))` ensures EVs stay balanced regardless
  /// of whether there are 4 players with 2 sabotages, or 20 players with 5 sabotages.
  static Map<String, int> calculateScores({
    required GameState state,
    required CardModel currentCard,
    required Map<String, String> playerVotes, // VoterID -> VotedForID (or "TRUTH")
  }) {
    Map<String, int> deltas = {};
    
    int p = state.totalPlayers;
    int s = state.sabotageAnswersCount;
    int truthReward = ((p - 1) / (s + 1)).ceil();
    
    // Evaluate every single vote
    playerVotes.forEach((voterId, votedForId) {
      if (votedForId == 'TRUTH') {
        // The voter gets points for finding the truth
        deltas[voterId] = (deltas[voterId] ?? 0) + truthReward;
        
        // The Target gets 1 point because someone correctly guessed their truth
        deltas[currentCard.targetPlayerId] = (deltas[currentCard.targetPlayerId] ?? 0) + 1;
      } else {
        // A Saboteur tricked someone and gets 1 point
        deltas[votedForId] = (deltas[votedForId] ?? 0) + 1;
      }
    });

    return deltas;
  }
}
