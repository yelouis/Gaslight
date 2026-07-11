# Agent Execution Guide — Remaining Work (post-verification, July 10)

**You are an engineering agent picking up Gaslight (Flutter + Firebase party game) after a verification pass.** Most of the planned work is already done and verified. This guide tells you **exactly what remains**, in priority order, and the loop to follow. Do **not** re-do finished work.

---

## 1. Current state (verified July 10)

A code + compile verification (`flutter analyze`: 0 errors, lint-only warnings) confirmed the following is **DONE and correct**:

- **Bug fixes Issues 2–11 + Clarifications 1–2** — all implemented; moved to the Resolved section of `docs/ongoing_general_errors.md` (entries 26–36). Includes per-card scoring, timeout placeholders, instant readiness, spectator-safe counters/honors, metric-based honors, start-game feedback, disconnect idempotency, join-order host handoff, and the interim rejoin-identity guard.
- **Gameplay Proposals P1–P6** — implemented (leaderboard, reveal drama + card-flip, reactions, re-roll, lobby warmth, share). See the "Delivered" summary in `ongoing_general_errors.md`.
- **UI foundation** — palette tokens (`lib/theme/app_colors.dart`), bundled fonts (Cormorant + Lora), lamp-pool background (`lib/widgets/atmosphere_background.dart`), and the concealment/card-flip reveal motif.

**What REMAINS (your job):**

| # | Remaining work | Where it's specified | Size |
|---|---|---|---|
| **R1** | **Issue 12** — fix the P3 reactions `setState`-during-`build` runtime error | `ongoing_general_errors.md` → Issue 12 | Small |
| **R2** | **Issue 1 (+ durable Issue 11)** — the server-authoritative Cloud Functions migration | `implementation_plan_selected_fixes.md` → **Wave C** | Large |
| **R3** | **UI polish** — finish Wave E items not yet done (icons confirmed missing; audit the rest) | `implementation_plan_gameplay_and_ui.md` → **Wave E** (E5–E8) | Medium |

Do them **in this order** (R1 → R2 → R3). R1 is a quick correctness win; R2 is the last real blocker for multiplayer and must be done before shipping; R3 is polish.

---

## 2. Where the docs are (read as needed)

| Purpose | Doc |
|---|---|
| **Required context** (game, architecture, file map, the write-path constraint) | `docs/implementation_plan_gameplay_and_ui.md` → **Section 0** — read first |
| The remaining bug (Issue 12) + the still-open Issue 1 | `docs/ongoing_general_errors.md` (Unresolved section) |
| The server-migration plan | `docs/implementation_plan_selected_fixes.md` → **Wave C** |
| The UI polish plan | `docs/implementation_plan_gameplay_and_ui.md` → **Wave E** |
| System behavior (source of truth) | `docs/design_*.md` |
| Manual test flows | `docs/e2e_testing_journeys.md` |
| Doc/commit conventions | `.agents/skills/` (`bug_documentation_guidelines`, `issue_resolution`, `resolved_issue_cleanup`, `commit_message_guidelines`, `fixing_ui_issues`) |

---

## 3. The remaining work, in detail

### R1 — Fix Issue 12 (P3 reactions crash) · do first
- **Problem:** `_checkForNewReactions(gs.players)` is called inside `build()` in `lib/screens/phase4_reveal.dart` (~line 255) and calls `setState` when a new reaction arrives → "setState() called during build" error.
- **Do:** implement **Option A** from Issue 12 — move the detection into `WidgetsBinding.instance.addPostFrameCallback` (or a `GameService` listener registered in `initState`) so the `setState` runs after the frame.
- **Validate:** widget test that pumps a player-doc update with a newer `lastReactionAt` while the Reveal is mounted; assert no `FlutterError` and one floating emoji appears. Manual: two clients, fire reactions rapidly, no red frames.
- **On success:** move Issue 12 to the Resolved section (issue_resolution format) and commit `fix(reveal): defer reaction detection out of build`.

### R2 — Wave C: server-authoritative migration (Issue 1 + durable Issue 11) · the big one
Follow `implementation_plan_selected_fixes.md` **Wave C** (C0–C5) exactly. Summary of what it entails:
- **C0** scaffold Cloud Functions (TypeScript) + Firebase Emulator Suite (Auth+Firestore+Functions); move the Gemini key server-side.
- **C1** port the room mutations to callable functions (`submitAnswer`, `castVote`, `setReady`, `advancePhase`, `startGame`, `handleDisconnect`) and port `rotation_engine.dart` + `scoring_logic.dart` to TS.
- **C2** lock down `firestore.rules`: deny client writes to `/rooms/{code}`; players may write only cosmetic self-fields.
- **C3** refactor `GameService` mutation methods into thin callable wrappers; keep the read/stream path unchanged.
- **C4** validation: **two-client emulator integration test** (host + joiner both submit/vote/ready and the game advances) + rules unit tests proving a client cannot tamper with `totalScore`/other players/room.
- **C5** durable **Issue 11**: stable per-device UUID `playerId` + `authUid` on the player doc, validated server-side (replaces the interim rejoin guard).

