# End-to-End (E2E) Testing Journeys

This document defines the key user journeys in Gaslight and provides step-by-step manual and automated simulation instructions to test the E2E integrity of the game loop, role assignments, security, and disconnect handling.

---

## 🎮 Journey 1: Standard Happy Path (4-Player Competitive Game)

**Objective**: Verify the complete game loop from lobby setup to final scoreboard for 4 active players.

### 📋 Steps to Test:
1. **Player 1 (Host)**:
   - Launch the application.
   - Enter name `"Alice"` in the creation form.
   - Select `2 Rounds` of forgery.
   - Select avatar token, leave `"Disable Game Timers"` **off**.
   - Tap **CREATE ROOM**. Verify the room code is generated (e.g., `ABCD`) and the lobby screen renders.
2. **Players 2, 3, and 4 (Voters/Forgerers)**:
   - Launch application on separate emulators/devices.
   - Enter names `"Bob"`, `"Charlie"`, and `"Dave"`.
   - Enter the room code `ABCD` and tap **JOIN ROOM**.
   - Verify all 4 player tokens render in the host's lobby screen.
3. **Lobby & Start**:
   - Host selects `"The Daily Grind"` deck from the dropdown.
   - Host taps **START GAME**.
   - Verify all players are automatically navigated to `/craft` (the **FORGERY** phase screen).
4. **Forgery Phase (Rotation 1 of 2)**:
   - Verify the screen title is `"FORGERY"` (no phase number).
   - Verify the timer counts down in the AppBar.
   - Each player is shown a prompt belonging to a different player.
     - *Example*: Alice completes Dave's prompt.
   - Enter a response and tap **SUBMIT**. Verify the screen changes to `"THE INK DRIES…"` and indicates how many players are remaining.
5. **Forgery Phase (Rotation 2 of 2)**:
   - Once all 4 submit, verify all players advance to Rotation 2.
   - Each player completes a prompt for a different player than in Rotation 1.
   - Enter response and tap **SUBMIT**.
6. **Truth Phase**:
   - Verify the screen title is `"TRUTH"`.
   - Each player receives their *own* card back.
   - Enter the true response (e.g., Alice writes her actual bio truth) and tap **SUBMIT**.
