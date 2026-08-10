# Agent Execution Guide — Queue Complete: All Issues Delivered & Deployed (Issues 50–57) — August 10, 2026

**You are an engineering agent with no memory of this project.** Issues 50–57 are delivered, deployed and **verified live in production** — do not rework any of them. The queue is complete.

**Every number, literal string and field name here is a decision, not a suggestion.** Copy quoted strings verbatim. If the design cannot work, STOP and file it in `ongoing_general_errors.md` with options and a `Your selection: _____` line — never choose on the user's behalf.

---

## Standing constraints

1. **Portrait phone is the target.** Validate every layout at **360×640 dp portrait**.
2. **Design tokens are law.** `AppColors`, `AppTextStyles`, `AppMotion`. **No raw hex in widget code** — the painter receives its `color` and must use it.
3. **Every animation needs an `AppMotion.reduce(context)` path.** Nothing in this build animates.
4. **Text scale clamped 1.0–1.3.** **Touch targets ≥ 48 dp.**
5. **`ThematicIcon` is the single public icon entry point.** §3 changes what `depart` draws, never how icons are dispatched.
6. **This build is client-only.** If you are editing `functions/`, `firestore.rules`, or deploying anything, you have left the spec. STOP.
7. **One item = one commit**, Conventional Commits, WHY in the body.

---

## 1. Verified baseline — the regression bar

Measured at commit `3b8019f`, clean tree.

| Gate | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze lib test` | **0 errors** (270 infos/warnings, pre-existing) |
| Client tests | `flutter test` | **121/121** |
| Functions build | `npm --prefix functions run build` | clean |
| Backend E2E | `npm --prefix functions test` | **36/36** |
| Production functions | `gcloud functions list` | all 14 at `2026-08-10T05:07` |
| Deployed bundle | source zip inspected | `ROOM_TTL_MS` ×2, `expiresAt` ×10, lobby-host close branch present |
| Deployed rules | Rules API | ruleset `bd0e3cc6`, released `05:06:36`, `expiresAt` in denylist |
| Legacy backfill | `backfill_expires_at.js --dry-run` | **0** missing across 98 rooms / 628 players |
| iOS release build | `flutter build ios --release --no-codesign` | ⚠️ **not re-run since `56c183a`** (49.5 MB then). §5.2. |
| Three-simulator playthrough | manual | ⚠️ **never performed against the deployed backend.** §5.1. |

**`gcloud` is not on this shell's `PATH`**; it is at `/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud`.

### ⚠️ Nine traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`** — ~678 phantom errors from gitignored vendored plugin source.
2. **Analyze ≠ compile.** Only `flutter test` or `flutter build` surfaces a broken dependency.
3. **Working directory persists** between Bash calls. Use absolute paths or `npm --prefix functions`.
4. **BSD `sed` does not support `\b`** — matches nothing, exits 0. Use `python3`.
5. **`Image.asset` loads no bytes under `flutter test`**, and an icon can render as the wrong picture with every test green. Decode the artefact (§3 validation).
6. **`test/fake_functions.dart` does not enforce `firestore.rules`.**
7. **Widget tests on animated screens hang unless you set `accessibleNavigation`.** Wrap the screen under test in `MediaQuery(data: const MediaQueryData(accessibleNavigation: true), …)` — `AppMotion.reduce(c) => MediaQuery.of(c).accessibleNavigation`. Never `await` a fake callable directly inside `testWidgets` (FakeAsync deadlock); wrap in `tester.runAsync`. `pumpAndSettle()` is not the culprit and is not banned.
8. **`firebase.json`'s `predeploy` hook is load-bearing.** Without it `firebase deploy` ships stale JavaScript from the gitignored `functions/lib/` and reports success. Verification procedure: `design_database_and_security.md` §8.
9. **A cmap presence check proves nothing about a glyph.** This font's cmap spans `0x0020–0xFFFD`, so nearly any codepoint tests `PRESENT`. That check passed and let the wrong icon ship. Outlines are decodable — §4.

### ⚠️ One more, specific to this build

**`_ThematicIconPainter.shouldRepaint` returns `false` unconditionally** (`app_icons.dart:484`). A new painter instance is constructed on every build, so first paint is correct — but a test that changes only the `color` or `type` on the same element and expects a repaint will fail **for that pre-existing reason, not because of your icon.** Do not "fix" it as part of Issue 57; if it genuinely blocks a test, restructure the test to pump a fresh widget.

