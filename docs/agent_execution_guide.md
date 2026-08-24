# Agent Execution Guide — Active Build: Wave L — Artefact Re-verification — August 24, 2026

**You are an engineering agent with no memory of this project.**

**Issues 1–111 are delivered and verified in source.** Wave L is not a feature wave: it makes the playthrough evidence honest again, and closes the hole that let it drift.

| # | Item | Touches | Deploy |
|---|---|---|---|
| **L1** | Teach the evidence gate that a cited artefact must **exist** | `scripts/check_playthrough_evidence.sh` | — |
| **L2** | Classify all 54 artefacts; delete the dead, downgrade the falsified | `docs/playthrough_evidence/`, both findings docs | — |
| **L3** | One browser session that re-shoots everything needing it | evidence | — |

**Order is L1 → L2 → L3 and it is a real dependency.** L1 is what catches a block whose artefact you delete in L2. L3 is last because it is the only step needing a running app, and it produces the replacements L2 identifies.

**Do not run `firebase deploy`.** Nothing here is a server change. `check_deploy_fresh.sh` will stay red because Wave K's server half is undeployed; that is the user's call, not yours.

## Verified baseline — the regression bar

| Gate | Result | Command |
|---|---|---|
| Analyzer | **0 errors** (21 warnings, 201 infos) | `flutter analyze lib test` |
| Client tests | **185/185** | `flutter test` |
| Functions build | clean | `npm --prefix functions run build` |
| Functions tests | **70/70** | `npm --prefix functions test` |
| Deploy freshness | **exit 1 — expected** | `./scripts/check_deploy_fresh.sh` |
| iOS evidence | **exit 0** — 15 blocks | `./scripts/check_playthrough_evidence.sh` |
| Web evidence | **exit 0** — 19 blocks | `./scripts/check_playthrough_evidence.sh docs/playthrough_findings_web.md` |

---

## 0. The measured state of the evidence — do not re-derive this

Counted on **August 24, 2026**:

| | |
|---|---|
| PNGs on disk | **54** |
| Cited by a block | **50** |
| **Orphaned** (on disk, cited by nothing) | **4** — `e8_p2_lobby.png`, `m3_gate_p1.png`, `m3_gate_p2.png`, `m3_gate_p3.png` |
| Dangling citations (cited, absent) | **0** |

**Two facts that decide how you do this:**

**1. File dates alone cannot decide staleness.** All 54 artefacts predate the newest `lib/screens` commit, so an mtime test flags *everything* and tells you nothing. Staleness is per-screen: compare an artefact against the commits that changed **the screen it depicts**, not against the repo as a whole.

**2. The gate cannot see a missing file.** `check_playthrough_evidence.sh` R3 matches the artefact **path string inside the block text** (`artefact_png_regex.search(obs_content)`) and **never stats the file**. So deleting a cited PNG leaves the gate **green** with the evidence gone. That is the hole L1 closes, and it is why L1 comes first.

---

## 1. Standing constraints

- **One item = one commit.**
- **Never fill in a `Your selection: _____` line.**
- **Do not run `firebase deploy`.**
- **A mechanical check must assert it matched something.**
- **`git rm`, never `rm`.** Every artefact is tracked, so a git deletion is recoverable and reviewable; a filesystem deletion is neither.
- **Never delete a cited artefact without updating the block that cites it** in the same commit.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **File defects with Pros/Cons and a blank selection line**, per `.agents/skills/bug_documentation_guidelines/SKILL.md`.
- **Do not touch anything in §6 or §7.**

---

## 2. L1 — The gate must require the artefact to exist

**The change:** add rule **R5** — for every `docs/playthrough_evidence/*.png` path appearing in a PASS or FAIL block, the file must exist on disk. Report the block id and the missing path. Keep it in the same exit-code scheme: a missing artefact is a **violation (exit 1)**, not a could-not-verify.

Resolve paths **relative to the repository root**, not the caller's working directory, or the rule will pass or fail depending on where it is run from.

**Falsification, mandatory, and recorded in a comment at the top of the script and in the commit body:**

1. Temporarily `git mv` one cited PNG aside. The gate must **exit 1 naming that block and that path**. Restore it; the gate must return to exit 0.
2. **Assert the rule matched something.** Print or assert the number of artefact paths checked — a run that found **zero** paths and a run where every path exists both report "no violations". This is lesson 2.21 and it has already shipped once in this repo.
3. **Over-reach guard:** a `NOT RUN` block carrying no artefact at all must **not** be flagged by R5.
4. **Regression:** both reports must still exit 0 with all files present — iOS 15 blocks, web 19 blocks.

---

## 3. L2 — Classify every artefact, then act

