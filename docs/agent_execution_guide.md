# Agent Execution Guide — Active Build: Task T4 → Task T5 (August 7, 2026)

**You are an engineering agent picking up Gaslight (Flutter party game, iOS + Android, server-authoritative Firebase backend). Assume you have no memory of this project.**

**Approved work — two items, in this order:**

| # | Item | Scope | Source |
|---|---|---|---|
| 1 | **Task T4** — replace the gas-lantern logo mascot with the crow | `lib/widgets/lobby_logo.dart` + delete one asset | User request |
| 2 | **Task T5** — expand the crow's pose vocabulary and wire poses to game moments | `lib/` + new art + tests | User request |

Nothing else is approved. Both specs are complete in §2 and §3.

**T4 first** — it is small, it removes a 251 KB asset, and it makes the crow the app's face before T5 gives it more to do.

> ### ✅ Issue 34 resolved — T5 uses a shared pose helper (Option A)
>
> The trigger plumbing was a decision in its own right, filed as Issue 34, and the user selected **Option A: one shared helper that owns the whole pose lifecycle, with the "only once" key as a required argument.** That helper is specified in **§3, Step 1**, and every trigger in T5 must go through it. Do not hand-copy the old per-screen block — replacing it is the point.

**Specs are decisions, not suggestions.** **A blocker is a filing event, not a licence to re-choose on the user's behalf.**

**Line numbers are anchors measured August 7, 2026** — re-grep rather than trusting them.

---

## Standing constraints

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**.
2. **Design tokens are law.** `AppColors`, `AppTextStyles`, `AppMotion`. No raw hex in widget code, no ad-hoc `Duration` — use `AppMotion.fast` (180 ms), `.standard` (300 ms), `.emphasis` (600 ms).
3. **Every animation needs an `AppMotion.reduce(context)` path** — skip the motion entirely, do not play it faster.
4. **Text scale clamped 1.0–1.3.** **Touch targets ≥ 48 dp** (M4).
5. **Neither item touches `functions/` or `firestore.rules`**, so the emulator suite is not a gate — but run it before the final commit to prove no drift.
6. **One item = one commit**, Conventional Commits, WHY in the body.

---

## 1. Verified baseline — the regression bar

