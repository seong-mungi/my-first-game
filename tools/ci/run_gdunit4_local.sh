#!/usr/bin/env bash
# Run the project GdUnit4 suites from a fresh local clone.
#
# If the project does not vendor addons/gdUnit4, this script temporarily
# downloads a Godot-4.6-compatible GdUnit4 release, imports the project so
# Godot's global class cache is populated, runs the headless suites, and then
# removes only the temporary addon it created.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

GDUNIT4_VERSION="${GDUNIT4_VERSION:-v6.1.3}"
GDUNIT4_URL="${GDUNIT4_URL:-https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/${GDUNIT4_VERSION}.zip}"
REPORT_DIR="${GDUNIT4_REPORT_DIR:-res://reports}"
if [[ -n "${GDUNIT4_TEST_PATHS:-}" ]]; then
  # Space-separated list, e.g. GDUNIT4_TEST_PATHS="res://tests/unit res://tests/integration"
  read -r -a TEST_PATHS <<< "$GDUNIT4_TEST_PATHS"
else
  TEST_PATHS=("res://tests/unit" "res://tests/integration")
fi

find_godot() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    printf '%s\n' "$GODOT_BIN"
    return 0
  fi
  if command -v godot >/dev/null 2>&1; then
    command -v godot
    return 0
  fi
  if command -v godot4 >/dev/null 2>&1; then
    command -v godot4
    return 0
  fi
  return 1
}

GODOT_BIN_RESOLVED="$(find_godot || true)"
if [[ -z "$GODOT_BIN_RESOLVED" ]]; then
  cat >&2 <<'MSG'
ERROR: Godot CLI was not found.
Install Godot 4.6.x or set GODOT_BIN to the executable path, for example:
  brew install --cask godot
  GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/ci/run_gdunit4_local.sh
MSG
  exit 127
fi

if [[ ! -x "$GODOT_BIN_RESOLVED" ]]; then
  printf 'ERROR: GODOT_BIN is not executable: %s\n' "$GODOT_BIN_RESOLVED" >&2
  exit 127
fi

BOOTSTRAPPED_ADDON=0
TMP_DIR=""
IMPORT_LOG=""
LOG_FILE=""
cleanup() {
  if [[ "$BOOTSTRAPPED_ADDON" == "1" ]]; then
    rm -rf addons/gdUnit4
    rmdir addons 2>/dev/null || true
  fi
  if [[ -n "$IMPORT_LOG" ]]; then
    rm -f "$IMPORT_LOG"
  fi
  if [[ -n "$LOG_FILE" ]]; then
    rm -f "$LOG_FILE"
  fi
  if [[ -n "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

if [[ ! -f addons/gdUnit4/bin/GdUnitCmdTool.gd ]]; then
  BOOTSTRAPPED_ADDON=1
  TMP_DIR="$(mktemp -d)"
  mkdir -p addons
  printf 'Bootstrapping GdUnit4 %s for this local run...\n' "$GDUNIT4_VERSION"
  curl --fail --location --silent --show-error "$GDUNIT4_URL" --output "$TMP_DIR/gdunit4.zip"
  ZIP_PATH="$TMP_DIR/gdunit4.zip" OUT_DIR="$TMP_DIR/unpacked" python3 - <<'PY'
import os
import pathlib
import shutil
import zipfile

zip_path = pathlib.Path(os.environ["ZIP_PATH"])
out_dir = pathlib.Path(os.environ["OUT_DIR"])
with zipfile.ZipFile(zip_path) as archive:
    archive.extractall(out_dir)
addon_candidates = list(out_dir.glob("*/addons/gdUnit4"))
if not addon_candidates:
    raise SystemExit("Downloaded GdUnit4 archive did not contain addons/gdUnit4")
shutil.copytree(addon_candidates[0], pathlib.Path("addons/gdUnit4"))
PY
fi

if [[ ! -f addons/gdUnit4/bin/GdUnitCmdTool.gd ]]; then
  printf 'ERROR: addons/gdUnit4/bin/GdUnitCmdTool.gd is missing after setup.\n' >&2
  exit 1
fi

printf 'Godot: %s\n' "$("$GODOT_BIN_RESOLVED" --version)"
printf 'GdUnit4: %s\n' "$(awk -F'=' '/^version=/ {gsub(/\"/, "", $2); print $2}' addons/gdUnit4/plugin.cfg)"

# First import populates Godot's .godot/global_script_class_cache.cfg. Without
# this, a fresh clone can fail to resolve GdUnit4 class_name declarations even
# though the addon files are present.
IMPORT_LOG="$(mktemp)"
GODOT_DISABLE_LEAK_CHECKS="${GODOT_DISABLE_LEAK_CHECKS:-1}" \
  "$GODOT_BIN_RESOLVED" --headless --editor --quit --path . >"$IMPORT_LOG" 2>&1 || {
    cat "$IMPORT_LOG" >&2
    exit 1
  }
if grep -Eq 'SCRIPT ERROR|Parse Error|Failed loading resource|Cannot open file' "$IMPORT_LOG"; then
  cat "$IMPORT_LOG" >&2
  printf 'ERROR: Godot reported an import/load error before the GdUnit4 run.
' >&2
  exit 1
fi

args=(
  --headless
  --path .
  -s
  -d
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd
  -rd "$REPORT_DIR"
  --ignoreHeadlessMode
  -c
)
for test_path in "${TEST_PATHS[@]}"; do
  args+=(-a "$test_path")
done

LOG_FILE="$(mktemp)"
set +e
GODOT_DISABLE_LEAK_CHECKS="${GODOT_DISABLE_LEAK_CHECKS:-1}" \
  "$GODOT_BIN_RESOLVED" "${args[@]}" 2>&1 | tee "$LOG_FILE"
status=${PIPESTATUS[0]}
set -e

if [[ "$status" -ne 0 ]]; then
  printf 'ERROR: GdUnit4 exited with %d.\n' "$status" >&2
  exit "$status"
fi

# Godot can return 0 for script-load failures before the test runner owns the
# process. Treat those as hard local-test failures.
if grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script' "$LOG_FILE"; then
  printf 'ERROR: Godot reported a script/load error during the GdUnit4 run.\n' >&2
  exit 1
fi

printf 'GdUnit4 local run passed. Reports written under %s.\n' "$REPORT_DIR"
