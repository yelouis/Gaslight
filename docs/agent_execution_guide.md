# Agent Execution Guide — Active Build: F1 → F4 (pre-demo ship) — August 21, 2026

**You are an engineering agent with no memory of this project.**

**Issues 1–101 are delivered, deployed and independently verified** (§6). This build is everything between the current build and putting a demo in a friend's hands.

| # | Item | Issue | Touches | Deploy |
|---|---|---|---|---|
| **F1** | Gate the seven `DEBUG:` buttons behind `kDebugMode` | 103.1 | client | — |
| **F2** | Real app icon and launch screen | 103.2 / 103.3 | iOS assets | — |
| **F3** | `PrivacyInfo.xcprivacy` for the app target | 104 | iOS | — |
| **F4** | Final E2E playthrough on three simulators | 102 | verification | — |

**Nothing here needs a backend deploy.** The server is current and verified; this is all client, assets and evidence.

**Order matters and is not negotiable: F1 and F2 land before F4.** F4's assertion E11 is *"no `DEBUG:` control is visible anywhere"* — it fails today because of F1, and the whole point of F4 is to test **the build friends will actually get**.

## Verified baseline — the regression bar

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors** (22 warnings, 194 infos) |
| `flutter test` | **156/156** |
| `npm --prefix functions run build` | clean |
| `npm --prefix functions test` | **61/61** |
| `./scripts/check_deploy_fresh.sh` | **exit 0** — 15/15 functions and the rules release |

---

## 1. Standing constraints

- **One item = one commit.**
- **Write validation that fails against the broken state, and observe it fail** — and apply it to the test itself: remove the guard, watch the test go red, restore it, and record the failure text **in a comment on the test** as well as the commit body.
- **Check that a test's subject is the thing the spec named.** Right shape, wrong fixture reads identically in a green run.
- **`flutter analyze lib test`, never bare `flutter analyze`.**
- **Never fill in a `Your selection: _____` line.**
- **Do not weaken an assertion or delete a test to reach green.**
- **Do not fix anything inline during F4.** Failures are described, not repaired.
- **Do not touch anything in §7 or §8.** **Read §2 before starting any item.**

---

## 2. Execution order — how to sequence F1 → F4

**Read this section before touching anything.** The order is not a preference; three of the four items change what is *inside the binary*, and F4 tests a binary. Getting the sequence wrong does not merely waste time — **it produces a confident, wrong verdict**, and one of the traps below would lead an agent to "fix" F1 by deleting code that must stay.

### 2.1 Why the order exists

| Dependency | Reason |
|---|---|
| **F1 before F4** | F4's assertion **E11** is *"no `DEBUG:` control is visible anywhere."* That assertion is a test **of F1's effect**. Run F4 first and E11 fails for a reason that has nothing to do with the build's quality. |
| **F2 before F4** | F4's assertion **E12** checks the icon and launch screen — a test **of F2's output**. |
| **F3 before F4** | Not required by any assertion, but F3 changes the app bundle. **F4 exists to test the artefact friends receive**, and that artefact includes the privacy manifest. Running F4 on a bundle missing it means re-running F4 later or shipping something never end-to-end tested. |
| **F1, F2, F3 among themselves** | **Mutually independent.** Any order. They touch disjoint files — Dart screens, iOS asset catalogues, and one new plist. Do them in the numbered order for a clean history, but nothing breaks if you do not. |

**The rule in one line: all of F1, F2 and F3 must be committed and green before F4 begins, and F4 must run on a binary built after all three.**

### 2.2 The build matrix — which build mode proves which item

**This is the part most likely to go wrong, because different items are provable only in different build modes, and one is provable in a mode Marionette cannot drive.**

| Item / assertion | Proved on | Why that mode |
|---|---|---|
| **F1** — buttons gated | **release** | `kDebugMode` is `false` **only** in release and profile. In a debug build the buttons are *supposed* to be visible. |
| **F2** — icon | any build | Icon assets are build-mode independent. Check on the home screen at small size. |
| **F2** — launch screen | any build, **cold start** | Must be a full quit-and-relaunch; a warm resume never renders the launch screen. |
| **F3** — manifest in bundle | any **built** `.app` | It is a file-presence check on the bundle, not a runtime behaviour. |
| **F4 — E1–E10, E12** | **debug** | Marionette requires `MarionetteBinding`, and `lib/main.dart:26` installs it **only** `if (kDebugMode)`. |
| **F4 — E11** | **release, and outside the Marionette session** | See §2.3. This is the trap. |

