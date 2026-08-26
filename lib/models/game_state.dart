import 'card_model.dart';
import '../utils/prompt_decks.dart';

enum GamePhase { lobby, forgery, truth, vote, reveal, gameOver }

class GameState {
  final String roomCode;
  final GamePhase currentPhase;

  // Custom Configurability
  final int totalPlayers;
  final int? forgeriesPerCard;
  final int totalRounds;
  final int currentRound;
  final bool isTimerDisabled;
  final String selectedDeckId;
  final String? effectiveDeckId;

  // Legacy alias for compatibility
  int? get sabotageAnswersCount => forgeriesPerCard;

  int effectiveForgeriesPerCard(int activePlayersCount) {
    if (forgeriesPerCard != null) return forgeriesPerCard!;
    if (activePlayersCount <= 1) return 1;
    return (activePlayersCount - 1).clamp(1, 5);
  }

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

  // Gated debug capabilities
  final bool debugEnabled;

  // Unmask deadline for revenge guesses
  final int? unmaskDeadline;

  // Published match summary for game over screen
  final Map<String, dynamic>? matchSummary;

  GameState({
    required this.roomCode,
    this.currentPhase = GamePhase.lobby,
    this.totalPlayers = 4,
    int? forgeriesPerCard,
    int? sabotageAnswersCount,
    this.totalRounds = 1,
    this.currentRound = 1,
    this.isTimerDisabled = false,
    this.selectedDeckId = PromptDecks.fallbackDeckId,
    this.effectiveDeckId,
    this.currentRotationIndex = 0,
    this.cards = const [],
    this.currentCardAssignments = const {},
    this.currentReaderId,
    this.rotationPlan = const {},
    this.readyPlayers = const {},
    this.endTime,
    this.resolutionOrder = const [],
    this.debugEnabled = false,
    this.unmaskDeadline,
    this.matchSummary,
  }) : forgeriesPerCard = forgeriesPerCard ?? sabotageAnswersCount;

  GameState copyWith({
    String? roomCode,
    GamePhase? currentPhase,
    int? totalPlayers,
    int? forgeriesPerCard,
    int? sabotageAnswersCount,
    int? totalRounds,
    int? currentRound,
    bool? isTimerDisabled,
    String? selectedDeckId,
    String? effectiveDeckId,
    int? currentRotationIndex,
    List<CardModel>? cards,
    Map<String, String>? currentCardAssignments,
    String? currentReaderId,
    Map<String, Map<String, String>>? rotationPlan,
    Map<String, bool>? readyPlayers,
    int? endTime,
    List<String>? resolutionOrder,
    bool? debugEnabled,
    int? unmaskDeadline,
    Map<String, dynamic>? matchSummary,
    bool clearReaderId = false,
    bool clearEndTime = false,
    bool clearUnmaskDeadline = false,
    bool clearEffectiveDeckId = false,
    bool clearMatchSummary = false,
  }) {
    return GameState(
      roomCode: roomCode ?? this.roomCode,
      currentPhase: currentPhase ?? this.currentPhase,
      totalPlayers: totalPlayers ?? this.totalPlayers,
      forgeriesPerCard: forgeriesPerCard ?? sabotageAnswersCount ?? this.forgeriesPerCard,
      totalRounds: totalRounds ?? this.totalRounds,
      currentRound: currentRound ?? this.currentRound,
      isTimerDisabled: isTimerDisabled ?? this.isTimerDisabled,
      selectedDeckId: selectedDeckId ?? this.selectedDeckId,
      effectiveDeckId: clearEffectiveDeckId ? null : (effectiveDeckId ?? this.effectiveDeckId),
      currentRotationIndex: currentRotationIndex ?? this.currentRotationIndex,
      cards: cards ?? this.cards,
      currentCardAssignments: currentCardAssignments ?? this.currentCardAssignments,
      currentReaderId: clearReaderId ? null : (currentReaderId ?? this.currentReaderId),
      rotationPlan: rotationPlan ?? this.rotationPlan,
      readyPlayers: readyPlayers ?? this.readyPlayers,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      resolutionOrder: resolutionOrder ?? this.resolutionOrder,
      debugEnabled: debugEnabled ?? this.debugEnabled,
      unmaskDeadline: clearUnmaskDeadline ? null : (unmaskDeadline ?? this.unmaskDeadline),
      matchSummary: clearMatchSummary ? null : (matchSummary ?? this.matchSummary),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomCode': roomCode,
      'currentPhase': currentPhase.name,
      'totalPlayers': totalPlayers,
      if (forgeriesPerCard != null) 'forgeriesPerCard': forgeriesPerCard,
      if (forgeriesPerCard != null) 'sabotageAnswersCount': forgeriesPerCard,
      'totalRounds': totalRounds,
      'currentRound': currentRound,
      'isTimerDisabled': isTimerDisabled,
      'selectedDeckId': selectedDeckId,
      if (effectiveDeckId != null) 'effectiveDeckId': effectiveDeckId,
      'currentRotationIndex': currentRotationIndex,
      'cards': cards.map((c) => c.toMap()).toList(),
      'currentCardAssignments': currentCardAssignments,
      'currentReaderId': currentReaderId,
      'rotationPlan': rotationPlan,
      'readyPlayers': readyPlayers,
      'endTime': endTime,
      'resolutionOrder': resolutionOrder,
      'debugEnabled': debugEnabled,
      'unmaskDeadline': unmaskDeadline,
      if (matchSummary != null) 'matchSummary': matchSummary,
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
      forgeriesPerCard: map['forgeriesPerCard']?.toInt() ?? map['sabotageAnswersCount']?.toInt(),
      totalRounds: map['totalRounds']?.toInt() ?? 1,
      currentRound: map['currentRound']?.toInt() ?? 1,
      isTimerDisabled: map['isTimerDisabled'] as bool? ?? false,
      selectedDeckId: map['selectedDeckId'] as String? ?? PromptDecks.fallbackDeckId,
      effectiveDeckId: map['effectiveDeckId'] as String?,
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
      debugEnabled: map['debugEnabled'] as bool? ?? false,
      unmaskDeadline: map['unmaskDeadline']?.toInt(),
      matchSummary: map['matchSummary'] != null
          ? Map<String, dynamic>.from(map['matchSummary'] as Map)
          : null,
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
