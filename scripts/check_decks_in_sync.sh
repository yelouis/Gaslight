#!/usr/bin/env bash
#
# Fails when lib/utils/prompt_decks.dart is stale against its source of truth,
# functions/src/prompt_decks.ts.
#
# The decks silently diverged twice before this existed: once the Dart copy was
# edited alone (commit ee6f02b), once the TypeScript copy was — each time the
# game drew from one set while the lobby offered another. This makes that a
# build failure instead of a bug report.
#
# Exit codes:
#   0: the committed Dart file is exactly what the generator produces.
#   1: it is stale — regenerate with ./scripts/generate_prompt_decks_dart.sh
#   2: could not verify (generator failed, or produced nothing to compare).
#
# Falsification record (2026-08-26):
#   $ printf "\n// tampered\n" >> lib/utils/prompt_decks.dart
#   $ ./scripts/check_decks_in_sync.sh
#   STALE: lib/utils/prompt_decks.dart does not match functions/src/prompt_decks.ts
#   (exit 1); reverting the file returned exit 0.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="lib/utils/prompt_decks.dart"

if [[ ! -f "$TARGET" ]]; then
  echo "ERROR: Could not verify — $TARGET does not exist." >&2
  exit 2
fi

BACKUP="$(mktemp)"
trap 'if [[ -f "$BACKUP" ]]; then cp "$BACKUP" "$TARGET"; rm -f "$BACKUP"; fi' EXIT
cp "$TARGET" "$BACKUP"

if ! node scripts/generate_prompt_decks_dart.mjs >/dev/null 2>&1; then
  echo "ERROR: Could not verify — the generator failed. Run it directly to see why:" >&2
  echo "  node scripts/generate_prompt_decks_dart.mjs" >&2
  exit 2
fi

# A check that compared nothing must not report success. An empty or truncated
# generated file would otherwise "match" a truncated committed one.
LINES=$(wc -l < "$TARGET" | tr -d ' ')
DECKS=$(grep -c '^    DeckDefinition(' "$TARGET" || true)
if [[ "$LINES" -lt 50 || "$DECKS" -lt 1 ]]; then
  echo "ERROR: Could not verify — generated file looks empty ($LINES lines, $DECKS decks)." >&2
  exit 2
fi

if diff -q "$BACKUP" "$TARGET" >/dev/null 2>&1; then
  echo "PASS: $TARGET is in sync with functions/src/prompt_decks.ts ($DECKS decks, $LINES lines compared)."
  exit 0
fi

echo "STALE: $TARGET does not match functions/src/prompt_decks.ts" >&2
echo "" >&2
echo "First differences (< committed, > freshly generated):" >&2
diff "$BACKUP" "$TARGET" | head -20 >&2
echo "" >&2
echo "Fix: ./scripts/generate_prompt_decks_dart.sh  then commit the result." >&2
echo "Never hand-edit $TARGET — edit functions/src/prompt_decks.ts instead." >&2
exit 1
