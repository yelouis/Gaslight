import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/game_state.dart';
import '../lib/models/player_state.dart';
import '../lib/models/card_model.dart';
import '../lib/utils/prompt_decks.dart';
import '../lib/utils/rotation_engine.dart';
import '../lib/utils/scoring_logic.dart';
import 'dart:math';

class FakeHttpsCallableResult<T> implements HttpsCallableResult<T> {
  @override
  final T data;
  FakeHttpsCallableResult(this.data);
}

class FakeFirebaseFunctions extends Fake implements FirebaseFunctions {
  final FirebaseFirestore db;
  FakeFirebaseFunctions(this.db);

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    return FakeHttpsCallable(db, name);
  }
}

class FakeHttpsCallable extends Fake implements HttpsCallable {
  final FirebaseFirestore db;
  final String name;

  FakeHttpsCallable(this.db, this.name);

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final params = parameters as Map<String, dynamic>? ?? {};
    final roomCode = params['roomCode'] as String? ?? 'TEST';

    if (name == 'createRoom') {
      final playerName = params['playerName'];
      final playerId = params['playerId'];
      final colorValue = params['colorValue'];
      final avatarIndex = params['avatarIndex'];
      final sabotageAnswersCount = params['sabotageAnswersCount'];
      final isTimerDisabled = params['isTimerDisabled'];

      const generatedCode = 'TEST';
      final initialState = GameState(
        roomCode: generatedCode,
        totalPlayers: 1,
        sabotageAnswersCount: sabotageAnswersCount,
        isTimerDisabled: isTimerDisabled,
      );
      final initialPlayer = PlayerState(
        id: playerId,
        name: playerName,
        isHost: true,
        colorValue: colorValue,
        avatarIndex: avatarIndex,
        joinedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await db.collection('rooms').doc(generatedCode).set(initialState.toMap());
      await db.collection('rooms').doc(generatedCode).collection('players').doc(playerId).set(initialPlayer.toMap());

      return FakeHttpsCallableResult({'roomCode': generatedCode} as T);
    }

    if (name == 'joinRoom') {
      final roomCode = params['roomCode'];
      final playerName = params['playerName'];
      final playerId = params['playerId'];
      final colorValue = params['colorValue'];
      final avatarIndex = params['avatarIndex'];

      final doc = await db.collection('rooms').doc(roomCode).get();
      final roomState = GameState.fromMap(doc.data()!, doc.id);
      final isSpectator = roomState.currentPhase != GamePhase.lobby;

      final newPlayer = PlayerState(
        id: playerId,
        name: playerName,
        colorValue: colorValue,
        avatarIndex: avatarIndex,
        joinedAt: DateTime.now().millisecondsSinceEpoch,
        role: isSpectator ? PlayerRole.spectator : PlayerRole.unassigned,
      );

      await db.collection('rooms').doc(roomCode).collection('players').doc(playerId).set(newPlayer.toMap());
      await db.collection('rooms').doc(roomCode).update({
        'totalPlayers': roomState.totalPlayers + (isSpectator ? 0 : 1),
      });

      return FakeHttpsCallableResult({'role': newPlayer.role.name} as T);
    }

    if (name == 'startGame') {
      final roomRef = db.collection('rooms').doc(roomCode);
      final roomDoc = await roomRef.get();
      final roomState = GameState.fromMap(roomDoc.data()!, roomDoc.id);

      final playersSnap = await roomRef.collection('players').get();
      final players = playersSnap.docs.map((doc) => PlayerState.fromMap(doc.data(), doc.id)).toList();
      final activePlayers = players.where((p) => p.role != PlayerRole.spectator).toList();

      if (activePlayers.length < 2) {
        throw Exception("Cannot start: Need at least 2 active players.");
      }
      if (activePlayers.length <= roomState.sabotageAnswersCount) {
        throw Exception("Cannot start: Need more players than forgery rounds.");
      }
      final deckSize = PromptDecks.getDeckSize(roomState.selectedDeckId);
      if (deckSize < activePlayers.length) {
        throw Exception("Cannot start: Selected deck has $deckSize prompts, but you need at least ${activePlayers.length} prompts.");
      }

      var pIds = activePlayers.map((p) => p.id).toList();
      var nativeRotations = RotationEngine.generateRotations(pIds, roomState.sabotageAnswersCount);
      Map<String, Map<String, String>> stringRotations = {};
      nativeRotations.forEach((key, val) => stringRotations[key.toString()] = val);

      var prompts = PromptDecks.drawPrompts(roomState.selectedDeckId, activePlayers.length);
      List<CardModel> startingCards = [];
      for (int i = 0; i < pIds.length; i++) {
        startingCards.add(CardModel(
          targetPlayerId: pIds[i],
          promptText: prompts[i],
        ));
      }

      int startIdx = 1;
      Map<String, String> initAssignments = stringRotations[startIdx.toString()]!;

      await roomRef.update(roomState.copyWith(
        currentPhase: GamePhase.forgery,
        totalPlayers: players.length,
        currentRotationIndex: startIdx,
        cards: startingCards,
        currentCardAssignments: initAssignments,
        rotationPlan: stringRotations,
        readyPlayers: {},
      ).toMap());

      return FakeHttpsCallableResult({'success': true} as T);
    }

    if (name == 'submitAnswer') {
      final targetCardId = params['targetCardId'];
      final authorId = params['authorId'];
      final text = params['text'];
      final isTruth = params['isTruth'];

      if (text.toString().contains('trigger_error')) {
        throw FirebaseFunctionsException(
          message: 'Similarity check failed or mock error triggered!',
          code: 'invalid-argument',
        );
      }

      final roomRef = db.collection('rooms').doc(roomCode);
      
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        final currentState = GameState.fromMap(snapshot.data()!, snapshot.id);
        
        final cardIdx = currentState.cards.indexWhere((c) => c.targetPlayerId == targetCardId);
        final card = currentState.cards[cardIdx];
        CardModel updatedCard;
        if (isTruth) {
          updatedCard = card.copyWith(truthAnswer: text);
        } else {
          final sabs = Map<String, String>.from(card.sabotageAnswers);
          sabs[authorId] = text;
          updatedCard = card.copyWith(sabotageAnswers: sabs);
        }
        
        final newCards = List<CardModel>.from(currentState.cards);
        newCards[cardIdx] = updatedCard;

        final newReadyMap = Map<String, bool>.from(currentState.readyPlayers);
        newReadyMap[authorId] = true;
        
        transaction.update(roomRef, {
          'cards': newCards.map((c) => c.toMap()).toList(),
          'readyPlayers': newReadyMap,
        });

        final playersSnap = await roomRef.collection('players').get();
        final players = playersSnap.docs.map((doc) => PlayerState.fromMap(doc.data(), doc.id)).toList();
        final activePlayers = players.where((p) => p.role != PlayerRole.spectator).toList();
        print('DEBUG submitAnswer: activePlayers=${activePlayers.map((p) => p.id)}, newReadyMap=$newReadyMap');
        bool allReady = activePlayers.every((p) => newReadyMap[p.id] == true);
        print('DEBUG submitAnswer: allReady=$allReady');
        if (allReady && activePlayers.isNotEmpty) {
          await advancePhaseInternal(transaction, roomRef, currentState.copyWith(cards: newCards, readyPlayers: newReadyMap), players, 'submitAnswer');
        }
      });