| Gate | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze lib test` | **0 errors** |
| Client tests | `flutter test` | **77/77 pass** |
| Functions build | `npm --prefix functions run build` | clean |
| Backend E2E | `npm --prefix functions test` | **31/31** |
| iOS release | `flutter build ios --release --no-codesign` | succeeds, `Runner.app` **44.0 MB** |

### ⚠️ Five traps that have each cost a cycle

1. **Analyzer scope.** Run `flutter analyze lib test`, **never bare `flutter analyze`** — the bare form reports ~678 errors from vendored plugin source under gitignored `build/`.
2. **Analyze ≠ compile.** Only `flutter test` or `flutter build` surfaces a broken dependency.
3. **Working directory persists** between Bash calls. Use absolute paths or `npm --prefix functions run build`.
4. **BSD `sed` does not support `\b`** — it silently matches nothing and exits 0. Use `python3`.
5. **`Image.asset` loads no bytes under `flutter test`.** Widget tests render `Image` widgets with no pixels, so `find.byType(Image)` counts them whether or not the art exists, and a golden render of the mascot comes out **blank**. **Anything about how art looks must be verified by decoding the PNG (see `test/helpers/png_decoder.dart`) or on a simulator.**

---

## 2. Task T4 — Make the crow the logo mascot

**What this means for the user:** the entry screen's playing-card logo currently shows a gas lantern character. It becomes the crow, so the app has one mascot instead of two competing ones.

### Current state
`lib/widgets/lobby_logo.dart:84` is the **only** reference to `assets/images/gaslight_mascot.png` anywhere in the repo — verified across `.dart`, `.yaml` and `.md`. The image is **251 KB**, which is larger than the entire raven asset set (68 KB for twelve files).

The mascot sits inside an Ace-of-spades card: an 80×100 `Container` whose `BoxDecoration` carries a **lamplight flicker glow** driven by `_flickerController`, wrapping a `ClipRRect(borderRadius: 12)` around `Image.asset(..., fit: BoxFit.cover)`.

### Implementation

**Step 1 — swap the widget.** Replace the `ClipRRect` + `Image.asset` with `RavenMascot`:

```dart
child: const RavenMascot(state: RavenState.idle, size: 80),
```

- **Use `RavenState.idle`**, not `sleep`. `idle` carries the random blink and head-tilt behaviour, so the logo reads as alive rather than a static picture. This is the app's first screen — it should breathe.
- **Import** `../widgets/raven_mascot.dart` in `lobby_logo.dart`.

**Step 2 — fix the aspect ratio.** `RavenMascot` renders square (`size` sets both width and height), but the container is **80×100**. Change the `Container` to `width: 80, height: 80` so the glow stays circular around the bird and no space is letterboxed. If this visibly unbalances the card, prefer keeping the container at 100 tall and centring an 80 dp mascot inside it — but do **not** stretch the mascot to 80×100.

**Step 3 — keep the flicker glow.** The `AnimatedBuilder` + `_flickerController` + `BoxShadow` stay exactly as they are. That warm pulsing halo is the "gas lamp" motif from `design_ui_direction.md` §5 and is the main thing carrying the lantern's identity forward. Removing the lantern image should not remove the lamplight.

**Step 4 — drop the `ClipRRect`.** It exists to round the corners of a rectangular photo. The crow is already transparent-background art with its own silhouette; clipping it to a rounded box can only cut the rim.

**Step 5 — delete the asset.** `rm assets/images/gaslight_mascot.png`. `pubspec.yaml` globs `assets/images/` as a directory, so **no pubspec change is needed** — but confirm the file is gone from the built bundle in validation. Do not leave it orphaned "just in case"; it is 251 KB and git has it in history.

### Validation

1. **Widget test** in `test/` — pump `AnimatedLobbyLogo` and assert:
   - `find.byType(RavenMascot)` finds one widget;
   - no `Image` widget in the logo subtree has an `AssetImage` whose `assetName` contains `gaslight_mascot`. **This is the falsifying assertion** — it fails today.
2. **Asset is really gone from the bundle** — after a release build:
   ```bash
   find build/ios/iphoneos/Runner.app -name "gaslight_mascot.png"   # must return NOTHING
   ```
   A widget swap that leaves the file shipping saves nothing.
3. **Measure the size delta.** `du -sh build/ios/iphoneos/Runner.app` against the **44.0 MB** baseline; expect roughly **−251 KB**. Record the actual number — do not restate this estimate (a spec once estimated 275 dp where the truth was 593).
4. **Simulator check.** The logo is the first thing on the entry screen:
   ```bash
   flutter build ios --simulator --debug
   xcrun simctl install booted build/ios/iphonesimulator/Runner.app
   xcrun simctl launch booted com.whylabs.gaslight
   xcrun simctl io booted screenshot /tmp/logo.png
   ```
   Confirm the crow sits inside the card, the flicker halo still pulses behind it, and the rim is not clipped.

### 🚦 Approval gate — this BLOCKS the commit
**Show the user the screenshot and get explicit approval before committing.** This is the app's logo. Issue 32's artwork shipped unseen because this step sat in a checklist rather than blocking, and a hollow bird was the result.

### Blast radius
`lib/widgets/lobby_logo.dart`, deletion of `assets/images/gaslight_mascot.png`, one new widget test. Nothing else.

---

## 3. Task T5 — Expand the pose vocabulary and wire poses to game moments

**What this means for the user:** the crow currently has five poses and reacts at three moments. It gains reactions at the moments that actually matter — someone joining, a vote being sealed, being fooled, fooling someone, the truth landing — so it feels like it is watching the game rather than decorating it.

### The existing pattern — follow it exactly

Four screens already drive the mascot through a `_ravenState` field, firing a pose then reverting. The idiom, verbatim from `phase3_vote.dart:296`:

```dart
if (shouldHop && !AppMotion.reduce(context)) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _ravenHopTimer?.cancel();
    setState(() { _ravenState = RavenState.hop; });
    _ravenHopTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) { setState(() { _ravenState = RavenState.idle; }); }
    });
  });
}
```

This block gets **replaced** by the shared helper in Step 1. It is reproduced here because the helper must preserve all four of its safety properties — the **`AppMotion.reduce` guard**, the **post-frame callback**, a **cancellable timer**, and the **`mounted` check** — plus a fifth the old block leaves to each caller: a **"only once" key**. The game state streams from Firestore and rebuilds constantly, so a bare `if (condition)` re-fires the pose on every rebuild while the condition holds. Existing hand-rolled examples: `_playedRevealForTargetId` (`phase4_reveal.dart:307`) and `_knownPlayerIds` (`lobby_screen.dart:341`).

### Step 1 — build the shared pose helper (Issue 34, Option A)

Create `lib/widgets/raven_pose_host.dart` — a mixin on `State` that every mascot-bearing screen adopts:

```dart
mixin RavenPoseHost<T extends StatefulWidget> on State<T> {
  RavenState _resting = RavenState.idle;
  RavenState _pose = RavenState.idle;
  Timer? _poseTimer;
  final Set<String> _firedKeys = <String>{};

  /// The pose the crow returns to. Lobby sets this to `sleep` until players arrive.
  set ravenResting(RavenState p) { ... }   // also re-points _pose if currently resting
  RavenState get ravenPose => _pose;

  /// Play [pose] once per distinct [onceKey], then return to resting.
  void playRavenPose(RavenState pose, {required String onceKey, Duration? hold}) { ... }

  @override
  void dispose() { _poseTimer?.cancel(); super.dispose(); }
}
```

**`playRavenPose` must, in this order:**
1. Return immediately if `_firedKeys` already contains `onceKey`; otherwise add it. **Do this before the reduced-motion check**, so the "have we reacted to this yet" bookkeeping is identical in both modes and tests behave the same way with motion on or off.
2. Return if `AppMotion.reduce(context)` — skip the motion entirely, never play it faster.
3. `WidgetsBinding.instance.addPostFrameCallback`, then re-check `mounted`. Doing this inside the helper is what lets callers invoke it straight from `build()` without a "setState during build" crash — the ergonomic reason this refactor pays for itself.
4. Cancel `_poseTimer`, `setState` the pose.
5. Start a new `_poseTimer` for `hold ?? _defaultHold(pose)`, which on completion re-checks `mounted` and reverts to `_resting`.

**`onceKey` is a required named argument.** That is the entire point of Option A: the subtlest of the three failure modes — a forgotten de-duplication key, invisible in code review and visible only as the bird machine-gunning on device — becomes something the code will not compile without.

**Key naming and unboundedness.** Namespace keys by trigger: `'join:$playerId'`, `'reveal:$targetCardId'`, `'vote:$cardId'`. `_firedKeys` grows with distinct events, which is bounded in practice (players per room, cards per game) — a game cannot generate unbounded keys. **Do not** add eviction logic; it would reintroduce the re-fire bug it was meant to prevent.

**Default hold durations** live in one table in the helper, from the §3 pose spec, using `AppMotion` tokens.

### Step 2 — migrate the four existing screens

`lobby_screen.dart:43`, `phase3_vote.dart:47`, `phase4_reveal.dart:62` and `game_over_screen.dart` each drop their `_ravenState` field, their `_raven*Timer`, and their hand-rolled block, adopting the mixin and passing `ravenPose` to `RavenMascot`. The lobby sets `ravenResting = RavenState.sleep` until players arrive, then `idle` (`lobby_screen.dart:320`).

Their existing de-dup guards become `onceKey` values: `_playedRevealForTargetId` → `onceKey: 'reveal:$targetId'`; the `_knownPlayerIds` delta → `onceKey: 'join:$playerId'`. **Delete the now-redundant fields** — leaving both mechanisms in place means two sources of truth about whether an event fired.

### ⚠️ Known limitation of Option A — handle it at the call site

Option A deliberately has **no priority arbitration** (that was Option C, not selected). Within a single frame, the last `playRavenPose` call wins. This only bites on `phase4_reveal.dart`, where `preen`, `startle` and `bow` can all be true in the same beat.

**Mitigation, and it costs nothing:** on the reveal screen, chain the three triggers as `if / else if / else if` so exactly one fires per beat, ordered **`startle` → `preen` → `bow`** — being fooled is the sharpest reaction and should win, then fooling someone, then the ceremonial bow. Put a comment naming Issue 34 Option C as the upgrade path if this ever needs to be smarter.

Current state fields: `lobby_screen.dart:43` (`sleep`), `phase3_vote.dart:47` (`idle`), `phase4_reveal.dart:62` (`idle`), `game_over_screen.dart`. `phase2_craft.dart:304` passes a `const RavenState.idle` and has no state field yet.

### Tier 1 — five new poses, NO new art required

All five are achievable with the existing four layers by transform alone. Add to the `RavenState` enum and implement in `raven_mascot.dart`'s `AnimatedBuilder`, alongside the existing `scaleX/scaleY/translate/headTilt/wingFlare` maths.

| Pose | Moment | Motion | Duration |
|---|---|---|---|
| `alert` | **A player joins the lobby.** Hook: `lobby_screen.dart:341` already compares `_knownPlayerIds` against the current ids — fire when the count *increases*. | Snap the body 10° toward the roster, hold ~80 ms, ease back. Force `eye_open` for the whole pose. | `AppMotion.standard` (300 ms) |
| `peck` | **Vote confirmed** — pairs with the wax-seal stamp, the signature micro-interaction in `design_ui_direction.md` §5. | Rotate body forward-and-down 18° over the first 40%, snap back over the remainder. Sharp in, soft out (`Curves.easeOutBack`). | `AppMotion.fast` (180 ms) |
| `preen` | **Reveal: you fooled someone.** | Wing rotates up ~25° to meet the body, body tilts 8° toward the wing, hold, both return. Smug, unhurried. | `AppMotion.emphasis` (600 ms) |
| `startle` | **Reveal: you were fooled.** | Scale to 1.08 and translate up 0.10 × size over 120 ms, wing flares 14°, then settle with a small overshoot. | `AppMotion.standard` (300 ms) |
| `bow` | **The Truth is revealed**, and again on the game-over honours. | Slow forward rotation to 22°, hold 150 ms, slow return. Deliberate — this is the ceremony beat. | `AppMotion.emphasis` (600 ms) |

**Resting pose stays `idle` everywhere except the lobby**, which keeps `sleep` until players arrive (`lobby_screen.dart:320`).

### Tier 2 — two new art layers, for the two poses transforms cannot fake

A closed silhouette cannot open its beak or raise its wing to a genuinely different shape. These two need new assets.

| Pose | Moment | New layer | Motion |
|---|---|---|---|
| `caw` | **The game starts** (host presses START GAME) and at each new round. | `beak_open.png` | Swap `body` → `body` + `beak_open` overlay for 160 ms while the body scales 1.04 and tilts back 6°, as if calling. |
| `flap` (upgrade of `fly`) | **Game over — the winner is announced.** | `wing_up.png` | Alternate `wing.png` / `wing_up.png` every 110 ms for three cycles while translating up 0.15 × size. A real two-frame flap instead of the current single-wing rotation. |

**Generation brief — append to `assets/images/raven/PROMPTS.md`.** The same shared-canvas rule that governs the existing four layers applies, and it is the thing most likely to be got wrong:

> **`beak_open.png`** — Using the supplied `body.png` as an exact reference, output only the crow's **lower beak, dropped open** as if calling, on the same transparent canvas at the same scale and position. The upper beak, head and body must be erased to full transparency — this layer overlays the unchanged body. Match the existing brass `#C6A14B` outline weight and the dark `#2E2A26` fill. Do not redraw, re-centre or re-scale anything.
>
> **`wing_up.png`** — Using the supplied `wing.png` as an exact reference, output the **same wing raised to roughly 40° above its resting angle**, pivoting from the shoulder where it meets the body. Same canvas, same scale, same shoulder position, same colours and outline weight. Only the wing's angle changes.

