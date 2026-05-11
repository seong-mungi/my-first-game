#!/usr/bin/env bash
# tools/ci/pm_static_check.sh — Player Movement static-analysis CI gate.
#
# Implements three BLOCKING ACs from design/gdd/player-movement.md:
#   - AC-H3-04 (H.3 Per-Tick Determinism)   — GREP-PM-3 wall-clock,
#                                              GREP-PM-6 async/await,
#                                              GREP-PM-4 single-arg _anim.seek
#   - AC-H7-03 (H.7 Static Analysis)        — GREP-PM-1 external 7-field write,
#                                              GREP-PM-5 _is_restoring write
#                                              outside restore_from_snapshot,
#                                              GREP-PM-7 is_on_floor() count == 1
#   - AC-H7-04 (H.7 Static Analysis)        — Every _on_anim_* func body must
#                                              contain _is_restoring OR
#                                              # ALLOW-PM-GREP-4 exemption
#
# Precedent: tools/ci/damage_static_check.sh (damage.md AC-21).
# False-positive exemption: # ALLOW-PM-GREP-N inline comment + justification.
#
# Tier 1 behaviour: if $PM_FILE is missing (design-only phase), the script
# emits a NOTICE and exits 0 so it can be wired into CI before PM code lands.
# Set PM_REQUIRE=1 to fail when the file is missing.
#
# Override defaults:
#   PM_FILE   — path to player_movement.gd (default: src/player/player_movement.gd)
#   SRC_ROOT  — repo source tree to scan for external writes (default: src)
#   PM_REQUIRE — when "1", treat missing PM_FILE as a failure
#
# Exit codes: 0 = all checks pass; 1 = at least one violation.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

PM_FILE="${PM_FILE:-src/player/player_movement.gd}"
SRC_ROOT="${SRC_ROOT:-src}"
FAIL=0

red()    { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }

violation() {
  red "VIOLATION ($1): $2"
  FAIL=1
}

# ─────────────────────────────────────────────────────────────────────────────
# Tier 1 guard — graceful pass when player_movement.gd does not yet exist.
# ─────────────────────────────────────────────────────────────────────────────

if [[ ! -f "$PM_FILE" ]]; then
  yellow "NOTICE: $PM_FILE not found (Tier 1 design-only phase)."
  yellow "        pm_static_check.sh wired in CI but trivially passes until PM code lands."
  yellow "        Set PM_REQUIRE=1 to enforce file presence."
  if [[ "${PM_REQUIRE:-0}" == "1" ]]; then
    violation "PM-FILE" "$PM_FILE missing and PM_REQUIRE=1"
    exit 1
  fi
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# AC-H3-04 — Wall-clock + async + single-arg _anim.seek absence
#   GREP-PM-3 · GREP-PM-6 · GREP-PM-4
# ─────────────────────────────────────────────────────────────────────────────

# Filter helper: strip lines that contain a matching # ALLOW-PM-GREP-N exemption.
filter_allow() {
  local tag="$1"
  grep -vE "# ALLOW-${tag}\b"
}

# GREP-PM-3 — Engine.get_physics_frames() is the single deterministic clock
#             (ADR-0003). Wall-clock APIs are forbidden in PM.
H3_PM3=$(grep -nE 'Time\.get_ticks_msec|OS\.get_ticks_msec|Time\.get_unix_time' "$PM_FILE" \
           | filter_allow "PM-GREP-3" || true)
if [[ -n "$H3_PM3" ]]; then
  violation "GREP-PM-3 (AC-H3-04)" "wall-clock API call in $PM_FILE"
  echo "$H3_PM3" >&2
fi

# GREP-PM-6 — Async transitions forbidden (atomic synchronous SM only).
H3_PM6=$(grep -nE 'await\s+get_tree\(\)\.physics_frame|await\s+.*\.timeout' "$PM_FILE" \
           | filter_allow "PM-GREP-6" || true)
if [[ -n "$H3_PM6" ]]; then
  violation "GREP-PM-6 (AC-H3-04)" "async/await construct in $PM_FILE"
  echo "$H3_PM6" >&2
fi

# GREP-PM-4 — Single-arg _anim.seek(t) forbidden; time-rewind.md I4 mandates
#             seek(time, true) for immediate evaluation.
# Pattern matches _anim.seek( followed by content with NO comma before the ).
H3_PM4=$(grep -nE '_anim\.seek\s*\([^,)]*\)' "$PM_FILE" \
           | filter_allow "PM-GREP-4" || true)
if [[ -n "$H3_PM4" ]]; then
  violation "GREP-PM-4 (AC-H3-04)" "single-arg _anim.seek() (require seek(time, true))"
  echo "$H3_PM4" >&2
fi

# ─────────────────────────────────────────────────────────────────────────────
# AC-H7-03 — External direct-write + restore single-writer + Phase 6a floor
#   (a) GREP-PM-1 · (b) GREP-PM-5 · (c) GREP-PM-7
# ─────────────────────────────────────────────────────────────────────────────

# (a) GREP-PM-1 — External direct-write to PM 7 fields forbidden.
# Scan $SRC_ROOT excluding the PM file itself.
PM_FILE_BASE="$(basename "$PM_FILE")"
if [[ -d "$SRC_ROOT" ]]; then
  H7_PM1=$(grep -rnE \
    '\.global_position\s*=|\.velocity\s*=|\.facing_direction\s*=|\._current_weapon_id\s*=|\._is_grounded\s*=' \
    "$SRC_ROOT" \
    --include='*.gd' \
    --exclude="$PM_FILE_BASE" 2>/dev/null \
    | filter_allow "PM-GREP-1" || true)
  if [[ -n "$H7_PM1" ]]; then
    violation "GREP-PM-1 (AC-H7-03a)" "external direct-write to PM 7 fields"
    echo "$H7_PM1" >&2
  fi
