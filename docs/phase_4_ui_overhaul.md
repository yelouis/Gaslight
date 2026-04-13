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
- **Matrix Scoring Integration**: Completely rewrote `lib/utils/scoring_logic.dart` shifting from the legacy Trickster point system into the dynamic mapping formula `calculateScores` required for Mimicry Edition. It allocates truth voters, targets, and successful saboteurs safely using the verified `ceil` formula.
- **Component Stubbing**: Validated that `Phase1SabotageScreen` handles the Timer/Null mapping decoupling successfully while we wait on future extensive graphic design passes. Phase 4's primary logical blockers are resolved natively as reusable util widgets alongside the UI stubs built in Phase 1.

### Verification Done:
- **Math Verification Passed**: A standalone eval validated the $P=4, S=2$ constraint and scaled the $P=10, S=3$ ceiling to 3 exactly as requested by the EV balancing. 

### Things to review:
- **Countdown Tick**: To prevent out-of-sync Timer drifts in `buildWritePhase` when 12+ clients are playing simultaneously, it is strongly advised to migrate the actual countdown metric to a single `endTime` Timestamp on the Firestore `GameState` document rather than executing local timers universally in the upcoming UI.

### Places where there could be errors:
- **Null Safety in Legacy Vode Screen**: `phase2_craft`, `phase3_vote`, etc. represent blank slates right now to compile. I strongly recommend generating new `.dart` files purely focused on `CardModel` state injection when the visual UI designer takes over later.
