# Agent Execution Guide — Active Build: Issue 31 → Issue 32 (August 7, 2026)

**You are an engineering agent picking up Gaslight (Flutter party game, iOS + Android, server-authoritative Firebase backend). Assume you have no memory of this project.**

**Approved work — two items, in this order:**

| # | Item | Scope | Selected |
|---|---|---|---|
| 1 | **Issue 31** — settings wipe each other; START GAME then crashes | `lib/` + `functions/` + tests + **redeploy** | Option A |
| 2 | **Issue 32** — replace the raven with new simple-mascot artwork | new assets + `lib/widgets/raven_mascot.dart` + tests | Option D (user-authored) |

Nothing else is approved. Both specs are complete in §3 and §4.

**Issue 31 is a live production defect that makes the game unstartable after any settings change.** Do it first.

**Specs are decisions, not suggestions.** Every hex value, threshold, and file path below is deliberate.

**If something turns out to be impossible, STOP and file it** in `ongoing_general_errors.md` with options and a `Your selection: _____` line. **A blocker is a filing event, not a licence to re-choose on the user's behalf.**

**Line numbers are anchors measured August 7, 2026** and drift as you edit — re-grep rather than trusting them.

---

## Standing constraints

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**.
2. **Design tokens are law.** `AppColors`, `AppTextStyles`, `AppMotion`, `ThematicIcon`, `WaxSealBadge`. No raw hex in widget code, no ad-hoc `Duration`, no one-off `TextStyle`.
3. **Every animation needs an `AppMotion.reduce(context)` path** — jump to a static end state instead of animating.
4. **Text scale clamped 1.0–1.3** (`main.dart:81–88`). Layouts must survive 1.3.
5. **Touch targets ≥ 48 dp** (M4).
6. **Issue 31 touches `functions/`, so the emulator suite is a required gate and a redeploy is required.** Issue 32 does not touch the backend.
7. **One item = one commit**, Conventional Commits, WHY in the body.

---

## 1. Verified baseline — the regression bar

