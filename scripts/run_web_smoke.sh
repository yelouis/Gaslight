#!/usr/bin/env bash
# scripts/run_web_smoke.sh
#
# The web smoke as ONE command (Wave AK / AK1). It
#   1. builds an emulator-only web app into a scratch directory (never build/web: that build talks
#      to the emulators and must never be deployed) and the Cloud Functions;
#   2. starts the Auth, Functions and Firestore emulators with `firebase emulators:exec`;
#   3. serves the app on 127.0.0.1:8777 and runs both Playwright playthroughs from test/web_e2e/:
#        run_full_playthrough.js          one full game, W1-W16 and the responsive sweeps
#        run_match_summary_playthrough.js a 2-round game and its match summary
#      Each plays a game with three browsers and exits 0 only if it reaches game over.
#
# Run it before `flutter build web --release` (README -> Releasing -> 1. Web app). It exits 0 only
# if both scripts exited 0, the tracked evidence folder is untouched, and nothing it started is
# still listening.
#
# Needs: Flutter, Node, Java (the emulators), and Playwright's Chromium in
# test/web_e2e/node_modules. It takes about 6 minutes. It never kills a process: if one of the
# ports below is busy it prints the owner and stops.
#
# Exit codes:
#   0: PASS - both scripts exited 0, the screenshots went to the scratch directory, the ports are free.
#   1: FAIL - a script failed or was killed at 10 minutes, the evidence folder was touched, or a
#      port was left listening. Read the logs under the printed scratch directory.
#   2: Could not run - a port is busy, a tool or file is missing, or a build or the emulators
#      failed to start.
#
# Screenshots, per-script logs and the exit codes are kept in the printed scratch directory.
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
REPO="$(cd "$(dirname "$SELF")/.." && pwd)"
cd "$REPO" || exit 2

PROJECT_ID="gaslight-46368"
PORTS="8777 8080 9099 5001 4000 4400 4500 9150"
SCRIPT_SECONDS=600
MIN_PNGS=20
EVIDENCE_DIR="docs/playthroughs/evidence"
SMOKE_PATH="/opt/homebrew/bin:/opt/homebrew/opt/openjdk/bin:$PATH"

# Prints "<command> (pid <pid>)" for whatever listens on port $1, or nothing.
port_owner() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN 2>/dev/null | awk 'NR > 1 { print $1 " (pid " $2 ")"; exit }'
}

# ---------------------------------------------------------------------------------------------
# Inner mode: runs inside `emulators:exec`, so the emulators are up.
# ---------------------------------------------------------------------------------------------
if [ "${1:-}" = "--inner" ]; then
  TMP="${2:?--inner needs the scratch directory}"
  touch "$TMP/inner.started"
  mkdir -p "$TMP/shots"

  # Serve the emulator-only build, in the background. It is stopped below, before the exit.
  python3 -m http.server 8777 --bind 127.0.0.1 --directory "$TMP/web" > "$TMP/http.log" 2>&1 &
  SERVER_PID=$!
  trap 'kill "$SERVER_PID" 2>/dev/null' EXIT
  served=1
  for _ in $(seq 1 20); do
    if curl -fsS -o /dev/null http://127.0.0.1:8777/version.json 2>/dev/null; then served=0; break; fi
    sleep 0.5
  done
  if [ "$served" -ne 0 ]; then
    echo "ERROR: the web server did not come up on 127.0.0.1:8777 (see $TMP/http.log)" >&2
    kill "$SERVER_PID" 2>/dev/null
    exit 2
  fi

  cd "$REPO/test/web_e2e" || exit 2
  export WEB_E2E_SHOT_DIR="$TMP/shots"

  # Each script runs under a hard kill (macOS has no `timeout`); its exit code is read bare.
  echo "=== run_full_playthrough.js ==="
  perl -e "alarm $SCRIPT_SECONDS; exec @ARGV" node run_full_playthrough.js 2>&1 | tee "$TMP/full.log"
  rc_full=${PIPESTATUS[0]}
  echo "$rc_full" > "$TMP/full.exit"
  echo "=== run_full_playthrough.js exited $rc_full ==="

  echo "=== run_match_summary_playthrough.js ==="
  perl -e "alarm $SCRIPT_SECONDS; exec @ARGV" node run_match_summary_playthrough.js 2>&1 | tee "$TMP/summary.log"
  rc_summary=${PIPESTATUS[0]}
  echo "$rc_summary" > "$TMP/summary.exit"
  echo "=== run_match_summary_playthrough.js exited $rc_summary ==="

  kill "$SERVER_PID" 2>/dev/null
  wait "$SERVER_PID" 2>/dev/null

  status=0
  if [ "$rc_full" -ne 0 ] || [ "$rc_summary" -ne 0 ]; then status=1; fi
  # emulators:exec passes on the exit code of the LAST command of its script, so this is the last one.
  exit "$status"
fi

# ---------------------------------------------------------------------------------------------
# Outer mode
# ---------------------------------------------------------------------------------------------
started_at=$(date +%s)

