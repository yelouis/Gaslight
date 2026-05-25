import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_state.dart';
import '../models/player_state.dart';
import 'dart:math';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/prompt_decks.dart';
import '../utils/rotation_engine.dart';
import '../models/card_model.dart';
import '../utils/scoring_logic.dart';
import '../utils/semantic_filter.dart';

class GameService extends ChangeNotifier {
  final FirebaseFirestore _db;
  
  GameService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;
  
  GameState? _gameState;
  List<PlayerState> _players = [];
  String? _currentPlayerId;

  // Cleanup and Heartbeat
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _playersSubscription;
  Timer? _heartbeatTimer;

  // Duplicate-advance guards
  final Set<String> _advancedStateKeys = {};

  GameState? get gameState => _gameState;
  List<PlayerState> get players => _players;
  String? get currentPlayerId => _currentPlayerId;

  PlayerState? get currentPlayer {
    try {
      return _players.firstWhere((p) => p.id == _currentPlayerId);
    } catch (_) {
      return null;
    }
  }

  String _currentStateKey() {
    final state = _gameState;
    if (state == null) return '';
    return '${state.roomCode}_${state.currentPhase.name}_${state.currentRotationIndex}_${state.currentReaderId}';
  }

  // Gem colors for dark fantasy poker chips
  static const List<int> _playerColors = [
    0xFFB71C1C, // Ruby
    0xFF0D47A1, // Sapphire
    0xFF1B5E20, // Emerald
    0xFF4A148C, // Amethyst
    0xFFE65100, // Topaz
    0xFF006064, // Turquoise
    0xFF880E4F, // Garnet
    0xFF3E2723, // Obsidian
    0xFFFBC02D, // Gold/Amber
    0xFF795548, // Bronze
    0xFF455A64, // Iron/Steel
    0xFF607D8B, // Silver
  ];

