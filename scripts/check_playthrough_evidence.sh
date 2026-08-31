#!/usr/bin/env bash
# scripts/check_playthrough_evidence.sh
#
# Validates playthrough findings evidence rules for Gaslight E2E reports (iOS E blocks and Web W blocks).
#
# Exit codes:
#   0: All blocks satisfy evidence rules. Prints block counts and breakdown.
#   1: One or more blocks violate rules. Prints each offending block and rule.
#   2: Could not verify (file missing, unreadable, or 0 blocks parsed).
#
# Falsification record for I1 (Web blocks R3 strict PNG enforcement):
#   1. W1 PASS with only Type: Text and no PNG:
#      $ ./scripts/check_playthrough_evidence.sh /tmp/test_w1.md -> exit 1
#      FAIL: 1 violation(s) found across 1 blocks:
#        [W1] Rule R3 violation: Web PASS/FAIL block's Observed field must contain a PNG screenshot path under docs/playthroughs/evidence/
#   2. W1 PASS with docs/playthroughs/evidence/w1.png:
#      $ ./scripts/check_playthrough_evidence.sh /tmp/test_w1.md -> exit 0 (1 PASS)
#   3. E1 PASS with only Type: Text (iOS):
#      $ ./scripts/check_playthrough_evidence.sh /tmp/test_e1.md -> exit 0 (1 PASS)
#   4. W2 NOT RUN with Reason (over-reach guard):
#      $ ./scripts/check_playthrough_evidence.sh /tmp/test_w2.md -> exit 0 (1 NOT RUN)
#   5. Default iOS report regression:
#      $ ./scripts/check_playthrough_evidence.sh -> exit 0 (14 PASS, 1 NOT RUN, 0 FAIL)
#
# Falsification record for L1 (Rule R5 - Cited PNG artefacts must exist on disk):
#   1. Move cited PNG aside:
#      $ git mv docs/playthroughs/evidence/e10_p1_gameover.png docs/playthroughs/evidence/e10_p1_gameover.png.bak
#      $ ./scripts/check_playthrough_evidence.sh -> exit 1
#      FAIL: 1 violation(s) found across 15 blocks:
#        [E10] Rule R5 violation: Cited artefact does not exist on disk: docs/playthroughs/evidence/e10_p1_gameover.png
#   2. Restore cited PNG:
#      $ git mv docs/playthroughs/evidence/e10_p1_gameover.png.bak docs/playthroughs/evidence/e10_p1_gameover.png
#      $ ./scripts/check_playthrough_evidence.sh -> exit 0 (14 PASS, 1 NOT RUN, 0 FAIL; 14 artefact file paths verified on disk)
#   3. Over-reach guard: E9 (NOT RUN with no PNG) is not flagged by R5.
#   4. Non-zero match assertion: 14 artefacts verified on iOS, 37 on Web.
#
# Rule R6 — manifest-driven verbatim assertion check:
#   Reads docs/playthroughs/manifest.md. For every block listed there, R6 checks:
#     (a) The block exists in the report.
#     (b) The block's heading title matches the manifest Title column verbatim
#         (after normalising surrounding whitespace only).
#     (c) The block contains a **Specified assertion:** field matching the manifest
#         Specified assertion column verbatim.
#     (d) Every PNG the block cites is accompanied by a non-empty **Artefact depicts:**
#         field, and appears in docs/playthroughs/evidence/ARTEFACTS.tsv.
#   R6 fails if the manifest file exists but parses to zero rows.
#   Blocks NOT listed in the manifest are unaffected by R6 — legacy blocks are untouched.
#
#   What R6 does NOT prove: that the assertion is true, or that a cited artefact shows
#   what its Artefact depicts: field claims. R6 proves only that the block still carries
#   the assertion it was originally given. Opening every cited artefact and asking what
#   it shows remains a standing human obligation (see agent_execution_guide.md §9).
#
# Falsification record for R6:
#   (Recorded in the S2 commit body — three runs: unmodified exit 0, one-word title
#    change exit 1, one-word assertion change exit 1.)


set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORT_FILE="${1:-$REPO_ROOT/docs/playthroughs/findings_marionette.md}"

if [[ ! -f "$REPORT_FILE" ]]; then
  echo "ERROR: Could not verify — report file does not exist: $REPORT_FILE" >&2
  exit 2
