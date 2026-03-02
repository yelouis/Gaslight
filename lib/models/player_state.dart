enum PlayerRole { trickster, voter, unassigned }

class PlayerState {
  final String id;
  final String name;
  final int score;
  final PlayerRole role;
  final bool isHost;
  
  // Visuals
  final int colorValue; // Hex color for the player
  final int avatarIndex; // Reference to a local simple avatar
  
  // Phase 1 Draft Data
  final List<String> draftedTemplates;
  final List<String> draftedPromptHalves;
  
  // Phase 3 Vote Data
  final String? selectedOption; // 'A' or 'B'
  final int? guessedTarget;

  PlayerState({
    required this.id,
    required this.name,
    this.score = 0,
    this.role = PlayerRole.unassigned,
    this.isHost = false,
    this.colorValue = 0xFF58A6FF,
    this.avatarIndex = 0,
    this.draftedTemplates = const [],
    this.draftedPromptHalves = const [],
    this.selectedOption,
    this.guessedTarget,
  });

  PlayerState copyWith({
    String? id,
    String? name,
    int? score,
    PlayerRole? role,
    bool? isHost,
    int? colorValue,
    int? avatarIndex,
    List<String>? draftedTemplates,
    List<String>? draftedPromptHalves,
    String? selectedOption,
    int? guessedTarget,
  }) {
    return PlayerState(
      id: id ?? this.id,
      name: name ?? this.name,
      score: score ?? this.score,
      role: role ?? this.role,
      isHost: isHost ?? this.isHost,
      colorValue: colorValue ?? this.colorValue,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      draftedTemplates: draftedTemplates ?? this.draftedTemplates,
      draftedPromptHalves: draftedPromptHalves ?? this.draftedPromptHalves,
      selectedOption: selectedOption ?? this.selectedOption,
      guessedTarget: guessedTarget ?? this.guessedTarget,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'score': score,
      'role': role.name,
      'isHost': isHost,
      'colorValue': colorValue,
      'avatarIndex': avatarIndex,
      'draftedTemplates': draftedTemplates,
      'draftedPromptHalves': draftedPromptHalves,
      'selectedOption': selectedOption,
      'guessedTarget': guessedTarget,
    };
  }

  factory PlayerState.fromMap(Map<String, dynamic> map, String docId) {
    return PlayerState(
      id: docId,
      name: map['name'] ?? '',
      score: map['score']?.toInt() ?? 0,
      role: PlayerRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => PlayerRole.unassigned,
      ),
      isHost: map['isHost'] ?? false,
      colorValue: map['colorValue']?.toInt() ?? 0xFF58A6FF,
      avatarIndex: map['avatarIndex']?.toInt() ?? 0,
      draftedTemplates: List<String>.from(map['draftedTemplates'] ?? []),
      draftedPromptHalves: List<String>.from(map['draftedPromptHalves'] ?? []),
      selectedOption: map['selectedOption'],
      guessedTarget: map['guessedTarget']?.toInt(),
    );
  }
}
