---
name: Resolved Issue Cleanup and Design Update
description: Reviews resolved issues in Gaslight, verifies their implementation in code, and cleans up docs/ongoing_general_errors.md by integrating design/UI updates into the main documentation.
---

# Resolved Issue Cleanup and Design Update

This skill systematically reviews the "Resolved Issues & Implementation Refinements" section of Gaslight's `docs/ongoing_general_errors.md` file, verifies the resolutions against the codebase, and integrates design or architectural updates into the main system documentation.

## 📋 Pre-requisites
1. Access to the [docs/ongoing_general_errors.md](file:///Users/louisye/Desktop/Louis Y./Gaslight/docs/ongoing_general_errors.md) file.
2. Access to the Gaslight codebase (e.g. `lib/services/`, `lib/screens/`, `test/`).
3. Flutter SDK environment to run tests and verify correctness.

## 🛠 Workflow Steps

### 1. Issue Review
- Go through the `## 🧪 Resolved Issues & Implementation Refinements` section of `docs/ongoing_general_errors.md`.
- Read the problem, solution, and phase-specific implications for each resolved issue.

### 2. Code Verification
- Verify in the codebase that the described fix is correctly implemented. For example:
  - Check that Phase 2 spectator logic renders correctly in `Phase2CraftScreen` and does not block ready state transitions in `GameService.evaluateReadyState`.
  - Check that Phase 3 spectator logic and voting progress calculations operate correctly in `Phase3VoteScreen` without exposing votes.
  - Check that dynamic disconnect handling bridges card assignments and recalculates sabotage rotations cleanly under `GameService.handlePlayerDisconnect`.
  - Verify that `firestore.rules` is present and matches the security rules definition.
- Run all tests to verify that there are no regressions:
  ```bash
  flutter test
  ```

### 3. Context & Retention Evaluation
- Evaluate if the resolved issue highlights a structural pitfall or regression risk (e.g. race conditions in phase transitions, Firestore listener leaks, stale shuffled states).
- **Decision:** If the issue has high future reference value, **keep** the issue in the `Resolved Issues & Implementation Refinements` section of `docs/ongoing_general_errors.md`.

### 4. Design & UI Integration
- If the issue modifies core system behavior or screen flows:
  - Locate the corresponding system design layer document under `docs/` (`design_prompt_system.md`, `design_game_state_and_models.md`, `design_rotation_engine.md`, `design_semantic_integrity.md`, `design_scoring_and_ui.md`, `design_database_and_security.md`) and update it to reflect the new system behavior.
  - Clearly state *why* the design was updated (e.g. why we bridge card assignments on disconnect in `design_rotation_engine.md`, or why we use Firestore auth rules instead of raw writes in `design_database_and_security.md`) so that subsequent modifications do not introduce regressions.
- If it is a minor fix (e.g., formatting issues, simple SnackBar display adjustments) and does not require system-level design updates, it is slated for cleanup.

### 5. Cleanup
- Once a resolved issue's design updates are fully documented, **delete** or **archive** it from the active list in `docs/ongoing_general_errors.md` to keep the file highly legible and relevant.

## 🏁 Success Criteria
- All resolved issues are verified in the codebase.
- System design changes are documented in the corresponding system design layer documents with explanations preventing regressions.
- The `docs/ongoing_general_errors.md` file remains clean, focused, and free of redundant historical entries.
