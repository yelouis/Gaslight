# Active Build Queue — Queue Complete (August 7, 2026)

All items in the active build queue (**Task T3** and **Issue 33**) have been successfully implemented, verified with automated unit and widget tests, and documented in `docs/ongoing_general_errors.md`.

---

## 🟢 Delivered Queue Summary

1. **Task T3 — Assertive PNG Decoding & Animation Contract Test Suite** (`9573a58`):
   - **Decoder Helper (`test/helpers/png_decoder.dart`)**: Built a pure Dart PNG decoder that decompresses IDAT scanlines, undoes PNG row filters, and extracts RGBA pixels with WCAG relative-luminance contrast calculation.
   - **Asset Integrity Assertions (`test/raven_mascot_test.dart`)**:
     - Verified exact dimensions for 1x (256×256), 2.0x (512×512), and 3.0x (768×768) variants across all 4 raven layers.
     - Verified real alpha channel presence (transparent and opaque pixels exist for all assets).
     - Verified WCAG relative-luminance rim contrast guard against `#14110E` is **≥ 4.5:1** (measured: 7.70:1).
     - Verified shared-canvas alignment bounding box containment (`bodyBox` contains `eyeBox`).
   - **Per-Pose Contract Assertions**: Verified exact `AssetImage` basenames (`eye_open.png` vs `eye_closed.png`), mid-animation non-identity `Transform` matrices (`hop`, `ruffle`, `fly`), static frame stability under `AppMotion.reduce`, and clean disposal.
   - **Falsifiability Verification**: Tested pre-fix `#171310` body color against contrast guard, confirming empirical failure (`Expected: >= 4.5 / Actual: 1.018631`).

2. **Issue 33 — Crow Mascot Silhouette Filled with Solid Body Color (Option A)** (`8949abe`):
   - **Asset Update (`assets/images/raven/body.png`)**: Regenerated `body.png` across 1x, 2.0x, and 3.0x variants to fill interior transparent pixels bounded by the brass rim contour with solid `#2E2A26` body fill.
   - **Visual Integrity & Contrast**: Increased opaque pixel coverage inside the bounding box from 12.4% (outline line-art) to 44.9% (solid mascot body), preventing background wall textures from showing through. Verified rim contrast (7.70:1) and alignment remain intact.

---

## 🧪 Final Verification Battery

- `flutter analyze lib test`: **0 errors** (263 warnings/infos)
- `flutter test`: **77/77 pass** (100% green)
- `npm --prefix functions run build`: **TypeScript build clean**
- `npm --prefix functions test`: **31/31 pass on emulator**
- `npx firebase-tools deploy --only functions`: **Production deploy succeeded**