Sort all 54 into exactly three buckets. **The distinction between the second and third is the whole point of this wave** — "old" and "wrong" are not the same thing, and deleting on age alone destroys valid evidence.

**Bucket A — Orphaned.** Cited by no block, referenced nowhere else in the repo (verified: zero references for all four). `git rm` them. No block changes needed because no block points at them.

**Bucket B — Falsified: the artefact shows behaviour the app no longer has.** These are actively misleading and must not survive. The known member:

- **`w14_case_file_share.png`** — shows the snackbar `Sharing is only supported on mobile devices.`, which Issue 110 replaced with a download. Its block has already been corrected twice for claiming more than this image shows.

**Bucket C — Outdated in appearance, still true in substance.** The screen has changed since, but the artefact still supports the specific assertion its block makes. **These are not deletions.** Eleven artefacts depict the game over screen and predate `24a2398`, which added the FINAL STANDINGS table:

```
e10_p1_gameover.png   e10_p2_gameover.png   e14_honors.png
e1_game_over_podium.png   w11_gameover.png   w14_case_file_share.png
w16_p1_gameover.png   w16_p2_gameover.png   w17_gameover.png
w18_gameover.png      w19_gameover.png
```

None of them shows the standings table, so none depicts today's screen. **But most of their blocks only assert "reached game over with scores intact", which those images still evidence.** Re-shoot them in L3 if the session is already open — it is nearly free once you are there — but **do not delete a Bucket C artefact and leave its block without evidence.** That trades a cosmetically-stale image for no image at all, which R5 will now correctly refuse.

**Judgement rule, stated so it is not a matter of taste:** ask *"does this image still show what its block claims?"* — not *"is this image current?"* Delete only on a **no** to the first question. If a block's claim and its image have diverged, the honest fixes are re-shoot, or narrow the claim to what the image shows. Both are better than deletion.

**Record the classification** in the commit body: every file, its bucket, and one line of why. That list is the audit trail for anything deleted.

---

## 4. L3 — One browser session, many artefacts

Nearly everything outstanding lives on **one screen**. Reaching game over once and capturing carefully settles the web Case File download, replaces `w14`, and refreshes every Bucket C game-over shot in the same sitting. **Plan the session around that.**

### 4.1 Reaching game over

**Three isolated browser contexts, not three tabs.** Two tabs in one browser profile are **one player** — web `SharedPreferences` is `localStorage` and the anonymous auth user lives in IndexedDB, both per-origin. Playwright's `browser.newContext()` gives separate storage partitions; the Wave I harness under `test/web_e2e/` already does this.

Serve the release build locally rather than a deployed URL, so what you observe is the tree you have:

```bash
flutter build web --release
python3 -m http.server 8777 --directory build/web
```

**Prove the artefact is newer than the source**, in epoch seconds, never strings:

```bash
stat -f %m build/web/main.dart.js; git log -1 --format=%ct -- lib
```

**The match summary will be absent** — Wave K's server half is committed and undeployed. That is expected and correct; standings render without it by design. **Do not deploy to make it appear.** Capture the standings, which are client-side and do work.

### 4.2 What to capture, and the trap in naming

1. **The Case File download.** Click **Share Case File**. Confirm a file lands as `gaslight_case_file_<roomcode>.png`, then **open it** — it must be a valid PNG of the Case File, not 0 bytes and not an HTML error page, which is what a malformed blob URL produces. Record the `file <path>` output and the byte size.
2. **The confirmation snackbar**, as its own screenshot.
3. **The standings table** on the game over screen — Issue 111 has never been seen running anywhere.
4. Fresh game-over shots for the Bucket C blocks you choose to refresh.

**Save every replacement under a NEW filename.** Reusing `w14_case_file_share.png` hides the staleness from `ls`, from `git diff --stat`, and from review — the exact mechanism that let this block overstate twice. Use `w14_case_file_download.png` and equivalents.

### 4.3 Updating the blocks

Rewrite each `Observed:` to cite the new artefact and quote the concrete output. Restore full-strength `Expected:` wording **only where the run actually supports it**. Keep the note recording that W14 previously overstated — that history is why R5 exists.

**If the download does not work, do not fix it inline.** File it with Pros/Cons and a blank selection line.

Re-run both gates afterwards; both must exit 0.

---

## 5. Playthrough procedure — the standing setup

1. **`.env` must contain `USE_EMULATOR=false`** — a bundled asset; changing it after the build has no effect.
2. **Uninstall on every booted simulator** so no stale room is restored from `SharedPreferences`.
3. **Build, then prove the binary is newer than the source**; paste both lines into the report header:
   ```bash
   stat -f '%Sm binary' build/ios/iphonesimulator/Runner.app/Runner; git log -1 --format='%cd source' -- lib ios
   ```