### 2.3 ⚠️ The E11 trap — E11 cannot be checked during the Marionette run

**The mechanism, verified in source:**

```dart
// lib/main.dart:26-30
if (kDebugMode) {
  MarionetteBinding.ensureInitialized();   // ← Marionette exists ONLY in debug
} else {
  WidgetsFlutterBinding.ensureInitialized();
}
```

`kDebugMode` is `false` in **both** profile and release builds. So:

- **Marionette can only attach to a debug build.**
- **F1's gating only takes effect when `kDebugMode` is false** — i.e. in exactly the builds Marionette cannot attach to.
- Therefore **there is no build in which Marionette can observe the buttons being correctly hidden.**

**What this means in practice, and what must not happen:**

> **In the F4 Marionette session the `DEBUG:` buttons WILL be visible, and that is CORRECT.** It is a debug build; `kDebugMode` is true; the buttons are supposed to render.
>
> **Do NOT record E11 as FAIL from the Marionette session.**
> **Do NOT "fix" F1 by deleting the buttons** — they are load-bearing for local development, and `debugSimulateBotResponses` drives several existing emulator tests. Deleting them would pass a misread E11 and break the suite.
> **Do NOT switch F4 to a profile build to work around it** — `kDebugMode` is false in profile too, so `MarionetteBinding` is not installed and Marionette simply cannot connect.

**E11's correct procedure — a separate release build, driven by hand:**

```bash
flutter build ios --simulator --release
```

```bash
xcrun simctl install <UDID> build/ios/iphonesimulator/Runner.app && xcrun simctl launch <UDID> com.whylabs.gaslight
```

Then walk the four screens that carry the seven sites — **lobby**, **truth/forgery** (`phase2_craft`), **vote** (`phase3_vote`), and confirm **zero** `DEBUG:` strings. Capture a screenshot of each with `xcrun simctl io <UDID> screenshot`.

**Record E11 in the findings doc as its own block, stating explicitly that it was verified on a release build outside the Marionette session, and why** — otherwise the next reader sees an assertion verified by a different method than its neighbours and cannot tell whether that was rigour or a shortcut.

*(A single device is enough for E11 — it is a per-screen rendering check, not a multiplayer one. Reaching the vote screen needs three players, so either run E11 on the release build during a three-device session, or accept lobby + truth/forgery coverage and record the vote screen as checked in a separate pass. State which you did.)*

### 2.4 The gates — what must be true before moving on

**Do not advance past a red gate.** If one fails, stop and fix that item; do not carry a known failure into the next.

| Gate | After | Must be true |
|---|---|---|
| **G1** | F1 | All seven sites wrapped, composing with each site's existing condition. `flutter test` **≥156**, analyzer **0 errors**. Buttons still present under `flutter test` (proving gated, not deleted). Committed. |
| **G2** | F2 | `file` reports the 1024 icon as **RGB, not RGBA**. Launch assets no longer 1×1. Icon eyeballed at 60 px, cold start checked from a full quit. Committed. |
| **G3** | F3 | `plutil -lint` clean **and** `find build/…/Runner.app -name "PrivacyInfo.xcprivacy"` returns a path — **with the pre-fix run recorded returning nothing.** Committed. |
| **G4** | before F4 | **The rebuild boundary — see §2.5.** |

### 2.5 G4 — the rebuild boundary

**The single most likely way to waste an F4 session is to run it against a binary built before F1–F3 landed.** Everything appears to work; E11 and E12 report the old behaviour; and the run has to be thrown away.

Perform these in order, and record the result of step 4:

1. **Confirm the tree is clean and all three commits are in.**
   ```bash
   git status --short && git log --oneline -4
   ```
   `git status` must print nothing, and F1, F2 and F3 must all appear.

2. **Uninstall on every booted simulator** — a reinstall over the top can retain a stale launch image, and `SharedPreferences` can restore a stale room.
   ```bash
   for U in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do xcrun simctl uninstall "$U" com.whylabs.gaslight 2>/dev/null; done
   ```

