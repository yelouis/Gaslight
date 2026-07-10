# Agent Execution Guide — How to Resolve Bugs & Build Features in Gaslight

**You are an engineering agent picking up planned work on Gaslight (a Flutter + Firebase party game).** All the work has already been triaged, decided, and specified. Your job is to execute it faithfully, validate each change, and keep the docs honest. This guide tells you **where the plans are** and **the exact loop to follow**.

---

## 1. Where everything lives (the doc map)

Read these in this priority order. Paths are relative to the repo root.

| Purpose | Doc | When to read |
|---|---|---|
| **Required context** (what the game is, architecture, file map, the write-path constraint, build order) | `docs/implementation_plan_gameplay_and_ui.md` → **Section 0** | **First, once.** Applies to all work. |
| **The bug/fix plan** (Issues 1–11 + Clarifications 1–2; Waves A–C) | `docs/implementation_plan_selected_fixes.md` | Before doing any fix |
| **The feature + visual-redesign plan** (Proposals P1–P6; the UI identity; Waves D–E) | `docs/implementation_plan_gameplay_and_ui.md` | Before doing any feature/UI work |
| **Why each item exists** (triage, root cause, the user's chosen option) | `docs/ongoing_general_errors.md` | When you need the rationale behind a fix |
| **System design (source of truth for behavior)** | `docs/design_*.md` (`design_game_state_and_models.md`, `design_rotation_engine.md`, `design_scoring_and_ui.md`, `design_semantic_integrity.md`, `design_database_and_security.md`, `design_prompt_system.md`, `design_ui_direction.md`) | When an item names one; update it if behavior/looks change |
| **How to test flows manually** | `docs/e2e_testing_journeys.md` | For manual validation |
| **Doc/commit conventions you must follow** | `.agents/skills/` (see §2) | Throughout |

**Do not invent work.** Every task is already written as a numbered item (A1, A2 … B5, C0–C5, D1–D6, E1–E8) with file paths, steps, and validation. Execute those items.

---

## 2. Project conventions (follow these skills)

The repo defines its own working rules under `.agents/skills/`. Load and obey them:
- **`bug_documentation_guidelines/SKILL.md`** — the exact format for the Resolved / Unresolved sections in `ongoing_general_errors.md`. Use it whenever you edit that file.
- **`issue_resolution/SKILL.md`** — the workflow for taking an issue from Unresolved → implemented → Resolved. This guide's loop is built on it.
- **`resolved_issue_cleanup/SKILL.md`** — after a fix, verify it in code and fold behavior changes into the relevant `design_*.md`.
- **`commit_message_guidelines/SKILL.md`** — Conventional Commits (`fix:`, `feat:`, `docs:`, `refactor:`, …) with a "why"-focused body. Use for every commit.
- **`fixing_ui_issues/SKILL.md`** — principles for the Wave E visual work (use `Theme.of(context)` tokens, match the existing design language).

---

## 3. Prime directives (guardrails — violating these causes regressions)

1. **Follow the build order.** Bug **Wave A** → bug **Wave B** → features **Waves D–E** → bug **Wave C** (server migration) last. Within a wave, top to bottom. The order encodes real dependencies.
2. **Respect the write-path constraint** (`gameplay_and_ui.md` §0.5). Until Wave C ships, a **non-host client cannot write the room document.** Do **not** build a non-host room write before Wave C. Features that write only a player's **own** doc are fine now — each item is tagged ✅/⛔.
3. **Honor cross-item dependencies.** Notably: the metric-honor stats (bug plan **A6**) must exist before **D2** (Best-Forgery honor) and **D6** (share card). Each item lists its dependencies — check them first.
4. **Mirror rule changes into Wave C.** Any game-rule fix in Waves A/B (scoring, placeholders, honors) and any new mutation in Wave D must be re-implemented in the Cloud Functions during Wave C. Both plans have a "mirror into Wave C" checklist — keep it current.
5. **Preserve existing regression guards.** E.g. the `_advancedStateKeys` double-advance guard in `game_service.dart` (see Resolved issue #1 in `ongoing_general_errors.md`). Don't remove guards to make a change "simpler".
6. **Mind the testing blind spot.** Existing tests drive the game as **host + bots on a `FakeFirestore` that does not enforce security rules.** That path hides multiplayer/permission bugs. For anything touching multiplayer or writes, add a test that exercises a **non-host** path and, for Wave C, a **rules-enforcing emulator**.
7. **One item per change.** Don't batch unrelated items into one commit. Small, validated, reversible steps.

---

## 4. THE LOOP (repeat until the wave is done)

```
        ┌────────────────────────────────────────────────────────────┐
        │  ORIENT (once per session):                                 │
        │  • Read gameplay_and_ui.md §0  • Skim both plan docs         │
        │  • flutter pub get  • flutter test  → confirm a green base   │
        └───────────────────────────┬────────────────────────────────┘
                                     ▼
   ┌───────────────────────────────────────────────────────────────────┐
   │ (1) SELECT the next item in build order (A→B→D/E→C; top to bottom).│
   ├───────────────────────────────────────────────────────────────────┤
   │ (2) STUDY it: read the item's full spec + the design_*.md it       │
   │     references + the actual source files it names. Confirm its     │
   │     dependencies are already done and its write-path is allowed.   │
   ├───────────────────────────────────────────────────────────────────┤
   │ (3) IMPLEMENT exactly as specified. Use Theme tokens, match        │
   │     surrounding code style, keep existing guards intact.           │
   ├───────────────────────────────────────────────────────────────────┤
   │ (4) VALIDATE (all three, in order):                                │
   │     a. Write/run the item's automated validation (unit/widget).    │
   │     b. Run `flutter analyze` and `flutter test` → must be green.   │
   │     c. Do the item's manual check (see e2e_testing_journeys.md).   │
   ├───────────────────────────────────────────────────────────────────┤
   │ (5) BLOCKED? If the spec is wrong, impossible, or has bad side     │
   │     effects: STOP. Document the finding in ongoing_general_errors  │
   │     .md (per bug_documentation_guidelines) and ASK THE USER.       │
   │     Do not silently improvise a different design.                  │
   ├───────────────────────────────────────────────────────────────────┤
   │ (6) RECORD on success:                                             │
   │     • Bugs: move the issue Unresolved → Resolved in                │
   │       ongoing_general_errors.md (issue_resolution format).         │
   │     • Features/UI: mark the proposal/section delivered in          │
   │       ongoing_general_errors.md / design_ui_direction.md.          │
   │     • If behavior or visuals changed, update the matching          │
   │       design_*.md (resolved_issue_cleanup).                        │
   │     • If a new mutation was added, update the Wave C mirror list.  │
   ├───────────────────────────────────────────────────────────────────┤
   │ (7) COMMIT (Conventional Commits; explain the WHY in the body).    │
   └───────────────────────────────┬───────────────────────────────────┘
                                    ▼
                    More items in the wave?  ──yes──▶ back to (1)
                                    │no
                                    ▼
        Wave complete → run the wave's Definition of Done checklist,
        report status to the user, then proceed to the next wave.
```

### Step details

**(1) Select** — Take the next unfinished item in order. Never skip ahead across waves.

**(2) Study** — An item is only "ready" if its dependencies are done and its write-path is permitted *now*. If not, skip to the next *eligible* item in the same wave and note why (don't jump waves).

**(3) Implement** — Change only what the item specifies. Reuse existing widgets/utilities (`shared_ui.dart`, `PlayerAvatar`, `RotationEngine`, `ScoringLogic`). For Wave E, centralize colors in `lib/theme/app_colors.dart` (E1) before touching other visual items.

**(4) Validate** — A change is not done until: its own test passes, the full suite passes, `flutter analyze` is clean, and you've eyeballed the behavior. If the item says "two-client / emulator" (Wave C), that specific test is mandatory — a `FakeFirestore` pass is not sufficient.

**(5) Blocked** — Genuine conflicts get documented and escalated, not worked around. Add an entry under `## ⚠️ Unresolved Issues & Suggestions` describing the conflict + options, and ask.

**(6) Record** — The docs must always reflect reality. A fix isn't finished until the issue is moved to Resolved and any design doc it changed is updated.

**(7) Commit** — One item = one commit. Example:
```
fix(scoring): derive S from per-card forgery count

- Issue 5: scoring inflated to max reward after a forgery-phase
  disconnect because sabotageAnswersCount was mutated to 0.
- ScoringLogic now reads S = currentCard.sabotageAnswers.length so the
  truth reward always matches the options voters actually faced.
- sabotageAnswersCount stays a pure rotation-config value.
```

---

## 5. Definition of Done (per wave)

Each plan doc ends with a **Definition of Done** checklist for its waves — run it before declaring a wave complete. Baseline for every wave:
- `flutter analyze` clean; `flutter test` green; new tests added per item.
- Docs updated: issues moved to Resolved / proposals marked delivered; changed `design_*.md` files updated.
- No non-host room writes introduced before Wave C; own-doc-only features verified against current `firestore.rules`.
- Wave A/B/D rule changes and new mutations reflected in the Wave C mirror checklist.

---

## 6. Quick-start (TL;DR)
1. Read `docs/implementation_plan_gameplay_and_ui.md` **§0**.
2. Open `docs/implementation_plan_selected_fixes.md`, start at **Wave A, item A1**.
3. Run the loop in §4 for each item, in order, across the waves (A → B → D/E → C).
4. When blocked, stop and ask. When done, update the docs and commit.
