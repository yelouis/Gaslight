# Agent Execution Guide — Active Build: Marionette-Driven Playthrough (M1–M5) — August 13, 2026

**You are an engineering agent with no memory of this project.** This build is written for **Antigravity**, which can install and use MCP servers.

**The code queue is empty.** Every tracked engineering issue through Issue 76 is delivered and verified in source (§9). **Do not write, refactor, or "improve" game logic.** If you find yourself editing `functions/`, `lib/models/`, `lib/services/`, `lib/utils/`, or `firestore.rules`, you have left this build.

**What is actually open is a playthrough**, and it has been deferred across seven cycles because no agent could drive the app. The game's shape changed materially in the last wave — truth-first ordering, an outer round loop, a reworked forgery setting — and the last playthrough found **six issues against a fully green battery**. Two were production correctness defects.

**Your job, in one sentence:** install Marionette MCP, drive three iOS simulators through the eleven assertions in §6, and write what you saw into `docs/playthrough_findings_marionette.md`.

**You do not fix anything and you do not file issues.** Claude Code reads your findings doc and converts failures into tracked issues with options. A fix applied inline destroys the evidence that the fix was needed.

**Every number and literal string below is deliberate — implement as written; do not substitute your own.**

---

## Standing constraints — these apply to every item

- **Permitted source edits: exactly the five steps in §4, and they are additive.** Nothing else in `lib/` may change. Nothing in `functions/`, `firestore.rules`, or `test/` may change at all.
- **`.env` must contain `USE_EMULATOR=false`.** It is a bundled asset — editing it requires a rebuild, not a hot reload. This run must hit the deployed backend, because that is the only place `firestore.rules` is enforced.
- **Debug build, always.** The server refuses debug callables when `debugEnabled` is false, and Marionette needs the VM service, which release builds do not expose.
- **Three real clients. Never `DEBUG: ADD 9 BOTS` for this run.** Bots are server-seeded documents that never traverse the client write path or the security rules — using them would reproduce the exact blind spot this playthrough exists to cover.
- **Record measured values and verbatim strings. Never paraphrase UI copy, and never estimate.** "Roughly the right message appeared" is not an observation.
- **Never fill in a `Your selection: _____` line** in `ongoing_general_errors.md`. That line belongs to the user.
- **The battery in §1 is a floor, not a target.** If your edits move any number, stop and fix your edit.

---

## 1. Verified baseline — the regression bar

Re-measured **August 13, 2026**, at `1e12748` with only doc edits in the tree. These are real numbers from this session, not copied forward.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ (24 warnings, 197 infos — 221 issues total) |
| `flutter test` | **127/127** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **43/43** ✅ |
| **The playthrough** | ❌ **NEVER RUN** — this is why this build exists |

**`gcloud` is not on this shell's `PATH`**; it is at `/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud`.
**`~/.pub-cache/bin` is not on this shell's `PATH` either** — §3 depends on this.

### ⚠️ Traps that have each cost a cycle

1. **Analyzer scope.** `flutter analyze lib test`, **never bare `flutter analyze`** — it walks `build/{ios,macos}/SourcePackages` and reports ~678 phantom errors from vendored plugin source.
2. **Analyze ≠ compile.** A package that resolves may still fail to build.
3. **Working directory persists** between Bash calls. Use `npm --prefix functions`.
4. **BSD `sed` has no `\b`**; **`rg -r` is `--replace`, not "recursive"**.
5. **`Image.asset` loads no bytes under `flutter test`.**
6. **`test/fake_functions.dart` does not enforce `firestore.rules`** but does model the server's error shape — keep it that way.
7. **Widget tests on animated screens hang unless you set `accessibleNavigation: true`.** `toImage()` must be inside `tester.runAsync`.
8. **`firebase.json`'s `predeploy` runs the test suite.** Gates `--only functions`, **not `--only firestore:rules`**. Needs Java.
9. **A cmap presence check proves nothing about a glyph.** Use `scripts/inspect_glyph.py`.
10. **A green suite is not evidence about anything it cannot observe.**
11. **Check which artefact a measurement describes, and in what units.**
12. **A raw `Error` from a callable flattens to `INTERNAL`.** Use `HttpsError`; match on the **code**.

### ⚠️ New traps specific to this build