| Gate | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze lib test` | **0 errors** |
| Client tests | `flutter test` | **65/65 pass** |
| Functions build | `npm --prefix functions run build` | clean |
| Backend E2E | `npm --prefix functions test` | **28/28** |
| iOS release | `flutter build ios --release --no-codesign` | succeeds, `Runner.app` **44.0 MB** |

### ⚠️ Four traps that have each cost a cycle

1. **Analyzer scope.** Run `flutter analyze lib test`, **never bare `flutter analyze`** — the bare form reports ~678 errors from vendored plugin source under `build/`, which is gitignored and not yours to fix.
2. **Analyze ≠ compile.** `flutter analyze` does not analyse dependency source; it once reported 0 errors with a package installed that could not build. Only `flutter test` or `flutter build` surfaces that.
3. **Working directory persists** between Bash calls. Use absolute paths or `npm --prefix functions run build`.
4. **BSD `sed` does not support `\b`** — it silently matches nothing and still exits 0. Use `python3` for word boundaries.

---

## 2. Execution order

| # | Item | Position rationale |
|---|---|---|
| 1 | **Issue 31** | Live defect: any settings change bricks START GAME. It also needs a functions redeploy, so getting it out first means the deployed backend is healthy while the (client-only) art work proceeds. |
| 2 | **Issue 32** | Client-only and gated on human art approval, so it can take as long as it takes without leaving a broken game deployed. |

---

## 3. Issue 31 — Settings wipe each other, then START GAME crashes (Option A)

**What this means for the user:** change the deck and your timer setting and round count are silently erased — not reverted, *erased*. Then START GAME dies with an unreadable `INTERNAL` error, because a game with no round count has no card-passing plan.

### Root cause — already diagnosed, do not re-investigate

`lib/services/game_service.dart:361–368` sends **all three** settings on every call, filling untouched ones with Dart `null`:

```dart
await _functions.httpsCallable('updateLobbySettings').call({
  'roomCode': _gameState!.roomCode,
  'sabotageAnswersCount': sabotageAnswersCount,   // null when not being changed
  'isTimerDisabled': isTimerDisabled,             // null when not being changed
  'selectedDeckId': selectedDeckId,
});
```

`functions/src/index.ts:1006–1008` skips fields that are `undefined`. **A Dart `null` arrives as JSON `null`, and `null !== undefined` is `true`** — so the nulls are written over the stored values.

Two consequences:
1. `isTimerDisabled` → `null` → falsy → the toggle reads as off. Symmetric: changing rounds wipes the timer, changing the timer wipes the rounds.
2. `sabotageAnswersCount` → `null` → in `functions/src/rotation_engine.ts`, the guard at `:7` evaluates `3 <= null` → `false`, so it does **not** throw; the loop at `:15` runs `r <= null` → zero iterations → returns `{}`. `startGame` then reads `stringRotations["1"]` → `undefined` → Firestore rejects the write:
   ```
   Cannot use "undefined" as a Firestore value (found in field "currentCardAssignments")
   ```
   The player sees only `[firebase_functions/internal] INTERNAL`.

### Implementation — four changes

**Step 1 — client stops sending nulls.** `lib/services/game_service.dart:361`. Build the payload conditionally:

```dart
Future<void> updateLobbySettings({int? sabotageAnswersCount, bool? isTimerDisabled, String? selectedDeckId}) async {
  if (_gameState == null || currentPlayer?.isHost != true) return;
  // Only send what is actually being changed. Sending nulls for untouched
  // fields is what erased them (Issue 31).
  final payload = <String, dynamic>{'roomCode': _gameState!.roomCode};
  if (sabotageAnswersCount != null) payload['sabotageAnswersCount'] = sabotageAnswersCount;
  if (isTimerDisabled != null) payload['isTimerDisabled'] = isTimerDisabled;
  if (selectedDeckId != null) payload['selectedDeckId'] = selectedDeckId;
  await _functions.httpsCallable('updateLobbySettings').call(payload);
}
```

**Step 2 — server treats null as absent.** `functions/src/index.ts:1006–1008`. Change the three `!== undefined` guards to `!= null`:

```ts
sabotageAnswersCount: sabotageAnswersCount != null ? sabotageAnswersCount : data.sabotageAnswersCount,
isTimerDisabled:      isTimerDisabled      != null ? isTimerDisabled      : data.isTimerDisabled,
selectedDeckId:       selectedDeckId       != null ? selectedDeckId       : (data.selectedDeckId || "the_daily_grind"),
```

**Use loose `!= null` deliberately** — in TypeScript it means "neither `null` nor `undefined`" and is the idiomatic guard here. Do **not** substitute a falsy check (`if (x)`): `isTimerDisabled: false` and `sabotageAnswersCount: 0` are legitimate values that a falsy check would discard, re-creating this bug in a new shape. `false != null` and `0 != null` are both `true`, which is exactly what is wanted.

**Step 3 — make the failure loud in `startGame`.** In `functions/src/index.ts`, before calling `RotationEngine.generateRotations` (currently around `:360`), validate and throw a *readable* error:

```ts
const rounds = room.sabotageAnswersCount;
if (!Number.isInteger(rounds) || rounds < 1) {
  throw new HttpsError(
    "failed-precondition",
    `This room has an invalid forgery-round count (${JSON.stringify(rounds)}). Re-set the house rules, then start again.`,
  );
}
```

`HttpsError` is what reaches the client as a readable message; a raw `Error` is flattened to `INTERNAL`, which is why the original bug was so opaque. This is the difference between a five-minute diagnosis and a log dig.

**Step 4 — harden the rotation engine.** `functions/src/rotation_engine.ts`, before the existing guard at `:7`:

```ts
if (!Number.isInteger(sabotageRounds) || sabotageRounds < 1) {
  throw new Error(`sabotageRounds must be a positive integer, received: ${JSON.stringify(sabotageRounds)}`);
}
```

Defence in depth — Step 3 is what the player sees, this is what stops the engine ever again silently returning `{}` for a nonsense input.

### Validation

**The falsifying test must send a literal `null`.** This is the whole point: the existing 28/28 suite calls the callable from TypeScript (`functions/test/game_e2e.spec.ts:643`) where an omitted key genuinely *is* `undefined`, so it structurally cannot reproduce the failure. A test that merely omits the field will pass against the broken backend and prove nothing.

Add to `functions/test/game_e2e.spec.ts`:

1. **Null does not erase.** Set `isTimerDisabled: true` and `sabotageAnswersCount: 3`. Then call `updateLobbySettings` with `{ roomCode, selectedDeckId: 'x', sabotageAnswersCount: null, isTimerDisabled: null }` — explicit nulls. Assert the stored room still has `isTimerDisabled === true` and `sabotageAnswersCount === 3`, and that the deck changed. **This fails against today's backend** — it is the falsifying assertion.
2. **False and zero survive.** Call with `isTimerDisabled: false`. Assert the stored value is `false`, not the previous `true`. This is the over-reach guard: it fails if someone "fixes" Step 2 with a falsy check instead of `!= null`.
3. **Bad round count fails readably.** Write a room doc with `sabotageAnswersCount: null`, call `startGame`, and assert the error code is `failed-precondition` **and not `internal`**, with a message mentioning the round count.

Add to the Dart side (`test/`, alongside the existing lobby tests):

4. **Client omits untouched keys.** Call `gs.updateLobbySettings(selectedDeckId: 'x')` against the fake and assert the recorded payload contains exactly `roomCode` and `selectedDeckId` — and specifically that it does **not** contain the keys `sabotageAnswersCount` or `isTimerDisabled`. `test/fake_functions.dart` may need to record the last payload; add that if it does not already.

**Gate and ship:**
```bash
npm --prefix functions run build && npm --prefix functions test   # 28/28 + new, all green
flutter analyze lib test && flutter test
npx firebase-tools deploy --only functions
```

**Manual confirmation on 3 simulators** (boot per §6): host turns timers off, sets rounds to 4, then scrolls to a different deck. Timer must stay off and rounds stay 4. Then START GAME must succeed. Before the fix this is exactly the sequence that bricks it.

**No data migration** — rooms are created fresh per game.

### Blast radius
`lib/services/game_service.dart` · `functions/src/index.ts` (two sites: `updateLobbySettings`, `startGame`) · `functions/src/rotation_engine.ts` · `functions/test/game_e2e.spec.ts` · one Dart test · `test/fake_functions.dart` if payload recording is missing. **Requires a functions redeploy.**

---

## 4. Issue 32 — New simple-mascot crow artwork (Option D, user-authored)

**What this means for the user:** the current bird is both invisible and, in their words, not good-looking. It is replaced with new artwork in a bold, simple mascot style — *Among Us*-simple but clearly a crow, fitting the gaslight theme — while keeping the five poses it animates through.

### The gap
`lib/widgets/raven_mascot.dart` fills the body with `Color(0xFF171310)` (lines **293, 307, 323, 406**) on `AppColors.ground` `#14110E`. Measured contrast **1.02:1**, where **1.00 is identical**. Only the brass beak and eye have real contrast, so the bird reads as two floating gold specks.

