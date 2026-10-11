# Agent Execution Guide — Active Build: Wave AI (14 approved items) + AH1 — October 10, 2026

**You are an engineering agent with no memory of this project.**

**Every number and literal string in this document is a decision, not a suggestion.** Implement as written. If a value turns out to be impossible, keep the intent, deviate minimally, and say so in the commit body. If the design itself cannot work, **STOP** and file it in `docs/ongoing_general_errors.md` with options and a `Your selection: _____` line — do not improvise.

**What is approved.** A read-only audit on October 10, 2026 filed Issues 178–191. The user selected **Option A for 179–188, 190 and 191**, and **Option B for 178 and 189** (chosen in chat on October 10 after asking for plain-language context; their tracker lines still hold the questions — never edit a `Your selection:` line). **AH1** (specced September/October, not yet implemented) stays in the queue. Wave AI numbers the fourteen items **in execution order**: AI1 … AI14. The mapping to issues is in §2.

**What not to touch.** Anything in §3 (delivered), §4 (accepted equivalents) and §5 (invariants). Do not invent work beyond §2.

---

## 0. Standing constraints — apply to every item

1. **One item = one Conventional Commit**, WHY in the body, plus the tracker update (§0.9) in the same commit.
2. **Falsify every new test.** Remove or revert the fix, run the test, watch it fail, restore. Paste the failing output into the commit body under `Falsification:`. A test that fails to *compile* proves nothing (THE LOOP rule 7).
3. **Read exit codes bare** — never through `| tail`, never through `timeout` (macOS has none). An empty result means nothing until the same query has returned something (lesson §2.44).
4. **New code adds zero analyzer infos.** Use `.withValues(alpha: x)`, never `.withOpacity(x)`; no `print`. After every item `flutter analyze lib test` must show **0 errors · 0 warnings · 188 infos** — until AI12, which lowers it to **172**.
5. **Strings are verbatim.** Every quoted string below — copy, keys, labels — is exact, including punctuation and the em dash.
6. **The only server change in this wave is AI11.** Deploy functions **once**, after AI11, then restore `CLEANUP_DRY_RUN=false` and re-run `./scripts/check_deploy_fresh.sh` (§0.8). Server changes are **additive only** — build **1.1.0 (8)** is on testers' phones.
7. **Rendered contrast is measured from pixels**, with the helper AI3 creates (`test/helpers/rendered_contrast.dart`). **Never** use the widget-tree walk in `test/contrast_tokens_test.dart:257–281` for a new check: it resolves the nearest decorated ancestor and cannot see a Material component's own fill — it would have passed Issue 179 at 1.02 : 1.
8. **Deploy procedure (AI11 only):** `firebase deploy --only functions` → `gcloud run services update cleanupdaily --update-env-vars CLEANUP_DRY_RUN=false` → read the flag back from the new revision → `./scripts/check_deploy_fresh.sh` bare, exit 0. Deploying changes production: if your session requires confirmation for outward-facing actions, ask the user first. **Do not upload to TestFlight** in this wave.
9. **Tracker update per item:** move the issue to `docs/ongoing_general_errors.md` §3 (one index row: what shipped, where the contract lives), update any design doc whose described behaviour changed, and delete the issue block from "Unresolved". Never fill in or edit a `Your selection:` line.
10. **Never accept Xcode's "Update to recommended settings" dialog** (lesson §2.29). Edit `project.pbxproj` as text.
11. **A load-bearing manual check is REQUIRED and its outcome goes in the commit body either way:** `Device check: DONE — <what you saw>` or `Device check: NOT RUN — <reason>` (lesson §2.45).

### 0.1 Environment — learned on this Mac, each cost a cycle

