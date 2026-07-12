export class RotationEngine {
  /**
   * Generates the circular card passing logic for Sabotage rounds.
   * Returns a map of Rotation Round (1 to sabotageRounds) -> Map of holdingPlayerId -> targetPlayerId
   */
  static generateRotations(playerIds: string[], sabotageRounds: number): Record<number, Record<string, string>> {
    if (playerIds.length <= sabotageRounds) {
      throw new Error('Total players must be strictly greater than sabotage rounds to prevent players from receiving their own cards.');
    }
    
    const rotations: Record<number, Record<string, string>> = {};
    const p = playerIds.length;
    const orderedIds = [...playerIds];
    
    for (let r = 1; r <= sabotageRounds; r++) {
      const currentRoundAssignments: Record<string, string> = {};
      for (let i = 0; i < p; i++) {
        const targetIndex = (i + r) % p;
        currentRoundAssignments[orderedIds[i]] = orderedIds[targetIndex];
      }
      rotations[r] = currentRoundAssignments;
    }
    
    return rotations;
  }
}
