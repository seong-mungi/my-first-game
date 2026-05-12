#!/usr/bin/env bash
# systems_index_bloat_check.sh
# Detects narrative re-contamination in design/gdd/systems-index.md
# after CCGS Tier 1 cleanup (commit 32fd90d, 2026-05-12).
#
# Usage:
#   tools/ci/systems_index_bloat_check.sh
#
# Exit codes:
#   0 — clean (post-Tier-1 budget respected)
#   1 — light re-contamination detected (Tier 2 recommended)
#   2 — heavy re-contamination (Tier 2 required immediately)

set -euo pipefail

INDEX="design/gdd/systems-index.md"

if [[ ! -f "$INDEX" ]]; then
  echo "FAIL: $INDEX not found"
  exit 2
fi

# Tier 1 baseline (post-commit 32fd90d, 2026-05-12)
BASELINE_BYTES=19857
BUDGET_BYTES=25000       # +25% headroom over baseline
WARN_BYTES=30000         # +50% — light re-contamination
FAIL_BYTES=40000         # +100% — heavy re-contamination

# Status column max chars (post-Tier-1 max was 89 chars for Camera row)
STATUS_BUDGET=150        # generous (enum · date · short annotation)
STATUS_WARN=300
STATUS_FAIL=500

# Last Updated header max chars (Tier 1 set to 83)
HEADER_BUDGET=150

bytes=$(wc -c < "$INDEX")
lines=$(wc -l < "$INDEX")

echo "=== systems-index.md bloat check ==="
echo "File:     $INDEX"
echo "Baseline: $BASELINE_BYTES B (Tier 1 commit 32fd90d)"
echo "Current:  $bytes B  ($lines lines)"
echo "Delta:    $((bytes - BASELINE_BYTES)) B"
echo ""

verdict=0

# Check 1: File size budget
if (( bytes > FAIL_BYTES )); then
  echo "FAIL  size > $FAIL_BYTES B — heavy re-contamination"
  verdict=2
elif (( bytes > WARN_BYTES )); then
  echo "WARN  size > $WARN_BYTES B — light re-contamination"
  verdict=$(( verdict > 1 ? verdict : 1 ))
elif (( bytes > BUDGET_BYTES )); then
  echo "INFO  size > $BUDGET_BYTES B (within +25% headroom)"
else
  echo "OK    size within $BUDGET_BYTES B budget"
fi

# Check 2: Last Updated header single-line
header_chars=$(grep "^> \*\*Last Updated\*\*:" "$INDEX" | head -1 | awk '{print length($0)}')
header_count=$(grep -c "^> \*\*Last Updated\*\*:" "$INDEX")
if (( header_count != 1 )); then
  echo "FAIL  Last Updated header count = $header_count (expected 1)"
  verdict=2
elif (( header_chars > HEADER_BUDGET )); then
  echo "WARN  Last Updated header = $header_chars chars (budget $HEADER_BUDGET) — narrative leakage"
  verdict=$(( verdict > 1 ? verdict : 1 ))
else
  echo "OK    Last Updated header = $header_chars chars"
fi

# Check 3: Status column cell lengths
max_status=$(python3 -c "
with open('$INDEX') as f:
    lines = f.readlines()
max_len = 0
for i, line in enumerate(lines):
    if line.startswith('| ') and line.count('|') >= 7:
        parts = line.split('|')
        if len(parts) > 5:
            status = parts[5].strip()
            if len(status) > max_len:
                max_len = len(status)
print(max_len)
")

if (( max_status > STATUS_FAIL )); then
  echo "FAIL  max Status cell = $max_status chars — heavy narrative bloat"
  verdict=2
elif (( max_status > STATUS_WARN )); then
  echo "WARN  max Status cell = $max_status chars (budget $STATUS_WARN) — light bloat"
  verdict=$(( verdict > 1 ? verdict : 1 ))
elif (( max_status > STATUS_BUDGET )); then
  echo "INFO  max Status cell = $max_status chars (budget $STATUS_BUDGET; warn $STATUS_WARN)"
else
  echo "OK    max Status cell = $max_status chars"
fi

# Check 4: Narrative leakage patterns
echo ""
echo "--- Narrative pattern occurrence ---"
total_leakage=0
for pat in "MAJOR REVISION" "Phase 5d" "Previously:" "re-review APPROVED" "RR[0-9]+"; do
  count=$(grep -cE "$pat" "$INDEX" || true)
  if (( count > 0 )); then
    echo "  '$pat': $count occurrences"
    total_leakage=$(( total_leakage + count ))
  fi
done

if (( total_leakage > 10 )); then
  echo "FAIL  total narrative leakage = $total_leakage (heavy)"
  verdict=2
elif (( total_leakage > 5 )); then
  echo "WARN  total narrative leakage = $total_leakage (moderate)"
  verdict=$(( verdict > 1 ? verdict : 1 ))
else
  echo "OK    total narrative leakage = $total_leakage"
fi

echo ""
case $verdict in
  0) echo "VERDICT: CLEAN — Tier 1 baseline holding. Tier 2 NOT required yet." ;;
  1) echo "VERDICT: WARN — light re-contamination. Schedule Tier 2 within 1-2 sessions." ;;
  2) echo "VERDICT: FAIL — heavy re-contamination. Apply Tier 2 immediately." ;;
esac

exit $verdict
