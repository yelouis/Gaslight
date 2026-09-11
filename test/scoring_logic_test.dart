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

  group('Issue 163 (AA10): ScoringLogic Round Multiplier', () {
    final card = CardModel(
      targetPlayerId: 'p_host',
      promptText: 'What is my secret?',
      truthAnswer: 'I love cats',
      sabotageAnswers: {
        'p_g3': 'I love dogs',
      },
    );

    final votes = {
      'p_g1': 'p_host',
      'p_g2': 'p_g3',
      'p_g3': 'p_host',
    };

    test('1. identical votes at currentRound 1, 2 and 3 produce x1, x2 and x3 the deltas', () {
      final stateR1 = GameState(roomCode: 'TEST', totalPlayers: 4, forgeriesPerCard: 1, currentRound: 1);
      final deltasR1 = ScoringLogic.calculateScores(state: stateR1, currentCard: card, playerVotes: votes);
      expect(deltasR1['p_g1'], equals(2));
      expect(deltasR1['p_g3'], equals(4));
      expect(deltasR1['p_host'], equals(2));

      final stateR2 = GameState(roomCode: 'TEST', totalPlayers: 4, forgeriesPerCard: 1, currentRound: 2);
      final deltasR2 = ScoringLogic.calculateScores(state: stateR2, currentCard: card, playerVotes: votes);
      expect(deltasR2['p_g1'], equals(4));
      expect(deltasR2['p_g3'], equals(8));
      expect(deltasR2['p_host'], equals(4));

      final stateR3 = GameState(roomCode: 'TEST', totalPlayers: 4, forgeriesPerCard: 1, currentRound: 3);
      final deltasR3 = ScoringLogic.calculateScores(state: stateR3, currentCard: card, playerVotes: votes);
      expect(deltasR3['p_g1'], equals(6));
      expect(deltasR3['p_g3'], equals(12));
      expect(deltasR3['p_host'], equals(6));
    });

    test('2. currentRound default (1) -> behaves as round 1', () {
      final stateDefault = GameState(roomCode: 'TEST', totalPlayers: 4, forgeriesPerCard: 1);
      final deltas = ScoringLogic.calculateScores(state: stateDefault, currentCard: card, playerVotes: votes);
      expect(deltas['p_g1'], equals(2));
      expect(deltas['p_g3'], equals(4));
      expect(deltas['p_host'], equals(2));
    });
  });

  group('ScoringLogic Breakdown Sum Invariant (AA11 / Issue 169)', () {
    int sumBreakdown(List<ScoreBreakdownItem>? items) =>
        items?.fold<int>(0, (sum, item) => sum + item.points) ?? 0;

    final card = CardModel(
      targetPlayerId: 'p_host',
      promptText: 'What is my secret?',
      truthAnswer: 'I love cats',
      sabotageAnswers: {
        'p_g3': 'I love dogs',
      },
    );

    final votes = {
      'p_g1': 'p_host',
      'p_g2': 'p_g3',
      'p_g3': 'p_host',
    };

    test('Fixture 1: Round 1 (P=4, S=1) - sum(breakdown) == deltas for every player', () {
      final state = GameState(roomCode: 'TEST', totalPlayers: 4, forgeriesPerCard: 1, currentRound: 1);
      final res = ScoringLogic.calculateScoresAndBreakdown(state: state, currentCard: card, playerVotes: votes);
      for (final entry in res.deltas.entries) {
        expect(sumBreakdown(res.breakdown[entry.key]), equals(entry.value), reason: 'Sum for player ${entry.key}');
      }
    });

    test('Fixture 2: Round 2 Multiplier (x2) - sum(breakdown) == deltas for every player', () {
      final state = GameState(roomCode: 'TEST', totalPlayers: 4, forgeriesPerCard: 1, currentRound: 2);
      final res = ScoringLogic.calculateScoresAndBreakdown(state: state, currentCard: card, playerVotes: votes);
      for (final entry in res.deltas.entries) {
        expect(sumBreakdown(res.breakdown[entry.key]), equals(entry.value), reason: 'Sum for player ${entry.key}');
        final multItem = res.breakdown[entry.key]?.any((item) => item.rule == 'round_multiplier');
        expect(multItem, isTrue, reason: 'Multiplier line present for player ${entry.key}');
      }
    });

    test('Fixture 3: Round 3 Multiplier (x3) on 5-player 3-forgery match - sum(breakdown) == deltas for every player', () {
      final state5 = GameState(roomCode: 'TEST', totalPlayers: 5, forgeriesPerCard: 3, currentRound: 3);
      final card5 = CardModel(
        targetPlayerId: 'p_host',
        promptText: 'A secret',
        truthAnswer: 'Truth',
        sabotageAnswers: {
          'p_g1': 'Lie 1',
          'p_g2': 'Lie 2',
          'p_g3': 'Lie 3',
        },
      );
      final votes5 = {
        'p_g4': 'p_host',
        'p_g1': 'p_g2',
        'p_g2': 'p_host',
        'p_g3': 'p_host',
      };
      final res = ScoringLogic.calculateScoresAndBreakdown(state: state5, currentCard: card5, playerVotes: votes5);
      for (final entry in res.deltas.entries) {
        expect(sumBreakdown(res.breakdown[entry.key]), equals(entry.value), reason: 'Sum for player ${entry.key}');
      }
    });

    test('Fixture 4: Negative deltas from unmask revenge accusation - sum(breakdown) == deltas for both sides', () {
      final state = GameState(roomCode: 'TEST', totalPlayers: 4, forgeriesPerCard: 1, currentRound: 1);
      final res = ScoringLogic.calculateScoresAndBreakdown(state: state, currentCard: card, playerVotes: votes);
      final deltas = Map<String, int>.from(res.deltas);
      final breakdown = Map<String, List<ScoreBreakdownItem>>.from(
        res.breakdown.map((k, v) => MapEntry(k, List<ScoreBreakdownItem>.from(v))),
      );

      const guesserId = 'p_g2';
      const forgerId = 'p_g3';

      deltas[guesserId] = (deltas[guesserId] ?? 0) + 1;
      deltas[forgerId] = (deltas[forgerId] ?? 0) - 1;

      final guesserItems = breakdown.putIfAbsent(guesserId, () => []);
      guesserItems.add(const ScoreBreakdownItem(rule: 'revenge_guess', points: 1));

      final forgerItems = breakdown.putIfAbsent(forgerId, () => []);
      forgerItems.add(const ScoreBreakdownItem(rule: 'revenge_guess', points: -1));

      expect(sumBreakdown(breakdown[guesserId]), equals(deltas[guesserId]));
      expect(sumBreakdown(breakdown[forgerId]), equals(deltas[forgerId]));

      // Standalone negative delta test
      final negativeBreakdown = const [ScoreBreakdownItem(rule: 'revenge_guess', points: -1)];
      expect(sumBreakdown(negativeBreakdown), equals(-1));
    });
  });

  group('ScoringLogic Target Forgery Guesses (AA16a / Issue 162)', () {
    int sumBreakdown(List<ScoreBreakdownItem>? items) {
      if (items == null) return 0;
      return items.fold(0, (acc, item) => acc + item.points);
    }

    final card = CardModel(
      targetPlayerId: 'p_target',
      promptText: 'My secret',
      truthAnswer: 'True answer',
      sabotageAnswers: const {
        'p_f1': 'Lie 1',
        'p_f2': 'Lie 2',
      },
      options: [
        CardAnswerOption(id: 'opt_truth', text: 'True answer'),
        CardAnswerOption(id: 'opt_f1', text: 'Lie 1'),
        CardAnswerOption(id: 'opt_f2', text: 'Lie 2'),
        CardAnswerOption(id: 'opt_placeholder', text: 'THE SOUL IS SILENT'),
      ],
      votes: const {
        'p_voter': 'opt_truth',
        'p_f1': 'opt_truth',
        'p_f2': 'opt_f1',
      },
    );

    const answerAuthors = {
      'opt_truth': 'p_target',
      'opt_f1': 'p_f1',
      'opt_f2': 'p_f2',
      'opt_placeholder': 'p_f3',
    };

    const votes = {
      'p_voter': 'p_target',
      'p_f1': 'p_target',
      'p_f2': 'p_f1',
    };

    test('1. all forgeries correctly guessed -> target receives +1 per forgery, forgers receive no penalty', () {
      final state = GameState(roomCode: 'TEST', totalPlayers: 4, forgeriesPerCard: 2, currentRound: 1);
      const targetGuesses = {
        'opt_f1': 'p_f1',
        'opt_f2': 'p_f2',
      };

      final baseResult = ScoringLogic.calculateScoresAndBreakdown(state: state, currentCard: card, playerVotes: votes);
      final withGuesses = ScoringLogic.calculateScoresAndBreakdown(
        state: state,
        currentCard: card,
        playerVotes: votes,
        targetForgeryGuesses: targetGuesses,
        answerAuthors: answerAuthors,
      );

      // Target gains 2 points for the 2 correct guesses
      expect(withGuesses.deltas['p_target'], equals((baseResult.deltas['p_target'] ?? 0) + 2));
      // Forgers receive no penalty
      expect(withGuesses.deltas['p_f1'], equals(baseResult.deltas['p_f1']));
      expect(withGuesses.deltas['p_f2'], equals(baseResult.deltas['p_f2']));

      // Breakdown contains target_forger_guess rule with 2 points for target
      final targetBreakdown = withGuesses.breakdown['p_target'] ?? [];
      final guessItem = targetBreakdown.firstWhere((i) => i.rule == 'target_forger_guess');
      expect(guessItem.points, equals(2));

      // Invariant holds
      for (final entry in withGuesses.deltas.entries) {
        expect(sumBreakdown(withGuesses.breakdown[entry.key]), equals(entry.value));
      }
    });

    test('2. partial map scores only correct entries', () {
      final state = GameState(roomCode: 'TEST', totalPlayers: 4, forgeriesPerCard: 2, currentRound: 1);
      const partialGuesses = {
        'opt_f1': 'p_f1', // correct (+1)
        'opt_f2': 'p_wrong', // incorrect (+0)
      };

      final baseResult = ScoringLogic.calculateScoresAndBreakdown(state: state, currentCard: card, playerVotes: votes);
      final withGuesses = ScoringLogic.calculateScoresAndBreakdown(
        state: state,
        currentCard: card,
        playerVotes: votes,
        targetForgeryGuesses: partialGuesses,
        answerAuthors: answerAuthors,
      );

      expect(withGuesses.deltas['p_target'], equals((baseResult.deltas['p_target'] ?? 0) + 1));
      final guessItem = (withGuesses.breakdown['p_target'] ?? []).firstWhere((i) => i.rule == 'target_forger_guess');
      expect(guessItem.points, equals(1));
      expect(sumBreakdown(withGuesses.breakdown['p_target']), equals(withGuesses.deltas['p_target']));
    });

    test('3. placeholder answer or departed player guess scores nothing', () {
      final state = GameState(roomCode: 'TEST', totalPlayers: 4, forgeriesPerCard: 2, currentRound: 1);
      const guesses = {
        'opt_placeholder': 'p_f3', // placeholder option
        'opt_f1': 'p_departed', // departed player
      };
      const authorsWithDeparted = {
        'opt_truth': 'p_target',
        'opt_f1': 'p_departed',
        'opt_f2': 'p_f2',
        'opt_placeholder': 'p_f3',
      };
      const activePlayers = ['p_target', 'p_voter', 'p_f1', 'p_f2']; // p_departed is NOT active

      final baseResult = ScoringLogic.calculateScoresAndBreakdown(state: state, currentCard: card, playerVotes: votes);
      final withGuesses = ScoringLogic.calculateScoresAndBreakdown(
        state: state,
        currentCard: card,
        playerVotes: votes,
        targetForgeryGuesses: guesses,
        answerAuthors: authorsWithDeparted,
        activePlayerIds: activePlayers,
      );

      expect(withGuesses.deltas['p_target'], equals(baseResult.deltas['p_target'] ?? 0));
      final hasGuessItem = (withGuesses.breakdown['p_target'] ?? []).any((i) => i.rule == 'target_forger_guess');
      expect(hasGuessItem, isFalse);
    });

    test('4. round multiplier scales target forgery guess points and satisfies sum invariant', () {
      final r3State = GameState(roomCode: 'TEST', totalPlayers: 4, forgeriesPerCard: 2, currentRound: 3); // multiplier x3
      const targetGuesses = {
        'opt_f1': 'p_f1',
        'opt_f2': 'p_f2',
      };

      final result = ScoringLogic.calculateScoresAndBreakdown(
        state: r3State,
        currentCard: card,
        playerVotes: votes,
        targetForgeryGuesses: targetGuesses,
        answerAuthors: answerAuthors,
      );

      // Base target points: 2 believable_target + 2 target_forger_guess = 4 base. x3 = 12 total.
      expect(result.deltas['p_target'], equals(12));
      for (final entry in result.deltas.entries) {
        expect(sumBreakdown(result.breakdown[entry.key]), equals(entry.value));
      }
    });
  });
}