  // Generate 4 letter room code
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    var rng = Random();
    return String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rng.nextInt(chars.length))));
  }

  int _getRandomColor() {
    final rng = Random();
    // Try to pick a color not already used if possible
    final usedColors = _players.map((p) => p.colorValue).toSet();
    final available = _playerColors.where((c) => !usedColors.contains(c)).toList();
    if (available.isNotEmpty) {
      return available[rng.nextInt(available.length)];
    }
    return _playerColors[rng.nextInt(_playerColors.length)];
  }

  int _getRandomAvatar() {
    return Random().nextInt(6); // 6 different icon types
  }

  Future<void> createRoom(String playerName, String playerId, {int totalPlayers = 4, int sabotageAnswersCount = 2, int? avatarIndex, bool isTimerDisabled = false}) async {
    final roomCode = _generateRoomCode();
    _currentPlayerId = playerId;
    print('DEBUG: createRoom playerId = $playerId');
    String? authUid;
    try {
      authUid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}
    print('DEBUG: FirebaseAuth UID = $authUid');

    final initialState = GameState(
      roomCode: roomCode, 
      totalPlayers: totalPlayers,
      sabotageAnswersCount: sabotageAnswersCount,
      isTimerDisabled: isTimerDisabled,
    );
    final initialPlayer = PlayerState(
      id: playerId,
      name: playerName,
      isHost: true,
      colorValue: _getRandomColor(),
      avatarIndex: avatarIndex ?? _getRandomAvatar(),
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );

    await _db.collection('rooms').doc(roomCode).set(initialState.toMap());
    await _db.collection('rooms').doc(roomCode).collection('players').doc(playerId).set(initialPlayer.toMap());
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('room_code', roomCode);
    await prefs.setString('player_id', playerId);

    listenToRoom(roomCode);
  }

  Future<void> joinRoom(String roomCode, String playerName, String playerId, {int? avatarIndex}) async {
    final doc = await _db.collection('rooms').doc(roomCode).get();
    if (!doc.exists) throw Exception('Room not found');

    final roomState = GameState.fromMap(doc.data()!, doc.id);
    final isSpectator = roomState.currentPhase != GamePhase.lobby;

    _currentPlayerId = playerId;
    
    // In order to pick a unique color, we need the current players, but we haven't listened yet
    final playersSnap = await _db.collection('rooms').doc(roomCode).collection('players').get();
    final existingColors = playersSnap.docs.map((d) => d.data()['colorValue'] as int? ?? 0).toSet();
    final available = _playerColors.where((c) => !existingColors.contains(c)).toList();
    
    final int selectedColor = available.isNotEmpty 
        ? available[Random().nextInt(available.length)] 
        : _playerColors[Random().nextInt(_playerColors.length)];

    final newPlayer = PlayerState(
      id: playerId,
      name: playerName,
      colorValue: selectedColor,
      avatarIndex: avatarIndex ?? _getRandomAvatar(),
      lastSeen: DateTime.now().millisecondsSinceEpoch,
      role: isSpectator ? PlayerRole.spectator : PlayerRole.unassigned,
    );

    await _db.collection('rooms').doc(roomCode).collection('players').doc(playerId).set(newPlayer.toMap());
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('room_code', roomCode);
    await prefs.setString('player_id', playerId);

    listenToRoom(roomCode);
  }

  Future<bool> tryRejoinSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRoom = prefs.getString('room_code');
      final savedPlayerId = prefs.getString('player_id');
      if (savedRoom != null && savedPlayerId != null) {
        final roomDoc = await _db.collection('rooms').doc(savedRoom).get();
        final playerDoc = await _db.collection('rooms').doc(savedRoom).collection('players').doc(savedPlayerId).get();
        if (roomDoc.exists && playerDoc.exists) {
          _currentPlayerId = savedPlayerId;
          _gameState = GameState.fromMap(roomDoc.data()!, roomDoc.id);
          listenToRoom(savedRoom);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error rejoining session: $e');
    }
    return false;
  }

  void _startHeartbeat(String roomCode, String playerId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_gameState == null) {
        timer.cancel();
        return;
      }
      try {
        await _db.collection('rooms').doc(roomCode).collection('players').doc(playerId).update({
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (_) {}
    });
  }

  Future<void> leaveRoom() async {
    final roomCode = _gameState?.roomCode;
    final playerId = _currentPlayerId;

    _roomSubscription?.cancel();
    _playersSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _roomSubscription = null;
    _playersSubscription = null;
    _heartbeatTimer = null;

    if (roomCode != null && playerId != null) {
      try {
        await _db.collection('rooms').doc(roomCode).collection('players').doc(playerId).delete();

        final playersSnap = await _db.collection('rooms').doc(roomCode).collection('players').get();
        if (playersSnap.docs.isEmpty) {
          await _db.collection('rooms').doc(roomCode).delete();
        }
      } catch (e) {
        debugPrint('Error cleaning up Firestore on leave: $e');
      }
    }

    _gameState = null;
    _players = [];
    _currentPlayerId = null;
    _advancedStateKeys.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('room_code');
    await prefs.remove('player_id');

    notifyListeners();
  }

  void listenToRoom(String roomCode) {
    _roomSubscription?.cancel();
    _playersSubscription?.cancel();
    _heartbeatTimer?.cancel();

    if (_currentPlayerId != null) {
      _startHeartbeat(roomCode, _currentPlayerId!);
    }

    // Listen to Game State
    _roomSubscription = _db.collection('rooms').doc(roomCode).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        _gameState = GameState.fromMap(snapshot.data()!, snapshot.id);
        notifyListeners();
      }
    });

    // Listen to Players
    _playersSubscription = _db.collection('rooms').doc(roomCode).collection('players').snapshots().listen((snapshot) {
      _players = snapshot.docs.map((doc) => PlayerState.fromMap(doc.data(), doc.id)).toList();
      
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Clean up inactive/dead players (30 seconds threshold)
      final deadPlayers = _players.where((p) {
        if (p.id == _currentPlayerId) return false;
        final lastSeen = p.lastSeen;
        if (lastSeen == null) return false;
        return (now - lastSeen) > 30000;
      }).toList();

      for (var dp in deadPlayers) {
        _db.collection('rooms').doc(roomCode).collection('players').doc(dp.id).delete().catchError((_) {});
      }

      // HOST TRANSFER LOGIC: If no host exists, promote the first player
      if (_players.isNotEmpty && !_players.any((p) => p.isHost)) {
        final newHost = _players.first;
        updatePlayerState(roomCode, newHost.copyWith(isHost: true));
      }
      
      notifyListeners();
      
      // If Host, evaluate ready state whenever players update (e.g. someone joins/leaves/marks ready)
      if (currentPlayer?.isHost == true) {
        evaluateReadyState();

        // Disconnect detection: compare actual active players to cards in gameState
        if (_gameState != null && 
            _gameState!.currentPhase != GamePhase.lobby && 
            _gameState!.currentPhase != GamePhase.gameOver) {
          final activeIds = _players.map((p) => p.id).toSet();
          final cardIds = _gameState!.cards.map((c) => c.targetPlayerId).toSet();
          final disconnected = cardIds.difference(activeIds);
          for (var dpId in disconnected) {
            handlePlayerDisconnect(dpId);
          }
        }
      }
    });
  }

  Future<void> updateGameState(GameState state) async {
    if (state.roomCode.isEmpty) return;
    await _db.collection('rooms').doc(state.roomCode).update(state.toMap());
  }

  Future<void> updatePlayerState(String roomCode, PlayerState player) async {
    await _db.collection('rooms').doc(roomCode).collection('players').doc(player.id).set(player.toMap(), SetOptions(merge: true));
  }

  Future<void> handlePlayerDisconnect(String disconnectedPlayerId) async {
    if (_gameState == null || currentPlayer?.isHost != true) return;
    
    final state = _gameState!;
    final phase = state.currentPhase;
    
    // 1. Remove the disconnected player's card from the list
    final updatedCards = state.cards.where((c) => c.targetPlayerId != disconnectedPlayerId).toList();
    
    // 2. Adjust ready players map
    final newReadyPlayers = Map<String, bool>.from(state.readyPlayers)..remove(disconnectedPlayerId);
    
    GameState nextState = state.copyWith(
      cards: updatedCards,
      totalPlayers: _players.where((p) => p.role != PlayerRole.spectator).length,
      readyPlayers: newReadyPlayers,
    );
    
    // 3. Phase-specific adjustments
    if (phase == GamePhase.forgery) {
      final assignments = Map<String, String>.from(state.currentCardAssignments);
      
      String? holderOfDisconnected;
      assignments.forEach((holder, target) {
        if (target == disconnectedPlayerId) {
          holderOfDisconnected = holder;
        }
      });
      
      final targetOfDisconnected = assignments[disconnectedPlayerId];
      assignments.remove(disconnectedPlayerId);
      
      if (holderOfDisconnected != null && targetOfDisconnected != null) {
        assignments[holderOfDisconnected!] = targetOfDisconnected;
      }
      
      final activePlayerIds = _players
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
          endTime: state.isTimerDisabled ? null : DateTime.now().add(const Duration(seconds: 60)).millisecondsSinceEpoch,
          clearEndTime: state.isTimerDisabled,
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
        final activePlayerIds = _players
            .where((p) => p.id != disconnectedPlayerId && p.role != PlayerRole.spectator)
            .map((p) => p.id)
            .toList();
        if (activePlayerIds.isNotEmpty) {
          nextState = nextState.copyWith(currentReaderId: activePlayerIds.first);
        } else {
          nextState = nextState.copyWith(currentPhase: GamePhase.gameOver);
        }
      }
    }
    
    await updateGameState(nextState);
  }

  /// Atomically updates scores for all players in a room.
  /// Resolves the 'Sequential Write' bottleneck identified for 10-player games.
  Future<void> applyScoreDeltas(String roomCode, Map<String, int> deltas) async {
    final batch = _db.batch();
    for (var p in _players) {
      final delta = deltas[p.id] ?? 0;
      if (delta != 0) {
        final ref = _db.collection('rooms').doc(roomCode).collection('players').doc(p.id);
        batch.update(ref, {'totalScore': p.totalScore + delta});
      }
    }
    await batch.commit();
  }

  // --- PHASE 2: ROTATION ENGINE & GAME LOOP ---
  
  Future<void> submitCardAnswer(String targetCardId, String authorId, String text, bool isTruth) async {
    if (_gameState == null) return;
    
    final roomRef = _db.collection('rooms').doc(_gameState!.roomCode);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;
      
      final data = snapshot.data()!;
      final currentState = GameState.fromMap(data, snapshot.id);
      
      final cardIdx = currentState.cards.indexWhere((c) => c.targetPlayerId == targetCardId);
      if (cardIdx == -1) return;
      
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
      
      transaction.update(roomRef, {
         'cards': newCards.map((c) => c.toMap()).toList()
      });
    });
  }

  Future<void> castVote(String targetCardId, String voterId, String votedForId) async {
    if (_gameState == null) return;
    
    final roomRef = _db.collection('rooms').doc(_gameState!.roomCode);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;
      
      final data = snapshot.data()!;
      final currentState = GameState.fromMap(data, snapshot.id);
      
      final cardIdx = currentState.cards.indexWhere((c) => c.targetPlayerId == targetCardId);
      if (cardIdx == -1) return;
      
      final card = currentState.cards[cardIdx];
      final newVotes = Map<String, String>.from(card.votes);
      newVotes[voterId] = votedForId;
      
      final updatedCard = card.copyWith(votes: newVotes);
      final newCards = List<CardModel>.from(currentState.cards);
      newCards[cardIdx] = updatedCard;
      
      transaction.update(roomRef, {
         'cards': newCards.map((c) => c.toMap()).toList()
      });
    });
    
    await setPlayerReady(true, playerId: voterId);
  }

  // --- PHASE 2: ROTATION ENGINE & GAME LOOP ---

  Future<void> startGame(String deckId) async {
    if (_gameState == null || _players.length < 2) return;
    
    if (_players.length <= _gameState!.sabotageAnswersCount) {
        throw Exception("Cannot start: Need more players than sabotage rounds.");
    }

    // 0. Maintenance
    SemanticFilter.clearCache();
    
    // 1. Calculate mathematical rotations across S derivations securely natively.
    var pIds = _players.map((p) => p.id).toList();
    var nativeRotations = RotationEngine.generateRotations(pIds, _gameState!.sabotageAnswersCount);
    Map<String, Map<String, String>> stringRotations = {};
    nativeRotations.forEach((key, val) => stringRotations[key.toString()] = val);

    // 2. Draw Cards dynamically based on player count
    var prompts = PromptDecks.drawPrompts(deckId, _players.length);
    List<CardModel> startingCards = [];
    for (int i = 0; i < pIds.length; i++) {
        startingCards.add(CardModel(
           targetPlayerId: pIds[i],
           promptText: prompts[i]
        ));
    }

    // 3. Initiate first rotation
    int startIdx = 1;
    Map<String, String> initAssignments = stringRotations[startIdx.toString()]!;

    // Set end time for forgery phase (60 seconds)
    final endTime = _gameState!.isTimerDisabled ? null : DateTime.now().add(const Duration(seconds: 60)).millisecondsSinceEpoch;

    await updateGameState(_gameState!.copyWith(
        currentPhase: GamePhase.forgery,
        totalPlayers: _players.length, // FIX: Sync totalPlayers
        currentRotationIndex: startIdx,
        cards: startingCards,
        currentCardAssignments: initAssignments,
        rotationPlan: stringRotations,
        readyPlayers: {}, // FIX: Reset readyPlayers in same write
        endTime: endTime,
        clearEndTime: _gameState!.isTimerDisabled,
    ));
  }
  
  Future<void> setPlayerReady(bool ready, {String? playerId}) async {
    final targetId = playerId ?? _currentPlayerId;
    if (_gameState == null || targetId == null) return;
    
    final roomRef = _db.collection('rooms').doc(_gameState!.roomCode);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;
      
      final data = snapshot.data()!;
      final currentState = GameState.fromMap(data, snapshot.id);
      
      final newReadyMap = Map<String, bool>.from(currentState.readyPlayers);
      newReadyMap[targetId] = ready;
      
      transaction.update(roomRef, {'readyPlayers': newReadyMap});
    });
  }

  Future<void> evaluateReadyState() async {
    if (_gameState == null) return;
    
    // Triggered often by listeners. If Host, evaluate.
    if (currentPlayer?.isHost != true) return;
    
    final phase = _gameState!.currentPhase;
    if (phase != GamePhase.forgery && phase != GamePhase.truth && phase != GamePhase.vote) {
      return;
    }

    final key = _currentStateKey();
    if (_advancedStateKeys.contains(key)) return;
    
    final activePlayers = _players.where((p) => p.role != PlayerRole.spectator).toList();
    bool allReady = activePlayers.every((p) => _gameState!.readyPlayers[p.id] == true);
    
    if (allReady && activePlayers.isNotEmpty) {
       _advancedStateKeys.add(key);
       await _advanceRotationOrPhase();
    }
  }

  Future<void> forceAdvance() async {
    if (_gameState == null || currentPlayer?.isHost != true) return;
    final key = _currentStateKey();
    if (_advancedStateKeys.contains(key)) return;
    _advancedStateKeys.add(key);
    await _advanceRotationOrPhase();
  }

  Future<void> _advanceRotationOrPhase() async {
    if (_gameState == null) return;

    GameState nextState = _gameState!.copyWith(readyPlayers: {});
    int forgeryDuration = 60;
    int truthDuration = 60;
    int voteDuration = 45;

    if (_gameState!.currentPhase == GamePhase.forgery) {
        if (_gameState!.currentRotationIndex < _gameState!.sabotageAnswersCount) {
            int nextRot = _gameState!.currentRotationIndex + 1;
            Map<String, String> nextAssignments = _gameState!.rotationPlan[nextRot.toString()]!;
            nextState = nextState.copyWith(
                currentRotationIndex: nextRot,
                currentCardAssignments: nextAssignments,
                endTime: _gameState!.isTimerDisabled ? null : DateTime.now().add(Duration(seconds: forgeryDuration)).millisecondsSinceEpoch,
                clearEndTime: _gameState!.isTimerDisabled,
            );
        } else {
            // Transition to Truth Phase: Every player gets their own card back
            var pIds = _players.where((p) => p.role != PlayerRole.spectator).map((p) => p.id).toList();
            Map<String, String> truthAssignments = { for (var id in pIds) id : id };
            
            nextState = nextState.copyWith(
                currentPhase: GamePhase.truth,
                currentCardAssignments: truthAssignments,
                endTime: _gameState!.isTimerDisabled ? null : DateTime.now().add(Duration(seconds: truthDuration)).millisecondsSinceEpoch,
                clearEndTime: _gameState!.isTimerDisabled,
            );
        }
    } else if (_gameState!.currentPhase == GamePhase.truth) {
        // Transition to Vote Phase: First player is the reader
        var pIds = _players.where((p) => p.role != PlayerRole.spectator).map((p) => p.id).toList();
        nextState = nextState.copyWith(
            currentPhase: GamePhase.vote,
            currentReaderId: pIds.isNotEmpty ? pIds.first : null,
            endTime: _gameState!.isTimerDisabled ? null : DateTime.now().add(Duration(seconds: voteDuration)).millisecondsSinceEpoch,
            clearEndTime: _gameState!.isTimerDisabled,
        );
    } else if (_gameState!.currentPhase == GamePhase.vote) {
        // Transition to Reveal for the CURRENT reader
        // 1. Calculate and apply scores for the current resolved card
        final currentCard = _gameState!.cards.firstWhere((c) => c.targetPlayerId == _gameState!.currentReaderId);
        final deltas = ScoringLogic.calculateScores(state: _gameState!, currentCard: currentCard, playerVotes: currentCard.votes);
        await applyScoreDeltas(_gameState!.roomCode, deltas);

        // 2. Advance Phase
        nextState = nextState.copyWith(
            currentPhase: GamePhase.reveal,
            clearEndTime: true,
        );
    }
    
    await updateGameState(nextState);
  }

  Future<void> advanceToNextResolution() async {
    if (_gameState == null || currentPlayer?.isHost != true) return;
    
    final key = _currentStateKey();
    if (_advancedStateKeys.contains(key)) return;
    _advancedStateKeys.add(key);

    final pIds = _players.where((p) => p.role != PlayerRole.spectator).map((p) => p.id).toList();
    final currentIdx = pIds.indexOf(_gameState!.currentReaderId ?? '');
    
    if (currentIdx != -1 && currentIdx < pIds.length - 1) {
        // Move to next player's card
        await updateGameState(_gameState!.copyWith(
            currentPhase: GamePhase.vote,
            currentReaderId: pIds[currentIdx + 1],
            readyPlayers: {},
            endTime: _gameState!.isTimerDisabled ? null : DateTime.now().add(const Duration(seconds: 45)).millisecondsSinceEpoch,
            clearEndTime: _gameState!.isTimerDisabled,
        ));
    } else {
        // All cards resolved -> Game Over
        await _advanceToGameOver();
    }
  }

  Future<void> _advanceToGameOver() async {
    await updateGameState(_gameState!.copyWith(
        currentPhase: GamePhase.gameOver,
    ));
  }

  // --- SIMULATION HELPERS (DEBUG ONLY) ---

  /// Programmatically fills the lobby with 9 bots for E2E stress testing.
  Future<void> debugAddBots() async {
    if (_gameState == null) return;
    final rCode = _gameState!.roomCode;
    final batch = _db.batch();
    
    for (int i = 1; i <= 9; i++) {
        final botId = 'bot_$i';
        final bot = PlayerState(
          id: botId,
          name: 'Bot $i',
          isHost: false,
          colorValue: _getRandomColor(),
          avatarIndex: i % 6,
        );
        final ref = _db.collection('rooms').doc(rCode).collection('players').doc(botId);
        batch.set(ref, bot.toMap());
    }
    await batch.commit();
  }

  /// Auto-submits answers for all bots in the current phase.
  Future<void> debugSimulateBotResponses() async {
    if (_gameState == null) return;
    final state = _gameState!;
    final phase = state.currentPhase;
    final roomRef = _db.collection('rooms').doc(state.roomCode);

    if (phase == GamePhase.forgery || phase == GamePhase.truth) {
      // 1. Update all bot card answers and readyPlayers in a single transaction
      await _db.runTransaction((transaction) async {
        final snap = await transaction.get(roomRef);
        if (!snap.exists) return;
        final currentState = GameState.fromMap(snap.data()!, snap.id);
        final newCards = List<CardModel>.from(currentState.cards);
        final newReadyMap = Map<String, bool>.from(currentState.readyPlayers);

        for (var p in _players) {
          if (!p.id.startsWith('bot_')) continue;
          
          // Mark bot ready in the room document
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
        }
        transaction.update(roomRef, {
          'cards': newCards.map((c) => c.toMap()).toList(),
          'readyPlayers': newReadyMap,
        });
      });

      // 2. Set all bots to ready in a batch write for players collection
      final batch = _db.batch();
      for (var p in _players) {
        if (!p.id.startsWith('bot_')) continue;
        final pRef = _db.collection('rooms').doc(state.roomCode).collection('players').doc(p.id);
        batch.update(pRef, {'isReady': true});
      }
      await batch.commit();

    } else if (phase == GamePhase.vote) {
      final currentTargetId = state.currentReaderId!;

      // 1. Update all bot votes and readyPlayers in a single transaction
      await _db.runTransaction((transaction) async {
        final snap = await transaction.get(roomRef);
        if (!snap.exists) return;
        final currentState = GameState.fromMap(snap.data()!, snap.id);
        final newCards = List<CardModel>.from(currentState.cards);
        final newReadyMap = Map<String, bool>.from(currentState.readyPlayers);

        final cardIdx = newCards.indexWhere((c) => c.targetPlayerId == currentTargetId);
        if (cardIdx != -1) {
          final card = newCards[cardIdx];
          final newVotes = Map<String, String>.from(card.votes);

          for (var p in _players) {
            if (!p.id.startsWith('bot_')) continue;
            
            // Mark bot ready in the room document
            newReadyMap[p.id] = true;

            if (currentTargetId != p.id) {
              newVotes[p.id] = 'TRUTH';
            }
          }
          newCards[cardIdx] = card.copyWith(votes: newVotes);
        }
        
        // If the current reader is a bot, mark them ready as well
        if (currentTargetId.startsWith('bot_')) {
          newReadyMap[currentTargetId] = true;
        }

        transaction.update(roomRef, {
          'cards': newCards.map((c) => c.toMap()).toList(),
          'readyPlayers': newReadyMap,
        });
      });

      // 2. If the current reader/target is a bot, mark them ready in players collection
      if (currentTargetId.startsWith('bot_')) {
        await _db.collection('rooms').doc(state.roomCode).collection('players').doc(currentTargetId).update({
          'isReady': true,
        });
      }
    }
  }

  Future<void> _resetAllPlayersReady() async {
    if (_gameState == null) return;
    // Single write instead of P writes!
    await updateGameState(_gameState!.copyWith(readyPlayers: {}));
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _playersSubscription?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