13. **One Marionette server process holds exactly one connection.** `connect` takes a single VM service URI and no other tool takes a session id. Three players means **three separate MCP server entries** (§3), not one server reconnected three times. Reconnecting mid-run silently drops the device you were driving.
14. **The Forgeries and Rounds choosers are both `ChoiceChip`s whose labels are bare numerals.** `lobby_screen.dart:569` renders `1…8`; `lobby_screen.dart:600` renders `1…5`. Without the keys added in §4, `tap(text: '3')` is ambiguous between them and can set the wrong House Rule while reporting success. **This is the single most likely way this run produces a false pass.**
15. **`get_interactive_elements` returns only what is currently visible.** `scroll_to` before concluding a control is absent. "The chooser did not offer 6" and "6 was below the fold" are different findings.
16. **Match UI copy exactly, including case.** This app renders headers and buttons as literal ALL-CAPS strings (`'THE GUEST LEDGER'`, `'CREATE ROOM'`, `'RE-ROLL PROMPT'`, `'SUBMIT DOSSIER'`, `'CONFIRM VOTE'`). `tap(text: 'Create Room')` will not match.
17. **Two `flutter run` builds against the same `build/` directory at once will corrupt each other.** Start P1, wait for its VM service URI, then P2, then P3.
18. **A screenshot you did not look at is not evidence.** `take_screenshots` returns base64 PNGs; decode and actually read them. Several assertions below are *only* answerable from the pixels.
19. **`Family-Friendly Decks Only` hides the deck assertion 4 needs.** The switch at `lobby_screen.dart:643` filters out `cah_dark_humor` and `rated_r_nsfw` (`lobby_screen.dart:423`). It defaults to **`false`** (`lobby_screen.dart:43`), so the deck is reachable — **leave it off**. If you flip it while exploring the lobby and forget, assertion 4 becomes untestable and the deck's absence looks like a bug that is not one.
20. **Phase auto-advance will fire mid-assertion.** An agent driving three devices through `get_interactive_elements` → `tap` → `take_screenshots` is far slower than the human pacing these timers assume; a phase that advances between your read and your tap produces a garbage observation that reads like a real defect. **Turn `Disable Game Timers` on** (`lobby_screen.dart:623`) before assertion 1, and record it as a deviation (§6).

**These three hazards — 14, 19, 20 — were found while writing this build and are confirmed. Handle all three before assertion 1.** Trap 14's fix is the keys in §4 step 3–4; traps 19 and 20 are settings you set in §6's setup block. None is optional: each one can turn a clean run into a plausible-looking false result.

---

## 2. Execution order

| # | Item | Why this position |
|---|---|---|
| **M1** | Install Marionette MCP server + register three clients | Nothing else is possible until Antigravity has the tools. Failure here is cheap and immediate. |
| **M2** | Instrument the app (binding + six keys) | Must precede the build in M3 — the binding is compiled in, and the keys are what make M4's taps unambiguous (trap 14). |
| **M3** | Boot, build, install, launch, connect three clients | The build is the slow step (~2–4 min cold); start it before you need it. Ends with a screenshot gate so a silently-stale device cannot poison M4. |
| **M4** | Drive the eleven assertions | The whole point. Items 9 and 10 destroy the room, so they run last, in that order. |
| **M5** | Write `docs/playthrough_findings_marionette.md` | Written **during** M4, per assertion, not reconstructed afterwards from memory. |

---

## 3. M1 — Install Marionette MCP

**What this means for the user:** today nobody can test this game without three humans in a room. This step is what removes that.

**The gap:** Antigravity has no way to see or touch a running Flutter app.

### Implementation

1. Install the server:

```bash
dart pub global activate marionette_mcp
```

2. Confirm the executable landed, and note that its directory is **not** on `PATH` — the config below must use the absolute path:

```bash
ls -l /Users/louisye/.pub-cache/bin/marionette_mcp
```