3. **Confirm `.env` has `USE_EMULATOR=false`.** It is a bundled asset — editing it after the build has no effect.

4. **Build fresh, and prove the binary is newer than the source.**
   ```bash
   flutter build ios --simulator --debug
   ```
   ```bash
   stat -f '%Sm binary' build/ios/iphonesimulator/Runner.app/Runner; git log -1 --format='%cd source' -- lib ios
   ```
   **The binary's timestamp must be later than the last commit touching `lib/` or `ios/`.** If it is not, the build did not pick up your changes — stop and investigate rather than proceeding.

5. **Launch one device at a time.** Concurrent builds against the same `build/` directory corrupt each other; start P1, wait for it to come up, then P2, then P3.

6. **Gate on the Guest Ledger.** `take_screenshots` on all three must show `THE GUEST LEDGER` before any assertion runs. A device showing a stale lobby, a crash or a white screen is not ready — **do not proceed with two working devices**; three is the enforced minimum player count.

### 2.6 If a gate fails

**Stop at the failing gate.** Do not proceed to the next item, and do not start F4 with a known-red gate — a playthrough on a build you already know is wrong produces evidence about nothing.

If the failure is a **design decision** rather than a defect — the icon does not read at 60 px and you are unsure what to draw; a plugin turns out to lack its privacy manifest — **file it in `docs/ongoing_general_errors.md` with options and a blank `Your selection: _____` line and stop.** Do not improvise brand or compliance decisions.

If the failure is in **F4 itself**, record it, mark every downstream assertion **NOT RUN**, and continue with whatever remains reachable. **A blocked run reporting six honest NOT RUNs is worth more than one reporting six passes it did not observe.**

---

## 3. F1 — Gate the `DEBUG:` buttons

**What this means for the user:** a friend opening the demo sees `DEBUG: ADD 9 BOTS` in the lobby and `DEBUG: BOTS SUBMIT` on three game screens. They will press one, and it will fail — since Issue 101 gated the callables on `FUNCTIONS_EMULATOR`, these buttons are **visible, tappable and guaranteed to error** in production.

### The gap

**Seven sites, none guarded.** The only condition on the lobby one is a player count:

```dart
// lib/screens/lobby_screen.dart:741-747
if (players.length < 10)
  Padding(
    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
    child: TextButton(
      onPressed: () => gs.debugAddBots(),
      child: const Text('DEBUG: ADD 9 BOTS', style: TextStyle(color: Colors.white24, fontSize: 10)),
    ),
  ),
```

| File | Lines |
|---|---|
| `lib/screens/lobby_screen.dart` | `745` |
| `lib/screens/phase2_craft.dart` | `331`, `368`, `569` |
| `lib/screens/phase3_vote.dart` | `257`, `414`, `572` |

**The one `kDebugMode` in `lobby_screen.dart` is not a guard.** It is `debugEnabled: kDebugMode` at `:188` — the flag passed to `createRoom` that marks the *room* as a debug room. Do not mistake it for protection on the buttons; **re-grep before editing**, because these line numbers drift.

### Implementation

Wrap each of the seven in `if (kDebugMode)`. `package:flutter/foundation.dart` is re-exported by `material.dart`, which every one of these files already imports, so **no new import is needed** — if the analyzer disagrees, add it rather than importing `dart:io`.

Compose with the existing condition rather than replacing it:

```dart
                    if (kDebugMode && players.length < 10)
                      Padding( ... ),
```

For the six `phase2_craft` / `phase3_vote` sites, the buttons sit in `Column`/`Row` children lists in varying shapes — some inside a `if (...) ...[ ]` spread, some standalone. **Read each site and wrap it in the form its context takes**; do not paste one shape into all seven.

**Do not delete the buttons.** They are load-bearing for local development and for the emulator suite; `debugSimulateBotResponses` drives several existing tests. `kDebugMode` is the right switch — it is `true` in debug and profile builds and compile-time `false` in release, so the tree-shaker removes the widgets entirely.

### Validation

