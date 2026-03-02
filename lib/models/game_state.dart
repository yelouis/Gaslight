enum GamePhase { lobby, draft, craft, vote, reveal, gameOver }

class GameState {
  final String roomCode;
  final GamePhase currentPhase;
  final int totalRounds;
  final int currentRound;
  final String? currentTricksterId;
  final int? secretTarget;
  final String? activeTemplate;
  final String? activePromptFirstHalf;
  final String? activePromptSecondHalf;
  final Map<String, String> promptBank; // Map ofplayerId -> prompt half

  GameState({
    required this.roomCode,
    this.currentPhase = GamePhase.lobby,
    this.totalRounds = 1,
    this.currentRound = 1,
    this.currentTricksterId,
    this.secretTarget,
    this.activeTemplate,
    this.activePromptFirstHalf,
    this.activePromptSecondHalf,
    this.promptBank = const {},
  });

  GameState copyWith({
    String? roomCode,
    GamePhase? currentPhase,
    int? totalRounds,
    int? currentRound,
    String? currentTricksterId,
    int? secretTarget,
    String? activeTemplate,
    String? activePromptFirstHalf,
    String? activePromptSecondHalf,
    Map<String, String>? promptBank,
  }) {
    return GameState(
      roomCode: roomCode ?? this.roomCode,
      currentPhase: currentPhase ?? this.currentPhase,
      totalRounds: totalRounds ?? this.totalRounds,
      currentRound: currentRound ?? this.currentRound,
      currentTricksterId: currentTricksterId ?? this.currentTricksterId,
      secretTarget: secretTarget ?? this.secretTarget,
      activeTemplate: activeTemplate ?? this.activeTemplate,
      activePromptFirstHalf: activePromptFirstHalf ?? this.activePromptFirstHalf,
      activePromptSecondHalf: activePromptSecondHalf ?? this.activePromptSecondHalf,
      promptBank: promptBank ?? this.promptBank,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomCode': roomCode,
      'currentPhase': currentPhase.name,
      'totalRounds': totalRounds,
      'currentRound': currentRound,
      'currentTricksterId': currentTricksterId,
      'secretTarget': secretTarget,
      'activePromptFirstHalf': activePromptFirstHalf,
      'activePromptSecondHalf': activePromptSecondHalf,
      'promptBank': promptBank,
    };
  }

  factory GameState.fromMap(Map<String, dynamic> map, String docId) {
    return GameState(
      roomCode: docId,
      currentPhase: GamePhase.values.firstWhere(
        (e) => e.name == map['currentPhase'],
        orElse: () => GamePhase.lobby,
      ),
      totalRounds: map['totalRounds']?.toInt() ?? 1,
      currentRound: map['currentRound']?.toInt() ?? 1,
      currentTricksterId: map['currentTricksterId'],
      secretTarget: map['secretTarget']?.toInt(),
      activePromptFirstHalf: map['activePromptFirstHalf'],
      activePromptSecondHalf: map['activePromptSecondHalf'],
      promptBank: Map<String, String>.from(map['promptBank'] ?? {}),
    );
  }
}
