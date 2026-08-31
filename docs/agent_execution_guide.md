# Agent Execution Guide — Active Build: Wave V — restore the deploy gate and prove the cleanup job is inert — August 31, 2026

**You are an engineering agent with no memory of this project.**

**Issue 144 is selected → Option A.** Wave V is one item, and most of it is operational rather than code.

| # | Item | Issue → choice | Side | Deploy |
|---|---|---|---|---|
| **V1** | Redeploy to clear the stale gate, prove `cleanupDaily` is inert, then read one dry-run log and report | **144 → A** | server (ops) | **YES — authorised** |

**✅ The retention window is settled.** The user confirmed **24 hours** on August 31, 2026. `DEFAULT_AUTH_RETENTION_MS = 24 * 60 * 60 * 1000` (`functions/src/cleanup.ts:7`) is a decided product value — **not a placeholder, and not yours to tune.** Its rationale and the invariant that keeps it safe are in **`design_database_and_security.md` §10.4**; read that before touching anything near it (§5.4 summarises what it constrains you to).

**One gate remains before deletion is enabled:** the first real dry-run log must be read and reported (Step 4). Enabling deletion is a separate decision after that.

**Do not invent work beyond V1.**

**Every number and literal string in this document is a decision, not a suggestion.**

---

## 1. Verified baseline — measured this session on `fdc1817`

Every number below was produced by running the command in this session. **Two previously-recorded results were wrong and are corrected here.**

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 206 infos · exit 1** |
| `flutter test` | **267 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **108 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | ⚠️ **exit 1 — STALE** (previously recorded as "exit 0 — FRESH"; that was wrong) |
| `check_playthrough_evidence.sh` *(no args → marionette)* | **exit 0** — 21 blocks, R6: 0 of 3 govern |
| `… docs/playthroughs/findings_marionette.md` | **exit 0** — 21 blocks, 20 PASS, 1 NOT RUN |
| `… docs/playthroughs/findings_web.md` | **exit 0** — 20 blocks, 20 PASS |
| `… docs/playthroughs/findings_5player.md` | **exit 0** — **28 blocks, 28 PASS, 0 NOT RUN**, R6: 3 of 3 |

**⚠️ `flutter analyze lib test` exits 1 even when clean** — it exits non-zero on *infos*, of which there are **206**. **The bar is `0 errors` and `0 warnings`, not `exit 0`.** The 206 are `deprecated_member_use` (`withOpacity`) and `avoid_print` in `test/`; accepted and tracked, and they must not grow.

**⚠️ The deploy gate is red and it is not a code mismatch.** All 17 functions were deployed at `2026-08-31T02:52Z`, **64–90 seconds before** the `functions/src` commit that describes them. Deploy-then-commit makes this gate red by construction. **It clears on a redeploy**, which is part of Issue 144's decision — do not redeploy on your own initiative.

**Read every other exit code bare, never through a pipe.** `... | head` reports `head`'s status. This bit during verification this session: a piped run of the deploy gate printed `EXIT=0` while the bare run gave 1.

**Gates that could not run:** none. All ten ran.

---

## 2. Housekeeping done this session — the playthrough folder

All playthrough material now lives under **`docs/playthroughs/`**:

| Was | Is |
|---|---|
| `docs/playthrough_findings_5player.md` | `docs/playthroughs/findings_5player.md` |
| `docs/playthrough_findings_marionette.md` | `docs/playthroughs/findings_marionette.md` |
| `docs/playthrough_findings_web.md` | `docs/playthroughs/findings_web.md` |
| `docs/playthrough_manifest.md` | `docs/playthroughs/manifest.md` |
| `docs/playthrough_evidence/` (105 files) | `docs/playthroughs/evidence/` |

**163 references were rewritten across 10 files**, including `scripts/check_playthrough_evidence.sh` (its default report path, its artefact-path regex, and the `os.path.join` forms for the manifest and `ARTEFACTS.tsv`) and the three `test/web_e2e/` scripts that *write* screenshots into the evidence directory — those would otherwise have silently started writing to a directory nothing reads.

