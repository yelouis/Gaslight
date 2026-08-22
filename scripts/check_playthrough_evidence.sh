#!/usr/bin/env bash
# scripts/check_playthrough_evidence.sh
#
# Validates playthrough findings evidence rules for Gaslight E2E reports.
#
# Exit codes:
#   0: All blocks satisfy evidence rules. Prints block counts and breakdown.
#   1: One or more blocks violate rules. Prints each offending block and rule.
#   2: Could not verify (file missing, unreadable, or 0 blocks parsed).
#
# Falsification record against pre-H2 docs/playthrough_findings_marionette.md:
#   $ ./scripts/check_playthrough_evidence.sh
#   FAIL: 2 violation(s) found across 15 blocks:
#     [E10] Rule R3 violation: PASS block's Observed field contains no device artefacts (screenshot path, Type: widget entry, or flutter: log line)
#       Offending Observed content:
#         `handleDisconnect` evaluates remaining active players in room transaction. If remaining player count < 3 during active gameplay, server executes `transaction.update(roomRef, { currentPhase: "gameOver", unmaskDeadline: null })`.
#     [E11] Rule R3 violation: PASS block's Observed field contains no device artefacts (screenshot path, Type: widget entry, or flutter: log line)
#       Offending Observed content:
#         All 7 debug button sites (`lobby_screen.dart:745`, `phase2_craft.dart:327, 364, 564`, `phase3_vote.dart:254, 411, 571`) are gated behind `if (kDebugMode)`.
#         Gating verified via `flutter test test/debug_buttons_gating_test.dart`: `3/3 tests passed`.

set -euo pipefail

REPORT_FILE="${1:-docs/playthrough_findings_marionette.md}"

if [[ ! -f "$REPORT_FILE" ]]; then
  echo "ERROR: Could not verify — report file does not exist: $REPORT_FILE" >&2
  exit 2
fi

python3 - "$REPORT_FILE" << 'EOF'
import sys
import re

report_path = sys.argv[1]

try:
    with open(report_path, "r", encoding="utf-8") as f:
        content = f.read()
except Exception as e:
    print(f"ERROR: Could not verify — failed to read {report_path}: {e}", file=sys.stderr)
    sys.exit(2)

# Split into blocks on '### E' headings
heading_regex = re.compile(r'(?m)^###\s+(E\d+.*?)$')
splits = heading_regex.split(content)

if len(splits) < 3:
    print(f"ERROR: Could not verify — zero assertion blocks (### E...) found in {report_path}", file=sys.stderr)
    sys.exit(2)

blocks = []
for i in range(1, len(splits), 2):
    heading = splits[i].strip()
    body = splits[i + 1] if i + 1 < len(splits) else ""
    id_match = re.match(r'^(E\d+)', heading)
    block_id = id_match.group(1) if id_match else heading
    blocks.append({
        "id": block_id,
        "heading": heading,
        "body": body
    })

total_blocks = len(blocks)
if total_blocks == 0:
    print(f"ERROR: Could not verify — zero blocks parsed in {report_path}", file=sys.stderr)
    sys.exit(2)

pass_count = 0
not_run_count = 0
fail_count = 0
other_count = 0

violations = []

verdict_regex = re.compile(r'(?m)^\s*[-*]*\s*\*\*Verdict:\*\*\s*(.+)$')
reason_regex = re.compile(r'(?m)^\s*[-*]*\s*\*\*Reason[^*]*:\*\*\s*(.+)$')
observed_header_regex = re.compile(r'(?m)^\s*[-*]*\s*\*\*Observed([^*]*):\*\*\s*(.*)$')
field_header_regex = re.compile(r'(?m)^\s*[-*]*\s*\*\*[A-Z][a-zA-Z0-9\s()_-]*:\*\*')

artefact_png_regex = re.compile(r'docs/playthrough_evidence/[a-zA-Z0-9_.-]+\.png')
artefact_widget_regex = re.compile(r'Type:\s*\w+|Text:\s*"')
artefact_log_regex = re.compile(r'flutter:\s*|flutter\s+run|plutil\s+-lint|build/ios/')
grep_banned_regex = re.compile(r'grep\s+-')

for block in blocks:
    bid = block["id"]
    body = block["body"]
    
    # 1. Extract Verdict
    vmatch = verdict_regex.search(body)
    verdict_raw = vmatch.group(1).strip() if vmatch else "UNKNOWN"
    verdict_upper = verdict_raw.upper()
    
    is_pass = verdict_upper.startswith("PASS")
    is_not_run = verdict_upper.startswith("NOT RUN")
    is_fail = verdict_upper.startswith("FAIL")
    
    if is_pass:
        pass_count += 1
    elif is_not_run:
        not_run_count += 1
    elif is_fail:
        fail_count += 1
    else:
        other_count += 1

    # Check NOT RUN rules
    if is_not_run:
        rmatch = reason_regex.search(body)
        if not rmatch or not rmatch.group(1).strip():
            violations.append(f"[{bid}] NOT RUN block is missing a non-empty **Reason:** line")
        continue

    # Rules R2 - R4 apply to PASS and FAIL blocks
    # 2. Extract Observed field matching any **Observed...:** header
    obs_matches = list(observed_header_regex.finditer(body))
    if not obs_matches:
        violations.append(f"[{bid}] Rule R2 violation: Block claiming {verdict_raw} has no **Observed:** field")
        continue
    
    obs_match = obs_matches[0]
    obs_start = obs_match.end()
    same_line_obs = obs_match.group(2).strip()
    
    remaining_body = body[obs_start:]
    next_field_match = field_header_regex.search(remaining_body)
    if next_field_match:
        obs_content = remaining_body[:next_field_match.start()]
    else:
        obs_content = remaining_body
    
    if same_line_obs:
        obs_content = same_line_obs + "\n" + obs_content
    
    obs_content = obs_content.strip()
    if not obs_content:
        violations.append(f"[{bid}] Rule R2 violation: Block claiming {verdict_raw} has an empty Observed field")
        continue
    
    # 3. Rule R4: Negative check (must NOT contain 'grep -')
    if grep_banned_regex.search(obs_content):
        violations.append(f"[{bid}] Rule R4 violation: Observed field contains banned 'grep -' command:\n    {obs_content}")
        continue
    
    # 4. Rule R3: Positive check (must contain at least one device artefact)
    has_png = bool(artefact_png_regex.search(obs_content))
    has_widget = bool(artefact_widget_regex.search(obs_content))
    has_log = bool(artefact_log_regex.search(obs_content))
    
    if not (has_png or has_widget or has_log):
        lines = [l.strip() for l in obs_content.splitlines() if l.strip()]
        preview = "\n        ".join(lines[:4])
        violations.append(
            f"[{bid}] Rule R3 violation: PASS block's Observed field contains no device artefacts "
            f"(screenshot path, Type: widget entry, or flutter: log line)\n"
            f"      Offending Observed content:\n        {preview}"
        )

if violations:
    print(f"FAIL: {len(violations)} violation(s) found across {total_blocks} blocks:")
    for v in violations:
        print(f"  {v}")
    sys.exit(1)

print(f"PASS: Checked {total_blocks} blocks in {report_path}: {pass_count} PASS, {not_run_count} NOT RUN, {fail_count} FAIL.")
print("All assertion blocks satisfy playthrough evidence rules R1-R4.")
sys.exit(0)
EOF