**The falsifying assertion.** A widget test that pumps each of the four screens and asserts **no widget whose text starts with `DEBUG:` exists**. Because `kDebugMode` is `true` under `flutter test`, a naive assertion cannot distinguish a gated button from an ungated one — **so assert the opposite in the test environment**: with `kDebugMode` true the buttons **must still be present**, proving the widget was not simply deleted, and rely on the release-build check below for the absence.

**The release check is the one that actually proves F1**, and it must be performed and recorded:

```bash
flutter build ios --simulator --release
```

Install that build and walk the lobby, the truth/forgery screen and the vote screen, confirming **zero** `DEBUG:` strings. Capture a screenshot of each with `xcrun simctl io <UDID> screenshot`.

> ⚠️ **This check cannot use Marionette, and §2.3 explains why in full.** `MarionetteBinding` is installed only `if (kDebugMode)` (`lib/main.dart:26`), and `kDebugMode` is false in release — so Marionette cannot attach to the only build in which this fix is observable. **Drive the release build by hand.** A 10 px grey label is easy to miss, so screenshot every screen rather than trusting a glance, and zoom in on the region where the button used to sit.

Battery: `flutter analyze lib test` 0 errors · `flutter test` **≥156**.

Commit: `fix(debug): gate developer controls behind kDebugMode`.

---

## 4. F2 — Real app icon and launch screen

**What this means for the user:** today the app installs as the **stock blue Flutter chevron** and cold-starts on a **white flash**. Both say "unfinished demo" before the game renders a single frame.

### The gap

- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` holds 15 PNGs and **every one is the default Flutter logo** — verified by opening `Icon-App-1024x1024@1x.png`, not inferred from filenames.
- `LaunchImage.png`, `@2x` and `@3x` are all **1 × 1 pixel** greyscale stubs.
- **No icon tooling is configured** — `flutter_launcher_icons` and `flutter_native_splash` are absent from `pubspec.yaml`, so the current PNGs were placed by hand.

### Implementation

**Use tooling, not hand-placed files.** Add to `dev_dependencies`:

```yaml
  flutter_launcher_icons: ^0.14.4
  flutter_native_splash: ^2.4.6
```

**Source art already exists in the repo** — the raven mascot at `assets/images/raven/` and the palette in `lib/theme/app_colors.dart`. Compose a **1024 × 1024** master: the raven on a solid `AppColors.ground` `#14110E` or `AppColors.oxblood` field, with generous padding — iOS applies a large corner radius and a 60 px icon is mostly centre.

**Three hard requirements, each of which fails an App Store upload:**

1. **The 1024 icon must have NO alpha channel.** Flatten it. `flutter_launcher_icons` has `remove_alpha_ios: true` — set it; do not rely on the source being flat.
2. **No transparency and no rounded corners in the source.** iOS masks the corners itself; a pre-rounded icon renders with a doubled radius.
3. **Every size must be generated from the one master.** Hand-placing 15 PNGs is how icon sets drift out of sync.

Configure and generate:

```yaml
flutter_launcher_icons:
  ios: true
  android: false
  image_path: "assets/icon/app_icon_1024.png"
  remove_alpha_ios: true

flutter_native_splash:
  color: "#14110E"
  ios: true
  android: false
```

Then `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.

**Keep the splash minimal.** A solid `#14110E` field is the goal — the app's first frame is already the lit lobby, and a logo splash on top of a fast Flutter start reads as a stutter. If you add the wordmark, keep it small and centred.

**Commit the generated assets.** They are build inputs, not build outputs, and `ios/Runner/Assets.xcassets` is tracked.

### Validation

**Automated:**
- `Icon-App-1024x1024@1x.png` is **1024 × 1024** and has **no alpha**: `file` reports `8-bit/color RGB`, not `RGBA`. **This is the check that catches a rejected upload**, and it must be recorded.
- All 15 icon slots are non-default: their md5s differ from the current stock set. Record the before/after hash of the 1024 file at minimum.
- `LaunchImage` assets are no longer 1 × 1 — `file` reports real dimensions.

**Visual, on a simulator:**
- The home-screen icon is the raven, legible at the smallest size. **Look at it at 60 px, not at 1024** — detail that reads at full size disappears on a home screen.
- Cold start shows the dark ground, not white. **Fully quit the app first**; a warm relaunch does not exercise the launch screen.