---

## 2. Execution order

| # | Item | Why this position |
|---|---|---|
| 1 | **§3 — draw the `depart` sigil** | The filed defect, with a selected option. Own commit. |
| 2 | **§4 — commit the glyph inspector and audit the other eleven glyphs** | Read-only and independent, so it cannot break §3. Do it in the same wave: the same failure mode that produced Issue 57 applies to eleven other icons that have never been checked either. |
| 3 | **§5 — the two residual verifications** | Independent of both. |

---

## 3. Issue 57 — draw `depart` as a bespoke sigil (Option A)

**What this means for the user:** the only control that removes them from a room is currently marked with a toggle-like symbol instead of a door with an arrow leaving it.

### The gap

`lib/theme/app_icons.dart` maps `ThematicIconType.depart` to `IconData(0xe674, fontFamily: _kPhosphorLight)`. Rasterising that codepoint's outlines gives **glyph id 837, 4 contours** — a horizontal capsule enclosing an inner element. Not a door, not an arrow. The painter already carries `case ThematicIconType.depart:` at **line 478 with a bare `break;`** — an empty branch that draws nothing and is currently unreachable.

### How dispatch works — read this before editing

`ThematicIcon.build` (line 75) takes the font path **only** when the type is *not* in `_bespokeSigils` **and** `_phosphorGlyphs[type]` is non-null. Otherwise it falls through to `CustomPaint(painter: _ThematicIconPainter(type, color))`. So there are two independent switches, and you must throw both:

**Step 1 — remove the font mapping.** Delete the `ThematicIconType.depart: IconData(0xe674, …)` line from `_phosphorGlyphs` (the map at lines 46–59). Leaving it behind is a dead entry that will tell the next reader this icon comes from the font.

**Step 2 — force the painter.** Add `ThematicIconType.depart,` to the `_bespokeSigils` set (lines 32–39). The set is currently commented "Avatar Sigils"; update that comment to reflect that it is now *the set of types drawn by `_ThematicIconPainter`*, which is what it has always actually meant.

Either change alone would work. Do both: step 1 removes the lie, step 2 states the intent.

### Step 3 — fill the empty case

Replace `case ThematicIconType.depart: break;` at line 478. Conventions, taken from the existing cases and **not optional**:

- All geometry as fractions of `w` and `h` (both are already in scope, as is `center`), so the icon scales at any `size`.
- Stroke with the pre-built `paint` — it already carries `strokeWidth = math.max(1.5, size.width / 16)`, `StrokeCap.round`, `StrokeJoin.round`, and the passed-in `color`. **Do not construct a new `Paint` with a literal colour.**
- Use a `Path` for the door so `StrokeJoin.round` applies at its corners; `canvas.drawLine` for the arrow, matching the `envelope` (427) and `redraw` (440) precedents.
- End with `break;`.

Draw a **door open on its right side, with an arrow leaving through the opening** — the standard sign-out reading:

| Element | Geometry |
|---|---|
| Door, three sides (right side deliberately absent) | `Path`: `moveTo(w*0.46, h*0.14)` → `lineTo(w*0.14, h*0.14)` → `lineTo(w*0.14, h*0.86)` → `lineTo(w*0.46, h*0.86)`, stroked with `paint` |
| Arrow shaft | `drawLine(Offset(w*0.40, h*0.5), Offset(w*0.84, h*0.5), paint)` |
| Arrow head, upper barb | `drawLine(Offset(w*0.84, h*0.5), Offset(w*0.70, h*0.36), paint)` |
| Arrow head, lower barb | `drawLine(Offset(w*0.84, h*0.5), Offset(w*0.70, h*0.64), paint)` |

The shaft deliberately starts at `w*0.40`, inside the door's right edge at `w*0.46`, so the arrow reads as passing *through* the opening rather than floating beside it. If these proportions look wrong once rendered, **keep the intent** — door on the left, arrow exiting right — adjust minimally, and note the change in the commit body.

### Validation

**Every assertion below fails against the current code.** Run them first and record the output.

**Test 1 — the painter is actually reached.** Pump `ThematicIcon(type: ThematicIconType.depart, size: 24)`. Assert `find.byType(CustomPaint)` finds the icon's painter and `find.byType(Icon)` finds **nothing**. **Falsifying today:** `depart` sits in `_phosphorGlyphs` and outside `_bespokeSigils`, so `build()` returns an `Icon` and this fails immediately.

