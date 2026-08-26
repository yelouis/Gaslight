#!/usr/bin/env bash
# Regenerates lib/utils/prompt_decks.dart from functions/src/prompt_decks.ts.
# See scripts/generate_prompt_decks_dart.mjs for why that direction.
set -euo pipefail
cd "$(dirname "$0")/.."
node scripts/generate_prompt_decks_dart.mjs
