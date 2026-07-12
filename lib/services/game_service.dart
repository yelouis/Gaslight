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
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

class GameService extends ChangeNotifier {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  
  GameService({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance {
    final useEmulator = const bool.fromEnvironment('USE_EMULATOR', defaultValue: false) || (dotenv.isInitialized && dotenv.env['USE_EMULATOR'] == 'true');
    if (useEmulator) {
      try {
        _db.useFirestoreEmulator('localhost', 8080);
        _functions.useFunctionsEmulator('localhost', 5001);
        FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      } catch (e) {
        debugPrint('Emulator already initialized: $e');
      }
    }
  }
  
  GameState? _gameState;
  List<PlayerState> _players = [];
  String? _currentPlayerId;

  // Cleanup and Heartbeat
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _playersSubscription;
  Timer? _heartbeatTimer;

  // Duplicate-advance guards
  final Set<String> _advancedStateKeys = {};

  // Disconnect in-flight guards
  final Set<String> _disconnectsInFlight = {};

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

  static const String kMissingAnswerPlaceholder = "(The ink ran dry...)";

  // Generate 4 letter room code
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    var rng = Random();
    return String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rng.nextInt(chars.length))));
  }

  int _getRandomColor() {
    final rng = Random();
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

  Future<void> ensureAuthenticated() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (e) {
      debugPrint('Firebase Auth not available (failing open): $e');
    }
  }

  Future<String> getOrCreateStablePlayerId() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('stable_device_player_id');
    if (storedId == null) {
      storedId = const Uuid().v4();
      await prefs.setString('stable_device_player_id', storedId);
    }
    return storedId;
  }

  Future<void> createRoom(String playerName, String? playerId, {int totalPlayers = 4, int sabotageAnswersCount = 2, int? avatarIndex, bool isTimerDisabled = false}) async {
    await ensureAuthenticated();
    final resolvedPlayerId = playerId ?? await getOrCreateStablePlayerId();

    final result = await _functions.httpsCallable('createRoom').call({
      'playerName': playerName,
      'playerId': resolvedPlayerId,
      'colorValue': _getRandomColor(),
      'avatarIndex': avatarIndex ?? _getRandomAvatar(),
      'sabotageAnswersCount': sabotageAnswersCount,
      'isTimerDisabled': isTimerDisabled,
    });

    final roomCode = result.data['roomCode'] as String;
    _currentPlayerId = resolvedPlayerId;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('room_code', roomCode);
    await prefs.setString('player_id', resolvedPlayerId);

    listenToRoom(roomCode);
  }

  Future<void> joinRoom(String roomCode, String playerName, String? playerId, {int? avatarIndex}) async {
    await ensureAuthenticated();
    final resolvedPlayerId = playerId ?? await getOrCreateStablePlayerId();

    final playersSnap = await _db.collection('rooms').doc(roomCode).collection('players').get();
    final existingColors = playersSnap.docs.map((d) => d.data()['colorValue'] as int? ?? 0).toSet();
    final available = _playerColors.where((c) => !existingColors.contains(c)).toList();
    
    final int selectedColor = available.isNotEmpty 
        ? available[Random().nextInt(available.length)] 
        : _playerColors[Random().nextInt(_playerColors.length)];

    await _functions.httpsCallable('joinRoom').call({
      'roomCode': roomCode,
      'playerName': playerName,
      'playerId': resolvedPlayerId,
      'colorValue': selectedColor,
      'avatarIndex': avatarIndex ?? _getRandomAvatar(),
    });

    _currentPlayerId = resolvedPlayerId;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('room_code', roomCode);
    await prefs.setString('player_id', resolvedPlayerId);

    listenToRoom(roomCode);
  }

  Future<bool> tryRejoinSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRoom = prefs.getString('room_code');
      final savedPlayerId = prefs.getString('player_id');
      if (savedRoom != null && savedPlayerId != null) {
        String? authUid;
        try {
          authUid = FirebaseAuth.instance.currentUser?.uid;
        } catch (_) {}
        
        if (authUid != null && authUid != savedPlayerId) {
          await prefs.remove('room_code');
          await prefs.remove('player_id');
          debugPrint('Identity mismatch on rejoin: auth=$authUid, saved=$savedPlayerId. Session cleared.');
          return false;
        }

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
        await _functions.httpsCallable('handleDisconnect').call({
          'roomCode': roomCode,
          'disconnectedPlayerId': playerId,
        });
      } catch (e) {
        debugPrint('Error calling handleDisconnect on leave: $e');
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
        if (currentPlayer?.isHost == true) {
          evaluateReadyState();
        }
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
        _functions.httpsCallable('handleDisconnect').call({
          'roomCode': roomCode,
          'disconnectedPlayerId': dp.id,
        }).catchError((_) {});
      }

      notifyListeners();
      
      // If Host, evaluate ready state and handle disconnects
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
            if (_disconnectsInFlight.contains(dpId)) continue;
            _disconnectsInFlight.add(dpId);
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

  Future<void> toggleLobbyReady() async {
    final p = currentPlayer;
    final rCode = _gameState?.roomCode;
    if (p == null || rCode == null || rCode.isEmpty) return;
    
    final updated = p.copyWith(lobbyReady: !p.lobbyReady);
    await updatePlayerState(rCode, updated);
  }

  Future<void> updateLobbySettings({int? sabotageAnswersCount, bool? isTimerDisabled}) async {
    if (_gameState == null || currentPlayer?.isHost != true) return;
    await _functions.httpsCallable('updateLobbySettings').call({
      'roomCode': _gameState!.roomCode,
      'sabotageAnswersCount': sabotageAnswersCount,
      'isTimerDisabled': isTimerDisabled,
    });
  }

  Future<void> sendReaction(String emoji) async {
    final p = currentPlayer;
    final rCode = _gameState?.roomCode;
    if (p == null || rCode == null || rCode.isEmpty) return;
    
    final updated = p.copyWith(
      lastReaction: emoji,
      lastReactionAt: DateTime.now().millisecondsSinceEpoch,
    );
    await updatePlayerState(rCode, updated);
  }

  Future<void> rerollMyPrompt() async {
    final p = currentPlayer;
    final rCode = _gameState?.roomCode;
    if (p == null || rCode == null || rCode.isEmpty || _gameState == null) return;
    
    await _functions.httpsCallable('rerollPrompt').call({
      'roomCode': rCode,
      'playerId': p.id,
    });
  }

  Future<void> handlePlayerDisconnect(String disconnectedPlayerId) async {
    if (_gameState == null) return;
    try {
      await _functions.httpsCallable('handleDisconnect').call({
        'roomCode': _gameState!.roomCode,
        'disconnectedPlayerId': disconnectedPlayerId,
      });
    } finally {
      _disconnectsInFlight.remove(disconnectedPlayerId);
    }
  }

  // --- PHASE 2: ROTATION ENGINE & GAME LOOP ---
  
  Future<void> submitCardAnswer(String targetCardId, String authorId, String text, bool isTruth) async {
    if (_gameState == null) return;
    await _functions.httpsCallable('submitAnswer').call({
      'roomCode': _gameState!.roomCode,
      'targetCardId': targetCardId,
      'authorId': authorId,
      'text': text,
      'isTruth': isTruth,
    });
  }

  Future<void> castVote(String targetCardId, String voterId, String votedForId) async {
    if (_gameState == null) return;
    await _functions.httpsCallable('castVote').call({
      'roomCode': _gameState!.roomCode,
      'targetCardId': targetCardId,
      'voterId': voterId,
      'votedForId': votedForId,
    });
  }

  Future<void> startGame(String deckId) async {
    if (_gameState == null) {
      throw Exception("No active game room found.");
    }
    await _functions.httpsCallable('startGame').call({
      'roomCode': _gameState!.roomCode,
      'selectedDeckId': deckId,
    });
  }
  
  Future<void> setPlayerReady(bool ready, {String? playerId}) async {
    final targetId = playerId ?? _currentPlayerId;
    if (_gameState == null || targetId == null) return;
    await _functions.httpsCallable('setReady').call({
      'roomCode': _gameState!.roomCode,
      'playerId': targetId,
      'ready': ready,
    });
  }

  Future<void> evaluateReadyState() async {
    if (_gameState == null) return;
    await _functions.httpsCallable('advancePhase').call({
      'roomCode': _gameState!.roomCode,
    });
  }

  Future<void> forceAdvance() async {
    if (_gameState == null || currentPlayer?.isHost != true) return;
    await _functions.httpsCallable('advancePhase').call({
      'roomCode': _gameState!.roomCode,
    });
  }

  Future<void> advanceToNextResolution() async {
    if (_gameState == null || currentPlayer?.isHost != true) return;
    await _functions.httpsCallable('advanceToNextResolution').call({
      'roomCode': _gameState!.roomCode,
    });
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
          joinedAt: DateTime.now().millisecondsSinceEpoch + i,
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