Deliver both at 768×768 and downscale to 512 and 256, exactly as the existing layers. Keep the palette to colours already in the set so the PNGs stay palette-indexed and small.

**Scope note:** Tier 1 is self-contained and needs no art. If Tier 2's generation proves unreliable, **ship Tier 1 and file Tier 2 separately** rather than blocking — say so in the commit body.

### Where each pose fires

| Screen | Trigger | Pose |
|---|---|---|
| `lobby_screen.dart` | player count increases (`_knownPlayerIds` at `:341`) | `alert` |
| `lobby_screen.dart` | host presses START GAME | `caw` |
| `phase3_vote.dart` | vote confirmed (existing hop site, `:296`) | `peck` (replaces `hop`) |
| `phase4_reveal.dart` | this player fooled someone (existing ruffle site, `:314`) | `preen` |
| `phase4_reveal.dart` | this player was fooled | `startle` |
| `phase4_reveal.dart` | the Truth card is revealed | `bow` |
| `game_over_screen.dart` | winner announced | `flap`, then `bow` |

`phase2_craft.dart:304` currently passes a `const` state — leave it as resting `idle` unless adding a state field there is trivial.

### Validation

**Unit-level, in `test/raven_mascot_test.dart`** — extend the existing per-pose contract tests (T3 established the pattern of asserting real transforms and asset paths, not just widget counts):