4. **Launch one device at a time** — concurrent builds corrupt `build/`. Gate all three on `THE GUEST LEDGER`.
5. `Disable Game Timers` **on** (`lobby_screen.dart:623`), recorded as a deviation. `Family-Friendly Decks Only` **off** (`:643`).
6. **Three real clients. Never `DEBUG: ADD 9 BOTS`.**
7. Paste `flutter --version` into the header rather than recalling it.

**Evidence contract.**

| Field | Takes | Never takes |
|---|---|---|
| `Observed:` | `get_interactive_elements` output, screen text, a saved screenshot path, a `flutter:` log line | A `grep`. A source line. A test name. Prose describing code. |
| `Reference:` | `file:line` — optional context for the expected value | — |

**Name the field `Observed:`.** A renamed variant is what let E11 through a human review; `check_playthrough_evidence.sh` now catches the rename, but do not create the need.

---

## 6. Already delivered — do NOT rework

**Verified in source, in the built artefacts, and on devices, August 22, 2026:**

- **Issue 102** — the pre-demo playthrough in room `GLRD`: full 3-round match; with Issue 105's re-runs the report now stands at **14 PASS, 1 NOT RUN (E9, honestly labelled), 0 FAIL**, every cited screenshot present. **E7 seat recovery device-verified** (`xcrun simctl terminate` mid-match → relaunch → straight back to `/reveal`, seat and score intact). **E8 host kick device-verified on both sides.** **No product defect found.**
- **Issue 105** — `scripts/check_playthrough_evidence.sh` enforces evidence rules R1–R4 mechanically; **E10** re-run in room `YJUG` with the in-game `Leave game` control and evidence from **both** remaining devices; **E11** re-run on a **release** build outside Marionette (its screen coverage stated honestly — the lobby was observed, the rest rests on `kDebugMode` being one compile-time const); **E13** fixed beyond spec, having been found by the script and missed by two human passes.
- **Issue 103** — seven `DEBUG:` sites gated (`lobby_screen.dart:740`, `phase2_craft.dart:328/365/565`, `phase3_vote.dart:255/414/572`), each composing with its pre-existing condition; **all seven buttons still exist** — gated, not deleted. Icon is the raven, 1024×1024 **RGB with no alpha**; launch images are real sizes.
- **Issue 104** — `PrivacyInfo.xcprivacy` lints clean, declares three collected types with `Linked`/`Tracking` false, keeps `NSPrivacyAccessedAPITypes` empty by design, and **is a member of the Runner target**.
- **Issues 96–101** — `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken` hashed into default-deny `sealed`, or a stale seat; `votes` stores opaque option UUIDs with phase/reader/duplicate guards; the reveal merges only the current card; unmask authorship is withheld until the deadline; debug callables are emulator-only *and* host-only.
- **Issues 50–95** as previously recorded. **Issue 31** — loose `!= null`. **Issues 28/29** — `phosphor_flutter` can never be used.

**The battery is seven gates:** analyze · `flutter test` · functions build · functions test · `check_deploy_fresh.sh` · `check_playthrough_evidence.sh`.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · version `1.0.0+2` · iOS target **15.0** · Node **22**.

---

## 7. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.** Deleting them breaks emulator tests; `debugSimulateBotResponses` drives several. Their gating is observable only in a release or profile build.
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty. If a plugin lacks its own manifest, **upgrade the plugin**.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat — **do not simplify to one condition**.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.**
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal. Never store the resolved author pre-reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own.
- **`castVote` rejects only genuine self-votes.** Never let a client bound exceed the server's.
- **The option id is the authority; text is the fallback, consulted only when the id is null.**
- **A failed `getMyOptionId` is not cached and will be retried**; `fetchMyOptionId` is called from `build()` on purpose.
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby.
- **`handleDisconnect` has exactly three legitimate callers.**
- **Dialogs render on `groundRaised`.** **Never interpolate an exception into user-facing text.** **Busy-state disabling is a correctness guard** — `createRoom` is not idempotent.
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; prototype pollution via `selectedDeckId`; plus the declined options in `ongoing_general_errors.md` §4.

---

## 8. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Rules, seat tokens (§5, device-verified), callables, debug isolation (§7.1), privacy manifest (§7.2), deploy verification (§8) | `design_database_and_security.md` |
| `votes` two-phase contract, phases, 3-player floor, readiness gate | `design_game_state_and_models.md` |
| Scoring, reveal beats, reveal scoping, unmask withholding, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, release identity, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |

---

## 9. Validation standard