> Scope the `CustomPaint` finder — Flutter's own widgets insert `CustomPaint` nodes, so a bare `find.byType(CustomPaint)` matches several and would pass for the wrong reason. Use `find.descendant(of: find.byType(ThematicIcon), matching: find.byType(CustomPaint))`, and assert the painter's runtime type where practical. A check that cannot fail is not a check (§7).

**Test 2 — the sigil actually draws something.** This is the assertion that catches an empty `break;`, and it is the one that would have caught Issue 57. Render the widget to a bitmap and count marks:

- Wrap the icon in a `RepaintBoundary` with a `GlobalKey`, pump, then inside `tester.runAsync` call `boundary.toImage(pixelRatio: 4.0)` and `image.toByteData(format: ImageByteFormat.png)`.
- Decode the PNG with the project's existing pure-Dart decoder, `test/helpers/png_decoder.dart` — **reuse it, do not write another.**
- Assert the count of pixels with alpha > 0 is **at least 120** at 24 dp × 4.0 (a conservative floor for four strokes; measure the real number and record it — do not tune the threshold to whatever you get, and if it lands near the floor, say so).

**Falsifying today:** the case draws nothing, so the count is **0**.

**Test 3 — visual identity, decoded not assumed.** Reduce the same bitmap to an ASCII grid and look at it, exactly as the technique in §4 did for the font. **Paste the rendering into the Issue 57 Resolved entry.** A pixel count proves ink exists; it does not prove the ink is a door. This project has now shipped one icon whose identity nobody checked — do not ship a second.

**Over-reach guard A — the other eleven still use the font.** Assert `ThematicIcon(type: ThematicIconType.envelope)` still renders an `Icon` and **not** a `CustomPaint`. This catches an over-broad `_bespokeSigils` edit, which would silently swap eleven icons to their fallback painter drawings.

**Over-reach guard B — the six avatar sigils are unchanged.** Run the same pixel-count on `flame`, `moth`, `key`, `raven`, `moon`, `hourglass` and assert each is non-zero and unchanged from before your edit. Record the before numbers.

**Layout check.** Confirm the lobby `AppBar` still fits at 360×640 dp with the new leading icon, and that the tooltip is still `'Leave room'`.

### Blast radius — same commit

`lib/theme/app_icons.dart` · `test/thematic_icon_test.dart` (extend, or add `test/depart_sigil_test.dart`) · `docs/design_ui_direction.md` — **two edits**: line 129 currently says "**twelve** functional affordances render from a vendored Phosphor Light font asset" and lists `depart` among them; that becomes **eleven**, with `depart` moved to the bespoke-sigil group. Line 222 carries a ⚠️ recording the wrong glyph — **replace it** with the sigil description once the icon is right.

---

## 4. Commit the glyph inspector, and audit the other eleven glyphs

**What this means for the user:** possibly nothing, possibly a second wrong icon. Nobody knows, which is the point.

### Why this is not optional

`0xe674` was wrong and shipped. **The other eleven `_phosphorGlyphs` entries were mapped by exactly the same process and have never been checked either.** Their comments (`// feather`, `// lamp`, `// sealCheck`…) are assertions nobody has tested. The tool that settles it already exists in prototype and needs a home.

### Implementation

Create `scripts/inspect_glyph.py`, committed. It must:

1. Parse the TTF table directory, then `head` (`indexToLocFormat`), `maxp`, `cmap` (format 4), `loca`, `glyf`.
2. Map a codepoint to a glyph id, and **report glyph id `0` explicitly as `.notdef` / tofu** — a distinct failure from "wrong picture".
3. Read contours (`numberOfContours`, `endPtsOfContours`, flags with their repeat bit, and the delta-encoded x/y arrays with their short-vector and same-value bits) and plot the points to an ASCII grid, joining consecutive points with straight segments.
4. Report **composite glyph** when `numberOfContours < 0` rather than emitting garbage.
5. Accept several codepoints per invocation for side-by-side comparison.

**The working implementation already exists** — it diagnosed Issue 57 and is reproduced in that issue's write-up in `ongoing_general_errors.md`. Lift it rather than re-deriving the table parsing.

### Validation

