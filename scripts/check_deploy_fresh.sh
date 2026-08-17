#!/usr/bin/env bash
set -eo pipefail

PROJECT_ID="gaslight-46368"
EXPECTED_FUNCTION_COUNT=15
EXPECTED_FUNCTIONS=(
  "advancePhase"
  "advanceToNextResolution"
  "castVote"
  "createRoom"
  "debugAddBots"
  "debugSimulateBotResponses"
  "getMyOptionId"
  "handleDisconnect"
  "joinRoom"
  "rerollPrompt"
  "setReady"
  "startGame"
  "submitAnswer"
  "submitUnmaskGuess"
  "updateLobbySettings"
)

# 1. Resolve gcloud path
GCLOUD_BIN=""
if [[ -n "${GCLOUD_BIN_OVERRIDE:-}" ]]; then
  if [[ -x "$GCLOUD_BIN_OVERRIDE" ]]; then
    GCLOUD_BIN="$GCLOUD_BIN_OVERRIDE"
  fi
elif command -v gcloud >/dev/null 2>&1; then
  GCLOUD_BIN="$(command -v gcloud)"
elif [[ -x "/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud" ]]; then
  GCLOUD_BIN="/Users/louisye/Downloads/google-cloud-sdk/bin/gcloud"
fi

if [[ -z "$GCLOUD_BIN" ]]; then
  echo "ERROR: gcloud binary not found in PATH or at /Users/louisye/Downloads/google-cloud-sdk/bin/gcloud." >&2
  echo "Could not verify deploy freshness." >&2
  exit 2
fi

# 2. Get git commit timestamps in epoch seconds and ISO form
LAST_SRC_EPOCH=$(git log -1 --format=%ct -- functions/src 2>/dev/null || true)
LAST_SRC_ISO=$(git log -1 --format=%cI -- functions/src 2>/dev/null || true)
LAST_RULES_EPOCH=$(git log -1 --format=%ct -- firestore.rules 2>/dev/null || true)
LAST_RULES_ISO=$(git log -1 --format=%cI -- firestore.rules 2>/dev/null || true)

if [[ -z "$LAST_SRC_EPOCH" || -z "$LAST_RULES_EPOCH" ]]; then
  echo "ERROR: Failed to read git commit history for functions/src or firestore.rules." >&2
  echo "Could not verify deploy freshness." >&2
  exit 2
fi

# 3. Query deployed Cloud Functions
FUNC_RAW=$("$GCLOUD_BIN" functions list --project="$PROJECT_ID" --format="value(name,updateTime)" 2>&1) || {
  echo "ERROR: gcloud functions list failed: $FUNC_RAW" >&2
  echo "Could not verify deploy freshness (auth or network error)." >&2
  exit 2
}

if [[ -z "$FUNC_RAW" ]]; then
  echo "ERROR: gcloud functions list returned empty output." >&2
  echo "Could not verify deploy freshness." >&2
  exit 2
fi

# 4. Query deployed Firestore Rules via Firebase Rules API
AUTH_TOKEN=$("$GCLOUD_BIN" auth print-access-token 2>&1) || {
  echo "ERROR: gcloud auth print-access-token failed: $AUTH_TOKEN" >&2
  echo "Could not verify deploy freshness." >&2
  exit 2
}

RULES_RAW=$(curl -s -f -H "Authorization: Bearer $AUTH_TOKEN" -H "x-goog-user-project: $PROJECT_ID" "https://firebaserules.googleapis.com/v1/projects/$PROJECT_ID/releases" 2>&1) || {
  echo "ERROR: Failed to query Firebase Rules API: $RULES_RAW" >&2
  echo "Could not verify deploy freshness." >&2
  exit 2
}

# 5. Process timestamps and evaluate freshness via python3
python3 - <<EOF
import sys
import json
from datetime import datetime

project_id = "$PROJECT_ID"
expected_count = int("$EXPECTED_FUNCTION_COUNT")
expected_fns = set("""${EXPECTED_FUNCTIONS[*]}""".split())

last_src_epoch = int("$LAST_SRC_EPOCH")
last_src_iso = "$LAST_SRC_ISO"
last_rules_epoch = int("$LAST_RULES_EPOCH")
last_rules_iso = "$LAST_RULES_ISO"

func_raw = """$FUNC_RAW""".strip()
rules_raw = """$RULES_RAW""".strip()