**A mechanical check must assert it matched something.** Zero matches and zero violations produce the same number — `check_playthrough_evidence.sh` exists because a mandated check of mine did not.

**A check written for one shape of a defect will not catch the next shape.** The rule looked for `grep -`; the next instance was prose, and the one after that was a renamed field. **Assert positively — require the artefact — rather than only forbidding the known-bad token.**

**A `grep` is not an observation.**

**Prove the artefact ships, not that it exists.** The guard is in the source; the button is in the binary.

**Record every substitution.** An omitted assertion reads as though it passed.

**A test harness that cannot express the bug will pass against it.**

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**Measure; do not estimate. Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** Fifteen blocks can pass and the game may still not be fun. That question belongs to the Apple beta.

---

## 10. Feedback loop — what past specs got wrong

- **A check that matches nothing returns the same number as a check that passes.** Mine did, and it shipped as a mandatory step.
- **A defect class mutates faster than the rule written to catch it.** `grep` as observation → prose as observation → a **renamed field** hiding both. Each escaped a rule written for the previous shape. **Match the concept, not the literal.**
- **A convention introduced to stop one failure can become the next one.** `grep -F` traceability stopped invented quotes, then became the observation.
- **When a written step fails twice, replace it with a tool.** `check_deploy_fresh.sh` for deploys; `check_playthrough_evidence.sh` for evidence.
- **A fix can be correct while its design doc still describes the vulnerability.**
- **When you redefine what a field holds, enumerate its readers.**
- **A guard's test must be run with the guard removed.**
- **Working logs rot by appending.** One banner, one Resolved heading, one line per resolved issue.
- **One item = one commit.**

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the files at the cited anchors. RE-GREP every anchor; numbers drift.
(2) WRITE the falsifying validation FIRST. Run it. OBSERVE IT FAIL. Record
    the exact output. For a mechanical check, confirm it matched a NON-ZERO
    count before believing its result.
(3) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(4) VALIDATE per section 8, including the over-reach guard.
(5) RECORD observed output in the commit body and, for a guard, in a comment
    at the top of the script or test.
(6) RE-RUN THE FULL BATTERY before committing — all six. check_deploy_fresh
    may legitimately still be red for server changes you must not deploy.
(7) BLOCKED, or a decision is needed? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
(8) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
    SINGLE existing Resolved heading and update the design doc that described
    the OLD behaviour.
```

---

## Definition of Done

**L1 — the gate requires artefacts to exist**
- [ ] R5 implemented: every artefact path in a PASS/FAIL block must exist on disk; violations exit **1** naming block and path; paths resolve from the **repo root**.
- [ ] **Falsified**: a cited PNG moved aside makes the gate exit 1 naming that block; restoring it returns exit 0. Output recorded in the script header and the commit body.
- [ ] **The rule asserts it matched something** — the count of artefact paths checked is non-zero before "no violations" is believed.
- [ ] **Over-reach guard**: a `NOT RUN` block with no artefact is not flagged.
- [ ] **Regression**: iOS report 15 blocks exit 0, web report 19 blocks exit 0.

**L2 — classification and cleanup**
- [ ] All 54 artefacts classified into Orphaned / Falsified / Outdated-but-true, with the full list and a one-line reason per file in the commit body.
- [ ] The 4 orphans removed with **`git rm`**: `e8_p2_lobby.png`, `m3_gate_p1.png`, `m3_gate_p2.png`, `m3_gate_p3.png`.
- [ ] **No cited artefact deleted without its block being updated in the same commit.** R5 must be green at the end.
- [ ] No Bucket C artefact deleted merely for being old — the test applied is "does it still show what its block claims", and that reasoning is written down.

**L3 — the browser session**
- [ ] Game over reached with **three isolated contexts**, not tabs.
- [ ] Build freshness proven in epoch seconds first.
- [ ] **A file actually landed and was opened** — valid PNG, `file` output and byte size recorded. Not 0 bytes, not HTML.
- [ ] Confirmation snackbar and the **standings table** both captured; Issue 111 has never been observed running.
- [ ] Every replacement saved under a **new filename**; no old name reused.
- [ ] Blocks rewritten to cite the new artefacts, with full-strength claims only where the run supports them.
- [ ] If the download failed: filed with Pros/Cons and a blank selection line, **not fixed inline**.

**Across the wave**
- [ ] Battery at or above baseline: **0 errors** · **≥185** · clean functions build · **≥70** · both evidence gates exit 0.
- [ ] `check_deploy_fresh.sh` still red, explained rather than left looking like a regression, and **`firebase deploy` was never run**.
- [ ] One item, one commit; Conventional Commit; WHY in the body.