### The hard constraint: keep the public API identical

`RavenMascot` is used on **five screens**, each passing a different pose:

| Screen | Anchor | Pose |
|---|---|---|
| Lobby | `lobby_screen.dart:424` | varies |
| Craft | `phase2_craft.dart:304` | `idle` |
| Vote | `phase3_vote.dart:382` | varies |
| Reveal | `phase4_reveal.dart:417` | varies |
| Game over | `game_over_screen.dart:231` | varies |

**`RavenMascot`'s constructor (`state`, `size`) and the `RavenState` enum (`sleep`, `idle`, `hop`, `ruffle`, `fly`) must not change.** Only the internal rendering swaps from `CustomPaint` to layered `Image.asset`. **If any of those five call sites needs editing, you have gone off-spec — stop.** This constraint is what keeps an art change from becoming a five-screen refactor.

### Two deliberate simplifications — flag if you disagree, do not silently deviate

The current `_RavenPainter` animates independent body parts: `headTiltAngle`, `isBlinking`, `wingFlare`, `lowerBeakOpen`, `scaleX/Y`, `translateX/Y`, `flapCount`. A single-silhouette mascot cannot keep all of them:

- **Independent head tilt → whole-body tilt.** In an *Among Us*-style design the head and body are one shape, so `headTiltAngle` rotates the entire character group instead of a separate head. Reads fine on a rounded silhouette and preserves the sleep pose's "head down" feel.
- **`lowerBeakOpen` is dropped.** The beak is part of the body silhouette. It is currently used subtly; losing it is an accepted cost of the simpler design.

Everything else survives: breathing scale, hop arc, wing flare/flap, blink.

### Asset architecture — four layers on a shared canvas

Derived from what the animation actually moves:

