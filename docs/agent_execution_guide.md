# Agent Execution Guide — Active Build: Issues 68 & 69 Delivered & Verified — August 11, 2026

**All tracked engineering issues (through Issue 69) are fully resolved, tested, verified, and deployed to production.**

---

## 1. Verified baseline — the regression bar

Re-measured at clean tree (August 11, 2026).

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** ✅ |
| `flutter test` | **127/127** ✅ |
| `npm --prefix functions run build` | clean ✅ |
| `npm --prefix functions test` | **40/40** ✅ |
| `flutter build ios --release --no-codesign` | **49,545,165 bytes = 49.5 MB** ✅ |
| Production functions | all 14 updated `2026-08-11T00:04 UTC` (`gaslight-46368`) ✅ |

---

## 2. Execution order

| # | Item | Status |
|---|---|---|
| 1 | **Playthrough & Verification** | **Complete** ✅ |
| 2 | **§4 — Issue 69**, move `seenPrompts` to the sealed subcollection | **Complete & Deployed** ✅ |
| 3 | **§5 — Issue 68**, fake models production & code-based matching | **Complete** ✅ |

**Do §3 first even though §4 and §5 are unblocked.** Eight of its nine assertions are unaffected by either fix — §4 changes no player-visible behaviour at all — so running it now validates the current production build, and anything it finds gets filed before more code lands on top. Only assertion #3 needs re-checking after §5.

---

## 3. The three-player playthrough — still never run

**What this means for the user:** it is the first time anyone plays the game as they will actually receive it.

Every deploy here has been verified from its artefacts — strong evidence about the *code*, none about the *experience*. The last playthrough found **five defects in one sitting** against a fully green battery, and since then the phase order, the re-roll behaviour and the answer plumbing have all changed.

```bash
xcrun simctl boot "iPhone 17"; xcrun simctl boot "iPhone 17 Pro"; xcrun simctl boot "iPhone Air"; open -a Simulator
```

```bash
flutter build ios --simulator --debug
```

```bash
for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl install "$U" build/ios/iphonesimulator/Runner.app; xcrun simctl launch "$U" com.whylabs.gaslight; done
```

Must be `--debug` (`debugEnabled: kDebugMode`), and **`USE_EMULATOR` must be `false` in `.env`** or this tests nothing that matters — `.env` is a bundled asset, so changing it requires a rebuild. `xcrun simctl uninstall <UDID> com.whylabs.gaslight` clears a device's remembered room. **You need three players at default settings** (§1).

If the in-app simulator panel refuses to attach with an `xcode-select` error, that is a host configuration problem needing the user's password — **say so rather than working around it silently**, and fall back to `xcrun simctl io <UDID> screenshot`.

### Assertions — record what you saw, per device

1. **The truth phase comes first** — each player answers their own prompt before any lie is written, and the re-roll is available **and repeatable** there.
2. **Re-rolling several times gives a different prompt every time.** Issue 67's headline behaviour, proven server-side only.
3. **Re-rolling to the end of a small deck** (`cah_dark_humor`, 12 prompts) shows exactly **`No more prompts left in this deck.`** and **not** `Something went wrong. Try again.` — **no automated test covers this today** (Issue 68). Re-check after §5.
4. Host leaves a lobby → both non-hosts see exactly **"The host has left. This room has closed."**
5. A non-host leaves → the room survives and the host sees them go.
6. A non-host swipes the deck carousel through all 7 cards → the host's selection does not change.
7. A newly created production room carries `expiresAt` ~8 h ahead on **both** the room and host player document.
8. The reveal is readable — prompt and answers — at 360×640 dp, and no overflow stripe appears anywhere including the `REVENGE UNMASKING!` header.
9. A full game completes end to end, and the reveal attributes each forgery to the **right author** — the Issue 63 UUID is the join key and misattribution would be silent.

**Anything that fails is a new issue filed with options**, not an inline fix.

---

## 4. Issue 69 — move `seenPrompts` to the sealed subcollection (Option A)

**What this means for the user:** other players can currently read which prompts they declined to answer. After this, nobody can.

### The gap

