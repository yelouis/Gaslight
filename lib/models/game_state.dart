import 'card_model.dart';

enum GamePhase { lobby, forgery, truth, vote, reveal, gameOver }

class GameState {
  final String roomCode;
  final GamePhase currentPhase;

  // Custom Configurability
  final int totalPlayers;
  final int sabotageAnswersCount;
  final bool isTimerDisabled;
  final String selectedDeckId;

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

  // Auto-advance timestamp (millisecondsSinceEpoch)
  final int? endTime;

  // Randomized card resolution order
  final List<String> resolutionOrder;

  GameState({
    required this.roomCode,
    this.currentPhase = GamePhase.lobby,
    this.totalPlayers = 4,
    this.sabotageAnswersCount = 2,
    this.isTimerDisabled = false,
    this.selectedDeckId = 'the_daily_grind',
    this.currentRotationIndex = 0,
    this.cards = const [],
    this.currentCardAssignments = const {},
    this.currentReaderId,
    this.rotationPlan = const {},
    this.readyPlayers = const {},
    this.endTime,
    this.resolutionOrder = const [],
  });

  GameState copyWith({
    String? roomCode,
    GamePhase? currentPhase,
    int? totalPlayers,
    int? sabotageAnswersCount,
    bool? isTimerDisabled,
    String? selectedDeckId,
    int? currentRotationIndex,
    List<CardModel>? cards,
    Map<String, String>? currentCardAssignments,
    String? currentReaderId,
    Map<String, Map<String, String>>? rotationPlan,
    Map<String, bool>? readyPlayers,
    int? endTime,
    List<String>? resolutionOrder,
    bool clearReaderId = false,
    bool clearEndTime = false,
  }) {
    return GameState(
      roomCode: roomCode ?? this.roomCode,
      currentPhase: currentPhase ?? this.currentPhase,
      totalPlayers: totalPlayers ?? this.totalPlayers,
      sabotageAnswersCount: sabotageAnswersCount ?? this.sabotageAnswersCount,
      isTimerDisabled: isTimerDisabled ?? this.isTimerDisabled,
      selectedDeckId: selectedDeckId ?? this.selectedDeckId,
      currentRotationIndex: currentRotationIndex ?? this.currentRotationIndex,
      cards: cards ?? this.cards,
      currentCardAssignments: currentCardAssignments ?? this.currentCardAssignments,
      currentReaderId: clearReaderId ? null : (currentReaderId ?? this.currentReaderId),
      rotationPlan: rotationPlan ?? this.rotationPlan,
      readyPlayers: readyPlayers ?? this.readyPlayers,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      resolutionOrder: resolutionOrder ?? this.resolutionOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomCode': roomCode,
      'currentPhase': currentPhase.name,
      'totalPlayers': totalPlayers,
      'sabotageAnswersCount': sabotageAnswersCount,
      'isTimerDisabled': isTimerDisabled,
      'selectedDeckId': selectedDeckId,
      'currentRotationIndex': currentRotationIndex,
      'cards': cards.map((c) => c.toMap()).toList(),
      'currentCardAssignments': currentCardAssignments,
      'currentReaderId': currentReaderId,
      'rotationPlan': rotationPlan,
      'readyPlayers': readyPlayers,
      'endTime': endTime,
      'resolutionOrder': resolutionOrder,
    };
  }

  factory GameState.fromMap(Map<String, dynamic> map, String docId) {
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
      isTimerDisabled: map['isTimerDisabled'] as bool? ?? false,
      selectedDeckId: map['selectedDeckId'] as String? ?? 'the_daily_grind',
      currentRotationIndex: map['currentRotationIndex']?.toInt() ?? 0,
      cards: (map['cards'] as List<dynamic>? ?? [])
          .map((c) => CardModel.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      currentCardAssignments: Map<String, String>.from(map['currentCardAssignments'] ?? {}),
      currentReaderId: map['currentReaderId'],
      rotationPlan: rotMap,
      readyPlayers: Map<String, bool>.from(map['readyPlayers'] ?? {}),
      endTime: map['endTime']?.toInt(),
      resolutionOrder: List<String>.from(map['resolutionOrder'] ?? []),
    );
  }

  static String getRouteForPhase(GamePhase phase) {
    switch (phase) {
      case GamePhase.lobby:
        return '/';
      case GamePhase.forgery:
      case GamePhase.truth:
        return '/craft';
      case GamePhase.vote:
        return '/vote';
      case GamePhase.reveal:
        return '/reveal';
      case GamePhase.gameOver:
        return '/game-over';
    }
  }
}