| Asset | Purpose | Animated by |
|---|---|---|
| `body.png` | Full crow silhouette including head, beak and tail — one shape | `scaleX/Y` (breathe), `translateX/Y` (hop), group rotation (tilt) |
| `wing.png` | Near wing only, positioned to overlap the body | `wingFlare`, `flapCount` — rotated about its own pivot |
| `eye_open.png` | Open eye | swapped |
| `eye_closed.png` | Closed eye — a simple curved line | swapped when `isBlinking` |

**Every layer must be exported on the same 1024×1024 canvas with the subject in its final position.** They are stacked with `Stack` + `Positioned.fill` and need no per-layer offsets. Layers cropped to their own bounding box will not align and will cost hours — this is the single most important instruction in this section.

**Wing pivot:** the wing must be drawn so its shoulder joint sits at a documented fraction of the canvas (e.g. `Alignment(-0.15, -0.10)`); record the actual value in a comment so the rotation looks hinged rather than sliding.

### The generation brief — for Gemini / nano banana

Nano banana's strength is **character consistency across edits**, so the workflow is: generate one master, then *edit* it into the variants. Do not generate each layer from scratch — they will not match.

**Prompt 1 — the master.** Generate 3–4 candidates and have the user pick one before continuing.

> A simple flat vector mascot of a crow, front-facing three-quarter view, for a Victorian gaslight-themed party game.
>
> Style: extremely simple and bold, like the characters in *Among Us* — one clean rounded silhouette, no gradients, no texture, no feather detail, no shading. Flat fills only, at most four colours. Chunky and friendly, slightly plump body, short tail, small visible wing, one large expressive eye. Readable at 48 pixels tall.
>
> Colours, exactly: body `#2E2A26`; a 3-pixel rim-light outline along the top and left of the silhouette in brass `#C9A24B`; beak brass `#C9A24B`; eye ivory `#F5EEDB` with a `#14110E` pupil.
>
> The character sits on a very dark background (`#14110E`), so the brass rim-light is what makes it visible — keep the outline unbroken and clearly separated from the body fill.
>
> Square canvas 1024×1024, transparent background (PNG with alpha), subject centred with roughly 10% padding. No text, no drop shadow, no scenery, no ground line.

**Prompt 2 — layer separations.** Feed the approved master back in as the reference, once per layer:

> Using the supplied image as the exact reference, output only the *[body / near wing]*, in precisely the same position, at the same scale, on the same 1024×1024 transparent canvas. Erase everything else to full transparency. Do not redraw, recolour, re-centre, or crop — the output must overlay the original pixel-for-pixel.

**Prompt 3 — eye variants.** Two crops on the same canvas: the open eye as drawn, and a closed variant — a simple downward-curved brass line in the same position and at the same scale.

**Iterate on the master, not the layers.** If the crow is wrong, regenerate Prompt 1 and redo the separations; patching an individual layer breaks alignment.

**Save the final prompts** to `assets/images/raven/PROMPTS.md` alongside the art. This is what makes the design "simple to redraw" — regenerating becomes a copy-paste rather than an archaeology exercise.

### Wiring it up

1. **Files:** `assets/images/raven/{body,wing,eye_open,eye_closed}.png`, plus `2.0x/` and `3.0x/` subfolders with the same four names. Provide 1x at 256×256 (downscaled from the 1024 master), 2x at 512, 3x at 768.
2. **pubspec:** `assets/images/` is **not recursive** — Flutter's directory globbing does not descend into subfolders. Add an explicit `- assets/images/raven/` entry. The `2.0x`/`3.0x` density variants *are* picked up automatically once the parent directory is listed. Omitting this entry is a runtime "asset not found", not a build error.
3. **Widget:** replace the `CustomPaint` in `_RavenMascotState.build` with a `Stack` of `Image.asset` layers wrapped in the existing `Transform`s. Keep `AnimatedBuilder` and all three controllers exactly as they are — the parameters they compute (`scaleY`, `translateY`, `headTiltAngle`, `wingFlare`, `isBlinking`) now drive `Transform` widgets instead of painter arguments. Delete `_RavenPainter` only once every pose is confirmed working.
4. **Reduced motion:** the existing `prefersReducedMotion` early-return must still yield a single static frame — body + wing + open eye, no controllers running.
5. **Size budget:** **≤150 KB total** for all twelve files. Flat four-colour art compresses to a few KB each; anything larger means gradients or noise crept in. Run the images through `pngquant`/`oxipng` if needed. Issue 29 fought for 2.7 MB — do not hand it back.