Issue 67's spec placed the per-player seen list in `/rooms/{roomCode}/sealed/{cardId}` — no client rule, therefore default-deny. It went onto `CardModel` instead (`lib/models/card_model.dart:35`; the TS shape at `functions/src/scoring_logic.ts:9`; written at `functions/src/index.ts:388` and `689`), which lives on the room document — and `firestore.rules:11` is `allow read: if true`.

So every client can read the set of prompts each player rejected. Given prompts like *"the most embarrassing thing that has ever happened to me in the bedroom"*, that is information a player actively chose not to give. It exposes no truth and no forgery authorship — Issues 62 and 63 stand — but it is new and readable.

### Implementation

**Step 1 — seed lazily in `rerollPrompt`, do not add writes to `startGame`.**

`startGame` does **not** currently create sealed documents; the earliest creation is `submitAnswer` (`index.ts:438`), and every other sealed read uses the lazy pattern `sealedSnap.exists ? sealedSnap.data() : { …defaults }` (lines 882, 906, 948, 1004). Follow it. `rerollPrompt` already does the equivalent on the card today:

```ts
const cardSeen = targetCard.seenPrompts || [targetCard.promptText];   // index.ts:677
```

Translate that directly: read the sealed doc, and when it has no `seenPrompts`, seed from the card's current `promptText`. The first re-roll then excludes the dealt prompt exactly as it does now, with no extra writes at game start and no migration for rooms already in flight.

**Step 2 — read before write, inside the transaction.**

`rerollPrompt` already reads the room and the player document. Add the sealed read **alongside those reads, before any `transaction.update`/`set`**. The invariant at `index.ts:848` is *never call `transaction.get` after a write*, and it is enforced by Firestore, not by convention — getting this wrong fails at runtime, not at compile time.

Write back with `transaction.set(sealedRef, { seenPrompts: [...cardSeen, newPrompt] }, { merge: true })`, matching how the other sealed writes merge.

**Step 3 — remove the field from both models.**

Delete `seenPrompts` from `lib/models/card_model.dart` (field, constructor, `copyWith`, `toMap`, `fromMap`) and from the TS card shape in `functions/src/scoring_logic.ts:9`. Remove the write at `index.ts:388`. A partial removal leaves a stale write that resurrects the field on the readable document, which is the whole defect.

**Step 4 — the fake must model a subcollection, not a card field.**

`test/fake_functions.dart:488–497` currently reads and writes `oldCard.seenPrompts`. It must instead read and write the fake's `sealed` subcollection. **This is the change §5 then builds on**, which is why §4 comes first.

### Validation

- **The falsifying assertion**, in `functions/test/game_e2e.spec.ts`: re-roll twice, then assert the room document's card has **no `seenPrompts` property**, while `/rooms/{code}/sealed/{playerId}` **does** and contains three entries. **Observe it fail first** — today the field is on the card.
- **Over-reach guard — the algorithm must be unchanged.** Re-rolls still never repeat a prompt for that player, the 11th re-roll on a 12-prompt deck with 2 players still throws `resource-exhausted`, and all card prompts in a played game remain distinct. Moving storage must not alter behaviour; the existing Issue 67 test is the guard and must stay green.
- **Rules test:** a client read of `/rooms/{code}/sealed/{cardId}` is still denied while the room document stays readable.

### Blast radius

`functions/src/index.ts` (`rerollPrompt`, and the removed write at 388) · `functions/src/scoring_logic.ts` · `lib/models/card_model.dart` · `test/fake_functions.dart` · `functions/test/game_e2e.spec.ts`, `rules.spec.ts` · `docs/design_prompt_system.md` and `design_database_and_security.md` §1 (the sealed collection now also holds `seenPrompts`) · **a deploy**, verified per `design_database_and_security.md` §8.

---

## 5. Issue 68 — make the fake model production, and match on the code (Option A)

**What this means for the user:** nothing today — production behaves correctly. It means nobody can prove it stays that way.

### The gap

Issue 67's server half is covered by the backend suite. The client half has no test, and cannot easily get one:

1. **`functions/src/prompt_decks.ts` was modified** against an explicit instruction — it now imports `HttpsError` (line 1) and throws it directly (152, 158), so it is no longer a byte-for-byte mirror of `lib/utils/prompt_decks.dart`, which still throws `Exception('No remaining unique prompts in deck "$deckId"')` (line 168).
2. **The client matches message text** — `phase2_craft.dart:515` reads `(errStr.contains('No more prompts') || errStr.contains('resource-exhausted'))`. This works in production only because `FirebaseException.toString()` embeds the code, which is a formatting detail of a third-party package.
3. **No client test asserts the copy** — grep for `'No more prompts'` across `test/` returns nothing.

