#!/usr/bin/env bash
# scripts/check_web_e2e_strings.sh
#
# Proves that:
#   1. Every UI string matched by test/web_e2e/*.js exists in lib/**/*.dart (existence).
#   2. Every .text and .ariaLabel comparison in test/web_e2e/*.js references the
#      curated UI or FIXTURE map rather than a bare string literal (containment).
#   3. Every UI string in test/web_e2e/ui_strings.js is at least 3 characters long
#      and contains at least one letter, preventing vacuous substring matches (vacuity guard).
#
# Variable-agnostic containment:
#   The containment scan matches comparisons against \w+\.(text|ariaLabel),
#   ensuring helpers using any parameter name (e.g., e, n, el, item) are fully covered
#   without relying on variable-naming conventions (lesson §2.44).
#
# Runtime interpolation limit:
#   Labels assembled dynamically at runtime (e.g. 'CARD $roman OF $total') will
#   not match whole-string searches in Dart source. Any such UI label must match
#   on an invariant literal substring present in lib/, documented with a comment
#   in test/web_e2e/ui_strings.js.
#
# Exit codes:
#   0: Pass — all UI strings exist in lib/, vacuity checks pass, and all comparisons reference maps.
#   1: Stale / violation — one or more UI strings absent from lib/, bare literal in web_e2e scripts,
#      or vacuity rule violation.
#   2: Could not verify — missing file, bad directory, or runtime error.
#
# Falsification record:
#   1. First-run failure:
#      $ ./scripts/check_web_e2e_strings.sh -> exit 1
#      Reported 6 stale UI strings absent from lib/: INSPECT, ACCUSE, SHARE, VIEW STANDINGS, START ROUND, DISMISS.
#   2. Existence falsification:
#      Adding UI.ZZNOTAREALLABEL = 'ZZNOTAREALLABEL' -> exit 1 naming ZZNOTAREALLABEL. Reverting -> exit 0.
#   3. Containment falsification:
#      Adding bare literal e.text === 'CANCEL' in playthrough_helpers.js -> exit 1 naming file & line. Reverting -> exit 0.
#   4. Vacuity guard falsification:
#      Adding UI.ONE = '1' -> exit 1 rejecting entry as too short to verify. Reverting -> exit 0.
#   5. Variable-agnostic falsification:
#      Renaming parameter 'e' to 'dialogEl' in dismissAnyDialog -> containment scanner still flags bare literals.

set -euo pipefail
cd "$(dirname "$0")/.."

node << 'EOF'
const fs = require('fs');
const path = require('path');

const repoRoot = process.cwd();
const uiStringsPath = path.join(repoRoot, 'test/web_e2e/ui_strings.js');
const libDir = path.join(repoRoot, 'lib');
const webE2eDir = path.join(repoRoot, 'test/web_e2e');

if (!fs.existsSync(uiStringsPath)) {
  console.error(`ERROR: Could not verify — ${uiStringsPath} does not exist.`);
  process.exit(2);
}
if (!fs.existsSync(libDir)) {
  console.error(`ERROR: Could not verify — ${libDir} does not exist.`);
  process.exit(2);
}
if (!fs.existsSync(webE2eDir)) {
  console.error(`ERROR: Could not verify — ${webE2eDir} does not exist.`);
  process.exit(2);
}

let uiModule;
try {
  uiModule = require(uiStringsPath);
} catch (err) {
  console.error(`ERROR: Could not verify — failed to require ${uiStringsPath}: ${err.message}`);
  process.exit(2);
}

const UI = uiModule.UI;
const FIXTURE = uiModule.FIXTURE;

if (!UI || typeof UI !== 'object' || Object.keys(UI).length === 0) {
  console.error(`ERROR: Could not verify — UI export in ui_strings.js is missing or empty.`);
  process.exit(2);
}
if (!FIXTURE || typeof FIXTURE !== 'object' || Object.keys(FIXTURE).length === 0) {
  console.error(`ERROR: Could not verify — FIXTURE export in ui_strings.js is missing or empty.`);
  process.exit(2);
}

let hasFailures = false;

// 1. Vacuity guard on UI entries
for (const [key, val] of Object.entries(UI)) {
  if (typeof val !== 'string' || val.length < 3 || !/[a-zA-Z]/.test(val)) {
    console.error(`VACUITY ERROR: UI.${key} = "${val}" is rejected. UI entries must be at least 3 characters and contain at least one letter.`);
    hasFailures = true;
  }
}

