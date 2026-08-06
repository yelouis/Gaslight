# Active Build Queue — Queue Complete (August 6, 2026)

All six issues in the active build queue (**Issues 23, 24, 25, 26, 27, 28**) have been successfully implemented, verified with unit and widget tests, and documented in `docs/ongoing_general_errors.md`.

---

## 🟢 Delivered Queue Summary

1. **Issue 23 — Hybrid Icon System (Option B)**:
   - Integrated `phosphoricons_flutter` package.
   - Updated `lib/theme/app_icons.dart` to route 11 functional icons (`writing`, `redraw`, `timer`, `secret`, `ledger`, `envelope`, `observe`, `confirm`, `sound`, `mute`, `host`) to `PhosphorIconsLight` glyphs while retaining hand-painted custom painters for 6 character sigils (`flame`, `moth`, `key`, `raven`, `moon`, `hourglass`).
   - Verified by `test/thematic_icon_test.dart`.

2. **Issue 25 & Issue 27 — Parlor House Rules Consolidation (Option A & C)**:
   - Offloaded house rules pre-creation settings off the entry form; default `createRoom` uses `sabotageAnswersCount: 2`.
   - Consolidated House Rules into a single inline panel in the Parlor (`lib/screens/lobby_screen.dart`), removing the duplicate `HouseRulesDialog` modal.
   - Extended Forgery Rounds selection to range `[1, 2, 3, 4, 5]` using a `Wrap` layout.
   - Added non-host read-only gating (`IgnorePointer`, `0.5` opacity, and caption `Only the host can modify house rules.`) so all guests can view active game rules.
   - Verified by `test/house_rules_dialog_test.dart`.

3. **Issue 24 — Entry Form Fits Viewport (Option A)**:
   - Relocated pre-creation settings off the entry form and compressed the vertical rhythm in `lib/screens/lobby_screen.dart` to a tight 6/8/12/16/20 spacing scale.
   - Added a logo size breakpoint when `maxHeight < 700` dp, scaling `AnimatedLobbyLogo` into a 60 dp box.
   - Reclaimed >300 dp of vertical height so room code input and "JOIN ROOM" fit above the fold at 360×640 portrait (`maxScrollExtent == 0.0`), while preserving `SingleChildScrollView` as an overflow safety net for 1.3 accessibility text scaling.
   - Verified by `test/lobby_entry_test.dart`.

4. **Issue 26 — Draggable Roster Sheet (Option C)**:
   - Added `DraggableScrollableController` (`_sheetController`) to `_LobbyScreenState` in `lib/screens/lobby_screen.dart` with `snap: true` (`[0.25, 0.4, 0.7]`).
   - Wrapped the header block in a `GestureDetector(behavior: HitTestBehavior.opaque)` handling drag deltas and velocity snaps, plus tap-to-toggle between expanded (`0.7`) and collapsed (`0.25`).
   - Added `physics: const AlwaysScrollableScrollPhysics()` to the roster `GridView` so 1-player short rosters hand drags to the sheet.
   - Verified by `test/lobby_parlor_sheet_test.dart`.

5. **Issue 28 — Icon Dependency Compatibility (Option B)**:
   - Recorded `phosphoricons_flutter: ^1.0.0` as an accepted equivalent due to `phosphor_flutter: ^2.1.0` `IconData` final class SDK compilation errors.
   - Verified across full test battery.

---

## 🧪 Verification Battery

- `flutter analyze lib test`: **0 errors** (276 issues / warnings/infos)
- `flutter test`: **60/60 pass**
- `npm --prefix functions run build`: **TypeScript build clean**
- `npm --prefix functions test`: **28/28 pass on emulator**
- `flutter build ios --simulator --debug`: **Succeeded (`Runner.app` built)**