      return FakeHttpsCallableResult({'success': true} as T);
    }

    if (name == 'castVote') {
      final targetCardId = params['targetCardId'];
      final voterId = params['voterId'];
      final votedForId = params['votedForId'];

      if (votedForId == 'trigger_error') {
        throw FirebaseFunctionsException(
          message: 'Mock vote error triggered!',
          code: 'invalid-argument',
        );
      }

      final roomRef = db.collection('rooms').doc(roomCode);
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        final currentState = GameState.fromMap(snapshot.data()!, snapshot.id);
        
        final cardIdx = currentState.cards.indexWhere((c) => c.targetPlayerId == targetCardId);
        final card = currentState.cards[cardIdx];
        final newVotes = Map<String, String>.from(card.votes);
        newVotes[voterId] = votedForId;
        
        final updatedCard = card.copyWith(votes: newVotes);
        final newCards = List<CardModel>.from(currentState.cards);
        newCards[cardIdx] = updatedCard;

        final newReadyMap = Map<String, bool>.from(currentState.readyPlayers);
        newReadyMap[voterId] = true;
        
        transaction.update(roomRef, {
          'cards': newCards.map((c) => c.toMap()).toList(),
          'readyPlayers': newReadyMap,
        });

        final playersSnap = await roomRef.collection('players').get();
        final players = playersSnap.docs.map((doc) => PlayerState.fromMap(doc.data(), doc.id)).toList();
        final activePlayers = players.where((p) => p.role != PlayerRole.spectator).toList();
        bool allReady = activePlayers.every((p) => newReadyMap[p.id] == true);
        print('DEBUG castVote: allReady=$allReady');
        if (allReady && activePlayers.isNotEmpty) {
          await advancePhaseInternal(transaction, roomRef, currentState.copyWith(cards: newCards, readyPlayers: newReadyMap), players, 'castVote');
        }
      });

      return FakeHttpsCallableResult({'success': true} as T);
    }

    if (name == 'setReady') {
      final playerId = params['playerId'];
      final ready = params['ready'];

      if (playerId == 'trigger_error') {
        throw FirebaseFunctionsException(
          message: 'Mock ready error triggered!',
          code: 'invalid-argument',
        );
      }

      final roomRef = db.collection('rooms').doc(roomCode);
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        final currentState = GameState.fromMap(snapshot.data()!, snapshot.id);

        final newReadyMap = Map<String, bool>.from(currentState.readyPlayers);
        newReadyMap[playerId] = ready;
        
        transaction.update(roomRef, {'readyPlayers': newReadyMap});

        final playersSnap = await roomRef.collection('players').get();
        final players = playersSnap.docs.map((doc) => PlayerState.fromMap(doc.data(), doc.id)).toList();
        final activePlayers = players.where((p) => p.role != PlayerRole.spectator).toList();
        print('DEBUG setReady: activePlayers=${activePlayers.map((p) => p.id)}, newReadyMap=$newReadyMap');
        bool allReady = activePlayers.every((p) => newReadyMap[p.id] == true);
        print('DEBUG setReady: allReady=$allReady');
        if (allReady && activePlayers.isNotEmpty) {
          await advancePhaseInternal(transaction, roomRef, currentState.copyWith(readyPlayers: newReadyMap), players, 'setReady');
        }
      });

      return FakeHttpsCallableResult({'success': true} as T);
    }

    if (name == 'advancePhase') {
      final roomRef = db.collection('rooms').doc(roomCode);
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        final currentState = GameState.fromMap(snapshot.data()!, snapshot.id);
        final playersSnap = await roomRef.collection('players').get();
        final players = playersSnap.docs.map((doc) => PlayerState.fromMap(doc.data(), doc.id)).toList();

        await advancePhaseInternal(transaction, roomRef, currentState, players, 'advancePhase');
      });

      return FakeHttpsCallableResult({'success': true} as T);
    }

    if (name == 'advanceToNextResolution') {
      final roomRef = db.collection('rooms').doc(roomCode);
      final snapshot = await roomRef.get();
      final currentState = GameState.fromMap(snapshot.data()!, snapshot.id);

      final order = currentState.resolutionOrder;
      final currentIdx = order.indexOf(currentState.currentReaderId ?? '');
      
      if (currentIdx != -1 && currentIdx < order.length - 1) {
        await roomRef.update(currentState.copyWith(
          currentPhase: GamePhase.vote,
          currentReaderId: order[currentIdx + 1],
          readyPlayers: {},
        ).toMap());
      } else {
        await roomRef.update(currentState.copyWith(
          currentPhase: GamePhase.gameOver,
        ).toMap());
      }

      return FakeHttpsCallableResult({'success': true} as T);
    }

    if (name == 'updateLobbySettings') {
      final sabotageAnswersCount = params['sabotageAnswersCount'];
      final isTimerDisabled = params['isTimerDisabled'];

      final roomRef = db.collection('rooms').doc(roomCode);
      final snapshot = await roomRef.get();
      final currentState = GameState.fromMap(snapshot.data()!, snapshot.id);

      await roomRef.update(currentState.copyWith(
        sabotageAnswersCount: sabotageAnswersCount ?? currentState.sabotageAnswersCount,
        isTimerDisabled: isTimerDisabled ?? currentState.isTimerDisabled,
      ).toMap());

      return FakeHttpsCallableResult({'success': true} as T);
    }

    if (name == 'rerollPrompt') {
      final playerId = params['playerId'];

      final roomRef = db.collection('rooms').doc(roomCode);
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        final currentState = GameState.fromMap(snapshot.data()!, snapshot.id);

        final playerSnap = await transaction.get(roomRef.collection('players').doc(playerId));
        final player = PlayerState.fromMap(playerSnap.data()!, playerSnap.id);

        if (player.hasRerolled) {
          throw Exception("Prompt already re-rolled once this game.");
        }

        final cards = List<CardModel>.from(currentState.cards);
        final cardIndex = cards.indexWhere((c) => c.targetPlayerId == playerId);
        final oldCard = cards[cardIndex];

        final deckId = currentState.selectedDeckId;
        final currentPrompts = cards.map((c) => c.promptText).toSet();
        final newPromptText = PromptDecks.drawOneExcluding(deckId, currentPrompts);

        cards[cardIndex] = oldCard.copyWith(promptText: newPromptText);

        transaction.update(roomRef, {'cards': cards.map((c) => c.toMap()).toList()});
        transaction.update(roomRef.collection('players').doc(playerId), {'hasRerolled': true});
      });

      return FakeHttpsCallableResult({'success': true} as T);
    }

    if (name == 'handleDisconnect') {
      final disconnectedPlayerId = params['disconnectedPlayerId'];

      final roomRef = db.collection('rooms').doc(roomCode);
      final playersSnap = await roomRef.collection('players').get();
      final players = playersSnap.docs.map((doc) => PlayerState.fromMap(doc.data(), doc.id)).toList();

      final snapshot = await roomRef.get();
      final state = GameState.fromMap(snapshot.data()!, snapshot.id);

      PlayerState? disconnectedPlayer;
      for (var p in players) {
        if (p.id == disconnectedPlayerId) {
          disconnectedPlayer = p;
          break;
        }
      }

      await roomRef.collection('players').doc(disconnectedPlayerId).delete();

      final remaining = players.where((p) => p.id != disconnectedPlayerId).toList();
      final remainingActive = remaining.where((p) => p.role != PlayerRole.spectator).toList();

      if (disconnectedPlayer != null && disconnectedPlayer.isHost && remainingActive.isNotEmpty) {
        remainingActive.sort((a, b) {
          final aTime = a.joinedAt ?? 0;
          final bTime = b.joinedAt ?? 0;
          if (aTime != bTime) return aTime.compareTo(bTime);
          return a.id.compareTo(b.id);
        });
        await roomRef.collection('players').doc(remainingActive.first.id).update({'isHost': true});
      }

      if (!state.cards.any((c) => c.targetPlayerId == disconnectedPlayerId)) {
        return FakeHttpsCallableResult({'success': true} as T);
      }

      final updatedCards = state.cards.where((c) => c.targetPlayerId != disconnectedPlayerId).toList();
      final newReadyPlayers = Map<String, bool>.from(state.readyPlayers)..remove(disconnectedPlayerId);
      final newResolutionOrder = List<String>.from(state.resolutionOrder)..remove(disconnectedPlayerId);
      
      GameState nextState = state.copyWith(
        cards: updatedCards,
        totalPlayers: players.where((p) => p.id != disconnectedPlayerId && p.role != PlayerRole.spectator).length,
        readyPlayers: newReadyPlayers,
        resolutionOrder: newResolutionOrder,
      );

      final phase = state.currentPhase;
      if (phase == GamePhase.forgery) {
        final assignments = Map<String, String>.from(state.currentCardAssignments);
        String? holderOfDisconnected;
        assignments.forEach((holder, target) {
          if (target == disconnectedPlayerId) holderOfDisconnected = holder;
        });
        final targetOfDisconnected = assignments[disconnectedPlayerId];
        assignments.remove(disconnectedPlayerId);
        if (holderOfDisconnected != null && targetOfDisconnected != null) {
          assignments[holderOfDisconnected!] = targetOfDisconnected;
        }

        final activePlayerIds = players
            .where((p) => p.id != disconnectedPlayerId && p.role != PlayerRole.spectator)
            .map((p) => p.id)
            .toList();
            
        int remainingRotations = state.sabotageAnswersCount;
        if (activePlayerIds.length <= remainingRotations) {
          remainingRotations = activePlayerIds.length - 1;
        }
        
        if (remainingRotations <= 0 || state.currentRotationIndex > remainingRotations) {
          final pIds = activePlayerIds;
          Map<String, String> truthAssignments = { for (var id in pIds) id : id };
          nextState = nextState.copyWith(
            currentPhase: GamePhase.truth,
            currentCardAssignments: truthAssignments,
            sabotageAnswersCount: 0,
            currentRotationIndex: 0,
          );
        } else {
          final newRotations = RotationEngine.generateRotations(activePlayerIds, remainingRotations);
          Map<String, Map<String, String>> stringRotations = {};
          newRotations.forEach((key, val) => stringRotations[key.toString()] = val);
          
          nextState = nextState.copyWith(
            currentCardAssignments: assignments,
            rotationPlan: stringRotations,
            sabotageAnswersCount: remainingRotations,
          );
        }
      } else if (phase == GamePhase.truth) {
        final assignments = Map<String, String>.from(state.currentCardAssignments)..remove(disconnectedPlayerId);
        nextState = nextState.copyWith(currentCardAssignments: assignments);
      } else if (phase == GamePhase.vote || phase == GamePhase.reveal) {
        if (state.currentReaderId == disconnectedPlayerId) {
          if (newResolutionOrder.isNotEmpty) {
            final originalIdx = state.resolutionOrder.indexOf(disconnectedPlayerId);
            if (originalIdx != -1 && originalIdx < newResolutionOrder.length) {
              nextState = nextState.copyWith(currentReaderId: newResolutionOrder[originalIdx]);
            } else {
              nextState = nextState.copyWith(currentReaderId: newResolutionOrder.first);
            }
          } else {
            nextState = nextState.copyWith(currentPhase: GamePhase.gameOver);
          }
        }
      }

      await roomRef.update(nextState.toMap());
      return FakeHttpsCallableResult({'success': true} as T);
    }

    if (name == 'debugAddBots') {
      final generatedCode = roomCode;
      final roomRef = db.collection('rooms').doc(generatedCode);
      final roomSnap = await roomRef.get();
      if (!roomSnap.exists) {
        throw Exception("Room not found");
      }

      const botColors = [
        0xFF58A6FF, 0xFFFF7B72, 0xFF7EE787, 0xFFA5D6FF, 0xFFFFE68C,
        0xFFD3A4FF, 0xFFFF80BF, 0xFF79C0FF, 0xFFFF935A, 0xFF85EA2D
      ];

      final batch = db.batch();
      for (int i = 1; i <= 9; i++) {
        final botId = 'bot_$i';
        final bot = PlayerState(
          id: botId,
          name: 'Bot $i',
          isHost: false,
          colorValue: botColors[i % botColors.length],
          avatarIndex: i % 6,
          joinedAt: DateTime.now().millisecondsSinceEpoch + i,
        );
        final ref = db.collection('rooms').doc(generatedCode).collection('players').doc(botId);
        batch.set(ref, bot.toMap());
      }
      await batch.commit();

      return FakeHttpsCallableResult({'success': true} as T);
    }

    if (name == 'debugSimulateBotResponses') {
      final roomRef = db.collection('rooms').doc(roomCode);
      await db.runTransaction((transaction) async {
        final snap = await transaction.get(roomRef);
        if (!snap.exists) return;
        final currentState = GameState.fromMap(snap.data()!, snap.id);
        final playersSnap = await roomRef.collection('players').get();
        final players = playersSnap.docs.map((doc) => PlayerState.fromMap(doc.data(), doc.id)).toList();

        final phase = currentState.currentPhase;
        final newCards = List<CardModel>.from(currentState.cards);
        final newReadyMap = Map<String, bool>.from(currentState.readyPlayers);

        if (phase == GamePhase.forgery || phase == GamePhase.truth) {
          for (var p in players) {
            if (!p.id.startsWith('bot_')) continue;
            
            newReadyMap[p.id] = true;

            final targetId = currentState.currentCardAssignments[p.id];
            if (targetId != null) {
              final cardIdx = newCards.indexWhere((c) => c.targetPlayerId == targetId);
              if (cardIdx != -1) {
                final card = newCards[cardIdx];
                if (phase == GamePhase.truth) {
                  newCards[cardIdx] = card.copyWith(truthAnswer: 'Simulated Answer from ${p.name}');
                } else {
                  final sabs = Map<String, String>.from(card.sabotageAnswers);
                  sabs[p.id] = 'Simulated Answer from ${p.name}';
                  newCards[cardIdx] = card.copyWith(sabotageAnswers: sabs);
                }
              }
            }

            // Also update player document in transaction to make it ready
            final pRef = roomRef.collection('players').doc(p.id);
            transaction.update(pRef, {'isReady': true});
          }

          transaction.update(roomRef, {
            'cards': newCards.map((c) => c.toMap()).toList(),
            'readyPlayers': newReadyMap,
          });
        } else if (phase == GamePhase.vote) {
          final currentTargetId = currentState.currentReaderId;
          if (currentTargetId != null) {
            final cardIdx = newCards.indexWhere((c) => c.targetPlayerId == currentTargetId);
            if (cardIdx != -1) {
              final card = newCards[cardIdx];
              final newVotes = Map<String, String>.from(card.votes);

              for (var p in players) {
                if (!p.id.startsWith('bot_')) continue;

                newReadyMap[p.id] = true;
                if (currentTargetId != p.id) {
                  newVotes[p.id] = 'TRUTH';
                }
              }
              newCards[cardIdx] = card.copyWith(votes: newVotes);
            }

            if (currentTargetId.startsWith('bot_')) {
              newReadyMap[currentTargetId] = true;
              final readerRef = roomRef.collection('players').doc(currentTargetId);
              transaction.update(readerRef, {'isReady': true});
            }

            transaction.update(roomRef, {
              'cards': newCards.map((c) => c.toMap()).toList(),
              'readyPlayers': newReadyMap,
            });
          }
        }
      });

      return FakeHttpsCallableResult({'success': true} as T);
    }

    throw UnimplementedError('Callable mock handler not found: $name');
  }

  Future<void> advancePhaseInternal(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> roomRef,
    GameState state,
    List<PlayerState> players,
    String caller,
  ) async {
    final activePlayers = players.where((p) => p.role != PlayerRole.spectator).toList();
    print('DEBUG advancePhaseInternal (caller=$caller): phase=${state.currentPhase}, activePlayers=${activePlayers.map((p) => p.id)}, readyPlayers=${state.readyPlayers}');
    GameState nextState = state.copyWith(readyPlayers: {});

    if (state.currentPhase == GamePhase.forgery) {
      final nextCards = nextState.cards.map((card) {
        String? holderId;
        state.currentCardAssignments.forEach((hId, tId) {
          if (tId == card.targetPlayerId) holderId = hId;
        });
        if (holderId != null) {
          final isSpectator = players.any((p) => p.id == holderId && p.role == PlayerRole.spectator);
          if (!isSpectator) {
            final answer = card.sabotageAnswers[holderId];
            if (answer == null || answer.trim().isEmpty) {
              final newSabotage = Map<String, String>.from(card.sabotageAnswers);
              newSabotage[holderId!] = 'THE SOUL IS SILENT';
              return card.copyWith(sabotageAnswers: newSabotage);
            }
          }
        }
        return card;
      }).toList();
      nextState = nextState.copyWith(cards: nextCards);

      if (state.currentRotationIndex < state.sabotageAnswersCount) {
        int nextRot = state.currentRotationIndex + 1;
        Map<String, String> nextAssignments = state.rotationPlan[nextRot.toString()]!;
        nextState = nextState.copyWith(
          currentRotationIndex: nextRot,
          currentCardAssignments: nextAssignments,
        );
      } else {
        var pIds = activePlayers.map((p) => p.id).toList();
        Map<String, String> truthAssignments = { for (var id in pIds) id : id };
        nextState = nextState.copyWith(
          currentPhase: GamePhase.truth,
          currentCardAssignments: truthAssignments,
        );
      }
    } else if (state.currentPhase == GamePhase.truth) {
      final nextCards = nextState.cards.map((card) {
        final isSpectator = players.any((p) => p.id == card.targetPlayerId && p.role == PlayerRole.spectator);
        if (!isSpectator) {
          if (card.truthAnswer.trim().isEmpty) {
            return card.copyWith(truthAnswer: 'THE SOUL IS SILENT');
          }
        }
        return card;
      }).toList();
      nextState = nextState.copyWith(cards: nextCards);

      var pIds = activePlayers.map((p) => p.id).toList();
      pIds.shuffle(Random());
      nextState = nextState.copyWith(
        currentPhase: GamePhase.vote,
        currentReaderId: pIds.isNotEmpty ? pIds.first : null,
        resolutionOrder: pIds,
      );
    } else if (state.currentPhase == GamePhase.vote) {
      final currentCard = state.cards.firstWhere((c) => c.targetPlayerId == state.currentReaderId);
      final deltas = ScoringLogic.calculateScores(
        state: state,
        currentCard: currentCard,
        playerVotes: Map<String, String>.from(currentCard.votes),
      );

      final timesFooledDeltas = <String, int>{};
      final playersDeceivedDeltas = <String, int>{};
      currentCard.votes.forEach((voterId, votedForId) {
        if (votedForId != 'TRUTH' && votedForId != voterId) {
          timesFooledDeltas[voterId] = (timesFooledDeltas[voterId] ?? 0) + 1;
          playersDeceivedDeltas[votedForId] = (playersDeceivedDeltas[votedForId] ?? 0) + 1;
        }
      });

      for (var p in activePlayers) {
        final sDelta = deltas[p.id] ?? 0;
        final tfDelta = timesFooledDeltas[p.id] ?? 0;
        final pdDelta = playersDeceivedDeltas[p.id] ?? 0;
        if (sDelta != 0 || tfDelta != 0 || pdDelta != 0) {
          final pRef = roomRef.collection('players').doc(p.id);
          transaction.update(pRef, {
            'totalScore': p.totalScore + sDelta,
            'timesFooled': p.timesFooled + tfDelta,
            'playersDeceived': p.playersDeceived + pdDelta,
          });
        }
      }

      nextState = nextState.copyWith(
        currentPhase: GamePhase.reveal,
      );
    }

    transaction.update(roomRef, nextState.toMap());
  }
}