Commit: `feat(brand): add the app icon and launch screen`.

---

## 5. F3 — `PrivacyInfo.xcprivacy`

**What this means for the user:** without it the App Store upload is rejected, and the privacy label on the product page is wrong. It costs one file and needs no Apple licence, so it is worth doing while you wait.

### The gap

There is **no `.xcprivacy` anywhere in the repo**. Two separate obligations:

1. **Required-reason APIs** — a fixed Apple list (`UserDefaults`, file timestamps, disk space, boot time, active keyboards). **This project's app target owes nothing here**: `ios/Runner/AppDelegate.swift` is Flutter boilerplate and the only other native file is the generated plugin registrant, so **no code of ours calls one**. `SharedPreferences` does touch `UserDefaults`, but that call lives in `shared_preferences_foundation` and is that plugin's manifest to declare.
2. **Data collection** — feeds the App Store privacy label. **This is the half we must write.**

### Implementation

Create **`ios/Runner/PrivacyInfo.xcprivacy`**:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyTracking</key>
  <false/>
  <key>NSPrivacyTrackingDomains</key>
  <array/>
  <key>NSPrivacyAccessedAPITypes</key>
  <array/>
  <key>NSPrivacyCollectedDataTypes</key>
  <array>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeName</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <false/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
    </dict>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeOtherUserContent</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <false/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
    </dict>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeUserID</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <false/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
    </dict>
  </array>