**Validate the validator first.** A rasteriser that draws nonsense "proves" an icon wrong just as confidently as a working one.

- `0xE214` must render a recognisable **envelope**; `0xE2D6` a recognisable **key**. Both identities are beyond doubt. **Paste both renders into the commit body.**

**Then the audit.** Render all eleven remaining `_phosphorGlyphs` codepoints and check each against the comment beside it in `app_icons.dart`. Record the verdict per icon in the Issue 57 Resolved entry — a one-line table is enough.

**If any of the eleven is wrong: do not fix it here.** File it as a new issue in `ongoing_general_errors.md` with options, and let the user choose. One wrong icon is a defect; a second changes the question from "fix this" to "should these all be bespoke sigils?", which is theirs to answer.

### Blast radius

`scripts/inspect_glyph.py` (new, committed) · `ongoing_general_errors.md` §2.9 already records the technique.

---

## 5. The two residual verifications

Neither is blocked; neither is visible to any suite.

**5.1 — Three-simulator playthrough against the deployed backend.** The deploy was verified from its artefacts, which is strong evidence about the *code* and none about the *experience*. Nobody has played against the live backend since it shipped.

```bash
xcrun simctl boot "iPhone 17"; xcrun simctl boot "iPhone 17 Pro"; xcrun simctl boot "iPhone Air"; open -a Simulator
```

```bash
flutter build ios --simulator --debug
```

```bash
for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl install "$U" build/ios/iphonesimulator/Runner.app; xcrun simctl launch "$U" com.whylabs.gaslight; done
```

Must be `--debug` (`debugEnabled: kDebugMode`), and **`USE_EMULATOR` must be `false` in `.env`** to hit production — `.env` is a bundled asset, so a change requires a rebuild. `xcrun simctl uninstall <UDID> com.whylabs.gaslight` clears a device's remembered room.

Assert in one session, recording what you saw per device: host leaves a lobby → **both** non-hosts land on the entry screen showing **"The host has left. This room has closed."**; a non-host leaves → the room survives and the host sees them go; a non-host can swipe the deck carousel through all 7 cards without changing the host's selection; a full game completes end to end. **Also look at the leave icon while you are there** — that is a free confirmation of §3.

**5.2 — Re-measure the release build.** `flutter build ios --release --no-codesign`; record `Runner.app`. The 49.5 MB figure is inherited from `56c183a` and predates the Issue 50 and 57 work.

---

## 6. Already delivered — do NOT rework

Verified **August 10, 2026** by reading source and by inspecting production artefacts — not from commit messages:

- **Issue 51** — lobby-host close branch precedes the `!hasCard` branch (`index.ts:741/744/753`), and is present in the deployed bundle. Reversing that order silently reinstates the original bug.
- **Issue 52** — one `PageView` for both roles; selection and stamp pulse suppressed for non-hosts; `CHOSEN` badge; 3-second snap-back via `_lastSwipeTime`. Contract in `design_prompt_system.md` §67–70.
- **Issue 53** — `ROOM_TTL_MS` 8 h, `expiresAt` at ten sites, rules denylist. Live in the deployed bundle and ruleset.
- **Issue 54** — both TTL policies `ACTIVE`. **Do not re-run the enable commands.**
- **Issue 55** — functions and rules deployed `2026-08-10T05:06–05:07`; `predeploy` hook in `firebase.json`.
- **Issue 56** — legacy backfill complete; a fresh `--dry-run` reports **0** missing across 98 rooms and 628 players.
- **Issue 50's three defects** — `showGeneralDialog` with unconditional `barrierDismissible`, `barrierLabel`, `barrierColor`, reduce-gated `transitionDuration`; `_isLeaving` set before `Navigator.pop()` with no `finally` reset; tooltip-based finders; four new tests with scoped `find.ancestor`. **Only the icon remained — that is §3.**
- **Issues 1–49, Tasks T1–T11** — the mascot programme is finished; `POSE_REGISTRY` is the single source of truth for frame geometry; two renderers coexist by design.
- **Issue 31** — the server uses loose `!= null`; **never "simplify" to a falsy check**.
- **Issues 28/29** — `phosphor_flutter` can never be used (`IconData` is a `final class`); the app vendors the Phosphor Light font.

---

## 7. Validation standard

**Write validation that fails against the broken state, and observe it fail.** Record the output in the Resolved entry.

