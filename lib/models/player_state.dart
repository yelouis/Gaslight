enum PlayerRole { saboteur, target, voter, spectator, unassigned }

class PlayerState {
  final String id;
  final String name;
  final int totalScore;
  final PlayerRole role;
  final bool isHost;
  
  // Visuals
  final int colorValue; // Hex color for the player
  final int avatarIndex; // Reference to a local simple avatar
  final int? lastSeen; // Epoch timestamp for heartbeat

  // Metric Honors Stats
  final int timesFooled;
  final int playersDeceived;

  // Session metadata
  final int? joinedAt; // Epoch timestamp for join time
  final bool lobbyReady; // If player is ready in the lobby

  // Emoji Reactions
  final String? lastReaction;
  final int? lastReactionAt; // Epoch timestamp in ms

  // Prompt re-roll
  final bool hasRerolled;

  PlayerState({
    required this.id,
    required this.name,
    this.totalScore = 0,
    this.role = PlayerRole.unassigned,
    this.isHost = false,
    this.colorValue = 0xFF58A6FF,
    this.avatarIndex = 0,
    this.lastSeen,
    this.timesFooled = 0,
    this.playersDeceived = 0,
    this.joinedAt,
    this.lobbyReady = false,
    this.lastReaction,
    this.lastReactionAt,
    this.hasRerolled = false,
  });

  PlayerState copyWith({
    String? id,
    String? name,
    int? totalScore,
    PlayerRole? role,
    bool? isHost,
    int? colorValue,
    int? avatarIndex,
    int? lastSeen,
    int? timesFooled,
    int? playersDeceived,
    int? joinedAt,
    bool? lobbyReady,
    String? lastReaction,
    int? lastReactionAt,
    bool? hasRerolled,
  }) {
    return PlayerState(
      id: id ?? this.id,
      name: name ?? this.name,
      totalScore: totalScore ?? this.totalScore,
      role: role ?? this.role,
      isHost: isHost ?? this.isHost,
      colorValue: colorValue ?? this.colorValue,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      lastSeen: lastSeen ?? this.lastSeen,
      timesFooled: timesFooled ?? this.timesFooled,
      playersDeceived: playersDeceived ?? this.playersDeceived,
      joinedAt: joinedAt ?? this.joinedAt,
      lobbyReady: lobbyReady ?? this.lobbyReady,
      lastReaction: lastReaction ?? this.lastReaction,
      lastReactionAt: lastReactionAt ?? this.lastReactionAt,
      hasRerolled: hasRerolled ?? this.hasRerolled,
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
      'lastSeen': lastSeen,
      'timesFooled': timesFooled,
      'playersDeceived': playersDeceived,
      'joinedAt': joinedAt,
      'lobbyReady': lobbyReady,
      'lastReaction': lastReaction,
      'lastReactionAt': lastReactionAt,
      'hasRerolled': hasRerolled,
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
      lastSeen: map['lastSeen']?.toInt(),
      timesFooled: map['timesFooled']?.toInt() ?? 0,
      playersDeceived: map['playersDeceived']?.toInt() ?? 0,
      joinedAt: map['joinedAt']?.toInt(),
      lobbyReady: map['lobbyReady'] ?? false,
      lastReaction: map['lastReaction'],
      lastReactionAt: map['lastReactionAt']?.toInt(),
      hasRerolled: map['hasRerolled'] ?? false,
    );
  }
}