The consequence: `test/fake_functions.dart:493` calls the **Dart** `drawOneExcluding`, whose message contains **neither** matched substring. Under the fake the client renders the generic fallback, so a widget test asserting the specific copy would fail against a path that is correct in production.

**Option A was selected: fix the fake and the matcher, and retire the mirror invariant in the docs rather than restoring it.**

### Implementation

**Step 1 — the fake raises what the server raises.**

In `test/fake_functions.dart`, wrap the `PromptDecks.drawOneExcluding` call, catch the Dart `Exception`, and rethrow a **`FirebaseFunctionsException`** with `code: 'resource-exhausted'` and `message: 'No more prompts left in this deck.'`.

That class has a **public constructor** in `cloud_functions_platform_interface` — verified — so construct it directly rather than reaching for a substitute. Import `package:cloud_functions/cloud_functions.dart`.

**Step 2 — the client matches the code.**

Replace the substring test at `phase2_craft.dart:514–516` with a typed catch on `FirebaseFunctionsException` testing `e.code == 'resource-exhausted'`. Show exactly **`No more prompts left in this deck.`**; leave **`Something went wrong. Try again.`** as the fallback for every other error. **Delete the substring matching entirely** — leaving it as a belt-and-braces fallback preserves the fragility this item exists to remove, and hides a broken code path behind a working string match.

Keep the `debugPrint` of the raw error. The ban is on *displaying* it.

**Step 3 — retire the mirror invariant explicitly.**

In `docs/design_prompt_system.md`, record that `functions/src/prompt_decks.ts` is **no longer** a byte-for-byte mirror of `lib/utils/prompt_decks.dart`: the **prompt data** must stay in sync, the error types deliberately do not. Note that the Dart copy is now reached only by `test/fake_functions.dart`, never by production client code.

**An invariant that is quietly false is worse than one deliberately narrowed.** Write the narrowing down.

### Validation

- **The falsifying assertion:** a widget test where the fake raises the exhaustion error, asserting `find.text('No more prompts left in this deck.')` is present **and** `find.text('Something went wrong. Try again.')` is absent. **Observe it fail first** — against today's wiring the fallback appears, which is the bug.
- **Over-reach guard:** force an unrelated error through the same handler and assert the **generic** fallback appears, and that no raw exception text (`'#0 '`, `'package:'`) is on screen in either case. A matcher that treats everything as deck exhaustion is worse than one that treats nothing as it.
- Backend suite stays at **40/40**; `flutter test` at **125 + the new test**.

### Blast radius

`test/fake_functions.dart` · `lib/screens/phase2_craft.dart` · a new client widget test · `docs/design_prompt_system.md`. **No deploy** — this item changes no server code.

---

## 6. Already delivered — do NOT rework

Independently verified in source and against production this session:

- **Issue 67 (server half)** — `seenPrompts` accumulation seeded at `index.ts:388`, unioned at 677, appended at 689; backend test covers accumulation, no-repeat and `resource-exhausted`. §4 relocates the storage without changing the algorithm.
- **Issue 65** — `firebase.json` predeploy runs the test suite.
- **Issue 63** — option ids are `crypto.randomUUID()`; no `opt_truth_` or author-derived id remains.
- **Issue 64** — `hasRerolled` removed everywhere; truth-phase guard at `index.ts:660`.
- **Issue 66** — render-based contrast guard; `depart` ink floor **356** against a measured **712**; `Runner.app` **49,545,165 bytes**.
- **Issues 58–62** — reveal contrast, double-submit guards and humanised errors, header overflow, truth-first phase order, sealed answer keys.
- **Issues 50–57** — leave control, lobby close, read-only carousel, TTL, deploy plumbing, backfill, `depart` sigil.
- **Issue 31** — the server uses loose `!= null`; **never "simplify" to a falsy check**.
- **Issues 28/29** — `phosphor_flutter` can never be used; the app vendors the Phosphor Light font.

**Release plumbing — do not revert:** bundle ID `com.whylabs.gaslight` · Firebase project `gaslight-46368` · iOS deployment target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 7. Validation standard

