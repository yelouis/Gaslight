class RotationEngine {
  /// Generates the circular card passing logic for Sabotage rounds.
  /// Returns a map of Rotation Round (1 to sabotageRounds) -> Map of `holdingPlayerId` -> `targetPlayerId`
  /// 
  /// The algorithm ensures:
  /// 1. No player receives their own card (Target != Holder).
  /// 2. No player receives the same Target's card structurally.
  static Map<int, Map<String, String>> generateRotations(List<String> playerIds, int sabotageRounds) {
    if (playerIds.length <= sabotageRounds) {
      throw Exception('Total players must be strictly greater than sabotage rounds to prevent players from receiving their own cards.');
    }
    
    var rotations = <int, Map<String, String>>{};
    int p = playerIds.length;
    
    // Create a local copy to ensure predictable indexing logic without destroying the original list
    List<String> orderedIds = List.from(playerIds);
    // By keeping the list explicitly unshuffled during assignment generation, 
    // the mathematical modulo ensures perfect distribution. 
    // Randomization of prompts themselves will handle variety.
    
    for (int r = 1; r <= sabotageRounds; r++) {
      Map<String, String> currentRoundAssignments = {};
      for (int i = 0; i < p; i++) {
        // Derangement logic: Offset by the current rotation index
        int targetIndex = (i + r) % p;
        currentRoundAssignments[orderedIds[i]] = orderedIds[targetIndex];
      }
      rotations[r] = currentRoundAssignments;
    }
    
    return rotations;
  }
}
