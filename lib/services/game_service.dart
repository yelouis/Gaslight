import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import '../models/player_state.dart';
import 'dart:math';
import '../utils/prompt_decks.dart';
import '../utils/rotation_engine.dart';
import '../models/card_model.dart';
class GameService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  GameState? _gameState;
  List<PlayerState> _players = [];
  String? _currentPlayerId;

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

  Future<void> createRoom(String playerName, String playerId, {int totalPlayers = 4, int sabotageAnswersCount = 2, int? avatarIndex}) async {
    final roomCode = _generateRoomCode();
    _currentPlayerId = playerId;

    final initialState = GameState(
      roomCode: roomCode, 
      totalPlayers: totalPlayers,
      sabotageAnswersCount: sabotageAnswersCount,
    );
    final initialPlayer = PlayerState(
      id: playerId,
      name: playerName,
      isHost: true,
      colorValue: _getRandomColor(),
      avatarIndex: avatarIndex ?? _getRandomAvatar(),
    );

    await _db.collection('rooms').doc(roomCode).set(initialState.toMap());
    await _db.collection('rooms').doc(roomCode).collection('players').doc(playerId).set(initialPlayer.toMap());
    
    listenToRoom(roomCode);
  }

  Future<void> joinRoom(String roomCode, String playerName, String playerId, {int? avatarIndex}) async {
    final doc = await _db.collection('rooms').doc(roomCode).get();
    if (!doc.exists) throw Exception('Room not found');

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
    );

    await _db.collection('rooms').doc(roomCode).collection('players').doc(playerId).set(newPlayer.toMap());
    
    listenToRoom(roomCode);
  }

  void listenToRoom(String roomCode) {
    // Listen to Game State
    _db.collection('rooms').doc(roomCode).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        _gameState = GameState.fromMap(snapshot.data()!, snapshot.id);
        notifyListeners();
      }
    });

    // Listen to Players
    _db.collection('rooms').doc(roomCode).collection('players').snapshots().listen((snapshot) {
      _players = snapshot.docs.map((doc) => PlayerState.fromMap(doc.data(), doc.id)).toList();
      notifyListeners();
    });
  }

  Future<void> updateGameState(GameState state) async {
    if (state.roomCode.isEmpty) return;
    await _db.collection('rooms').doc(state.roomCode).update(state.toMap());
  }

  Future<void> updatePlayerState(String roomCode, PlayerState player) async {
    await _db.collection('rooms').doc(roomCode).collection('players').doc(player.id).update(player.toMap());
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
    
    await setPlayerReady(true);
  }

  // --- PHASE 2: ROTATION ENGINE & GAME LOOP ---

  Future<void> startGame(String deckId) async {
    if (_gameState == null || _players.length < 2) return;
    
    if (_players.length <= _gameState!.sabotageAnswersCount) {
        throw Exception("Cannot start: Need more players than sabotage rounds.");
    }
    
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
           promptId: prompts[i]
        ));
    }

    // 3. Initiate first rotation
    int startIdx = 1;
    Map<String, String> initAssignments = stringRotations[startIdx.toString()]!;

    await updateGameState(_gameState!.copyWith(
        currentPhase: GamePhase.sabotage,
        currentRotationIndex: startIdx,
        cards: startingCards,
        currentCardAssignments: initAssignments,
        rotationPlan: stringRotations,
    ));
    await _resetAllPlayersReady();
  }
  
  Future<void> setPlayerReady(bool ready) async {
    if (_gameState == null || currentPlayer == null) return;
    await updatePlayerState(_gameState!.roomCode, currentPlayer!.copyWith(isReadyForNextRotation: ready));
  }

  Future<void> evaluateReadyState() async {
    if (_gameState == null) return;
    
    // Triggered often by listeners. If Host, evaluate.
    if (currentPlayer?.isHost != true) return;
    
    bool allReady = _players.every((p) => p.isReadyForNextRotation);
    if (allReady) {
       await _advanceRotationOrPhase();
    }
  }

  Future<void> _advanceRotationOrPhase() async {
    if (_gameState == null) return;

    if (_gameState!.currentPhase == GamePhase.sabotage) {
        if (_gameState!.currentRotationIndex < _gameState!.sabotageAnswersCount) {
            int nextRot = _gameState!.currentRotationIndex + 1;
            Map<String, String> nextAssignments = _gameState!.rotationPlan[nextRot.toString()]!;
            await updateGameState(_gameState!.copyWith(
                currentRotationIndex: nextRot,
                currentCardAssignments: nextAssignments,
            ));
        } else {
            // Transition to Truth Phase: Every player gets their own card back
            var pIds = _players.map((p) => p.id).toList();
            Map<String, String> truthAssignments = { for (var id in pIds) id : id };
            
            await updateGameState(_gameState!.copyWith(
                currentPhase: GamePhase.truth,
                currentCardAssignments: truthAssignments,
            ));
        }
    } else if (_gameState!.currentPhase == GamePhase.truth) {
        // Transition to Vote Phase: First player is the reader
        var pIds = _players.map((p) => p.id).toList();
        await updateGameState(_gameState!.copyWith(
            currentPhase: GamePhase.vote,
            currentReaderId: pIds.first,
        ));
    } else if (_gameState!.currentPhase == GamePhase.vote) {
        // Transition to Reveal for the CURRENT reader
        await updateGameState(_gameState!.copyWith(
            currentPhase: GamePhase.reveal,
        ));
    }
    
    await _resetAllPlayersReady();
  }

  Future<void> advanceToNextResolution() async {
    if (_gameState == null || currentPlayer?.isHost != true) return;
    
    final pIds = _players.map((p) => p.id).toList();
    final currentIdx = pIds.indexOf(_gameState!.currentReaderId ?? '');
    
    if (currentIdx != -1 && currentIdx < pIds.length - 1) {
        // Move to next player's card
        await updateGameState(_gameState!.copyWith(
            currentPhase: GamePhase.vote,
            currentReaderId: pIds[currentIdx + 1],
        ));
        await _resetAllPlayersReady();
    } else {
        // All cards resolved -> Game Over
        await updateGameState(_gameState!.copyWith(
            currentPhase: GamePhase.gameOver,
        ));
    }
  }

  Future<void> _resetAllPlayersReady() async {
    if (_gameState == null) return;
    WriteBatch batch = _db.batch();
    for (var p in _players) {
        DocumentReference ref = _db.collection('rooms').doc(_gameState!.roomCode).collection('players').doc(p.id);
        batch.update(ref, {'isReadyForNextRotation': false});
    }
    await batch.commit();
  }
}