### Validation — four layers, because "looks right" is not testable

**Layer 1 — asset integrity (automated).** A test that, for each of the four PNGs: asserts the 1x is 256×256, asserts an alpha channel is present, and asserts the alpha bounding boxes are consistent with a shared canvas (the body's box should contain the eye's box). Catches the cropped-layer misalignment failure directly.

**Layer 2 — measured contrast (automated). This is the regression guard for the original bug.** Parse `body.png`, take the brightest non-transparent pixel as the rim-light, and assert its contrast against `#14110E` is **≥ 4.5:1**. Also assert the body fill itself is **≥ 1.2:1** so it is not pure background. For reference, measured on the current tree: the broken body is `1.02:1`, `#2E2A26` is `1.32:1`, brass `#C9A24B` is `7.84:1`. **A screenshot cannot regress-test this, which is precisely how the bird shipped invisible.**

**Layer 3 — animation contract (automated widget tests), one per pose:**
- `sleep` → renders `eye_closed.png`; the body group has a negative rotation; scaleY oscillates over time.
- `idle` → renders `eye_open.png` at rest; after pumping past a blink, `eye_closed.png` appears, then reverts.
- `hop` → mid-animation Y translation is non-zero and returns to zero at completion.
- `ruffle` / `fly` → the wing's `Transform` rotation is non-zero mid-animation.
- `AppMotion.reduce == true` → exactly one static frame, no controller is animating.
- Disposal → pumping the widget away leaves no exception.

**Layer 4 — human approval gate (required, cannot be automated).** Before merging, produce a contact sheet: all five poses rendered at their real on-screen sizes (the craft screen uses 64 dp) over the actual `#14110E` background, captured from the simulator:
```bash
xcrun simctl io booted screenshot /tmp/raven_poses.png
```
**The user approves the art before this merges.** If they reject it, iterate Prompt 1 — do not adjust code.

### Blast radius
New: `assets/images/raven/**` and `PROMPTS.md`. Changed: `pubspec.yaml` (assets entry), `lib/widgets/raven_mascot.dart` (rendering internals only), new tests. **The five call sites must not change** — if they do, stop.

---

## 5. Validation standard

**For a fix: write validation that fails against the broken state, and observe it fail.**
```bash
cp <file> /tmp/CURRENT
git show HEAD:<file> > <file>
flutter test test/<file>.dart      # must FAIL
cp /tmp/CURRENT <file>
git status --short                 # must be clean
```
This is how Issues 24, 26 and 30 were confirmed real (`Actual: <593.0>`, `Actual: <334.0>`, `Found 1 widget`). **Record the observed failure output in the Resolved entry.**

**For anything tests cannot see** — art, glyph identity — require an itemised manual pass, or better, verify the artefact directly. Parsing a font's `cmap` proved 11/11 glyphs resolve where no widget test could; the same trick applies to parsing a PNG for contrast.

Prefer assertions on **counts, ranges, geometry and measured values** over "it looks right". Pair every fix assertion with an **over-reach guard** — the first thing dropped under pressure.

---

## 6. Running 3 simulators for multiplayer testing

Bots are server-seeded documents and never exercise the non-host **client** path — use real simulator clients for anything you need to be correct.

```bash
xcrun simctl boot "iPhone 17"; xcrun simctl boot "iPhone 17 Pro"; xcrun simctl boot "iPhone Air"; open -a Simulator
```
```bash
flutter build ios --simulator --debug
```
```bash
for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl install "$U" build/ios/iphonesimulator/Runner.app; xcrun simctl launch "$U" com.whylabs.gaslight; done
```

The build must be `--debug`: `lobby_screen.dart:87` passes `debugEnabled: kDebugMode`, and the server refuses debug calls when it is false. **DEBUG: ADD 9 BOTS** is host-only and adds 9 unconditionally — with 3 real players you land at 12.

---

## 7. `.gitignore` — rules that must never be removed

**Decision rule.** (1) Secret, or identifies a developer's machine/account? → **ignore, always.** (2) Would a fresh clone fail or build differently without it? → **commit.**