fi

python3 - "$REPORT_FILE" "$REPO_ROOT" << 'EOF'
import os
import sys
import re

report_path = sys.argv[1]
repo_root = sys.argv[2]

try:
    with open(report_path, "r", encoding="utf-8") as f:
        content = f.read()
except Exception as e:
    print(f"ERROR: Could not verify — failed to read {report_path}: {e}", file=sys.stderr)
    sys.exit(2)

# Split into blocks on '### [EW]' headings
heading_regex = re.compile(r'(?m)^###\s+([EW]\d+.*?)$')
splits = heading_regex.split(content)

if len(splits) < 3:
    print(f"ERROR: Could not verify — zero assertion blocks (### [EW]...) found in {report_path}", file=sys.stderr)
    sys.exit(2)

blocks = []
for i in range(1, len(splits), 2):
    heading = splits[i].strip()
    body = splits[i + 1] if i + 1 < len(splits) else ""
    id_match = re.match(r'^([EW]\d+)', heading)
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
total_pngs_checked = 0

violations = []

verdict_regex = re.compile(r'(?m)^\s*[-*]*\s*\*\*Verdict:\*\*\s*(.+)$')
reason_regex = re.compile(r'(?m)^\s*[-*]*\s*\*\*Reason[^*]*:\*\*\s*(.+)$')
observed_header_regex = re.compile(r'(?m)^\s*[-*]*\s*\*\*Observed([^*]*):\*\*\s*(.*)$')
field_header_regex = re.compile(r'(?m)^\s*[-*]*\s*\*\*[A-Z][a-zA-Z0-9\s()_-]*:\*\*')

artefact_png_regex = re.compile(r'docs/playthroughs/evidence/[a-zA-Z0-9_.-]+\.png')
artefact_widget_regex = re.compile(r'Type:\s*\w+|Text:\s*"')
artefact_log_regex = re.compile(r'flutter:\s*|flutter\s+run|plutil\s+-lint|build/ios/')
grep_banned_regex = re.compile(r'grep\s+-')

for block in blocks:
    bid = block["id"]
    body = block["body"]
    is_w_block = bid.startswith("W")
    
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

    # Check NOT RUN rules (R5 over-reach guard: NOT RUN blocks carry no required artefact check)
    if is_not_run:
        rmatch = reason_regex.search(body)
        if not rmatch or not rmatch.group(1).strip():
            violations.append(f"[{bid}] NOT RUN block is missing a non-empty **Reason:** line")
        continue

    # Rules R2 - R5 apply to PASS and FAIL blocks
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
    
    # 4. Rule R3: Positive check
    has_png = bool(artefact_png_regex.search(obs_content))
    has_widget = bool(artefact_widget_regex.search(obs_content))
    has_log = bool(artefact_log_regex.search(obs_content))
    
    lines = [l.strip() for l in obs_content.splitlines() if l.strip()]
    preview = "\n        ".join(lines[:4])
    
    if is_w_block:
        # On web, there is no widget tree and no flutter: log.
        # Strict requirement: Must have a PNG under docs/playthroughs/evidence/
        if not has_png:
            violations.append(
                f"[{bid}] Rule R3 violation: Web PASS/FAIL block's Observed field must contain a PNG screenshot path under docs/playthroughs/evidence/\n"
                f"      Offending Observed content:\n        {preview}"
            )
    else:
        # iOS (E) blocks accept screenshot path, Type: widget entry, or flutter: log line
        if not (has_png or has_widget or has_log):
            violations.append(
                f"[{bid}] Rule R3 violation: PASS block's Observed field contains no device artefacts "
                f"(screenshot path, Type: widget entry, or flutter: log line)\n"
                f"      Offending Observed content:\n        {preview}"
            )

    # 5. Rule R5: Existence check for every cited PNG artefact on disk
    cited_pngs = artefact_png_regex.findall(obs_content)
    for p in cited_pngs:
        total_pngs_checked += 1
        full_png_path = os.path.join(repo_root, p)
        if not os.path.isfile(full_png_path):
            violations.append(
                f"[{bid}] Rule R5 violation: Cited artefact does not exist on disk: {p}\n"
                f"      Expected absolute path: {full_png_path}"
            )