</dict>
</plist>
```

**Why these three and no others**, traced through the code rather than guessed: the display name comes from `player_name_field` into `PlayerState.name`; the truths and forgeries a player writes go through `submitAnswer` into `sealed/{cardId}`; the anonymous Firebase UID from `signInAnonymously()` is stored as `PlayerState.authUid`. There is **no analytics SDK, no ad SDK, and no Gemini call left in the client**, so tracking is `false` and the domains list is empty. **`Linked` is `false` because the account is anonymous** — there is no email, phone or sign-in tying it to a person.

**⚠️ The step that is most often missed: the file must be a member of the `Runner` target.** Add it in Xcode (or via the `pbxproj`) to **Runner → Build Phases → Copy Bundle Resources**. **A manifest sitting in the repo but not in the target ships nothing**, and everything still builds and runs — the failure is silent until Apple rejects the upload.

### Validation

**The falsifying check — prove it is inside the built app, not just in the repo:**

```bash
flutter build ios --simulator --release
find build/ios/iphonesimulator/Runner.app -name "PrivacyInfo.xcprivacy"
```

That must return a path. **Run it before adding the file to the target and confirm it returns nothing** — that is the failure this check exists to catch, and it is the whole reason this step is called out.

Then verify the plist parses and reads back as expected:

```bash
plutil -lint ios/Runner/PrivacyInfo.xcprivacy
```

**Also re-check the plugin side after a clean `pod install`.** `ios/Pods` currently holds only scaffolding — `Headers`, `Local Podspecs`, `Manifest.lock`, `Pods.xcodeproj`, `Target Support Files` — with no pod sources, so `find ios/Pods -name "*.xcprivacy"` returns nothing today and proves nothing. After a real install, confirm the manifests are present for `shared_preferences_foundation`, `path_provider_foundation`, `firebase_core`, `cloud_firestore`, `audioplayers_darwin` and `share_plus`. **If any is missing, that plugin needs an upgrade — file it, do not write a manifest on its behalf.**

Commit: `feat(ios): add the app privacy manifest`.

---

## 6. F4 — Final E2E playthrough

**What this means for the user:** this is the last gate before friends play it. It runs on the build they will get, after F1–F3.

### Why this is not a routine playthrough

The security wave changed **four load-bearing gameplay paths and nothing has played the game since**:

- `votes` now stores an opaque option UUID resolved server-side at the reveal transition — **the third redefinition of that field, and the first two both broke the reveal.**
- The reveal merge is scoped to a single card, so **cards 2 and 3 of a round take a different code path** than before.
- Forgery authorship is withheld until `unmaskDeadline` closes — a change to **when** data appears, not just what.
- `joinRoom` requires ownership, a seat token, or staleness. **The seat-token rejoin path has never run on a device.**

The 61-test emulator suite proves the server. It cannot prove the reveal renders, the standings are right, or that a player who backgrounds the app gets back into their seat.

### Setup

Marionette is installed and working — `marionette_flutter` in `pubspec.yaml`, the binding in `lib/main.dart`, three servers in `.agents/mcp_config.json`, stable keys from `f3a5a1d`. **Verify rather than redo.**

- **`.env` must contain `USE_EMULATOR=false`** — it is a bundled asset, so changing it needs a rebuild.
- **Rebuild after F1–F3**; a stale binary tests the old client.
- Uninstall on all three simulators so no stale room is restored, then launch **one device at a time** (concurrent builds corrupt `build/`).
- `Disable Game Timers` **on** (`lobby_screen.dart:623`) — record it as a deviation. `Family-Friendly Decks Only` **off** (`:643`).
- **Three real clients. Never `DEBUG: ADD 9 BOTS`** — bots are server-seeded and never traverse the client write path or the rules. *(After F1 the button is gone from release builds anyway; if you run a debug build for convenience, the ban still stands.)*
- Prefix each device's answers `AAA` / `BBB` / `CCC` — assertions E5 and E6 are only checkable with that ground truth.

### The assertions

| # | Assertion | Verdict comes from |
|---|---|---|
| **E1** | A 3-round match plays through to `THE NIGHT'S HONORS` without stalling | The round counter advancing twice, then Game Over |
| **E2** | Every reveal shows the right truth and forgeries — **cards 2 and 3 included** | Card text on all three devices. Issue 99 changed this path |
| **E3** | Unread cards stay blank before their turn | No answers visible for a card not yet revealed |
| **E4** | The unmask window shows no authorship; results correct once it closes | `REVENGE UNMASKING RESULTS`. Issue 100 changed *when* this appears |
| **E5** | Scoring is right — truth-finder `ceil((P−1)/(S+1))`, truth-teller `+1` per finder, forger `+1` per fooled voter | `STANDINGS` before and after, **as numbers**. Issue 98 changed what `votes` holds |
| **E6** | Attribution is correct — the named author actually wrote it | Your `AAA`/`BBB`/`CCC` ground truth |
| **E7** | **Seat recovery: force-quit a player mid-match and relaunch — they return to their own seat with their score** | **Never tested live. Issue 97's seat token is the mechanism, and if it is wrong friends get locked out of their own seats** |
| **E8** | Host kick removes a lobby player; the removed player sees the notice | Both devices |
| **E9** | A player leaves mid-match from a 4-player game; the match continues | The remaining three |
| **E10** | A 3-player match dropping to 2 ends for everyone at the final score | All devices reach Game Over, scores intact |
| **E11** | **No `DEBUG:` control is visible anywhere**, on a **release** build | ⚠️ **Not checkable in this session — see §2.3.** In the debug build Marionette drives, these buttons are *correctly* visible. Run E11 separately on a release build, by hand, and record it as its own block saying so |
| **E12** | The app icon and launch screen are the real ones | Home screen at 60 px; a cold start from fully-quit |

**E7 is the one to get right.** Force-quit from the app switcher — not a background — and relaunch. The seat token lives in `SharedPreferences` as `seat_token_{roomCode}`, so a relaunch should present it and land back in the same seat. **If it fails, capture the room code, the player id and the error code before doing anything else**, and file it: that is a security-critical path and a fix must not be improvised.

**E9 and E10 destroy the match — run them last, E9 before E10.**

### Record

`docs/playthrough_findings_marionette.md`, one block per assertion, all twelve, including passes. Header: date, commit SHA, the three devices and UDIDs, build mode, `USE_EMULATOR`, and the timers-disabled deviation.

**Every quoted game string needs a `grep -F` traceability line.** An assertion whose evidence cannot be traced to something the harness returned is **NOT RUN**, not PASS. **Do not paraphrase, reconstruct or infer** — this record has been fabricated once before, and the defence is mechanical, not vigilance.

**Do not fix anything inline, and do not write into `ongoing_general_errors.md`.** A failure becomes a tracked issue with options — a fix applied during the run destroys the evidence that it was needed.

Commit: `docs(playthrough): record the pre-demo end-to-end verification`.

---

## 7. Already delivered — do NOT rework