**A check that cannot fail is not a check.** Five instances now: the cmap presence script, `find.byType(IconButton).last`, a bare `find.byType(FadeTransition)`, a "file is non-empty" contrast test, and — waiting to happen — a bare `find.byType(CustomPaint)` (§3 Test 1). **Before trusting a check, ask what input would turn it red.**

**Validate the validator.** §4's control pair exists because a broken rasteriser would have "proved" the icon wrong just as confidently as a working one.

**Ink is not identity.** A pixel count proves something was drawn; only looking proves it is the right thing. §3 Test 3 is not optional.

**A green suite is not delivery, and "Resolved" is not "live."** Issues 51 and 53 sat green and Resolved for a day while production ran older code. The fix was reading the deployed artefact — `design_database_and_security.md` §8.

**"Invisible to the harness" is a claim to test.** The glyph was called unverifiable-without-a-device for two cycles. It was decodable the whole time.

**Measure; do not estimate**, and **do not tune a threshold to make a test pass** — report the measured number and say the guard failed.

**Pair every fix assertion with an over-reach guard.**

---

## 8. Accepted equivalents — do NOT "fix" back

- **Leaving a room does not call `Navigator` explicitly.** `lobby_screen.dart` gates the waiting room on `gs.gameState != null && gs.currentPlayer != null` and otherwise falls through to `_buildEntryForm`. **Do not add a redundant `pushReplacement`.**
- **The non-host carousel is interactive-but-inert, not dimmed.**
- **`pumpAndSettle()` and `pump()` + `pump(500ms)` are both acceptable** once `accessibleNavigation: true` is set.
- **The leave dialog uses `showGeneralDialog`, not `showDialog`** — that is what makes the reduce-motion path possible.
- **`_ThematicIconPainter` carries fallback cases for font-backed types too.** They are unreachable while `_phosphorGlyphs` has an entry. Do not delete them and do not "wire them up".
- **Craft SUBMIT is in-flow**; **Vote's CONFIRM** is bottom-anchored via `Expanded`+`SafeArea`.
- **`isSmallHeight` uses a `< 700` dp breakpoint** with a 6/8/12/16/20 spacing scale.

---

## 9. Intentional decisions / invariants — do NOT change

- **Server-authoritative**; `firestore.rules` denies client room writes. `lastSeen` is the only sanctioned client write; `expiresAt` is server-owned.
- **Portrait-locked on phones**; **text scale clamped 1.0–1.3**.
- **Duplicate-answer check is a lexical heuristic**, mirrored byte-identically across `text_similarity.ts` ↔ `text_similarity.dart`.
- **The `_advancedStateKeys` / once-per-event guards** survive Firestore-stream rebuilds — **never remove them.**
- **`_familyFriendlyOnly` is client-local and never synced.**
- **`playRavenPose`'s `onceKey` stays required.**
- **`ROOM_TTL_MS` is 8 hours.** **If ever shortened below roughly 4 hours, a host-only `touchRoom` keepalive callable plus a client timer become mandatory** — an idle lobby writes nothing and a player's `expiresAt` is never refreshed after join. Design recorded in `ongoing_general_errors.md` Issue 53.
- **`firebase.json`'s `predeploy` hook stays.**
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 Option C, Issue 34 Option C, and **Issue 57 Options B and C** — the codepoint hunt and the do-nothing were both considered and rejected on August 10, 2026.

---

## 10. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Full history of any resolved item | `git log` |
| Backend writes, rules, identity, TTL §6, **deploy & verification §8** | `design_database_and_security.md` — §7 is the `null` ≠ absent contract |
| Card passing, disconnect recalculation, input validation | `design_rotation_engine.md` §5 |
| Scoring, routing, gameplay programme | `design_scoring_and_ui.md` §4 |
| Palette, typography, icons, mascot, dialog motion | `design_ui_direction.md` |
| Deck catalogue and non-host carousel contract | `design_prompt_system.md` §67–70 |
| PNG decoding helper (reuse, do not rewrite) | `test/helpers/png_decoder.dart` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 11. Feedback loop — what past specs got wrong