# Non-zero match assertion: ensure rule executed on actual data
if total_blocks > 0 and (pass_count + fail_count) > 0 and total_pngs_checked == 0 and any(b["id"].startswith("W") for b in blocks):
    violations.append(f"FATAL: Rule R5 evaluated 0 cited PNG artefacts across {total_blocks} blocks.")

# -------------------------------------------------------------------------
# -------------------------------------------------------------------------
# Rule R6: Manifest-driven verbatim assertion check (scoped per report)
# -------------------------------------------------------------------------
manifest_path = os.path.join(repo_root, "docs", "playthroughs", "manifest.md")
r6_checked = 0
r6_summary = ""

if os.path.isfile(manifest_path):
    try:
        with open(manifest_path, "r", encoding="utf-8") as mf:
            manifest_content = mf.read()
    except Exception as e:
        violations.append(f"R6 FATAL: Could not read manifest {manifest_path}: {e}")
        manifest_content = ""

    # Parse TSV-style pipe table rows (skip header and separator rows)
    # Format: | Report | Block | Title | Specified assertion | Artefact must depict |
    table_row_regex = re.compile(
        r'^\|\s*(.*?)\s*\|\s*([EW]\d+)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|$',
        re.MULTILINE
    )
    manifest_rows = []
    for m in table_row_regex.finditer(manifest_content):
        row_report = m.group(1).strip()
        block_id = m.group(2).strip()
        title = m.group(3).strip()
        assertion = m.group(4).strip()
        depicts = m.group(5).strip()
        if row_report and block_id and title and assertion:
            manifest_rows.append({
                "report": row_report,
                "id": block_id,
                "title": title,
                "assertion": assertion,
                "depicts": depicts,
            })

    if len(manifest_rows) == 0:
        violations.append(
            f"R6 FATAL: Manifest file exists at {manifest_path} but parsed to zero rows. "
            f"Either the file is empty, the table body is empty, or the parser failed. "
            f"Edit docs/playthroughs/manifest.md to add rows, or remove the file if no blocks are governed."
        )
    else:
        def norm_repo_path(p):
            if os.path.isabs(p):
                return os.path.relpath(p, repo_root)
            return os.path.relpath(os.path.join(repo_root, p), repo_root)

        cur_report_norm = norm_repo_path(report_path)
        governed_rows = [r for r in manifest_rows if norm_repo_path(r["report"]) == cur_report_norm]
        total_manifest_count = len(manifest_rows)

        if len(governed_rows) == 0:
            r6_summary = f" R6: 0 of {total_manifest_count} manifest entries govern this report ({cur_report_norm})."
        else:
            # Build a lookup of blocks by id
            block_by_id = {b["id"]: b for b in blocks}

            # Load ARTEFACTS.tsv for cross-check
            tsv_path = os.path.join(repo_root, "docs", "playthroughs", "evidence", "ARTEFACTS.tsv")
            tsv_entries = set()  # set of (block_id, filename) tuples with non-empty depicts
            if os.path.isfile(tsv_path):
                try:
                    with open(tsv_path, "r", encoding="utf-8") as tf:
                        for line_num, line in enumerate(tf):
                            if line_num == 0:
                                continue  # skip header
                            parts = line.rstrip("\n").split("\t")
                            if len(parts) >= 5 and parts[0].strip() and parts[1].strip() and parts[4].strip():
                                tsv_entries.add((parts[0].strip(), parts[1].strip()))
                except Exception as e:
                    violations.append(f"R6 WARNING: Could not read ARTEFACTS.tsv: {e}")

            # Also find the Artefact depicts: field regex
            artefact_depicts_regex = re.compile(r'(?m)^\s*[-*]*\s*\*\*Artefact depicts:\*\*\s*(.+)$')

            for row in governed_rows:
                r6_checked += 1
                bid = row["id"]
                expected_title = row["title"]
                expected_assertion = row["assertion"]

                if bid not in block_by_id:
                    violations.append(
                        f"[{bid}] R6 violation: Block is listed in docs/playthroughs/manifest.md "
                        f"but does not exist in {report_path}. "
                        f"Edit the manifest row at docs/playthroughs/manifest.md if the block id changed."
                    )
                    continue

                block = block_by_id[bid]
                # Normalise: strip surrounding whitespace from heading after the 'ID — ' prefix
                heading = block["heading"]
                # heading looks like "E47 — Own answer is sealed in round 2, ..."
                heading_title_match = re.match(r'^[EW]\d+\s+[-—]\s+(.+)$', heading)
                if heading_title_match:
                    actual_title = heading_title_match.group(1).strip()
                else:
                    actual_title = heading.strip()

                if actual_title != expected_title:
                    violations.append(
                        f"[{bid}] R6 violation: Block title does not match manifest verbatim.\n"
                        f"      Manifest (docs/playthroughs/manifest.md): \"{expected_title}\"\n"
                        f"      Report heading:                          \"{actual_title}\"\n"
                        f"      To fix a legitimate re-scope, update the manifest row in the same commit."
                    )

                # Check Specified assertion: field
                body = block["body"]
                spec_assertion_regex = re.compile(r'(?m)^\s*[-*]*\s*\*\*Specified assertion:\*\*\s*(.+)$')
                sa_match = spec_assertion_regex.search(body)
                if not sa_match:
                    violations.append(
                        f"[{bid}] R6 violation: Block has no **Specified assertion:** field. "
                        f"Add one quoting the manifest assertion verbatim: \"{expected_assertion}\""
                    )
                else:
                    actual_assertion = sa_match.group(1).strip()
                    if actual_assertion != expected_assertion:
                        violations.append(
                            f"[{bid}] R6 violation: **Specified assertion:** does not match manifest verbatim.\n"
                            f"      Manifest (docs/playthroughs/manifest.md): \"{expected_assertion}\"\n"
                            f"      Report field:                             \"{actual_assertion}\"\n"
                            f"      To fix a legitimate re-scope, update the manifest row in the same commit."
                        )

                # Check every cited PNG has a non-empty Artefact depicts: field
                # and appears in ARTEFACTS.tsv
                obs_matches_r6 = list(observed_header_regex.finditer(body))
                if obs_matches_r6:
                    obs_match_r6 = obs_matches_r6[0]
                    obs_start_r6 = obs_match_r6.end()
                    same_line_r6 = obs_match_r6.group(2).strip()
                    remaining_r6 = body[obs_start_r6:]
                    next_field_r6 = field_header_regex.search(remaining_r6)
                    obs_body_r6 = remaining_r6[:next_field_r6.start()] if next_field_r6 else remaining_r6
                    if same_line_r6:
                        obs_body_r6 = same_line_r6 + "\n" + obs_body_r6

                    cited_pngs_r6 = artefact_png_regex.findall(obs_body_r6)
                    for png_path in cited_pngs_r6:
                        png_basename = os.path.basename(png_path)
                        # Check Artefact depicts: field is non-empty (at least one instance in the block)
                        depicts_matches = artefact_depicts_regex.findall(body)
                        if not depicts_matches or not any(d.strip() for d in depicts_matches):
                            violations.append(
                                f"[{bid}] R6 violation: Block cites PNG '{png_basename}' but has no non-empty "
                                f"**Artefact depicts:** field. Add one describing what the screenshot shows."
                            )
                        # Check ARTEFACTS.tsv has an entry for this PNG
                        if os.path.isfile(tsv_path):
                            if (bid, png_basename) not in tsv_entries:
                                violations.append(
                                    f"[{bid}] R6 violation: PNG '{png_basename}' is cited in the report but has no entry "
                                    f"in docs/playthroughs/evidence/ARTEFACTS.tsv with matching block_id='{bid}' and filename='{png_basename}'. "
                                    f"Log it in ARTEFACTS.tsv at capture time."
                                )

            r6_summary = f" R6: {r6_checked} of {r6_checked} manifest entries checked for {cur_report_norm}."
else:
    r6_summary = " R6: manifest not present (no governed blocks)."

# -------------------------------------------------------------------------

if violations:
    print(f"FAIL: {len(violations)} violation(s) found across {total_blocks} blocks:")
    for v in violations:
        print(f"  {v}")
    sys.exit(1)

print(f"PASS: Checked {total_blocks} blocks ({total_pngs_checked} artefact file paths verified on disk) in {report_path}: {pass_count} PASS, {not_run_count} NOT RUN, {fail_count} FAIL.{r6_summary}")
print("All assertion blocks satisfy playthrough evidence rules R1-R5.")
sys.exit(0)
EOF