7. **Voting Phase (Resolving Cards)**:
   - Verify all players transition to `/vote`. Title must display `"THE VOTE"`.
   - **Card 1 Resolution (e.g., Alice's Card)**:
     - Alice (Target/Reader) sees: `"THE PARLOR DELIBERATES…"` and subtitle: `"They are voting on your card. Keep a straight face."`
     - Bob, Charlie, Dave (Voters) see the prompt and a shuffled list of 3 options (Alice's Truth + Forgeries by Bob/Charlie).
     - Bob clicks the option corresponding to his own forgery. Verify that the option is disabled or his vote is rejected (Self-Vote Guard).
     - Bob, Charlie, and Dave select the correct Truth and tap submit.
     - Alice taps `"I'M READY"` to lock in.
   - **Reveal Phase (Card 1)**:
     - Verify transition to `/reveal` with the title `"THE REVEAL"`.
     - Verify the correct Truth is highlighted in green.
     - Verify other options show the names/avatars of players who forged them (e.g. `"FORGERY by Bob"`).
     - Verify avatars of players who voted for each option are rendered next to the answer text.
     - Verify points awarded display:
       - Voters who guessed truth: `+ceil((4-1)/(2+1)) = +1` point.
       - Target (Alice): `+1` point for each voter who found the truth.
     - Host (Alice) taps **CONTINUE** to move to Card 2.
   - Repeat the Voting/Reveal steps for Cards 2, 3, and 4.
8. **Game Over**:
   - After the 4th card, verify all players navigate to `/game-over` (the **GAME OVER** screen).
   - Verify the final honors (e.g., "The Mastermind", "The Trickster") are rendered correctly based on scores.
   - Tap **RETURN TO LOBBY**. Verify the screen transitions instantly back to the entry screen (`/`) with no freeze/stall.

---

## ⏱ Journey 2: Casual Mode (Disabled Game Timers)

**Objective**: Verify that disabling timers in the lobby successfully hides all timer countdowns and disables auto-advancement.

### 📋 Steps to Test:
1. **Lobby Setup**:
   - Host enters name `"Alice"`.
   - Toggle **Disable Game Timers** to **ON**.
   - Tap **CREATE ROOM**.
2. **Game Loop**:
   - Add bots using the `"DEBUG: ADD 9 BOTS"` button, then tap **START GAME**.
   - Verify the transition to the **FORGERY** phase.
   - **Check UI**: Look at the AppBar actions. Verify that the timer countdown widget is **hidden** (replaced with `SizedBox.shrink()`).
   - Leave the game inactive for more than 60 seconds. Verify that the screen **does not auto-advance** or force submit.
   - Host taps `"DEBUG: BOTS SUBMIT"` and submits their own forgery.
   - Proceed to **TRUTH** phase and **VOTING** phase. Verify that timers remain hidden throughout all screens.

---

## 👁 Journey 3: Mid-Game Spectator Join

**Objective**: Verify that late-joining players are assigned a Spectator role, do not block readiness, and see passive UI screens.

### 📋 Steps to Test:
1. **Match Start**:
   - Host creates a room and starts a 2-player match with 1 bot.
   - Advance the game to the **FORGERY** phase.
2. **Late Joiner**:
   - A new player `"Steve"` joins by typing the active room code.
   - Verify that Steve is immediately assigned the role `PlayerRole.spectator`.
   - Steve should be navigated directly to `/craft`.
   - **Check Steve's UI**: Verify Steve sees `"THE GALLERY"` with description `"You joined mid-game. Enjoy watching the match!"` and the game progress count (e.g. `"Players ready: 0 / 2"`). Steve has no prompt input field.
3. **Readiness Verification**:
   - Player 1 (Host) and the bot submit their forgery answers.
   - Verify that the game transitions to the next phase immediately once they are ready, **without** waiting for Steve.
4. **Voting Spec Mode**:
   - In the **VOTE** phase, verify Steve sees the spectating vote screen displaying who is being voted on, the prompt, and the vote progress, but cannot cast a vote.

---

## ⚡ Journey 4: Mid-Game Player Disconnect & Re-indexing

**Objective**: Verify host-driven recovery, card pruning, assignment bridging, and reader advancement when players drop out.

### 📋 Steps to Test:
1. **Sabotage Disconnect**:
   - Start a 4-player game (Host + 3 Bots).
   - In **FORGERY Rotation 1**:
     - Turn off Wi-Fi/Internet on the emulator running Bot 1, or simulate deletion of Bot 1's player document in the Firestore console.
     - Host listens to Firestore, detects Bot 1 has left, and triggers `handlePlayerDisconnect`.
     - **Verification**:
       - Verify the card owned by Bot 1 is removed from `GameState.cards` (total cards becomes 3).
       - Verify active card assignments are bridged. The player who was writing for Bot 1 is now reassigned to write for Bot 1's target.
       - Verify the remaining `rotationPlan` is dynamically recalculated.
2. **Voting Reader Disconnect**:
   - Advance the game to the **VOTE** phase.
   - Let Bot 2 be the active reader (`currentReaderId == Bot 2`).
   - Simulate a disconnection of Bot 2.
   - **Verification**:
     - Host prunes Bot 2, detects they were the active reader, and automatically shifts `currentReaderId` to the next active player.
     - Verify the screen refreshes to vote on the new reader's card.

---

## 🔍 Journey 5: Semantic Integrity Check (Similarity Filter)

**Objective**: Verify that players cannot submit synonym/redundant responses to cards.

### 📋 Steps to Test:
1. **Prompt Setup**:
   - In the **FORGERY** phase, target card has the prompt: `"My favorite way to spend a Saturday is..."`.
   - Player 1 submits `"sleeping in my bed all day"`.
2. **Duplicate Attack**:
   - Player 2 receives the same card in Rotation 2.
   - Player 2 types `"sleep all day in bed"` and taps **SUBMIT**.
3. **Verification**:
   - Verify the submission is blocked.
   - Verify a SnackBar displays error: `"Too similar to an existing answer! Be more creative."`
   - Verify the state remains unsubmitted so Player 2 must write a different answer.

---

## 🔍 Journey 6: Unmask the Forger (Revenge Guess Window)

**Objective**: Verify the Unmask the Forger gameplay mechanic, ensuring players who are fooled get one blind guess during the active reveal window, while others see a waiting status, followed by author reveals and REVENGE points updating.

### 📋 Steps to Test:
1. **Lobby & Setup**:
   - Host ("Alice") creates a room and Bob joins. Add 1 Bot ("Charlie").
   - Start the game. In Forgery phase, Bob receives Charlie's prompt and writes a forgery. Charlie's bot submits a forgery for Alice.
   - In Vote phase, Alice's card is resolved.
     - Charlie's forgery option: "lie A" (written by Bob).
     - Bob's forgery option: "lie B" (written by Charlie).
     - Alice's Truth: "truth A".
     - Bob votes for "truth A" (not fooled).
     - Charlie (bot) votes for "lie A" (fooled by Bob).
2. **Transition to Reveal**:
   - Alice (Host) taps "I'M READY" to submit.
   - Verify transition to `/reveal` (THE REVEAL).
   - **Beat 1 & 2 (0 - 3.6s)**: Vote chips land and the Truth option ("truth A") flips open.
   - **Beat 3 (Unmask Window)**:
     - Verify that the unmask guess tray displays for Charlie (the fooled bot) and Bob if they were fooled (since Bob voted TRUTH, he is not fooled).
     - Bob (not fooled) sees a status message: `"UNMASKING IN PROGRESS..."` and `"Fooled players are trying to unmask their forgers: Charlie: Thinking..."`.
     - Charlie (fooled bot) sees the accusation buttons listing candidates (Alice and Bob).
     - Since Charlie is a bot, the simulated bot submits a guess accusing Bob (the actual author of "lie A").
     - Verify that the timer counts down in the tray and the CONTINUE button is locked/opaque.
   - **Beat 4 (Post-Deadline)**:
     - Settle time past `unmaskDeadline`.
     - Verify the forgery author flips open to display `"FORGERY BY BOB"`.
     - Verify the `"REVENGE UNMASKING RESULTS"` section appears below the options showing `"Charlie accused Bob — SUCCESS! (+1)"`.
     - Verify that Bob's score stands updated by -1 and Charlie's by +1.
     - Verify that the CONTINUE button unlocks.

---

## 🎨 Journey 7: Custom Deck Contributions & Deal

**Objective**: Verify the Custom Decks mechanic where players submit custom prompts in the lobby, host selects Custom Deck, and prompts are harvested and dealt authority-correctly (under 3 prompts cap, own-prompt exclusion, fallback top-ups).

### 📋 Steps to Test:
1. **Lobby Contributions**:
   - Host ("Alice") creates a room and Bob joins.
   - In the lobby screen, Alice expands the "CONTRIBUTE PROMPTS" panel.
     - Alice writes 4 prompts: `"Prompt A"`, `"Prompt B"`, `"Prompt C"`, and `"Prompt D"`.
     - Bob expands his panel and writes 2 prompts: `"Prompt E"`, `"Prompt F"`.
   - Host (Alice) selects `"Custom Deck"` from the deck dropdown.
   - Verify the in-app contribution tracker displays `"Prompts: 6 contributed"` (aggregate count only).
2. **Start and Harvest**:
   - Alice taps **START GAME**.
   - **Server Harvest**:
     - Alice submitted 4 prompts, but only the first 3 valid ones (`Prompt A`, `Prompt B`, `Prompt C`) are harvested (enforcing the 3-per-player cap).
     - Bob submitted 2 prompts, so both are harvested (`Prompt E`, `Prompt F`).
     - Total pool size from contributions is 5.
     - Since 3 players are active (Alice, Bob, plus 1 bot Charlie), and the pool is shuffled and dealt, the pool size is sufficient.
   - **Own-Prompt Exclusion**:
     - Verify cards are dealt such that Alice never receives `Prompt A`, `Prompt B`, or `Prompt C`.
     - Verify Bob never receives `Prompt E` or `Prompt F`.
3. **Prompt Re-roll fallback**:
   - In Forgery phase, Alice clicks **RE-ROLL** on her prompt.
   - Verify that Alice's prompt is swapped with a fresh fallback prompt from `'the_daily_grind'` deck, rather than another custom prompt that might be hers.

---

## 🧪 E2E Simulation Automation Script

To run the automated E2E simulation script verifying E2E logic (including 10-player scaling, spectator joins, and mid-game disconnects), execute the following in the project root:

```bash
# Fetch dependencies
flutter pub get

# Execute E2E Simulation tests
flutter test test/simulation_test.dart
```
