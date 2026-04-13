enum PlayerRole { saboteur, target, voter, unassigned }

class PlayerState {
  final String id;
  final String name;
  final int totalScore;
  final PlayerRole role;
  final bool isHost;
  
  // Visuals
  final int colorValue; // Hex color for the player
  final int avatarIndex; // Reference to a local simple avatar

  PlayerState({
    required this.id,
    required this.name,
    this.totalScore = 0,
    this.role = PlayerRole.unassigned,
    this.isHost = false,
    this.colorValue = 0xFF58A6FF,
    this.avatarIndex = 0,
  });

  PlayerState copyWith({
    String? id,
    String? name,
    int? totalScore,
    PlayerRole? role,
    bool? isHost,
    int? colorValue,
    int? avatarIndex,
  }) {
    return PlayerState(
      id: id ?? this.id,
      name: name ?? this.name,
      totalScore: totalScore ?? this.totalScore,
      role: role ?? this.role,
      isHost: isHost ?? this.isHost,
      colorValue: colorValue ?? this.colorValue,
      avatarIndex: avatarIndex ?? this.avatarIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'totalScore': totalScore,
      'role': role.name,
      'isHost': isHost,
      'colorValue': colorValue,
      'avatarIndex': avatarIndex,
    };
  }

  factory PlayerState.fromMap(Map<String, dynamic> map, String docId) {
    return PlayerState(
      id: docId,
      name: map['name'] ?? '',
      totalScore: map['totalScore']?.toInt() ?? 0,
      role: PlayerRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => PlayerRole.unassigned,
      ),
      isHost: map['isHost'] ?? false,
      colorValue: map['colorValue']?.toInt() ?? 0xFF58A6FF,
      avatarIndex: map['avatarIndex']?.toInt() ?? 0,
    );
  }
}
