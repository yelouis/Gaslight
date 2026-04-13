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

  GameState({
    required this.roomCode,
    this.currentPhase = GamePhase.lobby,
    this.totalPlayers = 4,
    this.sabotageAnswersCount = 2,
    this.currentRotationIndex = 0,
    this.cards = const [],
    this.currentCardAssignments = const {},
    this.currentReaderId,
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
  }) {
    return GameState(
      roomCode: roomCode ?? this.roomCode,
      currentPhase: currentPhase ?? this.currentPhase,
      totalPlayers: totalPlayers ?? this.totalPlayers,
      sabotageAnswersCount: sabotageAnswersCount ?? this.sabotageAnswersCount,
      currentRotationIndex: currentRotationIndex ?? this.currentRotationIndex,
      cards: cards ?? this.cards,
      currentCardAssignments: currentCardAssignments ?? this.currentCardAssignments,
      currentReaderId: currentReaderId ?? this.currentReaderId,
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
    };
  }

  factory GameState.fromMap(Map<String, dynamic> map, String docId) {
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
          .map((c) => CardModel.fromMap(c as Map<String, dynamic>))
          .toList(),
      currentCardAssignments: Map<String, String>.from(map['currentCardAssignments'] ?? {}),
      currentReaderId: map['currentReaderId'],
    );
  }
}