def parse_iso_epoch(ts_str):
    clean_ts = ts_str[:19] + "+00:00"
    return int(datetime.fromisoformat(clean_ts).timestamp())

# Parse functions
lines = [l.strip() for l in func_raw.splitlines() if l.strip()]
deployed_fns = {}
for line in lines:
    parts = line.split()
    if len(parts) >= 2:
        name = parts[0].split('/')[-1]
        raw_ts = parts[1]
        try:
            epoch = parse_iso_epoch(raw_ts)
            deployed_fns[name] = (epoch, raw_ts)
        except Exception as e:
            print(f"ERROR: Could not parse function timestamp '{raw_ts}' for {name}: {e}", file=sys.stderr)
            sys.exit(2)

# Check function count and names
missing_fns = expected_fns - set(deployed_fns.keys())
stale_fns = []

for name in sorted(deployed_fns.keys()):
    epoch, raw_ts = deployed_fns[name]
    if epoch < last_src_epoch:
        stale_fns.append((name, epoch, raw_ts, last_src_epoch, last_src_iso))

# Parse rules
try:
    rules_json = json.loads(rules_raw)
    releases = rules_json.get("releases", [])
    if not releases:
        print("ERROR: No releases found in Firebase Rules API response.", file=sys.stderr)
        sys.exit(2)
    rules_ts = releases[0].get("updateTime", "")
    rules_epoch = parse_iso_epoch(rules_ts)
except Exception as e:
    print(f"ERROR: Could not parse Firebase Rules API response: {e}", file=sys.stderr)
    sys.exit(2)

rules_stale = False
if rules_epoch < last_rules_epoch:
    rules_stale = True

# Evaluate verdicts
if len(deployed_fns) < expected_count or missing_fns:
    print("STALE / INCOMPLETE DEPLOY: Missing expected Cloud Functions:", file=sys.stderr)
    for m in sorted(missing_fns):
        print(f"  - Missing function: {m}", file=sys.stderr)
    print(f"Total deployed: {len(deployed_fns)} / {expected_count}", file=sys.stderr)
    sys.exit(1)

if stale_fns or rules_stale:
    print("DEPLOY IS STALE! The following components lag the current tree:\n", file=sys.stderr)
    if stale_fns:
        print("Stale Functions (compared to newest commit on functions/src):", file=sys.stderr)
        print(f"  Target commit on functions/src: {last_src_iso} (epoch: {last_src_epoch})", file=sys.stderr)
        for name, d_epoch, d_iso, c_epoch, c_iso in stale_fns:
            lag_sec = c_epoch - d_epoch
            print(f"  - {name}: deployed at {d_iso} (epoch: {d_epoch}) -> LAGS by {lag_sec}s", file=sys.stderr)
        print("", file=sys.stderr)
    if rules_stale:
        lag_sec = last_rules_epoch - rules_epoch
        print("Stale Security Rules (compared to newest commit on firestore.rules):", file=sys.stderr)
        print(f"  Target commit on firestore.rules: {last_rules_iso} (epoch: {last_rules_epoch})", file=sys.stderr)
        print(f"  - firestore.rules: deployed at {rules_ts} (epoch: {rules_epoch}) -> LAGS by {lag_sec}s", file=sys.stderr)
    sys.exit(1)

# All Fresh
epochs = [ep for ep, _ in deployed_fns.values()]
min_epoch = min(epochs)
max_epoch = max(epochs)
oldest_fn = [n for n, (ep, _) in deployed_fns.items() if ep == min_epoch][0]
newest_fn = [n for n, (ep, _) in deployed_fns.items() if ep == max_epoch][0]

print("DEPLOY IS FRESH!")
print(f"All {len(deployed_fns)} Cloud Functions and Firestore Rules exceed the latest tree commits.")
print(f"  Last commit on functions/src: {last_src_iso} (epoch: {last_src_epoch})")
print(f"  Oldest deployed function: {oldest_fn} @ {deployed_fns[oldest_fn][1]} (epoch: {min_epoch})")
print(f"  Newest deployed function: {newest_fn} @ {deployed_fns[newest_fn][1]} (epoch: {max_epoch})")
print(f"  Last commit on firestore.rules: {last_rules_iso} (epoch: {last_rules_epoch})")
print(f"  Deployed firestore.rules release: {rules_ts} (epoch: {rules_epoch})")
sys.exit(0)
EOF
