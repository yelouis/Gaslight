# Agent Execution Guide — One Small Item: MF1 (verified July 16)

**You are an engineering agent picking up Gaslight (Flutter phone game, Android + iOS).** The July 16 verification of commit `d9ee136` confirmed the entire 13-item UI queue (UF1–UF3, M1–M5, V1–V5) **delivered and green** — with **one small remainder: MF1 below** (an M5 sub-item, already authorized under Option A; no user input needed). Implement it, then the queue is empty.

## 1. Verified baseline (July 16 — re-run before starting)
`flutter analyze` **0 errors** · `flutter test` **48/48** · `cd functions && npm run build` clean · `npm --prefix functions test` **28/28** (backend untouched by any UI work — must stay 28/28).

Delivered and verified — do **not** rework: portrait lock (M1) · textScaler clamp 1.0–1.3 + elasticity (M3) · 48 dp hit areas (M4) · lobby scrollable sheet + pinned action bar (M2) · vote/reveal thumb bars + craft's **deliberate** in-flow SUBMIT (M5) · zero `CircularProgressIndicator` (V4) · reaction medallions with unchanged emoji wire format (V5) · one-at-a-time living sigils (V2) · deck dossier carousel with 400 ms debounce (V3) · the Raven on its five perches (V1) · ceremony order/sounds/gating, ballot caption + quiet stamp, inkwell + pinned header (UF1–3).

**Standing rules:** design tokens only (`AppColors` / `AppTextStyles` / `AppMotion` / `ThematicIcon` / `WaxSealBadge`); every layout validated at **360×640 dp portrait** (`tester.view.physicalSize`, `takeException() == null`); reduce-motion (`AppMotion.reduce`) path for every animation; never touch `functions/` or game logic for UI work.

---

## 2. MF1 · Pin the game-over footer (the M5 remainder) — `lib/screens/game_over_screen.dart`

**The gap:** `Share Case File` and `RETURN TO LOBBY` currently live **inside** the ceremony's `SingleChildScrollView` — on a 360×640 phone the player must scroll past the plaques to reach them. M5's spec: they belong in a **pinned bottom action bar** with the ceremony scrolling behind.

**Implementation (exact):**
1. Add `bottomNavigationBar:` to the game-over `Scaffold`: `SafeArea(minimum: EdgeInsets.fromLTRB(24, 12, 24, 12), child: <bar>)` using **the same bar recipe as the lobby's M2 bar** (container: `AppColors.ground`, top border 1 dp `brass @0.25`, `BoxShadow(black @0.4, blur 8, offset (0, −2))`).
2. Bar content — `Column(mainAxisSize: min)`:
   - The share button, **moved unchanged**: same `ElevatedButton.icon` with its existing UF1 gating (`_ceremonyComplete` → disabled + `'Engraving…'`), `_isSharing` ink-dot state, and `envelope` icon.
   - 8 dp gap, then `RETURN TO LOBBY` (the existing `TextButton`, unchanged styling).
3. **Remove both** from the scrolled `Column` in the body. The body keeps: `Stack[EmberBackdrop, SafeArea(scroll view with the RepaintBoundary ceremony)]` — embers and the share-capture boundary are untouched (the bar is outside the `RepaintBoundary`, so the Case File image is unaffected).
4. Give the scroll view `padding: EdgeInsets.fromLTRB(24, 24, 24, 12)` (bottom shrinks since the bar now owns that space).

**Validation:**
- Widget test at **360×640** with 4 honors: `Share Case File` and `RETURN TO LOBBY` are visible **without scrolling** (`find` inside `bottomNavigationBar`); the ceremony still staggers per UF1 (existing tests untouched); share disabled/`'Engraving…'` until `_ceremonyComplete` — asserted **in the bar**; `takeException() == null`.
- Existing `game_over_screen_test.dart` assertions all still pass (only placement moved; behavior identical).
- Manual: gesture-nav phone — the bar clears the home indicator; the Case File share image contains no bar.

Commit: `fix(ui): pin game-over actions in bottom bar (MF1)` — then run the full battery.

---

## 3. After MF1 — the queue is EMPTY. Do not invent work.
1. **RECORD:** in `ongoing_general_errors.md`, update the Unresolved header ("MF1 closed, <date>") and the M-audit note; confirm `design_ui_direction.md` §10 still reads SHIPPED.
2. Act again **only** on: a new filled `Your selection:` line in `ongoing_general_errors.md` (implement per its chosen option — write a detailed spec first if it's UI), or a **battery regression** on a fresh checkout (triage → file with options per `bug_documentation_guidelines` → fix).
3. Otherwise report the queue complete and stop. Do not refactor working, tested code for its own sake.

## 4. Definition of Done
- [ ] MF1: both actions in a pinned `SafeArea` bar (M2 recipe); body scroll behind; `RepaintBoundary`/embers untouched; 360×640 test proves no-scroll visibility; UF1 gating asserted in the bar.
- [ ] Battery: `flutter analyze` 0 · `flutter test` green · functions build clean · emulator 28/28.
- [ ] Docs: MF1 closed in `ongoing_general_errors.md`.
