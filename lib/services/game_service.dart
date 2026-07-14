import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'audio_service.dart';
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

  bool _soundEnabled = true;
  bool get soundEnabled => _soundEnabled;
  
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
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    AudioService.instance.soundEnabled = _soundEnabled;
    notifyListeners();
  }

  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    AudioService.instance.soundEnabled = _soundEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', _soundEnabled);
    notifyListeners();
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

  Future<void> createRoom(String playerName, String? playerId, {int totalPlayers = 4, int sabotageAnswersCount = 2, int? avatarIndex, bool isTimerDisabled = false, bool debugEnabled = false}) async {
    await ensureAuthenticated();
    final resolvedPlayerId = playerId ?? await getOrCreateStablePlayerId();

    final result = await _functions.httpsCallable('createRoom').call({
      'playerName': playerName,
      'playerId': resolvedPlayerId,
      'colorValue': _getRandomColor(),
      'avatarIndex': avatarIndex ?? _getRandomAvatar(),
      'sabotageAnswersCount': sabotageAnswersCount,
      'isTimerDisabled': isTimerDisabled,
      'debugEnabled': debugEnabled,
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
        final roomDoc = await _db.collection('rooms').doc(savedRoom).get();
        final playerDoc = await _db.collection('rooms').doc(savedRoom).collection('players').doc(savedPlayerId).get();
        if (roomDoc.exists && playerDoc.exists) {
          final pData = playerDoc.data()!;
          final name = pData['name'] as String? ?? 'Player';
          final avatarIndex = pData['avatarIndex'] as int? ?? 0;
          final colorValue = pData['colorValue'] as int? ?? 0xFF58A6FF;

          try {
            await ensureAuthenticated();
            await _functions.httpsCallable('joinRoom').call({
              'roomCode': savedRoom,
              'playerName': name,
              'playerId': savedPlayerId,
              'avatarIndex': avatarIndex,
              'colorValue': colorValue,
            });
            
            _currentPlayerId = savedPlayerId;
            _gameState = GameState.fromMap(roomDoc.data()!, roomDoc.id);
            listenToRoom(savedRoom);
            return true;
          } catch (e) {
            debugPrint('Error re-binding session during rejoin: $e');
            await prefs.remove('room_code');
            await prefs.remove('player_id');
          }
        }
      }
    } catch (e) {
      debugPrint('Error rejoining session: $e');
    }
    return false;
  }

  void _startHeartbeat(String roomCode, String playerId) {
    print("DEBUG HEARTBEAT: started timer for room: $roomCode, player: $playerId");
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
      
      // If Host, handle disconnects
      if (currentPlayer?.isHost == true) {
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

  Future<void> toggleLobbyReady() async {
    final p = currentPlayer;
    final rCode = _gameState?.roomCode;
    if (p == null || rCode == null || rCode.isEmpty) return;
    
    await _db.collection('rooms').doc(rCode).collection('players').doc(p.id).update({
      'lobbyReady': !p.lobbyReady,
    });
  }

  Future<void> updateLobbySettings({int? sabotageAnswersCount, bool? isTimerDisabled, String? selectedDeckId}) async {
    if (_gameState == null || currentPlayer?.isHost != true) return;
    await _functions.httpsCallable('updateLobbySettings').call({
      'roomCode': _gameState!.roomCode,
      'sabotageAnswersCount': sabotageAnswersCount,
      'isTimerDisabled': isTimerDisabled,
      'selectedDeckId': selectedDeckId,
    });
  }

  Future<void> submitUnmaskGuess(String guessedAuthorId) async {
    final p = currentPlayer;
    final rCode = _gameState?.roomCode;
    if (p == null || rCode == null || rCode.isEmpty) return;

    await _functions.httpsCallable('submitUnmaskGuess').call({
      'roomCode': rCode,
      'guesserId': p.id,
      'guessedAuthorId': guessedAuthorId,
    });
  }

  Future<void> sendReaction(String emoji) async {
    final p = currentPlayer;
    final rCode = _gameState?.roomCode;
    if (p == null || rCode == null || rCode.isEmpty) return;
    
    await _db.collection('rooms').doc(rCode).collection('players').doc(p.id).update({
      'lastReaction': emoji,
      'lastReactionAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updatePlayerCustomPrompts(List<String> prompts) async {
    final p = currentPlayer;
    final rCode = _gameState?.roomCode;
    if (p == null || rCode == null || rCode.isEmpty) return;

    await _db.collection('rooms').doc(rCode).collection('players').doc(p.id).update({
      'customPrompts': prompts,
    });
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
    await _functions.httpsCallable('debugAddBots').call({
      'roomCode': rCode,
    });
  }

  /// Auto-submits answers for all bots in the current phase.
  Future<void> debugSimulateBotResponses() async {
    if (_gameState == null) return;
    final rCode = _gameState!.roomCode;
    await _functions.httpsCallable('debugSimulateBotResponses').call({
      'roomCode': rCode,
    });
  }

  @override
  void dispose() {
    print("DEBUG HEARTBEAT: gameService.dispose() called");
    _roomSubscription?.cancel();
    _playersSubscription?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