**CRITICAL — mirror the already-shipped rules into the functions** (they currently live in the Dart client and must be reproduced server-side, or they'll be lost):
- Per-card `S` scoring + saboteur "Sharp Eye" bonus (from `scoring_logic.dart`).
- Timeout placeholder fill (`kMissingAnswerPlaceholder`).
- Honor-stat accumulation (`timesFooled`, `playersDeceived`) in the scoring step.
- Disconnect idempotency; join-order host handoff.
- The P3 `sendReaction` and P4 `rerollMyPrompt` mutations (decide: keep `sendReaction` as an own-doc write, move `rerollMyPrompt` to a callable — it writes the room doc, so **P4 is non-functional for non-host players until this lands**).

### R3 — UI polish: finish Wave E (E5–E8)
Audit against `implementation_plan_gameplay_and_ui.md` **Wave E** and finish what's missing. Confirmed status:
- **E6 (icons) — NOT done.** Stock Material icons remain (`Icons.remove_red_eye`, `Icons.timer`, `Icons.vpn_key`, `Icons.casino`, `Icons.lightbulb_outline` in `phase2_craft.dart`, `phase3_vote.dart`, `auto_advance_timer.dart`, `player_avatar.dart`). Replace with the thematic set per E6.
- **E5 / E7 / E8 — verify each sub-item** (button stamp feel, avatar bevel + active-reader halo, timer lamp flicker, sound/haptics + mute toggle, contrast/tabular-figures audit) and implement any not present. Reduce-motion is already honored in the card flip — extend the same guard to any new animation.

---

## 4. THE LOOP (repeat per work item)

```
   ORIENT once: read gameplay_and_ui.md §0 · flutter pub get · flutter analyze (confirm 0 errors baseline)
        │
        ▼
  (1) SELECT the next item in priority order: R1 → R2 (C0…C5) → R3.
  (2) STUDY its spec + the design_*.md it touches + the named source files.
  (3) IMPLEMENT exactly as specified. Reuse tokens (app_colors.dart), keep existing
      guards (_advancedStateKeys, _disconnectsInFlight). For Wave C, mirror the shipped
      Dart rules into the functions — do not drop them.
  (4) VALIDATE: write/run the item's test → `flutter analyze` + `flutter test` green →
      manual check. For Wave C, the two-client EMULATOR test is mandatory (a FakeFirestore
      pass does NOT count — that harness hides the exact permission bug being fixed).
  (5) BLOCKED / spec wrong / impossible? STOP. Document it in ongoing_general_errors.md
      (bug_documentation_guidelines format, with options) and ASK THE USER. Don't improvise.
  (6) RECORD: move the resolved item Unresolved → Resolved with a what-was-solved note;
      update the matching design_*.md if behavior/looks changed.
  (7) COMMIT (Conventional Commits; explain WHY in the body). One item = one commit.
        │
        ▼
   More items? → back to (1).  Wave/priority done? → run its Definition of Done, report to user.
```

---

## 5. Guardrails
1. **Order matters:** R1 (quick) → R2 (unblocks real multiplayer) → R3 (polish).
2. **The write-path constraint is still live until R2 lands.** Today only the host can write the room doc; non-host humans still get `PERMISSION_DENIED` on submit/vote/ready. This is exactly what R2 fixes. Until then, do not assume non-host multiplayer works.
3. **Mirror, don't drop.** Every game-rule fix already shipped in Dart (scoring, placeholders, honors, disconnect, host handoff) must be reproduced in the Cloud Functions during R2.
4. **Beat the testing blind spot.** Existing tests run host + bots on a `FakeFirestore` that ignores security rules. For R2, add rules-enforcing **emulator** tests with a real non-host client — that path is the one that has never been exercised.
5. **Preserve guards.** Don't remove `_advancedStateKeys` (double-advance) or `_disconnectsInFlight` (disconnect idempotency) to simplify code.
6. **Ask when it's genuinely the user's call** (e.g., latency/cost trade-offs in the Functions design, or a spec that turns out wrong) — file a bug with options rather than guessing.

---

## 6. Definition of Done (remaining work)
- [ ] **R1:** Issue 12 fixed; reactions animate with no build-phase `setState`; moved to Resolved.
- [ ] **R2:** two-client emulator test proves a non-host can submit/vote/ready and the game advances; rules unit tests prove clients can't tamper with scores/other players/room; all shipped Dart rules mirrored in functions; Gemini key server-side; durable Issue 11 (stable ID) in place. Issue 1 + Issue 11 moved to Resolved.
- [ ] **R3:** Wave E audit complete; E6 icons replaced; remaining E5/E7/E8 items done or explicitly deferred with a note; reduce-motion honored everywhere.
- [ ] `flutter analyze` clean; `flutter test` green; docs updated (issues moved, design docs synced); commits are one-item Conventional Commits.

---

## 7. Quick-start (TL;DR)
1. Read `docs/implementation_plan_gameplay_and_ui.md` **§0**.
2. **R1:** fix Issue 12 (defer reactions out of `build`).
3. **R2:** execute `implementation_plan_selected_fixes.md` **Wave C** (C0→C5), mirroring the shipped rules and adding the two-client emulator test.
4. **R3:** finish Wave E polish (start with E6 icons).
5. Run the loop in §4 per item; when blocked, stop and ask; when done, update docs and commit.