1. **Every `RavenState` value renders without exception** at `size: 64`. Drive this off `RavenState.values` so a future pose cannot be added without a test.
2. **Each new pose produces a non-identity transform mid-animation** and settles back. Read matrices via `tester.widgetList<Transform>(...)`; assert not-identity at mid-pump and identity (or resting) at completion. **A test that only asserts "no exception" would pass with the animation removed** — that is exactly the decoration T3 was created to eliminate.
3. **`caw` renders `beak_open.png`; `flap` alternates `wing.png` and `wing_up.png`.** Assert on `AssetImage.assetName`, as T3 does for `eye_open` / `eye_closed`.
4. **Reduced motion:** for **every** pose, with `AppMotion.reduce == true`, the tree is identical across two pumps 500 ms apart. This is the over-reach guard — it is easy to add a pose and forget its reduce path.
5. **New Tier 2 assets** pass the T3 asset battery: 256/512/768 dimensions, real alpha, and bounding boxes contained within `body.png`'s.

**Screen-level** — for at least the `alert` and `peck` triggers, a widget test that drives the real condition (a player appearing in the roster; a vote being confirmed) and asserts `_ravenState` changed. Firing a pose from a test hook proves nothing about whether the game moment actually reaches it.

**Timer hygiene:** pump each screen away mid-pose and assert no exception — proving every new `Timer` is cancelled in `dispose()`.