| Rule | Guards |
|---|---|
| `.env` | Firebase API keys + `USE_EMULATOR`. Bundled into the IPA. |
| `**/google-services.json` · `**/GoogleService-Info.plist` | Firebase config. The plist is required on disk to build, never committed. |
| `/build/`, `.dart_tool/` | Generated. Source of the phantom analyzer errors in §1. |
| `functions/node_modules/`, `functions/lib/` | Installed and compiled output. |
| `**/ios/Flutter/Generated.xcconfig`, `flutter_export_environment.sh` | Absolute paths to the local Flutter SDK. |
| `*.log`, `firebase-debug.log`, `firestore-debug.log` | Emulator logs; can contain room data and UIDs. |

**Must stay tracked:** the vendored Phosphor font and its `LICENSE`, `.firebaserc`, `ios/Podfile.lock`, both `xcshareddata/swiftpm/Package.resolved`, and **the new raven PNGs** — verify with `git check-ignore -v assets/images/raven/body.png` (must print nothing) and confirm they appear in `git status`.

**Trap: `.swiftpm/` does not match `swiftpm/`** — the real Xcode paths have no leading dot.

---

## 8. Already delivered — do NOT rework

**Issues 1–30 and Tasks T1–T2**, all independently verified. Highlights that bear on current work:
- **Issue 23/29** — hybrid icons: 11 functional glyphs from a **vendored** Phosphor Light font (`assets/fonts/phosphor/`), 6 bespoke `CustomPainter` avatar sigils. All 11 code points verified present via `cmap` parse.
- **Issue 24** — entry form fits 360×640. Pre-fix overflow `593.0` dp → now `0.0`.
- **Issue 26** — roster sheet header drag/tap. Pre-fix the header moved the sheet `0` px.
- **Issue 27/30** — one House Rules panel in the Parlor, non-hosts see it read-only; `Family-Friendly Decks Only` is host-only.
- **Issue 28** — `phosphor_flutter` **can never be used**: `flutter/lib/src/widgets/icon_data.dart:23` declares `final class IconData` and that package extends it. Proven twice.
- **T2** — `cupertino_icons` deliberately absent; restore it only if a Cupertino widget is ever introduced.

**Release plumbing — do not revert:** bundle ID `com.whylabs.gaslight` everywhere (Android `MainActivity.kt` must stay in the matching Kotlin package) · Firebase iOS app `1:184580940908:ios:e79d100cc1231a8f022449`, project `gaslight-46368` · iOS deployment target **15.0** · Node **22** · `ITSAppUsesNonExemptEncryption = false` · `GoogleService-Info.plist` required on disk but gitignored · `.env` ships in the IPA so **`USE_EMULATOR` must be `false`** for testers.

---

## 9. Accepted equivalents — do NOT "fix" back

- **Craft SUBMIT is in-flow** under the text field (M5 keyboard exception); **Vote's CONFIRM** is bottom-anchored via `Expanded`+`SafeArea`.
- **Reactions send raw emoji strings**; medallions are render-side only (V5).
- **Entry-form logo uses `SizedBox(height: 60)` + `FittedBox`**, not `Transform.scale` — the latter does not change layout size.
- **`isSmallHeight` uses a `< 700` dp breakpoint with a 6/8/12/16/20 spacing scale.**
- **House Rules non-host gating uses `IgnorePointer` + `Opacity(0.5)`**, not per-control `onChanged: null`. The server rejects non-host writes regardless.
- **Forgery Rounds uses `Wrap(spacing: 6)`** to fit five chips at 360 dp.
- **The caption reads `Only the host can modify house rules.`** Settled; do not re-expand.

---

## 10. Intentional decisions / invariants — do NOT change

- **Server-authoritative:** clients read Firestore streams; **all** mutations go through callables; `firestore.rules` denies client room writes. Transactions read-before-write always.
- **Portrait-locked on phones**, iPad rotation retained. **Text scale clamped 1.0–1.3** (M3).
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically in `functions/src/text_similarity.ts` ↔ `lib/utils/text_similarity.dart` (Decision 2).
- **The `_advancedStateKeys` / once-per-event guards** survive Firestore-stream rebuilds — **never remove them.**
- **`ThematicIcon` is the single public icon entry point.** Only `test/thematic_icon_test.dart` may import the glyph source directly.
- **`_familyFriendlyOnly` is client-local and never synced** — Issue 30 Option C was explicitly not selected.
- **"Forgery Rounds" maps to `sabotageAnswersCount`** (forgeries per card). Renaming user-visible copy is a product decision.
- **`RavenMascot`'s public API and `RavenState` enum are fixed** — see §4.