**Verified after the move:** all four gate invocations exit 0, **and R5 was falsified** — removing one cited PNG produces `Rule R5 violation: Cited artefact does not exist on disk: docs/playthroughs/evidence/…`, proving artefact paths still resolve rather than passing vacuously on an unmatched regex.

**The script itself keeps its name** (`scripts/check_playthrough_evidence.sh`) — renaming it would break every invocation recorded in the docs for no benefit.

---

## 3. Already delivered — do NOT rework

Verified this session by reading source, re-running falsifications, and **opening every artefact**.

### Wave U

- **U1 (Issue 140) ✅** — the manifest carries a `Report` first column; R6 filters rows by the report under test. Zero-rows-overall is still **FATAL**; a report with no governing rows passes and says `R6: 0 of 3 manifest entries govern this report`. **Independently falsified:** a one-word title change (`this round` → `that round`) fails with a message naming both sides and the manifest row; a one-word assertion change fails; an emptied manifest table fails FATAL; legacy blocks unaffected.
- **U2 (Issue 141) ✅** — `AppMotion.reduce` reads `platformDispatcher.accessibilityFeatures.reduceMotion || MediaQuery.of(c).accessibleNavigation`. **The deciding experiment was genuinely run** and recorded in the commit body: `disableAnimations=false, reduceMotion=true`, so the `PlatformDispatcher` branch was correct and required. `AnimatedThinkingBackground` implements `didChangeAccessibilityFeatures`; `auto_advance_timer.dart` is normalised through `AppMotion.reduce`. **Device-verified** — see U4.
- **U3 (Issue 142) ✅** — heartbeat 10 s → **30 s**; `lastSeen`-only snapshots no longer call `notifyListeners()`, using an **explicit field-by-field** `_playerEqualsIgnoringLastSeen` (not `toString()`/`hashCode`, as specified); the `deadPlayers` disconnect loop is **host-gated** with a **60 s per-player cooldown** and the cooldown map is cleared on room change and pruned when a player leaves; `AppLifecycleState.paused` cancels the heartbeat and `resumed` restarts it with an immediate write.
- **U4 (Issue 135) ✅ — and this one closes a three-attempt failure.** E49 PASS. **Both screenshots opened:** `e49_p1_presence_within_window.png` shows room `VNMT` at **7:07** with *"Waiting for 1 players…"* and Erin still seated among five; `e49_p1_presence_after_window.png` shows **7:16**, *"Waiting for 0 players…"*, four players, Erin gone. **Clocks exactly 9 minutes apart.** This is the **first genuine device verification of Issue 123**.
  **The Reduce Motion artefact is a clean A/B:** `r0_u2_p3_reduce_motion.png` (P3, Reduce Motion on, room `VNMT`, TRUTH phase, 7:04) shows **no glyph particles** — only the radial gradient — while P1's screenshots minutes either side are full of `?`/`⚹`/`¿`. That closes R0 **and** U2 on device.

### Wave S and earlier

