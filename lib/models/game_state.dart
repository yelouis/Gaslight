import 'card_model.dart';

enum GamePhase { lobby, sabotage, truth, vote, reveal, gameOver }

class GameState {
  final String roomCode;
  final GamePhase currentPhase;

  // Custom Configurability
  final int totalPlayers;
  final int sabotageAnswersCount;

  // Rotation Tracking
  final int currentRotationIndex;

  // The master list of cards in the current round
  final List<CardModel> cards;

  // Who is holding whose card mapped by holdingPlayerId -> targetPlayerId
  final Map<String, String> currentCardAssignments;

  // Track who is reading the card during Phase 3 & 4
  final String? currentReaderId;

  // Pre-calculated offline-safe rotation derivations (Phase 2 Master Fix)
  final Map<String, Map<String, String>> rotationPlan; // Stored as String keys for Firestore config parsing

  // Centralized readiness tracking to prevent race conditions
  final Map<String, bool> readyPlayers;

  GameState({
    required this.roomCode,
    this.currentPhase = GamePhase.lobby,
    this.totalPlayers = 4,
    this.sabotageAnswersCount = 2,
    this.currentRotationIndex = 0,
    this.cards = const [],
    this.currentCardAssignments = const {},
    this.currentReaderId,
    this.rotationPlan = const {},
    this.readyPlayers = const {},
  });

  GameState copyWith({
    String? roomCode,
    GamePhase? currentPhase,
    int? totalPlayers,
    int? sabotageAnswersCount,
    int? currentRotationIndex,
    List<CardModel>? cards,
    Map<String, String>? currentCardAssignments,
    String? currentReaderId,
    Map<String, Map<String, String>>? rotationPlan,
    Map<String, bool>? readyPlayers,
    bool clearReaderId = false,
  }) {
    return GameState(
      roomCode: roomCode ?? this.roomCode,
      currentPhase: currentPhase ?? this.currentPhase,
      totalPlayers: totalPlayers ?? this.totalPlayers,
      sabotageAnswersCount: sabotageAnswersCount ?? this.sabotageAnswersCount,
      currentRotationIndex: currentRotationIndex ?? this.currentRotationIndex,
      cards: cards ?? this.cards,
      currentCardAssignments: currentCardAssignments ?? this.currentCardAssignments,
      currentReaderId: clearReaderId ? null : (currentReaderId ?? this.currentReaderId),
      rotationPlan: rotationPlan ?? this.rotationPlan,
      readyPlayers: readyPlayers ?? this.readyPlayers,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomCode': roomCode,
      'currentPhase': currentPhase.name,
      'totalPlayers': totalPlayers,
      'sabotageAnswersCount': sabotageAnswersCount,
      'currentRotationIndex': currentRotationIndex,
      'cards': cards.map((c) => c.toMap()).toList(),
      'currentCardAssignments': currentCardAssignments,
      'currentReaderId': currentReaderId,
      'rotationPlan': rotationPlan,
      'readyPlayers': readyPlayers,
    };
  }

  factory GameState.fromMap(Map<String, dynamic> map, String docId) {
    // Firebase converts Map<int, Object> into Map<String, Object> 
    // so we handle the rotationPlan cast generically
    Map<String, Map<String, String>> rotMap = {};
    if (map['rotationPlan'] != null) {
      final rawPlan = map['rotationPlan'] as Map<dynamic, dynamic>;
      rawPlan.forEach((key, val) {
         rotMap[key.toString()] = Map<String, String>.from(val);
      });
    }

    return GameState(
      roomCode: docId,
      currentPhase: GamePhase.values.firstWhere(
        (e) => e.name == map['currentPhase'],
        orElse: () => GamePhase.lobby,
      ),
      totalPlayers: map['totalPlayers']?.toInt() ?? 4,
      sabotageAnswersCount: map['sabotageAnswersCount']?.toInt() ?? 2,
      currentRotationIndex: map['currentRotationIndex']?.toInt() ?? 0,
      cards: (map['cards'] as List<dynamic>? ?? [])
          .map((c) => CardModel.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      currentCardAssignments: Map<String, String>.from(map['currentCardAssignments'] ?? {}),
      currentReaderId: map['currentReaderId'],
      rotationPlan: rotMap,
      readyPlayers: Map<String, bool>.from(map['readyPlayers'] ?? {}),
    );
  }
}