- **Until AI1 lands, no iOS build works** (Xcode 27.0 rejects the generated `Flutter` pod's iOS 13.0 target). AI1 is first for that reason. After AI1 every simulator/device check below is runnable.
- **Emulators by hand:** `PATH="/opt/homebrew/bin:/opt/homebrew/opt/openjdk/bin:$PATH" npx firebase-tools emulators:start --only auth,functions,firestore` (the same PATH `functions/package.json`'s test script uses; without it `java -version` fails). App: `flutter run -d <udid> --dart-define=USE_EMULATOR=true`. Solo play: `DEBUG: ADD 9 BOTS` in the lobby, `DEBUG: BOTS SUBMIT` each phase.
- **Small-phone simulator:** none exists by default. Create it: `xcrun simctl create "iPhone SE (3rd generation)" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation com.apple.CoreSimulator.SimRuntime.iOS-26-5`. Text size: `xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large` (the app clamps to 1.3; restore with `large`). Reduce Motion: `xcrun simctl spawn <udid> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true`, then cold-relaunch.
- **This Xcode ships no Simulator.app** and `simctl` cannot rotate a device. Anything needing rotation needs the user.
- **Marionette:** text taps and `scroll_to` fail on off-screen widgets — swipe first. The `DEBUG:` buttons are `TextButton`s below the fold. Failed marionette taps appear in `get_runtime_errors` as `ext.flutter.marionette.*` exceptions — they are not app errors.
- **`flutter test --coverage` is broken on Flutter 3.44.6** (AI14 investigates). Do not use it for validation.
- **`~/.local/bin/git` cannot clone over https** — prefix `PATH="/usr/bin:$PATH"` for any clone.

---

## 1. Verified baseline — measured October 10, 2026 on `04363d6` (docs-only changes since)

**This is the regression bar.** Every gate below was run bare in that session.

| Gate | Result |
|---|---|
| `flutter analyze lib test` | **0 errors · 0 warnings · 188 infos · exit 1** |
| `flutter test` | **357 passing**, exit 0 |
| `npm --prefix functions run build` | clean, exit 0 |
| `npm --prefix functions test` | **164 passing**, exit 0 |
| `./scripts/check_decks_in_sync.sh` | **exit 0** |
| `./scripts/check_playthrough_evidence.sh` — **all five**: no-arg, `docs/playthroughs/findings_marionette.md`, `…/findings_web.md`, `…/findings_5player.md`, `…/findings_waveAA.md` | **exit 0** |
| `./scripts/check_deploy_fresh.sh` | **exit 0 — FRESH, 19 functions** |
| `./scripts/check_web_e2e_strings.sh` | **exit 0** |
| `flutter build ios --release --no-codesign` | **exit 0 — `✓ Built build/ios/iphoneos/Runner.app (50.1MB)`** — the required **ninth gate** since AI1 (Issue 178). Before AI1 it failed with exit 1: `Target Integrity … 'IPHONEOS_DEPLOYMENT_TARGET' is set to 13.0`. |
| `flutter test --coverage` | **Not a gate** — segfaults the runner (Issue 189 → AI14) |

**Production (read October 10 via Firebase MCP):** 19 functions deployed — the 18 callables in `functions/src/index.ts` plus `cleanupDaily`, **including `submitTargetForgeryGuesses`**. Firestore rules identical to `firestore.rules`. 0 ERROR log entries Sep 26 – Oct 10. `CLEANUP_DRY_RUN=false` was last read back on revision `cleanupdaily-00018-2wm` after the AG3 deploy; it was **not** re-read on October 10.

**⚠️ `flutter analyze lib test` exits 1 even when clean.** Judge it by the counts. Never run bare `flutter analyze` (~678 phantom errors from `build/`).

---

## 2. Execution order

| Step | Item | Issue → option | Why this position |
|---|---|---|---|
| 1 | **AI1** Remove CocoaPods | 178 → B | Nothing else can be built or checked on a simulator or device until this lands. |
| 2 | **AH1** iOS dropped connection → connection sentence | (already specced) | Its required device check needed a working build (AI1). AI9 and AI10 reuse the connection branch AH1 extends with `unknown`. |
| 3 | **AI2** Correct README and tracker drift | 191 → A | Docs only. Early because it removes the README's bare-`flutter analyze` trap and replaces README's hard-coded info count with a pointer, so AI12 never has to edit README. |
| 4 | **AI3** House Rules chips + the pixel-contrast helper | 179 → A | Creates `test/helpers/rendered_contrast.dart`, which AI4 and AI5 reuse. |
| 5 | **AI4** One shared confirmation dialog + lobby headings | 181 → A | Reuses AI3's helper. Before AI8, which edits the kick control next to the kick dialog. |
| 6 | **AI5** Vote screen contrast | 182 → A | Reuses AI3's helper. Before AI7, which changes `PrimaryButton` on the same screen. |
| 7 | **AI6** Many-voter reveal layout | 180 → A | Before AI7, which edits the same reveal file. |
| 8 | **AI7** No truncation on a 375-pt phone | 184 → A | After AI5/AI6 (same screens); before AI8, whose guideline test runs on the vote screen it changes. |
| 9 | **AI8** Tap targets and accessible names | 187 → A | After AI4 and AI7 so its guideline tests see the final dialogs and buttons. |
| 10 | **AI9** Settings write failures surface | 186 → A | After AH1 (`lobbyCallableErrorMessage`). |
| 11 | **AI10** Auto-rejoin keeps the seat on a transient failure | 183 → A | After AH1 (reuses the connection sentence). |
| 12 | **AI11** Error reasons from the server; one client mapper | 185 → A | The only server change; one deploy (§0.8). |
| 13 | **AI12** Migrate deprecated APIs | 190 → A | Lowers the analyzer bar once, after every other code item. Needs AI1 for its share-sheet device check. |
| 14 | **AI13** iPhone-only device family | 188 → A | Needs AI1 to build. Nothing depends on it; must land before the next App Store release. |
| 15 | **AI14** Investigate the coverage collector | 189 → B | Independent, no `lib/` change. May run any time after AI1, in parallel. |

---

## 3. AI1 — Remove CocoaPods; build through Swift Package Manager only (Issue 178 → B)

**What this means for the user.** Today no new iOS build can be made on this Mac — not for TestFlight, not for AH1's device check. After this, builds work on Xcode 27 and the project has one dependency system instead of two.

**The gap.** Xcode 27.0 (27A266a) rejects any target below iOS 15. The only such target is the `Flutter` aggregate pod CocoaPods generates (`ios/Pods/Local Podspecs/Flutter.podspec.json` → `"ios": "13.0"`; Flutter's `podhelper.rb:49` only clears targets **below** 13). `flutter run` already reports *"All plugins found for ios are Swift Packages, but your project still has CocoaPods integration"* — every plugin, Firebase included, already comes through Swift Package Manager. CocoaPods' only remaining job is generating that broken pod.

**Verified before specifying (October 10, scratch `git archive` of `04363d6`, Flutter 3.44.6, CocoaPods 1.17.0, Xcode 27.0):** steps 2–6 below produced a 6-file diff (2 insertions, 141 deletions), and `flutter build ios --release --no-codesign` then printed `✓ Built build/ios/iphoneos/Runner.app (50.1MB)`, exit 0. The build ran no `pod install` and did not recreate `ios/Podfile`. The same command on the unchanged tree exits 1 with the Target Integrity error.

### 3.1 Implementation
1. Preconditions: `flutter --version` → 3.44.6; `pod --version` → 1.17.0; `xcodebuild -version` → Xcode 27.0. Record `flutter config --list | grep -i swift` in the commit body.
2. `cd ios && LANG=en_US.UTF-8 pod deintegrate` (`LANG` silences CocoaPods' UTF-8 warning). Expected last lines: `Project has been deintegrated. No traces of CocoaPods left in project.` and `Note: The workspace referencing the Pods project still remains.` It removes from `ios/Runner.xcodeproj/project.pbxproj`: the `libPods-Runner.a` and `libPods-RunnerTests.a` build files and file references, the six `Pods-Runner.{debug,release,profile}.xcconfig` / `Pods-RunnerTests.{debug,release,profile}.xcconfig` file references, both `[CP] Check Pods Manifest.lock` build phases, and the empty `Frameworks` group.
3. Delete line 1 of `ios/Flutter/Debug.xcconfig` (`#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"`) and line 1 of `ios/Flutter/Release.xcconfig` (the `.release.` twin). Each file must then contain exactly one line: `#include "Generated.xcconfig"`.
4. `git rm ios/Podfile ios/Podfile.lock`. (`ios/Pods/` is gitignored; `pod deintegrate` deletes it.)
5. In `ios/Runner.xcworkspace/contents.xcworkspacedata`, delete the three-line `<FileRef location = "group:Pods/Pods.xcodeproj"> </FileRef>` element, leaving only the `group:Runner.xcodeproj` `FileRef`.
6. Delete the now-empty `Pods` group from `project.pbxproj`: its entry `CC17CA760A5EA19479DB890B /* Pods */,` in the main group's `children`, and the object `CC17CA760A5EA19479DB890B /* Pods */ = { isa = PBXGroup; … path = Pods; … };`. (These IDs are from the scratch run — confirm they match before deleting.) Edit as text.
7. Do **not** change `IPHONEOS_DEPLOYMENT_TARGET` (Runner stays 15.0) or `TARGETED_DEVICE_FAMILY` (that is AI13). If Xcode rewrites `ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`, commit it and say so.
8. Docs: in `docs/ongoing_general_errors.md` §2.29, the sentence *"This project has four shell-script build phases: two running Flutter's `xcode_backend.sh` … and two CocoaPods checks"* becomes two phases, noting AI1 removed the CocoaPods checks. `grep -rn "pod install\|Podfile\|CocoaPods" README.md docs/*.md` and correct every instruction that would tell a reader to run CocoaPods (historical records in §3 indexes stay).

### 3.2 Validation
1. **Falsifying check (record both outputs):** on the parent commit, `flutter build ios --release --no-codesign` → **exit 1**, log contains `Target Integrity (Xcode): The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 13.0`. After the change → **exit 0**, log contains `✓ Built build/ios/iphoneos/Runner.app`.
2. **No traces, mechanically:** `grep -c "Pods" ios/Runner.xcodeproj/project.pbxproj` → `0`; `grep -c "Pods" ios/Runner.xcworkspace/contents.xcworkspacedata` → `0`; `ls ios/Podfile ios/Podfile.lock` → both `No such file or directory`; the build log contains no `pod install`; afterwards `git status --porcelain ios/` shows no new `Podfile`.
3. **Release plumbing unchanged**, from `build/ios/iphoneos/Runner.app/Info.plist` via `/usr/libexec/PlistBuddy -c "Print :<key>"`: `CFBundleIdentifier` = `com.whylabs.gaslight`, `CFBundleShortVersionString` = `1.1.0`, `CFBundleVersion` = `8`, `MinimumOSVersion` = `15.0`; and `ls build/ios/iphoneos/Runner.app/PrivacyInfo.xcprivacy` exists (§5: the privacy manifest stays in the Runner target).
4. **Simulator run:** `flutter run -d <iPhone 17, iOS 26.5> --dart-define=USE_EMULATOR=true` reaches the title screen showing `v1.1.0 (8)`; create a room, `DEBUG: ADD 9 BOTS`, start, submit a truth — the craft screen renders with no runtime errors. Screenshot it.
5. **Archive:** `flutter build ipa` builds the `.xcarchive` (the export step may fail without an Apple Distribution certificate — expected). Verify the archive's timestamp and `CFBundleVersion` = `8`. **Do not upload.**
6. Full battery: all eight §1 gates bare, unchanged — plus the new ninth gate (step 1) at exit 0. Add the ninth row to §1 in the same commit.
7. Commit body: the two outputs from step 1, and `Device check: DONE — <what the simulator showed>`.

**Blast radius:** `ios/Podfile` (deleted), `ios/Podfile.lock` (deleted), `ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig`, `ios/Runner.xcworkspace/contents.xcworkspacedata`, `ios/Runner.xcodeproj/project.pbxproj`, possibly `Package.resolved`, `docs/ongoing_general_errors.md` §2.29, this guide's §1, README/docs mentions of CocoaPods.

---

## 4. AH1 — Make a dropped connection on iOS say so (unchanged spec; device check now runnable)

**What this means for the user.** AG1 was meant to replace the stack trace from the September 27 report with *"Could not reach the parlour. Check your connection and try again."* On an iPhone with no connection, it actually shows *"Something went wrong. Try again."* After this, it shows the connection sentence.

**The gap.** `lobbyCallableErrorMessage` (`lib/screens/lobby_screen.dart:44`) sends `unavailable` and `deadline-exceeded` to the connection sentence. **On iOS, almost no connection failure arrives as either.** Traced through the vendored sources:

1. **firebase-ios-sdk 12.15.0**, `FirebaseFunctions/Sources/Functions.swift`, `processedError(fromResponseError:endpointURL:)` maps HTTP status errors, and **only** `NSURLErrorDomain` + `NSURLErrorTimedOut` to `FunctionsError(.deadlineExceeded)`. No internet (`-1009`), DNS failure (`-1003`), cannot connect (`-1004`), connection lost (`-1005`) return as a **raw `NSError`**.
2. **cloud_functions 6.3.5**, `ios/…/FirebaseFunctionsPlugin.swift`, `createFlutterError(from:)` starts from `var errorCode = "unknown"` and maps only `com.firebase.functions` errors, so a raw `NSURLErrorDomain` error **keeps `unknown`**.
3. **cloud_functions_platform_interface 6.0.5**, `exception.dart`, `platformExceptionToFirebaseFunctionsException` sets `code = details['code']` → Dart receives **`FirebaseFunctionsException(code: 'unknown')`**.

**Re-check this chain before changing anything.** After AI1 the SDK checkout lives under `~/Library/Developer/Xcode/DerivedData/Runner-*/SourcePackages/checkouts/firebase-ios-sdk/` (Swift Package Manager — it was already there before AI1); the Dart packages are under `~/.pub-cache/hosted/pub.dev/`. If a version differs, re-trace that hop and record it.

### 4.1 Implementation
1. In `lobbyCallableErrorMessage`, add **`case 'unknown':`** to the branch returning **`Could not reach the parlour. Check your connection and try again.`**, alongside `unavailable` and `deadline-exceeded`. Same sentence for create and join.
2. Put a comment above that case naming the three hops and versions above, so a later tidy-up does not move `unknown` back to the default.
3. **Leave `internal` alone** — `test/lobby_join_error_test.dart` guard 3 asserts *"unmapped code (internal) produces generic message"* and must pass unedited.
4. A non-`FirebaseFunctionsException` stays generic.
5. This evidence covers iOS only. Make no claims about web.

### 4.2 Validation
1. Widget test in `test/lobby_create_error_test.dart`: create throws `FirebaseFunctionsException(code: 'unknown', message: 'The Internet connection appears to be offline.')` → SnackBar reads exactly the connection sentence, and the message text does not appear on screen.
2. Same for **join**, in the same file.
3. Over-reach guards, unedited: all 4 tests in `test/lobby_join_error_test.dart` (guard 3 especially), all 4 in `test/lobby_busy_state_test.dart`, every existing test in `test/lobby_create_error_test.dart` including *"plain Exception maps to generic sentence"*.
4. Falsification: remove `case 'unknown':` → tests 1 and 2 fail, everything in 3 passes. Record the output.
5. **⚠️ REQUIRED device check, outcome in the commit body either way:** on a physical iPhone running a **release** build, Wi-Fi and cellular off, tap **CREATE ROOM**; record the sentence on screen and the code `debugPrint` logged. The body must contain `Device check: DONE — sentence "<…>", code "<…>"` or `Device check: NOT RUN — <reason>`. If the device logs a code other than `unknown`, **do not widen the mapping — report it.**

**Blast radius:** `lib/screens/lobby_screen.dart`, `test/lobby_create_error_test.dart`.

---

## 5. AI2 — Correct README and tracker drift (Issue 191 → A)

**What this means for the user.** The first file a contributor reads tells them to run the one command that produces ~678 fake errors, and hard-codes a number that goes stale.

**The gap.** `README.md:62` reads `flutter analyze                 # static analysis — must report 0 errors`. `README.md:151` hard-codes *"of which there are 188"*. `docs/ongoing_general_errors.md` §3 repeats the blockquote beginning `> **The three highest-value things to know from this wave**` twice in a row. (The guide's old §3.1 claim that `submitTargetForgeryGuesses` is undeployed is already removed by this rewrite.)

### 5.1 Implementation
1. `README.md:62` → `flutter analyze lib test        # 0 errors · 0 warnings · infos per docs/agent_execution_guide.md §1 (exits 1 even when clean)`.
2. `README.md:151`: replace `of which there are 188` with `whose current count is in docs/agent_execution_guide.md §1`.
3. Delete the **second** copy of the duplicated blockquote in `docs/ongoing_general_errors.md` §3.

### 5.2 Validation
1. `grep -n "^flutter analyze" README.md` → every match is `flutter analyze lib test`.
2. `grep -c "188" README.md` → `0`.
3. `grep -c "three highest-value things to know from this wave" docs/ongoing_general_errors.md` → `1`.
4. `./scripts/check_playthrough_evidence.sh` (all five) and `./scripts/check_web_e2e_strings.sh` exit 0.

**Blast radius:** `README.md`, `docs/ongoing_general_errors.md`.

---

## 6. AI3 — House Rules chip numbers readable; build the pixel-contrast helper (Issue 179 → A)

**What this means for the user.** A host choosing rounds or a forgery count sees blank cream buttons; only the already-chosen number is visible.

**The gap.** `lib/screens/lobby_screen.dart:557–571` (forgeries) and `:589–603` (rounds) style the label `color: isSelected ? AppColors.ink : AppColors.ivory`. An unselected Material 3 `ChoiceChip` is filled from the colour scheme's `surface`, which is `AppColors.parchment`. Ivory on parchment measured **1.02 : 1** on the SE simulator; the selected chip measured 6.71 : 1.

### 6.1 Implementation
1. At both sites replace the ternary with `color: AppColors.ink,` (ink on parchment = **13.59 : 1**; the selected brass chip already uses ink). Keep `fontWeight: FontWeight.bold`. Change nothing else on the chips (keys `forgeries_$f` and `rounds_$r` stay).
2. Create **`test/helpers/rendered_contrast.dart`**, exporting:
   ```dart
   typedef ContrastSample = ({double ratio, Color background, Color foreground, int foregroundPixels});

   /// Measures the contrast actually painted inside [target]'s rect.
   Future<ContrastSample> measureRenderedContrast(
     WidgetTester tester, GlobalKey rootBoundary, Finder target, {int minPixels = 20, double inflate = 4});
   ```
   Algorithm (the method of `test/contrast_tokens_test.dart:91–137`, generalised to a sub-rect):
   - The test wraps the whole pumped app in `RepaintBoundary(key: rootBoundary, child: …)` and sets `tester.view.physicalSize = const Size(375, 667)` and `tester.view.devicePixelRatio = 1.0` (with `addTearDown(tester.view.reset)`), so logical px = image px.
   - `final image = await tester.runAsync(() => (rootBoundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 1.0));` then `toByteData(format: ui.ImageByteFormat.rawRgba)` under `tester.runAsync`.
   - Rect = `tester.getRect(target).inflate(inflate)`, clamped to the image.
   - Histogram of opaque pixels (alpha ≥ 128) in the rect. **Background** = the modal colour. **Foreground** = among colours with ≥ `minPixels` pixels, the one with the largest |relative luminance − background luminance|. Ratio via `relativeLuminance` / `contrastRatio` from `test/helpers/png_decoder.dart:247–256`.
   - **Fail loudly, never pass vacuously:** if fewer than two colours have ≥ `minPixels` pixels, `fail('measured nothing in <rect>')` (lesson §2.21).
   - Text under `flutter test` renders in the test font as solid glyph boxes in the text's colour — that is what makes the foreground measurable.
3. New test file **`test/house_rules_chip_contrast_test.dart`**. Set-up: host parlour with 3 players, copied from `test/house_rules_panel_test.dart:96–124`, inside `MediaQuery(data: MediaQueryData(accessibleNavigation: true))` (lesson §2.7) and the root `RepaintBoundary`. Scroll the House Rules panel into view. Cases, each at text scale **1.0** and **1.3** (`MediaQueryData(textScaler: TextScaler.linear(1.3))`):
   - For every chip key present — `forgeries_1` … `forgeries_N` and `rounds_1` … `rounds_5` — `measureRenderedContrast(...)` returns `ratio >= 4.5`.
   - Assert that at least one measured chip was selected and at least one unselected (read `tester.widget<ChoiceChip>(find.byKey(...)).selected`) — otherwise the test proves nothing about the defect.

### 6.2 Validation
1. **Falsifying:** revert one unselected label to `AppColors.ivory` → the `rounds_2` case fails with a ratio near **1.02** (record it).
2. **Helper falsification:** point `measureRenderedContrast` at a plain single-colour `Container` → it fails with `measured nothing` (proves the vacuity guard).
3. **Widget-walk trap, recorded:** in the commit body, state that the `contrast_tokens_test.dart:257–281` walk would resolve the dark card behind the chip and pass ivory — which is why the pixel helper exists.
4. Over-reach guards, unedited: all 12 tests in `test/house_rules_panel_test.dart`, `test/contrast_tokens_test.dart`.
5. **Device check (REQUIRED):** iPhone SE (3rd gen) simulator, host parlour at text size 1.0 and at maximum (clamped 1.3): every chip shows its number. Screenshot both.

**Blast radius:** `lib/screens/lobby_screen.dart`, `test/helpers/rendered_contrast.dart` (new), `test/house_rules_chip_contrast_test.dart` (new), `docs/design_ui_direction.md` (note House Rules chip labels are ink), `docs/ongoing_general_errors.md`.

---

## 7. AI4 — One shared confirmation dialog; readable lobby headings (Issue 181 → A)

**What this means for the user.** The buttons on irreversible actions — leave a game you cannot rejoin, remove a player, end the vote — are dark red on near-black and hard to read.

**The gap.** Six dialogs, five of them with unstyled `TextButton`s whose foreground is `colorScheme.primary` = `AppColors.oxblood` (**1.78 : 1** on `groundRaised`, measured): `lib/screens/phase2_craft.dart:84–106`, `lib/screens/phase3_vote.dart:95–117`, `lib/screens/phase4_reveal.dart:366–388` (three byte-identical in-game leave dialogs), `phase3_vote.dart:253–275` ("End Voting?"), `lib/screens/lobby_screen.dart:169–190` (kick). The sixth, `lobby_screen.dart:116–167` (lobby leave), styles STAY/LEAVE ivory/brass — **but its host label `CLOSE ROOM` is still oxblood** (`:163`). The two lobby headings `'THE GUEST LEDGER'` (`:1056`) and `'Select Character Token'` (`:1094`) use `crimsonColor = theme.colorScheme.primary` (`:1019`) and also measure 1.78 : 1.

### 7.1 Implementation
1. New **`lib/widgets/confirm_dialog.dart`**:
   ```dart
   class GaslightConfirmDialog extends StatelessWidget {
     const GaslightConfirmDialog({super.key, required this.title, required this.body,
         required this.cancelLabel, required this.confirmLabel, required this.onConfirm});
     final String title;
     final String body;
     final String cancelLabel;
     final String confirmLabel;
     /// Receives the dialog's own BuildContext; the caller pops it, exactly as today.
     final void Function(BuildContext dialogContext) onConfirm;
   ```
   `build` returns an `AlertDialog` with `backgroundColor: AppColors.groundRaised`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.brass, width: 1))`, `title: Text(title, style: AppTextStyles.cardHeader.copyWith(color: AppColors.brass))`, `content: Text(body, style: AppTextStyles.bodyIvory)`, and two actions:
   - `TextButton(key: const ValueKey('confirm_dialog_cancel'), onPressed: () => Navigator.of(context).pop(), style: TextButton.styleFrom(minimumSize: const Size(64, 48)), child: Text(cancelLabel, style: AppTextStyles.bodyIvory.copyWith(fontWeight: FontWeight.bold)))` — ivory, **15.36 : 1**.
   - `TextButton(key: const ValueKey('confirm_dialog_confirm'), onPressed: () => onConfirm(context), style: TextButton.styleFrom(minimumSize: const Size(64, 48)), child: Text(confirmLabel, style: AppTextStyles.bodyIvory.copyWith(fontWeight: FontWeight.bold, color: AppColors.brass)))` — brass, **7.41 : 1**.
2. Route all six through it with these strings, verbatim:
   - Lobby leave (`_buildLeaveDialog`): title `isHost ? 'Close this room?' : 'Leave this room?'`; body `isHost ? 'You are the host. Leaving will close the room for everyone.' : "You can rejoin with the room code as long as the game hasn't started."`; cancel `'STAY'`; confirm `isHost ? 'CLOSE ROOM' : 'LEAVE'`. **`onConfirm` keeps the `_isLeaving` latch verbatim**: `if (_isLeaving) return; _isLeaving = true; Navigator.of(ctx).pop(); try { await gs.leaveRoom(); } finally { if (mounted) _isLeaving = false; }` (lesson §2.40 — the reset stays in a `finally`).
   - Kick (`_confirmKick`): `'Remove player?'`; `'Remove ${player.name} from this room? They can rejoin with the room code.'`; `'CANCEL'`; `'REMOVE'`; `onConfirm`: pop, then `await gs.kickPlayer(player.id)`.
   - In-game leave ×3: `'Leave this game?'`; `'Your card and answers will be removed from this round. You cannot rejoin a game in progress.'`; `'STAY'`; `'LEAVE GAME'`; `onConfirm`: pop, then `await gs.leaveRoom()`.
   - End voting: `'End Voting?'`; `'End voting now? Players who have not voted will score nothing on this card, and their vote cannot be cast later.'`; `'CANCEL'`; `'PROCEED'`; `onConfirm`: pop, then `gs.forceAdvance()`.
   Keep each site's surrounding `showDialog` call. Add no new behaviour (no latch on the in-game dialogs — not selected).
3. Headings: change `color: crimsonColor` to `color: AppColors.brass` at `lobby_screen.dart:1056` and `:1094` only. Leave every other `crimsonColor` use (avatar rings, shadows) alone.

### 7.2 Validation
1. Extend **`test/dialog_theme_contrast_test.dart`** with a new test: `showDialog` a `GaslightConfirmDialog` inside the root `RepaintBoundary` at 375 × 667; `measureRenderedContrast` on the title (`>= 3.0`, large text per `design_ui_direction.md:110`), the body (`>= 4.5`), the cancel label (`>= 4.5`) and the confirm label (`>= 4.5`).
2. New **`test/confirm_dialog_routing_test.dart`**: open each of the six dialogs through its real entry point (lobby leave as host and as guest; kick; craft, vote and reveal leave; end voting as host) and assert `find.byType(GaslightConfirmDialog)` finds one, with the exact title string. This is the twin guard — a seventh copy-pasted `AlertDialog` fails it.
3. Headings: in a test of the entry screen at 375 × 667, `measureRenderedContrast(find.text('THE GUEST LEDGER'))` and `(find.text('Select Character Token'))` → each `>= 4.5`.
4. **Falsifying:** (a) set the confirm label colour back to `AppColors.oxblood` in the shared widget → test 1 fails near 1.78; (b) revert one site (e.g. `phase4_reveal.dart`) to its old `AlertDialog` → test 2 fails for that case; (c) revert one heading → test 3 fails.
5. Over-reach guards, unedited: all 9 tests in `test/lobby_leave_test.dart` (including double-tap and leaving two rooms in a row), all 6 in `test/in_game_leave_test.dart`, both in `test/lobby_host_kick_test.dart`, and the existing test in `test/dialog_theme_contrast_test.dart`.
6. **Device check (REQUIRED):** SE simulator: open the in-game leave dialog, the kick dialog, the end-voting dialog, and the lobby leave dialog as host and as guest. Every label is readable; leaving and kicking still work; leaving the lobby twice in a row still works. Screenshots.

**Blast radius:** `lib/widgets/confirm_dialog.dart` (new), `lib/screens/lobby_screen.dart`, `phase2_craft.dart`, `phase3_vote.dart`, `phase4_reveal.dart`, `test/dialog_theme_contrast_test.dart`, `test/confirm_dialog_routing_test.dart` (new), `docs/design_ui_direction.md` (dialogs paragraph near line 110: all confirmations go through `GaslightConfirmDialog`; actions ivory/brass).

---

## 8. AI5 — Vote screen contrast (Issue 182 → A)

**What this means for the user.** Every voter, on every card, has to read the line that names whose card it is — and today it is ink on near-black.

**The gap.** `lib/screens/phase3_vote.dart:420–428` (*"Keep a straight face while the parlor deliberates."*, target view) and `:442–449` (*"One of these is ${targetPlayer.name}'s truth."*, voter view) use `theme.colorScheme.onSurface.withOpacity(0.75)` — ink on the dark ground (measured **1.18 : 1** and **1.81 : 1**). On the parchment option card, `lib/widgets/card_grid.dart:569–575` (`'OPTION ${_toRoman(...)}'`, brass on its brass-tinted fill, **1.77 : 1**) and `:621–625` (`'Tap to choose this one'`, brass on parchment, **2.02 : 1**).

### 8.1 Implementation
1. `phase3_vote.dart:423` and `:445`: `color: AppColors.ivory.withValues(alpha: 0.75)` (**9.41 : 1** on `ground`).
2. `card_grid.dart:574` (`OPTION` label): `color: AppColors.ink.withValues(alpha: 0.7)` (**5.15 : 1** on its fill `brass@0.2` over parchment). Leave the chip's fill and border.
3. `card_grid.dart:623` (cue): `color: AppColors.ink.withValues(alpha: 0.7)` (**5.48 : 1** on parchment). Copy stays `'Tap to choose this one'`, 11 pt, Lora.
4. `docs/design_ui_direction.md:280`: replace *"in `AppColors.brass` at 11 pt"* with *"in `AppColors.ink` at 70 % opacity, 11 pt (5.48 : 1 on parchment; brass measured 2.02 : 1 — Issue 182)"*, and record the `OPTION` label colour the same way.

### 8.2 Validation
1. New **`test/vote_screen_contrast_test.dart`**, root `RepaintBoundary`, 375 × 667, `accessibleNavigation: true`:
   - Target view (local player is the card's target; set-up as in `test/phase3_vote_target_ready_toggle_test.dart`): `measureRenderedContrast(find.text('Keep a straight face while the parlor deliberates.'))` → `>= 4.5`.
   - Voter view with three options and nothing selected (set-up as in `test/vote_tap_cue_test.dart` test 1): `find.textContaining("'s truth.")` → `>= 4.5`; `find.text('Tap to choose this one')` → `>= 4.5`; `find.text('OPTION I')` → `>= 4.5`.
2. **Falsifying:** revert the voter subtitle to `onSurface` → fails near 1.1–1.8; revert the cue to brass → fails near 2.0.
3. Over-reach guards, unedited: all 5 tests in `test/vote_tap_cue_test.dart`, `test/vote_option_truncation_test.dart`, `test/stacked_deck_navigation_test.dart`, `test/guidance_strings_test.dart`, `test/phase3_vote_test.dart`.
4. **Device check (REQUIRED):** SE simulator, both views — subtitles, cue and option label readable. Screenshots.

**Blast radius:** `lib/screens/phase3_vote.dart`, `lib/widgets/card_grid.dart`, `test/vote_screen_contrast_test.dart` (new), `docs/design_ui_direction.md`.

---

## 9. AI6 — A reveal answer stays readable with many voters (Issue 180 → A)

**What this means for the user.** At a full table, the truth everyone found is displayed one letter per line, and the screen logs an overflow.

**The gap.** `lib/screens/phase4_reveal.dart:1226` is a `Row` of `Expanded(answer)` and, at `:1345–1369`, a `Column(VOTES, Wrap(voters))`. A `Row` gives that `Column` unbounded width, so the `Wrap` never wraps: the voter column is `32n − 4` pt plus a 12 pt gap. On a 375-pt phone the card row is **289 pt**, so 7 voters leave the answer 57 pt, 8 leave 25 pt, and 9 leave 0 pt and raise `A RenderFlex overflowed by 7.0 pixels on the right` (reproduced October 10, 10-player room). Rooms hold 10 players (`functions/src/index.ts:726`).

### 9.1 Implementation
1. Wrap the voters `Column` (`:1347`) in `ConstrainedBox(constraints: const BoxConstraints(maxWidth: 92), child: …)`, with the comment `// 3 avatars (28) + 2 gaps (4): the Wrap wraps instead of starving the answer (Issue 180).`
2. Change nothing else: avatar size stays 28, spacing and runSpacing 4, `WrapAlignment.end`, the `VOTES` label as is.

### 9.2 Validation
1. New **`test/reveal_many_voters_test.dart`**: 10 `PlayerState`s; the current card's `votes` give **9 voters** the truth option (build state as in `test/reveal_best_forgery_banner_test.dart:80–130`); pump past the truth flip with `pump(Duration)` (not `pumpAndSettle` — lesson §2.7 if the screen animates). Four cases: 320 × 640 and 375 × 667, text scale 1.0 and 1.3. Each asserts:
   - `tester.takeException()` is `null` (no overflow);
   - `find.descendant(of: <the card>, matching: find.byType(PlayerAvatar))` finds **9** voter avatars (proves the fixture is not vacuous);
   - the answer `Text`'s width is `>= 0.5 ×` the width of the card `Row` that contains the `VOTES` column.
2. **One-voter guard:** with 1 voter, the voters column is narrower than 92 pt; with 9 voters it is exactly 92 pt.
3. **Falsifying:** remove the `ConstrainedBox` → at 375 × 667 the overflow exception appears and the width assertion fails (answer width 0). Record both.
4. Over-reach guards, unedited: `test/phase4_reveal_test.dart`, `test/phase4_reveal_breakdown_test.dart`, `test/reveal_best_forgery_banner_test.dart`, `test/running_rivalries_test.dart`, `test/contrast_tokens_test.dart`.
5. **Device check (REQUIRED):** SE simulator, room with host + `DEBUG: ADD 9 BOTS`. In the October 10 audit the bots' first reveal card drew 9 truth votes. Screenshot that card: the answer wraps as words across full lines, and the voter tokens form rows of at most three.

**Blast radius:** `lib/screens/phase4_reveal.dart`, `test/reveal_many_voters_test.dart` (new).

---

## 10. AI7 — No truncated instructions on a 375-pt phone (Issue 184 → A)

**What this means for the user.** On an iPhone SE the vote button reads "TAP A CARD TO CHOO…" and the unmask heading "REVENGE UNMASKIN…" at the default text size; at 1.3 the game-over rows hide "Fooled by N".

**The gap.** `lib/widgets/shared_ui.dart:307–316`, `:322–331`, `:338–347`: every `PrimaryButton` label is `maxLines: 1, overflow: TextOverflow.ellipsis` (the vote button's text is set at `lib/screens/phase3_vote.dart:592`). `lib/screens/phase4_reveal.dart:987–990`: the unmask heading, `maxLines: 1` + ellipsis. `lib/screens/game_over_screen.dart:664–667`: the stat line, `maxLines: 1` + ellipsis. Contract: `docs/design_ui_direction.md:234` — *"Layouts must still survive 1.3."*

### 10.1 Implementation
1. `PrimaryButton`, all three label sites: replace the `Text(… overflow: TextOverflow.ellipsis, maxLines: 1)` with `FittedBox(fit: BoxFit.scaleDown, child: Text(widget.text, maxLines: 1, softWrap: false, style: <unchanged>))`. In the two `Row` variants keep the `Flexible` and put the `FittedBox` inside it.
2. `phase4_reveal.dart:988`: `maxLines: 1` → `maxLines: 2` (keep the ellipsis as a last resort).
3. `game_over_screen.dart:665`: `maxLines: 1` → `maxLines: 2`.
4. No copy changes.

### 10.2 Validation
1. New **`test/small_phone_truncation_test.dart`**, in the style of `test/highlight_card_truncation_test.dart`. For each of: (a) the vote screen, voter view, nothing selected — string `'TAP A CARD TO CHOOSE'`; (b) the reveal unmask panel while fooled — `'REVENGE UNMASKING!'`; (c) a game-over standings row — `'Fooled 1 · Fooled by 2'` (fixture values) — at 320 × 640 and 375 × 667, text scale 1.0 and 1.3:
   - find the `RenderParagraph` whose text is exactly that string, and assert `didExceedMaxLines == false`;
   - for (a) only, assert the `FittedBox`'s scale (its rendered width ÷ the child's intrinsic width) is `>= 0.6`. **If 320 × 1.3 measures below 0.6, STOP and file it** — that needs a copy change, which was not selected.
2. **Falsifying:** on the current code, (a) and (b) report `didExceedMaxLines == true` at 375 × 1.0 and (c) at 375 × 1.3 (all three observed on the SE simulator). Run the new test before the fix and record the failures.
3. Over-reach guards, unedited: the whole suite — `PrimaryButton` is shared — especially `test/guidance_strings_test.dart`, `test/vote_tap_cue_test.dart`, `test/lobby_busy_state_test.dart`, `test/highlight_card_truncation_test.dart`.
4. **Device check (REQUIRED):** SE simulator at text size 1.0 and at maximum: the vote button, the unmask heading and the game-over stats show in full. Screenshots.

**Blast radius:** `lib/widgets/shared_ui.dart`, `lib/screens/phase4_reveal.dart`, `lib/screens/game_over_screen.dart`, `test/small_phone_truncation_test.dart` (new).

---

## 11. AI8 — Tap targets of at least 44 pt, with accessible names (Issue 187 → A)

**What this means for the user.** The host's remove-player control is a 22-pt dot, the deck dots are 13 pt wide, and VoiceOver reads four icon-only controls as unnamed buttons.

**The gap.** Measured on the SE simulator: kick `kick_<id>` **22 × 22 pt** (`lib/screens/lobby_screen.dart:891–913`: a 22-pt badge `Positioned(top: -4, right: -4)` on a 48-pt avatar inside `Stack(clipBehavior: Clip.none)`); deck dots `stacked_deck_dot_i` **13 × 19 pt** (`lib/widgets/card_grid.dart:401–430`); `stacked_deck_prev_button` / `stacked_deck_next_button` **71 × 30 / 72 × 30 pt** (`:355`, `:439`, padding `vertical: 6`). There is no `Semantics` widget in `lib/`, and `ThematicIcon` has no `semanticLabel`, so the kick badge, the room-code share button (`lib/widgets/room_code_plaque.dart:141–158`), the six avatar-token pickers (`lobby_screen.dart:1103–1106`) and the deck dots have no accessible name.

### 11.1 Implementation
1. **Kick** — Flutter does not hit-test outside a parent's bounds, so the hit box must sit **inside** the 48-pt avatar. Replace the `Positioned(top: -4, right: -4, child: GestureDetector(…))` with:
   `Positioned(top: 0, right: 0, child: Semantics(button: true, label: 'Remove ${player.name}', excludeSemantics: true, child: GestureDetector(key: ValueKey('kick_${player.id}'), behavior: HitTestBehavior.opaque, onTap: () => _confirmKick(context, gs, player), child: SizedBox(width: 44, height: 44, child: Align(alignment: Alignment.topRight, child: Transform.translate(offset: const Offset(4, -4), child: <the existing 22-pt Container, unchanged>))))))`.
   The badge's painted position is identical (it still spans x 30–52, y −4–18 relative to the avatar); the hit box is the avatar's top-right 44 × 44. The `kick_<id>` key stays on the `GestureDetector`.
2. **Share** (`room_code_plaque.dart:141`): wrap the `InkWell` in `Semantics(button: true, label: 'Share room code', excludeSemantics: true, …)`. Size is already 48 × 48.
3. **Avatar tokens** (`lobby_screen.dart:1104`): wrap each `GestureDetector` in `Semantics(button: true, selected: isSelected, label: 'Token ${index + 1} of 6', excludeSemantics: true, …)`. Size is already ≥ 44.
4. **PREV / NEXT** (`card_grid.dart:359`, `:443`): `padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)` → `vertical: 13` (height 30 → 44). Wrap each `InkWell` in `Semantics(button: true, label: 'Previous option' / 'Next option', excludeSemantics: true, …)`. Keys unchanged.
5. **Deck dots** (`card_grid.dart:401–430`): wrap the dots `Row` in `Flexible`; wrap each dot's `GestureDetector` in `Flexible(child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44, maxWidth: 44), child: Semantics(button: true, selected: i == _currentIndex, label: 'Show option ${i + 1} of ${widget.answers.length}', excludeSemantics: true, child: GestureDetector(key: Key('stacked_deck_dot_$i'), behavior: HitTestBehavior.opaque, onTap: () => _goToIndex(i), child: Center(child: <existing AnimatedContainer dot>)))))`. **Bounded deviation, recorded:** each dot slot is 44 pt wide while they fit; with many options (≥ 5 at 375 pt) the slots shrink below 44 pt wide. PREV/NEXT at 44 pt remain the accessible path. Write this into §4 accepted equivalents in the same commit.

### 11.2 Validation
1. New **`test/tap_target_guidelines_test.dart`**, 375 × 667, `final handle = tester.ensureSemantics();` … `handle.dispose();`. Two screens: (a) the host parlour with 3 players (two kick badges visible), (b) the vote screen, voter view, **3 options**. For each:
   `await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));` and `await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));`
2. **Triage rule for anything else the guidelines flag:** the `DEBUG:` buttons (present in tests because `kDebugMode` is true) get `style: TextButton.styleFrom(minimumSize: const Size(64, 44))` — they stay gated (§5). Any other flagged control: fix it to ≥ 44 pt and add a label, or **STOP and file** it.
3. A semantics-label test: `tester.getSemantics(find.byKey(ValueKey('kick_<id>')))` has label `'Remove <name>'`; the share button has `'Share room code'`; the selected token has `'Token 1 of 6'` with the selected flag; PREV/NEXT have `'Previous option'` / `'Next option'`; dot 0 has `'Show option 1 of 3'`.
4. **Falsifying:** (a) shrink the kick `SizedBox` back to 22 → `iOSTapTargetGuideline` fails naming that node; (b) remove the share `Semantics` → `labeledTapTargetGuideline` fails; (c) revert PREV padding to 6 → the vote-screen guideline fails.
5. Over-reach guards, unedited: both tests in `test/lobby_host_kick_test.dart` (key `kick_<id>`), all 4 in `test/stacked_deck_navigation_test.dart` (dot, PREV and NEXT keys; dot taps still jump), `test/room_code_plaque_test.dart`, `test/house_rules_panel_test.dart` test *"non-host Parlor layout fits 360x640 portrait without overflow at scale 1.0 and 1.3"*.
6. **Device check (REQUIRED):** SE simulator. Open the **Accessibility Inspector** app (installed), target the simulator, and hover each of the five controls: each reports the label above. Tap each kick badge near its outer corner and near the avatar centre-right — both open the kick dialog. Screenshots of the Inspector readings.

**Blast radius:** `lib/screens/lobby_screen.dart`, `lib/widgets/card_grid.dart`, `lib/widgets/room_code_plaque.dart`, possibly the `DEBUG:` buttons in four screen files, `test/tap_target_guidelines_test.dart` (new), §4 of this guide.

---

## 12. AI9 — Host settings failures are reported (Issue 186 → A)

**What this means for the user.** A host whose settings change fails sees nothing happen — and if it's the Family-Friendly toggle, the game can start on the deck they thought they'd hidden.

**The gap.** Six call sites fire `gs.updateLobbySettings(...)` with no `await` or `catch`: `lib/screens/lobby_screen.dart:510` (deck), `:568` (forgeries), `:600` (rounds), `:621` (timers), `:670` (seconds), `:709` (the Family-Friendly write-through that keeps the filter and the room's deck in agreement — Issue 106). `lib/services/game_service.dart:624–637` has no `try`; `lib/main.dart` installs no global error handler.

### 12.1 Implementation
1. `enum LobbyAction { create, join, settings }` (`lobby_screen.dart:42`). In `lobbyCallableErrorMessage`:
   - `case 'invalid-argument':` returns the existing create/join sentences for those actions and, for `settings`, **`That house rule can't be set for this table.`**
   - add `case 'permission-denied':` returning **`Only the host can change the house rules.`** for `settings` and **`Something went wrong. Try again.`** for create and join (unchanged behaviour for them).
   - `unauthenticated`, `unavailable`, `deadline-exceeded` and (after AH1) `unknown` stay shared.
2. Add to `_LobbyScreenState`:
   ```dart
   Future<void> _applySetting(Future<void> Function() call) async {
     try {
       await call();
     } catch (e) {
       debugPrint('updateLobbySettings error: $e');
       if (!mounted) return;
       final messenger = ScaffoldMessenger.of(context);
       messenger.clearSnackBars();
       messenger.showSnackBar(SnackBar(content: Text(lobbyCallableErrorMessage(e, action: LobbyAction.settings))));
     }
   }
   ```
3. Route all six sites through it, e.g. `onDeckSelected: (val) => _applySetting(() => gs.updateLobbySettings(selectedDeckId: val))`, `if (selected) { _applySetting(() => gs.updateLobbySettings(totalRounds: r)); }`. Leave `GameService.updateLobbySettings` as is.

### 12.2 Validation
1. New **`test/lobby_settings_error_test.dart`**, host parlour, using `functions.overrideCallable('updateLobbySettings', (_) async => throw FirebaseFunctionsException(code: …, message: 'offline-raw-text'))`. Remember lesson §2.7 (`tester.runAsync` around awaited fakes). For **each** control — a `rounds_3` tap, a forgeries chip tap, the timers switch, the seconds field (fixture with timers enabled, enter `'45'`), the deck carousel (pump 500 ms for its 400 ms debounce), and the Family-Friendly toggle (fixture with a non-family-friendly deck selected) — with code `unavailable`:
   - exactly one SnackBar reading **`Could not reach the parlour. Check your connection and try again.`**;
   - `find.textContaining('offline-raw-text')` finds nothing;
   - `tester.takeException()` is `null` (no uncaught async error).
2. Code cases on one control: `invalid-argument` → `That house rule can't be set for this table.`; `permission-denied` → `Only the host can change the house rules.`; a plain `Exception('x')` → `Something went wrong. Try again.`
3. **Falsifying:** before the change no SnackBar appears and the error escapes uncaught — run test 1 on the parent commit and record the failure.
4. Over-reach guards, unedited: all 12 tests in `test/house_rules_panel_test.dart` (including *"client updateLobbySettings payload omits untouched keys"*), all 8 in `test/lobby_create_error_test.dart`, all 4 in `test/lobby_join_error_test.dart` (guard 3: `internal` stays generic), all 4 in `test/lobby_busy_state_test.dart`, `test/deck_carousel_test.dart`, `test/deck_selection_test.dart`.
5. **Device check (REQUIRED):** SE simulator, host parlour against emulators; stop the emulator process (Ctrl-C), tap a Rounds chip. The SnackBar shows the connection sentence. Record the code `debugPrint` logged (`unknown` is expected on iOS).

**Blast radius:** `lib/screens/lobby_screen.dart`, `test/lobby_settings_error_test.dart` (new), `docs/design_ui_direction.md` (error-surfaces paragraph: settings writes now surface).

---

## 13. AI10 — Auto-rejoin keeps the seat on a transient failure (Issue 183 → A)

**What this means for the user.** Reopen the app on a flaky connection and today you're told your session expired, and automatic seat recovery is gone. After this you're told the truth and offered RETRY.

**The gap.** `lib/services/game_service.dart:319–364`: any exception from the re-bind `joinRoom` lands in the catch at `:353–358`, which removes `seat_token_<room>`, `room_code` and `player_id`. `lib/screens/lobby_screen.dart:196–210` then shows *"Your session expired — please rejoin."* On iOS a dropped connection arrives as `unknown` (AH1).

### 13.1 Implementation
1. **Keep `Future<bool> tryRejoinSession()`** — `test/simulation_test.dart:570–581` asserts `isFalse` and must pass unedited. Add `enum RejoinFailure { none, expired, connection }` and `RejoinFailure get lastRejoinFailure` on `GameService`.
2. In `tryRejoinSession()`: set `none` at the start.
   - No saved room/player → return `false`, `none`.
   - Saved, but the room **or** player document does not exist → remove the three keys, return `false`, `expired`.
   - `joinRoom` throws a `FirebaseFunctionsException` whose `code` is `not-found`, `permission-denied` or `invalid-argument` → remove the three keys (as today), return `false`, `expired`.
   - Any other exception from `joinRoom` (including `unknown`, `unavailable`, `deadline-exceeded`, `unauthenticated`, `internal`, any non-`FirebaseFunctionsException`) → **keep** the keys, return `false`, `connection`.
   - The outer catch (e.g. a Firestore read failing) → keep the keys, return `false`, `connection`.
3. `lobby_screen.dart`: extract the `addPostFrameCallback` body (`:196–210`) into `Future<void> _attemptRejoin()`, called from `initState` and from RETRY. On `false`:
   - `connection` → `SnackBar(content: Text('Could not reach the parlour. Check your connection and try again.'), duration: const Duration(seconds: 10), action: SnackBarAction(label: 'RETRY', onPressed: _attemptRejoin))`;
   - `expired` (and a saved session existed) → the existing `Your session expired — please rejoin.`
   - On `true` → the existing `Rejoined active game session!`

### 13.2 Validation
1. New **`test/rejoin_failure_test.dart`**. Set-up: `SharedPreferences.setMockInitialValues({'room_code': 'ABCD', 'player_id': 'p1', 'seat_token_ABCD': 'tok'})`; a `FakeFirestore` holding room `ABCD` and player `p1`; `functions.overrideCallable('joinRoom', …)`. Service-level cases:
   1. throws `FirebaseFunctionsException(code: 'unknown', …)` → returns `false`, `lastRejoinFailure == connection`, and **all three keys are still present** — the falsifying case;
   2. `unavailable` → same as 1; 3. `unauthenticated` → same; 4. a plain `Exception` → same;
   5. `not-found` → `false`, `expired`, all three keys removed; 6. `permission-denied` → same as 5;
   7. no override (success) → `true`, `none`;
   8. room document absent → `false`, `expired`, keys removed.
2. Widget cases on `LobbyScreen`: `unknown` → SnackBar with the connection sentence and a `RETRY` action; remove the override and tap `RETRY` → `Rejoined active game session!` and `gameService.gameState` is non-null. `not-found` → `Your session expired — please rejoin.`
3. **Falsifying:** run case 1 on the parent commit → the keys are gone and the assertion fails. Record it.
4. Over-reach guards, unedited: `test/simulation_test.dart` (all, especially `:570–581`), and every test that calls `tryRejoinSession()` as set-up (20 files — `grep -rln tryRejoinSession test/`).
5. **Device check (REQUIRED):** SE simulator, emulators running: join a room as a second simulator player or as host, force-quit the app, **stop the emulators**, relaunch → the connection SnackBar with RETRY appears (seat kept). Restart the emulators (they wipe data on restart) and tap RETRY → now `Your session expired — please rejoin.` — that exercises both branches. Screenshots.

**Blast radius:** `lib/services/game_service.dart`, `lib/screens/lobby_screen.dart`, `test/rejoin_failure_test.dart` (new), `docs/design_database_and_security.md` §5 (seat recovery: transient failures keep the saved seat).

---

## 14. AI11 — Error reasons from the server; one client mapper (Issue 185 → A)

**What this means for the user.** A guess that lands as the countdown ends is told "That guess is already locked in." After this it says the window closed — and errors are mapped on codes, never on message text (§5 invariant).

**The gap.** `lib/screens/phase4_reveal.dart:1104–1114` chooses its sentence with `e.toString().contains('already submitted') || e.toString().contains('failed-precondition')`, but `submitUnmaskGuess` throws `failed-precondition` for six reasons, including `"Unmask guess deadline has passed or is inactive."` (`functions/src/index.ts:2514`). `lib/screens/phase2_craft.dart:186–189` matches `'similar'` / `'Similarity'`; the server's similarity rejection is `invalid-argument` (`index.ts:975`), the same code as its other `invalid-argument`s.

### 14.1 Implementation
1. **Server, additive** (`functions/src/index.ts`; keep the message strings byte-identical — 1.1.0 (8) still matches on them):
   - `:2514` → `throw new HttpsError("failed-precondition", "Unmask guess deadline has passed or is inactive.", { reason: "deadline_passed" });`
   - `:2557` → `throw new HttpsError("failed-precondition", "Player has already submitted an unmask guess.", { reason: "already_submitted" });`
   - `:975` → `throw new HttpsError("invalid-argument", "Answer is too similar to another player's answer!", { reason: "too_similar" });`
2. **Test helper, additive:** `callFn` in `functions/test/game_e2e.spec.ts` copies only `message` and `status` into the thrown error. Add `(err as any).details = json.error.details;` next to the `status` line. Without this no test can see `details`.
3. **Client:** new `lib/utils/callable_error_message.dart`:
   ```dart
   enum GameAction { unmaskGuess, submitAnswer }
   String gameCallableErrorMessage(Object error, {required GameAction action})
   ```
   `reason` = `error.details['reason']` when `error is FirebaseFunctionsException && error.details is Map`, else `null`.
   - `unmaskGuess` + `failed-precondition` + `deadline_passed` → **`The guessing window has closed.`**
   - `unmaskGuess` + `failed-precondition` + `already_submitted` → **`That guess is already locked in.`**
   - `submitAnswer` + `invalid-argument` + `too_similar` → **`Too similar to an existing answer! Be more creative.`**
   - everything else, including non-`FirebaseFunctionsException` errors and missing `details` → **`Something went wrong. Try again.`**
4. `phase4_reveal.dart:1108–1110`: `final msg = gameCallableErrorMessage(e, action: GameAction.unmaskGuess);`. `phase2_craft.dart:186–190`: `final msg = gameCallableErrorMessage(e, action: GameAction.submitAnswer);`. Keep the craft screen's local similarity pre-check (`:149–173`) unchanged.
5. After this item, `grep -rn "toString().contains" lib/` returns only `lib/theme/app_icons.dart:627` (the test-binding check, unrelated).
6. Deploy per §0.8, after the commit.

### 14.2 Validation
1. **Emulator suite** (`functions/test/game_e2e.spec.ts`), three new cases: (a) `submitUnmaskGuess` after the deadline → `err.status === 'FAILED_PRECONDITION'`, `err.details.reason === 'deadline_passed'`, and `err.message === 'Unmask guess deadline has passed or is inactive.'`; (b) a second guess → `'already_submitted'`, message unchanged; (c) a too-similar `submitAnswer` → `'INVALID_ARGUMENT'`, `'too_similar'`, message unchanged. The unchanged-message assertions are the 1.1.0 (8) compatibility guard. Count goes 164 → 167.
2. **Dart unit test** `test/callable_error_message_test.dart`: a table of (action, code, details, expected) covering the three mapped cases, a mapped code with `details: null`, `details` not a `Map`, an unknown reason, and a plain `Exception`.
3. **Widget tests:** reveal — `overrideCallable('submitUnmaskGuess')` throws `FirebaseFunctionsException(code: 'failed-precondition', message: 'Unmask guess deadline has passed or is inactive.', details: {'reason': 'deadline_passed'})` → SnackBar `The guessing window has closed.`; craft — `submitAnswer` throws `invalid-argument` with `details: {'reason': 'too_similar'}`, for text that passes the local pre-check → `Too similar to an existing answer! Be more creative.`
4. **Falsifying:** with the old reveal code, the deadline case shows `That guess is already locked in.` — run the widget test on the parent commit and record it. Remove the `details` line from `callFn` → emulator cases (a)–(c) fail.
5. Over-reach guards, unedited: every existing unmask and submit test in both suites; `test/phase2_craft_test.dart` and `test/ui_e2e_test.dart` (similarity paths).
6. **Deploy check (REQUIRED):** after deploying, `check_deploy_fresh.sh` exit 0 and `CLEANUP_DRY_RUN=false` read back from the new `cleanupdaily` revision — paste both into the commit body or a follow-up docs commit.
7. **Device check (REQUIRED):** SE simulator against emulators: as a fooled voter, let the unmask countdown reach 0 and tap an accusation as it expires → `The guessing window has closed.` (if the button disables first, record `Device check: NOT RUN — button disabled before deadline`, not a failure).

**Blast radius:** `functions/src/index.ts`, `functions/test/game_e2e.spec.ts`, `lib/utils/callable_error_message.dart` (new), `lib/screens/phase4_reveal.dart`, `lib/screens/phase2_craft.dart`, `test/callable_error_message_test.dart` (new), the two widget-test files, `docs/design_ui_direction.md` (error surfaces), `docs/design_database_and_security.md` (callable table: the three `details.reason` values).

---

## 15. AI12 — Migrate the deprecated APIs (Issue 190 → A)

**What this means for the user.** Nothing visible. It removes compile errors-in-waiting before an upgrade forces them at a bad moment.

**The gap.** 16 `deprecated_member_use` infos besides the 139 `withOpacity` (whose migration was rejected as 139 C — leave those alone): `lib/screens/game_over_screen.dart:125` (`Share`, `shareXFiles`), `lib/widgets/room_code_plaque.dart:144` (`Share`, `share`), `lib/screens/lobby_screen.dart:617` and `:691` (`activeColor`), `lib/screens/game_over_screen.dart:1174` and `lib/screens/lobby_screen.dart:1108` (`Matrix4.scale`), `lib/screens/lobby_screen.dart:1122` (`Color.value` × 2), `test/raven_mascot_test.dart:47` and `:195` (`Color.red/green/blue` × 3 each). Line numbers shift after earlier items — find them with `flutter analyze lib test | grep deprecated_member_use | grep -v withOpacity`.

### 15.1 Implementation
1. `game_over_screen.dart`: `await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], text: 'Just finished a match of Gaslight! Check out the night\'s honors.'));`
2. `room_code_plaque.dart`: `SharePlus.instance.share(ShareParams(text: 'Join my Gaslight game! Room code: ${widget.code}'));`
3. Both `activeColor: AppColors.brass` → `activeThumbColor: AppColors.brass`.
4. `Matrix4.identity()..scale(x)` → `Matrix4.identity()..scaleByDouble(x, x, x, 1.0)` at both sites (vector_math 2.2.0 `matrix4.dart:938`; `scale(x)` with one argument scales x, y, z by x and leaves w).
5. `crimsonColor.value` → `crimsonColor.toARGB32()`; `Colors.grey.shade700.value` → `Colors.grey.shade700.toARGB32()`.
6. `test/raven_mascot_test.dart:47`, `:195`: `AppColors.ground.red` → `(AppColors.ground.r * 255.0).round().clamp(0, 255)`, likewise `.green` → `.g`, `.blue` → `.b` (the formula the deprecation message gives).
7. Update §1 of this guide: **172 infos**. (README points here after AI2.)

### 15.2 Validation
1. `flutter analyze lib test` → **0 errors · 0 warnings · 172 infos**, exit 1; `flutter analyze lib test | grep deprecated_member_use | grep -vc withOpacity` → `0`; `… | grep -c withOpacity` → `139`.
2. `flutter test` → all passing (`test/raven_mascot_test.dart` T3.3 still asserts ≥ 4.5 : 1 with the same number).
3. **Falsifying (analyzer):** the info count before is 188; record before and after.
4. **Device check (REQUIRED — the share paths changed API):** SE simulator: tap the room-code envelope → the iOS share sheet opens with `Join my Gaslight game! Room code: XXXX`; finish a game → `Share Case File` → share sheet with the PNG and text. The Family-Friendly and timer switches still show a brass thumb when on; the selected avatar token still scales up. Screenshots.

**Blast radius:** `lib/screens/game_over_screen.dart`, `lib/widgets/room_code_plaque.dart`, `lib/screens/lobby_screen.dart`, `test/raven_mascot_test.dart`, this guide's §1.

---

## 16. AI13 — iPhone-only for the first App Store release (Issue 188 → A)

**What this means for the user.** Gaslight ships as the iPhone game it was designed and tested as. iPad users get the iPhone app in compatibility mode. Adding iPad later is allowed; removing it after an iPad-capable App Store release is not.

**The gap.** `ios/Runner.xcodeproj/project.pbxproj` sets `TARGETED_DEVICE_FAMILY = "1,2";` in the three Runner build configurations (lines 458, 586, 637 before AI1; find them with `grep -n TARGETED_DEVICE_FAMILY`). On iPad the parlour is the phone layout stretched to 1032 pt, and landscape/resizing were never verifiable (no rotation on this Xcode).

### 16.1 Implementation
1. Change all three to `TARGETED_DEVICE_FAMILY = 1;`, editing the file as text (§0.10).
2. Leave `UISupportedInterfaceOrientations~ipad` in `ios/Runner/Info.plist` — an iPhone-only binary ignores it. Do not touch `lib/main.dart`'s orientation lock.

### 16.2 Validation
1. `grep -c 'TARGETED_DEVICE_FAMILY = "1,2"' ios/Runner.xcodeproj/project.pbxproj` → `0`; `grep -c 'TARGETED_DEVICE_FAMILY = 1;'` → `3`.
2. **Falsifying (built artefact):** `flutter build ios --release --no-codesign`, then `/usr/libexec/PlistBuddy -c "Print :UIDeviceFamily" build/ios/iphoneos/Runner.app/Info.plist` → only `1` (before the change it prints `1` and `2` — record both).
3. **Device check (REQUIRED):** run on the iPad Pro 13" (iOS 26.5) simulator → the app opens in iPhone compatibility mode, title screen intact. Screenshot.
4. Full battery, including the ninth gate.

**Blast radius:** `ios/Runner.xcodeproj/project.pbxproj`, `README.md` → Releasing (note: no iPad screenshots needed), `docs/design_ui_direction.md` (record the iPhone-only decision).

---

## 17. AI14 — Investigate the coverage collector (Issue 189 → B)

**What this means for the user.** Nothing visible. It tries to restore a trustworthy way to see which code no test runs.

**The gap.** On Flutter 3.44.6: the full-suite `flutter test --coverage` segfaults the runner (24× in one run; also with `--concurrency=1`) and never exits; run file by file, 13 of 73 files still segfault (`ember_backdrop_reduce_motion`, `gaslight_route`, `phase4_header_overflow`, `phase4_reveal`, `raven_mascot`, `reduce_motion`, `room_code_plaque`, `scoring_logic`, `stacked_deck_navigation`, `text_similarity`, `vote_option_truncation`, `waiting_indicator`, `wax_seal_badge`); in the 60 that finish, `lib/services/game_service.dart` appears in one LCOV file with 0 hits although nearly every widget test drives it. One hypothesis is already falsified: switching `test/simulation_test.dart`'s relative `../lib/` imports to `package:` did not bring `game_service.dart` back.

### 17.1 Implementation — time-boxed to 2 hours of active work; no change to `lib/`, existing tests, `pubspec.yaml` or `pubspec.lock`
1. **Work in a scratch export** (`git archive HEAD | tar -x -C <scratch>`), never in the repo — running a different Flutter SDK rewrites `.dart_tool` and possibly `pubspec.lock`.
2. **Reproduce the crash** on the smallest crasher: `flutter test --coverage --coverage-path=<scratch>/x.info test/wax_seal_badge_test.dart`, 5 runs, each in the background with a 120 s kill (macOS has no `timeout`). Record the crash rate. Control: the same file without `--coverage`, 5 runs → expect 5/5 pass.
3. **Reproduce the missing library:** `flutter test --coverage test/lobby_create_error_test.dart`; `grep -c "SF:.*lib/services/game_service.dart"` on the LCOV → expect `0`. **Positive control:** the same LCOV contains `SF:lib/screens/lobby_screen.dart` (it did on October 10) — an absence means nothing without it (lesson §2.44).
4. **Collector flags**, one at a time, on both reproductions: `--coverage-package=gaslight`, `--branch-coverage`, `--concurrency=1`, `--no-pub`. Record the effect of each.
5. **Next Flutter stable, side by side:** `PATH="/usr/bin:$PATH" git clone --depth 1 --branch <latest stable tag> https://github.com/flutter/flutter.git <scratch>/flutter-next`, then run steps 2–3 with `<scratch>/flutter-next/bin/flutter`.
6. **Minimal repro:** if it reproduces in a fresh `flutter create` sample with one widget test, it is a Flutter bug. Draft an upstream issue in the tracker, but **do not post it** — posting is outward-facing, so ask the user.

### 17.2 Validation and deliverable
1. A findings entry in `docs/ongoing_general_errors.md` §1. For every claim: the exact command, the number of runs, and the outcome; and a positive control for every "absent" claim.
2. **Outcomes, exactly one:**
   - (a) A command that works on 3.44.6 → add it to §1 of this guide as **informational, never a gate** (lesson §2.30), with per-file numbers for `lib/services` and `lib/screens`.
   - (b) It works only on a newer Flutter → **STOP and file** a new issue with options (a project-wide SDK upgrade is the user's decision).
   - (c) Nothing works → add one line to §1: *"Coverage is not collectable on Flutter 3.44.6 (runner segfault; `game_service.dart` missing from LCOV) — see Issue 189 findings."*
3. `git status --porcelain` in the repo shows only docs changed.

**Blast radius:** `docs/ongoing_general_errors.md`, this guide's §1. Nothing in `lib/`, `test/`, `functions/` or `pubspec.*`.

---

## 18. Already delivered — do NOT rework

### Wave AG — verified October 3, 2026

| Item | What shipped | How it was verified |
|---|---|---|
| **AG1** | `lobbyCallableErrorMessage(error, action:)` shared by create and join; no raw exception reaches a player anywhere in `lib/`. | Restoring `'Error: $e'` fails 5 create tests. **Gap → AH1 (§4).** |
| **AG2** | Point chip headers in ivory, exact `Name: ±N` format kept; collapsed ternary removed. | Fails at 1.84 : 1 on the rendered ratio walk alone. |
| **AG3** (Issue 177 → B) | `ParlourLedger` on both waiting screens; one-line `thisCard` teaser on the reveal; additive `occurrences` + `thisCard` on the server. | 4 falsifications. Worst-case payload 18,013 bytes. Observed rendering correctly on the SE simulator on October 10. |

### Wave AA — sixteen items, verified September 11, 2026

Full index in `ongoing_general_errors.md` §3; durable contracts in the design docs.

| Items | What shipped |
|---|---|
| **AA1–AA6** (155, 156, 157, 154, 166, 158) | Craft screen: dealt-card overlay **deleted**; tap-away dismisses the keyboard; the focused field scrolls above the keyboard; a live `n/100` counter that **does not cap**; sentence stems for **150/150** prompts; the waiting screen recaps your own submitted answer. |
| **AA7–AA9** (153, 161, 159) | Room-code field hardened; the target's ready is a **server-driven toggle**; the best-forgery banner is suppressed below 2 votes and on ties. |
| **AA10–AA11** (163, 169) | Per-round score multiplier; itemised `scoreBreakdown` through all three flush sites; manual scoring copy rewritten. |
| **AA12–AA14** (164, 167, 168) | In-game manual button; standings above honors under `FINAL RESULTS`; highlight titles own the full card width. |
| **AA15 + Issue 160** | Treatment 3 (stacked deck) vote options with PREV/NEXT, swipe, and jump dots. |
| **AA16a + AA16b** (162) | `submitTargetForgeryGuesses` callable (deployed — 19 functions, read October 10); `+1` per correct attribution; tap-to-assign chip row. |

### Earlier waves

- **Wave Z (152)** leave latch reset in a `finally` — lesson §2.40. Leaving two rooms in a row re-verified on the SE simulator October 10.
- **Y1 (151)** runtime version label · **Y2 (149)** · **X1 (147)** · **X2 (148)** · **W1 (146)** · **W2 (145)** · **V1 (143, 144)** · **U1–U5**, **S1**, **R0–R2**, soak blocks **E22–E49**, Waves **Q/P/O**, Issues **96–105, 50–95, 31, 28/29**.
- Seat recovery after force-quit and Reduce Motion (particle layer omitted) re-verified on the SE simulator October 10.

**Release plumbing:** bundle ID `com.whylabs.gaslight` · `CFBundleDisplayName` **`Gaslight`** · `ITSAppUsesNonExemptEncryption` **`false`** · iOS target **15.0** · Node **22** · build **1.1.0 (8)** on TestFlight.

### Accepted equivalents — do NOT "fix" these back

- **The target's attribution UI is a separate chip row, not an interactive option grid.** O9 passes unedited — do not make the grid interactive.
- **AA16b enforces one-player-per-option on the client**; the server remains permissive. Keep both halves.
- **AA5 ships one stem list per prompt with phase-dependent framing** (`design_prompt_system.md` §6).
- **AA8 added a phase guard to `setReady`** beyond its item's scope — correct and contained.
- **`GameService.kMissingAnswerPlaceholder` is declared and never referenced** — leave it.
- **Waves Y1, Z1 and AA bumped `pubspec.yaml` inside their own commits.**
- **`EmberBackdrop` and `AnimatedThinkingBackground` both keep `..repeat()` in `initState`.**
- **E48 merged two artefacts** · **`r0_u2_p3_reduce_motion.png` is logged under E49** · **P4's Option B deferral**.
- **`use_build_context_synchronously` × 4** (`lobby_screen.dart:982–986`, `phase4_reveal.dart:1111`) guard `State.context` with `context.mounted` — equivalent to `mounted`; a lint quirk, not a defect.
- **`marionette_flutter` is in `dependencies`, not `dev_dependencies`** — it is tree-shaken from release (0 strings in the 1.1.0 (8) binary) and has no native code.

---

## 19. Invariants & intentional decisions — do NOT change

- **The seven `DEBUG:` buttons stay in the source, gated** (AI8 may give them a 44-pt minimum height; that is not removal).
- **`PrivacyInfo.xcprivacy` stays in the Runner target**; `NSPrivacyAccessedAPITypes` stays empty (re-checked in AI1).
- **The 1024 icon must have no alpha and no pre-rounded corners.**
- **`playerId` is NOT a credential.** A re-bind needs ownership, a `seatToken`, or a stale seat.
- **`allow get` and `allow list` are split on `/rooms`.** **`sealed` and `embeddings` are default-deny by having no `match` block.**
- **`votes` stores opaque option UUIDs during the vote phase.** **Never send other players' authorship to the client** before the unmask window closes.
- **Never let a client bound exceed the server's.** **The presence window gates the ACTION, not the caller.**
- **`pendingScoreDeltas` is flushed at three sites.** **The option id is the authority; text is the fallback.**
- **The readiness gate exempts the host deliberately** (`!== true`). **The 3-player floor applies in play as well as at start.**
- **Error surfaces match on `e.code` (and, after AI11, `e.details['reason']`), never on the message.**
- **Phase order is truth → forgery → vote → reveal.** **`ROOM_TTL_MS` is 8 hours.** **`predeploy` stays.** **Timers default OFF.**
- **Heartbeat 30 s** against a 10-minute server window and a 60 s client check. **`DEFAULT_AUTH_RETENTION_MS` is 24 hours** and must exceed `ROOM_TTL_MS`.
- **The cleanup's staleness timestamp is `Math.max(lastRefresh, lastSignIn, creation)`.** **The nightly orphan sweep is retained.** **`CLEANUP_DRY_RUN=false` is revision-scoped** — re-apply after every functions deploy.
- **`AppMotion.reduce` keeps the `accessibleNavigation` OR term** and reads `platformDispatcher.accessibilityFeatures.reduceMotion`.
- **The title-screen version is read from the bundle at runtime.** **`main.dart`'s bootstrap is load-bearing** — nothing added there may throw.
- **`LobbyScreen` renders entry screen and parlour from one `State`** — any flag on it outlives every room (Issue 152).
- **`lastReaction` / `lastReactionAt` are deliberately retained dead fields.** **`lib/utils/prompt_decks.dart` is generated** — never hand-edit.
- **Colour tokens name a SURFACE, not a role.** `colorScheme.primary` is oxblood (1.78 : 1 on `groundRaised`) and `onSurface` is ink — never text on the dark ground. **Text on the dark ground is ivory** (16.25 : 1); **brass** (7.41–7.84 : 1) is an accent **for the dark ground** — on parchment it is 2.02 : 1. **Text on parchment is ink.**
- **Never render an exception object to a player.** **Create and join share one mapping**; after AH1 `unknown` belongs to the connection sentence.
- **The web E2E string contract (Wave AE)**, **Wave AB** (guess points after the multiplier; rivalries only from public authorship; thresholds 1 vs 2) and **Wave AA** (`trailingSlots`, `validateDeckStems` throws, stems never inserted, `scoring_logic.dart` is a test-only mirror, target maps `optionId → guessedAuthorId`, balance knobs, breakdown sums) invariants stand as recorded in the design docs.
- **Never accept Xcode's "Update to recommended settings" dialog.**
- **After AI4: every confirmation dialog goes through `GaslightConfirmDialog`.** **After AI1: there is no CocoaPods** — do not reintroduce a `Podfile`.

**Assessed and rejected — do NOT re-propose** (see the September guides and the tracker §3): room codes from `Math.random()`; `authUid` exposure; the 133 B/C closes; 128 B; 130 B; 135 B; 136; 137 B; 138 A/C; 140 B/C; 141 B/C; 142 B/C; **migrating `withOpacity` → `withValues` (139 C)**; 143 B/C; 145 B/C; 146 B/C; 147 B/C; 148 B/C; 149 B/C; 150 A/B/C; 151 B/C; 152 B/C; and every September 8 rejection (153 B/C through 169 B/C). **October 10 rejections:** 178 A (Podfile pin) and C (old Xcode); 179 B; 180 B and C; 181 B; 182 B; 183 B; 184 B; 185 B; 186 B; 187 B; 188 B and C; 189 A; 190 B.

**There is no chat or emote feature.** Distinct from the reaction feature removed in Issue 74.

---

## 20. Where the contracts live

| What | Where |
|---|---|
| Open queue, selections, lessons, resolved index | `docs/ongoing_general_errors.md` |
| Release runbook | `README.md` → Releasing |
| Playthrough material | `docs/playthroughs/` |
| Rules, seat tokens, presence, retention, cleanup, callable table | `docs/design_database_and_security.md` |
| `votes` contract, phases, 3-player floor | `docs/design_game_state_and_models.md` |
| Scoring, reveal beats, delta withholding, unmask close | `docs/design_scoring_and_ui.md` |
| Palette, typography, dialogs, error surfaces, header sizing, stacked deck | `docs/design_ui_direction.md` |
| Decks, re-roll exclusion, stems | `docs/design_prompt_system.md` |
| Pixel-measured contrast (after AI3) | `test/helpers/rendered_contrast.dart` |

---

## 21. Validation standard

**Measure rendered contrast from pixels.** A widget-tree walk resolves the nearest decorated ancestor and cannot see a Material component's own fill — it would have passed Issue 179's invisible chips at 1.02 : 1 (October 10).

**Prove a platform behaviour on the real toolchain before specifying the fix.** AI1 was verified on a scratch export before it was written down; AH1's chain was traced through vendored source (lesson §2.45).

**An "already fixed" twin can be half-fixed.** The lobby leave dialog was the styled one — and its `CLOSE ROOM` label was still oxblood. Check every branch of the twin you are copying from.

**A guard flag lives as long as the object holding it** — reset it in a `finally` (lesson §2.40). **Write the test for the journey, not the defence.** **A test that reconstructs the world hides state bugs.**

**Analyze ≠ compile.** **A checker's exemption list is a map of where its guarantees stop.** **A test can prove a widget is in the tree; it cannot prove a person can find it.**

**A prediction followed by a matching outcome beats either alone.** **Re-run every gate yourself before trusting a table.** **Falsify every guard.** **Open the artefact and ask what it shows.** **Read exit codes bare.**

---

## THE LOOP

```
(1) A selection exists for every item in §2 (Oct 10, 2026). Take the next step
    in §2 order. Never fill in or edit a `Your selection:` line.
(2) "Implemented to spec" and "fixed the problem" are different claims. Check
    the second against the ORIGINAL REPORT in the tracker, not the spec.
(3) If a fix depends on how a platform or library behaves, read the vendored
    source or prove it on the real toolchain first.
(4) A load-bearing check is REQUIRED, and its outcome goes in the commit body
    either way: DONE with the result, or NOT RUN with the reason.
(5) An EMPTY result is not evidence until the same query has been seen to
    return something. Never use `timeout` on macOS.
(6) zsh does not word-split unquoted variables; an unmatched glob aborts the
    command. Use `while IFS= read -r` or bash for loops over files.
(7) A falsification that fails to COMPILE proves nothing.
(8) A fix applied to one of two twins is half a fix. Fix siblings through ONE
    shared path (AI4: six dialogs, one widget).
(9) A test is only as wide as what it walks; assert that you inspected the
    parts that matter (non-vacuity counts in AI3, AI6).
(10) COLOUR: tokens name a SURFACE. Ivory on ground, ink on parchment, brass
     only on the dark ground. Measure from pixels.
(11) Never show an exception object to a player. Map e.code (+ details.reason).
(12) A rename broke a test? UPDATE THE ASSERTION, never the production code.
(13) Server changes the shipped client reads must be ADDITIVE (1.1.0 (8)).
(14) Read exit codes BARE.
(15) RE-RUN THE FULL BATTERY — all eight gates bare, plus the iOS release
     build once AI1 lands; analyze bar 0/0/188 (172 after AI12).
(16) COMMIT: ONE ITEM, ONE Conventional Commit, WHY + Falsification + Device
     check in the body; tracker updated in the same commit.
```

## Definition of Done for this wave

- [ ] AI1 … AI14 and AH1 each committed separately, in §2 order (AI14 may run in parallel after AI1).
- [ ] Each commit body has `Falsification:` output and a `Device check:` line (DONE or NOT RUN with reason).
- [ ] All eight §1 gates green bare, the iOS release build exits 0, analyze at **0 / 0 / 172**, functions tests at **167**, `check_deploy_fresh.sh` FRESH after AI11's deploy, `CLEANUP_DRY_RUN=false` read back.
- [ ] Issues 178–191 moved to the tracker's §3 index with one row each; design docs updated as each item's blast radius lists.
- [ ] §1 of this guide re-measured and rewritten as the new baseline.

**When the last item is done the queue is empty. Do not invent work.** The only legitimate triggers for further action are: a new user selection, a §1 gate going red (investigate and file), or a user report.