**Security (Issues 96–101), verified in source and against the live project:** `/rooms` denies `list`; seat re-bind requires ownership, a `seatToken` (hashed in default-deny `sealed`), or a stale seat; `votes` stores opaque option UUIDs with phase/reader/duplicate guards; the reveal merges only the current card; unmask authorship is withheld until the deadline; debug callables are emulator-only *and* host-only.

**Functional (Issues 84–95):** dialog contrast (≥4.5:1 content / ≥3.0:1 title); deck exhaustion at two deck sizes; host kick with the non-host rejection bound; readiness gate with the host-exemption deadlock guard; below-3 auto-end with its two guards; `isTimerDisabled` leave controls; ordered option-id/text layering; join-error mapping; busy states.

**Issues 50–83** as previously recorded. **Issue 31** — loose `!= null`; never "simplify" to a falsy check. **Issues 28/29** — `phosphor_flutter` can never be used.

**Release plumbing already correct:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** (TestFlight will not stall on export compliance) · version `1.0.0+2` · iOS target **15.0** · Node **22** · `.env` ships inside the IPA.

---

## 8. Invariants & intentional decisions — do NOT change

- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat — **do not simplify to one condition**. The token's hash lives only in the default-deny `sealed` subcollection.
- **`allow get` and `allow list` are split on `/rooms`. Never collapse them back to `allow read`.**
- **`sealed` and `embeddings` are default-deny by having no `match` block.** Never add an explicit `allow read: if false`.
- **`votes` stores opaque option UUIDs during the vote phase**, resolved server-side at reveal. Never store the resolved author pre-reveal.
- **Never send *other players'* authorship to the client** — this does not forbid telling a caller their own.
- **`castVote` rejects only genuine self-votes.** Never loosen it, and never let a client bound exceed the server's.
- **Debug callables are emulator-only *and* host-only.** Both guards. **F1 gates the UI; it does not replace either.**
- **The option id is the authority; text is the fallback, consulted only when the id is null.** Never union the two.
- **A failed `getMyOptionId` is not cached and will be retried**; `fetchMyOptionId` is called from `build()` on purpose. Do not tidy either.
- **The readiness gate exempts the host deliberately.** Use `!== true`. Separate guard from the 3-player floor.
- **The 3-player floor applies in play as well as at start**, is exempt in the lobby, wins over the phase branches.
- **`handleDisconnect` has exactly three legitimate callers.** A non-host acting on a third player stays rejected.
- **Dialogs render on `groundRaised`, never `colorScheme.surface`.** **Never interpolate an exception into user-facing text.** **Busy-state disabling is a correctness guard** — `createRoom` is not idempotent.
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.**

**Assessed and rejected — do NOT re-propose:** room codes from `Math.random()`; `authUid` exposure in player documents; prototype pollution via `selectedDeckId`; plus the declined options listed in `ongoing_general_errors.md` §4.

---

## 9. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Playthrough evidence | `docs/playthrough_findings_marionette.md` |
| Rules, seat tokens, callables, debug isolation, TTL, deploy verification | `design_database_and_security.md` |
| `votes` two-phase contract, phases, 3-player floor, readiness gate | `design_game_state_and_models.md` |
| Scoring, reveal beats, reveal scoping, unmask withholding, own-answer lockout | `design_scoring_and_ui.md` |
| Palette, typography, icons, mascot, dialogs, error surfaces, busy states | `design_ui_direction.md` |
| Deck catalogue, re-roll exclusion, exhaustion plumbing | `design_prompt_system.md` |
| Rules assertions | `functions/test/rules.spec.ts` |
| Callable / authorization assertions | `functions/test/game_e2e.spec.ts` |

---

## 10. Validation standard

**Write validation that fails against the broken state, and observe it fail — and apply that to the test, not only the code.**

**Prove the artefact ships, not that it exists.** F3's whole risk is a manifest in the repo that is not in the target; F2's is an icon that is 1024 but carries alpha. **Check the built output.**

**Assert the negative as well as the positive.** "No `DEBUG:` string on any screen" is the assertion; "the game still runs" is not.

**A test harness that cannot express the bug will pass against it.** `kDebugMode` is `true` under `flutter test`, so F1 cannot be proved by a widget test alone — the release build is the evidence.