---

## 11. Where the contracts live

| What | Where |
|---|---|
| Engineering history, every issue and selection | `docs/ongoing_general_errors.md` |
| How to run / playtest | `README.md` → "Testing & Running the Game" |
| System design contracts | `docs/design_*.md` — `design_ui_direction.md` §7 carries the **SHIPPED STATE** block for the icon system. **Issue 32 must update it** to describe the new mascot. |
| Manual test journeys | `docs/e2e_testing_journeys.md` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 12. Feedback loop — what past specs got wrong

- **A cross-language `undefined` check is not a null check.** Issue 31's server guard was correct-looking TypeScript that failed because the Dart client sends explicit `null`. The 28/28 suite could not catch it — those tests are written in TypeScript, where an omitted key genuinely *is* `undefined`, so the failing payload was unreachable from the harness. **When a boundary is crossed by two languages, at least one test must send the payload the way the real client sends it.** Same real-client blind spot as the non-host write gap; two bugs and counting.
- **Resolution is not compilation.** A spec named a package after confirming it resolved via `--dry-run`; it could not compile. Name a *compiling* command as the acceptance check.
- **A blocker is a filing event, not a licence to re-choose.** THE LOOP step (4) exists for this.
- **A "no X exists" claim must be grepped across the whole feature.** Asserting no settings home existed, without grepping the Parlor body, produced Issue 27.
- **Layout overflow must be measured, not estimated** — estimated ~275 dp, measured **593 dp**.
- **A ruling is only as durable as the test that pins it** — the unpinned Family-Friendly ruling produced Issue 30.
- **Over-reach guards are the first thing dropped.** The 360×640 non-host check was flagged as most likely to be skipped, and was skipped.
- **Some correctness is invisible to tests.** A wrong icon code point renders a blank box that every assertion passes; a bird can ship at 1.02:1 contrast with a green suite. Verify the artefact directly — parse the font, parse the PNG.

---

## THE LOOP

```
(1) STUDY the item here + the rejected options in ongoing_general_errors.md + the
    exact files at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified.
(3) VALIDATE per §5. Observe the falsifying test fail against the broken state.
    For anything tests cannot see, verify the artefact directly or gate on human
    review. Then the full §1 battery. Anything touching functions/ or rules
    REQUIRES the emulator suite -- fakes never validate backend behaviour.
(4) BLOCKED or impossible? STOP. File it in ongoing_general_errors.md with options
    and a `Your selection: _____` line. Do NOT re-choose on the user's behalf.
(5) RECORD: move to Resolved (Problem / Solution / Validation) including observed
    failure output and measured numbers. Sync any design doc whose behaviour changed.
(6) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **Issue 31:** client omits null keys; server uses `!= null`; `startGame` throws a readable `failed-precondition`; rotation engine validates its input.
- [ ] Emulator test sending an **explicit `null`** proves settings are preserved, and was **observed to fail** against the pre-fix backend; the `false`/`0` over-reach guard passes; `startGame` returns `failed-precondition`, not `internal`.
- [ ] Dart test proves the client payload omits untouched keys.
- [ ] `npm --prefix functions test` green, then **`npx firebase-tools deploy --only functions`** run.
- [ ] 3-simulator manual check: set timers off + rounds 4 → change deck → both survive → START GAME succeeds.
- [ ] **Issue 32:** four layers on a shared 1024×1024 canvas; `assets/images/raven/` added to `pubspec.yaml` explicitly; `RavenMascot` API and the five call sites unchanged; `_RavenPainter` removed.
- [ ] Asset-integrity, measured-contrast (**rim ≥ 4.5:1** vs `#14110E`) and per-pose animation tests all green.
- [ ] `assets/images/raven/PROMPTS.md` saved so the art can be regenerated from a copy-paste.
- [ ] Total raven assets **≤ 150 KB**; release build re-measured against the 44.0 MB baseline.
- [ ] **User has approved the artwork from a five-pose contact sheet.**
- [ ] `design_ui_direction.md` updated to describe the new mascot.
- [ ] Full battery: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 65 + new** · functions build clean · `npm --prefix functions test` green · iOS release builds.
- [ ] Both issues moved to Resolved in `ongoing_general_errors.md`; two commits, one per item.
- [ ] This guide rewritten to **Queue Complete**, or to the next approved queue.
