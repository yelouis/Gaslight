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
```