**An observation you cannot trace to a tool result is not an observation.** `grep -F` every quoted game string.

**A green suite is not evidence about anything it cannot observe, or about what is deployed.**

**Measure; do not estimate. Pair every fix assertion with an over-reach guard, and make sure the guard can actually fail.**

**A driven playthrough is not a played one.** F4 can check every string and still miss whether the game is fun. Say so in "what the harness could not see."

---

## 11. Feedback loop — what past specs got wrong

- **A fix can be correct while its design doc still describes the vulnerability.** Grep the design docs for the code you just deleted.
- **A documented invariant with no test behind it is a wish.**
- **When a design doc calls something a secret, grep for where it is published.** `playerId` was the recovery credential *and* a world-readable document ID.
- **When you redefine what a field holds, enumerate its readers.** `votes` has done it three times.
- **A guard's test must be run with the guard removed** — the skip is invisible in a green run.
- **A spec can be over-cautious as well as wrong.** A warning that costs a cycle chasing a non-problem is as expensive as a missing one.
- **Working logs rot by appending.** `ongoing_general_errors.md` went 903 → 559 → 223 lines twice for the same reason: each pass added a summary without removing the one it superseded. **One banner in §1, one Resolved heading, one line per resolved issue.**
- **One item = one commit.**

---

## THE LOOP

```
(1) STUDY the item here + its full issue text in ongoing_general_errors.md +
    the exact files at the cited anchors. RE-GREP every anchor; F1's seven
    line numbers will drift as you edit.
(2) WRITE the falsifying validation FIRST. Run it. OBSERVE IT FAIL. Record
    the exact output. For F2 and F3 the check is on the BUILT ARTEFACT, not
    the source tree.
(3) IMPLEMENT exactly as specified. Record any substitution you make.
(4) VALIDATE per section 10, including the over-reach guard, and remove the
    guard to prove the test can still fail.
(5) RECORD the observed failure text in a comment on the test AND in the
    commit body.
(6) RE-RUN THE FULL BATTERY before committing, including
    ./scripts/check_deploy_fresh.sh.
(7) BLOCKED, or a design decision is needed? STOP. File it in
    ongoing_general_errors.md with options and a blank `Your selection: _____`.
(8) COMMIT: Conventional Commit, WHY in the body, pre-fix failure output
    included. Move the issue into the SINGLE existing Resolved heading and
    update the design doc that described the OLD behaviour.
```

---

## Definition of Done

- [ ] **F1** — all seven `DEBUG:` sites wrapped in `kDebugMode`, composing with each site's existing condition; buttons still present under `flutter test` (proving gated, not deleted); **a release build shows zero `DEBUG:` strings**, driven by hand with a screenshot per screen (**not** via Marionette — §2.3).
- [ ] **F2** — `flutter_launcher_icons` and `flutter_native_splash` configured and generated from a single 1024×1024 master; **the 1024 icon has no alpha** (`file` reports RGB, not RGBA); launch assets no longer 1×1; icon checked at 60 px and cold start checked from fully-quit.
- [ ] **F3** — `ios/Runner/PrivacyInfo.xcprivacy` created, `plutil -lint` clean, **added to the Runner target**, and `find build/…/Runner.app -name "PrivacyInfo.xcprivacy"` returns a path — **with the pre-fix run recorded returning nothing**.
- [ ] **F3** — plugin manifests re-checked after a clean `pod install`; any missing one filed as an upgrade, not written by hand.
- [ ] **Gates G1–G4 each observed green before the next item began**, and the G4 rebuild boundary's timestamp check (§2.5 step 4) recorded — the binary newer than the last `lib/`/`ios/` commit.
- [ ] **F4** — all twelve assertions attempted, each PASS / FAIL / NOT RUN with a reason and `grep -F` traceability; **E7 (seat recovery) explicitly recorded** — it has never run on a device.
- [ ] **E11 recorded as verified outside the Marionette session, on a release build, with that stated in its block** — and **not** reported FAIL from the debug run (§2.3).
- [ ] **F4** — nothing fixed inline; failures filed with options.
- [ ] Battery at or above the bar: **0 errors** · **≥156** · clean build · **61/61** · deploy gate **exit 0**.