**Simulator pass:** play one full loop across three simulators (§5) and confirm each pose fires at its moment and none stick. A pose that never reverts is the most likely runtime bug here, and no unit test will catch a stuck state as convincingly as watching it.

### 🚦 Approval gate — this BLOCKS the commit
Tier 2 introduces **new artwork**. Capture it on a simulator and get the user's explicit approval before committing, same as T4.

### Blast radius
`lib/widgets/raven_mascot.dart` (enum + transform maths), `lib/screens/{lobby_screen,phase3_vote,phase4_reveal,game_over_screen}.dart` (triggers + timer disposal), new `assets/images/raven/{beak_open,wing_up}.png` at three densities, `assets/images/raven/PROMPTS.md`, `test/raven_mascot_test.dart`.

**Note this breaks the Issue 32 freeze deliberately:** that spec froze `RavenMascot`'s API and the five call sites so an art change could not become a five-screen refactor. T5 *is* the sanctioned change to those call sites. The constructor signature (`state`, `size`) still must not change — only the enum grows.

---

## 4. Validation standard

**For a fix: write validation that fails against the broken state, and observe it fail.** Issue 31 is the model — rebuilt from pre-fix source, the suite reported `expected null to equal 3` and `expected 'INTERNAL' to equal 'FAILED_PRECONDITION'`. **Record the observed failure output in the Resolved entry.**

