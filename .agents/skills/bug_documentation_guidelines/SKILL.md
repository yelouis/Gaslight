---
name: Bug Documentation Style Guide
description: A strict style guide for documenting resolved bugs, refinements, and unresolved limitations in the Gaslight project. Follow this to maintain a consistent and machine-readable engineering history.
---

# Bug and Refinement Documentation Style Guide

This style guide defines how technical issues, bug fixes, and future suggestions MUST be documented in the Gaslight project's documentation (specifically [ongoing_general_errors.md](../../../docs/ongoing_general_errors.md)). Following this guide ensures that the repository history is transparent, actionable, and easily parsed by both humans and AI agents.

## 1. Resolved Issues & Implementation Refinements

This section is for work that has been completed, verified, and merged.

### Mandatory Structure
- **Heading**: Use `## 🧪 Resolved Issues & Implementation Refinements`.
- **Status Indicator**: Every item MUST include the resolution date in the format: `(Resolved - Month DD)`.
- **Level**: Use numbered lists for individual entries.
- **Problem/Solution Pattern**: Each entry MUST use the following sub-bullets:
    - `**Problem**`: Detailed technical root cause or failure mode.
    - `**Solution**`: Detailed specific technical fix or architectural change.

### Style Constraints
- **Detail**: Provide a comprehensive and detailed description of the problem, explaining the technical root cause, domain constraints, and the impact on the system. Avoid overly brief summaries.
- **Specificity**: Name specific files, methods, error types, or environment constraints (e.g., `game_service.dart`, Firestore snapshots).
- **No Fluff**: Avoid generic phrases like "Fixed a bug." State exactly what was broken and how it was fixed.

---

## 2. Unresolved Issues & Suggestions

This section is for active limitations, known bugs that aren't yet fixed, and architectural debt. It MUST provide actionable remediation paths for the user to choose from.

### Mandatory Structure
- **Heading**: Use `## ⚠️ Unresolved Issues & Suggestions`.
- **Issue Headings**: Use `### Issue [Number]: [Title]`.
- **Status Line**: Start with `**Status**: ⚠️ Confirmed Unresolved — [Description and verification details]`.
- **Remediation Options**: Provide a reasonable amount of detailed options (Option A, Option B, etc.). If it is an easy issue, one option is enough but if it is a hard issue, offer more solutions.
- **Recommendation**: Label the preferred approach with `(recommended)`.
- **Pros/Cons**: Each option MUST include a bulleted list of `Pros` and `Cons`.
- **Selection Line**: End each issue block with `Your selection: _____`.
- **Separation**: Use `---` horizontal rules between multiple issues.

### Style Constraints
- **Technical Transparency**: The Status line must explain *why* the issue is still unresolved (e.g., "Verified in game_service.dart (lines X-Y)").
- **Detailed Trade-offs**: Pros and Cons should be technical and specific (e.g., "Increases database read frequency," "Requires SharedPreferences migrations").
- **No Placeholders**: Do not use vague options. Every option must be a viable technical implementation path.

---

## 3. Formatting Examples (The "Look and Feel")

### Correct Example for Resolved Issues:
```markdown
## 🧪 Resolved Issues & Implementation Refinements

1. **Bot Readiness Bottleneck (Resolved - April 15)**:
   - **Problem**: `GameService.setPlayerReady` was hardcoded to only update the local `_currentPlayerId`, which blocked bot advancement during E2E simulation.
   - **Solution**: Modified `setPlayerReady` to accept an optional `playerId`, allowing the simulation and bots to correctly signal readiness.
```

### Correct Example for Unresolved Issues:
```markdown
## ⚠️ Unresolved Issues & Suggestions

### Issue 1: Firestore Listener Leaks
**Status**: ⚠️ Confirmed Unresolved — Verified in `game_service.dart` (lines 119-133): `GameService.listenToRoom()` subscribes to Firestore snapshots but never stores or cancels the subscriptions.

**Option A (recommended)**: **Track Subscriptions in Fields** — Store the subscriptions in private class variables (`_roomSub`, `_playersSub`) and cancel them before starting a new listener and during dispose.
  - *Pros*: Completely fixes the memory and state leak; relatively low complexity.
  - *Cons*: Must ensure all entry points (e.g., room change, game reset) correctly invoke cancellation.

**Option B**: **Refactor to StreamBuilder** — Move listeners to the UI level using Flutter's `StreamBuilder` widget.
  - *Pros*: Delegates subscription lifecycle management to Flutter's widget tree.
  - *Cons*: Requires massive refactoring of `GameService` state architecture.

Your selection: _____
```

## 4. Enforcement Guidelines
- **Audit Requirement**: Before closing a task, Antigravity MUST check [ongoing_general_errors.md](../../../docs/ongoing_general_errors.md) to ensure it aligns with this style guide.
- **Redundancy**: If a task spans multiple files, update the most relevant document and cross-reference if necessary.