- **"Invisible to the harness" is a hypothesis, not a fact.** The glyph gate was declared satisfiable only on a device, so it was skipped twice and the wrong icon shipped — while the outlines were decodable in ~60 lines of Python the whole time. **When a gate is called unverifiable, spend ten minutes trying to verify it before writing that into a guide.**
- **A blocking gate with no runnable command will be skipped.** Marking it "may not be ticked from a green suite" was not enough; it was ticked from a green suite. **Give a gate a command, or expect it to be dropped.**
- **One wrong instance implies a wrong process.** `0xe674` was not a typo — it was produced by the same unverified mapping step as eleven siblings. §4 exists because a defect found in one item is a reason to audit the batch.
- **"Resolved" is not "deployed."** Issues 51 and 53 were green, verified and Resolved while production ran a two-day-old build.
- **Enabling a thing is not the same as the thing working.** The TTL policies went `ACTIVE` and deleted nothing, because the field they key on was not yet written in production.
- **A convenience the tooling normally provides may be absent here.** `firebase.json` had no `predeploy` hook, so the build step every Firebase TypeScript project assumes was manual — and skipping it shipped stale code with a success message.
- **An accommodation implemented against the wrong axis is a regression.** `barrierDismissible: !reduceMotion` read as accessibility work and removed a capability from the users it named.
- **A confident diagnosis can be wrong in the same direction twice.** `pumpAndSettle` was blamed and banned; the cause was a missing `accessibleNavigation` flag.

---

## THE LOOP

```
(1) STUDY the item here + the rejected options in ongoing_general_errors.md + the
    exact files at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified. Copy strings verbatim; paste, do not retype.
(3) VALIDATE per §7. Observe the falsifying assertion fail first, and record it.
    Run the over-reach guards. Validate the validator where one exists.
    For anything the harness cannot see, decode the artefact — do not assume you cannot.
    Then the full §1 battery.
(4) BEFORE COMMITTING, re-read this guide's open defect list for the item you are
    finishing. Green tests are not evidence that a filed defect was addressed,
    and a blocking manual gate is not satisfied by a passing suite.
(5) BLOCKED or impossible? STOP. File it in ongoing_general_errors.md with options
    and a `Your selection: _____` line. Do NOT re-choose on the user's behalf.
(6) RECORD: move the issue to Resolved (Problem / Solution / Observed Falsifying
    Output / Over-reach Guard). Sync any design doc whose behaviour changed.
(7) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **§3 step 1/2** — `depart` removed from `_phosphorGlyphs` **and** added to `_bespokeSigils`; the set's comment updated to say what it means.
- [ ] **§3 step 3** — the empty `case ThematicIconType.depart: break;` replaced with a door-and-arrow drawn in fractional coordinates using the pre-built `paint`. No new `Paint` with a literal colour.
- [ ] **§3 Test 1** — painter reached, `Icon` absent, with the `CustomPaint` finder **scoped** to `ThematicIcon`. Observed failing first.
- [ ] **§3 Test 2** — rendered-bitmap ink count ≥ the recorded floor, decoded with `test/helpers/png_decoder.dart`. Observed as **0** before the fix. Measured number recorded, threshold not tuned to it.
- [ ] **§3 Test 3** — the rendered icon reduced to ASCII, **looked at**, and pasted into the Resolved entry. Ink is not identity.
- [ ] **§3 over-reach** — `envelope` still renders an `Icon`; the six avatar sigils' ink counts unchanged from their recorded before values.
- [ ] **§4** — `scripts/inspect_glyph.py` committed with the envelope and key control renders in the commit body; all eleven remaining Phosphor glyphs audited against their comments, verdicts recorded. **Any wrong sibling filed as a new issue with options, not fixed inline.**
- [ ] **§5.1** — three-simulator playthrough against the **deployed** backend, per-device observations recorded, including the exact eviction copy and a look at the new leave icon.
- [ ] **§5.2** — `Runner.app` re-measured; the inherited 49.5 MB replaced.
- [ ] Full battery at or above the §1 bar: `flutter analyze lib test` **0 errors** · `flutter test` **≥ 121 + new** · functions build clean · `npm --prefix functions test` **36/36**.
- [ ] `design_ui_direction.md` line 129 says **eleven** font-backed affordances with `depart` listed as a bespoke sigil; line 222's ⚠️ replaced with the sigil description.
- [ ] Issue 57 moved to Resolved with the ASCII render as evidence.
- [ ] **Guide rewritten** to `Queue Complete` or the next queue. If the queue is empty: **do not invent work.** The only legitimate triggers are a user-selected issue or a §9 invariant's stated trigger firing.
