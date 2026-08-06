# Active Build Queue — Queue Complete (August 6, 2026)

All four items in the active build queue (**Issue 30, Task T1, Issue 29, Task T2**) have been successfully implemented, verified with unit and widget tests, and documented in `docs/ongoing_general_errors.md`.

---

## 🟢 Delivered Queue Summary

1. **Issue 30 — Hide `Family-Friendly Decks Only` from non-hosts (Option A)** (`c88a043`):
   - Moved `Family-Friendly Decks Only` `SwitchListTile` out of the `IgnorePointer` house rules block in `lib/screens/lobby_screen.dart` and wrapped it in `if (isHost)`.
   - Preserved its client-local `setState` deck filtering behavior for the host's `DeckCarousel` without syncing to `GameState`.
   - Added 3 test cases in `test/house_rules_panel_test.dart` including non-host over-reach guards.

2. **Task T1 — Close Issue 27 test-coverage gap** (`107b8e8`):
   - Renamed `test/house_rules_dialog_test.dart` to `test/house_rules_panel_test.dart` via `git mv`.
   - Added Case A assertion verifying the Parlor `AppBar` contains exactly 1 `IconButton` (sound toggle).
   - Added Case B assertion verifying non-host Parlor layout fits 360×640 portrait at text scales 1.0 and 1.3 without RenderFlex exceptions.
   - Tested non-vacuousness by temporarily breaking each guarded behavior and observing test failures.

3. **Issue 29 — Vendor 11 Phosphor glyphs & drop dependency (Option B)** (`3f987bf`):
   - Vendored `Phosphor-Light.ttf` (524 KB) and its MIT `LICENSE` under `assets/fonts/phosphor/`.
   - Declared `PhosphorLight` font family in `pubspec.yaml` and mapped the 11 functional icons directly in `lib/theme/app_icons.dart` via `const IconData(..., fontFamily: 'PhosphorLight')` without `fontPackage`.
   - Removed `phosphoricons_flutter` package dependency, eliminating ~2.43 MB of unused font weights (`Bold`, `Duotone`, `Fill`, `Thin`, `Regular`) from the app bundle.
   - Updated `test/thematic_icon_test.dart` to assert `fontPackage` is `null` for first-party assets.
   - Updated `docs/design_ui_direction.md` §8 SHIPPED STATE.

4. **Task T2 — Drop unused `cupertino_icons` dependency** (`1ab50ba`):
   - Re-verified 0 references to `CupertinoIcons` or `package:flutter/cupertino.dart` across `lib/` and `test/`.
   - Removed `cupertino_icons` from `pubspec.yaml` along with orphaned template comments.
   - Recovered ~252 KB of unused `CupertinoIcons.ttf` font asset from the app bundle.

---

## 🧪 Final Verification Battery

- `flutter analyze lib test`: **0 errors** (265 warnings/infos)
- `flutter test`: **65/65 pass** (100% green)
- `npm --prefix functions run build`: **TypeScript build clean**
- `npm --prefix functions test`: **28/28 pass on emulator**
- `flutter build ios --simulator --debug`: **Succeeded (`Runner.app` built)**
