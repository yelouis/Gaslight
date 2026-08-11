export class RotationEngine {
  /**
   * Generates the circular card passing logic for Sabotage rounds.
   * Returns a map of Rotation Round (1 to forgeriesPerCard) -> Map of holdingPlayerId -> targetPlayerId
   */
  static generateRotations(playerIds: string[], forgeriesPerCard: number): Record<number, Record<string, string>> {
    if (!Number.isInteger(forgeriesPerCard) || forgeriesPerCard < 1) {
      throw new Error(`forgeriesPerCard must be a positive integer, received: ${JSON.stringify(forgeriesPerCard)}`);
    }
    if (playerIds.length <= forgeriesPerCard) {
      throw new Error('Total players must be strictly greater than forgeries per card to prevent players from receiving their own cards.');
    }
    
    const rotations: Record<number, Record<string, string>> = {};
    const p = playerIds.length;
    const orderedIds = [...playerIds];
    
    for (let r = 1; r <= forgeriesPerCard; r++) {
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
