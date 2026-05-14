# Test Infrastructure

**Engine**: Godot 4.6 / GDScript  
**Test Framework**: GdUnit4  
**CI**: `.github/workflows/tests.yml`  
**Setup date**: 2026-05-14

## Directory Layout

```text
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
```

## Installing GdUnit4

1. Open Godot.
2. Open **AssetLib** and search for `GdUnit4`.
3. Download and install the plugin.
4. Enable it: **Project → Project Settings → Plugins → GdUnit4**.
5. Restart the editor.
6. Verify `res://addons/gdunit4/` exists.

CI uses the official `MikeSchulze/gdunit4-action@v1` action, which installs the
test runner for GitHub Actions. Local editor runs still require the plugin.

## Running Tests

### CI

GitHub Actions runs tests on every push to `main` and on every pull request to
`main`.

### Local headless run

```bash
tools/ci/run_gdunit4_local.sh
```

The local runner requires a Godot CLI on `PATH` or `GODOT_BIN` pointing to the
executable. On macOS, `brew install --cask godot` provides Godot 4.6.2 and links
`godot` on `PATH`. If `res://addons/gdUnit4/` is not vendored in the project,
the script temporarily bootstraps GdUnit4 v6.1.3 for the run, refreshes Godot's
class cache, runs `res://tests/unit` and `res://tests/integration`, writes
reports under `reports/`, and removes only the temporary addon it created.

Override defaults when needed:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/ci/run_gdunit4_local.sh
GDUNIT4_TEST_PATHS="res://tests/unit" tools/ci/run_gdunit4_local.sh
```

### Local editor

Use the GdUnit4 inspector after installing and enabling the plugin.

### Direct Godot smoke check

```bash
godot --headless --script tests/gdunit4_runner.gd
```

The direct runner expects `res://addons/gdUnit4/bin/GdUnitCmdTool.gd` to exist.
Use `tools/ci/run_gdunit4_local.sh` for fresh clones because it can bootstrap
the addon before invoking Godot.

## Test Naming

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[scenario]_[expected]`
- **Example**: `combat_damage_test.gd` → `test_base_attack_returns_expected_damage()`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location |
|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` |
| Visual/Feel | Screenshot + lead sign-off | `tests/evidence/` |
| UI | Manual walkthrough OR interaction test | `tests/evidence/` |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` |

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging.

## First Example Test

`tests/unit/test_infrastructure/gdunit_smoke_test.gd` verifies that the GdUnit4
pipeline can discover and execute a minimal GDScript suite before gameplay code
exists.