else
  yellow "NOTICE: $SRC_ROOT not present — GREP-PM-1 external-write scan skipped"
fi

# (b) GREP-PM-5 — _is_restoring assignment ONLY inside restore_from_snapshot().
# State-machine awk extraction (B4-style — DO NOT use range-pattern with
# /^[a-zA-Z_]+/ end; it collapses to the start line because `func` starts with
# a letter and matches the end pattern on the same line).
H7_PM5=$(awk '
  BEGIN { in_restore = 0 }
  /^func restore_from_snapshot/ { in_restore = 1; next }
  in_restore && /^(func |class )/ { in_restore = 0 }
  !in_restore && /_is_restoring[[:space:]]*=[[:space:]]*(true|false)/ {
    if ($0 !~ /# ALLOW-PM-GREP-5/) {
      printf "%s:%d:%s\n", FILENAME, NR, $0
    }
  }
' "$PM_FILE")
if [[ -n "$H7_PM5" ]]; then
  violation "GREP-PM-5 (AC-H7-03b)" "_is_restoring write outside restore_from_snapshot()"
  echo "$H7_PM5" >&2
fi

# (c) GREP-PM-7 — is_on_floor() must be called exactly once (Phase 6a).
#                 # ALLOW-PM-GREP-7 lines do not count toward the budget.
# grep -c always prints a number; do not append `|| echo 0` (would yield "0\n0"
# when grep exits 1, breaking the arithmetic). Default the var if grep errors.
FLOOR_TOTAL="$(grep -cE 'is_on_floor\(\)' "$PM_FILE" 2>/dev/null)" || FLOOR_TOTAL=0
FLOOR_ALLOW="$(grep -cE 'is_on_floor\(\).*# ALLOW-PM-GREP-7' "$PM_FILE" 2>/dev/null)" || FLOOR_ALLOW=0
FLOOR_EFFECTIVE=$((FLOOR_TOTAL - FLOOR_ALLOW))
if [[ "$FLOOR_EFFECTIVE" -ne 1 ]]; then
  violation "GREP-PM-7 (AC-H7-03c)" \
    "is_on_floor() must appear exactly 1× in $PM_FILE (excl. # ALLOW-PM-GREP-7); got $FLOOR_EFFECTIVE"
  grep -nE 'is_on_floor\(\)' "$PM_FILE" >&2 || true
fi

# ─────────────────────────────────────────────────────────────────────────────
# AC-H7-04 — Anim method-track _is_restoring guard universal scan (B4 fix).
#
# Bug in the original GDD inline:
#   awk "/^func $func_name/,/^func |^[a-zA-Z_]+/" player_movement.gd
# The end pattern /^[a-zA-Z_]+/ matches the start line itself (because `func`
# starts with `f`), so the awk range collapses to the function signature line.
# The body is never inspected and every `_on_anim_*` callback silently passes.
#
# Fix: state-machine awk — enter on `func FN`, exit on next `^func ` or
# `^class `. This is the implementation source of truth referenced by AC-H7-04.
# ─────────────────────────────────────────────────────────────────────────────

ANIM_FUNCS=$(grep -nE '^func _on_anim_[a-z_]+' "$PM_FILE" 2>/dev/null \
  | sed -E 's/^[0-9]+:func[[:space:]]+(_on_anim_[a-z_]+).*/\1/' || true)

if [[ -z "$ANIM_FUNCS" ]]; then
  yellow "NOTICE: no _on_anim_* method-track callbacks in $PM_FILE — AC-H7-04 trivially passes"
else
  while IFS= read -r FN; do
    [[ -z "$FN" ]] && continue
    # Word-boundary uses [^a-zA-Z0-9_] for BSD-awk compatibility (macOS); \b
    # is only a GNU-awk extension. Anchors at start of func decl, exits on
    # the next `^func ` or `^class ` line.
    BODY=$(awk -v fn="$FN" '
      BEGIN { in_block = 0 }
      $0 ~ ("^func " fn "[^a-zA-Z0-9_]") { in_block = 1; print; next }
      in_block && /^(func |class )/ { in_block = 0 }
      in_block { print }
    ' "$PM_FILE")
    if [[ -z "$BODY" ]]; then
      violation "AC-H7-04" "could not extract body for $FN (awk extraction failed)"
      continue
    fi
    HAS_GUARD="$(echo "$BODY" | grep -cE '_is_restoring')" || HAS_GUARD=0
    HAS_ALLOW="$(echo "$BODY" | grep -cE '# ALLOW-PM-GREP-4')" || HAS_ALLOW=0
    if [[ "$HAS_GUARD" -eq 0 && "$HAS_ALLOW" -eq 0 ]]; then
      violation "AC-H7-04" "$FN lacks _is_restoring guard and # ALLOW-PM-GREP-4 exemption"
    fi
  done <<< "$ANIM_FUNCS"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Result
# ─────────────────────────────────────────────────────────────────────────────

if [[ "$FAIL" -eq 0 ]]; then
  green "PASS: tools/ci/pm_static_check.sh — AC-H3-04 + AC-H7-03 + AC-H7-04 clean"
  exit 0
else
  red   "FAIL: tools/ci/pm_static_check.sh — see violations above"
  exit 1
fi
