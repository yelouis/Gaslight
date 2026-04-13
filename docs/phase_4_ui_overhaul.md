# Phase 4: User Interface Overhaul

## Overview
Replacing the old UI requires views that clearly communicate what is happening (rotations) and elegantly reveal the final choices. The system now accounts for dynamic point modifiers based on player and sabotage configurations.

## Key Processing Logic
1. **Dynamic Timer & Players Ready**: The `WaitingRoomWidget` holds logic for displaying both "Players Ready: 7/10" and a countdown "00:30s". If the clock hits 0, it forces auto-advance.
2. **Tally Matrix Equation**: Because $P$ and $S$ are configurable, points are scaled so the EV stays relatively balanced. The points for guessing the Truth target is calculated as `ceil((P - 1) / (S + 1))`. Saboteurs get 1 point per vote on their fake. The Target gets 1 point per player that guessed them correctly.

## Pseudo Code

```dart
// 1. Shared Writing Screen with Countdown Lock
Widget buildWritePhase(GameState state, PlayerState me) {
  if (me.isReadyForNextRotation) {
    return Column(
      children: [
        Text("Holding tight..."),
        Text("Waiting for \${calculateUnready()} players"),
        TimerWidget(
          duration: 60,
          onComplete: () => triggerAutoAdvanceSystemIfHost() 
        )
      ]
    );
  }
  
  String targetId = state.currentCardAssignments[me.id];
  Card targetCard = state.cards.firstWhere((c) => c.targetPlayerId == targetId);
  bool isTruthRound = state.currentPhase == GamePhase.truth;
  
  return Column(
    children: [
       Text(isTruthRound ? "Write your Truth!" : "Write a Sabotage for \${targetCard.targetName}"),
       Text("Prompt: \${targetCard.promptText}"),
       TimerWidget(duration: 60, onComplete: submitPlaceholder), // Forces completion
       TextField(controller: _answerController),
       ElevatedButton(
         onPressed: () => submitAnswer(_answerController.text),
         child: Text("Submit"),
       )
    ]
  );
}

// 2. Voting Screen
Widget buildVotingPhase(GameState state, PlayerState me) {
   if (me.id == state.currentReaderId) {
      return ReaderLockoutWidget(targetCard: currentCard);
   }
   
   // S (sabotages) and 1 (truth) are dynamically size-scaled.
   return ListView.builder(
     itemCount: state.sabotageAnswersCount + 1, 
     itemBuilder: (context, idx) {
        return InkWell(
           onTap: () => castVote(shuffledAnswers[idx].id),
           child: Card(child: Text(shuffledAnswers[idx].text)),
        );
     }
   );
}

// 3. Dynamic Tallying Logic 
void calculateScores(GameState state, Card currentCard, Map<String, String> playerVotes) {
   
   // Voter Formula: ceil((TotalPlayers - 1) / (Sabotages + 1))
   // (e.g. 10 players, 3 sabotages -> (9/4) = 2.25 -> 3 Points)
   int voterPoints = ((state.totalPlayers - 1) / (state.sabotageAnswersCount + 1)).ceil();
   
   for (var voteEntry in playerVotes.entries) {
      String voterId = voteEntry.key;
      String votedForId = voteEntry.value; // ID of person who wrote it, or 'TRUTH'
      
      if (votedForId == 'TRUTH') {
          addPoints(voterId, voterPoints);
          addPoints(currentCard.targetPlayerId, 1);
      } else {
          addPoints(votedForId, 1); // Saboteur static point logic
      }
   }
}
}
```

## Verification Plan

### Evaluation of Score Scaling
We will execute a validation scratch script examining the `ceil((P-1)/(S+1))` scaling matrix. 
1. Given $P=4, S=2$, the Truth Reward must scale perfectly to `1`.
2. Given $P=10, S=3$, where guessing truth is harder among many sabotage cards, the Truth Reward must ceiling naturally to `3` to balance Expected Value (EV).

The codebase will not be committed until mathematical variance proves acceptable.

## Implementation Status (Phase 4 Completed)

### What has been accomplished:
- **Matrix Scoring Integration**: Completely rewrote `lib/utils/scoring_logic.dart` shifting from the legacy Trickster point system into the dynamic mapping formula required for Mimicry Edition.
- **Instructional Accuracy**: Fully rewrote the Lobby instructions in `lobby_screen.dart` to correctly describe Target/Reader roles, Sabotage mechanics, and the dynamic `ceil` scoring model.
- **Sequential Resolution Fix**: Resolved the navigation blocker in `Phase4RevealScreen` by adding a cross-phase bridge for `GamePhase.vote`. This allows the game to correctly loop back to the voting screen for subsequent card resolutions.
- **Debug Security**: Fixed the host-only guard in `Phase3VoteScreen`, ensuring that debug bot-submission buttons are correctly hidden from non-host players.
- **Auto-Advance Framework**: Implemented the `AutoAdvanceTimer` widget and integrated it into the Writing and Voting phases. The Host now has the authority to advance the game if the timer expires.

### Verification Done:
- **Math Verification Passed**: Validated $P=4, S=2$ and $P=10, S=3$ scoring scaling.
- **Timer Validation**: Confirmed that `AutoAdvanceTimer` correctly counts down and triggers advancements.
- **Navigation Stress Test**: Verified that 10-player games resolve all 10 cards sequentially without screen mounting errors.

### Places where there could be errors:
- **None currently identified.** (All critical UI blockers and legacy rule mismatches have been resolved).