// 2. Existence check: every UI value must appear in lib/**/*.dart
function getDartFiles(dir) {
  let results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results = results.concat(getDartFiles(full));
    } else if (entry.isFile() && full.endsWith('.dart')) {
      results.push(full);
    }
  }
  return results;
}

const dartFiles = getDartFiles(libDir);
if (dartFiles.length === 0) {
  console.error(`ERROR: Could not verify — no Dart files found under ${libDir}.`);
  process.exit(2);
}

// Normalise escaped quotes (\' -> ') to ensure quoting styles don't create false absences (lesson §2.44)
const dartSources = dartFiles.map(f => fs.readFileSync(f, 'utf8').replace(/\\'/g, "'"));

const missingStrings = [];
for (const [key, val] of Object.entries(UI)) {
  if (typeof val !== 'string' || val.length < 3 || !/[a-zA-Z]/.test(val)) {
    continue;
  }
  const found = dartSources.some(src => src.includes(val));
  if (!found) {
    missingStrings.push({ key, val });
  }
}

if (missingStrings.length > 0) {
  hasFailures = true;
  console.error(`EXISTENCE FAILURE: ${missingStrings.length} UI string(s) not found in lib/**/*.dart:`);
  for (const m of missingStrings) {
    console.error(`  - UI.${m.key}: "${m.val}"`);
  }
}

// 3. Containment check: scan test/web_e2e/*.js for \w+\.(text|ariaLabel) comparisons with bare string literals
const jsFiles = fs.readdirSync(webE2eDir)
  .filter(f => f.endsWith('.js') && f !== 'ui_strings.js')
  .map(f => path.join(webE2eDir, f));

if (jsFiles.length < 2) {
  console.error(`ERROR: Could not verify — expected at least 2 web_e2e test files, found ${jsFiles.length}.`);
  process.exit(2);
}

const strLitPattern = "(?:'([^'\\\\\\r\\n]|\\\\.)*'|\"([^\"\\\\\\r\\n]|\\\\.)*\"|`([^`\\\\\\r\\n]|\\\\.)*`)";
const r1 = new RegExp(`\\b\\w+\\.(?:text|ariaLabel)\\s*(?:===|!==|==|!=)\\s*(${strLitPattern})`, 'g');
const r2 = new RegExp(`(${strLitPattern})\\s*(?:===|!==|==|!=)\\s*\\b\\w+\\.(?:text|ariaLabel)\\b`, 'g');
const r3 = new RegExp(`\\b\\w+\\.(?:text|ariaLabel)\\.includes\\(\\s*(${strLitPattern})\\s*\\)`, 'g');
const r4 = new RegExp(`\\b\\w+\\.(?:text|ariaLabel)\\.(?:startsWith|endsWith)\\(\\s*(${strLitPattern})\\s*\\)`, 'g');

const containmentViolations = [];

for (const jsFile of jsFiles) {
  const relPath = path.relative(repoRoot, jsFile);
  const content = fs.readFileSync(jsFile, 'utf8');
  const lines = content.split('\n');

  lines.forEach((line, idx) => {
    const code = line.replace(/\/\/.*$/, '');
    let m;
    while ((m = r1.exec(code)) !== null) {
      containmentViolations.push({ file: relPath, line: idx + 1, expr: m[0] });
    }
    while ((m = r2.exec(code)) !== null) {
      containmentViolations.push({ file: relPath, line: idx + 1, expr: m[0] });
    }
    while ((m = r3.exec(code)) !== null) {
      containmentViolations.push({ file: relPath, line: idx + 1, expr: m[0] });
    }
    while ((m = r4.exec(code)) !== null) {
      containmentViolations.push({ file: relPath, line: idx + 1, expr: m[0] });
    }
  });
}

if (containmentViolations.length > 0) {
  hasFailures = true;
  console.error(`CONTAINMENT FAILURE: ${containmentViolations.length} bare string literal comparison(s) found in web_e2e scripts (must reference UI.* or FIXTURE.*):`);
  for (const v of containmentViolations) {
    console.error(`  ${v.file}:${v.line}: ${v.expr}`);
  }
}

if (hasFailures) {
  process.exit(1);
}

const uiCount = Object.keys(UI).length;
console.log(`PASS: All ${uiCount} UI strings verified in lib/ and all ${jsFiles.length} web_e2e scripts satisfy containment.`);
process.exit(0);
EOF