3. Create `.agents/mcp_config.json` (the `.agents/` directory already exists and holds this project's skills). **Three entries, distinct names, same executable** — see trap 13:

```json
{
  "mcpServers": {
    "marionette-p1": { "command": "/Users/louisye/.pub-cache/bin/marionette_mcp", "args": [] },
    "marionette-p2": { "command": "/Users/louisye/.pub-cache/bin/marionette_mcp", "args": [] },
    "marionette-p3": { "command": "/Users/louisye/.pub-cache/bin/marionette_mcp", "args": [] }
  }
}
```

4. Reload MCP servers: **…** in the agent side panel → **MCP Servers** → **Manage MCP Servers**. (Antigravity 2.0: Settings → Customizations → Installed MCP Servers. CLI: `/mcp`.) The global alternative to the workspace file is `~/.gemini/config/mcp_config.json`; prefer the workspace file so the config travels with the repo.

### Validation

**The falsifying check:** all **three** servers must appear with their own toolsets. If only one appears, or the tools are not namespaced per server, the three-client plan does not work and everything downstream is invalid. Record the tool names you actually see.

Expected tools per server: `connect`, `disconnect`, `get_interactive_elements`, `take_screenshots`, `tap`, `double_tap`, `long_press`, `swipe`, `scroll_to`, `enter_text`, `press_key`, `press_back_button`, `hot_reload`, `hot_restart`.

### Blast radius

`.agents/mcp_config.json` is new. Nothing else.

---

## 4. M2 — Instrument the app

**What this means for the user:** without this, an agent can see the screen but cannot reliably tell the "3 forgeries" button from the "3 rounds" button — and a test that taps the wrong thing and reports success is worse than no test.

**The gap:** `lib/main.dart:23` installs the stock binding, so no VM service extensions exist for Marionette to call. And the controls this playthrough must operate carry no keys.

### Implementation

1. Add the package as a **regular dependency** — it is imported from `lib/`, so it cannot be a dev dependency:

```bash
flutter pub add marionette_flutter
```

Expected: `marionette_flutter: ^0.6.0`. **If resolution fails against Flutter 3.44.6 / Dart 3.12.2, STOP and file it per §8.** Do not force a version or relax the SDK constraint.

2. `lib/main.dart:23` — replace the single binding line:

```dart
  WidgetsFlutterBinding.ensureInitialized();
```

with:

```dart
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
```

Add `import 'package:marionette_flutter/marionette_flutter.dart';` to the imports. **`kDebugMode` needs no new import** — `package:flutter/material.dart`, already imported, re-exports it. The `else` branch is not optional: release builds must keep the stock binding.

3. `lib/screens/lobby_screen.dart:569` — the Forgeries chooser. Add as the first argument to `ChoiceChip(`:

```dart
                                        key: ValueKey('forgeries_$f'),
```

4. `lib/screens/lobby_screen.dart:600` — the Rounds chooser. Add as the first argument to `ChoiceChip(`:

```dart
                                        key: ValueKey('rounds_$r'),
```

5. Add these four keys to their widgets, unchanged otherwise:

| File:line | Widget | Key to add |
|---|---|---|
| `lib/screens/lobby_screen.dart:971` | name `TextField` | `key: const ValueKey('player_name_field'),` |
| `lib/screens/lobby_screen.dart:1057` | room-code `TextField` | `key: const ValueKey('room_code_field'),` |
| `lib/screens/phase2_craft.dart:431` | answer `TextField` | `key: const ValueKey('answer_field'),` |
| `lib/widgets/deck_carousel.dart:190` | deck `GestureDetector` | `key: ValueKey('deck_$deckId'),` |

`deckId` is already in scope at `deck_carousel.dart:139`. Line numbers drift — **re-grep before editing**; anchor on the widget constructor, not the number.

### Validation

- `flutter analyze lib test` → **0 errors**, and the warning/info counts must not rise above 24/197.
- `flutter test` → **127/127**. Keys are additive and no existing test matches on them; if a test breaks, your edit changed behaviour and is wrong.
- **The falsifying check:** after M3 connects, `get_interactive_elements` on the host device must return elements whose keys include `forgeries_1` and `rounds_1` as *distinct* entries. If both rows still come back as unkeyed chips labelled `1`, the keys did not take effect and M4 assertion 1 cannot be trusted.

### Blast radius

`pubspec.yaml`, `pubspec.lock`, `lib/main.dart`, `lib/screens/lobby_screen.dart`, `lib/screens/phase2_craft.dart`, `lib/widgets/deck_carousel.dart`. One commit: `test(harness): add Marionette runtime driving and stable keys for agent playthrough`.

---

## 5. M3 — Launch three clients and connect

**What this means for the user:** a device that silently failed to install, or restored into last week's room, burns the whole session and nobody notices until the findings are already wrong.

### Preflight

Confirm `.env` contains `USE_EMULATOR=false`. It is bundled into the app — if you change it, rebuild.

### Implementation

1. Boot the three simulators:

```bash
xcrun simctl boot "iPhone 17"; xcrun simctl boot "iPhone 17 Pro"; xcrun simctl boot "iPhone Air"; open -a Simulator
```

2. **Uninstall first on every device** — `SharedPreferences` survives a reinstall-over and will restore a device into a stale room:

```bash
for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl uninstall "$U" com.whylabs.gaslight 2>/dev/null; done
```

3. Launch **one device at a time** (trap 17). For each UDID in turn, run it in the background and wait for the URI to appear before starting the next:

```bash
flutter run -d <UDID> --debug > /tmp/gaslight_p1.log 2>&1 &
```

4. Extract each VM service URI and convert it to the WebSocket form Marionette expects — `flutter run` prints `http://127.0.0.1:PORT/TOKEN=/`, Marionette wants `ws://127.0.0.1:PORT/TOKEN=/ws`:

```bash
grep -oE 'http://127\.0\.0\.1:[0-9]+/[^ ]*' /tmp/gaslight_p1.log | tail -1 | sed -e 's|^http|ws|' -e 's|/$|/ws|'
```

5. `marionette-p1.connect` → P1's URI. `marionette-p2.connect` → P2's. `marionette-p3.connect` → P3's. **Write down which UDID and which device name is behind each server** — every observation in M5 must name the device it came from.

### Validation

**The gate:** `take_screenshots` on all three and confirm each one shows **`THE GUEST LEDGER`**. A device showing anything else — a stale lobby, a crash, a white screen — is not ready. Do not proceed with two working devices; three is the minimum player count and it is enforced server-side.

Also record, from `get_logs` on each device, that Firebase initialised and anonymous sign-in succeeded. A device that failed sign-in will produce confusing permission failures later that look like rules bugs and are not.

---

## 6. M4 — The eleven assertions

**Setup, before assertion 1:**

- P1 is host. On P1: `enter_text` into `player_name_field` → `Alpha`, then `tap(text: 'CREATE ROOM')`. Read the room code off the screen under `ROOM CODE`.
- P2 and P3: `enter_text` into `player_name_field` → `Bravo` / `Charlie`, `enter_text` into `room_code_field` → the code, then `tap(text: 'JOIN ROOM')`.
- On P1, turn **on** the `Disable Game Timers` switch in House Rules (**trap 20**). **This is a deliberate deviation and you must record it in the findings doc.** An agent is slower than a human and phase auto-advance would otherwise fire mid-assertion; no assertion below tests timer behaviour, so nothing in scope is lost.
- Leave `Family-Friendly Decks Only` **off** — its default (**trap 19**). It hides `cah_dark_humor`, which assertion 4 needs.
- Confirm the §4 keys took effect (**trap 14**) before touching House Rules: `get_interactive_elements` on P1 must show `forgeries_*` and `rounds_*` as distinct keyed elements. If it does not, **stop here** — assertion 1 cannot be trusted and neither can any House Rule you set below.

**Use distinct, memorable answer text per device** — e.g. prefix every answer Alpha writes with `AAA`, Bravo's with `BBB`, Charlie's with `CCC`. Assertion 8 is only checkable because you know who typed what.

Run in this order. **Items 9 and 10 destroy the room.**

| # | Assertion | How to drive it | Verdict comes from |
|---|---|---|---|
| 1 | **Forgery chooser range.** Offers only `1 … n − 1`, defaults sensibly for the player count, and allows more than 5 when players allow. | `get_interactive_elements` on P1's House Rules; enumerate every `forgeries_*` key present and which is selected. With 3 players expect exactly `forgeries_1`, `forgeries_2`. | The key list — exact, not a screenshot |
| 2 | **Truth phase first.** Everyone answers their *own* prompt before any lie is written. | Read each device's phase-2 screen after `START GAME`. | The prompt/answer copy on all three |
| 3 | **Re-roll variety.** `tap(text: 'RE-ROLL PROMPT')` several times — a different prompt every time, never a repeat. | Capture the prompt text after each re-roll. | The sequence of prompt strings, recorded verbatim |
| 4 | **Deck exhaustion.** On `cah_dark_humor` (12 prompts), re-roll to exhaustion. | Select via `tap(key: 'deck_cah_dark_humor')` in the lobby, then re-roll past the end. | The message must read exactly `No more prompts left in this deck.` — **not** the generic fallback |
| 5 | **Reveal is readable.** Prompt and answer text plainly readable; no red-and-yellow overflow stripe anywhere. | Play to the reveal; `take_screenshots` on all three. | **The pixels.** The overflow stripe is visible in a screenshot; "plainly readable" is a judgement — state yours and attach the image |
| 6 | **`THE SOUL IS SILENT` must not appear** when everyone answered. | Ensure all three submitted, then read the reveal. | Search the reveal text on all three. **This is the check that matters most** — it was Issue 76 |
| 7 | **Points name real players**, not `Unknown`. | Read `POINTS AWARDED THIS CARD` on the reveal. | The names. `Unknown` here was Issue 71 |
| 8 | **Attribution is correct** — for two forgeries, the named author actually wrote it. | Cross-reference the reveal's attribution against your `AAA`/`BBB`/`CCC` prefixes. | Your own ground truth. A silent misattribution is what the opaque-UUID change could produce, and you are better placed to catch it than a human is |
| 9 | **A non-host leaves** → room survives, host sees them go. | On P3: `tap(text: 'LEAVE')`, then confirm. | P1 and P2 still in the room; P1's roster updates |
| 10 | **The host leaves** → both others land on the entry screen. | On P1: `tap(text: 'LEAVE')` → `CLOSE ROOM`. | P2 and P3 must show exactly `The host has left. This room has closed.` — verbatim, including the period |
| 11 | **TTL.** A fresh room and its host player document both carry `expiresAt` ~8 h ahead. | **Not Marionette-verifiable.** | Record as **NOT RUN**, and say why. Do not guess, and do not quietly omit it |

**If any assertion cannot be reached** — the game will not start, a device drops, a phase never advances — that is itself a finding. Record what you saw, mark every downstream assertion **NOT RUN**, and continue with whatever remains reachable. A blocked run that reports six honest NOT RUNs is worth more than one that reports six passes it did not observe.

---

## 7. M5 — Write the findings doc

Create **`docs/playthrough_findings_marionette.md`**. This is the deliverable Claude Code reads. Do **not** write into `ongoing_general_errors.md` — that doc's issue format and its `Your selection:` lines are the user's, and Claude Code owns the conversion from your findings to tracked issues.

Header: date, commit SHA, the three device names and their UDIDs, the app's build mode, `USE_EMULATOR` value, Marionette and `marionette_flutter` versions, and the deliberate deviation (timers disabled).

Then **one block per assertion, all eleven, in order** — including the ones that passed and the one that did not run:

```markdown
### A1 — Forgery chooser range

**Verdict:** PASS | FAIL | NOT RUN
**Devices:** P1 `iPhone 17` (host, Alpha)
**What I did:** <the exact tool calls, in order>
**What I observed, verbatim:** <exact strings / exact key list — no paraphrase>
**Expected:** <what the assertion required>
**Evidence:** docs/playthrough_evidence/a1_p1.png
```

Save screenshots to `docs/playthrough_evidence/`. **Commit the images only for FAIL and NOT RUN blocks**, so the repo does not accumulate passing screenshots; for PASS blocks, the verbatim strings are the record.

Close the doc with:

- **A battery re-run** after all your edits: `flutter analyze lib test` · `flutter test` · `npm --prefix functions run build` · `npm --prefix functions test`, with the real numbers, compared against §1.
- **A short "what the harness could not see" section** — anything you could not judge from the widget tree or the pixels. Be specific; this is the input to the next cycle's spec.

Commit separately from M2: `docs(playthrough): record Marionette-driven three-client findings`.

---

## 8. Do not invent work · escalation

Every tracked engineering issue is resolved. **If the playthrough finds nothing, stop.** The only legitimate triggers for further work are: a defect this playthrough surfaces, a user-selected issue, or a stated trigger from §11 firing.

**Bounded deviation:** if an exact value or step here is impossible, keep the intent, deviate minimally, and record the deviation in the findings doc. **If the design itself cannot work — Marionette will not resolve, the binding breaks the build, three servers will not register — STOP.** Do not improvise a substitute harness, and do not fall back to `DEBUG: ADD 9 BOTS`. File it in `ongoing_general_errors.md` with options and a `Your selection: _____` line, and leave that line blank.

**One short check is worth doing before the next deploy**, and it is not a known defect: confirm `submitAnswer`'s `authorId` is bound to `request.auth.uid` before it is used as the write key. If it is not, a client could write into another player's slot. This was unverifiable in the last pass, not found broken.

---

## 9. Already delivered — do NOT rework

Verified in source at `1e12748`:

- **Issue 76** — `submitAnswer` validates against `room.currentCardAssignments?.[authorId]` (`index.ts:~495`), so author and holder are provably the same identity and the timeout fill can no longer miss a real answer.
- **Issue 72** — default `Math.min(activePlayers.length - 1, 5)` (`index.ts:266`), derived from the live count; `updateLobbySettings` rejects out-of-range with `invalid-argument` against `maxAllowed = numPlayers - 1`; `isExplicitForgeriesUpdate` keeps "unset" distinct from an explicit choice; `totalRounds` bounded 1–5; the **3-player floor is its own guard** (`index.ts:260`); the chooser renders `1 … min(n − 1, 8)`.
- **Issue 71** — `castVote` resolves option ids via `sealedData.answerAuthors` (`index.ts:545–546`); tests at `game_e2e.spec.ts:1390`.
- **Issues 73–75** — `EVALUATE READY STATE (HOST)` removed, reactions removed, standings reworked.
- **Issues 50–70** as previously recorded.
- **Issue 31** — the server uses loose `!= null`; **never "simplify" to a falsy check**.
- **Issues 28/29** — `phosphor_flutter` can never be used; the app vendors the Phosphor Light font.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · project `gaslight-46368` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 10. Accepted equivalents — do NOT "fix" back

- **Issue 76 validates rather than re-derives.** The spec asked for the forgery write key to be re-derived server-side; the implementation keeps `[authorId]` and validates it against `currentCardAssignments`. **Same guarantee, different structure — leave it.**
- **Leaving a room does not call `Navigator` explicitly** — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null.
- **The non-host carousel is interactive-but-inert, not dimmed.**
- **`pumpAndSettle()` and `pump()` + `pump(500ms)` are both acceptable** once `accessibleNavigation: true` is set.
- **The leave dialog uses `showGeneralDialog`, not `showDialog`.**
- **`lastReaction` / `lastReactionAt` remain on `PlayerState` and in the rules deliberately** (Issue 74) — dead fields kept to avoid a rules deploy and migration. Do not resurrect the feature; do not delete them without the rules change.
- **The `prompt_decks` TS/Dart pair is data-only**; error plumbing deliberately differs. **`text_similarity` must stay byte-identical.**
- **Sealed documents are created lazily**, not at `startGame`.
- **`_ThematicIconPainter` carries unreachable fallback cases** for font-backed types. Do not delete or wire them up.

---

## 11. Intentional decisions / invariants — do NOT change

- **Server-authoritative**; room reads stay open; `/rooms/{code}/sealed/{cardId}` is default-deny and holds the answer key, `answerAuthors`, and `seenPrompts`. **Never add an explicit `allow read: if false`.**
- **Option ids are opaque UUIDs**, resolved to authors server-side. **Never send authorship to the client.**
- **Phase order is truth → forgery → vote → reveal.**
- **Minimum 3 active players**, enforced as its own guard — never as a side effect of the forgery arithmetic.
- **Forgeries per card: hard ceiling `n − 1`; `5` is a default, not a cap; values above `n − 1` are never presented.**
- **Re-rolls are unlimited during `truth`, rejected elsewhere, and never repeat a prompt.**
- **`ROOM_TTL_MS` is 8 hours**; below ~4 h a host-only `touchRoom` keepalive plus a client timer become mandatory.
- **`firebase.json`'s `predeploy` stays** and runs the tests.
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 Option C, Issue 34 Option C, Issue 57 B/C, Issue 67 A/C, Issue 68 B/C, Issue 69 B/C, Issue 70 A/C, Issue 71 B/C, Issue 76 B, and the rejected options on 58–66.

---

## 12. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| **This run's findings** | `docs/playthrough_findings_marionette.md` (you create it) |
| Backend writes, rules, identity, TTL, **deploy & verification §8** | `design_database_and_security.md` |
| Card passing, rotation, the forgery ceiling | `design_rotation_engine.md` |
| Scoring, routing, gameplay programme | `design_scoring_and_ui.md` |
| Palette, typography, icons, mascot | `design_ui_direction.md` |
| **Phase order, rounds, forgeries, the 3-player minimum** | `design_game_state_and_models.md` |
| Deck catalogue, re-roll exclusion, mirror status | `design_prompt_system.md` |
| PNG decoding + WCAG contrast helper | `test/helpers/png_decoder.dart` |
| Font glyph identity | `scripts/inspect_glyph.py` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 13. Validation standard

**Write validation that fails against the broken state, and observe it fail.**

**A test that asserts the happy path of a bug is not a test for the bug.** Issue 76 once shipped "done" while the only placeholder tests asserted the placeholder *should* appear.

**A green suite is not evidence about anything it cannot observe.** Issues 71 and 76 were both live in production with all four gates green. A playthrough found them.

**A driven playthrough is not a played one.** You can check every string in §6 and still miss that the game is confusing, badly paced, or not fun. Say so in your "what the harness could not see" section rather than implying coverage you do not have.

**Assert a derived default at two different inputs** — one value cannot pass both.

**A clamp is not a rejection.** **A client-only bound is not a bound.**

**Measure; do not estimate.** **Do not weaken an assertion or delete a test to reach green.**

---

## 14. Feedback loop — what past specs got wrong

- **A guide's title is not its contents.** This document was twice retitled "Queue Complete" while its body still specified unfinished work. **When you close a queue, rewrite the body — or the title is a lie with a checkmark on it.**
- **An item can be marked done because the *other* items in its commit were.** Issues 71–76 landed as one commit; five were real and Issue 76 was untouched, yet the batch read as complete. **One item = one commit** exists for exactly this.
- **A default that must be derived from live state cannot be baked in at creation.** `min(n − 1, 5)` is `0` at `createRoom`, so the first implementation fell back to a constant and the rule quietly vanished.
- **The manual gate earns its keep every time it runs.** One playthrough surfaced six issues, two of them production correctness defects four green gates could not see.
- **A blocker that costs a human's time gets deferred forever.** Issue 70 sat for seven cycles not because it was hard but because it needed a person. **When an item keeps slipping, the fix is usually tooling, not discipline** — this build is that fix.
- **When you redefine what a field holds, enumerate its readers.** `votes` silently changed meaning and broke scoring, the self-vote guard, and the reveal.
- **Doc structure rots silently.** Append inside the existing Resolved heading; never add a second.

---

## THE LOOP

```
(1) STUDY the item here + the options in ongoing_general_errors.md + the exact files
    at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified.
(3) VALIDATE per §13. Observe the falsifying check fail first where one exists,
    and record it.
(4) BEFORE COMMITTING, re-run the battery. One item = one commit.
(5) BLOCKED, or found something needing human judgement? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
(6) RECORD: findings go in docs/playthrough_findings_marionette.md, per assertion,
    verbatim. Never "playthrough passed".
(7) COMMIT: Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **M1** — three Marionette servers registered and visible in Antigravity with per-server toolsets.
- [ ] **M2** — binding installed under `kDebugMode`, six keys added, committed as one commit.
- [ ] **M2 gate** — `get_interactive_elements` returns `forgeries_*` and `rounds_*` as distinct keyed elements.
- [ ] **M3** — three devices launched, connected, and **screenshotted showing `THE GUEST LEDGER`** before any assertion runs.
- [ ] **All three confirmed hazards handled before assertion 1** — keys verified live (trap 14), `Family-Friendly Decks Only` off (trap 19), `Disable Game Timers` on (trap 20).
- [ ] **M4** — all eleven assertions attempted; every one has a PASS, FAIL, or NOT RUN with a reason.
- [ ] **M5** — `docs/playthrough_findings_marionette.md` exists, has one block per assertion with verbatim observations, records the timers-disabled deviation, and ends with a re-run battery and a "what the harness could not see" section.
- [ ] Battery unchanged at or above the §1 bar: `flutter analyze lib test` **0 errors** · `flutter test` **127/127** · functions build clean · `npm --prefix functions test` **43/43**.
- [ ] **Nothing was fixed inline.** Failures are described, not repaired.
- [ ] **If the playthrough finds nothing: stop.** Do not invent work (§8).