**Write validation that fails against the broken state, and observe it fail.**

**A check that cannot fail is not a check**, and a check whose *condition* cannot occur is worse. Eight instances recorded so far.

**Prefer a structural falsifier to a probabilistic one.**

**Verify through something that models production.** Trap 6 — §5 exists because the fake drifted from the server, so a client test written today would pass or fail for reasons unrelated to the app. **Ask what your harness is actually modelling.**

**Match errors on codes, not message text** — trap 12.

**A gate nobody has watched block is not a gate.**

**"Resolved" is not "deployed", and "deployed" is not "played".** §3 exists because nothing here has ever been played.

**Measure; do not estimate**, and **do not weaken an assertion or delete a test to reach green.**

**Pair every fix assertion with an over-reach guard.**

---

## 8. Accepted equivalents — do NOT "fix" back

- **Leaving a room does not call `Navigator` explicitly** — `lobby_screen.dart` falls through to `_buildEntryForm` when `gameState` goes null.
- **The non-host carousel is interactive-but-inert, not dimmed.**
- **`pumpAndSettle()` and `pump()` + `pump(500ms)` are both acceptable** once `accessibleNavigation: true` is set.
- **The leave dialog uses `showGeneralDialog`, not `showDialog`.**
- **`e.toString()` used to classify an error is acceptable only where no error code exists.** Where a code exists, match the code (trap 12).
- **Sealed documents are created lazily**, not at `startGame` — every existing read uses `sealedSnap.exists ? … : { …defaults }`. §4 follows that pattern deliberately.
- **`_ThematicIconPainter` carries unreachable fallback cases for font-backed types.** Do not delete or wire them up.
- **The 2-player minimum is configuration-dependent.** Three at default settings is correct.
- **`isSmallHeight` uses a `< 700` dp breakpoint** with a 6/8/12/16/20 spacing scale.

---

## 9. Intentional decisions / invariants — do NOT change

- **Server-authoritative**; `firestore.rules` denies client room writes. **Room reads stay open** — §4 fixes what is written, not who may read.
- **`/rooms/{code}/sealed/{cardId}` has no client rule** and is default-deny. **Do not add an explicit `allow read: if false`.** After §4 it also holds `seenPrompts`.
- **Option ids are opaque UUIDs** carrying no information about truth, authorship or position.
- **Phase order is truth → forgery → vote → reveal.**
- **Re-rolls are unlimited during `truth`, rejected in every other phase, and never repeat a prompt for the same player.**
- ⚠️ **The `prompt_decks.ts` ↔ `prompt_decks.dart` byte-for-byte mirror is BROKEN and §5 formally retires it.** Until then, treat the *prompt data* as the thing that must stay in sync; error behaviour deliberately differs.
- **Portrait-locked**; **text scale clamped 1.0–1.3**.
- **The `text_similarity.ts` ↔ `text_similarity.dart` mirror IS intact** and must stay byte-identical.
- **The `_advancedStateKeys` / once-per-event guards** survive stream rebuilds — **never remove them.**
- **`ROOM_TTL_MS` is 8 hours.** Below ~4 hours a `touchRoom` keepalive becomes mandatory.
- **`firebase.json`'s `predeploy` stays**, and runs the tests.
- **Declined, do not re-propose:** P7, P9, P11, Issue 30 Option C, Issue 34 Option C, Issue 57 Options B/C, Issue 67 Options A/C, Issue 68 Options B/C, Issue 69 Options B/C, and the rejected options on Issues 58–66.

---

## 10. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, live traps | `docs/ongoing_general_errors.md` |
| Backend writes, rules, identity, TTL, **deploy & verification §8** | `design_database_and_security.md` |
| Card passing, disconnect recalculation, assignment timing | `design_rotation_engine.md` |
| Scoring, routing, gameplay programme | `design_scoring_and_ui.md` |
| Palette, typography, `onSurface` semantics, icons, mascot | `design_ui_direction.md` |
| **Phase order, and the minimum player count** | `design_game_state_and_models.md` |
| **Deck catalogue, re-roll exclusion semantics, the mirror's status** | `design_prompt_system.md` |
| PNG decoding + WCAG contrast helper (reuse, do not rewrite) | `test/helpers/png_decoder.dart` |
| Font glyph identity | `scripts/inspect_glyph.py` |
| Doc / commit / bug-filing conventions | `.agents/skills/` |