**A test's name is not a test.** Issue 32 shipped `'…rim contrast >= 4.5:1'` asserting only that a file was non-empty. Before trusting a test, read its body. Before writing one, ask what change would make it fail — if the answer is "almost nothing", it is decoration.

**Some correctness is invisible to the harness.** `Image.asset` loads nothing under `flutter test`. Verify artefacts directly — `test/helpers/png_decoder.dart` exists for this — or on a simulator.

**Do not tune a threshold to make a test pass.** Report the measured number and say the guard failed.

Pair every fix assertion with an **over-reach guard**.

---

## 5. Running 3 simulators for multiplayer testing

Bots are server-seeded documents and never exercise the non-host **client** path — use real simulator clients for anything that must be correct.

```bash
xcrun simctl boot "iPhone 17"; xcrun simctl boot "iPhone 17 Pro"; xcrun simctl boot "iPhone Air"; open -a Simulator
```
```bash
flutter build ios --simulator --debug
```
```bash
for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl install "$U" build/ios/iphonesimulator/Runner.app; xcrun simctl launch "$U" com.whylabs.gaslight; done
```

Must be `--debug`: `lobby_screen.dart:87` passes `debugEnabled: kDebugMode`, and the server refuses debug calls when false. **DEBUG: ADD 9 BOTS** is host-only and adds 9 unconditionally.

---

## 6. `.gitignore` — rules that must never be removed

**Decision rule.** (1) Secret, or identifies a developer's machine/account? → **ignore, always.** (2) Would a fresh clone fail or build differently without it? → **commit.**

| Rule | Guards |
|---|---|
| `.env` | Firebase API keys + `USE_EMULATOR`. Bundled into the IPA. |
| `**/google-services.json` · `**/GoogleService-Info.plist` | Firebase config. The plist is required on disk to build, never committed. |
| `/build/`, `.dart_tool/` | Generated. Source of the phantom analyzer errors in §1. |
| `functions/node_modules/`, `functions/lib/` | Installed and compiled output. |
| `**/ios/Flutter/Generated.xcconfig`, `flutter_export_environment.sh` | Absolute paths to the local Flutter SDK. |
| `*.log`, `firebase-debug.log`, `firestore-debug.log` | Emulator logs; can contain room data and UIDs. |

**Must stay tracked:** the vendored Phosphor font + `LICENSE`, all raven PNGs + `PROMPTS.md`, `.firebaserc`, `ios/Podfile.lock`, both `xcshareddata/swiftpm/Package.resolved`. After adding art, confirm with `git status` that the new PNGs are staged — a silently-ignored asset is a blank bird on every other machine.

**Trap: `.swiftpm/` does not match `swiftpm/`** — the real Xcode paths have no leading dot.

---

## 7. Already delivered — do NOT rework

**Issues 1–33, Tasks T1–T3.** Points bearing on current work:
- **Issue 32/33** — mascot is four layered PNGs on a shared 256×256 canvas, body filled to 44.9% coverage behind a brass rim at 7.70:1 contrast. Regeneration prompts in `assets/images/raven/PROMPTS.md`.
- **Task T3** — `test/helpers/png_decoder.dart` decodes palette-indexed PNGs and computes WCAG contrast; the asset test asserts dimensions, alpha, rim contrast ≥ 4.5:1 and bounding-box containment. **Reuse this for any new art.**
- **Issue 31** — settings no longer wipe each other; `startGame` throws a readable `failed-precondition`. Live in production. The server uses loose `!= null` — **do not "simplify" to a falsy check**: `false` and `0` are legitimate values.
- **Issue 23/29** — 11 functional glyphs from a **vendored** Phosphor Light font. `phosphor_flutter` **can never be used** — `IconData` is a `final class`; proven twice.
- **Issue 24** — entry form fits 360×640 (was 593 dp over). **Issue 26** — roster sheet header drag works. **Issue 27/30** — one House Rules panel; `Family-Friendly Decks Only` is host-only. **T2** — `cupertino_icons` deliberately absent.