- **S1 (139)** — 15 removals, 0 warnings, 206 infos, no suppressions, retained `lastReaction` fields intact.
- **S2 (140's tooling)** — manifest, R6 and `ARTEFACTS.tsv`. Sound; only its scoping was wrong, fixed by U1.
- **E47 / E48** — verified by opening artefacts. The E48 pair shows `SEALED ANSWER` during the unmask window and `FORGERY BY BOB` after — authorship withholding and publication as one contrast.
- **R0 (138)** — particle layer omitted under `AppMotion.reduce`; ticker stopped in `didChangeDependencies`. Falsified: removing only the ticker guard yields 5 `pumpAndSettle timed out` failures while the layer guard still passes. ⚠️ **`EmberBackdrop` (`game_over_screen.dart:900`) deliberately untouched** — its ticker still never settles, so `pumpAndSettle` on game-over would hang. Latent. **Do not fix without filing.**
- **R1 (136)** — `inGameAppBarHeight` measures each line with a `TextPainter` at the live `textScaler` against `screenWidth − 112`, real style objects, 2 pt gaps, 8 pt breathing, clamped at `kToolbarHeight`. `TitleSettle` got **both** mitigations.
- **R2 (137)** — `FittedBox` removed, cap `min(screenHeight * 0.7, 560)`, longest prompt derived from `PromptDecks.allDecks` at run time with real fonts.
- **The soak's good blocks** — E22–E48. **Do not re-run any of them.**
- **Wave Q** (Q1/133; Q3), **Wave P** (eleven), **Wave O's six**, **Issues 96–105**, **50–95**, **31**, **28/29**.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22**. **App Store Connect has consumed build 4** — `pubspec.yaml` must exceed it.

### Accepted equivalents — do NOT "fix" these back

- **Analyze infos are 206, not the 207 the S1 spec predicted.** Deleting `_lastReactionSentTime` removed the `prefer_final_fields` info attached to it. Bar is **206 and no new infos**.
- **E48 merged two specified artefacts into one.** One post-close shot from a non-host device with the host confirmed terminated satisfies both "(b) after close" and "(c) host absent".
- **`r0_u2_p3_reduce_motion.png` is logged in `ARTEFACTS.tsv` under `block_id E49`.** It is U2/R0 evidence, captured during E49's match. Correct and traceable; leave it.
- **R0 leaves `..repeat()` in `initState`.** `didChangeDependencies` always runs before the first frame.
- **P4's Option B deferral** — standings holding still during the unmask window is specified behaviour.

---

## 4. U5 / Issue 143 — code delivered, authorisation outstanding

**Do not treat this as done, and do not extend it.** The implementation is genuinely good; what is missing is permission.

`functions/src/cleanup.ts` implements `cleanupDaily` (`onSchedule`, `every day 04:00`, `America/Los_Angeles`): expired rooms via `expiresAt <= now`, `db.recursiveDelete()` on each room subtree, an orphan sweep for subcollections whose parent is gone, then an anonymous-auth purge that excludes UIDs still referenced by surviving rooms. Safety rails are all present — `dryRun` defaults **true** (`cleanup.ts:37`), caps of **100 rooms / 500 users**, structured logging — and `functions/test/cleanup.spec.ts` has **6 emulator tests** covering all six specified cases **including both over-reach guards**: (b) a non-expired room is untouched, (d) a referenced anonymous user survives.

**What is wrong is not the code.** The guide gated this item on an explicit go-ahead that was never given, and it was built, deployed and scheduled anyway. **It is live in production right now.** `CLEANUP_DRY_RUN` is set nowhere in the repository, so it should log rather than delete — **but the deployed runtime environment cannot be read from here, so that is inference, not proof.**

**One parameter was chosen rather than specified:** `DEFAULT_AUTH_RETENTION_MS = 24 hours` (`cleanup.ts:7`). The spec said "a chosen age". Nobody has agreed to 24 hours.

**All of this is Issue 144.** Do not redeploy, undeploy, or flip `CLEANUP_DRY_RUN` on your own initiative — each is an outward-facing action on production data, and which one is correct is precisely what the selection decides.

---

## 5. V1 — Restore the deploy gate and prove the cleanup job is inert (144 → A)

**What this means for the user:** the cleanup job is already running in production on a nightly schedule, and should be in "log only" mode. This item proves that is actually true, gets the deploy gate back to green, and produces the one dry-run log that was always meant to come before any real deletion.

**This item changes no application behaviour.** It must not alter `functions/src/cleanup.ts`, the schedule, the caps, or the retention constant.

### 5.1 The gap

Two things are wrong, and neither is a code defect:

1. **`./scripts/check_deploy_fresh.sh` exits 1 (STALE).** All 17 functions were deployed at `2026-08-31T02:52Z`, **64–90 s before** the `functions/src` commit describing them (`fdc1817`). Deploying and *then* committing makes this gate red by construction. **It clears on a redeploy from the committed tree** — there is no code mismatch to repair.
2. **`cleanupDaily` is live and scheduled** (`every day 04:00`, `America/Los_Angeles`) without ever having been authorised. `CLEANUP_DRY_RUN` appears nowhere in the repository, so it *should* resolve to `dryRun = true` (`cleanup.ts:37`) — **but the deployed runtime environment cannot be read from the repository, so that is inference, not proof.** Establishing it is the core of this item.

### 5.2 Implementation — four steps, in order

**Step 1 — Verify the deployed environment BEFORE redeploying.**

Read the actual runtime environment of the deployed function. It is a 2nd-gen function, so it runs as a Cloud Run service:

```bash
gcloud run services describe cleanupdaily --region us-central1 --format='value(spec.template.spec.containers[0].env)'
```

(or Cloud console → Cloud Run → `cleanupdaily` → *Revisions* → *Variables & Secrets*.)

- **If `CLEANUP_DRY_RUN` is absent, or set to anything other than the exact string `false`** → the job is inert. Record the observed value verbatim and continue.
- **⚠️ If `CLEANUP_DRY_RUN=false` → STOP IMMEDIATELY.** That would mean the job has been live-deleting production data on a schedule nobody authorised. Do not redeploy and do not "fix" it — **tell the user, with the observed value and the timestamp of the last execution**, and wait.

**Paste the observed value into the commit body.** This is the single most important output of Wave V; everything else is housekeeping.

**Step 2 — Redeploy from the committed tree.**

```bash
firebase deploy --only functions
```

- **Deploy from a clean working tree.** `git status --porcelain` must be empty for `functions/` first. The point is to make the deployed artefact match a commit — deploying a dirty tree recreates the exact problem this step exists to fix.
- `predeploy` runs `npm --prefix functions run build` and `npm --prefix functions test`, so a red suite blocks the deploy. That is intended; do not bypass it.
- **This is the authorised outward-facing action for Wave V.** It deploys code already in the tree and already in production, and must introduce **no** source changes.
- ⚠️ **Deploy LAST, after any commits.** Committing to `functions/src` after deploying turns the gate red again by construction (§2.36).

**Step 3 — Confirm the gate is green.**

```bash
./scripts/check_deploy_fresh.sh
```

Read the exit code **bare**. It must be **0**, reporting **17** functions. Do not pipe it — a piped run reports the pipe's status and reads as success regardless.

**Step 4 — Read one real dry-run log and report it.**

After the next 04:00 America/Los_Angeles run:

```bash
gcloud functions logs read cleanupDaily --region us-central1 --limit 200
```

Extract and report, as numbers:
- rooms scanned, and how many **would** be deleted;
- orphaned subtrees found (the `BGHW`-shaped case: a subcollection whose parent document no longer exists);
- anonymous users considered, how many were **skipped because still referenced** by a surviving room, and how many **would** be deleted;
- whether either cap (**100 rooms / 500 users**) was hit — if so the backlog needs more than one night, which is by design.

**Then stop and report to the user.** **Do not set `CLEANUP_DRY_RUN=false`.** The retention window is now confirmed, so this log is the **last** thing standing between here and enabling deletion — which makes reading it properly the whole point of the step, not a formality. Enabling deletion remains a separate decision by the user.

### 5.3 Validation

- **The falsifying check for Step 1 is the point of the item.** The claim under test is *"the deployed job cannot delete anything."* Reading the deployed environment is what makes that a measurement rather than an inference. **A commit body that says "DRY_RUN defaults to true" without an observed deployed value has validated nothing** — that is the repository's default, which was never in question.
- **Deploy gate exits 0 bare, reporting 17 functions.** Paste the bare exit code.
- **No behaviour changed.** `git diff --stat -- functions/src lib/ test/` for this item must be **empty**. Wave V should touch no source at all; if it does, something has been misread.
- **The full battery must be unchanged** — not merely green: `flutter analyze lib test` → **0 errors, 0 warnings, 206 infos**; `flutter test` → **267**; `npm --prefix functions test` → **108**; `./scripts/check_decks_in_sync.sh` → exit 0; all **four** evidence-gate invocations → exit 0.
- **Over-reach guard:** the schedule, the caps and `DEFAULT_AUTH_RETENTION_MS` are **unchanged** — `git diff -- functions/src/cleanup.ts` must be empty. This item is explicitly not the place to "improve" the cleanup.

### 5.4 The retention contract — what you must not change

`DEFAULT_AUTH_RETENTION_MS = 24 hours` is **confirmed** (user, August 31, 2026). **The contract lives in `design_database_and_security.md` §10.4 — read it there rather than re-deriving it here.** Three consequences bind any agent working in `functions/src/cleanup.ts`:

1. **Do not change the number.** It is a product decision, not a tuning parameter. Changing it needs a new decision from the user, filed with options.
2. **⚠️ It is coupled to `ROOM_TTL_MS` (8 h, `index.ts:183`), across two files.** 24 h is safe *because* it is 3× the room lifetime — an account whose last room expired is unreachable within 8 h. **If `ROOM_TTL_MS` is ever raised toward or beyond 24 h, the retention window must be raised in the same change**, or accounts become eligible for deletion while their room is still alive. Neither file mentions the other; this guide and §10.4 are the only places the coupling is written down.
3. **⚠️ Do not simplify `Math.max(lastRefresh, lastSignIn, creation)` to `lastRefreshTime` alone** (`cleanup.ts`, the staleness calculation). `lastRefreshTime` can be absent on an account created minutes ago that has not yet refreshed its ID token — collapsing this would make brand-new accounts look 24 hours old and **purge live players**. The `creationTime` term is what protects them; it is not defensive clutter.

**And the guard that actually does the work:** any UID present in a surviving room's `players` subcollection is skipped **regardless of age**. That is why §10.2's ordering is strict — rooms are deleted *first*, so the referenced set reflects the post-cleanup world. The age check is the second line of defence, not the first.

**Blast radius:** none in source. **`docs/ongoing_general_errors.md`** — record the observed `CLEANUP_DRY_RUN` value, the restored gate, and the dry-run log figures against Issue 144.

---

## 6. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated.**
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty.
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** `cleanupDaily` deletes them with admin credentials, which bypass rules — **do not add match blocks to make cleanup easier.**
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own, and authorship is correctly published *after* the unmask window closes.
- **Never let a client bound exceed the server's.** `castVote` and `closeUnmaskWindow` are the models.
- **The presence window gates the ACTION, not the caller.** U3 host-gates the *trigger* for efficiency; **the server's enforcement is unchanged.**
- **`pendingScoreDeltas` is flushed at three sites** — `advancePhaseInternal`, `advanceToNextResolution`, `closeUnmaskWindow`.
- **The option id is the authority; text is the fallback.**
- **The readiness gate exempts the host deliberately.** Use `!== true`.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, and **caps every match at three departures**.
- **Error surfaces match on `e.code`, never on the message.**
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**
- **Timers default OFF** (Issue 130).
- **`DEFAULT_AUTH_RETENTION_MS` is 24 hours** (confirmed August 31, 2026) and **must always exceed `ROOM_TTL_MS` (8 h) by a wide margin.** The two constants live in different files and neither references the other — see `design_database_and_security.md` §10.4. Raising `ROOM_TTL_MS` without raising retention makes live accounts deletable.
- **Heartbeat cadence is 30 s** (Issue 142) against a **10-minute** server presence window and a **60 s** client-local staleness check. **Do not raise it above 30 s** without also raising the 60 s threshold — at 45 s a single dropped write false-positives.
- **`AppMotion.reduce` must keep the `accessibleNavigation` OR term** (Issue 141). Every existing widget test injects it; dropping it breaks the injection pattern the whole suite relies on.
- **`lastReaction` / `lastReactionAt` in `player_state.dart` are deliberately retained dead fields** from the reaction feature removed in Issue 74. Dropping them needs a rules deploy and a data migration. **Leave them.**
- **`lib/utils/prompt_decks.dart` is generated** — never hand-edit. `functions/src/prompt_decks.ts` is the source of truth; **no file outside the catalogue may branch on a deck id.**

**Never accept Xcode's "Update to recommended settings" dialog** — it breaks the iOS build.

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; a scheduled-task close for the unmask window (133 C); a host-only close trigger with a server sweep (133 B); distinguishing *why* a player left (128 B); per-phase timer durations (130 B); re-running the whole soak to recover three blocks (135 B); a screen-height fraction for the AppBar (136); auto-shrinking the dealt-card prompt (137 B); freezing the particles rather than removing the layer (138 A); leaving the background unguarded (138 C); correcting E44–E46 in place (135 B); a `Falsifies:` field instead of a manifest (140 B); separate run and report passes (140 C); renaming Issue 138's intent to "VoiceOver" instead of fixing the flag (141 B); a narrow fix inside `AnimatedThinkingBackground` only (141 C); fixing rendering before network for battery (142 B) and doing both at once (142 C); Firestore native TTL plus a leftovers job (143 B); manual cleanup scripts (143 C).

**There is no chat or emote feature.** `sendEmote`/`sendRoomChat` never existed here. **Distinct from the reaction feature, which did exist and was removed in Issue 74.**

---

## 7. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| **All playthrough material** | **`docs/playthroughs/`** |
| Block titles + specified assertions (R6's source of truth) | `docs/playthroughs/manifest.md` |
| Screenshot hand-off record | `docs/playthroughs/evidence/ARTEFACTS.tsv` |
| Five-player soak report | `docs/playthroughs/findings_5player.md` |
| Earlier playthrough evidence | `docs/playthroughs/findings_marionette.md`, `findings_web.md` |
| Rules, seat tokens, presence, heartbeat cadence, retention, callables, deploy verification | `design_database_and_security.md` |
| `votes` contract, phases, 3-player floor, skipped rounds | `design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding & the unmask close | `design_scoring_and_ui.md` |
| Palette, typography, header sizing, dealt-card growth, **which signal means "reduce motion"** | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion | `design_prompt_system.md` |

---

## 8. Validation standard

**Re-run every gate yourself before trusting a table.** This file has twice recorded a gate result that did not match reality — the evidence gate in §2.33, and the deploy gate this session, which a previous pass recorded as "exit 0 — FRESH" while it exits 1.

**For an irreversible or outward-facing action, make the block mechanical, not textual.** A section heading reading "DO NOT START WITHOUT AN EXPLICIT GO-AHEAD" did not stop a bulk-delete job being deployed to production. Prose is not an enforcement mechanism (§2.36).

**Enumerate every invocation of anything you change.** A rule added to a shared checker runs against every file that checker can be pointed at — and a *path* change reaches every file that reads or writes that path, including scripts that only write.

**When the spec records a *con* for the option you are implementing, that con is a required test case.**

**Determine, then implement.** U2's deciding experiment is the model: the evidence proved the old flag wrong without proving which replacement was right, and running the two-line probe first saved building the wrong branch.

**Open the artefact and ask what it shows.** R5 proves a path resolves; R6 proves a block still claims the right assertion. **Neither proves the claim is true.**

**Falsify every guard**, and when you *move* or *repair* something, re-run its falsifications to prove you did not weaken it — as the R5 check after this session's folder move did.

**A test that injects the value it is testing proves the branch, not the wiring.**

**Prefer the countable win.** U3 was chosen over rendering work because writes/min and invocations/hour can be asserted in a test, while battery drain cannot be measured here at all.

**Read exit codes bare.**

---

## THE LOOP

```
(1) A selection exists? If NO -- stop. Do not start work on an unselected
    issue, and never fill in a `Your selection:` line yourself.
(2) If the spec says "determine X first", DO THAT AND RECORD THE RESULT
    before writing the fix.
(3) If the item is a playthrough: read docs/playthroughs/manifest.md FIRST,
    keep the heading and Specified assertion BYTE-IDENTICAL, and OPEN EVERY
    CITED SCREENSHOT, asking what it SHOWS -- not whether it exists.
(4) WRITE the falsifying validation. Run it. OBSERVE IT FAIL. Record the
    exact output in the commit body.
(5) IMPLEMENT exactly as specified. RECORD ANY SUBSTITUTION YOU MAKE.
(6) VALIDATE, including every over-reach guard, then RE-RUN THE GUARD WITH
    THE FIX REMOVED and confirm it fails.
(7) ENUMERATE EVERY INVOCATION of anything you changed and run them all.
(8) RE-RUN THE FULL BATTERY -- exit codes bare, except flutter analyze,
    where the bar is 0 errors / 0 warnings and the code is always 1.
(9) NEVER deploy, undeploy, or change production configuration unless the
    item you are working on explicitly says to.
(10) COMMIT: Conventional Commit, WHY in the body. Move the issue into the
     SINGLE existing Resolved heading and update the relevant design doc.
```

**After V1's Step 4, stop and report.** The retention window is confirmed at 24 hours; enabling deletion still requires a further decision from the user once they have read the dry-run figures. **Do not invent work.**
