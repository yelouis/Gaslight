import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/utils/scoring_logic.dart';

void main() {
  group('Issue 78: ScoringLogic truth resolution by targetPlayerId', () {
    test('Case A: P=4, S=1 calculates correct score deltas (truth reward = 2)', () {
      final state = GameState(
        roomCode: 'TEST',
        totalPlayers: 4,
        forgeriesPerCard: 1,
      );

      // Card target is p_host
      final card = CardModel(
        targetPlayerId: 'p_host',
        promptText: 'What is my secret?',
        truthAnswer: 'I love cats',
        sabotageAnswers: {
          'p_g3': 'I love dogs',
        },
      );

      // p_g1 votes truth (resolved author: p_host)
      // p_g2 votes forgery (resolved author: p_g3)
      // p_g3 votes truth (resolved author: p_host)
      final votes = {
        'p_g1': 'p_host',
        'p_g2': 'p_g3',
        'p_g3': 'p_host',
      };

      final deltas = ScoringLogic.calculateScores(
        state: state,
        currentCard: card,
        playerVotes: votes,
      );

      // Truth voter p_g1 gets truthReward = ceil((4-1)/(1+1)) = 2
      expect(deltas['p_g1'], equals(2));

      // Saboteur p_g3 correctly identified truth -> gets truthReward (2) + bonus (1) + forger credit from p_g2 (1) = 4
      expect(deltas['p_g3'], equals(4));

      // Card target p_host gets +1 for each player who found the truth (p_g1 and p_g3) = 2
      expect(deltas['p_host'], equals(2));

      // Over-reach guard: p_g2 voted for a forgery, gets 0
      expect(deltas['p_g2'], isNull);
    });

    test('Case B: P=5, S=3 calculates correct score deltas (truth reward = 1)', () {
      final state = GameState(
        roomCode: 'TEST',
        totalPlayers: 5,
        forgeriesPerCard: 3,
      );

      final card = CardModel(
        targetPlayerId: 'p_host',
        promptText: 'A secret',
        truthAnswer: 'Truth',
        sabotageAnswers: {
          'p_g1': 'Lie 1',
          'p_g2': 'Lie 2',
          'p_g3': 'Lie 3',
        },
      );

      // p_g4 (non-saboteur) votes truth (p_host)
      // p_g1 (saboteur) votes forgery authored by p_g2
      // p_g2 (saboteur) votes truth (p_host)
      // p_g3 (saboteur) votes truth (p_host)
      final votes = {
        'p_g4': 'p_host',
        'p_g1': 'p_g2',
        'p_g2': 'p_host',
        'p_g3': 'p_host',
      };

      final deltas = ScoringLogic.calculateScores(
        state: state,
        currentCard: card,
        playerVotes: votes,
      );

      // Truth voter p_g4 (non-saboteur) gets truthReward = ceil((5-1)/(3+1)) = 1
      expect(deltas['p_g4'], equals(1));

      // Target p_host gets +1 per truth voter (p_g4, p_g2, p_g3) = 3
      expect(deltas['p_host'], equals(3));

      // Saboteur p_g2 gets truthReward (1) + bonus (1) + forger credit from p_g1 (1) = 3
      expect(deltas['p_g2'], equals(3));

      // Saboteur p_g3 gets truthReward (1) + bonus (1) = 2
      expect(deltas['p_g3'], equals(2));

      // Over-reach guard: p_g1 voted for a forgery, gets 0
      expect(deltas['p_g1'], isNull);
    });
  });
}