**Release plumbing — do not revert:** bundle ID `com.whylabs.gaslight` everywhere · Firebase iOS app `1:184580940908:ios:e79d100cc1231a8f022449`, project `gaslight-46368` · iOS deployment target **15.0** · Node **22** · `ITSAppUsesNonExemptEncryption = false` · `GoogleService-Info.plist` required on disk but gitignored · `.env` ships in the IPA so **`USE_EMULATOR` must be `false`** for testers.

---

## 8. Accepted equivalents — do NOT "fix" back

- **Craft SUBMIT is in-flow** under the text field (M5); **Vote's CONFIRM** is bottom-anchored via `Expanded`+`SafeArea`.
- **Reactions send raw emoji strings**; medallions are render-side only (V5).
- **Entry-form logo uses `SizedBox(height: 60)` + `FittedBox`**, not `Transform.scale`.
- **`isSmallHeight` uses a `< 700` dp breakpoint with a 6/8/12/16/20 spacing scale.**
- **House Rules non-host gating uses `IgnorePointer` + `Opacity(0.5)`.**
- **Forgery Rounds uses `Wrap(spacing: 6)`.** The caption reads `Only the host can modify house rules.`
- **The mascot's head tilt is whole-body, and `lowerBeakOpen` was dropped** as a painter parameter (Issue 32). T5's `caw` reintroduces the *effect* via a new art layer, not by restoring the old parameter.

---

## 9. Intentional decisions / invariants — do NOT change

- **Server-authoritative:** clients read Firestore streams; **all** mutations go through callables; `firestore.rules` denies client room writes.
- **Portrait-locked on phones**; **text scale clamped 1.0–1.3** (M3).
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically in `functions/src/text_similarity.ts` ↔ `lib/utils/text_similarity.dart`.
- **The `_advancedStateKeys` / once-per-event guards** survive Firestore-stream rebuilds — **never remove them.** Every new pose trigger must be equally rebuild-safe.
- **`ThematicIcon` is the single public icon entry point.**
- **`_familyFriendlyOnly` is client-local and never synced.**
- **`RavenMascot`'s constructor signature (`state`, `size`) is fixed.** T5 grows the enum; it must not change the constructor.
- **"Forgery Rounds" maps to `sabotageAnswersCount`.**

---

## 10. Where the contracts live

**`ongoing_general_errors.md` was consolidated on August 7** from 903 lines to ~140. It is now the live queue plus the lessons that still bite — **not** a full history. Full history is `git log`; the design consequences were moved into the contracts below. Do not re-expand it with delivered work; record outcomes in the design doc that owns the behaviour.

| What | Where |
|---|---|
| Open queue, selections, live engineering traps | `docs/ongoing_general_errors.md` (§1 queue, §2 traps, §3 deliberately-not-built) |
| Full history of any resolved item | `git log` |
| Backend write contract, security rules, identity | `design_database_and_security.md` — **§7 is the `null` ≠ absent contract from Issue 31** |
| Card passing, disconnect recalc, input validation | `design_rotation_engine.md` §5 |
| Scoring, routing, gameplay programme P1–P11 | `design_scoring_and_ui.md` §4 |
| Palette, typography, motif, icons, mascot, UI programme | `design_ui_direction.md` — §5 motif, §7 icons + `final class IconData`, §10 delivered programme, mascot block. **T4 changes the app's mascot, so the mascot block and §5 must be updated.** |
| Prompt decks | `design_prompt_system.md` · **Duplicate answers** `design_semantic_integrity.md` |
| Mascot art prompts | `assets/images/raven/PROMPTS.md` — **T5 appends the two new layer briefs here.** |
| PNG decoding / contrast helper | `test/helpers/png_decoder.dart` |
| Manual playtest journeys | `e2e_testing_journeys.md` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 11. Feedback loop — what past specs got wrong