# 1. Refuse to start if anything listens on a port the smoke needs. Nothing is killed.
busy=0
for port in $PORTS; do
  owner="$(port_owner "$port")"
  if [ -n "$owner" ]; then
    echo "ERROR: port $port is already in use by $owner" >&2
    busy=1
  fi
done
if [ "$busy" -ne 0 ]; then
  echo "Refusing to start: stop whatever owns those ports yourself (nothing was killed)." >&2
  exit 2
fi

# Preconditions that would otherwise fail late and confusingly.
if [ ! -f .env ]; then
  echo "ERROR: .env is missing: the app dies before it paints without it (README -> Releasing)." >&2
  exit 2
fi
if [ ! -d test/web_e2e/node_modules/playwright ]; then
  echo "ERROR: Playwright is not installed in test/web_e2e/node_modules." >&2
  echo "       Run: (cd test/web_e2e && npm install && npx playwright install chromium)" >&2
  exit 2
fi
if ! PATH="$SMOKE_PATH" java -version >/dev/null 2>&1; then
  echo "ERROR: Java is not on the PATH: the Firestore emulator needs it (brew install openjdk)." >&2
  exit 2
fi

# 2. Build the emulator-only web app (never into build/web) and the functions the emulator loads.
TMP="$(mktemp -d)"
echo "Scratch directory: $TMP"
echo "=== flutter build web --release --dart-define=USE_EMULATOR=true ==="
flutter build web --release --dart-define=USE_EMULATOR=true -o "$TMP/web" > "$TMP/build_web.log" 2>&1
rc_build=$?
if [ "$rc_build" -ne 0 ]; then
  echo "ERROR: flutter build web exited $rc_build (see $TMP/build_web.log)" >&2
  tail -n 15 "$TMP/build_web.log" >&2
  exit 2
fi
echo "=== npm --prefix functions run build ==="
npm --prefix functions run build > "$TMP/build_functions.log" 2>&1
rc_functions=$?
if [ "$rc_functions" -ne 0 ]; then
  echo "ERROR: the functions build exited $rc_functions (see $TMP/build_functions.log)" >&2
  tail -n 15 "$TMP/build_functions.log" >&2
  exit 2
fi

# 3. Run the inner mode of this script inside the emulators.
echo "=== firebase emulators:exec ==="
PATH="$SMOKE_PATH" npx firebase-tools emulators:exec --only auth,functions,firestore --project "$PROJECT_ID" "'$SELF' --inner '$TMP'"
rc_exec=$?

if [ ! -f "$TMP/inner.started" ]; then
  echo "ERROR: the emulators did not start, so nothing was run (emulators:exec exited $rc_exec)." >&2
  exit 2
fi

# 5. Report. The build output is no longer needed; the shots and logs stay.
rm -rf "$TMP/web"
rc_full="$(cat "$TMP/full.exit" 2>/dev/null || echo 'did not finish')"
rc_summary="$(cat "$TMP/summary.exit" 2>/dev/null || echo 'did not finish')"
pngs=$(find "$TMP/shots" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
dirty="$(git status --porcelain "$EVIDENCE_DIR")"

# Ports must be free again (emulators:exec stops what it started). Give the shutdown a moment.
leaked=""
for _ in $(seq 1 20); do
  leaked=""
  for port in $PORTS; do
    owner="$(port_owner "$port")"
    if [ -n "$owner" ]; then leaked="$leaked $port=$owner"; fi
  done
  [ -z "$leaked" ] && break
  sleep 1
done

echo
echo "================ WEB SMOKE ================"
echo "Scratch directory : $TMP"
echo "Screenshots       : $TMP/shots ($pngs PNGs)"
echo "emulators:exec    : exit $rc_exec"
echo "run_full_playthrough.js          : exit $rc_full   (log: $TMP/full.log)"
echo "run_match_summary_playthrough.js : exit $rc_summary   (log: $TMP/summary.log)"
echo "Time              : $(( $(date +%s) - started_at )) s"

verdict="PASS"
if [ "$rc_full" != "0" ] || [ "$rc_summary" != "0" ]; then
  verdict="FAIL (a playthrough did not exit 0)"
elif [ "$rc_exec" -ne 0 ]; then
  verdict="FAIL (emulators:exec exited $rc_exec although both scripts exited 0)"
elif [ "$pngs" -lt "$MIN_PNGS" ]; then
  verdict="FAIL (only $pngs PNGs in the shot directory, expected at least $MIN_PNGS)"
elif [ -n "$dirty" ]; then
  echo "git status --porcelain $EVIDENCE_DIR is not empty:" >&2
  echo "$dirty" >&2
  verdict="FAIL (the tracked evidence folder was touched)"
elif [ -n "$leaked" ]; then
  verdict="FAIL (still listening after the run:$leaked)"
fi
echo "Verdict           : $verdict"
echo "==========================================="

if [ "$verdict" = "PASS" ]; then
  exit 0
fi
exit 1
