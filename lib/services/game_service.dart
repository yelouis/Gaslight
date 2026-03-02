import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import '../models/player_state.dart';
import 'dart:math';

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

  Future<void> createRoom(String playerName, String playerId, {int totalRounds = 1, int? avatarIndex}) async {
    final roomCode = _generateRoomCode();
    _currentPlayerId = playerId;

    final initialState = GameState(roomCode: roomCode, totalRounds: totalRounds);
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
}