- **A test's name is not a test.** Issue 32 shipped a contrast test that only checked a file was non-empty — the exact guard for the bug being fixed, absent while reading as present.
- **Approval gates get skipped under momentum.** Issue 32's artwork shipped unseen because sign-off lived in a checklist. Both T4 and T5 now state the gate inline, in the implementation section, marked as blocking.
- **A cross-language `undefined` check is not a null check.** Issue 31's TypeScript guard failed because the Dart client sends explicit `null`, and the TypeScript test suite structurally could not produce the failing payload.
- **Resolution is not compilation.** A package that resolves may still fail to build.
- **A "no X exists" claim must be grepped across the whole feature.**
- **Layout overflow must be measured, not estimated** — estimated ~275 dp, measured **593 dp**.
- **A ruling is only as durable as the test that pins it.**
- **Some correctness is invisible to the harness.** Verify the artefact directly.

---

## THE LOOP

```
(1) STUDY the item here + the design_*.md contract it touches + the exact files
    at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified.
(3) VALIDATE per §4. Observe the falsifying test fail against the broken state.
    For anything the harness cannot see, decode the artefact or check a simulator.
    Then the full §1 battery.
(4) BLOCKED or impossible? STOP. File it in ongoing_general_errors.md with options
    and a `Your selection: _____` line. Do NOT re-choose on the user's behalf.
(5) RECORD: move to Resolved (Problem / Solution / Validation) including observed
    failure output and measured numbers. Sync any design doc whose behaviour changed.
(6) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **T4:** `lobby_logo.dart` renders `RavenMascot(state: idle)`; the flicker glow is preserved; `ClipRRect` removed; container no longer letterboxes.
- [ ] `assets/images/gaslight_mascot.png` deleted; `find build/ios/iphoneos/Runner.app -name "gaslight_mascot.png"` returns nothing.
- [ ] Widget test asserts the logo contains `RavenMascot` and no `gaslight_mascot` asset — **observed to fail** before the change.
- [ ] App-size delta measured against the 44.0 MB baseline and recorded (expect ≈ −251 KB).
- [ ] **🚦 User approved the new logo from a simulator screenshot, before the commit.**
- [ ] **T5:** Tier 1 poses `alert`, `peck`, `preen`, `startle`, `bow` implemented with the specified durations and `AppMotion` tokens.
- [ ] Tier 2 `caw` + `flap` implemented with `beak_open.png` and `wing_up.png` at three densities, passing the T3 asset battery; or explicitly deferred and filed.
- [ ] **Issue 34 Option A:** `lib/widgets/raven_pose_host.dart` exists; `onceKey` is a **required** argument; all four screens migrated to it with their hand-rolled timers and de-dup fields deleted.
- [ ] Helper tests: a repeated `onceKey` fires exactly once; a new key fires again; reduced motion plays nothing but still consumes the key; the pose reverts to the screen's resting pose; disposal mid-pose throws nothing.
- [ ] Reveal screen chains `startle`/`preen`/`bow` as `if / else if` so only one fires per beat.
- [ ] Every pose fires at its specified moment, guarded by `AppMotion.reduce`, post-frame, cancellable, `mounted`-checked, and cancelled in `dispose()`.
- [ ] Tests driven off `RavenState.values` so a future pose cannot skip coverage; non-identity transform asserted mid-animation for each; reduced-motion static-frame guard for **every** pose.
- [ ] Screen-level tests drive the real trigger conditions for at least `alert` and `peck`.
- [ ] Three-simulator playthrough confirms every pose fires and none stick.
- [ ] **🚦 User approved the Tier 2 artwork, before the commit.**
- [ ] `assets/images/raven/PROMPTS.md` updated with both new layer briefs; `design_ui_direction.md` §5 updated to record the crow as the app mascot.
- [ ] Full battery: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 77 + new** · functions build clean · `npm --prefix functions test` **31/31**.
- [ ] Two commits, one per task. This guide rewritten to **Queue Complete** or the next queue.