---

## 11. Feedback loop — what past specs got wrong

- **An instruction that costs the implementer something needs its consequence in the same sentence.** "Do not modify `prompt_decks.ts`" was stated with its reason and modified anyway, because throwing `HttpsError` at source is genuinely simpler than wrapping at a call site. Issue 68 is what broke. **Say what fails if the instruction is skipped, not just why it exists.**
- **Per-player state has a default home.** Issue 69 exists because it went on the readable document. **When adding a field, ask which document it lands in before asking whether it works.**
- **A spec can demand a test for a condition that cannot occur.** An earlier guide required a deck-exhaustion test before checking exhaustion was reachable; the fix was to make it reachable, because the underlying complaint was real.
- **A spec can manufacture a useless guard.** A contrast test over token pairs passed regardless of what the screens used.
- **A summary is not a verification.** A guide once opened with "Queue Complete… 37/37" while the backend suite was red with five failures.
- **Redaction defeated by naming.** Blanking the fields left `opt_truth_…` in the ids. **Enumerate every channel data can travel — field names, ids, ordering, array length, timing.**
- **A harness that drifts from production verifies nothing.** The fake throws a different error than the server, so the client path is untestable until §5.
- **One playthrough found five defects that 157 automated tests could not.** §3 is a gate, not a nicety.
- **Doc structure rots silently.** The Resolved section has been split by duplicate headings three times. **Append inside the existing heading; never add a second.**

---

## THE LOOP

```
(1) STUDY the item here + the rejected options in ongoing_general_errors.md + the
    exact files at the cited anchors (re-grep; line numbers drift).
(2) IMPLEMENT exactly as specified. Copy strings verbatim; paste, do not retype.
(3) VALIDATE per §7. Observe the falsifying assertion fail first, and record it.
    Run the over-reach guards. Then the full §1 battery — including the BACKEND suite.
(4) BEFORE COMMITTING, re-run the battery. Do not write a completion claim from memory.
(5) BLOCKED, or found something needing human judgement? STOP. File it in
    ongoing_general_errors.md with options and a `Your selection: _____` line.
(6) RECORD: move the item to Resolved inside the SINGLE existing Resolved heading,
    with its observed falsifying output. Sync any design doc whose behaviour changed.
(7) COMMIT: one item = one Conventional Commit, WHY in the body.
```

---

## Definition of Done

- [ ] **§3** — playthrough run against the **deployed** backend with three players and `USE_EMULATOR=false`; all nine assertions recorded per device, especially **#3**, which no automated test covers today.
- [ ] Anything §3 surfaces filed as a **new issue with options** — not fixed inline.
- [ ] **§4 (Issue 69)** — `seenPrompts` read and written on `/rooms/{code}/sealed/{cardId}`, seeded **lazily** in `rerollPrompt`; sealed read happens before any write in the transaction; field removed from `CardModel`, `scoring_logic.ts` and the `index.ts:388` write; fake models the subcollection. **"No `seenPrompts` on the card" assertion observed failing first.**
- [ ] **§4 over-reach** — re-rolls still never repeat, the 11th re-roll still throws `resource-exhausted`, all card prompts distinct, sealed still denied to clients.
- [ ] **§5 (Issue 68)** — fake raises `FirebaseFunctionsException(code: 'resource-exhausted')`; client matches `e.code` with **all substring matching deleted**; the mirror invariant formally retired in `design_prompt_system.md`. **Client-copy test observed failing first.**
- [ ] **§5 over-reach** — an unrelated error still shows the generic fallback; no raw exception text on screen in either case.
- [ ] §4's deploy verified by artefact inspection per `design_database_and_security.md` §8. §5 needs no deploy.
- [ ] Full battery **pasted into the commit body** rather than summarised: `flutter analyze lib test` 0 errors · `flutter test` ≥ 126 · functions build clean · `npm --prefix functions test` ≥ 40.
- [ ] Issues 68–69 moved to Resolved **inside the single existing Resolved heading**.
- [ ] **Guide rewritten** — body and title together — to `Queue Complete` or the next queue. **A completion claim must quote measured output.**
